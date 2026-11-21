"""H01 only: NEW owned profile, ordinary main.dart, no operational target input."""
import argparse
import json
import os
from pathlib import Path
import runpy
import subprocess
import tempfile
import time

shared=runpy.run_path(str(Path(__file__).with_name('profile-v1-acceptance.py')))
auth,execute,require,snapshot,occupied,FRONT,PG=(shared[k] for k in ('auth','execute','require','snapshot','occupied','FRONT','PG'))
PHASES=('initial','login','restore','wait','resume','reconnect','direct-block','status','restart','final')

def root_for(profile):
    root=shared['root_for'](profile)
    require(auth['plain'](root/'h01-owner').read_text(encoding='ascii')==profile,'Bukan profil H01 baru.')
    return root

PORT,HTTP=55801,55889

def helper(root,action,account=None,capture=True):
    args=[auth['plain'](root/'session.exe'),'h01-'+action,root.name.removeprefix('notaris-payment-')]
    if account is not None:args.append(account)
    return execute(args,capture=capture,timeout=None if action in ('serve','credential') else 45)

def state(root):return json.loads(helper(root,'state'))

def pin(root):
    with tempfile.TemporaryDirectory(prefix='notaris-h01-pin-') as folder:
        built=Path(folder).resolve(strict=True)/'session.exe';auth['build_helper'](built)
        require(auth['digest'](built)==auth['digest'](root/'session.exe'),'Helper berubah; STOP, tidak repin otomatis.')
    helper(root,'validate')

def cluster(root,action):
    data=auth['plain'](root/'pgdata',directory=True);require(data.parent==root,'Cluster bukan milik H01.')
    args=[PG/'pg_ctl.exe',action,'-D',data,'-w','-t','25']
    if action=='start':
        require(not occupied(PORT),'Port H01 terpakai; tidak mengambil instance lain.')
        args+=['-l',root/'postgres.log','-o',f'-h 127.0.0.1 -p {PORT} -c log_statement=none -c log_min_error_statement=panic -c log_parameter_max_length_on_error=0']
    else:
        require(action=='stop','Aksi cluster tidak valid.');state(root);args+=['-m','fast']
    result=subprocess.run([str(x) for x in args],env=shared['clean_env'](),stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=45)
    require(result.returncode==0,'pg_ctl H01 gagal; tidak retry otomatis.')

def verify_events(events,phase):
    require(all(e.get('event')!='http' or (e.get('allowed') is True and ((e.get('method')=='POST' and e.get('path')=='/api/v1/auth/login') or (e.get('method')=='GET' and e.get('path') in {'/api/v1/auth/me','/api/v1/auth/me/sidebar-access','/api/v1/development/profile-v1','/api/v1/profile'}))) for e in events),'Unexpected HTTP attempt: STOP; tidak retry/reset.')
    require(all(e.get('event')!='global_outcome' or e.get('outcome')=='disabledByPolicy' for e in events),'Outcome global bukan DISABLED_BY_POLICY.')
    if phase=='initial':require(not events,'Profil sudah pernah diluncurkan.')
    else:
        require(any(e.get('event')=='entrypoint' and e.get('entry')=='lib/main.dart' and e.get('ui_smoke') is False and e.get('isolated_manual_configuration') is False for e in events),'Bukti normal entrypoint tidak ada.')
        require(any(e.get('event')=='session' and e.get('state')=='authenticated' for e in events),'Login runtime belum terbukti.')
    if phase in ('restore','restart','final'):require(any(e.get('event')=='restore' and e.get('restored') is True for e in events),'Session restoration belum terbukti; remember-me diperlukan.')
    if phase in ('direct-block','final'):require(any(e.get('event')=='global_outcome' and e.get('outcome')=='disabledByPolicy' for e in events),'Direct block belum diuji melalui tombol Sinkronkan kategori.')
    if phase in ('resume','final'):
        inactive=False;resumed=False
        for e in events:
            if e.get('event')=='lifecycle':
                if e.get('state') in ('inactive','hidden','paused'):inactive=True
                if inactive and e.get('state')=='resumed':resumed=True
        require(resumed,'Minimize/restore runtime belum terbukti.')
    if phase in ('reconnect','final'):
        failed=False;reconnected=False
        for e in events:
            if e.get('event')=='http_error' and e.get('kind') in ('connectionError','connectionTimeout','receiveTimeout'):failed=True
            if failed and e.get('event')=='http_response' and e.get('status')==200:reconnected=True
        require(reconnected,'Backend outage dan read-only reconnect belum terbukti.')
    if phase in ('wait','final'):
        entries=[e for e in events if e.get('event')=='session' and e.get('state')=='authenticated']
        stops=[e for e in events if e.get('event')=='launch_closed']
        require(any(stop['unix_ms']-start['unix_ms']>=330000 for start in entries if 'unix_ms' in start for stop in stops if stop.get('launch')==start.get('launch')),'WAIT belum mencapai 5m30s dalam satu launch.')

