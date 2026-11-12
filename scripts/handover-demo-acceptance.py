"""Prepare a separate offline Serah Terima acceptance profile."""

import argparse
from contextlib import closing
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


invoice = runpy.run_path(str(Path(__file__).with_name('invoice-demo-acceptance.py')))
payment = invoice['payment']
require, plain = invoice['require'], invoice['plain']
table = 'transaksi_serah_terima'


def root_for(id):
    require(re.fullmatch(r'[a-f0-9]{32}', id or ''), 'ID profil tidak valid.')
    return Path(tempfile.gettempdir()).resolve(strict=True) / f'notaris-handover-{id}'


def draft_fingerprint(drafts):
    return hashlib.sha256(json.dumps(drafts, ensure_ascii=False).encode()).hexdigest()


def snapshot(root, schema_version):
    with closing(payment['read_only'](root / 'offline.sqlite')) as db:
        require(db.execute('PRAGMA user_version').fetchone()[0] == schema_version and
                [row[0] for row in db.execute('PRAGMA integrity_check')] == ['ok'] and
                not db.execute('PRAGMA foreign_key_check').fetchall(), 'Schema/integrity/FK gagal.')
        schema = [tuple(row) for row in db.execute(
            'SELECT type,name,sql FROM sqlite_schema WHERE tbl_name<>? ORDER BY type,name', (table,))]
        records = {}
        for kind, name, _ in schema:
            if kind == 'table':
                rows = [dict(row) for row in db.execute(f'SELECT * FROM "{name}" ORDER BY rowid')]
                records[name] = [row for row in rows if row.get('name') != table] if name == 'sqlite_sequence' else rows
        fingerprint = hashlib.sha256(json.dumps([schema, records], sort_keys=True).encode()).hexdigest()
        drafts = [] if schema_version == 23 else [tuple(row) for row in db.execute(f'''
            SELECT t.jenis_transaksi,h.uraian,h.keperluan,h.revision,h.created_by,h.updated_by
            FROM {table} h JOIN transaksis t ON t.id=h.transaksi_id ORDER BY t.jenis_transaksi,h.id
        ''')]
        return fingerprint, drafts


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('prepare', 'launch', 'postcheck'))
    parser.add_argument('--source-id')
    parser.add_argument('--id')
    parser.add_argument('--expect', choices=('initial', 'create', 'edit', 'restart'))
    args = parser.parse_args()
    invoice['maintenance'](24)
    if args.action == 'prepare':
        require(args.id is None, 'Prepare memerlukan profil baru.')
        source = invoice['profile_path'](args.source_id)
        require(not os.path.lexists(source / 'launch.lock'), 'Profil invoice masih dipakai.')
        invoice['check'](source, args.source_id)
        fingerprint, _ = snapshot(source, 23)
        id = uuid4().hex
        root = root_for(id)
        root.mkdir()
        (root / 'owner').write_text(id, encoding='ascii')
        with closing(payment['read_only'](source / 'offline.sqlite')) as original, closing(sqlite3.connect(root / 'offline.sqlite')) as clone:
            original.backup(clone)
        payment['command'](['flutter.bat', 'test', '--no-pub',
                            'test/repositories/transaction_handover_test.dart', '--plain-name',
                            'migrates the disposable acceptance clone'],
                           cwd=payment['FRONTEND'], env={**os.environ, 'NOTARIS_HANDOVER_PREPARE': id})
        require(snapshot(root, 24) == (fingerprint, []), 'Migrasi mengubah data terlindungi.')
        (root / 'baseline.json').write_text(json.dumps({'id': id, 'protected_sha256': fingerprint}), encoding='utf-8')
        print(f'PREPARED {id} | v24 integrity=ok FK=0 | {root / "offline.sqlite"}')
        return

    root = plain(root_for(args.id), directory=True)
    require(plain(root / 'owner').read_text(encoding='ascii') == args.id, 'Marker profil tidak cocok.')
    lock = root / 'launch.lock'
    require(not os.path.lexists(lock), 'Profil sedang dipakai.')
    baseline = json.loads(plain(root / 'baseline.json').read_text(encoding='utf-8'))
    fingerprint, drafts = snapshot(root, 24)
    require(baseline == {'id': args.id, 'protected_sha256': fingerprint}, 'Data terlindungi berubah.')
    if args.action == 'postcheck':
        notaris = ('notaris', 'Salinan Akta Fidusia', 'Arsip pemohon', 1, 1, None)
        ppat = ('ppat', 'Salinan Akta Jual Beli', 'Arsip pemohon', 1, 1, None)
        edited = ('notaris', 'Salinan Akta Fidusia dan lampiran', 'Arsip pemohon', 2, 1, 1)
        expect = {'initial': [], 'create': [notaris, ppat], 'edit': [edited, ppat], 'restart': [edited, ppat]}
        require(args.expect in expect and drafts == expect[args.expect], 'Fase atau audit data cetak tidak cocok.')
        if args.expect == 'restart':
            receipt = json.loads(plain(root / 'last-launch.json').read_text(encoding='utf-8'))
            digest = draft_fingerprint(drafts)
            require(receipt == {'id': args.id, 'before': digest, 'after': digest},
                    'Belum ada bukti profil dibuka ulang setelah edit.')
        print(f'PASS {args.expect} | {len(drafts)} record | integrity=ok FK=0 | {fingerprint}')
        return
    with lock.open('x', encoding='ascii') as stream:
        stream.write(args.id)
    try:
        payment['command'](['flutter.bat', 'run', '-d', 'windows', '--debug', '--no-pub',
                            '-t', 'lib/handover_demo_main.dart', f'--dart-define=NOTARIS_HANDOVER_DEMO_ID={args.id}'],
                           cwd=payment['FRONTEND'], timeout=None)
        after, saved = snapshot(root, 24)
        require(after == fingerprint, 'Data terlindungi berubah selama acceptance.')
        receipt = root / 'last-launch.json'
        if os.path.lexists(receipt):
            plain(receipt)
        receipt.write_text(json.dumps({'id': args.id, 'before': draft_fingerprint(drafts),
                                       'after': draft_fingerprint(saved)}), encoding='utf-8')
    finally:
        lock.unlink()


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, RuntimeError, sqlite3.Error, subprocess.SubprocessError) as error:
        raise SystemExit(f'BLOCKED: {error}') from None
