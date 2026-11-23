"""Provision and check a Windows document lifecycle demo with verified accounts."""

import argparse
from contextlib import closing
import hashlib
import json
import os
from pathlib import Path
import re
import runpy
import shutil
import sqlite3
import subprocess
import tempfile


docs = runpy.run_path(str(Path(__file__).with_name('document-demo-acceptance.py')))
auth = runpy.run_path(str(Path(__file__).with_name('payment-demo-acceptance.py')))
require, plain, read_only, sha = (docs[key] for key in ('require', 'plain', 'read_only', 'sha'))
command, owned_root = auth['command'], auth['owned_root']
stages = ('initial', 'edit', 'replace', 'archive', 'restore', 'history', 'permissions')
pdf, jpeg, png = docs['samples'].keys()
title, description = 'Salinan Fidusia terverifikasi', 'Dokumen diperiksa'
archive_reason, restore_reason = 'Salah transaksi', 'Diperiksa ulang'


def snapshot(root, baseline=None):
    hashes = docs['source_hashes'](root)
    with closing(read_only(root / 'offline.sqlite')) as db:
        require(db.execute('PRAGMA user_version').fetchone()[0] == 26 and
                db.execute('PRAGMA integrity_check').fetchone()[0] == 'ok' and
                not db.execute('PRAGMA foreign_key_check').fetchall(), 'Schema, integrity atau FK tidak sesuai.')
        require([tuple(r) for r in db.execute('SELECT jenis_transaksi,no_akta FROM transaksis ORDER BY id')]
                == [('notaris', auth['NOTARIS']), ('ppat', auth['PPAT'])], 'Fixture transaksi berbeda.')
        protected = docs['protected_fingerprint'](db)
        if baseline:
            require((protected, hashes) == (baseline['protected_sha256'], baseline['source_sha256']),
                    'Data transaksi terlindungi atau sampel sumber berubah.')
        documents = [dict(r) for r in db.execute('''SELECT d.*,t.jenis_transaksi AS domain FROM transaction_documents d
            JOIN transaksis t ON t.uuid=d.transaksi_uuid ORDER BY domain,document_uuid''')]
        versions = [dict(r) for r in db.execute('SELECT * FROM transaction_document_versions ORDER BY document_uuid,version_number')]
        operations = [dict(r) for r in db.execute('SELECT * FROM transaction_document_operations ORDER BY rowid')]
        audit = [dict(r) for r in db.execute('SELECT * FROM transaction_document_audit ORDER BY rowid')]
        store = db.execute('SELECT store_uuid FROM transaction_document_store').fetchone()
        if store:
            key = hashlib.sha256(str(root / 'offline.sqlite').lower().encode()).hexdigest()
            require(re.fullmatch('[a-f0-9-]{36}', store[0]), 'UUID store tidak valid.')
            home = root / 'transaction-documents' / key / store[0]
            for path in (root / 'transaction-documents', home.parent, home, home / 'blobs', home / 'staging'):
                plain(path, directory=True)
            require(json.loads(plain(home / 'manifest.json').read_text()) ==
                    {'format': 1, 'profile_key': key, 'store_uuid': store[0]}, 'Manifest store berbeda.')
            blobs = set()
            for row in versions:
                name = row['original_display_name']
                require(name in docs['samples'] and re.fullmatch('[a-f0-9-]{36}', row['version_uuid']),
                        'Versi di luar skenario.')
                _, mime, ext = docs['samples'][name]
                blob = home / 'blobs' / f"{row['version_uuid']}.{ext}"
                blobs.add(blob.name)
                require(row['media_type'] == mime and row['sha256'] == hashes[name] == sha(blob) and
                        row['byte_size'] == blob.stat().st_size, 'Byte versi berbeda dari sampel.')
            require({p.name for p in (home / 'blobs').iterdir()} == blobs and
                    not any((home / 'staging').iterdir()), 'Blob atau staging di luar skenario.')
        else:
            require(not versions and not os.path.lexists(root / 'transaction-documents'), 'Store belum terikat.')
    return dict(protected_sha256=protected, source_sha256=hashes, documents=documents,
                versions=versions, operations=operations, audit=audit)


