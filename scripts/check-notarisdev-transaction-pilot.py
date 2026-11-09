"""Check-only reader for the fixed synthetic development pilot recipe."""
import argparse
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import sqlite3
import sys


ROOT = Path(__file__).resolve().parent.parent
PLAN_PATH = ROOT / 'scripts/plans/notarisdev-transaction-pilot.json'


def require(condition, message):
    if not condition:
        raise ValueError(message)


def check_server(plan, snapshot):
    require(snapshot['target'] == plan['target'] and snapshot['marker'] == plan['deployment']
            and snapshot['role'] == 'nd_app_' + plan['generation'][:12], 'Unexpected PostgreSQL target or role')
    permissions = snapshot['permissions'] or {}
    require(snapshot['account_active'] and permissions.get('transaksi') == {'read': 1, 'create': 1}
            and permissions.get('pekerjaan_notaris', {}).get('read') == 1, 'Fixture account or permission mismatch')
    require(snapshot['pemohon_active'] and snapshot['petugas_version'] == 1, 'Server Pemohon/Petugas changed')
    require(all(snapshot[key] == 0 for key in ('master_pending', 'ppat_pending', 'transaction_pending')),
            'Unpublished events require review')
    require(snapshot['master_publication']['last_seq'] == plan['master_last_seq']
            and snapshot['master_publication']['min_cursor'] == 0
            and snapshot['transaction_publication']['last_seq'] == plan['transaction_last_seq'], 'Publication baseline changed')
    matches = [row for row in snapshot['active_masters']
               if all(row.get(key) == value for key, value in plan['master'].items())]
    require(len(matches) == 1 and matches[0]['price_matches_publication'], 'Active published Master/price/category mismatch')
    events = snapshot['master_feed']
    require([event['sequence'] for event in events] == list(range(1, plan['master_last_seq'] + 1)), 'Master feed gap')
    revisions = {}
    for event in events:
        uuid, revision, operation = (event[key] for key in ('uuid', 'revision', 'operation'))
        previous, deleted = revisions.get(uuid, (0, False))
        require(event['payload_uuid'] == uuid and not deleted and revision == previous + 1
                and operation in ({'create'} if previous == 0 else {'update', 'delete'}), 'Invalid Master replay identity/revision')
        revisions[uuid] = (revision, operation == 'delete')
    master = plan['master']
    published = events[master['sequence'] - 1]
    require(published['uuid'] == master['uuid'] and published['revision'] == master['revision']
            and revisions[master['uuid']] == (master['revision'], False), 'Master replay does not end at reviewed revision')
    return matches[0]


def closed_file(path):
    require(path.is_file() and path.resolve() == path.absolute(), 'Unexpected SQLite path')
    require(not any(Path(str(path) + suffix).exists() for suffix in ('-wal', '-shm', '-journal')),
            'Close SQLite writers before Check')


@contextmanager
def read_sqlite(path):
    closed_file(path)
    db = sqlite3.connect(path.as_uri() + '?mode=ro', uri=True)
    try:
        db.row_factory = sqlite3.Row
        db.execute('PRAGMA query_only=ON')
        db.execute('BEGIN')
        require(db.execute('PRAGMA user_version').fetchone()[0] == 19, 'SQLite v19 required')
        require([row[0] for row in db.execute('PRAGMA integrity_check')] == ['ok']
                and not db.execute('PRAGMA foreign_key_check').fetchall(), 'SQLite integrity/FK check failed')
        yield db
    finally:
        db.close()


def logical_sha256(db):
    digest = hashlib.sha256()
    for line in db.iterdump():
        digest.update((line + '\n').encode('utf-8'))
    return digest.hexdigest()


