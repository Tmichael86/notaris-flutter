"""Provision and verify the isolated Windows Materai stock-in acceptance."""
import argparse
from contextlib import closing
from datetime import datetime, timezone
from hashlib import sha256
import json
import os
from pathlib import Path
import re
import runpy
import sqlite3
import subprocess
import tempfile

presentation = runpy.run_path(str(Path(__file__).with_name('presentation-demo.py')))
auth = presentation['auth']
require, plain, read_only, command, digest = (
    auth[key] for key in ('require', 'plain', 'read_only', 'command', 'digest')
)
accounts = {'admin.demo': [1, 1, 0, 0], 'pembaca.demo': [1, 0, 0, 0], 'petugas.demo': [0, 0, 0, 0]}
stages = {'create': 'admin.demo', 'restart': 'admin.demo',
          'read-only': 'pembaca.demo', 'denied': 'petugas.demo'}
receipt_date = '2026-11-17'
receipt_label = 'Penerimaan materai uji Windows'


def fingerprint(value):
    return sha256(json.dumps(value, ensure_ascii=False, sort_keys=True,
                             default=lambda raw: {'bytes': raw.hex()}).encode()).hexdigest()


def root_for(profile):
    root = auth['owned_root'](profile)
    require(plain(root / 'materai-owner').read_text(encoding='ascii') == profile and
            not (root / 'presentation-owner').exists(), 'Scope disposable Materai V2 berbeda.')
    return root


def snapshot(root):
    file = root / 'offline.sqlite'
    with closing(read_only(file)) as db:
        require(db.execute('PRAGMA user_version').fetchone()[0] == 27, 'SQLite harus v27.')
        require([r[0] for r in db.execute('PRAGMA integrity_check')] == ['ok'],
                'SQLite integrity_check gagal.')
        require(not db.execute('PRAGMA foreign_key_check').fetchall(), 'Pelanggaran FK.')
        objects = [list(r) for r in db.execute(
            'SELECT type,name,tbl_name,sql FROM sqlite_master ORDER BY type,name')]
        protected = {}
        for kind, name, _, _ in objects:
            if kind == 'table' and name != 'materai_movements':
                quoted = '"' + name.replace('"', '""') + '"'
                protected[name] = sorted(fingerprint(list(r)) for r in db.execute(f'SELECT * FROM {quoted}'))
        ledger = [dict(r) for r in db.execute('SELECT * FROM materai_movements ORDER BY id')]
    return {'sqlite': digest(file), 'protected': fingerprint([objects, protected]), 'ledger': ledger}


def authentication(root, profile):
    signed = json.loads(command([root / 'session.exe', 'verify', profile], capture=True))
    require({a['username']: a['materai'] for a in signed} == accounts, 'Grant Materai demo berbeda.')
    return {a['username']: a['expiresAt'] for a in signed}


def auth_fingerprints(root):
    return {name: digest(root / name) for name in (*auth['AUTH_FILES'], 'materai-owner', 'session.exe')}


def prepare():
    with tempfile.TemporaryDirectory(prefix='notaris-materai-stock-auth-') as name:
        scratch = Path(name).resolve(strict=True)
        helper = scratch / 'session.exe'
        auth['build_helper'](helper)
        profile = auth['provision'](scratch, helper, materai=True)
        root = root_for(profile)
        with (root / 'session.exe').open('xb') as dest:
            dest.write(plain(helper).read_bytes())
    expiry = authentication(root, profile)
    command(['flutter.bat', 'test', '--no-pub', 'test/database/materai_stock_demo_profile_test.dart'],
            cwd=auth['FRONTEND'], env={**os.environ, 'NOTARIS_MATERAI_STOCK_PREPARE': profile}, timeout=240)
    baseline = snapshot(root)
    require([r['recorded_stock'] for r in baseline['ledger']] == [20, 25], 'Saldo fixture berbeda.')
    baseline.update(auth=auth_fingerprints(root), profile=profile,
                    prepared_ms=int(datetime.now(timezone.utc).timestamp()*1000))
    with (root / 'materai-stock-baseline.json').open('x', encoding='utf-8') as stream:
        json.dump(baseline, stream, indent=2)
    print(json.dumps({'result': 'PASS INITIAL', 'profile': profile, 'root': str(root),
                      'expiry': expiry, 'stocks': [20, 25], 'sqlite_sha256': baseline['sqlite'],
                      'protected_sha256': baseline['protected'], 'schema': 27, 'integrity': 'ok', 'fk': 0}))


