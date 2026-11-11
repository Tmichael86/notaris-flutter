"""Prepare, launch and inspect offline Windows completion demos."""

import argparse
import csv
import hashlib
import json
import os
from pathlib import Path
import re
import sqlite3
import stat
import subprocess
import tempfile
from contextlib import closing
from datetime import datetime, timezone
from uuid import uuid4

REPO = Path(__file__).resolve().parent.parent
FRONTEND = REPO / 'frontend_notaris'
NUMBER = '1001111260001'
UUID = '8164c13a-b6a4-41f5-8553-fc9ea5d107b0'
DEED = ('Fidusia', '25211', int(datetime(2026, 11, 11, tzinfo=timezone.utc).timestamp()))
EDITED_FIELDS = {'status_transaksi', 'judul_akta', 'nomor_akta', 'tanggal_akta',
                 'updated_at', 'is_sync_dirty'}
PPAT_NUMBER = '2001111260001'
PPAT_UUID = '4c8d9686-de87-481e-962a-e61c56d6e001'
PPAT_TARGET = '4c8d9686-de87-481e-962a-e61c56d6e002'
PPAT_OTHER = '4c8d9686-de87-481e-962a-e61c56d6e003'
PPAT_DEED = ('Akta Jual Beli', '25211', DEED[2])
PPAT_FIELDS = ('status_pekerjaan_ppat', 'judul_akta_ppat', 'nomor_akta_ppat', 'tanggal_akta_ppat')


def require(condition, reason):
    if not condition:
        raise RuntimeError(reason)


def maintenance(schema=21):
    require(os.name == 'nt', 'Windows diperlukan.')
    tasks = subprocess.check_output(
        ['tasklist.exe', '/FI', 'IMAGENAME eq frontend_notaris.exe', '/FO', 'CSV', '/NH'],
        text=True, errors='replace',
    )
    require(not any(row and row[0].lower() == 'frontend_notaris.exe'
                    for row in csv.reader(tasks.splitlines())), 'Tutup Flutter Notaris dahulu.')
    source = (FRONTEND / 'lib/database/app_database.dart').read_text(encoding='utf-8')
    require(re.search(rf'get schemaVersion\s*=>\s*{schema}\s*;', source),
            f'Source Flutter bukan Drift v{schema}.')


def plain(path, directory=False):
    info = path.lstat()
    require(path.resolve(strict=True) == path and
            not getattr(info, 'st_file_attributes', 0) & stat.FILE_ATTRIBUTE_REPARSE_POINT and
            (path.is_dir() if directory else path.is_file() and info.st_nlink == 1),
            f'Path tertaut atau tidak terverifikasi: {path}')
    return path


def quiet_sqlite_file(file):
    plain(file)
    for suffix in ('-wal', '-shm', '-journal'):
        require(not os.path.lexists(str(file) + suffix), f'Journal aktif: {file}{suffix}')
    return file


def read_only(file):
    quiet_sqlite_file(file)
    db = sqlite3.connect(file.as_uri() + '?mode=ro&immutable=1', uri=True)
    db.row_factory = sqlite3.Row
    return db


def original_database_path():
    profile = json.loads((REPO / '.local/notarisdev-profile.json').read_text(encoding='utf-8-sig'))
    generation = profile.get('generation', '')
    require(profile.get('database') == 'notarisdev' and profile.get('port') == 5432 and
            re.fullmatch(r'[a-f0-9]{32}', generation), 'Pointer notarisdev tidak valid.')
    return (Path(os.environ['APPDATA']).resolve(strict=True)
            / 'com.notaris/frontend_notaris/notarisdev' / generation / 'offline.sqlite')


def original_witness():
    file = original_database_path()
    with closing(read_only(file)) as db:
        version = db.execute('PRAGMA user_version').fetchone()[0]
    require(version == 20, 'SQLite development asli bukan v20.')
    return {'path': str(file), 'schema': version,
            'sha256': hashlib.sha256(file.read_bytes()).hexdigest()}


def root_for(id, ppat=False):
    require(re.fullmatch(r'[a-f0-9]{32}', id or ''), 'ID profil demo tidak valid.')
    prefix = 'notaris-ppat' if ppat else 'notaris-completion'
    return Path(tempfile.gettempdir()).resolve(strict=True) / f'{prefix}-{id}'


