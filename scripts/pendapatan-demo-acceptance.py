"""Provision and postcheck one isolated, read-only Windows Pendapatan dataset."""

import argparse
from contextlib import closing
from datetime import date, timedelta
from decimal import Decimal, InvalidOperation
import json
import os
from pathlib import Path
import runpy
import sqlite3
import subprocess
import tempfile
import xml.etree.ElementTree as xml
from zipfile import BadZipFile, ZipFile


presentation = runpy.run_path(str(Path(__file__).with_name('presentation-demo.py')))
auth = presentation['auth']
require, plain, read_only, command, digest = (
    auth[key] for key in ('require', 'plain', 'read_only', 'command', 'digest')
)
reader, denied = 'superadmin.demo', 'pembaca.demo'
stages = ('initial', 'report', 'date-filter', 'pagination', 'excel', 'read-only', 'denied', 'final')
name = 'Pendapatan_Data.xlsx'
title = 'Pendapatan Data'
headers = ['No', 'Tanggal', 'Penerimaan Tercatat', 'Pengeluaran Tercatat',
           'Selisih Penerimaan–Pengeluaran']
ns = {'s': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}


def root_for(profile):
    root = presentation['root_for'](profile)
    require(plain(root / 'pendapatan-owner').read_text(encoding='ascii') == profile,
            'Marker profil Pendapatan berbeda.')
    return root


def snapshot(root):
    file = root / 'offline.sqlite'
    with closing(read_only(file)) as db:
        require(db.execute('PRAGMA user_version').fetchone()[0] == 27, 'SQLite harus v27.')
        require([row[0] for row in db.execute('PRAGMA integrity_check')] == ['ok'], 'Integrity SQLite gagal.')
        require(not db.execute('PRAGMA foreign_key_check').fetchall(), 'Pelanggaran FK.')
        tables = ('transaksis', 'transaksi_details', 'transaksi_riwayat_pembayaran',
                  'transaksi_pembayaran_audit', 'pengeluaran', 'materai_movements',
                  'transaction_cloud_identity', 'transaction_cloud_pending')
        counts = {table: db.execute(f'SELECT count(*) FROM {table}').fetchone()[0] for table in tables}
        require(list(counts.values()) == [3, 4, 7, 6, 15, 1, 1, 1], 'Jumlah baris fixture berbeda.')
        cursor = db.execute("SELECT cursor FROM transaction_cloud_feed WHERE scope='pendapatan-demo'").fetchone()
        pending = db.execute("SELECT state FROM transaction_cloud_pending").fetchone()
        require(cursor is not None and cursor[0] == 3 and pending is not None and pending[0] == 'acked',
                'Cursor atau ACK fixture berbeda.')
    return {'schema': 27, 'integrity': 'ok', 'fk': 0, 'counts': counts,
            'transaction_cursor': cursor[0], 'mutation_state': pending[0],
            'sqlite_sha256': digest(file)}


def workbook_check(file):
    plain(file)
    with ZipFile(file) as archive:
        require(sum(item.file_size for item in archive.infolist()) <= 2_000_000,
                'Ukuran workbook di luar fixture.')
        def tree(path):
            return xml.fromstring(archive.read(path))

        sheets = tree('xl/workbook.xml').findall('s:sheets/s:sheet', ns)
        require([sheet.attrib['name'] for sheet in sheets] == [title], 'Worksheet berbeda.')
        paths = [path for path in archive.namelist() if path.startswith('xl/worksheets/sheet')
                 and path.endswith('.xml')]
        require(len(paths) == 1, 'Jumlah file worksheet berbeda.')
        shared = [entry for entry in tree('xl/sharedStrings.xml')] if 'xl/sharedStrings.xml' in archive.namelist() else []
        sheet = tree(paths[0])
        require(not sheet.findall('.//s:f', ns), 'Worksheet berisi formula.')
        rows = sheet.findall('s:sheetData/s:row', ns)
        require(len(rows) == 14, 'Excel harus memuat 13 hari dan satu header.')

        def text(cell):
            if cell.get('t') == 'inlineStr':
                return ''.join(node.text or '' for node in cell.findall('.//s:t', ns))
            value = cell.findtext('s:v', namespaces=ns)
            if cell.get('t') == 's':
                return ''.join(node.text or '' for node in shared[int(value)].findall('.//s:t', ns))
            return value

        def integer(cell):
            require(cell.get('t') in (None, 'n'), 'Nominal Excel bukan sel numerik.')
            value = Decimal(cell.findtext('s:v', namespaces=ns))
            require(value.is_finite() and value.copy_abs() <= 999999999999999 and
                    value == value.to_integral_value(),
                    'Sel Excel harus memiliki nilai bulat yang tepat.')
            return int(value)

        require([text(cell) for cell in rows[0]] == headers, 'Kolom Excel berbeda.')
        totals = [0, 0, 0]
        for i, row in enumerate(rows[1:], 1):
            day = 14 - i
            expected = date(2026, 11, day)
            require(len(row) == 5 and integer(row[0]) == i, 'Nomor atau jumlah kolom berbeda.')
            if row[1].get('t') == 'd':
                actual = date.fromisoformat(row[1].findtext('s:v', namespaces=ns)[:10])
            else:
                actual = date(1899, 12, 30) + timedelta(days=integer(row[1]))
            require(actual == expected, 'Tanggal Excel berbeda.')
            receipt = {1: 20000, 2: 20000, 3: 8000, 13: 30000}.get(day, 0)
            expense = day * 1000 + (2000 if day == 13 else 0)
            expected_values = [receipt, expense, receipt - expense]
            require([integer(cell) for cell in list(row)[2:]] == expected_values,
                    'Nilai harian Excel berbeda.')
            totals = [total + value for total, value in zip(totals, expected_values)]
        require(totals == [78000, 93000, -15000], 'Total Excel berbeda.')
    return {'rows': 13, 'totals': totals, 'sha256': digest(file)}


