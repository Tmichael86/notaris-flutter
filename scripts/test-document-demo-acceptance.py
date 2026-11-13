"""Focused checks for disposable document acceptance diagnostics."""

from pathlib import Path
import runpy
import unittest
from unittest.mock import patch


runner = runpy.run_path(str(Path(__file__).with_name('document-demo-acceptance.py')))
verify = runner['verify']
expected = [{'name': name, 'domain': sample[0]} for name, sample in runner['samples'].items()]


class DocumentAcceptanceTest(unittest.TestCase):
    def test_correct_ownership_passes(self):
        runner['verify_owners'](expected, 'import')

    def test_wrong_owner_and_duplicate_are_reported(self):
        records = expected + [{'name': 'Foto AJB.jpg', 'domain': 'notaris'}]
        with self.assertRaisesRegex(RuntimeError, r'Owner dokumen salah: Foto AJB.jpg.*Dokumen duplikat'):
            runner['verify_owners'](records, 'import')

    def test_missing_document_fails_postcheck_but_allows_initial_empty(self):
        runner['verify_owners']([], 'initial')
        with self.assertRaisesRegex(RuntimeError, 'Dokumen wajib belum diimpor: Peta AJB.png'):
            runner['verify_owners'](expected[:-1], 'import')

    def test_unexpected_document_name_is_not_printed(self):
        records = expected + [{'name': 'private.pdf', 'domain': 'notaris'}]
        with self.assertRaisesRegex(RuntimeError, r'^Dokumen tambahan di luar skenario: 1\.$'):
            runner['verify_owners'](records, 'import')

    def test_protected_fingerprint_is_checked_independently(self):
        with patch.dict(verify.__globals__, {'snapshot': lambda _: ('different', [], None)}):
            with self.assertRaisesRegex(RuntimeError, 'Fingerprint SQLite terlindungi berubah'):
                verify(Path('.'), {'protected_sha256': 'expected'}, 'import')

    def test_source_hash_failure_names_the_fixture(self):
        hashes = dict.fromkeys(runner['samples'], 'baseline')
        with patch.dict(verify.__globals__, {
            'snapshot': lambda _: ('protected', [], None),
            'source_hashes': lambda _: {**hashes, 'Peta AJB.png': 'changed'},
        }):
            with self.assertRaisesRegex(RuntimeError, 'SHA-256 sampel sumber berubah: Peta AJB.png'):
                verify(Path('.'), {'protected_sha256': 'protected', 'source_sha256': hashes}, 'import')


if __name__ == '__main__':
    unittest.main()