def check_local(db, path, plan, snapshot):
    legacy_scope = [plan['base_url'], 'notarisdev', plan['generation'], plan['account_id'], plan['device'], str(path)]
    officer_feed = db.execute('SELECT scope,cursor,blocked FROM petugas_sync_feed WHERE id=1').fetchone()
    require(officer_feed is not None and json.loads(officer_feed['scope']) == legacy_scope
            and officer_feed['cursor'] == 4 and officer_feed['blocked'] is None, 'Existing Petugas binding changed')
    applicant = db.execute('SELECT id FROM pemohons WHERE uuid=? AND status=1 AND deleted_at IS NULL '
                           'AND is_sync_dirty=0 AND last_synced_at IS NOT NULL', (plan['pemohon_uuid'],)).fetchall()
    officer = db.execute('''SELECT p.id,p.uuid FROM petugas p
        JOIN petugas_identity_map i ON i.local_uuid=p.uuid
        JOIN petugas_sync_journal j ON j.local_uuid=p.uuid
        WHERE i.cloud_uuid=? AND i.server_id=101 AND i.state IN ('verified','server_only') AND length(trim(i.evidence))>0
          AND p.status=1 AND p.deleted_at IS NULL AND p.is_sync_dirty=0 AND j.row_version=? AND j.pending IS NULL''',
        (plan['petugas_uuid'], snapshot['petugas_version'])).fetchall()
    require(len(applicant) == len(officer) == 1, 'Local Pemohon/Petugas reference unresolved')
    for table in ('transaction_cloud_identity', 'transaction_cloud_pending', 'transaction_cloud_feed',
                  'pekerjaan_notaris_sync_identity', 'pekerjaan_notaris_sync_pending', 'pekerjaan_notaris_sync_feed',
                  'pekerjaan_ppat_sync_identity', 'pekerjaan_ppat_sync_pending', 'pekerjaan_ppat_sync_feed'):
        require(db.execute(f'SELECT 1 FROM {table} LIMIT 1').fetchone() is None, f'Unexpected existing binding or mutation in {table}')
    for event in snapshot['master_feed']:
        prices, processes = event['harga'] or [], event['proses'] or []
        for price in prices:
            require(len(db.execute('SELECT id FROM pekerjaan_kategori WHERE uuid=? AND status=1 AND deleted_at IS NULL '
                                   'AND is_sync_dirty=0', (price['category_uuid'],)).fetchall()) == 1,
                    'A Master feed event needs an unresolved local category')
        for table, uuids in (
            ('pekerjaan_notaris', [event['uuid']]),
            ('pekerjaan_notaris_harga', [price['uuid'] for price in prices]),
            ('pekerjaan_notaris_proses', [process['uuid'] for process in processes]),
            ('pekerjaan_notaris_atributs', [attr['uuid'] for process in processes for attr in process['atribut'] or []]),
        ):
            for uuid in uuids:
                require(db.execute(f'SELECT 1 FROM {table} WHERE uuid=?', (uuid,)).fetchone() is None,
                        f'Local UUID collision in {table}; reconciliation is outside this pilot')
    scope = [plan['base_url'], plan['target'], plan['deployment'], plan['account_id'], plan['group_id'],
             plan['device'], plan['generation'], str(path)]
    prefix = json.dumps(scope, separators=(',', ':'), ensure_ascii=False)
    return {'pemohon_local_id': applicant[0]['id'], 'petugas_local_id': officer[0]['id'],
            'petugas_local_uuid': officer[0]['uuid'], 'petugas_scope': officer_feed['scope'],
            'proposed_master_scope': prefix + '/masters', 'proposed_transaction_scope': prefix + '/transactions',
            'dirty_transactions': [dict(row) for row in db.execute(
                'SELECT id,uuid,jenis_transaksi FROM transaksis WHERE is_sync_dirty=1 ORDER BY id')]}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--backup', type=Path)
    args = parser.parse_args()
    plan_bytes = PLAN_PATH.read_bytes()
    plan = json.loads(plan_bytes)
    snapshot = json.load(sys.stdin)
    candidate = check_server(plan, snapshot)
    profile = json.loads((ROOT / '.local/notarisdev-profile.json').read_text(encoding='utf-8'))
    require(profile['database'] == 'notarisdev' and profile['port'] == 5432 and profile['fixture'] == 'smoke-v1'
            and profile['generation'] == plan['generation'] == '14af5452144b42d0be2ad88bac41b656', 'Development profile changed')
    path = Path(os.environ['APPDATA']) / 'com.notaris/frontend_notaris/notarisdev' / profile['generation'] / 'offline.sqlite'
    closed_file(path)
    before = hashlib.sha256(path.read_bytes()).hexdigest()
    with read_sqlite(path) as db:
        local = check_local(db, path, plan, snapshot)
        digest = logical_sha256(db)
    backup = 'missing'
    if args.backup:
        file = args.backup.resolve(strict=True)
        require(file.is_relative_to((ROOT / '.local').resolve()) and file.suffix == '.sqlite', 'Expected an audit backup under .local')
        with read_sqlite(file) as db:
            backup = 'matches' if logical_sha256(db) == digest else 'stale_or_different'
    closed_file(path)
    require(hashlib.sha256(path.read_bytes()).hexdigest() == before, 'Source changed during Check')
    remaining = ['Runtime HTTP pilot attestation and binding approval', 'Local draft save approval',
                 'Verified PostgreSQL recovery backup and single-UUID Upload approval after draft review']
    if backup != 'matches':
        remaining.insert(0, 'Current verified SQLite backup')
    feed_bytes = json.dumps(snapshot['master_feed'], sort_keys=True, separators=(',', ':')).encode('utf-8')
    print(json.dumps({'stage': 'Check', 'execution': 'BLOCKED', 'plan_sha256': hashlib.sha256(plan_bytes).hexdigest(),
                      'postgres_target': snapshot['target'], 'permissions': snapshot['permissions'], 'master': candidate,
                      'master_feed_events': len(snapshot['master_feed']), 'master_feed_sha256': hashlib.sha256(feed_bytes).hexdigest(),
                      'sqlite': str(path), 'sqlite_sha256': before,
                      'sqlite_logical_sha256': digest, 'backup': backup, 'binding': local,
                      'remaining': remaining}, indent=2))


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, KeyError, sqlite3.Error) as error:
        sys.exit(f'BLOCKED: {error}')
