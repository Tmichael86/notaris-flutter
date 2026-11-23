"""Prepare and verify one read-only Windows Materai profile."""

import argparse
from contextlib import closing
import json
import os
from pathlib import Path
import runpy
import sqlite3
import subprocess
import tempfile


scripts = Path(__file__).resolve().parent
presentation = runpy.run_path(str(scripts / 'presentation-demo.py'))
auth = presentation['auth']
require, plain, read_only, command, digest = (
    auth[key] for key in ('require', 'plain', 'read_only', 'command', 'digest')
)
reader, denied = 'superadmin.demo', 'pembaca.demo'


def root_for(profile):
    root = presentation['root_for'](profile)
    require(plain(root / 'materai-owner').read_text(encoding='ascii') == profile,
            'Marker profil Materai berbeda.')
    return root


def snapshot(root):
    file = root / 'offline.sqlite'
    with closing(read_only(file)) as db:
        version = db.execute('PRAGMA user_version').fetchone()[0]
        require(version == 27, 'SQLite Materai harus v27.')
        require([row[0] for row in db.execute('PRAGMA integrity_check')] == ['ok'],
                'SQLite integrity_check gagal.')
        require(not db.execute('PRAGMA foreign_key_check').fetchall(), 'Pelanggaran FK.')
        counts = {table: db.execute(f'SELECT count(*) FROM {table}').fetchone()[0] for table in (
            'transaksis', 'transaksi_details', 'transaksi_riwayat_pembayaran',
            'transaksi_pembayaran_audit', 'transaction_cloud_identity', 'transaction_cloud_pending', 'materai_movements',
        )}
        cursor = db.execute("SELECT cursor FROM transaction_cloud_feed WHERE scope='penghasilan-demo'").fetchone()
        require(counts['transaksis'] == 16 and counts['materai_movements'] == 14 and cursor is not None and cursor[0] == 3,
                'Fixture atau cursor Materai berbeda.')
    return {'schema': version, 'integrity': 'ok', 'fk': 0, 'counts': counts,
            'transaction_cursor': cursor[0], 'sqlite_sha256': digest(file)}


def session_hashes(root, account):
    files = (['owner', 'presentation-owner', 'public.key', 'session.exe',
              f'{reader}.bin', f'handoff-{reader}.bin'] if account == reader else
             [*auth['AUTH_FILES'], 'monitoring-owner'])
    return {name: digest(root / name) for name in files}


def prepare():
    profile, root, verified = presentation['provision_auth']()
    def has_materai(package):
        return any(row['sidebar']['sidebar_kode'] == 'laporan_materai' and
                   row['sidebar']['status'] == 1 and row['read'] == 1
                   for row in package['sidebars'])

    require(has_materai(verified), 'Grant laporan_materai aktif belum terverifikasi.')
    with (root / 'materai-owner').open('x', encoding='ascii') as file:
        file.write(profile)
    scratch = Path(tempfile.mkdtemp(prefix='notaris-materai-denied-')).resolve(strict=True)
    helper = root / 'session.exe'
    denied_id = auth['provision'](scratch, helper, monitoring=True)
    denied_root = auth['owned_root'](denied_id)
    with (denied_root / 'session.exe').open('xb') as file:
        file.write(plain(helper).read_bytes())
    # As the denied bundle has no SQLite, verify the signed account directly.
    accounts = json.loads(command([denied_root / 'session.exe', 'verify', denied_id], capture=True))
    account = next(row for row in accounts if row['username'] == denied)
    # The Go verifier's monitoring scope allows only Transaksi and Monitoring.
    # Its summary reports the Monitoring grant without the full sidebar list.
    require((account['id'], account['role'], account['create'], account['update'],
             account['monitoring']) == (103, 'user', 0, 0, 1),
            'Sesi penolakan berbeda.')
    with (root / 'materai-denied-id').open('x', encoding='ascii') as file:
        file.write(denied_id)
    command(['flutter.bat', 'test', '--no-pub', 'test/database/materai_demo_profile_test.dart'],
            cwd=auth['FRONTEND'], env={**os.environ, 'NOTARIS_MATERAI_PREPARE': profile}, timeout=240)
    initial = snapshot(root)
    with (root / 'materai-baseline.json').open('x', encoding='utf-8') as file:
        json.dump({'profile': profile, 'denied_id': denied_id,
                   'auth': {reader: session_hashes(root, reader), denied: session_hashes(denied_root, denied)},
                   'initial': initial}, file, indent=2)
    print(json.dumps({'result': 'PASS INITIAL', 'profile': profile, 'root': str(root),
                      'read_expires_at': verified['expiresAt'], 'denied_expires_at': account['expiresAt'], **initial}, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('prepare', 'credential', 'launch', 'postcheck'))
    parser.add_argument('--id')
    parser.add_argument('--account', choices=(reader, denied))
    parser.add_argument('--expect', choices=('initial', 'final'))
    args = parser.parse_args()
    auth['completion']['maintenance'](24)
    if args.action == 'prepare':
        require(args.id is None and args.account is None and args.expect is None, 'Prepare membuat profil baru.')
        prepare()
        return
    require(args.id, 'ID profil Materai diperlukan.')
    root = root_for(args.id)
    with presentation['occupied'](root):
        baseline = json.loads(plain(root / 'materai-baseline.json').read_text(encoding='utf-8'))
        denied_id = plain(root / 'materai-denied-id').read_text(encoding='ascii')
        require(baseline['profile'] == args.id and baseline['denied_id'] == denied_id, 'Binding profil berbeda.')
        denied_root = auth['owned_root'](denied_id)
        require(baseline['auth'] == {reader: session_hashes(root, reader), denied: session_hashes(denied_root, denied)},
                'Fingerprint autentikasi berbeda.')
        before = snapshot(root)
        require(before == baseline['initial'], 'SQLite berbeda dari baseline.')
        if args.action == 'postcheck':
            require(args.expect, 'Tentukan initial atau final.')
            print(json.dumps({'result': f'PASS {args.expect.upper()}', 'profile': args.id, **before}, indent=2))
            return
        require(args.account, 'Pilih akun untuk sesi ini.')
        allowed = args.account == reader
        account_root, account_id = (root, args.id) if allowed else (denied_root, denied_id)
        sha = auth['trusted_helper_sha'](account_root, presentation=allowed)
        if allowed:
            presentation['verify_session'](account_root, account_id)
        else:
            require(plain(account_root / 'monitoring-owner').read_text(encoding='ascii') == account_id,
                    'Scope akun tanpa izin berbeda.')
            command([account_root / 'session.exe', 'verify', account_id], capture=True)
        if args.action == 'credential':
            auth['show_credential'](account_root, account_id, args.account)
            return
        command(['flutter.bat', 'run', '-d', 'windows', '--debug', '--no-pub',
                 '-t', 'lib/materai_demo_main.dart',
                 f'--dart-define=NOTARIS_MATERAI_DEMO_ID={args.id}',
                 f'--dart-define=NOTARIS_MATERAI_AUTH_ID={account_id}',
                 f'--dart-define=NOTARIS_MATERAI_HELPER_SHA256={sha}'], cwd=auth['FRONTEND'], timeout=None)
        require(snapshot(root) == before, 'SQLite berubah selama Flutter berjalan.')
        print('MATERAI SQLITE UNCHANGED')


if __name__ == '__main__':
    try:
        main()
    except (OSError, RuntimeError, ValueError, KeyError, StopIteration, sqlite3.Error, subprocess.SubprocessError) as error:
        raise SystemExit(f'BLOCKED: {error}') from None