def owned_root(id, ppat=False):
    root = plain(root_for(id, ppat), directory=True)
    require(plain(root / 'owner').read_text(encoding='ascii').strip() == id,
            'Marker kepemilikan profil tidak cocok.')
    return root


def snapshot(root):
    with closing(read_only(root / 'offline.sqlite')) as db:
        require(db.execute('PRAGMA user_version').fetchone()[0] == 21, 'SQLite demo bukan v21.')
        require([row[0] for row in db.execute('PRAGMA integrity_check')] == ['ok'],
                'SQLite integrity_check gagal.')
        require(db.execute('PRAGMA foreign_key_check').fetchone() is None,
                'SQLite mengandung pelanggaran FK.')
        records = [dict(row) for row in db.execute('SELECT * FROM transaksis ORDER BY id')]
        primary = [row for row in records if row['uuid'] == UUID]
        require(len(records) == 2 and len(primary) == 1 and primary[0]['no_akta'] == NUMBER and
                primary[0]['jenis_transaksi'] == 'notaris' and
                any(row['no_akta'] == '2001111260001' and row['jenis_transaksi'] == 'ppat'
                    for row in records), 'Identitas fixture transaksi berubah.')
        row = primary[0]
        status, deed = row['status_transaksi'], (row['judul_akta'], row['nomor_akta'], row['tanggal_akta'])
        states = {
            ('Dalam Proses', (None, None, None)): 'initial',
            ('Selesai', DEED): 'complete',
            ('Dalam Proses', DEED): 'reopened',
        }
        require((status, deed) in states, 'Status atau data akta di luar langkah acceptance.')
        schema = [tuple(item) for item in db.execute(
            'SELECT type, name, sql FROM sqlite_schema ORDER BY type, name')]
        tables = {}
        for kind, name, _ in schema:
            if kind != 'table':
                continue
            quoted = '"' + name.replace('"', '""') + '"'
            rows = [dict(item) for item in db.execute(f'SELECT * FROM {quoted} ORDER BY rowid')]
            if name == 'transaksis':
                rows = [
                    {key: value for key, value in item.items() if key not in EDITED_FIELDS}
                    if item['uuid'] == UUID else item for item in rows
                ]
            tables[name] = rows
        counts = {name: len(items) for name, items in tables.items()}
        require(all(counts[name] == 0 for name in (
            'transaction_cloud_pending', 'transaction_cloud_feed',
            'transaction_cloud_identity', 'sync_logs',
        )), 'Ada state atau riwayat sinkronisasi pada profil demo.')
        protected = json.dumps([schema, tables], sort_keys=True, separators=(',', ':'))
        return {
            'state': states[(status, deed)], 'status': status, 'nomor_transaksi': NUMBER,
            'judul_akta': deed[0], 'nomor_akta': deed[1],
            'tanggal_akta': '2026-11-11' if deed[2] is not None else None,
            'protected_sha256': hashlib.sha256(protected.encode()).hexdigest(),
            'details': counts['transaksi_details'], 'processes': counts['transaksi_proses'],
            'payments': counts['transaksi_riwayat_pembayaran'],
        }


def ppat_process_state(tables, parent, target):
    processes = [row for row in tables['transaksi_proses']
                 if row['transaksi_detail_uuid'] == target['uuid']]
    require(len(processes) == 1, 'Proses pekerjaan target tidak tunggal.')
    row = processes[0]
    phases = {None: 'initial', 'belum_valid': 'initialized', 'valid': 'valid'}
    steps = {None: [], 'belum_valid': [(None, 'belum_valid')],
             'valid': [(None, 'belum_valid'), ('belum_valid', 'valid')]}
    status = row['status_proses']
    require(status in phases and row['catatan'] is None, 'Status atau catatan proses di luar skenario.')
    history = tables['transaksi_proses_riwayat']
    require([(item['status_sebelumnya'], item['status_baru']) for item in history] == steps[status] and
            all(item['transaksi_proses_id'] == row['id'] and item['actor_user_id'] == 1
                and item['catatan'] is None and item['is_sync_dirty'] == 1
                and item['last_synced_at'] is None for item in history),
            'Histori Validasi Proses di luar skenario.')
    sequence = [item['seq'] for item in tables['sqlite_sequence']
                if item['name'] == 'transaksi_proses_riwayat']
    require(sequence == ([len(history)] if history else []), 'Sequence histori proses berbeda.')
    require((row['validated_by_user_id'], row['validated_at']) ==
            ((1, history[-1]['created_at']) if status == 'valid' else (None, None)),
            'Metadata validasi proses tidak cocok.')
    require(row['updated_at'] == (history[-1]['created_at'] if history else row['created_at']) and
            (not history or parent['updated_at'] == history[-1]['created_at']),
            'Timestamp proses tidak cocok dengan histori.')
    for key in ['status_proses', 'validated_by_user_id', 'validated_at', 'updated_at']:
        row.pop(key)
    parent.pop('updated_at')
    tables['transaksi_proses_riwayat'] = []
    tables['sqlite_sequence'] = [item for item in tables['sqlite_sequence']
                                 if item['name'] != 'transaksi_proses_riwayat']
    return phases[status], status, len(history)


