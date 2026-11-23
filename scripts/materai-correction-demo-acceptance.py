"""Provision and verify an isolated Materai transaction correction scenario."""
import argparse
from datetime import datetime
import json
import os
from pathlib import Path
import re
import runpy
import sqlite3
import subprocess
import tempfile
from uuid import UUID

usage = runpy.run_path(str(Path(__file__).with_name('materai-usage-demo-acceptance.py')))
auth, presentation = usage['auth'], usage['presentation']
require, plain, command, fingerprint, snapshot = (
    usage[key] for key in ('require', 'plain', 'command', 'fingerprint', 'snapshot')
)
stages = ('initial', 'notaris', 'ppat', 'notaris-return', 'notaris-increase',
          'ppat-return', 'insufficient', 'zero-delta', 'restart', 'read', 'denied', 'final')
corrections = ((0, 3, 1, 15), (0, 1, 4, 12), (1, 4, 2, 14))
note = 'Catatan uji koreksi Materai'
read_only_stages = ('restart', 'read', 'denied')
unchanged_stages = ('insufficient', *read_only_stages, 'final')


def marker(root):
    return root / 'materai-correction-owner'


def session_hashes(root):
    return {**usage['session_hashes'](root), marker(root).name: usage['digest'](plain(marker(root)))}


def state_file(root, stage):
    return root / f'materai-correction-{stage}.json'


def read_state(root, stage):
    return json.loads(plain(state_file(root, stage)).read_text(encoding='utf-8'))


def output(stage, state):
    moves = state['data']['materai_movements']
    print(json.dumps({'result': f'PASS {stage.upper()}', 'schema': 27, 'integrity': 'ok',
                      'fk': 0, 'stock': moves[-1]['recorded_stock'], 'movements': len(moves),
                      'protected_sha256': state['protected'], 'sqlite_sha256': state['sqlite']}))


def record(root, stage, state):
    path = state_file(root, stage)
    if path.exists():
        require(read_state(root, stage) == state, 'Checkpoint sebelumnya berbeda.')
    else:
        with path.open('x', encoding='utf-8') as stream:
            json.dump(state, stream)
    output(stage, state)


def prepare():
    with tempfile.TemporaryDirectory(prefix='notaris-materai-correction-auth-') as name:
        scratch = Path(name).resolve(strict=True)
        helper = scratch / 'session.exe'
        auth['build_helper'](helper)
        profile = auth['provision'](scratch, helper, materai_usage=True)
        root = usage['owned'](profile)
        with marker(root).open('x', encoding='ascii') as stream:
            stream.write(profile)
        with (root / 'session.exe').open('xb') as dest:
            dest.write(plain(helper).read_bytes())
    expiry = usage['grants'](root, profile)
    command(['flutter.bat', 'test', '--no-pub', 'test/database/materai_usage_demo_profile_test.dart'],
            cwd=auth['FRONTEND'], env={**os.environ, 'NOTARIS_MATERAI_USAGE_PREPARE': profile,
                                      'NOTARIS_MATERAI_CORRECTION_PREPARE': '1'}, timeout=240)
    baseline = snapshot(root)
    moves = baseline['data']['materai_movements']
    require(len(moves) == 1 and moves[0]['recorded_stock'] == 20 and
            json.loads(moves[0]['provenance_json'])['transaction_correction'] is True and
            len(baseline['data']['transaksis']) == 16, 'Fixture koreksi berbeda.')
    baseline.update(auth=session_hashes(root), profile=profile, prepared_ms=now_ms())
    usage['check'](baseline, baseline, 0)
    record(root, 'initial', baseline)
    print(json.dumps({'profile': profile, 'root': str(root), 'expiry': expiry}))


def now_ms():
    return int(datetime.now().timestamp() * 1000)


