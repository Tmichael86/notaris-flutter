"""New Windows-owned Profile read-only acceptance; no operational target input."""
import argparse
import json
from pathlib import Path
import os
import re
import runpy
import subprocess
import tempfile
import time

shared=runpy.run_path(str(Path(__file__).with_name('groups-v2-acceptance.py')))
auth=shared['auth']
execute,clean_env,occupied,snapshot,require=(shared[k]for k in ('execute','clean_env','occupied','snapshot','require'))
FRONT,PG=shared['FRONT'],shared['PG']
PORT,HTTP=55800,55888
PHASES=('initial','view','edit','save','reopen','refresh','forged-denied','inactive-denied','offline','restart','final')

def root_for(profile):
    require(re.fullmatch('[a-f0-9]{32}',profile or ''),'ID Profile V1 diperlukan.')
    root=auth['plain'](Path(tempfile.gettempdir()).resolve()/f'notaris-payment-{profile}',directory=True)
    for name in ('owner','profile-v1-owner'):
        require(auth['plain'](root/name).read_text(encoding='ascii')==profile,'Profil bukan Profile V1 baru.')
    require(not(root/'groups-v2-owner').exists() and not(root/'promotional-owner').exists(),'Profil lama terlarang.')
    return root

def helper(root,action,account=None,capture=True):
    args=[auth['plain'](root/'session.exe'),'profile-v1-'+action,root.name.removeprefix('notaris-payment-')]
    if account is not None:args.append(account)
    return execute(args,capture=capture,timeout=None if action in ('serve','credential')else 45)

def pin(root):
    with tempfile.TemporaryDirectory(prefix='notaris-profile-pin-')as folder:
        built=Path(folder).resolve(strict=True)/'session.exe';auth['build_helper'](built)
        require(auth['digest'](built)==auth['digest'](root/'session.exe'),'Source/helper berubah; tidak repin otomatis.')
    helper(root,'validate')

def cluster(root,action):
    data=auth['plain'](root/'pgdata',directory=True)
    require(data.parent==root,'Cluster bukan milik profil.')
    args=[PG/'pg_ctl.exe',action,'-D',data,'-w','-t','25']
    if action=='start':
        require(not occupied(PORT),'Port Profile terpakai; tidak mengambil instance lain.')
        args+=['-l',root/'postgres.log','-o',f'-h 127.0.0.1 -p {PORT} -c log_statement=none -c log_min_error_statement=panic -c log_parameter_max_length_on_error=0']
    else:
        require(action=='stop','Aksi cluster tidak sah.');helper(root,'state');args+=['-m','fast']
    result=subprocess.run([str(x)for x in args],env=clean_env(),stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=45)
    require(result.returncode==0,'pg_ctl gagal; tidak retry otomatis.')

def state(root):return json.loads(helper(root,'state'))

def verify_delta(base,current,phase):
    require(current['integrity']==current['recovery']==current['least_privilege']=='PASS','Integrity/recovery/privilege gagal.')
    require(current['protected']==base['protected'],'State terlindungi PostgreSQL berubah.')
    original=base['profile'];p=current['profile'];audits=current['audits']
    fixed=('id','username','email','group_id','group_nama','group_jenis','status')
    require(all(p[k]==original[k]for k in fixed),'Identity/membership berubah.')
    require(original['id']==201 and original['revision']==1 and base['audits']==[],'Baseline bukan profil baru.')
    after=p['revision']==2
    require(p['revision']in(1,2),'Revision di luar satu Save acceptance.')
    if phase in('initial','view','edit'):require(not after,'Save belum diizinkan pada checkpoint ini.')
    if phase in('save','reopen','refresh','forged-denied','inactive-denied','restart','final'):require(after,'Save terverifikasi diperlukan.')
    if not after:
        require(p==original and audits==[] and current['audit_sequence']==base['audit_sequence'],'State awal berubah.')
    else:
        require((p['nama'],p['no_telp'],p['alamat'])==('Rani Profil Diperbarui','+62 812-3456-7890','Alamat demonstrasi diperbarui'),'Field hasil Save tidak cocok.')
        require(len(audits)==1,'Exactly one audit required.')
        a=audits[0]
        require(a['actor_id']==a['target_id']==201 and a['action']=='profile_self_update' and a['target_type']=='self_profile' and a['result']=='success' and a['source']=='online_admin_api','Audit self-service tidak sah.')
        require(re.fullmatch('[a-f0-9-]{36}',a['request_id'])is not None,'Request ID audit invalid.')
        require(a['before_state']=={'revision':1,'fields':['nama','no_telp','alamat'],'origin':'self_service_profile'} and a['after_state']=={'revision':2,'fields':['nama','no_telp','alamat'],'origin':'self_service_profile'},'Audit revision/summary invalid.')
        require(current['audit_sequence']=={'LastValue':1,'IsCalled':True},'Audit sequence unexpected.')