def ppat_snapshot(root, scenario):
    with closing(read_only(root / 'offline.sqlite')) as db:
        require(db.execute('PRAGMA user_version').fetchone()[0] == 22, 'SQLite demo bukan v22.')
        require([row[0] for row in db.execute('PRAGMA integrity_check')] == ['ok'],
                'SQLite integrity_check gagal.')
        require(db.execute('PRAGMA foreign_key_check').fetchone() is None,
                'SQLite mengandung pelanggaran FK.')
        schema = [tuple(row) for row in db.execute(
            'SELECT type, name, sql FROM sqlite_schema ORDER BY type, name')]
        tables = {}
        for kind, name, _ in schema:
            if kind == 'table':
                quoted = '"' + name.replace('"', '""') + '"'
                tables[name] = [dict(row) for row in db.execute(f'SELECT * FROM {quoted} ORDER BY rowid')]
        headers = tables['transaksis']
        require(len(headers) == 1, 'Profil PPAT harus memiliki satu header.')
        parent = headers[0]
        require((parent['uuid'], parent['no_akta'], parent['jenis_transaksi'], parent['status_transaksi']) ==
                (PPAT_UUID, PPAT_NUMBER, 'ppat', 'Dalam Proses'), 'Header PPAT berbeda.')
        details = {row['uuid']: row for row in tables['transaksi_details']}
        require(len(tables['transaksi_details']) == 2 and set(details) == {PPAT_TARGET, PPAT_OTHER}
                and all(row['transaksi_id'] == parent['id'] and row['jenis_pekerjaan'] == 'ppat'
                        for row in details.values()), 'Identitas detail PPAT berbeda.')
        target, other = details[PPAT_TARGET], details[PPAT_OTHER]
        initial = ('dalamProses', None, None, None)
        values = tuple(target[key] for key in PPAT_FIELDS)
        require(tuple(other[key] for key in PPAT_FIELDS) == initial,
                'Status atau akta pekerjaan Balik Nama Sertifikat berubah.')
        if scenario == 'ppat-process':
            require(values == initial, 'Status atau akta pekerjaan berubah pada profil proses.')
            state, process_status, history_count = ppat_process_state(tables, parent, target)
        else:
            states = {initial: 'initial'}
            if scenario == 'ppat-optional':
                states[('selesai', None, None, None)] = 'complete'
            else:
                states[('selesai', *PPAT_DEED)] = 'complete'
                states[('dalamProses', *PPAT_DEED)] = 'reopened'
            require(values in states, 'Status atau akta pekerjaan target di luar langkah acceptance.')
            state, process_status, history_count = states[values], None, 0
            require(not tables['transaksi_proses_riwayat'],
                    'Histori Validasi Proses harus kosong pada acceptance completion.')
            for key in (*PPAT_FIELDS, 'updated_at'):
                target.pop(key)
        require(all(not rows for name, rows in tables.items()
                    if '_sync_' in name or name.startswith('transaction_cloud_') or
                    name in ('sync_logs', 'petugas_identity_map', 'recycle_bin_events')),
                'Ada state sinkronisasi atau recycle bin pada profil demo.')
        protected = json.dumps([schema, tables], sort_keys=True, separators=(',', ':'))
        return {
            'state': state, 'nomor_transaksi': PPAT_NUMBER, 'status_header': parent['status_transaksi'],
            'target': PPAT_TARGET, 'status_pekerjaan': values[0],
            'judul_akta': values[1], 'nomor_akta': values[2],
            'tanggal_akta': '2026-11-11' if values[3] is not None else None,
            'pekerjaan_lain': {'uuid': PPAT_OTHER, 'status': other['status_pekerjaan_ppat']},
            'protected_sha256': hashlib.sha256(protected.encode()).hexdigest(),
            'process_status': process_status, 'process_history': history_count,
            'processes': len(tables['transaksi_proses']),
            'payments': [item['nominal'] for item in tables['transaksi_riwayat_pembayaran']],
        }


