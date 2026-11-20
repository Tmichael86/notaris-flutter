"""New Windows-owned Groups V1 acceptance. Never discovers operational databases."""
import argparse
import json
import os
from pathlib import Path
import re
import runpy
import subprocess
import tempfile
import time

# Reuse reviewed process, filesystem and read-only fingerprint primitives only.
# Loading the module does not call its prepare/check or access any old profile.
common = runpy.run_path(str(Path(__file__).with_name('promotional-demo.py')))
auth = common['auth']
REPO, FRONT, PG = common['REPO'], common['FRONT'], common['PG']
execute, clean_env, occupied = common['execute'], common['clean_env'], common['occupied']
require, snapshot = common['require'], common['snapshot']
PORT, HTTP = 55796, 55884
PHASES = ('initial','list','search','filter','pagination','create','rename','conflict','deactivate','denied','offline','restart','final')


def root_for(profile):
    require(re.fullmatch('[a-f0-9]{32}', profile or ''), 'ID Groups V1 diperlukan.')
    root = auth['plain'](Path(tempfile.gettempdir()).resolve() / f'notaris-payment-{profile}', directory=True)
    for name in ('owner','groups-v1-owner'):
        require(auth['plain'](root / name).read_text(encoding='ascii') == profile, 'Profil bukan Groups V1 baru.')
    require(not (root / 'promotional-owner').exists(), 'Profil promosi terlarang.')
    return root


def helper(root, action, account=None, capture=True):
    args = [auth['plain'](root / 'session.exe'), 'groups-v1-' + action, root.name.removeprefix('notaris-payment-')]
    if account is not None:
        args.append(account)
    return execute(args, capture=capture, timeout=None if action in ('serve','credential') else 40)


def pin(root):
    with tempfile.TemporaryDirectory(prefix='notaris-groups-v1-pin-') as folder:
        built = Path(folder).resolve(strict=True) / 'session.exe'
        auth['build_helper'](built)
        require(auth['digest'](built) == auth['digest'](root / 'session.exe'), 'Source/helper berubah; STOP untuk review, tidak repin otomatis.')
    helper(root, 'validate')


def cluster(root, action):
    data = auth['plain'](root / 'pgdata', directory=True)
    require(data.parent == root, 'Cluster bukan milik profil.')
    args = [PG / 'pg_ctl.exe', action, '-D', data, '-w', '-t','25']
    if action == 'start':
        require(not occupied(PORT), 'Port Groups V1 terpakai; tidak menggunakan instance lain.')
        args += ['-l',root / 'postgres.log','-o',f'-h 127.0.0.1 -p {PORT} -c log_statement=none -c log_min_error_statement=panic -c log_parameter_max_length_on_error=0']
    else:
        require(action == 'stop', 'Aksi cluster tidak sah.')
        helper(root, 'state')  # verifies active connection + exact owned data_directory
        args += ['-m','fast']
    result = subprocess.run([str(x) for x in args], env=clean_env(), stdin=subprocess.DEVNULL,
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=45)
    require(result.returncode == 0, 'pg_ctl gagal; tidak ada fallback/retry otomatis.')


def postgres(root):
    return json.loads(helper(root, 'state'))


def check(root, phase, *, concurrent_edit=False):
    require(concurrent_edit or not (root / 'launch.lock').exists(), 'Tutup Flutter sebelum postcheck; lock dipertahankan jika exit ambigu.')
    base = json.loads(auth['plain'](root / 'groups-v1-baseline.json').read_text())
    require(snapshot(root) == base['sqlite'], 'Fingerprint seluruh SQLite operasional berubah. STOP tanpa reset.')
    state = postgres(root)
    require(state['fingerprints'] == base['postgres']['fingerprints'], 'Group/grant/akun terproteksi berubah.')
    require(state['integrity'] == state['recovery'] == 'PASS', 'Referensi/recovery tidak sah.')
    stage = PHASES.index(phase)
    expected = {r['id']:dict(r) for r in base['postgres']['groups']}
    users = {r['id']:dict(r) for r in base['postgres']['users']}
    audits = []
    if stage >= PHASES.index('create'):
        expected[1001] = {'id':1001,'group_nama':'Grup Baru','group_jenis':'user','status':1,'revision':1}
        audits.append(('group_create',1001,'success'))
    if stage >= PHASES.index('rename'):
        expected[1001].update(group_nama='Grup Baru Diperbarui',revision=2)
        audits.append(('group_update',1001,'success'))
    if stage >= PHASES.index('conflict'):
        expected[201].update(group_nama='Operasional Terbaru',revision=2)
        audits.extend([('group_update',201,'success'),('group_update',201,'denied')])
    if stage >= PHASES.index('deactivate'):
        expected[202].update(status=0,revision=2)
        for row in users.values():
            if row['group_id']==202:row['security_version']+=1
        audits.append(('group_deactivate',202,'success'))
    require({r['id']:r for r in state['groups']} == expected, 'State grup berbeda; STOP tanpa perbaikan baseline.')
    require({r['id']:r for r in state['users']} == users, 'Membership/status/security version berubah di luar skenario.')
    require([(a['action'],a['target_id'],a['result']) for a in state['audits']] == audits, 'Audit berbeda; STOP tanpa retry.')
    require(all(a['actor_id']==101 and a['target_type']=='group' and re.fullmatch('[a-f0-9-]{36}',a['request_id']) for a in state['audits']), 'Actor/target/audit tidak sah.')
    require(len({a['request_id'] for a in state['audits']})==len(audits), 'Request ID duplikat.')
    if stage >= PHASES.index('conflict'):
        denied=[a for a in state['audits'] if a['result']=='denied']
        require(len(denied)==1 and denied[0]['reason_code']=='stale_revision', 'Konflik tidak sesuai skenario.')
    evidence = root / f'postcheck-{phase}-{time.time_ns()}.json'
    result = {'marker':f'GROUPS_V1_{phase.upper().replace("-","_")}_PASS', 'profile':root.name.removeprefix('notaris-payment-'),
              'sqlite':base['sqlite'], 'postgres':state, 'http_target':'127.0.0.1:55884',
              'manual_visual':'OPERATOR MUST CONFIRM', 'operational_activation':'OFF'}
    with evidence.open('x',encoding='utf-8') as f:
        json.dump(result,f,indent=2)
    print(result['marker']); print(f'EVIDENCE={evidence}')


