"""H02 only: NEW owned profile, ordinary main.dart, no operational target input."""
import argparse
import json
import os
from pathlib import Path
import runpy
import subprocess
import sqlite3
from contextlib import closing
import tempfile
import time

shared=runpy.run_path(str(Path(__file__).with_name('profile-v1-acceptance.py')))
auth,execute,require,snapshot,occupied,FRONT,PG=(shared[k] for k in ('auth','execute','require','snapshot','occupied','FRONT','PG'))
PHASES=('initial','read-only','create-denied','update-denied','delete-denied','no-grant','editor-create','editor-update','permission-refresh','session-switch','editor-delete','offline','restart','final')

def root_for(profile):
    root=shared['root_for'](profile)
    require(auth['plain'](root/'h02-owner').read_text(encoding='ascii')==profile,'Bukan profil H02 baru.')
    return root

PORT,HTTP=55802,55890

def helper(root,action,account=None,capture=True):
    args=[auth['plain'](root/'session.exe'),'h02-'+action,root.name.removeprefix('notaris-payment-')]
    if account is not None:args.append(account)
    return execute(args,capture=capture,timeout=None if action in ('serve','credential') else 45)

def state(root):return json.loads(helper(root,'state'))

def pin(root):
    with tempfile.TemporaryDirectory(prefix='notaris-h02-pin-') as folder:
        built=Path(folder).resolve(strict=True)/'session.exe';auth['build_helper'](built)
        require(auth['digest'](built)==auth['digest'](root/'session.exe'),'Helper berubah; STOP, tidak repin otomatis.')
    helper(root,'validate')

def cluster(root,action):
    data=auth['plain'](root/'pgdata',directory=True);require(data.parent==root,'Cluster bukan milik H02.')
    args=[PG/'pg_ctl.exe',action,'-D',data,'-w','-t','25']
    if action=='start':
        require(not occupied(PORT),'Port H02 terpakai; tidak mengambil instance lain.')
        args+=['-l',root/'postgres.log','-o',f'-h 127.0.0.1 -p {PORT} -c log_statement=none -c log_min_error_statement=panic -c log_parameter_max_length_on_error=0']
    else:
        require(action=='stop','Aksi cluster tidak valid.');state(root);args+=['-m','fast']
    result=subprocess.run([str(x) for x in args],env=shared['clean_env'](),stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=45)
    require(result.returncode==0,'pg_ctl H02 gagal; tidak retry otomatis.')

def categories(root):
    file=auth['plain'](root/'offline.sqlite')
    with closing(sqlite3.connect(file.as_uri()+'?mode=ro',uri=True)) as db:
        db.execute('PRAGMA query_only=ON');db.row_factory=sqlite3.Row
        return [dict(r) for r in db.execute('SELECT * FROM pekerjaan_kategori ORDER BY id')]

def verify_category(base,rows,phase,receipt=None):
    originals={r['id']:r for r in base}
    require([r for r in rows if r['id'] in originals]==base,'Kategori baseline berubah.')
    extra=[r for r in rows if r['id'] not in originals]
    expect_new=phase in {'editor-create','editor-update','permission-refresh','session-switch','editor-delete','offline','restart','final'}
    require(len(extra)==int(expect_new),'Jumlah kategori uji tidak sesuai; tidak cleanup/repair otomatis.')
    if not expect_new:return None
    r=extra[0]
    require(__import__('re').fullmatch('[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}',r['uuid']) is not None,'UUID kategori tidak sah.')
    require(r['created_by']==101 and r['updated_by']==(None if phase=='editor-create' else 101) and r['is_sync_dirty']==1 and r['last_synced_at'] is None,'Actor/dirty/ACK kategori salah.')
    require(r['nama']==('Kategori H02' if phase=='editor-create' else 'Kategori H02 diperiksa'),'Nama hasil UI tidak sesuai kontrak.')
    deleted=phase in {'editor-delete','offline','restart','final'}
    require(r['status']==(0 if deleted else 1) and (r['deleted_at'] is not None)==deleted,'Status soft delete berbeda.')
    if receipt is not None:require(r['id']==receipt['id'] and r['uuid']==receipt['uuid'] and r['created_at']==receipt['created_at'],'Identity/PK awal berubah.')
    return r

