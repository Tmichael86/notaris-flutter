"""Prepare and verify one offline Windows Monitoring acceptance profile."""

import argparse
from contextlib import closing
import json
import os
from pathlib import Path
import runpy
import sqlite3
import subprocess
import tempfile


auth = runpy.run_path(str(Path(__file__).with_name('payment-demo-acceptance.py')))
require, plain, read_only, command, digest = (
    auth[key] for key in ('require', 'plain', 'read_only', 'command', 'digest')
)
accounts = {'pembaca.demo': 1, 'petugas.demo': 0}


def snapshot(root):
    file = root / 'offline.sqlite'
    with closing(read_only(file)) as db:
        require(db.execute('PRAGMA user_version').fetchone()[0] == 24,
                'SQLite Monitoring harus v24.')
        require([r[0] for r in db.execute('PRAGMA integrity_check')] == ['ok'],
                'SQLite integrity_check gagal.')
        require(not db.execute('PRAGMA foreign_key_check').fetchall(), 'Pelanggaran FK.')
        counts = dict(db.execute('SELECT jenis_transaksi,count(*) FROM transaksis '
                                 'WHERE deleted_at IS NULL GROUP BY jenis_transaksi'))
        require(counts == {'notaris': 8, 'ppat': 8}, 'Jumlah transaksi berbeda.')
        cursor = db.execute("SELECT cursor FROM transaction_cloud_feed "
                            "WHERE scope='monitoring-demo'").fetchone()
        require(cursor is not None and cursor[0] == 3, 'Cursor fixture berbeda.')
    return {'schema': 24, 'integrity': 'ok', 'fk': 0, 'counts': counts,
            'transaction_cursor': cursor[0], 'sqlite_sha256': digest(file)}


def verify_accounts(root, profile):
    rows = json.loads(command([root / 'session.exe', 'verify-db', profile], capture=True))
    expected = {name: auth['ACCOUNTS'][name][:2] for name in auth['ACCOUNTS']}
    require(len(rows) == len(expected) and
            {r['username']: (r['id'], r['role']) for r in rows} == expected and
            all((r['read'], r['create'], r['update'], r.get('monitoring', 0)) ==
                (1, 0, 0, accounts.get(r['username'], 0)) for r in rows),
            'Izin sesi Monitoring berbeda.')
    return rows


def auth_hashes(root):
    return {name: digest(root / name) for name in [*auth['AUTH_FILES'], 'monitoring-owner']}


def prepare():
    require(not auth['port_open'](), 'Port PostgreSQL disposable 55674 sudah dipakai.')
    scratch = Path(tempfile.mkdtemp(prefix='notaris-monitoring-auth-')).resolve(strict=True)
    helper = scratch / 'session.exe'
    auth['build_helper'](helper)
    profile = auth['provision'](scratch, helper, monitoring=True)
    root = auth['owned_root'](profile)
    with (root / 'session.exe').open('xb') as file:
        file.write(plain(helper).read_bytes())
    prepare_sqlite(root, profile)


def prepare_sqlite(root, profile):
    require(plain(root / 'monitoring-owner').read_text(encoding='ascii') == profile and
            not any(os.path.lexists(root / name) for name in
                    ('offline.sqlite', 'baseline.json', 'launch.lock')),
            'Profil Monitoring sudah dipakai atau marker berbeda.')
    command(['flutter.bat', 'test', '--no-pub', 'test/database/monitoring_demo_profile_test.dart'],
            cwd=auth['FRONTEND'], env={**os.environ, 'NOTARIS_MONITORING_PREPARE': profile},
            timeout=240)
    users = verify_accounts(root, profile)
    state = snapshot(root)
    with (root / 'baseline.json').open('x', encoding='utf-8') as file:
        json.dump({'id': profile, 'auth': auth_hashes(root), 'initial': state}, file, indent=2)
    print(json.dumps({'result': 'PASS INITIAL', 'profile': profile, 'root': str(root),
                      'accounts': users, **state}, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('prepare', 'credential', 'launch', 'postcheck'))
    parser.add_argument('--id')
    parser.add_argument('--account', choices=accounts)
    args = parser.parse_args()
    auth['completion']['maintenance'](24)
    if args.action == 'prepare':
        require(args.id is None and args.account is None, 'Prepare selalu membuat profil baru.')
        prepare()
        return
    require(args.id, 'ID profil diperlukan.')
    root = auth['owned_root'](args.id)
    require(plain(root / 'monitoring-owner').read_text(encoding='ascii') == args.id,
            'Marker Monitoring berbeda.')
    require(not os.path.lexists(root / 'launch.lock'), 'Tutup Flutter atau tinjau lock.')
    baseline = json.loads(plain(root / 'baseline.json').read_text(encoding='utf-8'))
    require(baseline['id'] == args.id and baseline['auth'] == auth_hashes(root),
            'Baseline autentikasi berbeda.')
    before = snapshot(root)
    require(before == baseline['initial'], 'SQLite berbeda dari baseline read-only.')
    if args.action == 'postcheck':
        print(json.dumps({'result': 'PASS', 'profile': args.id, **before}, indent=2))
        return
    helper_sha = auth['trusted_helper_sha'](root)
    verify_accounts(root, args.id)
    if args.action == 'credential':
        require(args.account, 'Akun diperlukan.')
        auth['show_credential'](root, args.id, args.account)
        return
    lock = root / 'launch.lock'
    with lock.open('x', encoding='ascii') as file:
        file.write(args.id)
    try:
        command(['flutter.bat', 'run', '-d', 'windows', '--debug', '--no-pub',
                 '-t', 'lib/monitoring_demo_main.dart',
                 f'--dart-define=NOTARIS_MONITORING_DEMO_ID={args.id}',
                 f'--dart-define=NOTARIS_MONITORING_HELPER_SHA256={helper_sha}'],
                cwd=auth['FRONTEND'], timeout=None)
        require(snapshot(root) == before, 'SQLite berubah selama Flutter berjalan.')
        print('MONITORING SQLITE UNCHANGED')
    finally:
        lock.unlink()


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, RuntimeError, sqlite3.Error, subprocess.SubprocessError) as error:
        raise SystemExit(f'BLOCKED: {error}') from None
