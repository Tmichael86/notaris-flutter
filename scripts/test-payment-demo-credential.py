"""Focused launcher checks. No PostgreSQL, SQLite connection, or real passwords."""

from contextlib import redirect_stdout
import io
from pathlib import Path
import runpy
import subprocess
import unittest
from unittest.mock import patch


runner = runpy.run_path(str(Path(__file__).with_name('payment-demo-acceptance.py')))


class CredentialDialogTests(unittest.TestCase):
    def setUp(self):
        self.profile = 'a' * 32
        self.root = Path('payment-demo')
        self.account = 'pembaca.demo'
        self.feedback = io.StringIO()
        self.enterContext(redirect_stdout(self.feedback))
        self.popen = self.enterContext(patch.object(subprocess, 'Popen'))
        self.enterContext(patch.object(subprocess, 'CREATE_NEW_PROCESS_GROUP', 512, create=True))
        self.child = self.popen.return_value.__enter__.return_value

    def show(self):
        return runner['show_credential'](self.root, self.profile, self.account)

    def test_reports_wait_before_starting_without_redirecting_credentials(self):
        def start(*args, **kwargs):
            self.assertIn('Terminal menunggu', self.feedback.getvalue())
            return child_context

        self.child.wait.return_value = 0
        child_context = self.popen.return_value
        self.popen.side_effect = start
        self.show()
        self.popen.assert_called_once_with(
            [str(self.root / 'session.exe'), 'credential', self.profile, self.account],
            creationflags=512,
        )
        self.child.wait.assert_called_once_with(timeout=600)
        self.child.terminate.assert_not_called()

    def test_timeout_terminates_owned_child(self):
        self.child.wait.side_effect = [subprocess.TimeoutExpired('session.exe', 600), 1]
        with self.assertRaisesRegex(RuntimeError, 'melewati batas'):
            self.show()
        self.child.terminate.assert_called_once()
        self.assertEqual(self.child.wait.call_count, 2)

    def test_cancel_terminates_owned_child(self):
        self.child.wait.side_effect = [KeyboardInterrupt(), 1]
        with self.assertRaisesRegex(RuntimeError, 'dibatalkan'):
            self.show()
        self.child.terminate.assert_called_once()
        self.assertEqual(self.child.wait.call_count, 2)

    def test_nonzero_exit_has_separate_diagnostic(self):
        self.child.wait.return_value = 1
        with self.assertRaisesRegex(RuntimeError, 'kode 1'):
            self.show()
        self.child.terminate.assert_not_called()

    def test_original_verification_uses_checksum_without_sqlite_connection(self):
        path = Path('offline.sqlite')
        with patch.dict(runner['completion'], {
            'original_database_path': lambda: path,
            'quiet_sqlite_file': lambda candidate: candidate,
        }), patch.dict(runner['verify_original_unchanged'].__globals__, {
            'digest': lambda candidate: 'current',
        }), patch('sqlite3.connect', side_effect=AssertionError('Unexpected SQLite connection')):
            runner['verify_original_unchanged']({'schema': 20, 'path': str(path), 'sha256': 'current'})
            with self.assertRaisesRegex(RuntimeError, 'development berubah'):
                runner['verify_original_unchanged']({'schema': 20, 'path': str(path), 'sha256': 'old'})


if __name__ == '__main__':
    unittest.main()