def verify_events(events,phase):
    require(all(e.get('event')!='http' or (e.get('allowed') is True and ((e.get('method')=='POST' and e.get('path')=='/api/v1/auth/login') or (e.get('method')=='GET' and e.get('path') in {'/api/v1/auth/me','/api/v1/auth/me/sidebar-access','/api/v1/development/profile-v1','/api/v1/profile'}))) for e in events),'Unexpected HTTP attempt.')
    require(all(e.get('event')!='global_outcome' or e.get('outcome')=='disabledByPolicy' for e in events),'Global sync outcome bukan disabled.')
    if phase=='initial':require(not events,'Profil sudah pernah diluncurkan.')
    else:
        require(any(e.get('event')=='entrypoint' and e.get('entry')=='lib/main.dart' and e.get('ui_smoke') is False and e.get('isolated_manual_configuration') is False for e in events),'Bukti entrypoint normal tidak ada.')
        require(any(e.get('event')=='session' and e.get('state')=='authenticated' for e in events),'Login runtime belum terbukti.')
    if phase in {'restart','final'}:require(any(e.get('event')=='restore' and e.get('restored') is True for e in events),'Restore sesi belum terbukti.')

def check(root,phase):
    require(not(root/'launch.lock').exists(),'Tutup Flutter; lock ambigu dipertahankan.')
    base=json.loads(auth['plain'](root/'h02-baseline.json').read_text())
    current=snapshot(root)
    for key in ('schema','integrity','fk'):require(current[key]==base['sqlite'][key],'SQLite integrity/schema berubah.')
    for key in ('counts','fingerprints'):require({k:v for k,v in current[key].items() if k!='pekerjaan_kategori'}=={k:v for k,v in base['sqlite'][key].items() if k!='pekerjaan_kategori'},'State terlindungi termasuk transaksi/Master/cursor/ACK berubah.')
    receipt_file=root/'h02-editor-row.json'
    receipt=json.loads(receipt_file.read_text()) if receipt_file.exists() else None
    row=verify_category(base['categories'],categories(root),phase,receipt)
    if row is not None and receipt is None:
        require(phase=='editor-create','Checkpoint CREATE belum tersedia.')
        with receipt_file.open('x',encoding='utf-8') as f:json.dump(row,f,indent=2)
    actual=state(root);require(actual==base['postgres'],'PostgreSQL disposable/grants berubah.')
    log=root/'h02-events.jsonl';events=[json.loads(line) for line in log.read_text().splitlines()] if log.exists() else []
    verify_events(events,phase)
    result={'marker':'H02_'+phase.upper().replace('-','_')+'_PASS','profile':root.name.removeprefix('notaris-payment-'),'sqlite':current,'postgres':actual,'category':row,'manual_visual':'OPERATOR MUST CONFIRM','operational_activation':'OFF'}
    evidence=root/f'h02-postcheck-{phase}-{time.time_ns()}.json'
    with evidence.open('x',encoding='utf-8') as f:json.dump(result,f,indent=2)
    print(result['marker']);print(f'EVIDENCE={evidence}')

def prepare():
    require(os.name=='nt' and not occupied(PORT) and not occupied(HTTP),'Windows/port disposable diperlukan.')
    with tempfile.TemporaryDirectory(prefix='notaris-h02-build-') as folder:
        built=Path(folder).resolve(strict=True)/'session.exe';auth['build_helper'](built)
        profile=json.loads(execute([built,'h02-init'],capture=True))['profile']
        root=shared['root_for'](profile)
        with(root/'session.exe').open('xb') as f:f.write(built.read_bytes())
    print(f'NEW_H02_PROFILE={profile}',flush=True)
    pw=auth['plain'](root/'initdb-password')
    try:execute([PG/'initdb.exe','-D',root/'pgdata','-U','profile_v1_owner','-A','scram-sha-256','--pwfile',pw,'--no-locale','-E','UTF8'],capture=True)
    finally:pw.unlink(missing_ok=True)
    cluster(root,'start')
    try:
        helper(root,'bootstrap')
        before=state(root);helper(root,'self-check');require(state(root)==before,'Self-check mengubah state.')
        for test,variable in [('profile_v1_acceptance_profile_test.dart','NOTARIS_PROFILE_V1_PREPARE'),('h02_acceptance_profile_test.dart','NOTARIS_H02_PREPARE')]:
            execute(['flutter.bat','test','--no-pub',f'test/database/{test}','--reporter','expanded'],cwd=FRONT,env={**shared['clean_env'](),variable:profile},timeout=600)
        with(root/'h02-baseline.json').open('x',encoding='utf-8') as f:json.dump({'sqlite':snapshot(root),'categories':categories(root),'postgres':state(root)},f,indent=2)
        check(root,'initial')
    finally:cluster(root,'stop')
    print(f'PROFILE_DIRECTORY={root}\nPREPARED: stopped; operator Windows acceptance PENDING.')

