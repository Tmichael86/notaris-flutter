# Disposable PostgreSQL only. No restore and no connection to permanent port 5432.
param([string]$PostgresBin='D:\Program Files\PostgreSQL\bin')
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'notaris-psql-process.ps1')
$root=Join-Path ([IO.Path]::GetTempPath()) ('notaris-grants-test-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root|Out-Null
$data=Join-Path $root 'data';$sqlRoot=Join-Path $repo 'backend-notaris-go/migration_proposals'
$keys=@('PGHOST','PGPORT','PGDATABASE','PGUSER','PGPASSWORD','PGOPTIONS','NOTARIS_SYNC_TEST_DSN','NOTARIS_READINESS_TEST_DSN','NOTARIS_FIXTURE_HTTP_DSN','NOTARIS_FLUTTER_E2E')
$previous=@{};foreach($key in $keys){$previous[$key]=[Environment]::GetEnvironmentVariable($key)}
$location=Get-Location;$started=$false;$passed=0
$psql=Join-Path $PostgresBin 'psql.exe'
function Check([bool]$Condition,[string]$Name){if(!$Condition){throw "FAILED: $Name ($root)"};$script:passed++;Write-Output "PASS: $Name"}
function Run-File([string]$Name,[string]$File,[hashtable]$Variables=@{},[bool]$Success=$true){
 $r=Invoke-NotarisPsqlFile -Executable $psql -File $File -Log (Join-Path $root ($Name+'.log')) -Variables $Variables
 if(($Success -and $r.ExitCode -ne 0) -or (!$Success -and $r.ExitCode -ne 3)){throw "Unexpected SQL exit $($r.ExitCode): $Name; $root"}
 return $r
}
function Exec([string]$Name,[string]$Text){
 $file=Join-Path $root ($Name+'.sql');$Text|Set-Content $file
 $null=Run-File $Name $file
}
function Read-Json([string]$Name,[string]$Query){
 Exec $Name ("\pset format unaligned`n\pset tuples_only on`n"+$Query)
 return Get-Content (Join-Path $root ($Name+'.log'))|Where-Object {$_ -match '^\{'}|ConvertFrom-Json
}
function Assert-AppUngrant([string]$Name){
 $j=Read-Json $Name "SELECT json_build_object('granted',COALESCE(has_table_privilege('recovery_app',to_regclass('public.petugas_sync_mutations')::oid,'SELECT'),false) OR COALESCE(has_table_privilege('recovery_app',to_regclass('public.petugas_sync_outbox')::oid,'SELECT'),false) OR COALESCE(has_table_privilege('recovery_app',to_regclass('public.petugas_sync_publication')::oid,'SELECT'),false) OR COALESCE(has_sequence_privilege('recovery_app',to_regclass('public.petugas_sync_outbox_id_seq')::oid,'USAGE'),false));"
 Check (!$j.granted) 'refusal leaves app sync privileges untouched'
}
try {
 $probe=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,55443);try{$probe.Start()}finally{$probe.Stop()}
 $p=Start-Process -FilePath (Join-Path $PostgresBin 'initdb.exe') -ArgumentList @('-D',('"'+$data+'"'),'-U','notaris_test','--auth=trust','--encoding=UTF8','--no-locale') -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput (Join-Path $root 'init.log') -RedirectStandardError (Join-Path $root 'init.stderr')
 if($p.ExitCode -ne 0){throw 'initdb failed'}
 $ctl=Start-Process -FilePath (Join-Path $PostgresBin 'pg_ctl.exe') -ArgumentList @('-D',('"'+$data+'"'),'-l',('"'+(Join-Path $root 'postgres.log')+'"'),'-o','"-h 127.0.0.1 -p 55443"','-w','start') -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $root 'start.log') -RedirectStandardError (Join-Path $root 'start.stderr')
 $started=$true;$handle=$ctl.Handle
 if(!$ctl.WaitForExit(45000) -or $ctl.ExitCode -ne 0){throw 'owned PostgreSQL start failed'}
 $env:PGHOST='127.0.0.1';$env:PGPORT='55443';$env:PGDATABASE='postgres';$env:PGUSER='notaris_test'
 Remove-Item Env:PGPASSWORD,Env:PGOPTIONS -ErrorAction SilentlyContinue
 $owned=Read-Json 'owned' "SELECT json_build_object('directory',current_setting('data_directory'),'port',inet_server_port());"
 if([IO.Path]::GetFullPath($owned.directory) -ne [IO.Path]::GetFullPath($data) -or $owned.port -ne 55443){throw 'Wrong cluster; no database creation allowed'}
 Exec 'create-db' 'CREATE DATABASE notarisdev TEMPLATE template0;'
 $env:PGDATABASE='notarisdev'
 Exec 'fixture' @'
