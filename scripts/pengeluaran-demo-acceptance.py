"""Prepare and verify a disposable Windows Pengeluaran CRUD acceptance."""

import argparse
from contextlib import closing
from datetime import datetime, timezone
import hashlib
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
accounts = {'petugas.demo': [1, 1, 1, 1], 'pembaca.demo': [1, 0, 0, 0],
            'admin.demo': [0, 0, 0, 0]}
stages = ('initial', 'create', 'edit', 'restart', 'delete', 'reader', 'denied')
reference = 'PT-ACCEPT-01'


def schema_version():
    source = (auth['FRONTEND'] / 'lib/database/app_database.dart').read_text(encoding='utf-8')
    match = re.search(r'get schemaVersion\s*=>\s*(\d+)\s*;', source)
    require(match, 'Versi Drift utama tidak ditemukan.')
    return int(match[1])


def fingerprint(rows):
    values = sorted(json.dumps(tuple(row), ensure_ascii=True,
                               default=lambda value: {'blob': value.hex()}) for row in rows)
    return hashlib.sha256(json.dumps(values).encode()).hexdigest()


def snapshot(root):
    with closing(read_only(root / 'offline.sqlite')) as db:
        version = db.execute('PRAGMA user_version').fetchone()[0]
        require(version == schema_version(), 'Versi SQLite berbeda dari source Drift.')
        require([r[0] for r in db.execute('PRAGMA integrity_check')] == ['ok'],
                'SQLite integrity_check gagal.')
        require(not db.execute('PRAGMA foreign_key_check').fetchall(), 'Pelanggaran FK.')
        schema = db.execute('SELECT type,name,tbl_name,sql FROM sqlite_schema').fetchall()
        protected = {'schema': fingerprint(schema)}
        for kind, name, _, _ in schema:
            if kind == 'table' and name not in ('pengeluaran', 'sqlite_sequence'):
                require(re.fullmatch(r'[a-zA-Z0-9_]+', name), 'Nama tabel tidak sah.')
                protected[name] = fingerprint(db.execute(f'SELECT * FROM "{name}"'))
        protected['sqlite_sequence'] = fingerprint(db.execute(
            "SELECT * FROM sqlite_sequence WHERE name != 'pengeluaran'"))
        sequence = db.execute("SELECT seq FROM sqlite_sequence WHERE name='pengeluaran'").fetchone()
        require(sequence is not None, 'Sequence Pengeluaran tidak tersedia.')
        return {'schema': version, 'integrity': 'ok', 'fk': 0,
                'protected': protected, 'sequence': sequence[0],
                'jenis': dict(db.execute('SELECT nama,id FROM pengeluaran_jenis '
                                          'WHERE status=1 AND deleted_at IS NULL')),
                'expenses': [dict(r) for r in db.execute('SELECT * FROM pengeluaran ORDER BY id')]}


def calendar(day):
    return int(datetime(2026, 11, day, tzinfo=timezone.utc).timestamp())


def verify_stage(state, initial, stage, created=None, edited=None):
    for key in ('schema', 'integrity', 'fk', 'protected', 'jenis'):
        require(state[key] == initial[key], f'Baseline terlindungi berubah: {key}.')
    old, rows = initial['expenses'], state['expenses']
    if stage == 'initial':
        require(rows == old and state['sequence'] == initial['sequence'], 'Fixture awal berubah.')
        return None
    require(len(rows) == len(old) + 1 and rows[:-1] == old and
            state['sequence'] == initial['sequence'] + 1, 'Perubahan di luar satu record pilot.')
    row = rows[-1]
    require(re.fullmatch(r'[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}', row['uuid']) and
            row['id'] == state['sequence'] and row['no_faktur'] == reference,
            'Identitas atau faktur record pilot berbeda.')
    if created is not None:
        require(all(row[k] == created[k] for k in ('id', 'uuid', 'created_at')),
                'PK, UUID, atau timestamp pembuatan berubah.')
        require(row['updated_at'] >= created['updated_at'], 'Waktu update mundur.')
    first = stage == 'create'
    deleted = stage in ('delete', 'reader', 'denied')
    kind = 'ATK' if first else 'Transport'
    expected = (calendar(14 if first else 15), 15000 if first else 20000,
                initial['jenis'][kind], kind,
                'Berkas kantor sintetis' if first else 'Kurir kantor sintetis')
    require(tuple(row[k] for k in ('tanggal', 'nominal', 'jenis_id', 'jenis_nama', 'keterangan')) ==
            expected, 'Tanggal, nominal, jenis, atau keterangan pilot berbeda.')
    require(row['created_at'] > 0 and row['updated_at'] >= row['created_at'] and
            (row['deleted_at'] is not None) == deleted, 'Timestamp atau soft delete tidak sesuai.')
    if deleted:
        require(row['deleted_at'] == row['updated_at'] and row['deleted_at'] >= edited['updated_at'] and
                all(row[k] == edited[k] for k in row if k not in ('updated_at', 'deleted_at')),
                'Soft delete mengubah data historis.')
    elif stage == 'restart':
        require(row == edited, 'Record berubah setelah restart.')
    return row