def verify_grants(root, profile, denied_root, denied_id):
    allowed = presentation['verify_session'](root, profile)
    by_code = {item['sidebar']['sidebar_kode']: item for item in allowed['sidebars']}
    require(all(by_code.get(code, {}).get('read') == 1 for code in
                ('laporan_pendapatan', 'penghasilan', 'pengeluaran')), 'Tiga grant baca tidak lengkap.')
    accounts = json.loads(command([denied_root / 'session.exe', 'verify', denied_id], capture=True))
    missing = next(row for row in accounts if row['username'] == denied)
    require((missing['id'], missing['role'], missing['read'], missing['create'], missing['update'])
            == (103, 'user', 1, 0, 0), 'Sesi penolakan berbeda.')
    require(not any(os.path.lexists(denied_root / f'offline.sqlite{suffix}')
                    for suffix in ('', '-wal', '-shm', '-journal')), 'Bundel penolakan harus khusus autentikasi.')
    return allowed['expiresAt'], missing['expiresAt']


def identity_hashes(root, denied_root):
    def pins(folder, names):
        return {key: digest(plain(folder / key)) for key in names}
    return {
        'reader': pins(root, ('owner', 'presentation-owner', 'pendapatan-owner',
                              'pendapatan-denied-id', 'public.key', 'session.exe',
                              f'{reader}.bin', f'handoff-{reader}.bin')),
        'denied': pins(denied_root, (*auth['AUTH_FILES'], 'monitoring-owner')),
    }


def prepare():
    profile, root, _ = presentation['provision_auth']()
    print(json.dumps({'provisioning': profile, 'root': str(root)}), flush=True)
    with tempfile.TemporaryDirectory(prefix='notaris-pendapatan-auth-') as temp:
        scratch = Path(temp).resolve(strict=True)
        helper = root / 'session.exe'
        denied_id = auth['provision'](scratch, helper, monitoring=True)
        denied_root = auth['owned_root'](denied_id)
        with (denied_root / 'session.exe').open('xb') as dest:
            dest.write(plain(helper).read_bytes())
        prepare_dataset(profile, root, denied_id, denied_root, scratch)


def prepare_dataset(profile, root, denied_id, denied_root, scratch):
    verify_grants(root, profile, denied_root, denied_id)
    for marker, value in [('pendapatan-owner', profile), ('pendapatan-denied-id', denied_id)]:
        with (root / marker).open('x', encoding='ascii') as stream:
            stream.write(value)
    validate_dataset(profile, root, denied_id, denied_root, scratch, create=True)


