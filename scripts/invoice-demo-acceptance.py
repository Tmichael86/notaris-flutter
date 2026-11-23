"""Prepare a read-only SQLite invoice demo from completed payment evidence."""

import argparse
from contextlib import closing
import json
import os
from pathlib import Path
import re
import runpy
import sqlite3
import subprocess
import tempfile
from uuid import uuid4


payment = runpy.run_path(str(Path(__file__).with_name('payment-demo-acceptance.py')))
require, plain, digest = (payment[name] for name in ('require', 'plain', 'digest'))
maintenance = payment['completion']['maintenance']


def profile_path(id):
    require(re.fullmatch(r'[a-f0-9]{32}', id or ''), 'ID profil invoice tidak valid.')
    return Path(tempfile.gettempdir()).resolve(strict=True) / f'notaris-invoice-{id}'


def check(root, id):
    plain(root, directory=True)
    require(plain(root / 'owner').read_text(encoding='ascii') == id,
            'Marker profil invoice berbeda.')
    receipt = json.loads(plain(root / 'baseline.json').read_text(encoding='utf-8'))
    current = payment['snapshot'](root)
    require(receipt['id'] == id and current == receipt['snapshot'] and
            digest(root / 'offline.sqlite') == receipt['sha256'],
            'Data SQLite disposable berubah.')
    print(json.dumps({'status': 'PASS', 'id': id, 'path': str(root / 'offline.sqlite'),
                      'sha256': receipt['sha256'], **current}, indent=2), flush=True)


def prepare(source_id):
    require(source_id, 'ID evidence payment diperlukan.')
    source = payment['owned_root'](source_id)
    require(not os.path.lexists(source / 'launch.lock'), 'Profil payment masih dipakai.')
    receipt = payment['load_baseline'](source, source_id)
    current = payment['snapshot'](source)
    require(current['phase'] == 'cancel' and
            current['protected_sha256'] == receipt['initial']['protected_sha256'],
            'Evidence payment CANCEL tidak sesuai.')
    source_sha = digest(source / 'offline.sqlite')
    id = uuid4().hex
    root = profile_path(id)
    root.mkdir()
    (root / 'owner').write_text(id, encoding='ascii')
    target = root / 'offline.sqlite'
    with closing(payment['read_only'](source / 'offline.sqlite')) as original, closing(sqlite3.connect(target)) as clone:
        original.backup(clone)
    require(payment['snapshot'](root) == current and
            digest(source / 'offline.sqlite') == source_sha,
            'Snapshot atau evidence sumber berbeda setelah backup.')
    (root / 'baseline.json').write_text(json.dumps({
        'id': id, 'source_id': source_id, 'source_sha256': source_sha,
        'snapshot': current, 'sha256': digest(target),
    }, indent=2), encoding='utf-8')
    check(root, id)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('prepare', 'launch', 'postcheck'))
    parser.add_argument('--source-id')
    parser.add_argument('--id')
    args = parser.parse_args()
    maintenance(23, compatible=(24,))
    if args.action == 'prepare':
        require(args.id is None, 'Prepare selalu membuat profil baru.')
        prepare(args.source_id)
        return
    root = profile_path(args.id)
    lock = root / 'launch.lock'
    require(not os.path.lexists(lock), 'Profil sedang diluncurkan.')
    check(root, args.id)
    if args.action == 'launch':
        with lock.open('x', encoding='ascii') as stream:
            stream.write(args.id)
        try:
            payment['command']([
                'flutter.bat', 'run', '-d', 'windows', '--debug', '--no-pub',
                '-t', 'lib/invoice_demo_main.dart',
                f'--dart-define=NOTARIS_INVOICE_DEMO_ID={args.id}',
            ], cwd=payment['FRONTEND'], timeout=None)
        finally:
            lock.unlink()
        check(root, args.id)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, RuntimeError, sqlite3.Error,
            subprocess.SubprocessError) as error:
        raise SystemExit(f'BLOCKED: {error}') from None