def session_files(root):
    return {name: digest(root / name) for name in [*auth['AUTH_FILES'], 'pengeluaran-owner']}


def verify_accounts(root, profile):
    rows = json.loads(command([root / 'session.exe', 'verify-db', profile], capture=True))
    identities = {name: value[:2] for name, value in auth['ACCOUNTS'].items()}
    require(len(rows) == len(accounts) and
            {r['username']: (r['id'], r['role']) for r in rows} == identities and
            {r['username']: r.get('pengeluaran') for r in rows} == accounts and
            all((r['read'], r['create'], r['update']) == (1, 0, 0) for r in rows),
            'Izin sesi Pengeluaran atau Transaksi berbeda.')
    return rows


def write_new(path, value):
    with path.open('x', encoding='utf-8') as file:
        json.dump(value, file, indent=2)


def prepare():
    require(not auth['port_open'](), 'Port PostgreSQL disposable 55674 sudah dipakai.')
    scratch = Path(tempfile.mkdtemp(prefix='notaris-pengeluaran-auth-')).resolve(strict=True)
    helper = scratch / 'session.exe'
    auth['build_helper'](helper)
    profile = auth['provision'](scratch, helper, pengeluaran=True)
    root = auth['owned_root'](profile)
    with (root / 'session.exe').open('xb') as file:
        file.write(plain(helper).read_bytes())
    command(['flutter.bat', 'test', '--no-pub', 'test/database/pengeluaran_demo_profile_test.dart'],
            cwd=auth['FRONTEND'], env={**os.environ, 'NOTARIS_PENGELUARAN_PREPARE': profile},
            timeout=240)
    users = verify_accounts(root, profile)
    state = snapshot(root)
    require(len(state['expenses']) == 12 and state['sequence'] == 12 and
            all(r['nominal'] == 10000 and r['deleted_at'] is None for r in state['expenses']) and
            set(state['jenis']) == {'ATK', 'Transport'}, 'Fixture awal tidak sesuai.')
    write_new(root / 'baseline.json', {'id': profile, 'auth': session_files(root), 'initial': state})
    print(json.dumps({'result': 'PASS INITIAL', 'profile': profile, 'root': str(root),
                      'accounts': users, 'schema': state['schema'], 'integrity': 'ok', 'fk': 0,
                      'protected_count': len(state['protected']),
                      'active_count': 12, 'active_total': 120000}, indent=2))


