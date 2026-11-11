"""Provision and inspect Windows-only offline payment acceptance profiles."""

import argparse
from contextlib import closing
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import runpy
import secrets
import shutil
import socket
import subprocess
import tempfile
from uuid import uuid4


completion = runpy.run_path(str(Path(__file__).with_name('notaris-completion-acceptance.py')))
REPO, FRONTEND = completion['REPO'], completion['FRONTEND']
require, plain, read_only = (completion[name] for name in ('require', 'plain', 'read_only'))
PORT = 55674
PG_BIN = Path('D:/Program Files/PostgreSQL/bin')
ACCOUNTS = {'petugas.demo': (101, 'user', 1, 1), 'admin.demo': (102, 'superadmin', 0, 1),
            'pembaca.demo': (103, 'user', 0, 0)}
AUTH_FILES = ['owner', 'public.key', 'session.exe'] + [
    f'{prefix}{name}.bin' for name in ACCOUNTS for prefix in ('', 'handoff-')
]
PHASES = ('initial', 'add', 'edit', 'cancel', 'restart')
NOTARIS, PPAT = '1001111260001', '2001111260001'
PAYMENT, AUDIT = 'transaksi_riwayat_pembayaran', 'transaksi_pembayaran_audit'


def digest(path):
    return hashlib.sha256(plain(path).read_bytes()).hexdigest()


def owned_root(profile):
    require(re.fullmatch(r'[a-f0-9]{32}', profile), 'ID profil tidak valid.')
    root = plain(Path(tempfile.gettempdir()).resolve(strict=True) / f'notaris-payment-{profile}',
                 directory=True)
    require(plain(root / 'owner').read_text(encoding='ascii') == profile, 'Marker profil berbeda.')
    return root


def command(args, *, capture=False, timeout=120, **kwargs):
    return subprocess.run([str(arg) for arg in args], check=True, text=True,
                          stdout=subprocess.PIPE if capture else None, timeout=timeout,
                          **kwargs).stdout


def build_helper(path):
    command(['go.exe', 'build', '-trimpath', '-buildvcs=false', '-o', path, './cmd/paymentdemo'],
            cwd=REPO / 'backend-notaris-go', timeout=240)


def trusted_helper_sha(root):
    # The manifest is evidence. Only a fresh build of the workspace helper
    # establishes which executable the launcher may run and pin in Flutter.
    with tempfile.TemporaryDirectory(prefix='notaris-payment-helper-') as folder:
        helper = Path(folder).resolve(strict=True) / 'session.exe'
        build_helper(helper)
        expected = digest(helper)
    require(digest(root / 'session.exe') == expected, 'Helper profil berbeda dari build tepercaya.')
    return expected


def port_open():
    with socket.socket() as sock:
        sock.settimeout(1)
        return sock.connect_ex(('127.0.0.1', PORT)) == 0


def provision(scratch, helper):
    require(not port_open(), f'Port disposable {PORT} sudah dipakai.')
    data = scratch / 'pgdata'
    pg_ctl = PG_BIN / 'pg_ctl.exe'
    connection = ['-h', '127.0.0.1', '-p', PORT, '-U', 'postgres']
    database = 'payment_demo_' + uuid4().hex[:16]
    # No inherited libpq service/option/credential configuration.
    env = {key: val for key, val in os.environ.items() if not key.upper().startswith('PG')}
    password = secrets.token_hex(32)
    password_file = scratch / 'initdb-password'
    try:
        with password_file.open('x', encoding='ascii') as stream:
            stream.write(password + '\n')
        command([PG_BIN / 'initdb.exe', '-D', data, '-U', 'postgres', '-A', 'scram-sha-256',
                 '--pwfile', password_file, '--no-locale', '-E', 'UTF8'], capture=True, env=env)
    finally:
        password_file.unlink(missing_ok=True)
    client_env = {**env, 'PGPASSWORD': password}
    try:
        command([pg_ctl, 'start', '-D', data, '-l', scratch / 'postgres.log',
                 '-o', f'-h 127.0.0.1 -p {PORT}', '-w', '-t', '25'], env=env)
        psql = [PG_BIN / 'psql.exe', '-X', '-w', *connection, '-v', 'ON_ERROR_STOP=1', '-Atc']
        target = command([*psql, 'SHOW data_directory', '-d', 'postgres'],
                         capture=True, env=client_env).strip()
        require(Path(target).resolve(strict=True) == data, 'Instance PostgreSQL bukan disposable.')
        command([PG_BIN / 'createdb.exe', '-w', *connection, database], env=client_env)
        command([*psql, f"COMMENT ON DATABASE {database} IS 'NOTARIS PAYMENT DISPOSABLE {database}'",
                 '-d', database], capture=True, env=client_env)
        return command([helper, 'provision', database, data], capture=True, env=client_env).strip()
    finally:
        if (data / 'postmaster.pid').exists():
            command([pg_ctl, 'stop', '-D', data, '-m', 'fast', '-w', '-t', '25'], env=env)
        require(not port_open(), 'Port backend disposable masih terbuka.')


