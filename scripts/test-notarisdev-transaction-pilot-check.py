import copy
import json
from pathlib import Path
import runpy
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


if __name__ == '__main__':
    unittest.main()