def prepare():
    require(os.name == 'nt', 'Windows DPAPI diperlukan.')
    require(not occupied(PORT) and not occupied(HTTP), 'Port acceptance terpakai.')
    with tempfile.TemporaryDirectory(prefix='notaris-groups-v1-build-') as folder:
        built = Path(folder).resolve(strict=True) / 'session.exe'
        auth['build_helper'](built)
        raw = json.loads(execute([built,'groups-v1-init'],capture=True))
        profile = raw['profile']; root=root_for(profile)
        with (root / 'session.exe').open('xb') as f:
            f.write(built.read_bytes())
    print(f'NEW_GROUPS_V1_PROFILE={profile}',flush=True)
    pw = auth['plain'](root / 'initdb-password')
    try:
        execute([PG/'initdb.exe','-D',root/'pgdata','-U','groups_owner','-A','scram-sha-256','--pwfile',pw,'--no-locale','-E','UTF8'],capture=True)
    finally:
        pw.unlink(missing_ok=True)
    cluster(root,'start')
    try:
        helper(root,'bootstrap')
        execute(['flutter.bat','test','--no-pub','test/database/groups_acceptance_profile_test.dart','--reporter','expanded'],
                cwd=FRONT,env={**clean_env(),'NOTARIS_GROUPS_V1_PREPARE':profile},timeout=600)
        helper(root,'self-check')
        before = snapshot(root)
        require(before['counts']['transaksis']==2 and before['counts']['transaksi_riwayat_pembayaran']==2,'Fixture proteksi tidak lengkap.')
        with (root/'groups-v1-baseline.json').open('x',encoding='utf-8') as f:
            json.dump({'sqlite':before,'postgres':postgres(root)},f,indent=2)
        check(root,'initial')
    finally:
        cluster(root,'stop')
    print(f'PROFILE_DIRECTORY={root}')
    print('PREPARED: cluster stopped, evidence retained. Operator UI acceptance NOT started.')


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('action',choices=('prepare','backend','credential','launch','check','postcheck','state','conflict-edit','stop'))
    p.add_argument('--id');p.add_argument('--account');p.add_argument('--expect',choices=PHASES,default='initial')
    args=p.parse_args()
    if args.action=='prepare':
        require(args.id is None,'Prepare wajib membuat profil BARU.');prepare();return
    root=root_for(args.id);pin(root)
    if args.action=='backend':
        if not occupied(PORT):cluster(root,'start')
        postgres(root)
        require(not occupied(HTTP),'Port HTTP terpakai; tidak mengambil proses lain.')
        helper(root,'serve',capture=False)
    elif args.action=='stop':
        require(not occupied(HTTP),'Tutup backend Ctrl+C dahulu.');cluster(root,'stop');print('GROUPS_V1_STOPPED_DATA_RETAINED')
    elif args.action=='credential':
        require(args.account is not None,'--account diperlukan.')
        print('Kredensial hanya di dialog Windows; jangan scan atau rekam password.',flush=True)
        helper(root,'credential',args.account,capture=False)
    elif args.action=='state':
        print(json.dumps(postgres(root),indent=2))
    elif args.action in ('check','postcheck'):
        check(root,args.expect)
    elif args.action=='conflict-edit':
        require((root / 'launch.lock').exists(), 'Buka Ubah Nama Operasional di Flutter dahulu.')
        check(root,'rename',concurrent_edit=True);print(helper(root,'conflict'))
    elif args.action=='launch':
        # State may be intentionally between phases. Do not force an old baseline.
        require(snapshot(root)==json.loads((root/'groups-v1-baseline.json').read_text())['sqlite'],'SQLite berubah.')
        postgres(root);helper(root,'http-check')
        lock=root/'launch.lock'
        with lock.open('x',encoding='ascii') as f:f.write(args.id)
        try:
            execute(['flutter.bat','run','-d','windows','--debug','--no-pub','-t','lib/groups_acceptance_main.dart',
                     f'--dart-define=NOTARIS_GROUPS_V1_ID={args.id}',
                     f'--dart-define=NOTARIS_GROUPS_V1_HELPER_SHA256={auth["digest"](root/"session.exe")}'],cwd=FRONT,timeout=None)
        finally:
            lock.unlink()
        require(snapshot(root)==json.loads((root/'groups-v1-baseline.json').read_text())['sqlite'],'SQLite berubah.')


if __name__=='__main__':
    try:main()
    except (OSError,ValueError,RuntimeError,KeyError,subprocess.SubprocessError) as error:
        raise SystemExit(f'BLOCKED: {error}') from None
    except KeyboardInterrupt:
        print('\nDihentikan; profil dipertahankan. Tidak ada reset/retry otomatis.')
