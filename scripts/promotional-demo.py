"""Prepare and operate only the dedicated post-P0 promotional Windows profile."""
import argparse
from contextlib import closing
import hashlib
import json
import os
from pathlib import Path
import re
import runpy
import socket
import sqlite3
import subprocess
import tempfile

auth = runpy.run_path(str(Path(__file__).with_name('payment-demo-acceptance.py')))
REPO, FRONT = auth['REPO'], auth['FRONTEND']
PG = Path('D:/Program Files/PostgreSQL/bin')
PORT, HTTP = 55794, 55882


def require(condition, reason):
    if not condition:
        raise RuntimeError(reason)


def execute(args, *, capture=False, cwd=None, env=None, timeout=240):
    result = subprocess.run([str(x) for x in args], cwd=cwd or REPO / 'backend-notaris-go',
                            env=env or clean_env(), capture_output=capture, text=True,
                            timeout=timeout, check=False)
    # Captured output can include account sessions. Never print it on failure.
    require(result.returncode == 0, f'{Path(str(args[0])).name}: operasi ditolak (exit {result.returncode}); evidence dipertahankan.')
    return result.stdout if capture else None


def clean_env():
    return {k: v for k, v in os.environ.items() if not k.upper().startswith('PG') and not k.startswith('NOTARIS_')}


def occupied(port):
    with socket.socket() as sock:
        return sock.connect_ex(('127.0.0.1', port)) == 0


def root_for(profile):
    require(re.fullmatch('[a-f0-9]{32}', profile or ''), 'ID promosi diperlukan.')
    root = auth['plain'](Path(tempfile.gettempdir()).resolve() / f'notaris-payment-{profile}', directory=True)
    for name in ('owner', 'promotional-owner'):
        require(auth['plain'](root / name).read_text(encoding='ascii') == profile, 'Marker profil berbeda.')
    return root


def helper(root, action, *, capture=True):
    return execute([auth['plain'](root / 'session.exe'), action, root.name.removeprefix('notaris-payment-')], capture=capture, timeout=None if action in ('promo-serve', 'promo-credential') else 30)


def pin_helper(root):
    with tempfile.TemporaryDirectory(prefix='notaris-promo-helper-') as folder:
        fresh = Path(folder).resolve(strict=True) / 'session.exe'
        auth['build_helper'](fresh)
        require(auth['digest'](fresh) == auth['digest'](root / 'session.exe'), 'Helper bukan build source terkini; STOP untuk review kompatibilitas.')
    helper(root, 'promo-validate-profile')


def pg_ctl(root, action):
    data = auth['plain'](root / 'pgdata', directory=True)
    require(data.parent == root, 'Data directory bukan milik profil.')
    args = [PG / 'pg_ctl.exe', action, '-D', data, '-w', '-t', '25']
    if action == 'start':
        require(not occupied(PORT), 'Port PostgreSQL demo sudah terpakai; tidak mengambil instance lain.')
        args += ['-l', root / 'postgres.log', '-o',
                 f'-h 127.0.0.1 -p {PORT} -c log_statement=none -c log_min_error_statement=panic -c log_parameter_max_length_on_error=0']
    elif action == 'stop':
        args += ['-m', 'fast']
    else:
        raise RuntimeError('Aksi cluster tidak dikenal.')
    result = subprocess.run([str(x) for x in args], env=clean_env(), stdin=subprocess.DEVNULL,
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=45)
    require(result.returncode == 0, 'pg_ctl demo gagal; tidak ada fallback atau retry otomatis.')