def check_correction(move, previous, original, tx, rule, profile):
    _, old, new, stock = rule
    delta = new - old
    operation = json.loads(move['provenance_json'])['operation']
    require(str(UUID(operation, version=4)) == operation, 'UUID operasi tidak sah.')
    date = datetime.fromtimestamp(move['source_created_ms'] / 1000).date().isoformat()
    kind = 'transaction_usage_return' if delta < 0 else 'transaction_usage_increase'
    label = 'Pengembalian' if delta < 0 else 'Tambahan pemakaian'
    desc = f"{label} meterai · {tx['jenis_transaksi'].upper()} {tx['no_akta']}"
    namespace = f"local:materai:{profile}:transaction:{tx['uuid']}:adjustment:{operation}"
    values = {'source_namespace': namespace, 'source_id': 1, 'business_date': date,
              'stock_in': max(-delta, 0), 'stock_out': max(delta, 0), 'recorded_stock': stock,
              'source_officer_id': 100, 'officer_snapshot': 'Rani Wulandari',
              'source_status': 1, 'review_reason': None, 'description': desc}
    require(all(move[k] == value for k, value in values.items()), 'Baris mutasi koreksi berbeda.')
    proof = json.loads(move['provenance_json'])
    expected = {'kind': kind, 'profile': profile, 'transaction_id': tx['id'],
                'transaction_uuid': tx['uuid'], 'domain': tx['jenis_transaksi'],
                'original_movement': original['id'], 'previous': previous['id'],
                'date': date, 'recorded_ms': move['source_created_ms'], 'quantity': abs(delta),
                'old_quantity': old, 'new_quantity': new, 'delta': delta, 'stock': stock,
                'description': desc, 'user_id': 102, 'group_id': 102, 'officer_id': 100,
                'officer': 'Rani Wulandari', 'officer_uuid': tx['petugas_uuid']}
    require(all(proof.get(k) == value for k, value in expected.items()) and
            all(re.fullmatch('[0-9a-f]{64}', proof[k]) for k in ('request_sha256', 'expected_revision')) and
            usage['sha256'](move['provenance_json'].encode()).hexdigest() == move['payload_sha256'] and
            previous['id'] < move['id'] and
            previous['source_created_ms'] < move['source_created_ms'] <= now_ms() and
            datetime.fromisoformat(proof['actor_verified_at']).timestamp() * 1000 <= move['source_created_ms'],
            'Provenance koreksi berbeda.')
    return operation