def finish_prepare(root):
    # Only the NEW, not-yet-accepted H02 profile whose Flutter fixture never
    # started. No cluster init/bootstrap replay, reset, repin or baseline rewrite.
    require(not(root/'offline.sqlite').exists() and not(root/'h02-baseline.json').exists() and not(root/'h02-events.jsonl').exists(),'Fixture sudah ada/ambigu; STOP.')
    require((root/'bootstrap-committed.json').exists(),'Go bootstrap belum committed.')
    with(root/'h02-finish-attempted.lock').open('x',encoding='ascii') as f:f.write(root.name)
    require(not occupied(PORT) and not occupied(HTTP),'Port H02 terpakai.')
    cluster(root,'start')
    try:
        before=state(root);helper(root,'self-check');require(state(root)==before,'Self-check mengubah state.')
        profile=root.name.removeprefix('notaris-payment-')
        for test,variable in [('profile_v1_acceptance_profile_test.dart','NOTARIS_PROFILE_V1_PREPARE'),('h02_acceptance_profile_test.dart','NOTARIS_H02_PREPARE')]:
            execute(['flutter.bat','test','--no-pub',f'test/database/{test}','--reporter','expanded'],cwd=FRONT,env={**shared['clean_env'](),variable:profile},timeout=600)
        with(root/'h02-baseline.json').open('x',encoding='utf-8') as f:json.dump({'sqlite':snapshot(root),'categories':categories(root),'postgres':state(root)},f,indent=2)
        check(root,'initial')
    finally:cluster(root,'stop')
    print(f'PROFILE_DIRECTORY={root}\nPREPARED: stopped; manual Windows acceptance PENDING.')

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('action',choices=['prepare','finish-prepare','backend','credential','launch','postcheck','stop']);p.add_argument('--id');p.add_argument('--account',choices=['admin.profile','user.profile','admin.biasa','recovery.profile']);p.add_argument('--expect',choices=PHASES,default='initial');a=p.parse_args()
    if a.action=='prepare':prepare();return
    root=root_for(a.id);pin(root)
    if a.action=='finish-prepare':finish_prepare(root)
    elif a.action=='backend':
        if not occupied(PORT):cluster(root,'start')
        state(root);require(not occupied(HTTP),'Port HTTP terpakai.');helper(root,'serve',capture=False)
    elif a.action=='credential':require(a.account is not None,'--account diperlukan.');helper(root,'credential',a.account,capture=False)
    elif a.action=='postcheck':check(root,a.expect)
    elif a.action=='stop':require(not occupied(HTTP),'Tutup backend dengan Ctrl+C.');cluster(root,'stop');print('H02_STOPPED_DATA_RETAINED')
    elif a.action=='launch':
        # Read-only ready check, not INITIAL: relaunches preserve evidence.
        base=json.loads((root/'h02-baseline.json').read_text());require(state(root)==base['postgres'],'PostgreSQL baseline berubah.')
        # Check every protected table before relaunch; only the receipt-owned
        # category lifecycle may differ after approved UI actions.
        current=snapshot(root)
        for key in ('counts','fingerprints'):require({k:v for k,v in current[key].items() if k!='pekerjaan_kategori'}=={k:v for k,v in base['sqlite'][key].items() if k!='pekerjaan_kategori'},'Protected SQLite berubah.')
        require(occupied(HTTP),'Backend disposable harus berjalan.')
        with(root/'launch.lock').open('x',encoding='ascii') as f:f.write(a.id)
        launch=str(time.time_ns());log=root/'h02-events.jsonl'
        with log.open('a',encoding='utf-8') as f:f.write(json.dumps({'event':'launch_start','unix_ms':time.time_ns()//1000000,'launch':launch})+'\n')
        execute(['flutter.bat','run','-d','windows','--debug','--no-pub','-t','lib/main.dart',f'--dart-define=NOTARIS_H02_ID={a.id}',f'--dart-define=NOTARIS_H02_LAUNCH={launch}',f'--dart-define=NOTARIS_H02_HELPER_SHA256={auth["digest"](root/"session.exe")}'],cwd=FRONT,timeout=None)
        with log.open('a',encoding='utf-8') as f:f.write(json.dumps({'event':'launch_closed','unix_ms':time.time_ns()//1000000,'launch':launch})+'\n')
        (root/'launch.lock').unlink()
        print('H02_LAUNCH_CLOSED: run matching postcheck; no automatic retry.')

if __name__=='__main__':
    try:main()
    except (OSError,ValueError,RuntimeError,KeyError) as e:raise SystemExit(f'BLOCKED: {e}') from None
    except KeyboardInterrupt:print('STOP: evidence/lock retained; no automatic reset.')
