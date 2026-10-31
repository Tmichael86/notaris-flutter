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
 'petugas_fingerprint',(SELECT md5(COALESCE(jsonb_agg(to_jsonb(p) ORDER BY id)::text,'[]')) FROM public.petugas p),
 'app_can_ddl',has_schema_privilege(current_user,'public','CREATE'));
'@
try {
 $env:PGHOST='127.0.0.1';$env:PGPORT='5432';$env:PGDATABASE='notarisdev';$env:PGUSER=$settings['DB_USER'];$env:PGPASSWORD=$settings['DB_PASSWORD'];$env:PGOPTIONS='-c default_transaction_read_only=on';$env:PGCONNECT_TIMEOUT='5'
 $raw=& (Join-Path $PostgresBin 'psql.exe') -X -w -v ON_ERROR_STOP=1 -Atc $sql
 if($LASTEXITCODE){throw 'Read-only development preflight failed'}
 $json=$raw -join "`n";$report=$json|ConvertFrom-Json
 if($report.database -ne 'notarisdev' -or $report.read_only -ne 'on' -or $report.marker -ne 'NOTARISDEV SYNTHETIC v1'){throw 'Target identity mismatch'}
 if($report.app_can_ddl){throw 'Application role unexpectedly has schema CREATE rights'}
 if($report.sync_tables -ne 0 -or ($report.petugas_columns|Where-Object name -in @('uuid','row_version','deleted_at'))){throw 'Existing/partial sync migration; inspect manually'}
 if($report.petugas_count -ne 4 -or ($report.petugas_ids -join ',') -ne '101,102,103,104' -or $report.gender_orphans -ne 0 -or $report.user_orphans -ne 0){throw 'Unexpected legacy baseline/reference data; inspect before migration'}
 if(!$report.fixture_operator.active -or @($report.petugas_permission).Count -ne 1){throw 'Fixture operator/group/permission provenance unavailable'}
 foreach($permission in @('read','create','update','delete')) {if($report.petugas_permission[0].$permission -ne 1){throw "Fixture operator lacks Petugas $permission permission"}}
 Write-Output "PREFLIGHT PASS: notarisdev, Petugas=4, stable IDs=101..104, no reference orphans, sync schema absent. App DDL=False."
 Write-Output (ConvertTo-Json $report -Depth 6 -Compress)
 if(!$Backup){return}
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
 if($post.petugas_fingerprint -ne $report.petugas_fingerprint -or $post.detail_fingerprint -ne $report.detail_fingerprint){throw 'Data changed during backup; retake under maintenance'}
 Write-Output "BACKUP_READY=$root (private development data; not committed). Full restore still requires disposable verification."
} finally {
 foreach($k in $previous.Keys){if($null -eq $previous[$k]){Remove-Item -LiteralPath "Env:$k" -ErrorAction SilentlyContinue}else{[Environment]::SetEnvironmentVariable($k,$previous[$k])}}
}
