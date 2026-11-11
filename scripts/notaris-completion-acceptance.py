"""Prepare, launch and inspect the offline Windows Notaris completion demo."""

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


def require(condition, reason):
    if not condition:
        raise RuntimeError(reason)


def maintenance():
    require(os.name == 'nt', 'Windows diperlukan.')
    tasks = subprocess.check_output(
        ['tasklist.exe', '/FI', 'IMAGENAME eq frontend_notaris.exe', '/FO', 'CSV', '/NH'],
        text=True, errors='replace',
    )
    require(not any(row and row[0].lower() == 'frontend_notaris.exe'
                    for row in csv.reader(tasks.splitlines())), 'Tutup Flutter Notaris dahulu.')
    source = (FRONTEND / 'lib/database/app_database.dart').read_text(encoding='utf-8')
    require(re.search(r'get schemaVersion\s*=>\s*21\s*;', source),
            'Source Flutter bukan Drift v21.')


def plain(path, directory=False):
    info = path.lstat()
    require(path.resolve(strict=True) == path and
            not getattr(info, 'st_file_attributes', 0) & stat.FILE_ATTRIBUTE_REPARSE_POINT and
            (path.is_dir() if directory else path.is_file() and info.st_nlink == 1),
            f'Path tertaut atau tidak terverifikasi: {path}')
    return path


def read_only(file):
    plain(file)
    for suffix in ('-wal', '-shm', '-journal'):
        require(not os.path.lexists(str(file) + suffix), f'Journal aktif: {file}{suffix}')
    db = sqlite3.connect(file.as_uri() + '?mode=ro&immutable=1', uri=True)
    db.row_factory = sqlite3.Row
    return db


def original_witness():
    profile = json.loads((REPO / '.local/notarisdev-profile.json').read_text(encoding='utf-8-sig'))
    generation = profile.get('generation', '')
    require(profile.get('database') == 'notarisdev' and profile.get('port') == 5432 and
            re.fullmatch(r'[a-f0-9]{32}', generation), 'Pointer notarisdev tidak valid.')
    file = (Path(os.environ['APPDATA']).resolve(strict=True)
            / 'com.notaris/frontend_notaris/notarisdev' / generation / 'offline.sqlite')
    with closing(read_only(file)) as db:
        version = db.execute('PRAGMA user_version').fetchone()[0]
    require(version == 20, 'SQLite development asli bukan v20.')
    return {'path': str(file), 'schema': version,
            'sha256': hashlib.sha256(file.read_bytes()).hexdigest()}


def root_for(id):
    require(re.fullmatch(r'[a-f0-9]{32}', id or ''), 'ID profil demo tidak valid.')
    return Path(tempfile.gettempdir()).resolve(strict=True) / f'notaris-completion-{id}'


def owned_root(id):
    root = plain(root_for(id), directory=True)
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


def show(root, observed):
    print(f'Profile: {root / "offline.sqlite"}')
    print('Schema demo v21 | integrity ok | FK 0 | Backend OFF | sync state/log 0')
    print(json.dumps(observed, ensure_ascii=False, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('stage', choices=['prepare', 'launch', 'postcheck', 'cleanup'])
    parser.add_argument('--id')
    parser.add_argument('--expect', choices=['initial', 'complete', 'reopened'])
    args = parser.parse_args()
    maintenance()
    original = original_witness()
    if args.stage == 'prepare':
        require(args.id is None, 'Prepare selalu membuat ID baru.')
        id = uuid4().hex
        root = root_for(id)
        root.mkdir()
        (root / 'owner').write_text(id, encoding='ascii')
        subprocess.run(
            ['flutter.bat', 'test', '--no-pub',
             'test/database/notaris_completion_demo_profile_test.dart'],
            cwd=FRONTEND, env={**os.environ, 'NOTARIS_COMPLETION_PREPARE': id}, check=True,
        )
        observed = snapshot(owned_root(id))
        require(observed['state'] == 'initial' and original_witness() == original,
                'Baseline awal atau SQLite development berubah.')
        (root / 'baseline.json').write_text(json.dumps({
            'id': id, 'original': original, 'protected_sha256': observed['protected_sha256'],
        }, indent=2), encoding='utf-8')
        show(root, observed)
        print(f'PREPARED id={id} | SQLite development asli v20 sha256={original["sha256"]}')
        return

    root = owned_root(args.id)
    lock = root / 'launch.lock'
    require(not os.path.lexists(lock), 'Launcher masih aktif atau memerlukan review.')
    receipt = plain(root / 'baseline.json')
    baseline = json.loads(receipt.read_text(encoding='utf-8'))
    require(baseline['id'] == args.id and baseline['original'] == original,
            'Marker atau fingerprint SQLite development berbeda dari baseline.')
    observed = snapshot(root)
    require(observed['protected_sha256'] == baseline['protected_sha256'],
            'Fingerprint detail, histori, PPAT atau data lain berubah.')
    if args.stage == 'launch':
        with lock.open('x'):
            pass
        try:
            show(root, observed)
            subprocess.run(
                ['flutter.bat', 'run', '-d', 'windows', '--debug', '--no-pub',
                 '-t', 'lib/notaris_completion_demo_main.dart',
                 f'--dart-define=NOTARIS_COMPLETION_DEMO_ID={args.id}'],
                cwd=FRONTEND, check=True,
            )
        finally:
            lock.unlink()
    elif args.stage == 'postcheck':
        require(args.expect is not None and observed['state'] == args.expect,
                'Status SQLite tidak sesuai hasil yang sedang diuji.')
        show(root, observed)
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