def check(root,phase):
    require(not(root/'launch.lock').exists(),'Tutup Flutter; lock ambigu dipertahankan.')
    base=json.loads(auth['plain'](root/'h01-baseline.json').read_text())
    current=snapshot(root);require(current==base['sqlite'],'Fingerprint SQLite berbeda; tidak memperbaiki baseline.')
    actual=state(root);require(actual==base['postgres'],'PostgreSQL disposable berubah.')
    log=root/'h01-events.jsonl'
    events=[json.loads(line) for line in log.read_text().splitlines()] if log.exists() else []
    verify_events(events,phase)
    result={'marker':'H01_'+phase.upper().replace('-','_')+'_PASS','profile':root.name.removeprefix('notaris-payment-'),'sqlite':current,'postgres':actual,'http_attempts':len([e for e in events if e.get('event')=='http']),'manual_visual':'OPERATOR MUST CONFIRM','operational_activation':'OFF'}
    evidence=root/f'h01-postcheck-{phase}-{time.time_ns()}.json'
    with evidence.open('x',encoding='utf-8') as f:json.dump(result,f,indent=2)
    print(result['marker']);print(f'EVIDENCE={evidence}')

def prepare():
    require(os.name=='nt' and not occupied(PORT) and not occupied(HTTP),'Windows/port disposable diperlukan.')
    with tempfile.TemporaryDirectory(prefix='notaris-h01-build-') as folder:
        built=Path(folder).resolve(strict=True)/'session.exe';auth['build_helper'](built)
        profile=json.loads(execute([built,'h01-init'],capture=True))['profile']
        root=shared['root_for'](profile)
        with(root/'session.exe').open('xb') as f:f.write(built.read_bytes())
    print(f'NEW_H01_PROFILE={profile}',flush=True)
    pw=auth['plain'](root/'initdb-password')
    try:execute([PG/'initdb.exe','-D',root/'pgdata','-U','profile_v1_owner','-A','scram-sha-256','--pwfile',pw,'--no-locale','-E','UTF8'],capture=True)
    finally:pw.unlink(missing_ok=True)
    cluster(root,'start')
    try:
        helper(root,'bootstrap')
        before=state(root);helper(root,'self-check');require(state(root)==before,'Self-check mengubah state.')
        for test,variable in [('profile_v1_acceptance_profile_test.dart','NOTARIS_PROFILE_V1_PREPARE'),('h01_acceptance_profile_test.dart','NOTARIS_H01_PREPARE')]:
            execute(['flutter.bat','test','--no-pub',f'test/database/{test}','--reporter','expanded'],cwd=FRONT,env={**shared['clean_env'](),variable:profile},timeout=600)
        with(root/'h01-baseline.json').open('x',encoding='utf-8') as f:json.dump({'sqlite':snapshot(root),'postgres':state(root)},f,indent=2)
        check(root,'initial')
    finally:cluster(root,'stop')
    print(f'PROFILE_DIRECTORY={root}\nPREPARED: stopped; operator Windows acceptance PENDING.')

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('action',choices=['prepare','backend','credential','launch','postcheck','stop']);p.add_argument('--id');p.add_argument('--account',choices=['admin.profile','user.profile']);p.add_argument('--expect',choices=PHASES,default='initial');a=p.parse_args()
    if a.action=='prepare':prepare();return
    root=root_for(a.id);pin(root)
    if a.action=='backend':
        if not occupied(PORT):cluster(root,'start')
        state(root);require(not occupied(HTTP),'Port HTTP terpakai.');helper(root,'serve',capture=False)
    elif a.action=='credential':require(a.account is not None,'--account diperlukan.');helper(root,'credential',a.account,capture=False)
    elif a.action=='postcheck':check(root,a.expect)
    elif a.action=='stop':require(not occupied(HTTP),'Tutup backend dengan Ctrl+C.');cluster(root,'stop');print('H01_STOPPED_DATA_RETAINED')
    elif a.action=='launch':
        # Read-only ready check, not INITIAL: relaunches preserve evidence.
        base=json.loads((root/'h01-baseline.json').read_text());require(snapshot(root)==base['sqlite'] and state(root)==base['postgres'],'Baseline berubah.')
        require(occupied(HTTP),'Backend disposable harus berjalan.')
        with(root/'launch.lock').open('x',encoding='ascii') as f:f.write(a.id)
        launch=str(time.time_ns());log=root/'h01-events.jsonl'
        with log.open('a',encoding='utf-8') as f:f.write(json.dumps({'event':'launch_start','unix_ms':time.time_ns()//1000000,'launch':launch})+'\n')
        execute(['flutter.bat','run','-d','windows','--debug','--no-pub','-t','lib/main.dart',f'--dart-define=NOTARIS_H01_ID={a.id}',f'--dart-define=NOTARIS_H01_LAUNCH={launch}',f'--dart-define=NOTARIS_H01_HELPER_SHA256={auth["digest"](root/"session.exe")}'],cwd=FRONT,timeout=None)
        with log.open('a',encoding='utf-8') as f:f.write(json.dumps({'event':'launch_closed','unix_ms':time.time_ns()//1000000,'launch':launch})+'\n')
        (root/'launch.lock').unlink()
        print('H01_LAUNCH_CLOSED: run matching postcheck; no automatic retry.')

if __name__=='__main__':
    try:main()
    except (OSError,ValueError,RuntimeError,KeyError) as e:raise SystemExit(f'BLOCKED: {e}') from None
    except KeyboardInterrupt:print('STOP: evidence/lock retained; no automatic reset.')
