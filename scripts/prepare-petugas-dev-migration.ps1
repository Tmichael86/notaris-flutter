# Read-only readiness / backup ONLY. There is intentionally no Apply option.
param([switch]$Backup,[string]$PostgresBin='D:\Program Files\PostgreSQL\bin')
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
$settings=@{}
foreach($line in Get-Content (Join-Path $repo 'backend-notaris-go/.env.notarisdev')) {
 if($line -match '^([A-Z_]+)=(.*)$'){$settings[$matches[1]]=$matches[2].Trim().Trim('"').Trim("'")}
}
if($settings['DB_NAME'] -ne 'notarisdev' -or $settings['DB_HOST'] -notin @('localhost','127.0.0.1') -or $settings['DB_PORT'] -ne '5432'){throw 'Only explicit loopback:5432/notarisdev development config allowed; no .env fallback'}
$profile=Get-Content (Join-Path $repo '.local/notarisdev-profile.json') -Raw|ConvertFrom-Json
if($profile.database -ne 'notarisdev' -or $profile.port -ne 5432 -or $profile.fixture -ne 'smoke-v1'){throw 'Unexpected provisioning manifest'}
$previous=@{};foreach($k in @('PGHOST','PGPORT','PGDATABASE','PGUSER','PGPASSWORD','PGOPTIONS','PGCONNECT_TIMEOUT')){$previous[$k]=[Environment]::GetEnvironmentVariable($k)}
$sql=@'
SELECT json_build_object('database',current_database(),'read_only',current_setting('transaction_read_only'),
 'server_address',inet_server_addr(),'server_port',inet_server_port(),
 'database_owner',(SELECT pg_get_userbyid(datdba) FROM pg_database WHERE datname=current_database()),
 'petugas_owner',(SELECT pg_get_userbyid(relowner) FROM pg_class WHERE oid='public.petugas'::regclass),
 'provisioning_owner',(SELECT json_build_object('role',r.rolname,'can_login',r.rolcanlogin,'separate_from_app',r.rolname<>current_user) FROM pg_roles r JOIN pg_class c ON c.relowner=r.oid WHERE c.oid='public.petugas'::regclass),
 'schema_fingerprint',(SELECT md5(string_agg(def,E'\n' ORDER BY def)) FROM (
   SELECT row_to_json(c)::text AS def FROM information_schema.columns c WHERE table_schema='public'
   UNION ALL SELECT indexdef FROM pg_indexes WHERE schemaname='public'
   UNION ALL SELECT conrelid::regclass::text||conname||pg_get_constraintdef(oid) FROM pg_constraint WHERE connamespace='public'::regnamespace
   UNION ALL SELECT schemaname||viewname||definition FROM pg_views WHERE schemaname='public'
   UNION ALL SELECT pg_get_functiondef(oid) FROM pg_proc WHERE pronamespace='public'::regnamespace AND prokind IN ('f','p')
   UNION ALL SELECT pg_get_triggerdef(oid) FROM pg_trigger WHERE NOT tgisinternal AND tgrelid IN (SELECT oid FROM pg_class WHERE relnamespace='public'::regnamespace)
   UNION ALL SELECT row_to_json(s)::text FROM information_schema.sequences s WHERE sequence_schema='public'
 ) definitions),
 'other_connections',(SELECT COALESCE(json_agg(json_build_object('pid',pid,'role',usename,'application',application_name,'state',state)), '[]'::json) FROM pg_stat_activity WHERE datname=current_database() AND pid<>pg_backend_pid()),
 'app_role',current_user,'server_version',current_setting('server_version'),
 'marker',(SELECT notaris_bersangkutan FROM public.konfigurasi_umum WHERE id=1),
 'petugas_count',(SELECT count(*) FROM public.petugas),
 'petugas_ids',(SELECT json_agg(id ORDER BY id) FROM public.petugas),
 'petugas_columns',(SELECT json_agg(json_build_object('name',column_name,'type',data_type,'nullable',is_nullable,'default',column_default) ORDER BY ordinal_position) FROM information_schema.columns WHERE table_schema='public' AND table_name='petugas'),
 'petugas_indexes',(SELECT json_agg(indexdef) FROM pg_indexes WHERE schemaname='public' AND tablename='petugas'),
 'sync_tables',(SELECT count(*) FROM pg_tables WHERE schemaname='public' AND tablename LIKE 'petugas_sync%'),
 'gender_orphans',(SELECT count(*) FROM public.petugas p WHERE jenis_kelamin IS NOT NULL AND NOT EXISTS(SELECT FROM public.jenis_kelamin j WHERE j.id=p.jenis_kelamin)),
 'user_orphans',(SELECT count(*) FROM public.petugas p WHERE user_id IS NOT NULL AND NOT EXISTS(SELECT FROM public.users u WHERE u.id=p.user_id)),
 'genders',(SELECT json_agg(json_build_object('server_id',id,'status',status) ORDER BY id) FROM public.jenis_kelamin),
 'fixture_operator',(SELECT json_build_object('user_id',u.id,'group_id',u.group_id,'active',u.status=1 AND g.status=1) FROM public.users u JOIN public.groups g ON g.id=u.group_id WHERE u.username='fixture.operator'),
 'petugas_permission',(SELECT json_agg(json_build_object('read',a.read,'create',a.create,'update',a.update,'delete',a.delete)) FROM public.sidebar_akses a JOIN public.sidebar s ON s.id=a.sidebar_id JOIN public.users u ON u.group_id=a.group_id WHERE s.sidebar_kode='petugas' AND s.status=1 AND u.username='fixture.operator'),
 'detail_count',(SELECT count(*) FROM public.transaksi_detail_proses),
 'detail_fingerprint',(SELECT md5(COALESCE(jsonb_agg(to_jsonb(d) ORDER BY id)::text,'[]')) FROM public.transaksi_detail_proses d),
 'transaction_count',(SELECT count(*) FROM public.transaksi),
 'transaction_fingerprint',(SELECT md5(COALESCE(jsonb_agg(to_jsonb(t) ORDER BY id)::text,'[]')) FROM public.transaksi t),
 'payment_fingerprint',(SELECT md5(COALESCE(jsonb_agg(to_jsonb(p) ORDER BY id)::text,'[]')) FROM public.transaksi_riwayat_pembayaran p),
 'petugas_fingerprint',(SELECT md5(COALESCE(jsonb_agg(to_jsonb(p) ORDER BY id)::text,'[]')) FROM public.petugas p),
 'app_can_ddl',has_schema_privilege(current_user,'public','CREATE'));