def check(root,phase):
    require(not(root/'launch.lock').exists(),'Tutup Flutter dahulu; lock ambigu dipertahankan.')
    base=json.loads(auth['plain'](root/'profile-v1-baseline.json').read_text())
    require(snapshot(root)==base['sqlite'],'Fingerprint SQLite terlindungi berubah.')
    current=state(root);verify_delta(base['postgres'],current,phase)
    if occupied(HTTP):helper(root,'http-check')
    else:require(phase in('initial','offline'),'Backend diperlukan untuk checkpoint ini.')
    result={'marker':'PROFILE_V1_'+phase.upper().replace('-','_')+'_PASS','profile':root.name.removeprefix('notaris-payment-'),'sqlite':base['sqlite'],'postgres':current,'manual_visual':'OPERATOR MUST CONFIRM','operational_activation':'OFF'}
    evidence=root/f'postcheck-{phase}-{time.time_ns()}.json'
    with evidence.open('x',encoding='utf-8')as f:json.dump(result,f,indent=2)
    print(result['marker']);print(f'EVIDENCE={evidence}');print(f"USER=201 REVISION={current['profile']['revision']} AUDITS={len(current['audits'])}")

def prepare():
    require(os.name=='nt' and not occupied(PORT) and not occupied(HTTP),'Windows/port disposable tidak tersedia.')
    with tempfile.TemporaryDirectory(prefix='notaris-profile-build-')as folder:
        built=Path(folder).resolve(strict=True)/'session.exe';auth['build_helper'](built)
        profile=json.loads(execute([built,'profile-v1-init'],capture=True))['profile'];root=root_for(profile)
        with(root/'session.exe').open('xb')as f:f.write(built.read_bytes())
    print(f'NEW_PROFILE_V1_PROFILE={profile}',flush=True)
    pw=auth['plain'](root/'initdb-password')
    try:execute([PG/'initdb.exe','-D',root/'pgdata','-U','profile_v1_owner','-A','scram-sha-256','--pwfile',pw,'--no-locale','-E','UTF8'],capture=True)
    finally:pw.unlink(missing_ok=True)
    cluster(root,'start')
    try:
        helper(root,'bootstrap');before=state(root);helper(root,'self-check')
        require(state(root)==before,'Self-check mengubah state.')
        execute(['flutter.bat','test','--no-pub','test/database/profile_v1_acceptance_profile_test.dart','--reporter','expanded'],cwd=FRONT,env={**clean_env(),'NOTARIS_PROFILE_V1_PREPARE':profile},timeout=600)
        with(root/'profile-v1-baseline.json').open('x',encoding='utf-8')as f:json.dump({'sqlite':snapshot(root),'postgres':state(root)},f,indent=2)
        check(root,'initial')
    finally:cluster(root,'stop')
    print(f'PROFILE_DIRECTORY={root}\nPREPARED: cluster stopped; manual Windows acceptance NOT started.')

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('action',choices=('prepare','backend','credential','launch','postcheck','check','state','stop'));p.add_argument('--id');p.add_argument('--account',choices=('admin.profile','recovery.profile','user.profile','admin.biasa','inactive.profile','groupinactive.profile'));p.add_argument('--expect',choices=PHASES,default='initial');args=p.parse_args()
    if args.action=='prepare':require(args.id is None,'Prepare wajib profil BARU.');prepare();return
    root=root_for(args.id);pin(root)
    if args.action=='backend':
        if not occupied(PORT):cluster(root,'start')
        state(root);require(not occupied(HTTP),'Port HTTP terpakai.');helper(root,'serve',capture=False)
    elif args.action=='credential':require(args.account is not None,'--account diperlukan.');helper(root,'credential',args.account,capture=False)
    elif args.action in ('check','postcheck'):check(root,args.expect)
    elif args.action=='state':print(json.dumps(state(root),indent=2))
    elif args.action=='stop':require(not occupied(HTTP),'Tutup backend Ctrl+C dahulu.');cluster(root,'stop');print('PROFILE_V1_STOPPED_DATA_RETAINED')
    elif args.action=='launch':
        check(root,'ready');lock=root/'launch.lock'
        with lock.open('x',encoding='ascii')as f:f.write(args.id)
        try:execute(['flutter.bat','run','-d','windows','--debug','--no-pub','-t','lib/profile_v1_acceptance_main.dart',f'--dart-define=NOTARIS_PROFILE_V1_ID={args.id}',f'--dart-define=NOTARIS_PROFILE_V1_HELPER_SHA256={auth["digest"](root/"session.exe")}'],cwd=FRONT,timeout=None)
        except BaseException:raise
        else:lock.unlink()
        check(root,'ready' if occupied(HTTP)else'offline')

if __name__=='__main__':
    try:main()
    except (OSError,ValueError,RuntimeError,KeyError,subprocess.SubprocessError)as error:raise SystemExit(f'BLOCKED: {error}')from None
    except KeyboardInterrupt:print('\nDihentikan; evidence dan lock dipertahankan. Tidak ada reset otomatis.')