def show(root, observed, schema=21):
    print(f'Profile: {root / "offline.sqlite"}')
    print(f'Schema demo v{schema} | integrity ok | FK 0 | Backend OFF | sync state/log 0')
    print(json.dumps(observed, ensure_ascii=False, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('stage', choices=['prepare', 'launch', 'postcheck', 'cleanup'])
    parser.add_argument('--scenario', choices=['notaris', 'ppat', 'ppat-optional', 'ppat-process'],
                        default='notaris')
    parser.add_argument('--id')
    parser.add_argument('--expect', choices=['initial', 'complete', 'reopened', 'initialized', 'valid'])
    args = parser.parse_args()
    ppat = args.scenario != 'notaris'
    schema = 22 if ppat else 21
    module = 'ppat_completion_demo' if ppat else 'notaris_completion_demo'
    env_key = 'NOTARIS_PPAT_PREPARE' if ppat else 'NOTARIS_COMPLETION_PREPARE'
    def inspect(root):
        return ppat_snapshot(root, args.scenario) if ppat else snapshot(root)
    maintenance(schema)
    original = original_witness()
    if args.stage == 'prepare':
        require(args.id is None, 'Prepare selalu membuat ID baru.')
        id = uuid4().hex
        root = root_for(id, ppat)
        root.mkdir()
        (root / 'owner').write_text(id, encoding='ascii')
        subprocess.run(
            ['flutter.bat', 'test', '--no-pub',
             f'test/database/{module}_profile_test.dart'],
            cwd=FRONTEND, env={**os.environ, env_key: id}, check=True,
        )
        observed = inspect(owned_root(id, ppat))
        require(observed['state'] == 'initial' and original_witness() == original,
                'Baseline awal atau SQLite development berubah.')
        (root / 'baseline.json').write_text(json.dumps({
            'id': id, 'scenario': args.scenario, 'original': original,
            'protected_sha256': observed['protected_sha256'],
        }, indent=2), encoding='utf-8')
        show(root, observed, schema)
        print(f'PREPARED id={id} | SQLite development asli v20 sha256={original["sha256"]}')
        return

    root = owned_root(args.id, ppat)
    lock = root / 'launch.lock'
    require(not os.path.lexists(lock), 'Launcher masih aktif atau memerlukan review.')
    receipt = plain(root / 'baseline.json')
    baseline = json.loads(receipt.read_text(encoding='utf-8'))
    require(baseline['id'] == args.id and baseline['original'] == original,
            'Marker atau fingerprint SQLite development berbeda dari baseline.')
    require(baseline.get('scenario', 'notaris') == args.scenario,
            'Skenario berbeda dari baseline profil.')
    observed = inspect(root)
    require(observed['protected_sha256'] == baseline['protected_sha256'],
            'Fingerprint detail, histori, PPAT atau data lain berubah.')
    if args.stage == 'launch':
        with lock.open('x'):
            pass
        try:
            show(root, observed, schema)
            subprocess.run(
                ['flutter.bat', 'run', '-d', 'windows', '--debug', '--no-pub',
                 '-t', f'lib/{module}_main.dart',
                 f'--dart-define=NOTARIS_COMPLETION_DEMO_ID={args.id}'],
                cwd=FRONTEND, check=True,
            )
        finally:
            lock.unlink()
    elif args.stage == 'postcheck':
        require(args.expect is not None and observed['state'] == args.expect,
                'Status SQLite tidak sesuai hasil yang sedang diuji.')
        show(root, observed, schema)
        print(f'POSTCHECK PASS | SQLite development asli v20 sha256={original["sha256"]}')
    else:
        allowed = {'owner', 'offline.sqlite', 'baseline.json'}
        require({item.name for item in root.iterdir()} == allowed,
                'Folder demo memiliki berkas tambahan. Review sebelum cleanup.')
        for name in allowed:
            plain(root / name).unlink()
        root.rmdir()
        print(f'CLEANED disposable profile {root}')


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError, sqlite3.Error, subprocess.CalledProcessError) as error:
        raise SystemExit(f'BLOCKED: {error}') from None