def check(current, baseline, stage):
    old, ledger = baseline['ledger'], current['ledger']
    require(current['protected'] == baseline['protected'] and ledger[:len(old)] == old,
            'Data terlindungi atau saldo historis berubah.')
    if stage == 'initial':
        require(ledger == old and current['sqlite'] == baseline['sqlite'], 'Profil awal berubah.')
        return None
    require(len(ledger) == len(old) + 1 and current['sqlite'] != baseline['sqlite'],
            'Perlu tepat satu mutasi penerimaan baru.')
    row = ledger[-1]
    data = json.loads(row['provenance_json'])
    op = data.get('operation')
    require(isinstance(op, str) and re.fullmatch(r'[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}', op),
            'UUID operasi berbeda.')
    require(row['source_namespace'] == f"local:materai:{baseline['profile']}:receipt:{op}" and
            row['source_id'] == 1 and len({r['source_namespace'] for r in ledger}) == len(ledger),
            'Identitas ledger baru berbeda atau ganda.')
    require((row['business_date'], row['stock_in'], row['stock_out'], row['recorded_stock'],
             row['description'], row['source_status'], row['review_reason'],
             row['source_officer_id'], row['officer_snapshot']) ==
            (receipt_date, 7, 0, 32, receipt_label, 1, None, 100, 'Rani Wulandari'),
            'Isi penerimaan tidak cocok dengan skenario.')
    require(sha256(row['provenance_json'].encode()).hexdigest() == row['payload_sha256'] and
            (data.get('kind'), data.get('profile'), data.get('previous'), data.get('user_id'), data.get('group_id'),
             data.get('officer_id'), data.get('officer_uuid'), data.get('officer'), data.get('quantity'),
             data.get('stock'), data.get('description'), data.get('date'), data.get('recorded_ms')) ==
            ('manual_stock_in', baseline['profile'], old[-1]['id'], 102, 102, 100,
             'e0c928a2-c304-437e-8bf5-7a81bd5e0eae', 'Rani Wulandari', 7, 32, receipt_label,
             receipt_date, row['source_created_ms']),
            'Provenance penerimaan berbeda.')
    recorded = row['source_created_ms']
    verified = datetime.fromisoformat(data['actor_verified_at'])
    require(baseline['prepared_ms'] <= recorded <= int(datetime.now(timezone.utc).timestamp()*1000)
            and int(verified.timestamp()*1000) <= recorded,
            'Waktu pencatatan tidak berasal dari sesi yang berlaku.')
    return op


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('prepare', 'credential', 'launch', 'postcheck'))
    parser.add_argument('--id')
    parser.add_argument('--stage', choices=('initial', *stages, 'final'))
    args = parser.parse_args()
    auth['completion']['maintenance'](24)
    if args.action == 'prepare':
        require(args.id is None and args.stage is None, 'Prepare membuat satu profil baru.')
        prepare()
        return
    require(args.id and args.stage, 'ID dan tahap diperlukan.')
    root = root_for(args.id)
    with presentation['occupied'](root):
        baseline = json.loads(plain(root / 'materai-stock-baseline.json').read_text(encoding='utf-8'))
        require(baseline['profile'] == args.id and baseline['auth'] == auth_fingerprints(root),
                'Binding profil atau fingerprint autentikasi berbeda.')
        current = snapshot(root)
        pending = root / 'materai-pending-receipt.json'
        if args.action == 'postcheck':
            require(not os.path.lexists(pending), 'Draf belum ditutup. Lanjutkan CREATE terlebih dahulu.')
            operation = check(current, baseline, args.stage)
            print(json.dumps({'result': 'PASS ' + args.stage.upper(),
                              'stocks': [r['recorded_stock'] for r in current['ledger']],
                              'operation': operation, 'protected_sha256': current['protected'],
                              'sqlite_sha256': current['sqlite'], 'integrity': 'ok', 'fk': 0}))
            return
        require(args.stage in stages, 'Pilih create, restart, read-only, atau denied.')
        writable = args.stage == 'create'
        if os.path.lexists(pending):
            require(writable, 'Hanya tahap CREATE boleh melanjutkan draf.')
            plain(pending)
        pre_stage = 'initial' if writable and len(current['ledger']) == 2 else args.stage
        check(current, baseline, pre_stage)
        if writable and pre_stage != 'initial':
            require(pending.exists(), 'Penerimaan sudah selesai. Gunakan RESTART.')
        helper_sha = auth['trusted_helper_sha'](root, presentation=True)
        authentication(root, args.id)
        account = stages[args.stage]
        if args.action == 'credential':
            auth['show_credential'](root, args.id, account)
            return
        command(['flutter.bat', 'run', '-d', 'windows', '--debug', '--no-pub',
                 '-t', 'lib/materai_stock_demo_main.dart',
                 f'--dart-define=NOTARIS_MATERAI_STOCK_ID={args.id}',
                 f'--dart-define=NOTARIS_MATERAI_STOCK_ACCOUNT={account}',
                 f'--dart-define=NOTARIS_MATERAI_STOCK_HELPER_SHA={helper_sha}',
                 f'--dart-define=NOTARIS_MATERAI_STOCK_OPENING_SHA={baseline["ledger"][0]["payload_sha256"]}',
                 f'--dart-define=NOTARIS_MATERAI_STOCK_WRITE={str(writable).lower()}'],
                cwd=auth['FRONTEND'], timeout=None)
        require(writable or snapshot(root) == current, 'Profil baca saja berubah selama Flutter berjalan.')


if __name__ == '__main__':
    try:
        main()
    except (OSError, RuntimeError, ValueError, KeyError, sqlite3.Error, subprocess.SubprocessError) as error:
        raise SystemExit(f'BLOCKED: {error}') from None