def verify_stage(state, stage):
    documents, versions, operations, audit = (state[key] for key in ('documents', 'versions', 'operations', 'audit'))
    if stage == 'initial':
        require(not any((documents, versions, operations, audit)), 'Profil initial sudah berubah.')
        return
    expected = stages.index(stage)
    actions = ['edit', 'replace', 'archive', 'restore'][:min(expected, 4)]
    require([row['action'] for row in audit] == actions and len(documents) == 2,
            'Jumlah dokumen atau urutan audit berbeda.')
    notaris, ppat = documents
    require(notaris['domain'] == 'notaris' and ppat['domain'] == 'ppat' and
            all(row['detail_uuid'] is None and row['created_by'] == 101 for row in documents), 'Owner impor berbeda.')
    names = {doc['domain']: [v['original_display_name'] for v in versions if v['document_uuid'] == doc['document_uuid']]
             for doc in documents}
    require(names == {'notaris': [pdf] + ([png] if expected >= 2 else []), 'ppat': [jpeg]}, 'Riwayat versi berbeda.')
    require(notaris['title'] == title and notaris['description'] == description and
            notaris['revision'] == 1 + len(actions) and (notaris['archived_at'] is not None) == (stage == 'archive') and
            notaris['archived_by'] == (102 if stage == 'archive' else None) and ppat['revision'] == 1 and
            ppat['archived_at'] is None, 'Metadata, revisi atau status arsip berbeda.')
    require(len(operations) == len(versions) and all(r['state'] == 'committed' for r in operations), 'Receipt file berbeda.')
    for version in versions:
        receipt = next((r for r in operations if r['version_uuid'] == version['version_uuid']), None)
        doc = next(r for r in documents if r['document_uuid'] == version['document_uuid'])
        imported = version['version_number'] == 1
        require(receipt and receipt['action'] == ('import' if imported else 'replace') and
                receipt['actor_user_id'] == receipt['actor_group_id'] == version['created_by'] == (101 if imported else 102) and
                receipt['transaksi_uuid'] == doc['transaksi_uuid'] and receipt['document_uuid'] == doc['document_uuid'] and
                receipt['sha256'] == version['sha256'], 'Receipt, actor atau hash berbeda.')
    notaris_versions = [v for v in versions if v['document_uuid'] == notaris['document_uuid']]
    require([v['version_number'] for v in notaris_versions] == list(range(1, len(notaris_versions) + 1)), 'Urutan versi berbeda.')
    for index, row in enumerate(audit):
        before, after = (json.loads(row[key]) for key in ('before_state', 'after_state'))
        prior, current = notaris_versions[int(index >= 2)], notaris_versions[int(index >= 1)]
        require(row['document_uuid'] == notaris['document_uuid'] and row['actor_user_id'] == row['actor_group_id'] == 102 and
                row['occurred_at'] > 0 and row['reason'] == [None, None, archive_reason, restore_reason][index] and
                (before['revision'], after['revision']) == (index + 1, index + 2) and
                (before['version_uuid'], before['sha256']) == (prior['version_uuid'], prior['sha256']) and
                (after['version_uuid'], after['sha256']) == (current['version_uuid'], current['sha256']) and
                (before['archived'], after['archived']) == (index == 3, index == 2) and
                (before['title'], before['description']) == ((None, None) if index == 0 else (title, description)) and
                (after['title'], after['description']) == (title, description), 'Audit lifecycle berbeda.')