def auth_status(root, profile):
    accounts = json.loads(command([root / 'session.exe', 'verify', profile], capture=True))
    require(len(accounts) == 3 and all(account['read'] == 1 for account in accounts) and
            {a['username']: (a['id'], a['role'], a['create'], a['update']) for a in accounts}
            == ACCOUNTS, 'Akun atau izin autentikasi berbeda.')
    return accounts


def show_credential(root, profile, account):
    print(f'Membuka dialog Windows untuk {account}. Terminal menunggu hingga dialog ditutup. '
          'Jika belum terlihat, periksa taskbar atau tekan Alt+Tab. '
          'Tekan Ctrl+C untuk membatalkan.', flush=True)
    args = [str(root / 'session.exe'), 'credential', profile, account]
    with subprocess.Popen(args, creationflags=subprocess.CREATE_NEW_PROCESS_GROUP) as child:
        try:
            status = child.wait(timeout=600)
        except (KeyboardInterrupt, subprocess.TimeoutExpired) as error:
            child.terminate()
            child.wait()
            if isinstance(error, KeyboardInterrupt):
                raise RuntimeError('Pembukaan dialog dibatalkan. Jalankan ulang credential bila perlu.') from None
            raise RuntimeError('Dialog melewati batas 10 menit dan telah ditutup. Jalankan ulang credential.') from None
    require(status == 0, f'Helper gagal membuka kredensial demo (kode {status}). '
            'Periksa sesi Windows yang sama dengan saat profil disiapkan.')


def verify_original_unchanged(original):
    file = completion['quiet_sqlite_file'](completion['original_database_path']())
    require(original['schema'] == 20 and str(file) == original['path'] and
            digest(file) == original['sha256'], 'SQLite development berubah.')


def rupiah_state(payment):
    deleted = payment['deleted_at']
    return {'date': payment['tanggal_pembayaran'], 'amount': payment['nominal_rupiah'],
            'method': payment['metode_pembayaran'], 'note': payment['keterangan'],
            'order': payment['urutan_pembayaran'], 'status': payment['status'],
            'deleted_at': None if deleted is None else deleted * 1000}


