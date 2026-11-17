"""Provision the isolated Windows test for Transaksi Materai stock-out."""
import argparse
from contextlib import closing
from datetime import datetime
from hashlib import sha256
import json
import os
from pathlib import Path
import re
import runpy
import sqlite3
import subprocess
import tempfile

base = runpy.run_path(str(Path(__file__).with_name('materai-stock-demo-acceptance.py')))
auth, presentation = base['auth'], base['presentation']
require, plain, read_only, command, digest, fingerprint = (
    base[k] for k in ('require', 'plain', 'read_only', 'command', 'digest', 'fingerprint')
)
stages = {
    'notaris': ('admin.demo', True, 0, 1),
    'restart': ('admin.demo', False, 1, 1),
    'ppat': ('admin.demo', True, 1, 2),
    'insufficient': ('admin.demo', True, 2, 2),
    'read': ('pembaca.demo', False, 2, 2),
    'denied': ('petugas.demo', False, 2, 2),
}
guards = {'initial': 0, 'final': 2, **{name: stage[3] for name, stage in stages.items()}}
changing = {'transaksis', 'transaksi_details', 'transaksi_proses',
            'transaksi_riwayat_pembayaran', 'materai_movements'}


def owned(profile):
    root = auth['owned_root'](profile)
    require(plain(root / 'materai-usage-owner').read_text(encoding='ascii') == profile,
            'Marker bukan profil stock-out disposable.')
    return root


def session_hashes(root):
    return {name: digest(plain(root / name)) for name in (*auth['AUTH_FILES'], 'materai-usage-owner')}


def grants(root, profile):
    verified = json.loads(command([root / 'session.exe', 'verify', profile], capture=True))
    actual = {row['username']: (row['id'], row['read'], row['create'], row['update'], row['materai'])
              for row in verified}
    require(actual == {'admin.demo': (102, 1, 1, 1, [1, 0, 0, 0]),
                       'pembaca.demo': (103, 1, 0, 0, [1, 0, 0, 0]),
                       'petugas.demo': (101, 1, 0, 0, [0, 0, 0, 0])}, 'Grant Materai/Transaksi berbeda.')
    return {row['username']: row['expiresAt'] for row in verified}


def snapshot(root):
    file = root / 'offline.sqlite'
    with closing(read_only(file)) as db:
        require(db.execute('PRAGMA user_version').fetchone()[0] == 27, 'SQLite harus v27.')
        require([r[0] for r in db.execute('PRAGMA integrity_check')] == ['ok'], 'SQLite integrity_check gagal.')
        require(not db.execute('PRAGMA foreign_key_check').fetchall(), 'Pelanggaran FK.')
        objects = [list(r) for r in db.execute(
            'SELECT type,name,tbl_name,sql FROM sqlite_master ORDER BY type,name')]
        protected = {}
        for kind, table, _, _ in objects:
            if kind == 'table' and table not in changing and table != 'sqlite_sequence':
                quoted = '"' + table.replace('"', '""') + '"'
                protected[table] = sorted(fingerprint(list(row)) for row in db.execute(f'SELECT * FROM {quoted}'))
        seq = {row['name']: row['seq'] for row in db.execute('SELECT * FROM sqlite_sequence')}
        data = {table: [dict(row) for row in db.execute(f'SELECT * FROM {table} ORDER BY id')]
                for table in sorted(changing)}
    return {'sqlite': digest(file), 'protected': fingerprint([objects, protected]), 'seq': seq, 'data': data}


