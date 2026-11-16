from copy import deepcopy
from pathlib import Path
import runpy
import tempfile
import unittest


demo = runpy.run_path(str(Path(__file__).with_name('pengeluaran-demo-acceptance.py')))


class PostcheckTest(unittest.TestCase):
    def setUp(self):
        self.initial = dict(schema=24, integrity='ok', fk=0, expenses=[],
                            protected={'transaksi_riwayat_pembayaran': 'fixture'},
                            sequence=0, jenis={'ATK': 1, 'Transport': 2})
        self.created = dict(id=1, uuid='10000000-0000-4000-8000-000000000001',
                            no_faktur='PT-ACCEPT-01', tanggal=demo['calendar'](14),
                            nominal=15000, jenis_id=1, jenis_nama='ATK',
                            keterangan='Berkas kantor sintetis',
                            created_at=1, updated_at=1, deleted_at=None)
        self.edited = dict(self.created, tanggal=demo['calendar'](15), nominal=20000,
                           jenis_id=2, jenis_nama='Transport', keterangan='Kurir kantor sintetis',
                           updated_at=2)
        self.deleted = dict(self.edited, updated_at=3, deleted_at=3)

    def state(self, row):
        return dict(deepcopy(self.initial), sequence=1, expenses=[dict(row)])

    def test_phase_sequence_requires_separate_launches_and_preserves_uuid(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp).resolve()
            check = demo['postcheck']
            check(root, self.initial, self.initial, 'initial')
            before = self.initial
            for i, (stage, row) in enumerate(zip(
                    demo['stages'][1:], [self.created, self.edited, self.edited,
                                         self.deleted, self.deleted, self.deleted]), 1):
                state = self.state(row)
                with self.assertRaises((OSError, ValueError, RuntimeError)):
                    check(root, state, self.initial, stage)
                demo['write_new'](root / f'launch-{i}.json', {'before': before, 'after': state})
                check(root, state, self.initial, stage)
                before = state

    def test_protected_change_duplicate_hard_delete_and_identity_drift_are_rejected(self):
        validate = demo['verify_stage']
        changed = self.state(self.edited)
        changed['protected']['transaksi_riwayat_pembayaran'] = 'unexpected'
        duplicate = self.state(self.edited)
        duplicate['expenses'].append(deepcopy(self.edited))
        drift = self.state(dict(self.edited, uuid='10000000-0000-4000-8000-000000000002'))
        for state in [changed, duplicate, drift]:
            with self.assertRaises((ValueError, RuntimeError)):
                validate(state, self.initial, 'edit', self.created)
        with self.assertRaises((ValueError, RuntimeError)):
            validate(self.initial, self.initial, 'delete', self.created, self.edited)


if __name__ == '__main__':
    unittest.main()
