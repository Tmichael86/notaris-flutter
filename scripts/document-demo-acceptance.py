"""Prepare and verify the disposable offline Windows document demo."""

import argparse
from collections import Counter
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


legacy = runpy.run_path(str(Path(__file__).with_name('notaris-completion-acceptance.py')))
require, plain, read_only = (legacy[key] for key in ('require', 'plain', 'read_only'))
front = legacy['FRONTEND']
samples = {
    'Salinan Fidusia.pdf': ('notaris', 'application/pdf', 'pdf'),
    'Foto AJB.jpg': ('ppat', 'image/jpeg', 'jpg'),
    'Peta AJB.png': ('ppat', 'image/png', 'png'),
}
stages = ('initial', 'import', 'open', 'restart', 'read-only')


def root_for(id):
    require(re.fullmatch('[a-f0-9]{32}', id or ''), 'ID profil dokumen tidak valid.')
    return Path(tempfile.gettempdir()).resolve(strict=True) / f'notaris-documents-{id}'


def sha(path):
    with plain(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def protected_fingerprint(db):
    schema = [tuple(row) for row in db.execute('''SELECT type,name,sql FROM sqlite_schema
        WHERE name NOT LIKE 'transaction_document%' AND tbl_name NOT LIKE 'transaction_document%'
        ORDER BY type,name''')]
    protected = {name: [dict(row) for row in db.execute(f'SELECT * FROM "{name}" ORDER BY rowid')]
                 for kind, name, _ in schema if kind == 'table'}
    return hashlib.sha256(json.dumps([schema, protected], sort_keys=True).encode()).hexdigest()


def snapshot(root):
    with closing(read_only(root / 'offline.sqlite')) as db:
        require(db.execute('PRAGMA user_version').fetchone()[0] == 25 and
                [row[0] for row in db.execute('PRAGMA integrity_check')] == ['ok'] and
                not db.execute('PRAGMA foreign_key_check').fetchall(), 'Schema, integrity atau FK tidak cocok.')
        records = [dict(row) for row in db.execute('''SELECT t.jenis_transaksi AS domain,
            d.document_uuid,d.detail_uuid,v.version_uuid,v.original_display_name AS name,
            v.media_type,v.byte_size,v.sha256,v.created_by
            FROM transaction_documents d JOIN transaksis t ON t.uuid=d.transaksi_uuid
            JOIN transaction_document_versions v ON v.document_uuid=d.document_uuid
            JOIN transaction_document_operations o ON o.document_uuid=d.document_uuid
              AND o.version_uuid=v.version_uuid AND o.transaksi_uuid=d.transaksi_uuid
              AND o.detail_uuid IS d.detail_uuid AND o.state='committed' AND o.action='import'
              AND o.sha256=v.sha256 AND o.byte_size=v.byte_size AND o.media_type=v.media_type
              AND o.original_display_name=v.original_display_name AND o.actor_user_id=v.created_by
              AND d.created_by=v.created_by AND o.actor_group_id=1
            WHERE d.archived_at IS NULL AND v.version_number=1 ORDER BY v.original_display_name''')]
        store = db.execute('SELECT store_uuid FROM transaction_document_store').fetchone()
        counts = [db.execute(f'SELECT count(*) FROM {table}').fetchone()[0] for table in (
            'transaction_documents', 'transaction_document_versions', 'transaction_document_operations',
        )]
        committed = db.execute("SELECT count(*) FROM transaction_document_operations WHERE state='committed'").fetchone()[0]
        require(counts == [len(records)] * 3 and committed == len(records), 'Metadata atau receipt impor tidak lengkap.')
        digest = protected_fingerprint(db)
        return digest, records, store[0] if store else None


def source_hashes(root):
    return {name: sha(root / name) for name in samples}


def verify_owners(records, stage):
    names = Counter(row['name'] for row in records)
    unexpected = sum(count for name, count in names.items() if name not in samples)
    require(unexpected == 0, f'Dokumen tambahan di luar skenario: {unexpected}.')
    issues = []
    for name, (owner, _, _) in samples.items():
        number = '1001111260001' if owner == 'notaris' else '2001111260001'
        if any(row['name'] == name and row['domain'] != owner for row in records):
            issues.append(f'Owner dokumen salah: {name} harus di {owner.upper()} {number}')
        if names[name] > 1:
            issues.append(f'Dokumen duplikat: {name} ({names[name]} salinan)')
        if stage and stage != 'initial' and not names[name]:
            issues.append(f'Dokumen wajib belum diimpor: {name}')
    require(not issues, '. '.join(issues) + '.' if issues else '')


def verify(root, baseline, stage=None):
    protected, records, store = snapshot(root)
    require(protected == baseline['protected_sha256'],
            f"Fingerprint SQLite terlindungi berubah (expected {baseline['protected_sha256']}, aktual {protected}).")
    sources = source_hashes(root)
    for name in samples:
        require(sources[name] == baseline['source_sha256'].get(name), f'SHA-256 sampel sumber berubah: {name}.')
    require(sources == baseline['source_sha256'], 'Daftar hash sampel sumber berbeda dari baseline.')
    if stage == 'initial':
        require(not records and store is None and not os.path.lexists(root / 'transaction-documents'),
                'Profil initial sudah memiliki lampiran.')
    verify_owners(records, stage)
    if records:
        require(re.fullmatch('[a-f0-9-]{36}', store or ''), 'Store UUID tidak valid.')
        key = hashlib.sha256(str(root / 'offline.sqlite').lower().encode()).hexdigest()
        home = root / 'transaction-documents' / key / store
        for directory in (root / 'transaction-documents', home.parent, home, home / 'blobs', home / 'staging'):
            plain(directory, directory=True)
        manifest = json.loads(plain(home / 'manifest.json').read_text(encoding='ascii'))
        require(manifest == {'format': 1, 'profile_key': key, 'store_uuid': store}, 'Manifest store berbeda.')
        blob_names = set()
        for row in records:
            _, media_type, ext = samples[row['name']]
            require(row['media_type'] == media_type and row['created_by'] == 1 and
                    row['detail_uuid'] is None and re.fullmatch('[a-f0-9-]{36}', row['version_uuid']),
                    f"Metadata atau aktor impor berbeda: {row['name']}.")
            blob = home / 'blobs' / f"{row['version_uuid']}.{ext}"
            blob_names.add(blob.name)
            require(os.path.lexists(blob), f"File managed hilang: {row['name']}.")
            require(row['sha256'] == baseline['source_sha256'][row['name']] == sha(blob) and
                    row['byte_size'] == blob.stat().st_size == (root / row['name']).stat().st_size,
                    f"Byte, ukuran atau SHA-256 file managed berbeda: {row['name']}.")
        require({entry.name for entry in (home / 'blobs').iterdir()} == blob_names and
                not any((home / 'staging').iterdir()), 'Ada blob atau staging di luar skenario.')
    return records


def check_stage(root, id, baseline, stage):
    records = verify(root, baseline, stage)
    checkpoint = root / f'checked-{stage}.json'
    if stage != 'initial':
        previous = stages[stages.index(stage) - 1]
        prior = None if previous == 'initial' else json.loads(
            plain(root / f'checked-{previous}.json').read_text(encoding='utf-8'))
        receipt = json.loads(plain(root / 'last-launch.json').read_text(encoding='utf-8'))
        require(receipt['id'] == id and receipt['after'] == records and
                receipt['before'] == ([] if stage == 'import' else records) and
                (prior is None or prior['id'] == id and prior['run_id'] != receipt['run_id']),
                'Tutup Flutter dan gunakan sesi launch baru untuk setiap fase.')
        evidence = {'id': id, 'run_id': receipt['run_id']}
        if os.path.lexists(checkpoint):
            require(json.loads(plain(checkpoint).read_text(encoding='utf-8')) == evidence,
                    'Checkpoint fase sudah tercatat pada sesi lain.')
        else:
            with checkpoint.open('x', encoding='utf-8') as stream:
                json.dump(evidence, stream)
    print(json.dumps({'stage': stage, 'database_and_bytes': 'PASS', **baseline,
                      'documents': records}, ensure_ascii=False))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('prepare', 'launch', 'postcheck'))
    parser.add_argument('--id')
    parser.add_argument('--samples-from')
    parser.add_argument('--expect', choices=stages)
    args = parser.parse_args()
    legacy['maintenance'](24)
    if args.action == 'prepare':
        require(args.id is None, 'Prepare selalu menggunakan ID baru.')
        verified_samples = None
        if args.samples_from:
            source = plain(root_for(args.samples_from), directory=True)
            require(plain(source / 'owner').read_text(encoding='ascii') == args.samples_from,
                    'Marker profil sampel berbeda.')
            require(not os.path.lexists(source / 'launch.lock'), 'Profil sampel sedang digunakan.')
            source_baseline = json.loads(plain(source / 'baseline.json').read_text(encoding='utf-8'))
            verified_samples = {name: plain(source / name).read_bytes() for name in samples}
            require(source_baseline['id'] == args.samples_from and
                    {name: hashlib.sha256(data).hexdigest() for name, data in verified_samples.items()}
                    == source_baseline['source_sha256'], 'SHA-256 sampel sumber berbeda.')
        id = uuid4().hex
        root = root_for(id)
        root.mkdir()
        (root / 'owner').write_text(id, encoding='ascii')
        env = {**os.environ, 'NOTARIS_DOCUMENT_PREPARE': id}
        env.pop('NOTARIS_DOCUMENT_REUSE_SAMPLES', None)
        if verified_samples is not None:
            env['NOTARIS_DOCUMENT_REUSE_SAMPLES'] = '1'
        subprocess.run(['flutter.bat', 'test', '--no-pub', 'test/database/document_demo_prepare_test.dart'],
                       cwd=front, env=env, check=True)
        if verified_samples is not None:
            for name, data in verified_samples.items():
                with (root / name).open('xb') as stream:
                    stream.write(data)
        protected, _, _ = snapshot(root)
        baseline = {'id': id, 'protected_sha256': protected, 'source_sha256': source_hashes(root)}
        (root / 'baseline.json').write_text(json.dumps(baseline, indent=2), encoding='utf-8')
        check_stage(root, id, baseline, 'initial')
        print(f'PREPARED {id} | {root / "offline.sqlite"}')
        return

    require(args.samples_from is None, '--samples-from hanya berlaku saat prepare.')
    id = args.id
    root = plain(root_for(id), directory=True)
    require(plain(root / 'owner').read_text(encoding='ascii') == id, 'Marker profil berbeda.')
    lock = root / 'launch.lock'
    require(not os.path.lexists(lock), 'Profil sedang digunakan atau perlu review lock.')
    baseline = json.loads(plain(root / 'baseline.json').read_text(encoding='utf-8'))
    require(baseline['id'] == id, 'Baseline berbeda.')
    if args.action == 'postcheck':
        require(args.expect, 'Tentukan fase postcheck.')
        check_stage(root, id, baseline, args.expect)
        return

    before = verify(root, baseline)
    with lock.open('x', encoding='ascii') as stream:
        stream.write(id)
    try:
        subprocess.run(['flutter.bat', 'run', '-d', 'windows', '--debug', '--no-pub',
                        '-t', 'lib/document_demo_main.dart', f'--dart-define=NOTARIS_DOCUMENT_DEMO_ID={id}'],
                       cwd=front, check=True)
        legacy['maintenance'](24)
        after = verify(root, baseline)
        receipt = root / 'last-launch.json'
        if os.path.lexists(receipt):
            plain(receipt)
        receipt.write_text(json.dumps({'id': id, 'run_id': uuid4().hex,
                                      'before': before, 'after': after}), encoding='utf-8')
    finally:
        lock.unlink()


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, RuntimeError, sqlite3.Error, subprocess.SubprocessError) as error:
        raise SystemExit(f'BLOCKED: {error}') from None