'@
try {
 $env:PGHOST='127.0.0.1';$env:PGPORT='5432';$env:PGDATABASE='notarisdev';$env:PGUSER=$settings['DB_USER'];$env:PGPASSWORD=$settings['DB_PASSWORD'];$env:PGOPTIONS='-c default_transaction_read_only=on';$env:PGCONNECT_TIMEOUT='5'
 $raw=& (Join-Path $PostgresBin 'psql.exe') -X -w -v ON_ERROR_STOP=1 -Atc $sql
 if($LASTEXITCODE){throw 'Read-only development preflight failed'}
 $json=$raw -join "`n";$report=$json|ConvertFrom-Json
 if($report.database -ne 'notarisdev' -or $report.server_address -ne '127.0.0.1' -or $report.server_port -ne 5432 -or $report.read_only -ne 'on' -or $report.marker -ne 'NOTARISDEV SYNTHETIC v1'){throw 'Target identity mismatch'}
 if($report.app_can_ddl){throw 'Application role unexpectedly has schema CREATE rights'}
 if(!$report.provisioning_owner.can_login -or !$report.provisioning_owner.separate_from_app){throw 'Separate login-capable provisioning owner required'}
 if($report.sync_tables -ne 0 -or ($report.petugas_columns|Where-Object name -in @('uuid','row_version','deleted_at'))){throw 'Existing/partial sync migration; inspect manually'}
 if($report.petugas_count -ne 4 -or ($report.petugas_ids -join ',') -ne '101,102,103,104' -or $report.gender_orphans -ne 0 -or $report.user_orphans -ne 0){throw 'Unexpected legacy baseline/reference data; inspect before migration'}
 if(!$report.fixture_operator.active -or @($report.petugas_permission).Count -ne 1){throw 'Fixture operator/group/permission provenance unavailable'}
 foreach($permission in @('read','create','update','delete')) {if($report.petugas_permission[0].$permission -ne 1){throw "Fixture operator lacks Petugas $permission permission"}}
 Write-Output "PREFLIGHT PASS: notarisdev, Petugas=4, stable IDs=101..104, no reference orphans, sync schema absent. App DDL=False."
 Write-Output (ConvertTo-Json $report -Depth 6 -Compress)
 if(!$Backup){return}
 # Keep the maintenance gate before creating an archive. Do not stop other apps.
 $listener=[Net.Sockets.TcpClient]::new()
 try {$backendActive=$listener.ConnectAsync('127.0.0.1',8081).Wait(1000) -and $listener.Connected}
 catch {$backendActive=$false} finally {$listener.Dispose()}
 if($backendActive -or @($report.other_connections).Count -gt 0){throw 'Maintenance required: stop development backend/clients and close target database sessions before backup; no processes were stopped'}
 $root=Join-Path $repo ('.local/petugas-migration-'+[datetime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
 New-Item -ItemType Directory -Path $root|Out-Null
 $json|Set-Content (Join-Path $root 'preflight.json')
 & (Join-Path $PostgresBin 'pg_dump.exe') -w -Fc --no-owner --no-privileges -f (Join-Path $root 'notarisdev-before.dump')
 if($LASTEXITCODE){throw 'Pre-migration backup failed'}
 & (Join-Path $PostgresBin 'pg_restore.exe') --list (Join-Path $root 'notarisdev-before.dump')|Set-Content (Join-Path $root 'toc.txt')
 if($LASTEXITCODE){throw 'Backup listing verification failed'}
 Get-FileHash (Join-Path $root 'notarisdev-before.dump')|Select-Object Algorithm,Hash|ConvertTo-Json|Set-Content (Join-Path $root 'sha256.json')
 $after=& (Join-Path $PostgresBin 'psql.exe') -X -w -Atc $sql
 if($LASTEXITCODE){throw 'Post-backup check failed'}
 $post=($after -join "`n")|ConvertFrom-Json
 foreach($fingerprint in @('schema_fingerprint','petugas_fingerprint','detail_fingerprint','transaction_fingerprint','payment_fingerprint')) {
  if($post.$fingerprint -ne $report.$fingerprint){throw 'Schema/data changed during backup; inspect and retake under maintenance'}
 }
 if(@($post.other_connections).Count -gt 0){throw 'Database sessions appeared during backup; inspect and retake under maintenance'}
 Write-Output "BACKUP_READY=$root (private development data; not committed). Full restore still requires disposable verification."
} finally {
 foreach($k in $previous.Keys){if($null -eq $previous[$k]){Remove-Item -LiteralPath "Env:$k" -ErrorAction SilentlyContinue}else{[Environment]::SetEnvironmentVariable($k,$previous[$k])}}
}