def snapshot(root):
    # No original database discovery or maintenance helper is invoked.
    dbfile = auth['plain'](root / 'offline.sqlite')
    with closing(sqlite3.connect(dbfile.as_uri() + '?mode=ro', uri=True)) as db:
        db.execute('PRAGMA query_only=ON')
        require(db.execute('PRAGMA user_version').fetchone()[0] == 27, 'Schema promosi harus v27.')
        require(db.execute('PRAGMA integrity_check').fetchall() == [('ok',)], 'Integrity SQLite gagal.')
        require(not db.execute('PRAGMA foreign_key_check').fetchall(), 'Pelanggaran FK.')
        tables = [r[0] for r in db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name")]
        fingerprints, counts = {}, {}
        for name in tables:
            safe = name.replace('"', '""')
            rows = [json.dumps(list(r), default=lambda b: b.hex(), ensure_ascii=True, separators=(',', ':'))
                    for r in db.execute(f'SELECT * FROM "{safe}"')]
            counts[name] = len(rows)
            fingerprints[name] = hashlib.sha256('\n'.join(sorted(rows)).encode()).hexdigest()
    return {'schema': 27, 'integrity': 'ok', 'fk': 0, 'counts': counts, 'fingerprints': fingerprints}


def check(root):
    state = snapshot(root)
    baseline = json.loads(auth['plain'](root / 'promotional-baseline.json').read_text())
    require(state == baseline['sqlite'], 'SQLite demo berubah; jangan reset atau menimpa baseline.')
    actual = json.loads(helper(root, 'promo-db-check'))
    require(actual == baseline['postgres'], 'State PostgreSQL demo berubah; STOP untuk review.')
    navigation = set(re.findall(r"^\s*case '([^']+)':", (FRONT / 'lib/core/widgets/app_shell.dart').read_text(encoding='utf-8'), re.MULTILINE))
    context = json.loads(helper(root, 'promo-fixture-context'))
    grants = context['sidebars']
    require(len(grants) == len(navigation) and
            {row['sidebar']['sidebar_nama'] for row in grants if row['read'] == 1} == navigation,
            'Grant demo berbeda dari route AppShell terkini.')
    summary = json.loads(auth['plain'](root / 'fixture-summary.json').read_text())
    return {'result': 'PASS', 'profile': root.name.removeprefix('notaris-payment-'),
            'root': str(root), 'schema': 27, 'integrity': 'ok', 'fk': 0,
            'menus': len(navigation), 'username': 'superadmin.promo', 'http': 'http://127.0.0.1:55882',
            'postgres': actual, 'fixture': summary}


def prepare():
    require(os.name == 'nt', 'Windows DPAPI diperlukan.')
    require(not occupied(PORT) and not occupied(HTTP), 'Port demo terpakai; tidak reuse instance tanpa identitas.')
    with tempfile.TemporaryDirectory(prefix='notaris-promo-build-') as folder:
        built = Path(folder) / 'session.exe'
        auth['build_helper'](built)
        raw = json.loads(execute([built, 'promo-init'], capture=True))
        profile = raw['profile']; root = root_for(profile)
        with (root / 'session.exe').open('xb') as target:
            target.write(built.read_bytes())
    print(f'NEW_PROMOTIONAL_PROFILE={profile}', flush=True)
    password_file = auth['plain'](root / 'initdb-password')
    try:
        execute([PG / 'initdb.exe', '-D', root / 'pgdata', '-U', 'promo_owner', '-A',
                 'scram-sha-256', '--pwfile', password_file, '--no-locale', '-E', 'UTF8'], capture=True)
    finally:
        password_file.unlink(missing_ok=True)
    pg_ctl(root, 'start')
    try:
        helper(root, 'promo-bootstrap')
        env = {**clean_env(), 'NOTARIS_PROMOTIONAL_TEST_PROFILE': profile}
        execute(['go', 'test', './cmd/paymentdemo', '-run', 'TestPromotional', '-v', '-count=1'], env=env)
        execute(['flutter.bat', 'test', '--no-pub', 'test/database/promotional_demo_profile_test.dart', '--reporter', 'expanded'], cwd=FRONT,
                env={**clean_env(), 'NOTARIS_PROMOTIONAL_PREPARE': profile}, timeout=600)
        finalize(root, profile)
    finally:
        pg_ctl(root, 'stop')
    print('PREPARED: database retained; demo backend and cluster stopped. Operator recording NOT started.')


def finalize(root, profile):
    state = snapshot(root)
    require(state['counts']['transaksis'] == 2 and state['counts']['transaksi_riwayat_pembayaran'] == 2, 'Fixture transaksi tidak lengkap.')
    postgres = json.loads(helper(root, 'promo-db-check'))
    # Start the real fixed-port process once for automated HTTP validation.
    with subprocess.Popen([str(root / 'session.exe'), 'promo-serve', profile], env=clean_env(),
                          stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                          creationflags=subprocess.CREATE_NO_WINDOW) as server:
        import time
        for _ in range(40):
            if occupied(HTTP):
                break
            require(server.poll() is None, 'Backend demo gagal startup.')
            time.sleep(.1)
        try:
            http = json.loads(helper(root, 'promo-http-check'))
            require(http['profile'] == profile and http['http'] == 'PASS', 'HTTP demo gagal.')
        finally:
            server.terminate(); server.wait(timeout=15)
    with (root / 'promotional-baseline.json').open('x', encoding='utf-8') as stream:
        json.dump({'sqlite': state, 'postgres': postgres}, stream, indent=2)
    print(json.dumps(check(root), indent=2), flush=True)


def validate_existing(root, profile):
    require(not occupied(HTTP), 'Tutup backend demo sebelum validasi rehearsal.')
    if not occupied(PORT):
        pg_ctl(root, 'start')
    try:
        helper(root, 'promo-db-check')
        before = snapshot(root)
        require((root / 'fixture-summary.json').is_file(), 'Fixture belum selesai; tidak reseed otomatis.')
        execute(['flutter.bat', 'test', '--no-pub', 'test/database/promotional_demo_profile_test.dart', '--reporter', 'expanded'], cwd=FRONT,
                env={**clean_env(), 'NOTARIS_PROMOTIONAL_PREPARE': profile, 'NOTARIS_PROMOTIONAL_VERIFY': '1'}, timeout=600)
        execute(['go', 'test', './cmd/paymentdemo', '-run', '^TestPromotionalAttestationReadOnly$', '-count=1', '-v'],
                env={**clean_env(), 'NOTARIS_PROMOTIONAL_TEST_PROFILE': profile})
        require(snapshot(root) == before, 'Validasi mengubah fixture.')
        if (root / 'promotional-baseline.json').exists():
            print(json.dumps(check(root), indent=2))
        else:
            finalize(root, profile)
    finally:
        pg_ctl(root, 'stop')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('prepare', 'validate', 'backend', 'health', 'check', 'credential', 'launch', 'stop'))
    parser.add_argument('--id')
    args = parser.parse_args()
    if args.action == 'prepare':
        require(args.id is None, 'Prepare selalu membuat profil BARU.')
        prepare(); return
    root = root_for(args.id); pin_helper(root)
    if args.action == 'validate':
        validate_existing(root, args.id)
    elif args.action == 'backend':
        if not occupied(PORT):
            pg_ctl(root, 'start')
        helper(root, 'promo-db-check')
        require(not occupied(HTTP), 'Port HTTP demo terpakai; tidak menjalankan server kedua.')
        print(json.dumps(check(root), indent=2), flush=True)
        helper(root, 'promo-serve', capture=False)
    elif args.action == 'stop':
        require(not occupied(HTTP), 'Tutup Terminal backend demo dengan Ctrl+C dahulu.')
        helper(root, 'promo-db-check'); pg_ctl(root, 'stop')
        print('STOPPED: hanya cluster promosi; data dipertahankan.')
    elif args.action == 'credential':
        require((root / 'bootstrap-committed.json').is_file(), 'Bootstrap belum committed.')
        print('Dialog Windows berisi kredensial akan dibuka. Tutup dialog sebelum merekam.', flush=True)
        helper(root, 'promo-credential', capture=False)
    else:
        result = check(root)
        if args.action in ('health', 'launch'):
            result['runtime'] = json.loads(helper(root, 'promo-http-check'))
        print(json.dumps(result, indent=2), flush=True)
        if args.action == 'launch':
            lock = root / 'launch.lock'
            with lock.open('x', encoding='ascii') as stream:
                stream.write(args.id)
            try:
                execute(['flutter.bat', 'run', '-d', 'windows', '--debug', '--no-pub', '-t', 'lib/promotional_demo_main.dart',
                         f'--dart-define=NOTARIS_PROMOTIONAL_ID={args.id}',
                         f'--dart-define=NOTARIS_PROMOTIONAL_HELPER_SHA256={auth["digest"](root / "session.exe")}'],
                        cwd=FRONT, timeout=None)
            finally:
                lock.unlink()
            print(json.dumps(check(root), indent=2))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, RuntimeError, KeyError, sqlite3.Error, subprocess.SubprocessError) as error:
        raise SystemExit(f'BLOCKED: {error}') from None
    except KeyboardInterrupt:
        print('\nProses demo dihentikan. Profil dipertahankan; gunakan stop setelah backend ditutup.')