CREATE TABLE konfigurasi_umum(id bigint PRIMARY KEY,notaris_bersangkutan text);
INSERT INTO konfigurasi_umum VALUES(1,'NOTARISDEV SYNTHETIC v1');
CREATE TABLE jenis_kelamin(id integer PRIMARY KEY,status smallint);
CREATE TABLE users(id integer PRIMARY KEY,status smallint);
INSERT INTO jenis_kelamin VALUES(11,1),(29,1); INSERT INTO users VALUES(2001,1);
CREATE TABLE petugas(id bigserial PRIMARY KEY,nik varchar,nama varchar NOT NULL,alamat varchar,
 tempat_lahir varchar,tanggal_lahir date,jenis_kelamin integer,no_telp varchar,email varchar NOT NULL,
 user_id integer,created_by integer,updated_by integer,created_at timestamp,updated_at timestamp,status smallint NOT NULL);
INSERT INTO petugas(id,nama,email,jenis_kelamin,user_id,status) SELECT i,'Synthetic '||i,'fixture'||i||'@example.invalid',CASE WHEN i%2=0 THEN 11 ELSE 29 END,2001,1 FROM generate_series(101,104)i;
CREATE TABLE transaksi(id bigint PRIMARY KEY,petugas_id bigint,note text);
CREATE TABLE transaksi_detail_proses(id bigint PRIMARY KEY,transaksi_id bigint,note text);
CREATE TABLE transaksi_riwayat_pembayaran(id bigint PRIMARY KEY,transaksi_id bigint,note text);
INSERT INTO transaksi SELECT i,i-400,'Synthetic transaction' FROM generate_series(501,504)i;
INSERT INTO transaksi_detail_proses SELECT i,i-100,'Synthetic detail' FROM generate_series(601,604)i;
INSERT INTO transaksi_riwayat_pembayaran SELECT i,i-200,'Synthetic payment' FROM generate_series(701,704)i;
CREATE ROLE recovery_app LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE;
GRANT CONNECT ON DATABASE notarisdev TO recovery_app;
GRANT USAGE ON SCHEMA public TO recovery_app;
GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA public TO recovery_app;
GRANT USAGE,SELECT,UPDATE ON ALL SEQUENCES IN SCHEMA public TO recovery_app;
'@
 $snapshotQuery=@'
SELECT json_build_object('petugas',(SELECT md5(COALESCE(jsonb_agg(to_jsonb(p)-ARRAY['uuid','row_version','deleted_at'] ORDER BY id)::text,'[]')) FROM petugas p),
 'tx',(SELECT md5(jsonb_agg(to_jsonb(t) ORDER BY id)::text) FROM transaksi t),
 'detail',(SELECT md5(jsonb_agg(to_jsonb(t) ORDER BY id)::text) FROM transaksi_detail_proses t),
 'payment',(SELECT md5(jsonb_agg(to_jsonb(t) ORDER BY id)::text) FROM transaksi_riwayat_pembayaran t),
 'uuid',(SELECT md5(string_agg(id::text||':'||(to_jsonb(p)->>'uuid'),',' ORDER BY id)) FROM petugas p));