def check(current, baseline, count):
    old, data = baseline['data'], current['data']
    require(current['protected'] == baseline['protected'], 'Tabel terlindungi atau skema berubah.')
    for table in changing:
        require(data[table][:len(old[table])] == old[table], f'Histori berubah pada {table}.')
    added = {table: data[table][len(old[table]):] for table in changing}
    jobs = [0, 1, 3][count]
    require([len(added[t]) for t in ('transaksis','materai_movements','transaksi_details',
            'transaksi_proses','transaksi_riwayat_pembayaran')]
            == [count, count, jobs, jobs, count], 'Jumlah header, mutasi, detail, proses, atau pembayaran berbeda.')
    seq = dict(baseline['seq'])
    for table in ('transaksis', 'transaksi_details', 'transaksi_proses', 'transaksi_riwayat_pembayaran'):
        if added[table]:
            seq[table] = added[table][-1]['id']
    require(current['seq'] == seq, 'Sequence SQLite di luar perubahan yang diizinkan.')
    if count == 0:
        require(current['sqlite'] == baseline['sqlite'], 'SQLite awal berubah.')
    movements = []
    for i, (tx, move) in enumerate(zip(added['transaksis'], added['materai_movements'])):
        domain, quantity, stock, paid = [('notaris', 3, 17, 20000), ('ppat', 4, 13, 30000)][i]
        names = [('Materai Uji Notaris',), ('Materai Uji PPAT A', 'Materai Uji PPAT B')][i]
        day = datetime.fromtimestamp(tx['tanggal_transaksi'])
        number = f"{i+1}00{day:%d%m%y}{i+1:04}"
        require(tx['jenis_transaksi'] == domain and tx['jumlah_materai'] == quantity and
                tx['no_akta'] == number and tx['status_transaksi'] == 'Baru' and
                tx['total'] == len(names)*100000 and tx['pembayaran_sekarang'] == paid and
                tx['pemohon_id'] == 1 and tx['pemohon_uuid'] == 'applicant' and tx['petugas_id'] == 100 and
                tx['petugas_uuid'] == 'e0c928a2-c304-437e-8bf5-7a81bd5e0eae' and
                tx['deleted_at'] is None and tx['is_sync_dirty'] == 1 and tx['last_synced_at'] is None,
                'Header transaksi tidak cocok dengan skenario.')
        details = [row for row in added['transaksi_details'] if row['transaksi_id'] == tx['id']]
        require(sorted(row['nama_pekerjaan_snapshot'] for row in details) == list(names) and
                all(row['jenis_pekerjaan'] == domain and row['total_snapshot'] == 100000 and
                    row['deleted_at'] is None and row['status'] == 1 for row in details),
                'Detail pekerjaan berbeda.')
        processes = [row for row in added['transaksi_proses'] if row['transaksi_id'] == tx['id']]
        require(sorted(row['transaksi_detail_uuid'] for row in processes) == sorted(row['uuid'] for row in details) and
                all(row['nama_proses_snapshot'] == 'Periksa berkas' and row['status_proses'] is None and
                    row['deleted_at'] is None for row in processes), 'Snapshot proses berbeda.')
        history = [row for row in added['transaksi_riwayat_pembayaran'] if row['transaksi_id'] == tx['id']]
        require(len(history) == 1 and history[0]['nominal_rupiah'] == paid and history[0]['nominal'] == paid and
                history[0]['urutan_pembayaran'] == 1 and history[0]['status'] == 1 and
                history[0]['deleted_at'] is None and history[0]['tanggal_pembayaran'] == tx['tanggal_transaksi'],
                'Pembayaran awal berbeda.')
        uuid = tx['uuid']
        require(re.fullmatch('[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}', uuid),
                'UUID transaksi tidak sah.')
        namespace = f"local:materai:{baseline['profile']}:transaction:{uuid}"
        date = day.date().isoformat()
        require((move['source_namespace'], move['source_id'], move['business_date'], move['stock_in'],
                 move['stock_out'], move['recorded_stock'], move['source_status'], move['review_reason'],
                 move['source_officer_id'], move['officer_snapshot']) ==
                (namespace, 1, date, 0, quantity, stock, 1, None, 100, 'Rani Wulandari'),
                'Mutasi stok berbeda.')
        proof = json.loads(move['provenance_json'])
        previous = data['materai_movements'][i]
        expected = {'kind': 'transaction_stock_out', 'profile': baseline['profile'], 'transaction_uuid': uuid,
                    'transaction_id': tx['id'], 'domain': domain, 'previous': previous['id'], 'date': date,
                    'recorded_ms': move['source_created_ms'], 'quantity': quantity, 'stock': stock,
                    'description': f'Pemakaian {domain.upper()} · {number}', 'user_id': 102, 'group_id': 102,
                    'officer_id': 100, 'officer_uuid': tx['petugas_uuid'], 'officer': 'Rani Wulandari'}
        require(all(proof.get(k) == v for k,v in expected.items()) and
                move['description'] == expected['description'] and
                re.fullmatch('[0-9a-f]{64}', proof.get('request_sha256', '')) and
                sha256(move['provenance_json'].encode()).hexdigest() == move['payload_sha256'] and
                previous['source_created_ms'] < move['source_created_ms'] and
                baseline['prepared_ms'] <= move['source_created_ms'] <= int(datetime.now().timestamp()*1000) and
                datetime.fromisoformat(proof['actor_verified_at']).timestamp()*1000 <= move['source_created_ms'],
                'Rantai atau provenance stok tidak cocok.')
        movements.append({'number': number, 'uuid': uuid, 'usage': quantity, 'stock': stock, 'identity': namespace})
    require(len({m['uuid'] for m in movements}) == count, 'Mutasi ganda.')
    return movements


