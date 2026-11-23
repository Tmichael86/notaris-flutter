"""New Windows-owned Groups V2 acceptance. Never discovers operational databases."""
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
PORT, HTTP = 55797, 55885
PHASES = ('initial','list','open','expand','enable-read','enable-cud','save','reopen','revoke','permission-refresh','conflict','denied','protected','recovery','restart','final')
ALIASES = {'catalog':'list','grant':'enable-cud','backend-denied':'permission-refresh'}
# Explicit acceptance selections, not new authorization policy. Unsupported
# actions stay zero; actual module authorization is tested independently.
FULL_CRUD = {4,11,22,24,27,28,29,30}


def acceptance_flags(sidebar_id, revision, full):
    if revision == 2:
        if full:
            return [1,1,1,1] if sidebar_id in FULL_CRUD else [1,1,0,0] if sidebar_id == 32 else [1,0,0,0]
        if sidebar_id == 4:return [1,1,1,1]
    if revision == 4 and sidebar_id == 4:return [1,0,0,0]
    return [0,0,0,0]


def root_for(profile):
    require(re.fullmatch('[a-f0-9]{32}', profile or ''), 'ID Groups V2 diperlukan.')
    root = auth['plain'](Path(tempfile.gettempdir()).resolve() / f'notaris-payment-{profile}', directory=True)
    for name in ('owner','groups-v2-owner'):
        require(auth['plain'](root / name).read_text(encoding='ascii') == profile, 'Profil bukan Groups V2 baru.')
    require(not (root / 'promotional-owner').exists(), 'Profil promosi terlarang.')
    return root


def helper(root, action, account=None, capture=True):
    args = [auth['plain'](root / 'session.exe'), 'groups-v2-' + action, root.name.removeprefix('notaris-payment-')]
    if account is not None:
        args.append(account)
    return execute(args, capture=capture, timeout=None if action in ('serve','credential') else 40)


def pin(root):
    with tempfile.TemporaryDirectory(prefix='notaris-groups-v2-pin-') as folder:
        built = Path(folder).resolve(strict=True) / 'session.exe'
        auth['build_helper'](built)
        require(auth['digest'](built) == auth['digest'](root / 'session.exe'), 'Source/helper berubah; STOP untuk review, tidak repin otomatis.')
    helper(root, 'validate')