def prepare():
    require(all((auth['PG_BIN'] / name).is_file() for name in ('initdb.exe', 'pg_ctl.exe', 'psql.exe', 'createdb.exe')),
            'Binari PostgreSQL disposable tidak ditemukan.')
    require(not auth['port_open'](), 'Port khusus disposable 55674 sedang dipakai.')
    # Keep provisioning artifacts for audit. The official provisioner shuts
    # down its own cluster and attests the fresh data directory before seeding.
    scratch = Path(tempfile.mkdtemp(prefix='notaris-document-auth-')).resolve(strict=True)
    helper = scratch / 'session.exe'
    auth['build_helper'](helper)
    profile = auth['provision'](scratch, helper)
    root = owned_root(profile)
    with helper.open('rb') as source, (root / 'session.exe').open('xb') as target:
        shutil.copyfileobj(source, target)
    accounts = auth['auth_status'](root, profile)
    (root / 'document-lifecycle-owner').write_text(profile, encoding='ascii')
    env = {key: value for key, value in os.environ.items() if key != 'NOTARIS_DOCUMENT_REUSE_SAMPLES'}
    command(['flutter.bat', 'test', '--no-pub', 'test/database/document_demo_prepare_test.dart'], cwd=docs['front'],
            env={**env, 'NOTARIS_DOCUMENT_PREPARE': profile, 'NOTARIS_DOCUMENT_LIFECYCLE': '1'})
    state = snapshot(root)
    verify_stage(state, 'initial')
    baseline = {**state, 'id': profile, 'auth': {name: sha(root / name) for name in auth['AUTH_FILES']}}
    with (root / 'baseline.json').open('x', encoding='utf-8') as stream:
        json.dump(baseline, stream, indent=2)
    print(json.dumps({'stage': 'initial', 'result': 'PASS', 'id': profile, 'root': str(root),
                      'source_sha256': state['source_sha256'], 'protected_sha256': state['protected_sha256'],
                      'accounts': accounts, 'disposable_cluster': str(scratch / 'pgdata')}, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('prepare', 'credential', 'launch', 'postcheck'))
    parser.add_argument('--id')
    parser.add_argument('--account', choices=auth['ACCOUNTS'])
    parser.add_argument('--expect', choices=stages)
    args = parser.parse_args()
    auth['completion']['maintenance'](24)
    if args.action == 'prepare':
        require(args.id is None, 'Prepare membutuhkan profil baru.')
        return prepare()
    require(args.id, 'ID profil diperlukan.')
    root = owned_root(args.id)
    require(plain(root / 'document-lifecycle-owner').read_text(encoding='ascii') == args.id, 'Marker lifecycle berbeda.')
    require(not os.path.lexists(root / 'launch.lock'), 'Tutup Flutter atau tinjau lock terlebih dahulu.')
    baseline = auth['load_baseline'](root, args.id)
    before = snapshot(root, baseline)
    if args.action == 'postcheck':
        require(args.expect, 'Fase diperlukan.')
        verify_stage(before, args.expect)
        if args.expect in ('history', 'permissions'):
            receipt = json.loads(plain(root / 'last-launch.json').read_text(encoding='utf-8'))
            require(receipt['before'] == receipt['after'] == before, 'Belum ada bukti sesi baca tanpa perubahan.')
        print(f'PASS {args.expect} | v26 integrity=ok FK=0 | {len(before["versions"])} versi | {len(before["audit"])} audit')
        return
    helper_sha = auth['trusted_helper_sha'](root)
    auth['auth_status'](root, args.id)
    if args.action == 'credential':
        require(args.account, 'Akun diperlukan.')
        return auth['show_credential'](root, args.id, args.account)
    lock = root / 'launch.lock'
    with lock.open('x', encoding='ascii') as stream:
        stream.write(args.id)
    try:
        command(['flutter.bat', 'run', '-d', 'windows', '--debug', '--no-pub', '-t', 'lib/document_demo_main.dart',
                 f'--dart-define=NOTARIS_DOCUMENT_DEMO_ID={args.id}',
                 f'--dart-define=NOTARIS_DOCUMENT_HELPER_SHA256={helper_sha}'], cwd=docs['front'], timeout=None)
        after = snapshot(root, baseline)
        receipt = root / 'last-launch.json'
        if os.path.lexists(receipt):
            plain(receipt)
        receipt.write_text(json.dumps({'before': before, 'after': after}), encoding='utf-8')
    finally:
        lock.unlink()


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, RuntimeError, sqlite3.Error, subprocess.SubprocessError) as error:
        raise SystemExit(f'BLOCKED: {error}') from None
