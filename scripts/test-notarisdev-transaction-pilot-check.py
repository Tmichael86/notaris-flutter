import copy
import json
from pathlib import Path
import runpy
import sqlite3
import tempfile
import unittest


check = runpy.run_path(str(Path(__file__).with_name('check-notarisdev-transaction-pilot.py')))


class PilotCheckTest(unittest.TestCase):
    def setUp(self):
        self.plan = json.loads(check['PLAN_PATH'].read_bytes())
        ids = [f'master-{i}' for i in range(1, 6)] + [self.plan['master']['uuid']]
        self.snapshot = {
            'target': self.plan['target'], 'marker': self.plan['deployment'],
            'role': 'nd_app_' + self.plan['generation'][:12], 'account_active': True,
            'permissions': {'transaksi': {'read': 1, 'create': 1}, 'pekerjaan_notaris': {'read': 1}},
            'pemohon_active': True, 'petugas_version': 1, 'master_pending': 0,
            'ppat_pending': 0, 'transaction_pending': 0,
            'master_publication': {'last_seq': 6, 'min_cursor': 0},
            'transaction_publication': {'last_seq': 8},
            'active_masters': [{**self.plan['master'], 'price_matches_publication': True}],
            'master_feed': [
                {'sequence': sequence, 'uuid': uuid, 'payload_uuid': uuid,
                 'revision': 1, 'operation': 'create'} for sequence, uuid in enumerate(ids, start=1)
            ],
        }

    def test_selects_reviewed_published_price(self):
        self.assertEqual(check['check_server'](self.plan, self.snapshot)['uuid'], self.plan['master']['uuid'])

    def test_refuses_unpublished_or_changed_price(self):
        self.snapshot['active_masters'][0]['price_matches_publication'] = False
        with self.assertRaisesRegex(ValueError, 'published Master'):
            check['check_server'](self.plan, self.snapshot)

    def test_refuses_gap_and_wrong_payload_identity(self):
        gap = copy.deepcopy(self.snapshot)
        gap['master_feed'].pop(2)
        with self.assertRaisesRegex(ValueError, 'feed gap'):
            check['check_server'](self.plan, gap)
        self.snapshot['master_feed'][0]['payload_uuid'] = 'different'
        with self.assertRaisesRegex(ValueError, 'replay identity'):
            check['check_server'](self.plan, self.snapshot)

    def test_refuses_pending_event_and_missing_permission(self):
        pending = copy.deepcopy(self.snapshot)
        pending['ppat_pending'] = 1
        with self.assertRaisesRegex(ValueError, 'Unpublished events'):
            check['check_server'](self.plan, pending)
        self.snapshot['permissions']['transaksi']['create'] = 0
        with self.assertRaisesRegex(ValueError, 'permission mismatch'):
            check['check_server'](self.plan, self.snapshot)

    def test_ambiguous_bootstrap_and_upload_never_reopen_execution(self):
        row = {'id': 4, 'uuid': 'pilot', 'mutation_id': 'frozen', 'payload_sha256': 'hash',
               'state': 'pending', 'operation': 'create', 'revision': None}
        receipt = {**row, 'status': 'LOCAL_COMMITTED_PENDING'}
        status = check['checkpoint_status']
        self.assertEqual(status([row], receipt, False), 'CHECKPOINT_PRESENT_PENDING')
        self.assertEqual(status([row], None, False), 'BOOTSTRAP_OUTCOME_REVIEW_REQUIRED')
        self.assertEqual(status([row], receipt, True), 'UPLOAD_ATTEMPTED_REVIEW_REQUIRED')
        self.assertEqual(status([{**row, 'payload_sha256': 'changed'}], receipt, False),
                         'BOOTSTRAP_OUTCOME_REVIEW_REQUIRED')

    def test_check_reader_cannot_write_sqlite(self):
        with tempfile.TemporaryDirectory(prefix='pilot-check-test-', dir=check['ROOT']) as folder:
            path = Path(folder) / 'review.sqlite'
            db = sqlite3.connect(path)
            db.executescript('PRAGMA user_version=19; CREATE TABLE record(id INTEGER); INSERT INTO record VALUES (1);')
            db.close()
            before = path.read_bytes()
            with check['read_sqlite'](path) as readonly:
                self.assertEqual(readonly.execute('SELECT count(*) FROM record').fetchone()[0], 1)
                with self.assertRaises(sqlite3.OperationalError):
                    readonly.execute('INSERT INTO record VALUES (2)')
            self.assertEqual(path.read_bytes(), before)


if __name__ == '__main__':
    unittest.main()
