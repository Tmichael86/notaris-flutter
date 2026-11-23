"""Check-only inventory of the approved synthetic development profile. No Drift open."""
import argparse
import json
import os
from pathlib import Path
import re
import sqlite3

parser = argparse.ArgumentParser()
parser.add_argument('--stage', choices=['Check'], default='Check')
parser.parse_args()
repo = Path(__file__).resolve().parent.parent
profile = json.loads((repo / '.local/notarisdev-profile.json').read_text(encoding='utf-8'))
assert profile['database'] == 'notarisdev' and profile['port'] == 5432 and profile['fixture'] == 'smoke-v1'
assert re.fullmatch('[a-f0-9]{32}', profile['generation'])
path = Path(os.environ['APPDATA']) / 'com.notaris/frontend_notaris/notarisdev' / profile['generation'] / 'offline.sqlite'
assert path.is_file() and not path.is_symlink() and path.resolve() == path.absolute(), 'Unexpected profile path'
with sqlite3.connect(path.as_uri() + '?mode=ro', uri=True) as db:
    db.row_factory = sqlite3.Row
    db.execute('PRAGMA query_only=ON')
    db.execute('BEGIN')
    assert db.execute('PRAGMA user_version').fetchone()[0] == 19, 'Stop: schema changed; no migration permitted'
    assert db.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
    assert not db.execute('PRAGMA foreign_key_check').fetchall()
    result = {'stage': 'Check', 'path': str(path), 'schema': 19,
              'execution': 'BLOCKED: development HTTP factory/attestation and scope binding not approved',
              'counts': {}, 'records': []}
    for table in ['pemohons', 'petugas', 'transaksis', 'transaction_cloud_identity', 'transaction_cloud_pending', 'transaction_cloud_feed', 'pekerjaan_notaris_sync_identity', 'pekerjaan_ppat_sync_identity']:
        result['counts'][table] = db.execute('SELECT count(*) FROM ' + table).fetchone()[0]
    for row in db.execute('SELECT id,uuid,jenis_transaksi,is_sync_dirty,deleted_at FROM transaksis ORDER BY id'):
        assert row['jenis_transaksi'] in {'notaris', 'ppat'}, 'Unknown domain: stop Check'
        item = dict(row)
        item['missing_price_category_provenance'] = db.execute('SELECT count(*) FROM transaksi_details WHERE transaksi_id=? AND deleted_at IS NULL AND (harga_uuid IS NULL OR kategori_uuid IS NULL)', (row['id'],)).fetchone()[0]
        item['unmapped_master_references'] = db.execute('SELECT count(*) FROM transaksi_details d LEFT JOIN pekerjaan_' + row['jenis_transaksi'] + ' p ON p.id=d.pekerjaan_' + row['jenis_transaksi'] + '_id LEFT JOIN pekerjaan_' + row['jenis_transaksi'] + '_sync_identity i ON i.local_uuid=p.uuid WHERE d.transaksi_id=? AND d.deleted_at IS NULL AND i.local_uuid IS NULL', (row['id'],)).fetchone()[0]
        result['records'].append(item)
    db.rollback()
print(json.dumps(result, indent=2))