def payment_phase(payments, history):
    require(len(payments) in (1, 2), 'Jumlah pembayaran Notaris di luar skenario.')
    first = payments[0]
    require(first['nominal_rupiah'] == first['nominal'] == 500000 and
            first['urutan_pembayaran'] == first['status'] == 1 and first['deleted_at'] is None,
            'Pembayaran awal berubah.')
    if len(payments) == 1:
        require(not history, 'Histori tersedia tanpa cicilan.')
        return 'initial', 500000

    installment = payments[1]
    require(installment['urutan_pembayaran'] == 2 and
            installment['nominal'] == installment['nominal_rupiah'] and
            installment['is_sync_dirty'] == 1 and installment['last_synced_at'] is None,
            'Identitas atau state cicilan berbeda.')
    steps = [('add', 101), ('edit', 102), ('cancel', 102)]
    require(1 <= len(history) <= 3 and
            [(row['action'], row['actor_user_id']) for row in history] == steps[:len(history)] and
            all(row['payment_uuid'] == installment['uuid'] for row in history),
            'Audit cicilan atau aktor di luar skenario.')
    timestamps = [row['occurred_at'] for row in history]
    require(timestamps == sorted(timestamps) and timestamps[0] > 0 and
            installment['created_at'] == timestamps[0] // 1000 and
            installment['updated_at'] == timestamps[-1] // 1000 and
            (len(history) != 3 or installment['deleted_at'] == timestamps[-1] // 1000),
            'Timestamp cicilan tidak cocok dengan audit.')
    state = rupiah_state(installment)
    added = dict(state, amount=750000, status=1, deleted_at=None)
    edited = dict(added, amount=800000)
    expected = [added, edited, dict(edited, status=0, deleted_at=state['deleted_at'])]
    for index, row in enumerate(history):
        previous = json.loads(row['before_state']) if row['before_state'] is not None else None
        require(previous == (expected[index - 1] if index else None) and
                json.loads(row['after_state']) == expected[index] and
                (bool((row['reason'] or '').strip()) if index else row['reason'] is None),
                'Rangkaian before/after atau alasan audit berbeda.')
    require(state == expected[len(history) - 1] and
            ((state['deleted_at'] is not None) == (len(history) == 3)),
            'State cicilan tidak cocok dengan audit.')
    return PHASES[len(history)], (500000 if state['status'] == 0 else 500000 + state['amount'])


def snapshot(root):
    with closing(read_only(root / 'offline.sqlite')) as db:
        require(db.execute('PRAGMA user_version').fetchone()[0] == 23 and
                [row[0] for row in db.execute('PRAGMA integrity_check')] == ['ok'] and
                db.execute('PRAGMA foreign_key_check').fetchone() is None, 'Schema, integrity, atau FK gagal.')
        schema = [tuple(row) for row in db.execute(
            'SELECT type, name, sql FROM sqlite_schema ORDER BY type, name')]
        tables = {}
        for kind, name, _ in schema:
            if kind == 'table':
                quoted = '"' + name.replace('"', '""') + '"'
                tables[name] = [dict(row) for row in db.execute(f'SELECT * FROM {quoted} ORDER BY rowid')]
        require(all(not tables[name] for name in ('sync_logs', 'transaction_cloud_pending',
                                                 'transaction_cloud_feed', 'transaction_cloud_identity')),
                'Profil demo memiliki state sinkronisasi.')
        transactions = sorted(tables['transaksis'], key=lambda row: row['jenis_transaksi'])
        require([(row['no_akta'], row['jenis_transaksi'], row['total']) for row in transactions]
                == [(NOTARIS, 'notaris', 3000000), (PPAT, 'ppat', 3000000)], 'Fixture transaksi berbeda.')
        notaris = transactions[0]
        payments = [row for row in tables[PAYMENT] if row['transaksi_id'] == notaris['id']]
        history = tables[AUDIT]
        phase, paid = payment_phase(payments, history)
        require(notaris['pembayaran_sekarang'] == paid, 'Total dibayar tidak cocok dengan ledger.')
        require(not history or notaris['updated_at'] == history[-1]['occurred_at'] // 1000,
                'Timestamp header tidak cocok dengan audit terakhir.')
        require(all(row['seq'] == max((entry['id'] for entry in tables[row['name']]), default=0)
                    for row in tables['sqlite_sequence'] if row['name'] in (PAYMENT, AUDIT)),
                'Sequence pembayaran atau audit di luar skenario.')
        if phase != 'initial':
            tables[PAYMENT].remove(payments[1])
        tables[AUDIT] = []
        tables['sqlite_sequence'] = [row for row in tables['sqlite_sequence']
                                     if row['name'] not in (PAYMENT, AUDIT)]
        notaris.pop('pembayaran_sekarang')
        notaris.pop('updated_at')
        protected = json.dumps([schema, tables], sort_keys=True, separators=(',', ':'))
        return {'phase': phase, 'paid': paid, 'remaining': 3000000 - paid,
                'audit_count': len(history), 'sqlite': 23, 'integrity': 'ok', 'fk': 0,
                'protected_sha256': hashlib.sha256(protected.encode()).hexdigest()}


def load_baseline(root, profile):
    baseline = json.loads(plain(root / 'baseline.json').read_text(encoding='utf-8'))
    require(baseline['id'] == profile and baseline['auth'] ==
            {name: digest(root / name) for name in AUTH_FILES}, 'Manifest atau fingerprint sesi berbeda.')
    return baseline


def prepare():
    original = completion['original_witness']()
    with tempfile.TemporaryDirectory(prefix='notaris-payment-provision-') as folder:
        scratch = Path(folder).resolve(strict=True)
        helper = scratch / 'session.exe'
        build_helper(helper)
        profile = provision(scratch, helper)
        root = owned_root(profile)
        with helper.open('rb') as source, (root / 'session.exe').open('xb') as dest:
            shutil.copyfileobj(source, dest)
    accounts = auth_status(root, profile)
    command(['flutter.bat', 'test', '--no-pub', 'test/database/payment_demo_profile_test.dart'],
            cwd=FRONTEND, env={**os.environ, 'NOTARIS_PAYMENT_PREPARE': profile}, timeout=240)
    initial = snapshot(root)
    require(initial['phase'] == 'initial' and original == completion['original_witness'](),
            'Baseline initial atau SQLite development berbeda.')
    baseline = {'id': profile, 'auth': {name: digest(root / name) for name in AUTH_FILES},
                'original': original, 'initial': initial, 'accounts': accounts}
    with (root / 'baseline.json').open('x', encoding='utf-8') as manifest:
        json.dump(baseline, manifest, indent=2)
    print(json.dumps({'profile': profile, 'database': str(root / 'offline.sqlite'), **baseline}, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('prepare', 'launch', 'postcheck', 'credential', 'cleanup'))
    parser.add_argument('--id')
    parser.add_argument('--account', choices=ACCOUNTS)
    parser.add_argument('--expect', choices=PHASES)
    args = parser.parse_args()
    if args.action == 'credential':
        require(os.name == 'nt' and args.account and args.id, 'ID dan akun diperlukan.')
        root = owned_root(args.id)
        load_baseline(root, args.id)
        trusted_helper_sha(root)
        try:
            auth_status(root, args.id)
        except subprocess.CalledProcessError:
            raise RuntimeError('Sesi demo tidak dapat diverifikasi. Periksa masa berlaku '
                               'dan gunakan akun Windows yang menyiapkan profil.') from None
        show_credential(root, args.id, args.account)
        return
    completion['maintenance'](23)
    if args.action == 'prepare':
        require(args.id is None, 'Prepare selalu membuat profil baru.')
        prepare()
        return
    require(args.id, 'ID profil diperlukan.')
    root = owned_root(args.id)
    baseline = load_baseline(root, args.id)
    require(not os.path.lexists(root / 'launch.lock'), 'Profil sedang diluncurkan.')
    current = snapshot(root)
    require(current['protected_sha256'] == baseline['initial']['protected_sha256'],
            'Fingerprint data terlindungi berbeda.')
    verify_original_unchanged(baseline['original'])
    if args.action == 'postcheck':
        require(args.expect and current['phase'] == ('cancel' if args.expect == 'restart' else args.expect),
                f"Fase tidak cocok, aktual {current['phase']}.")
        if args.expect == 'restart':
            receipt = json.loads(plain(root / 'last-launch.json').read_text(encoding='utf-8'))
            require(receipt['id'] == args.id and receipt['before'] == receipt['after'] == current,
                    'Belum ada bukti Flutter dibuka ulang setelah Cancel.')
            trusted_helper_sha(root)
            auth_status(root, args.id)
        print(json.dumps({'result': 'PASS', 'checkpoint': args.expect, **current}, indent=2))
    elif args.action == 'launch':
        helper_sha = trusted_helper_sha(root)
        auth_status(root, args.id)
        lock = root / 'launch.lock'
        with lock.open('x', encoding='ascii') as stream:
            stream.write(args.id)
        try:
            command(['flutter.bat', 'run', '-d', 'windows', '--debug', '--no-pub',
                     '-t', 'lib/payment_demo_main.dart',
                     f'--dart-define=NOTARIS_PAYMENT_DEMO_ID={args.id}',
                     f'--dart-define=NOTARIS_PAYMENT_HELPER_SHA256={helper_sha}'],
                    cwd=FRONTEND, timeout=None)
            receipt = root / 'last-launch.json'
            if os.path.lexists(receipt):
                plain(receipt)
            with receipt.open('w', encoding='utf-8') as stream:
                json.dump({'id': args.id, 'before': current, 'after': snapshot(root),
                           'closed_at': datetime.now(timezone.utc).isoformat()}, stream)
        finally:
            lock.unlink()
    elif args.action == 'cleanup':
        allowed = set(AUTH_FILES) | {'offline.sqlite', 'baseline.json'}
        if os.path.lexists(root / 'last-launch.json'):
            allowed.add('last-launch.json')
        require({file.name for file in root.iterdir()} == allowed, 'Isi profil tidak cocok untuk cleanup.')
        for name in sorted(allowed - {'owner'}):
            plain(root / name).unlink()
        plain(root / 'owner').unlink()
        root.rmdir()
        print('Profil demo dihapus.')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, RuntimeError, subprocess.SubprocessError) as error:
        raise SystemExit(f'BLOCKED: {error}') from None