def prepare():
    with tempfile.TemporaryDirectory(prefix='notaris-materai-usage-auth-') as name:
        scratch = Path(name).resolve(strict=True)
        helper = scratch / 'session.exe'
        auth['build_helper'](helper)
        profile = auth['provision'](scratch, helper, materai_usage=True)
        root = owned(profile)
        with (root / 'session.exe').open('xb') as dest:
            dest.write(plain(helper).read_bytes())
    expiry = grants(root, profile)
    command(['flutter.bat', 'test', '--no-pub', 'test/database/materai_usage_demo_profile_test.dart'],
            cwd=auth['FRONTEND'], env={**os.environ, 'NOTARIS_MATERAI_USAGE_PREPARE': profile}, timeout=240)
    baseline = snapshot(root)
    require([row['recorded_stock'] for row in baseline['data']['materai_movements']] == [20] and
            len(baseline['data']['transaksis']) == 16, 'Fixture berbeda.')
    baseline.update(auth=session_hashes(root), profile=profile, prepared_ms=int(datetime.now().timestamp()*1000))
    with (root / 'materai-usage-baseline.json').open('x', encoding='utf-8') as f:
        json.dump(baseline, f, indent=2)
    print(json.dumps({'result': 'PASS INITIAL', 'profile': profile, 'root': str(root), 'expiry': expiry,
                      'stock': 20, 'schema': 27, 'integrity': 'ok', 'fk': 0,
                      'protected_sha256': baseline['protected'], 'sqlite_sha256': baseline['sqlite']}))


def checkpoint(root, stage, current, movements):
    output = {'result': 'PASS ' + stage.upper(), 'movements': movements, 'sqlite_sha256': current['sqlite'],
              'protected_sha256': current['protected'], 'integrity': 'ok', 'fk': 0}
    # Persist the prior successful state so later stages prove immutability.
    if stage in ('notaris', 'ppat'):
        path = root / f'materai-checkpoint-{stage}.json'
        state = {'sqlite': current['sqlite'], 'related': current['data']}
        if path.exists():
            require(json.loads(plain(path).read_text(encoding='utf-8')) == state, 'Checkpoint sebelumnya berubah.')
        else:
            with path.open('x', encoding='utf-8') as f:
                json.dump(state, f)
    print(json.dumps(output))


def preserve_previous(root, current, count, same):
    if count == 0:
        return
    name = 'notaris' if count == 1 else 'ppat'
    previous = json.loads(plain(root / f'materai-checkpoint-{name}.json').read_text(encoding='utf-8'))
    require(all(current['data'][t][:len(rows)] == rows for t, rows in previous['related'].items()),
            'Hasil transaksi tahap sebelumnya berubah.')
    if same:
        require(current['sqlite'] == previous['sqlite'], 'SQLite berubah pada tahap tanpa penulisan.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('prepare', 'credential', 'launch', 'postcheck'))
    parser.add_argument('--id')
    parser.add_argument('--stage', choices=guards)
    args = parser.parse_args()
    auth['completion']['maintenance'](24)
    if args.action == 'prepare':
        require(args.id is None and args.stage is None, 'Prepare membuat satu profil baru.')
        prepare()
        return
    require(args.id and args.stage, 'ID dan tahap diperlukan.')
    root = owned(args.id)
    with presentation['occupied'](root):
        baseline = json.loads(plain(root / 'materai-usage-baseline.json').read_text(encoding='utf-8'))
        require(baseline['profile'] == args.id and baseline['auth'] == session_hashes(root), 'Binding autentikasi berbeda.')
        current = snapshot(root)
        if args.action == 'postcheck':
            count = guards[args.stage]
            movements = check(current, baseline, count)
            if args.stage not in ('initial', 'notaris'):
                preserve_previous(root, current, 1 if args.stage in ('restart', 'ppat') else 2, args.stage != 'ppat')
            checkpoint(root, args.stage, current, movements)
            return
        require(args.stage in stages, 'Pilih tahap Flutter.')
        account, writable, before, _ = stages[args.stage]
        check(current, baseline, before)
        preserve_previous(root, current, before, True)
        helper = auth['trusted_helper_sha'](root, presentation=True)
        grants(root, args.id)
        if args.action == 'credential':
            auth['show_credential'](root, args.id, account)
            return
        command(['flutter.bat', 'run', '-d', 'windows', '--debug', '--no-pub', '-t', 'lib/materai_stock_demo_main.dart',
                 f'--dart-define=NOTARIS_MATERAI_STOCK_ID={args.id}',
                 f'--dart-define=NOTARIS_MATERAI_STOCK_ACCOUNT={account}',
                 f'--dart-define=NOTARIS_MATERAI_STOCK_HELPER_SHA={helper}',
                 f'--dart-define=NOTARIS_MATERAI_STOCK_OPENING_SHA={baseline["data"]["materai_movements"][0]["payload_sha256"]}',
                 f'--dart-define=NOTARIS_MATERAI_STOCK_WRITE={str(writable).lower()}',
                 '--dart-define=NOTARIS_MATERAI_TRANSACTION_USAGE=true'],
                cwd=auth['FRONTEND'], timeout=None)
        if not writable or args.stage == 'insufficient':
            require(snapshot(root) == current, 'SQLite berubah pada tahap tanpa penulisan.')


if __name__ == '__main__':
    try:
        main()
    except (OSError, RuntimeError, ValueError, KeyError, sqlite3.Error, subprocess.SubprocessError) as error:
        raise SystemExit(f'BLOCKED: {error}') from None