def validate_dataset(profile, root, denied_id, denied_root, scratch, *, create=False):
    require(root_for(profile) == root and
            plain(root / 'pendapatan-denied-id').read_text(encoding='ascii') == denied_id,
            'Binding profil Pendapatan berbeda.')
    expires = verify_grants(root, profile, denied_root, denied_id)
    validation_xlsx = scratch / 'validated.xlsx'
    command(['flutter.bat', 'test', '--no-pub', 'test/database/pendapatan_demo_profile_test.dart'],
            cwd=auth['FRONTEND'], timeout=240, env={
                **os.environ,
                'NOTARIS_PENDAPATAN_PREPARE': profile if create else '',
                'NOTARIS_PENDAPATAN_VERIFY': '' if create else profile,
                'NOTARIS_PENDAPATAN_VALIDATE_XLSX': str(validation_xlsx),
            })
    workbook = workbook_check(validation_xlsx)
    (root / 'export').mkdir()
    initial = snapshot(root)
    with (root / 'pendapatan-baseline.json').open('x', encoding='utf-8') as stream:
        json.dump({'profile': profile, 'denied_id': denied_id, 'auth': identity_hashes(root, denied_root),
                   'initial': initial, 'automated_workbook': workbook}, stream, indent=2)
    print(json.dumps({'result': 'PASS INITIAL', 'profile': profile, 'root': str(root),
                      'expires': expires, 'automated_workbook': workbook, **initial}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('prepare', 'credential', 'launch', 'postcheck'))
    parser.add_argument('--id')
    parser.add_argument('--stage', choices=stages)
    args = parser.parse_args()
    auth['completion']['maintenance'](24)
    if args.action == 'prepare':
        require(args.id is None and args.stage is None, 'Prepare membuat satu profil data baru.')
        prepare()
        return
    require(args.id and args.stage, 'ID dan tahap diperlukan.')
    root = root_for(args.id)
    with presentation['occupied'](root):
        baseline = json.loads(plain(root / 'pendapatan-baseline.json').read_text(encoding='utf-8'))
        denied_id = plain(root / 'pendapatan-denied-id').read_text(encoding='ascii')
        denied_root = auth['owned_root'](denied_id)
        require(baseline['profile'] == args.id and baseline['denied_id'] == denied_id and
                baseline['auth'] == identity_hashes(root, denied_root), 'Binding profil berbeda.')
        current = snapshot(root)
        require(current == baseline['initial'], 'SQLite berubah dari baseline.')
        stage = args.stage
        folder = plain(root / 'export', directory=True)
        target = folder / name
        after_excel = stages.index(stage) >= stages.index('excel')
        files = list(folder.iterdir())
        require(not files or (after_excel and files == [target]), 'Terdapat output yang tidak diharapkan.')
        if args.action == 'postcheck':
            evidence = {'result': f'PASS {stage.upper()}', 'profile': args.id, **current}
            if after_excel:
                evidence['workbook'] = workbook_check(target)
            if stage in ('read-only', 'denied', 'final'):
                verified = json.loads(plain(root / 'pendapatan-excel-postcheck.json').read_text(encoding='utf-8'))
                require(evidence['workbook'] == verified['workbook'], 'File Excel berubah setelah diverifikasi.')
            checkpoint = root / f'pendapatan-{stage}-postcheck.json'
            if checkpoint.exists():
                require(evidence == json.loads(plain(checkpoint).read_text(encoding='utf-8')),
                        'Bukti tahap sebelumnya berbeda.')
            else:
                with checkpoint.open('x', encoding='utf-8') as stream:
                    json.dump(evidence, stream, indent=2)
            print(json.dumps(evidence))
            return
        require(stage not in ('initial', 'final'), 'Tahap ini memakai postcheck saja.')
        if stage == 'excel':
            require(not files, 'File Excel sudah ada. Tutup Flutter dan jalankan postcheck excel.')
        elif after_excel:
            require(workbook_check(target) == json.loads(
                plain(root / 'pendapatan-excel-postcheck.json').read_text(encoding='utf-8'))['workbook'],
                'File Excel berbeda dari bukti.')
        is_reader = stage != 'denied'
        account_root, account_id = (root, args.id) if is_reader else (denied_root, denied_id)
        helper = auth['trusted_helper_sha'](account_root, presentation=is_reader)
        # Verify the chosen executable before running it or relying on its grants.
        other = denied_root if is_reader else root
        auth['trusted_helper_sha'](other, presentation=not is_reader)
        verify_grants(root, args.id, denied_root, denied_id)
        if args.action == 'credential':
            auth['show_credential'](account_root, account_id, reader if is_reader else denied)
            return
        if stage == 'excel':
            print(f'Simpan Excel pada {target}', flush=True)
        command(['flutter.bat', 'run', '-d', 'windows', '--debug', '--no-pub',
                 '-t', 'lib/pendapatan_demo_main.dart',
                 f'--dart-define=NOTARIS_PENDAPATAN_DEMO_ID={args.id}',
                 f'--dart-define=NOTARIS_PENDAPATAN_AUTH_ID={account_id}',
                 f'--dart-define=NOTARIS_PENDAPATAN_HELPER_SHA256={helper}'],
                cwd=auth['FRONTEND'], timeout=None)
        require(snapshot(root) == current, 'SQLite berubah selama Flutter berjalan.')


if __name__ == '__main__':
    try:
        main()
    except (OSError, RuntimeError, ValueError, KeyError, StopIteration, sqlite3.Error,
            subprocess.SubprocessError, BadZipFile, xml.ParseError, InvalidOperation) as error:
        raise SystemExit(f'BLOCKED: {error}') from None
