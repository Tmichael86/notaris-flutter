"""Prepare, renew or launch the isolated Windows internship demo."""

import argparse
from contextlib import closing, contextmanager
import json
import os
from pathlib import Path
import re
import runpy
import sqlite3
import subprocess
import tempfile
from uuid import uuid4


auth = runpy.run_path(str(Path(__file__).with_name('payment-demo-acceptance.py')))
require, plain, read_only, command, digest = (
    auth[key] for key in ('require', 'plain', 'read_only', 'command', 'digest')
)
username = 'superadmin.demo'
schema = 26
binding_name = 'presentation-session.json'


def root_for(profile):
    root = auth['owned_root'](profile)
    require(plain(root / 'presentation-owner').read_text(encoding='ascii') == profile,
            'Profil ini bukan milik presentasi.')
    return root


def verify_session(root, profile):
    rows = json.loads(command([root / 'session.exe', 'verify', profile], capture=True))
    package = rows[0] if len(rows) == 1 else {}
    require((package.get('username'), package.get('id'), package.get('groupId'), package.get('role'))
            == (username, 104, 104, 'superadmin'), 'Identitas Superadmin tidak terverifikasi.')
    shell = (auth['FRONTEND'] / 'lib/core/widgets/app_shell.dart').read_text(encoding='utf-8')
    names = set(re.findall(r"^\s*case '([^']+)':", shell, re.MULTILINE))
    sidebars = package['sidebars']
    require(len(sidebars) == len(names) and
            {row['sidebar']['sidebar_nama'] for row in sidebars if row['read'] == 1} == names,
            'Cakupan RBAC berbeda dari AppShell.')
    return package


def verify_data(root):
    with closing(read_only(root / 'offline.sqlite')) as db:
        require(db.execute('PRAGMA user_version').fetchone()[0] == schema,
                'Schema SQLite presentasi harus v26.')
        require([row[0] for row in db.execute('PRAGMA integrity_check')] == ['ok'],
                'SQLite integrity_check gagal.')
        require(not db.execute('PRAGMA foreign_key_check').fetchall(), 'Pelanggaran FK.')
        tables = ('transaksis', 'pemohons', 'petugas', 'transaksi_riwayat_pembayaran',
                  'transaksi_serah_terima', 'transaction_documents', 'pengeluaran')
        return {'schema': schema, 'integrity': 'ok', 'fk': 0, 'counts': {
            table: db.execute(f'SELECT count(*) FROM {table}').fetchone()[0] for table in tables
        }}


@contextmanager
def occupied(root):
    lock = root / 'launch.lock'
    with lock.open('x', encoding='ascii') as file:
        file.write(root.name)
    try:
        yield
    finally:
        lock.unlink()


def provision_auth():
    scratch = Path(tempfile.mkdtemp(prefix='notaris-presentation-auth-')).resolve(strict=True)
    helper = scratch / 'session.exe'
    auth['build_helper'](helper)
    profile = auth['provision'](scratch, helper, presentation=True)
    root = root_for(profile)
    with (root / 'session.exe').open('xb') as file:
        file.write(plain(helper).read_bytes())
    return profile, root, verify_session(root, profile)


def publish_binding(root, profile, auth_id, auth_root):
    path = root / binding_name
    if os.path.lexists(path):
        plain(path)
    temporary = root / f'.session-{uuid4().hex}.tmp'
    with temporary.open('x', encoding='utf-8') as file:
        json.dump({'data_id': profile, 'auth_id': auth_id,
                   'helper_sha256': digest(auth_root / 'session.exe')}, file)
        file.flush()
        os.fsync(file.fileno())
    os.replace(temporary, path)


def prepare():
    front = auth['FRONTEND']
    build = front / 'build/windows/x64/runner/Debug'
    require(all((build / name).is_file() for name in
                ('notaris_document_store.dll', 'notaris_document_pdf.exe', 'pdfium.dll')),
            'Build Windows debug diperlukan untuk menyiapkan dokumen sampel.')
    profile, root, session = provision_auth()
    print(f'Menyiapkan profil data presentasi {profile}.', flush=True)
    command(['flutter.bat', 'test', '--no-pub', 'test/database/presentation_demo_profile_test.dart'],
            cwd=front, timeout=240,
            env={**os.environ, 'NOTARIS_PRESENTATION_PREPARE': profile})
    publish_prepared(profile, root, session)


def publish_prepared(profile, root, session):
    require(not os.path.lexists(root / binding_name), 'Profil presentasi sudah diterbitkan.')
    state = verify_data(root)
    require(state['counts'] == {'transaksis': 2, 'pemohons': 2, 'petugas': 1,
            'transaksi_riwayat_pembayaran': 2, 'transaksi_serah_terima': 2,
            'transaction_documents': 2, 'pengeluaran': 1}, 'Dataset presentasi belum lengkap.')
    publish_binding(root, profile, profile, root)
    summary(profile, root, session, state)


def summary(profile, root, session, state):
    print(json.dumps({'result': 'PASS', 'profile': profile, 'root': str(root),
                      'username': username, 'role': session['role'],
                      'menus': len(session['sidebars']),
                      'expiresAt': session['expiresAt'], **state}, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('prepare', 'credential', 'launch', 'renew', 'check'))
    parser.add_argument('--id')
    args = parser.parse_args()
    auth['completion']['maintenance'](24)
    if args.action == 'prepare':
        require(args.id is None, 'Prepare selalu membuat profil data baru.')
        prepare()
        return
    require(args.id, 'ID profil presentasi diperlukan.')
    root = root_for(args.id)
    with occupied(root):
        state = verify_data(root)
        binding = json.loads(plain(root / binding_name).read_text(encoding='utf-8'))
        require(binding['data_id'] == args.id, 'Binding profil data berbeda.')
        if args.action == 'renew':
            original = digest(root / 'offline.sqlite')
            auth_id, auth_root, session = provision_auth()
            require(digest(root / 'offline.sqlite') == original,
                    'SQLite berubah selama pembaruan sesi.')
            publish_binding(root, args.id, auth_id, auth_root)
            summary(args.id, root, session, state)
            return
        auth_id = binding['auth_id']
        auth_root = root_for(auth_id)
        sha = auth['trusted_helper_sha'](auth_root, presentation=True)
        require(sha == binding['helper_sha256'], 'Fingerprint helper berbeda.')
        session = verify_session(auth_root, auth_id)
        if args.action == 'check':
            summary(args.id, root, session, state)
        elif args.action == 'credential':
            auth['show_credential'](auth_root, auth_id, username)
        else:
            command(['flutter.bat', 'run', '-d', 'windows', '--debug', '--no-pub',
                     '-t', 'lib/presentation_demo_main.dart',
                     f'--dart-define=NOTARIS_PRESENTATION_DATA_ID={args.id}',
                     f'--dart-define=NOTARIS_PRESENTATION_AUTH_ID={auth_id}',
                     f'--dart-define=NOTARIS_PRESENTATION_HELPER_SHA256={sha}'],
                    cwd=auth['FRONTEND'], timeout=None)
            verify_data(root)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, RuntimeError, sqlite3.Error, subprocess.SubprocessError) as error:
        raise SystemExit(f'BLOCKED: {error}') from None