'@
 $before=Read-Json 'before' $snapshotQuery
 $migrationRoot=(Join-Path $repo 'backend-notaris-go/migrations').Replace('\','/')
 Exec 'phase1' ("BEGIN;`n\i '$migrationRoot/20261029_01_petugas_cloud_sync.sql'`nCOMMIT;")
 $assigned=Read-Json 'assigned' $snapshotQuery
 $vars=@{EXPECTED_PORT='55443';NOTARIS_DEV_APP_ROLE='recovery_app';PETUGAS_HASH=$before.petugas;UUID_HASH=$assigned.uuid;TRANSACTION_HASH=$before.tx;DETAIL_HASH=$before.detail;PAYMENT_HASH=$before.payment}
 $verify=Join-Path $sqlRoot 'verify_petugas_grants.sql';$apply=Join-Path $sqlRoot 'recover_petugas_grants_only.sql'
 $null=Run-File 'phase1-refused' $verify $vars $false;Check $true 'phase1-only migration refuses recovery';Assert-AppUngrant 'phase1-grants'
 Exec 'phase2' ("\i '$migrationRoot/20261030_01_petugas_publication.sql'")
 $null=Run-File 'phase2-refused' $verify $vars $false;Check $true 'missing UUID hardening refuses recovery';Assert-AppUngrant 'phase2-grants'
 Exec 'phase3' ("\i '$migrationRoot/20261030_02_petugas_uuid_hardening.sql'")
 $null=Run-File 'verified' $verify $vars;Check $true 'complete schema verified read-only, before grants'
 Assert-AppUngrant 'verify-only-grants'
 $null=Run-File 'approval-missing' $apply $vars $false;Check $true 'missing separate approval refuses GRANT'
 $vars.NOTARIS_DEV_GRANTS_APPROVED='true'
 # Every destructive/malformed test below is confined to this owned cluster and
 # wrapped in a failing transaction. No changes survive connection close.
 $cases=[ordered]@{
  'missing-hardening'='ALTER TABLE petugas ALTER COLUMN uuid DROP NOT NULL;'
  'extra-column'='ALTER TABLE petugas_sync_mutations ADD COLUMN unexpected text;'
  'missing-index'='DROP INDEX petugas_uuid_unique;'
  'wrong-index'='DROP INDEX petugas_sync_outbox_publication_idx; CREATE INDEX petugas_sync_outbox_publication_idx ON petugas_sync_outbox(row_version) WHERE publication_seq IS NOT NULL;'
  'wrong-constraint'='ALTER TABLE petugas_sync_publication DROP CONSTRAINT petugas_sync_publication_check; ALTER TABLE petugas_sync_publication ADD CONSTRAINT petugas_sync_publication_check CHECK(min_cursor>=0) NOT VALID;'
  'sequence-dependency'='ALTER SEQUENCE petugas_sync_outbox_id_seq OWNED BY NONE;'
  'sequence-definition'='ALTER SEQUENCE petugas_sync_outbox_id_seq CACHE 5;'
  'counter-advanced'='UPDATE petugas_sync_publication SET last_seq=1;'
  'changed-local-data'="UPDATE petugas SET nama='Unexpected edit' WHERE id=101;"
  'changed-uuid'='UPDATE petugas SET uuid=gen_random_uuid() WHERE id=101;'
  'excessive-privilege'='GRANT DELETE ON petugas_sync_mutations TO recovery_app;'
  'grant-option'='GRANT SELECT ON petugas_sync_mutations TO recovery_app WITH GRANT OPTION;'
  'references-privilege'='GRANT REFERENCES ON petugas_sync_mutations TO recovery_app;'
  'nonempty-receipt'="INSERT INTO petugas_sync_mutations VALUES(gen_random_uuid(),gen_random_uuid(),'test','{}',now());"
  'nonempty-outbox'="INSERT INTO petugas_sync_outbox(id,petugas_uuid,row_version,tombstone,payload) VALUES(-1,gen_random_uuid(),1,false,'{}');"
 }
 $reasons=@{
  'missing-hardening'='Column mismatch';'extra-column'='Unexpected columns';'missing-index'='Missing index';'wrong-index'='Incompatible index';'wrong-constraint'='Constraint mismatch'
  'sequence-dependency'='Sequence identity/owner mismatch';'sequence-definition'='Sequence ownership/dependency/definition mismatch'
  'counter-advanced'='Pre-activation counter/journal/sequence state changed';'changed-local-data'='Approved identity/data fingerprint changed';'changed-uuid'='Approved identity/data fingerprint changed'
  'excessive-privilege'='Unexpected application privilege/grant option';'grant-option'='Unexpected application privilege/grant option';'references-privilege'='Unexpected application privilege/grant option'
  'nonempty-receipt'='Pre-activation counter/journal/sequence state changed';'nonempty-outbox'='Pre-activation counter/journal/sequence state changed'
 }
 foreach($case in $cases.Keys){
  $file=Join-Path $root ($case+'.sql');$inc=$sqlRoot.Replace('\','/')
  ("\i '$inc/petugas_grants_context.sql'`nSET search_path=public,pg_catalog;`nBEGIN;`n"+$cases[$case]+"`n\i '$inc/petugas_grants_target_guard.sql'`n\i '$inc/petugas_grants_existing_guard.sql'`nCOMMIT;")|Set-Content $file
  $result=Run-File $case $file $vars $false
  Check ([bool](Select-String -LiteralPath $result.Stderr -SimpleMatch $reasons[$case])) "invalid installed state refused for expected reason: $case"
  $null=Run-File ($case+'-rolled-back') $verify $vars
 }
 Assert-AppUngrant 'negative-grants'
 # Fault injection in a private COPY, immediately before the grants transaction's
 # COMMIT. This proves even successfully executed GRANTs roll back on SQL error.
 $injected=Join-Path $root 'injected';New-Item -ItemType Directory $injected|Out-Null
 foreach($name in @('petugas_grants_context.sql','petugas_grants_target_guard.sql','petugas_grants_existing_guard.sql')){Copy-Item -LiteralPath (Join-Path $sqlRoot $name) -Destination (Join-Path $injected $name)}
 $text=Get-Content $apply -Raw
 $text.Replace('COMMIT;','DO $$ BEGIN RAISE EXCEPTION ''TEST_BEFORE_COMMIT''; END $$; COMMIT;')|Set-Content (Join-Path $injected 'apply.sql')
 $null=Run-File 'grant-rollback' (Join-Path $injected 'apply.sql') $vars $false
 Assert-AppUngrant 'rollback-grants';Check $true 'SQL error before COMMIT rolls back all four grants'
 Exec 'restricted-grantor' @'
CREATE ROLE recovery_operator LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE;
GRANT USAGE ON SCHEMA public TO recovery_operator;
GRANT SELECT ON konfigurasi_umum,jenis_kelamin,users,petugas,transaksi,transaksi_detail_proses,transaksi_riwayat_pembayaran TO recovery_operator;
ALTER TABLE petugas_sync_mutations OWNER TO recovery_operator;
ALTER TABLE petugas_sync_outbox OWNER TO recovery_operator;
ALTER TABLE petugas_sync_publication OWNER TO recovery_operator;
'@
 $env:PGUSER='recovery_operator'
 $priv=Read-Json 'restricted-privileges' "SELECT json_build_object('super',(SELECT rolsuper FROM pg_roles WHERE rolname=current_user),'schema_create',has_schema_privilege(current_user,'public','CREATE'),'petugas_owner',pg_has_role(current_user,(SELECT pg_get_userbyid(relowner) FROM pg_class WHERE oid='petugas'::regclass),'USAGE'));"
 Check (!$priv.super -and !$priv.schema_create -and !$priv.petugas_owner) 'restricted grantor needs neither superuser/schema CREATE nor ownership of legacy Petugas'
 $null=Run-File 'apply' $apply $vars;Check $true 'grants-only applied by restricted owner of sync objects on disposable target'
 $env:PGUSER='notaris_test'
 $null=Run-File 'after-apply' $verify $vars
 $null=Run-File 'apply-retry' $apply $vars;Check $true 'grants-only retry is idempotent'
 $after=Read-Json 'after' $snapshotQuery
 Check ($after.petugas -eq $before.petugas -and $after.tx -eq $before.tx -and $after.detail -eq $before.detail -and $after.payment -eq $before.payment -and $after.uuid -eq $assigned.uuid) 'all data, transaction references and assigned UUIDs preserved'
 $env:PGUSER='recovery_app'
 Exec 'app-access' @'
BEGIN;
SELECT * FROM petugas_sync_mutations; SELECT * FROM petugas_sync_outbox;
SELECT * FROM petugas_sync_publication; SELECT last_value,is_called FROM petugas_sync_outbox_id_seq;
INSERT INTO petugas_sync_mutations VALUES(gen_random_uuid(),gen_random_uuid(),'permission-probe','{}',now());
INSERT INTO petugas_sync_outbox(id,petugas_uuid,row_version,tombstone,payload) VALUES(-1,gen_random_uuid(),1,false,'{}');
UPDATE petugas_sync_outbox SET published_at=now() WHERE id=-1;
UPDATE petugas_sync_publication SET last_seq=last_seq WHERE id=1;
ROLLBACK;
'@
 Check $true 'app can execute required reads/writes; permission probe rolled back, no sequence allocation'
 $deny=Join-Path $root 'deny.sql';'BEGIN; DELETE FROM petugas_sync_mutations; ROLLBACK;'|Set-Content $deny
 $null=Run-File 'app-delete-denied' $deny @{} $false;Check $true 'app cannot delete mutation receipts'
 $null=Run-File 'app-cannot-recover' $verify $vars $false;Check $true 'app cannot run provisioning recovery'
 $env:PGUSER='notaris_test'
 $null=Run-File 'after-app-probe' $verify $vars
 $null=Run-File 'first-install-refused' (Join-Path $sqlRoot '20261030_03_notarisdev_petugas.sql') @{NOTARIS_DEV_REVIEWED='true';NOTARIS_DEV_APP_ROLE='recovery_app'} $false
 Check $true 'first-install guard still refuses existing schema'
 $badPort=$vars.Clone();$badPort.EXPECTED_PORT='55444'
 $null=Run-File 'wrong-port' $verify $badPort $false;Check $true 'wrong endpoint refused'
 $env:PGDATABASE='postgres';$null=Run-File 'wrong-db' $verify $vars $false;Check $true 'wrong database refused';$env:PGDATABASE='notarisdev'
 # Execute the shared helper in actual Windows PowerShell 5, including NOTICE
 # followed by a real error. stderr is retained; exit 0/3 decide success/failure.
 $notice=Join-Path $root 'notice.sql';"DO `$`$ BEGIN RAISE NOTICE 'EXPECTED_NOTICE'; END `$`$; SELECT 'AFTER_NOTICE';"|Set-Content $notice
 $fatal=Join-Path $root 'fatal.sql';"DO `$`$ BEGIN RAISE NOTICE 'BEFORE_ERROR'; RAISE EXCEPTION 'EXPECTED_SQL_ERROR'; END `$`$;"|Set-Content $fatal
 $probeFile=Join-Path $root 'windows-powershell-probe.ps1'
 @'
param($Helper,$Exe,$Notice,$Fatal,$Root)
$ErrorActionPreference='Stop'
. $Helper
foreach($name in @('notaris-psql-process.ps1','recover-notarisdev-petugas-grants.ps1','migrate-notarisdev-petugas.ps1')){
 $tokens=$null;$errors=$null;[System.Management.Automation.Language.Parser]::ParseFile((Join-Path (Split-Path $Helper -Parent) $name),[ref]$tokens,[ref]$errors)|Out-Null
 if($errors){throw 'Windows PowerShell parser regression'}
}
$refused=$false
try { & (Join-Path (Split-Path $Helper -Parent) 'recover-notarisdev-petugas-grants.ps1') -ApplyGrants -ConfirmTarget 'wrong' -BackupDirectory 'absent' -InstallationReceiptDirectory 'absent' }
catch { if($_.Exception.Message -eq 'Separate explicit grants-only target approval required'){$refused=$true}else{throw} }
if(!$refused){throw 'Wrong-target refusal regression'}
$a=Invoke-NotarisPsqlFile -Executable $Exe -File $Notice -Log (Join-Path $Root 'ps5 notice.log')
$b=Invoke-NotarisPsqlFile -Executable $Exe -File $Fatal -Log (Join-Path $Root 'ps5 error.log')
if($a.ExitCode -ne 0 -or $b.ExitCode -ne 3 -or !(Select-String -LiteralPath $a.Stderr -SimpleMatch EXPECTED_NOTICE) -or !(Select-String -LiteralPath $a.Stdout -SimpleMatch AFTER_NOTICE) -or !(Select-String -LiteralPath $b.Stderr -SimpleMatch EXPECTED_SQL_ERROR)){throw 'Native logging regression'}
$value="spaces `"quote`" slash\ apostrophe'"
$file=Join-Path $Root 'argument quoting.sql'
"\pset format unaligned`n\pset tuples_only on`nSELECT json_build_object('value', :'PROBE');"|Set-Content $file
$q=Invoke-NotarisPsqlFile -Executable $Exe -File $file -Log (Join-Path $Root 'argument quoting.log') -Variables @{PROBE=$value}
$json=Get-Content $q.Stdout|Where-Object {$_ -match '^\{'}|ConvertFrom-Json
if($q.ExitCode -ne 0 -or $json.value -cne $value){throw 'Native argument quoting regression'}
Write-Output 'PS5_NATIVE_LOGGING_PASS'
'@|Set-Content $probeFile
 & powershell.exe -NoProfile -File $probeFile (Join-Path $PSScriptRoot 'notaris-psql-process.ps1') $psql $notice $fatal $root
 Check ($LASTEXITCODE -eq 0) 'actual Windows PowerShell 5 NOTICE/error exit codes and separate logs'
 foreach($key in @('NOTARIS_READINESS_TEST_DSN','NOTARIS_FIXTURE_HTTP_DSN','NOTARIS_FLUTTER_E2E')){Remove-Item -LiteralPath "Env:$key" -ErrorAction SilentlyContinue}
 $env:NOTARIS_SYNC_TEST_DSN='host=127.0.0.1 port=55443 user=notaris_test dbname=postgres sslmode=disable'
 Set-Location (Join-Path $repo 'backend-notaris-go')
 & go test -json -count=1 ./... > (Join-Path $root 'go-tests.jsonl')
 if($LASTEXITCODE){throw 'Go regression failed'}
 $events=Get-Content (Join-Path $root 'go-tests.jsonl')|ConvertFrom-Json
 $events|Where-Object Test|Group-Object Action|Where-Object Name -in @('pass','fail','skip')|Select-Object Name,Count|Format-Table
 Check $true 'Go full suite with isolated PostgreSQL integrations'
 $null=Run-File 'final-verify' $verify $vars
 # A used sequence cannot be reset/reconciled by this recovery path. Deliberately
 # allocate once ONLY in this disposable cluster, prove refusal, never setval.
 Exec 'sequence-used' "SELECT nextval('public.petugas_sync_outbox_id_seq');"
 $null=Run-File 'sequence-used-refused' $verify $vars $false
 Check $true 'used sequence blocks recovery; no automatic sequence reset'
 Write-Output "RECOVERY_TEST_PASS: $passed checks, no skipped recovery cases. Logs: $root"
} finally {
 Set-Location $location
 if($started){& (Join-Path $PostgresBin 'pg_ctl.exe') -D $data -m fast -w stop *> (Join-Path $root 'stop.log');if($LASTEXITCODE){Write-Warning "Owned cluster stop failed: $root"}}
 foreach($key in $previous.Keys){if($null -eq $previous[$key]){Remove-Item -LiteralPath "Env:$key" -ErrorAction SilentlyContinue}else{[Environment]::SetEnvironmentVariable($key,$previous[$key])}}
}