def postcheck(root, state, initial, stage):
    index = stages.index(stage)
    current = root / f'passed-{stage}.json'
    previous = None
    if index:
        previous = json.loads(plain(root / f'passed-{stages[index - 1]}.json').read_text())
    created = previous['created'] if previous else None
    edited = previous['edited'] if previous else None
    row = verify_stage(state, initial, stage, created, edited)
    launch_id = None
    if index:
        # Launch evidence is written only after Flutter closes successfully.
        latest = max((plain(path) for path in root.glob('launch-*.json')), default=None)
        require(latest is not None, 'Bukti penutupan Flutter belum tersedia.')
        launch = json.loads(latest.read_text(encoding='utf-8'))
        launch_id = latest.name
        require(launch['after'] == state and launch['before'] == previous['state'] and
                launch_id != previous['launch'], 'Diperlukan satu sesi Flutter baru untuk fase ini.')
        if stage in ('restart', 'reader', 'denied'):
            require(state == previous['state'], 'Data berubah pada fase baca-saja.')
    record = {'state': state, 'launch': launch_id,
              'created': row if stage == 'create' else created,
              'edited': row if stage == 'edit' else edited}
    if not os.path.lexists(current):
        write_new(current, record)
    else:
        require(json.loads(plain(current).read_text(encoding='utf-8')) == record,
                'Bukti fase yang sudah dicatat berbeda.')
    active = [r for r in state['expenses'] if r['deleted_at'] is None]
    print(json.dumps({'result': f'PASS {stage.upper()}', 'integrity': 'ok', 'fk': 0,
                      'active_count': len(active), 'active_total': sum(r['nominal'] for r in active),
                      'protected_count': len(state['protected']), 'uuid': row['uuid'] if row else None},
                     indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('prepare', 'credential', 'launch', 'postcheck'))
    parser.add_argument('--id')
    parser.add_argument('--account', choices=accounts)
    parser.add_argument('--expect', choices=stages)
    args = parser.parse_args()
    auth['completion']['maintenance'](schema_version())
    if args.action == 'prepare':
        require(args.id is None and args.account is None and args.expect is None,
                'Prepare selalu membuat profil baru.')
        prepare()
        return
    require(args.id, 'ID profil diperlukan.')
    root = auth['owned_root'](args.id)
    require(plain(root / 'pengeluaran-owner').read_text(encoding='ascii') == args.id,
            'Marker Pengeluaran berbeda.')
    lock = root / 'launch.lock'
    require(not os.path.lexists(lock), 'Tutup Flutter atau tinjau lock.')
    baseline = json.loads(plain(root / 'baseline.json').read_text(encoding='utf-8'))
    require(baseline['id'] == args.id and baseline['auth'] == session_files(root),
            'Baseline autentikasi berbeda.')
    state = snapshot(root)
    initial = baseline['initial']
    require(state['protected'] == initial['protected'], 'Fingerprint data terlindungi berubah.')
    if args.action == 'postcheck':
        require(args.expect, 'Fase postcheck diperlukan.')
        postcheck(root, state, initial, args.expect)
        return
    helper_sha = auth['trusted_helper_sha'](root)
    verify_accounts(root, args.id)
    if args.action == 'credential':
        require(args.account, 'Akun diperlukan.')
        auth['show_credential'](root, args.id, args.account)
        return
    checkpoints = [root / f'passed-{stage}.json' for stage in stages]
    previous = next((path for path in reversed(checkpoints) if os.path.lexists(path)), None)
    require(previous is not None and
            json.loads(plain(previous).read_text(encoding='utf-8'))['state'] == state,
            'Jalankan postcheck fase sebelumnya sebelum membuka Flutter.')
    with lock.open('x', encoding='ascii') as file:
        file.write(args.id)
    try:
        command(['flutter.bat', 'run', '-d', 'windows', '--debug', '--no-pub',
                 '-t', 'lib/pengeluaran_demo_main.dart',
                 f'--dart-define=NOTARIS_PENGELUARAN_DEMO_ID={args.id}',
                 f'--dart-define=NOTARIS_PENGELUARAN_HELPER_SHA256={helper_sha}'],
                cwd=auth['FRONTEND'], timeout=None)
        after = snapshot(root)
        require(after['protected'] == initial['protected'], 'Fingerprint data terlindungi berubah.')
        stamp = datetime.now(timezone.utc).strftime('%Y%m%d%H%M%S%f')
        write_new(root / f'launch-{stamp}-{uuid4().hex}.json', {'before': state, 'after': after})
    finally:
        lock.unlink()


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, RuntimeError, sqlite3.Error, subprocess.SubprocessError) as error:
        raise SystemExit(f'BLOCKED: {error}') from None