def cluster(root, action):
    data = auth['plain'](root / 'pgdata', directory=True)
    require(data.parent == root, 'Cluster bukan milik profil.')
    args = [PG / 'pg_ctl.exe', action, '-D', data, '-w', '-t','25']
    if action == 'start':
        require(not occupied(PORT), 'Port Groups V2 terpakai; tidak menggunakan instance lain.')
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
    requested_phase=phase
    phase=ALIASES.get(phase,phase)
    require(concurrent_edit or phase in ('open','expand','enable-read','enable-cud') or not (root/'launch.lock').exists(), 'Tutup Flutter sebelum postcheck commit; lock ambigu dipertahankan.')
    base=json.loads(auth['plain'](root/'groups-v2-baseline.json').read_text())
    full=base.get('catalog')=='full-v2.1'
    # V2.1 refreshes granted permissions before revocation. The accepted V2
    # sequence retains its original post-revoke permission-refresh checkpoint.
    if full and requested_phase=='permission-refresh':phase='reopen'
    if full:
        manifest=json.loads(helper(root,'validate'))
        require(manifest.get('Catalog')=='full-v2.1','Katalog tidak terikat ke profil DPAPI.')
        entries=base['postgres']['access']['entries']
        require(len(entries)==21 and sum(row['editable'] for row in entries)==19,'Baseline full catalog tidak lengkap.')
    require(snapshot(root)==base['sqlite'],'Fingerprint SQLite terproteksi berubah.')
    state=postgres(root);before=base['postgres'];stage=PHASES.index(phase)
    require(state['fingerprints']==before['fingerprints'],'Definisi/grant tersembunyi/akun/grup terproteksi berubah.')
    require(state['integrity']==state['recovery']=='PASS','Integrity/recovery gagal.')
    require(state['users']==before['users'],'Membership/security version berubah.')
    require(state['grant_counts']==before['grant_counts'],'Jumlah grants berubah.')
    expected=json.loads(json.dumps(before['groups']))
    revision=1 if stage<PHASES.index('save') else 2 if stage<PHASES.index('revoke') else 3 if stage<PHASES.index('conflict') else 4
    for row in expected:
        if row['id']==201:row['revision']=revision
    require(state['groups']==expected,'Metadata/status/revision grup berbeda.')
    access=state['access'];expected_access=json.loads(json.dumps(before['access']))
    expected_access['group']['revision']=revision
    for row in expected_access['entries']:
        if row['editable']:
            flags=acceptance_flags(row['sidebar']['id'],revision,full)
            for key,value in zip(('read','create','update','delete'),flags):row[key]=value
    require(access==expected_access,'Snapshot/hidden grant/catalog berbeda.')
    expected_audits=[('group_grants',201,'success')]*(revision-1)
    if stage>=PHASES.index('conflict'):expected_audits.append(('group_grants',201,'denied'))
    audits=state['audits']
    require([(a['action'],a['target_id'],a['result'])for a in audits]==expected_audits,'Jumlah/urutan audit berbeda.')
    require(all(a['actor_id']==101 and a['target_type']=='group' and re.fullmatch('[a-f0-9-]{36}',a['request_id'])for a in audits),'Actor/request ID tidak sah.')
    require(len({a['request_id']for a in audits})==len(audits),'Request ID duplikat.')
    for i,a in enumerate(a for a in audits if a['result']=='success'):
        require(a['before_state']['group']['revision']==i+1 and a['after_state']['group']['revision']==i+2,'Audit revision tidak konsisten.')
    if stage>=PHASES.index('conflict'):require(audits[-1]['reason_code']=='stale_revision','Konflik bukan stale revision.')
    probe=None
    if occupied(HTTP):
        helper(root,'http-check')
        probe=json.loads(helper(root,'probe'))
        want={a:(200 if revision==2 or (revision==4 and a=='read') else 403)for a in ('read','create','update','delete')}
        require(probe==want,'Backend permission probe tidak cocok dengan grants.')
    elif phase!='initial':raise RuntimeError('Backend Groups V2 diperlukan untuk membuktikan enforcement.')
    evidence=root/f'postcheck-{phase}-{time.time_ns()}.json'
    result={'marker':f'GROUPS_V2_{phase.upper().replace("-","_")}_PASS','profile':root.name.removeprefix('notaris-payment-'),'sqlite':base['sqlite'],'postgres':state,'backend_permission_probe':probe,'manual_visual':'OPERATOR MUST CONFIRM','operational_activation':'OFF'}
    with evidence.open('x',encoding='utf-8')as f:json.dump(result,f,indent=2)
    print(result['marker']);print(f'EVIDENCE={evidence}')


