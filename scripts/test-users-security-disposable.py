"""Own one fresh PostgreSQL cluster for Users security tests; no live target input."""
import os
from pathlib import Path
import secrets
import socket
import subprocess
import tempfile
import sys

REPO = Path(__file__).resolve().parents[1]
PG = Path('D:/Program Files/PostgreSQL/bin')
PORT = 55793


def run(args, env, capture=False):
    # Windows PostgreSQL children can inherit PIPE handles from pg_ctl even
    # with -l. A DEVNULL handle avoids communicate() waiting for a daemon EOF.
    if Path(str(args[0])).name == 'pg_ctl.exe':
        subprocess.run([str(x) for x in args], cwd=REPO / 'backend-notaris-go', env=env,
                       stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL, timeout=45, check=True)
        return ''
    result = subprocess.run([str(x) for x in args], cwd=REPO / 'backend-notaris-go',
                            env=env, capture_output=capture, text=True, timeout=600, check=False)
    if result.returncode:
        # Initdb/psql messages are not emitted with inherited connection secrets.
        raise RuntimeError(f'{Path(str(args[0])).name} failed ({result.returncode})')
    return result.stdout if capture else ''


def main():
    with socket.socket() as sock:
        if sock.connect_ex(('127.0.0.1', PORT)) == 0:
            raise RuntimeError('Disposable port occupied; no existing instance will be used')
    env = {k: v for k, v in os.environ.items() if not k.upper().startswith('PG')}
    # Other opt-ins must not direct unrelated tests toward a permanent service.
    env = {k: v for k, v in env.items() if not k.startswith('NOTARIS_')}
    with tempfile.TemporaryDirectory(prefix='notaris-users-security-') as directory:
        root = Path(directory).resolve()
        data = root / 'pgdata'
        password = secrets.token_hex(32)
        pw = root / 'init-password'
        pw.write_text(password + '\n', encoding='ascii')
        try:
            run([PG / 'initdb.exe', '-D', data, '-U', 'postgres', '-A', 'scram-sha-256',
                 '--pwfile', pw, '--no-locale', '-E', 'UTF8'], env, True)
        finally:
            pw.unlink(missing_ok=True)
        client = {**env, 'PGPASSWORD': password}
        connection = ['-h', '127.0.0.1', '-p', PORT, '-U', 'postgres', '-w']
        try:
            run([PG / 'pg_ctl.exe', 'start', '-D', data, '-l', root / 'postgres.log',
                 '-o', f'-h 127.0.0.1 -p {PORT}', '-w', '-t', '25'], env, True)
            actual = run([PG / 'psql.exe', '-X', *connection, '-d', 'postgres', '-Atc',
                          'SHOW data_directory'], client, True).strip()
            if Path(actual).resolve() != data:
                raise RuntimeError('Disposable ownership mismatch')
            run([PG / 'createdb.exe', *connection, 'users_security_disposable'], client, True)
            run([PG / 'psql.exe', '-X', *connection, '-d', 'users_security_disposable', '-v',
                 'ON_ERROR_STOP=1', '-c', "COMMENT ON DATABASE users_security_disposable IS 'NOTARIS USERS SECURITY DISPOSABLE'"], client, True)
            testenv = {**env, 'NOTARIS_USERS_SECURITY_TEST_DSN':
                       f'host=127.0.0.1 port={PORT} user=postgres password={password} dbname=users_security_disposable sslmode=disable'}
            if '--flutter' in sys.argv:
                testenv['NOTARIS_USERS_V1_FLUTTER_E2E'] = '1'
            run(['go', 'test', './routes', '-run', '^TestUsersSecurity', '-count=1', '-v'], testenv)
        finally:
            if (data / 'postmaster.pid').exists():
                run([PG / 'pg_ctl.exe', 'stop', '-D', data, '-m', 'fast', '-w', '-t', '25'], env, True)
    print('USERS_SECURITY_DISPOSABLE: PASS (fresh owned cluster stopped)')


if __name__ == '__main__':
    main()