def check_stage(root, stage, current, baseline, previous):
    if stage in ('notaris', 'ppat'):
        usage['check'](current, baseline, stages.index(stage))
        require(all(current['data'][t][:len(rows)] == rows for t, rows in previous['data'].items()),
                'Data checkpoint sebelumnya berubah.')
        return
    if stage in unchanged_stages:
        require(current == previous, 'SQLite berubah pada tahap tanpa penulisan.')
    created = read_state(root, 'ppat')
    data, old = current['data'], created['data']
    require(current['protected'] == created['protected'] and current['seq'] == created['seq'],
            'Tabel terlindungi, skema, atau sequence berubah.')
    for table in usage['changing'] - {'transaksis', 'materai_movements'}:
        require(data[table] == old[table], f'Child atau pembayaran berbeda pada {table}.')
    txs = old['transaksis']
    require(data['transaksis'][:-2] == txs[:-2] and len(data['transaksis']) == len(txs),
            'Transaksi lama atau jumlah transaksi berubah.')
    count = min(stages.index(stage) - stages.index('ppat'), len(corrections))
    moves, originals = data['materai_movements'], old['materai_movements']
    require(moves[:3] == originals and len(moves) == 3 + count, 'Mutasi awal atau jumlah mutasi berubah.')
    prior_moves = previous['data']['materai_movements']
    require(moves[:len(prior_moves)] == prior_moves, 'Histori koreksi diubah.')
    quantities = [3, 4]
    operations = set()
    for i, rule in enumerate(corrections[:count]):
        domain, _, quantity, _ = rule
        quantities[domain] = quantity
        operations.add(check_correction(moves[3 + i], moves[2 + i], originals[1 + domain],
                                        txs[-2 + domain], rule, baseline['profile']))
    require(len(operations) == count, 'UUID koreksi duplikat.')
    previous_txs = previous['data']['transaksis'][-2:]
    for i, (before, after) in enumerate(zip(txs[-2:], data['transaksis'][-2:])):
        fields = {'updated_at', 'jumlah_materai', 'catatan'}
        changed = i == 0 if stage == 'zero-delta' else count > 0 and stage in stages[3:6] and corrections[count-1][0] == i
        expected_note = note if stages.index(stage) >= stages.index('zero-delta') and i == 0 else before['catatan']
        require({k: v for k, v in after.items() if k not in fields} ==
                {k: v for k, v in before.items() if k not in fields} and
                after['jumlah_materai'] == quantities[i] and after['catatan'] == expected_note and
                (after['updated_at'] >= previous_txs[i]['updated_at'] if changed else after == previous_txs[i]),
                'Header transaksi berbeda di luar koreksi yang diharapkan.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('prepare', 'postcheck', 'credential', 'launch'))
    parser.add_argument('--id')
    parser.add_argument('--stage', choices=stages)
    args = parser.parse_args()
    auth['completion']['maintenance'](24)
    if args.action == 'prepare':
        require(args.id is None and args.stage is None, 'Prepare membuat satu profil baru.')
        prepare()
        return
    require(args.id and args.stage, 'ID dan tahap diperlukan.')
    root = usage['owned'](args.id)
    require(plain(marker(root)).read_text(encoding='ascii') == args.id, 'Profil bukan milik skenario koreksi.')
    with presentation['occupied'](root):
        stage = args.stage
        baseline = read_state(root, 'initial')
        require(baseline['profile'] == args.id and baseline['auth'] == session_hashes(root),
                'Binding autentikasi berbeda.')
        current = snapshot(root)
        if stage == 'initial':
            require(args.action == 'postcheck', 'Pilih tahap Flutter.')
            usage['check'](current, baseline, 0)
            output(stage, current)
            return
        previous = read_state(root, stages[stages.index(stage) - 1])
        if stage == 'notaris':
            previous = {key: baseline[key] for key in current}
        if args.action == 'postcheck':
            check_stage(root, stage, current, baseline, previous)
            record(root, stage, current)
            return
        require(stage != 'final' and not state_file(root, stage).exists(), 'Tahap sudah selesai atau tidak interaktif.')
        require(current == previous, 'SQLite berbeda dari checkpoint sebelumnya.')
        account = {'read': 'pembaca.demo', 'denied': 'petugas.demo'}.get(stage, 'admin.demo')
        helper = auth['trusted_helper_sha'](root, presentation=True)
        usage['grants'](root, args.id)
        if args.action == 'credential':
            auth['show_credential'](root, args.id, account)
            return
        writable = stage not in read_only_stages
        opening_sha = baseline['data']['materai_movements'][0]['payload_sha256']
        command(['flutter.bat', 'run', '-d', 'windows', '--debug', '--no-pub', '-t', 'lib/materai_stock_demo_main.dart',
                 f'--dart-define=NOTARIS_MATERAI_STOCK_ID={args.id}',
                 f'--dart-define=NOTARIS_MATERAI_STOCK_ACCOUNT={account}',
                 f'--dart-define=NOTARIS_MATERAI_STOCK_HELPER_SHA={helper}',
                 f'--dart-define=NOTARIS_MATERAI_STOCK_OPENING_SHA={opening_sha}',
                 f'--dart-define=NOTARIS_MATERAI_STOCK_WRITE={str(writable).lower()}',
                 '--dart-define=NOTARIS_MATERAI_TRANSACTION_USAGE=true',
                 '--dart-define=NOTARIS_MATERAI_TRANSACTION_CORRECTION=true'],
                cwd=auth['FRONTEND'], timeout=None)
        if stage in unchanged_stages:
            require(snapshot(root) == current, 'SQLite berubah pada tahap tanpa penulisan.')


if __name__ == '__main__':
    try:
        main()
    except (OSError, RuntimeError, ValueError, KeyError, sqlite3.Error, subprocess.SubprocessError) as error:
        raise SystemExit(f'BLOCKED: {error}') from None