def prepare(full=False):
    require(os.name == 'nt', 'Windows DPAPI diperlukan.')
    require(not occupied(PORT) and not occupied(HTTP), 'Port acceptance terpakai.')
    with tempfile.TemporaryDirectory(prefix='notaris-groups-v2-build-') as folder:
        built = Path(folder).resolve(strict=True) / 'session.exe'
        auth['build_helper'](built)
        raw = json.loads(execute([built,'groups-v2-init-full' if full else 'groups-v2-init'],capture=True))
        profile = raw['profile']; root=root_for(profile)
        with (root / 'session.exe').open('xb') as f:
            f.write(built.read_bytes())
    print(f'NEW_GROUPS_V2_PROFILE={profile}',flush=True)
    pw = auth['plain'](root / 'initdb-password')
    try:
        execute([PG/'initdb.exe','-D',root/'pgdata','-U','groups_v2_owner','-A','scram-sha-256','--pwfile',pw,'--no-locale','-E','UTF8'],capture=True)
    finally:
        pw.unlink(missing_ok=True)
    cluster(root,'start')
    try:
        helper(root,'bootstrap')
        execute(['flutter.bat','test','--no-pub','test/database/groups_v2_acceptance_profile_test.dart','--reporter','expanded'],
                cwd=FRONT,env={**clean_env(),'NOTARIS_GROUPS_V2_PREPARE':profile},timeout=600)
        helper(root,'self-check')
        before = snapshot(root)
        require(before['counts']['transaksis']==2 and before['counts']['transaksi_riwayat_pembayaran']==2,'Fixture proteksi tidak lengkap.')
        with (root/'groups-v2-baseline.json').open('x',encoding='utf-8') as f:
            json.dump({'sqlite':before,'postgres':postgres(root), 'catalog':'full-v2.1' if full else 'reduced-v2'},f,indent=2)
        check(root,'initial')
    finally:
        cluster(root,'stop')
    print(f'PROFILE_DIRECTORY={root}')
    print('PREPARED: cluster stopped, evidence retained. Operator UI acceptance NOT started.')


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('action',choices=('prepare','backend','credential','launch','check','postcheck','state','conflict-edit','stop'))
    p.add_argument('--id');p.add_argument('--account');p.add_argument('--expect',choices=PHASES+tuple(ALIASES),default='initial')
    p.add_argument('--catalog',choices=('reduced','full'))
    args=p.parse_args()
    if args.action=='prepare':
        require(args.id is None,'Prepare wajib membuat profil BARU.');prepare(args.catalog=='full');return
    require(args.catalog is None,'Katalog hanya dapat dipilih saat membuat profil BARU.')
    root=root_for(args.id);pin(root)
    if args.action=='backend':
        if not occupied(PORT):cluster(root,'start')
        postgres(root)
        require(not occupied(HTTP),'Port HTTP terpakai; tidak mengambil proses lain.')
        helper(root,'serve',capture=False)
    elif args.action=='stop':
        require(not occupied(HTTP),'Tutup backend Ctrl+C dahulu.');cluster(root,'stop');print('GROUPS_V2_STOPPED_DATA_RETAINED')
    elif args.action=='credential':
        require(args.account is not None,'--account diperlukan.')
        print('Kredensial hanya di dialog Windows; jangan scan atau rekam password.',flush=True)
        helper(root,'credential',args.account,capture=False)
    elif args.action=='state':
        print(json.dumps(postgres(root),indent=2))
    elif args.action in ('check','postcheck'):
        check(root,args.expect)
    elif args.action=='conflict-edit':
        require((root / 'launch.lock').exists(), 'Buka Atur Akses CS revisi 3 di Flutter dahulu.')
        check(root,'backend-denied',concurrent_edit=True);print(helper(root,'conflict'))
    elif args.action=='launch':
        # State may be intentionally between phases. Do not force an old baseline.
        require(snapshot(root)==json.loads((root/'groups-v2-baseline.json').read_text())['sqlite'],'SQLite berubah.')
        postgres(root);helper(root,'http-check')
        lock=root/'launch.lock'
        with lock.open('x',encoding='ascii') as f:f.write(args.id)
        try:
            execute(['flutter.bat','run','-d','windows','--debug','--no-pub','-t','lib/groups_v2_acceptance_main.dart',
                     f'--dart-define=NOTARIS_GROUPS_V2_ID={args.id}',
                     f'--dart-define=NOTARIS_GROUPS_V2_HELPER_SHA256={auth["digest"](root/"session.exe")}'],cwd=FRONT,timeout=None)
        except BaseException:
            raise
        else:
            lock.unlink()
        require(snapshot(root)==json.loads((root/'groups-v2-baseline.json').read_text())['sqlite'],'SQLite berubah.')


if __name__=='__main__':
    try:main()
    except (OSError,ValueError,RuntimeError,KeyError,subprocess.SubprocessError) as error:
        raise SystemExit(f'BLOCKED: {error}') from None
    except KeyboardInterrupt:
        print('\nDihentikan; profil dipertahankan. Tidak ada reset/retry otomatis.')
