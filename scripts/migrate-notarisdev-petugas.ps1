# Interactive, development-only operator entry point. No startup integration.
# Default: credential/ownership preflight only. -Apply requires the approved target.
param(
 [switch]$Apply,
 [string]$ConfirmTarget,
 [Parameter(Mandatory)][string]$BackupDirectory,
 [string]$ProvisioningUser='postgres',
 [PSCredential]$Credential,
 [string]$PostgresBin='D:\Program Files\PostgreSQL\bin'
)
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'notaris-psql-process.ps1')
if($Apply -and $ConfirmTarget -cne '127.0.0.1:5432/notarisdev'){throw 'Explicit approved target required for Apply'}
$BackupDirectory=(Resolve-Path -LiteralPath $BackupDirectory).Path
$baseline=Get-Content (Join-Path $BackupDirectory 'preflight.json') -Raw|ConvertFrom-Json
$archive=Join-Path $BackupDirectory 'notarisdev-before.dump'
$hash=Get-Content (Join-Path $BackupDirectory 'sha256.json') -Raw|ConvertFrom-Json
if($baseline.database -ne 'notarisdev' -or $baseline.server_address -ne '127.0.0.1' -or $baseline.server_port -ne 5432 -or $baseline.marker -ne 'NOTARISDEV SYNTHETIC v1' -or (Get-FileHash $archive).Hash -ne $hash.Hash){throw 'Unexpected target/backup or checksum mismatch'}
$settings=@{}
foreach($line in Get-Content (Join-Path $repo 'backend-notaris-go/.env.notarisdev')){
 if($line -match '^([A-Z_]+)=(.*)$'){$settings[$matches[1]]=$matches[2].Trim().Trim('"').Trim("'")}
}
if($settings.DB_NAME -ne 'notarisdev' -or $settings.DB_HOST -notin @('127.0.0.1','localhost') -or $settings.DB_PORT -ne '5432' -or $settings.PETUGAS_PUBLISHER_ENABLED -ne 'false'){throw 'Explicit development configuration with publisher OFF required; no .env fallback'}
if(!$settings.DB_USER -or ($Credential -and $Credential.UserName -eq $settings.DB_USER) -or (!$Credential -and $ProvisioningUser -eq $settings.DB_USER)){throw 'Application role cannot run DDL'}
if($settings.DB_USER -notmatch '^[a-z_][a-z0-9_]*$'){throw 'Unexpected generated application role identifier'}
function Assert-Baseline {
 $output=& (Join-Path $PSScriptRoot 'prepare-petugas-dev-migration.ps1') -PostgresBin $PostgresBin
 $current=($output|Select-Object -Last 1)|ConvertFrom-Json
 foreach($key in @('schema_fingerprint','petugas_fingerprint','detail_fingerprint','transaction_fingerprint','payment_fingerprint')){
  if(!$baseline.$key -or $baseline.$key -ne $current.$key){throw "Baseline changed: $key. Stop and revalidate a fresh backup"}
 }
 if(@($current.other_connections).Count){throw 'Maintenance required: close other notarisdev sessions'}
 $probe=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,8081)
 try{$probe.Start()}finally{$probe.Stop()}
}
Assert-Baseline
if(!$Credential){
 $secret=Read-Host "Password provisioning role $ProvisioningUser (local terminal only; not saved)" -AsSecureString
 $Credential=[PSCredential]::new($ProvisioningUser,$secret)
}
$keys=@('PGHOST','PGPORT','PGDATABASE','PGUSER','PGPASSWORD','PGOPTIONS','PGCONNECT_TIMEOUT')
$previous=@{};foreach($key in $keys){$previous[$key]=[Environment]::GetEnvironmentVariable($key)}
$history=$null;$root=$null
function Sql([string]$Text){
 $output=& (Join-Path $PostgresBin 'psql.exe') -X -w -v ON_ERROR_STOP=1 -Atc $Text
 if($LASTEXITCODE){throw 'Provisioning query failed; stop, no automatic restore'}
 return $output -join "`n"
}
try {
 $env:PGHOST='127.0.0.1';$env:PGPORT='5432';$env:PGDATABASE='notarisdev'
 $env:PGUSER=$Credential.UserName;$env:PGPASSWORD=$Credential.GetNetworkCredential().Password
 $env:PGCONNECT_TIMEOUT='5';$env:PGOPTIONS='-c default_transaction_read_only=on -c lock_timeout=5s -c statement_timeout=60s'
 $access=(Sql @'
SELECT json_build_object('database',current_database(),'address',inet_server_addr(),'port',inet_server_port(),
 'role',current_user,'read_only',current_setting('transaction_read_only'),
 'marker',(SELECT notaris_bersangkutan FROM public.konfigurasi_umum WHERE id=1),
 'can_create',has_schema_privilege(current_user,'public','CREATE'),
 'can_alter',pg_has_role(current_user,(SELECT pg_get_userbyid(relowner) FROM pg_class WHERE oid='public.petugas'::regclass),'USAGE'));
'@)|ConvertFrom-Json
 if($access.database -ne 'notarisdev' -or $access.address -ne '127.0.0.1' -or $access.port -ne 5432 -or $access.read_only -ne 'on' -or $access.marker -ne 'NOTARISDEV SYNTHETIC v1' -or $access.role -eq $settings.DB_USER -or !$access.can_create -or !$access.can_alter){throw 'Provisioning rights or target identity insufficient; no permission changes attempted'}
 Write-Output 'ACCESS_PREFLIGHT_PASS: separate provisioning role, table ownership and schema CREATE verified; no DDL yet.'
 if(!$Apply){return}
 # Recheck after password entry; operator could have taken time to authenticate.
 Assert-Baseline
 $root=Join-Path $repo ('.local/petugas-rollout-'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
 New-Item -ItemType Directory -Path $root|Out-Null
 $sqlRoot=Join-Path $repo 'backend-notaris-go'
 $files=@('migration_proposals/20261030_03_notarisdev_petugas.sql','migration_proposals/notarisdev_petugas_target_guard.sql','migrations/20261029_01_petugas_cloud_sync.sql','migrations/20261030_01_petugas_publication.sql','migrations/20261030_02_petugas_uuid_hardening.sql')
 $history=[ordered]@{target='127.0.0.1:5432/notarisdev';startedUtc=[DateTime]::UtcNow.ToString('o');backup=$BackupDirectory;backupSha256=$hash.Hash;provisioningRole=$access.role;appRole=$settings.DB_USER;status='started';phases=@();sql=@($files|ForEach-Object {@{file=$_;sha256=(Get-FileHash (Join-Path $sqlRoot $_)).Hash}})}
 $history|ConvertTo-Json -Depth 6|Set-Content (Join-Path $root 'history.json')
 $env:PGOPTIONS='-c lock_timeout=5s -c statement_timeout=60s'
 # Windows PowerShell 5 treats redirected native stderr (including harmless
 # PostgreSQL NOTICEs) as ErrorRecords under ErrorActionPreference=Stop. Keep
 # stdout/stderr as separate native files and use the process EXIT CODE instead.
 $process=Invoke-NotarisPsqlFile -Executable (Join-Path $PostgresBin 'psql.exe') -File (Join-Path $sqlRoot $files[0]) -Log (Join-Path $root 'migration.log') -Variables @{NOTARIS_DEV_REVIEWED='true';NOTARIS_DEV_APP_ROLE=$settings.DB_USER}
 $migrationExit=$process.ExitCode
 $log=Get-Content (Join-Path $root 'migration.log')
 $markers=@('PETUGAS_PHASE1_COMMITTED','PETUGAS_PHASE2_COMMITTED','PETUGAS_PHASE3_COMMITTED','PETUGAS_GRANTS_COMMITTED')
 $history.phases=@($markers|ForEach-Object {@{phase=$_;commitMarkerSeen=($log -contains $_)}})
 $history.migrationExitCode=$migrationExit
 $history.status='migration_failed_or_partial'
 $history|ConvertTo-Json -Depth 6|Set-Content (Join-Path $root 'history.json')
 if($null -eq $migrationExit -or $migrationExit -ne 0 -or @($history.phases|Where-Object {!$_.commitMarkerSeen}).Count){throw "Migration failed/partial. Keep clients OFF; inspect $root. Missing markers do not prove rollback. No restore or retry attempted"}
 $env:PGOPTIONS='-c default_transaction_read_only=on -c statement_timeout=60s'
 $post=(Sql @'
SELECT json_build_object('database',current_database(),'address',inet_server_addr(),'port',inet_server_port(),
 'petugas_count',(SELECT count(*) FROM public.petugas),
 'ids',(SELECT json_agg(id ORDER BY id) FROM public.petugas),
 'petugas_fingerprint',(SELECT md5(COALESCE(jsonb_agg(to_jsonb(p)-ARRAY['uuid','row_version','deleted_at'] ORDER BY id)::text,'[]')) FROM public.petugas p),
 'detail_fingerprint',(SELECT md5(COALESCE(jsonb_agg(to_jsonb(d) ORDER BY id)::text,'[]')) FROM public.transaksi_detail_proses d),
 'transaction_fingerprint',(SELECT md5(COALESCE(jsonb_agg(to_jsonb(t) ORDER BY id)::text,'[]')) FROM public.transaksi t),
 'payment_fingerprint',(SELECT md5(COALESCE(jsonb_agg(to_jsonb(p) ORDER BY id)::text,'[]')) FROM public.transaksi_riwayat_pembayaran p),
 'valid_rows',(SELECT count(*) FROM public.petugas WHERE uuid IS NOT NULL AND row_version=1 AND deleted_at IS NULL),
 'unique_uuids',(SELECT count(DISTINCT uuid) FROM public.petugas),
 'uuid_not_null',(SELECT attnotnull FROM pg_attribute WHERE attrelid='public.petugas'::regclass AND attname='uuid'),
 'uuid_default',(SELECT pg_get_expr(d.adbin,d.adrelid) FROM pg_attrdef d JOIN pg_attribute a ON a.attrelid=d.adrelid AND a.attnum=d.adnum WHERE a.attrelid='public.petugas'::regclass AND a.attname='uuid'),
 'uuid_unique_index',EXISTS(SELECT FROM pg_index WHERE indrelid='public.petugas'::regclass AND indisunique AND indisvalid AND indnkeyatts=1 AND indkey[0]=(SELECT attnum FROM pg_attribute WHERE attrelid='public.petugas'::regclass AND attname='uuid')),
 'receipts',(SELECT count(*) FROM public.petugas_sync_mutations),
 'outbox',(SELECT count(*) FROM public.petugas_sync_outbox),
 'publication',(SELECT json_agg(json_build_object('id',id,'last_seq',last_seq,'min_cursor',min_cursor)) FROM public.petugas_sync_publication));
'@)|ConvertFrom-Json
 if($post.database -ne 'notarisdev' -or $post.address -ne '127.0.0.1' -or $post.port -ne 5432 -or ($post.ids -join ',') -ne '101,102,103,104' -or $post.petugas_count -ne 4 -or $post.valid_rows -ne 4 -or $post.unique_uuids -ne 4 -or !$post.uuid_not_null -or $post.uuid_default -notmatch '^(pg_catalog\.|public\.)?gen_random_uuid\(\)$' -or !$post.uuid_unique_index -or $post.receipts -ne 0 -or $post.outbox -ne 0 -or @($post.publication).Count -ne 1 -or $post.publication[0].id -ne 1 -or $post.publication[0].last_seq -ne 0 -or $post.publication[0].min_cursor -ne 0){throw 'Post-migration schema/identity baseline mismatch; stop and inspect history'}
 foreach($key in @('petugas_fingerprint','detail_fingerprint','transaction_fingerprint','payment_fingerprint')){if($post.$key -ne $baseline.$key){throw "Legacy data changed: $key; no automatic recovery"}}
 # Authenticate as the app for actual SELECT access; inspect all required grants
 # individually (has_table_privilege with a comma-list means ANY, not ALL).
 $env:PGUSER=$settings.DB_USER;$env:PGPASSWORD=$settings.DB_PASSWORD
 $grants=(Sql @'
SELECT json_build_object('can_ddl',has_schema_privilege(current_user,'public','CREATE'),
 'receipts',(SELECT count(*) FROM public.petugas_sync_mutations),
 'outbox',(SELECT count(*) FROM public.petugas_sync_outbox),
 'publication',(SELECT count(*) FROM public.petugas_sync_publication),
 'sequence_read',(SELECT last_value IS NOT NULL FROM public.petugas_sync_outbox_id_seq),
 'allowed',has_table_privilege(current_user,'public.petugas_sync_mutations','INSERT')
 AND has_table_privilege(current_user,'public.petugas_sync_outbox','INSERT')
 AND has_table_privilege(current_user,'public.petugas_sync_outbox','UPDATE')
 AND has_table_privilege(current_user,'public.petugas_sync_publication','UPDATE')
 AND has_sequence_privilege(current_user,'public.petugas_sync_outbox_id_seq','USAGE'),
 'extra',has_table_privilege(current_user,'public.petugas_sync_mutations','UPDATE')
 OR has_table_privilege(current_user,'public.petugas_sync_mutations','DELETE')
 OR has_table_privilege(current_user,'public.petugas_sync_outbox','DELETE')
 OR has_table_privilege(current_user,'public.petugas_sync_publication','INSERT')
 OR has_table_privilege(current_user,'public.petugas_sync_publication','DELETE'));
'@)|ConvertFrom-Json
 if($grants.can_ddl -or !$grants.allowed -or $grants.extra -or !$grants.sequence_read){throw 'Unexpected application grants; stop and inspect'}
 $post|ConvertTo-Json -Depth 6|Set-Content (Join-Path $root 'postflight.json')
 $grants|ConvertTo-Json -Depth 4|Set-Content (Join-Path $root 'grants.json')
 $history.status='schema_and_grants_verified';$history.finishedUtc=[DateTime]::UtcNow.ToString('o')
 $history|ConvertTo-Json -Depth 6|Set-Content (Join-Path $root 'history.json')
 Write-Output "SCHEMA_VERIFIED: IDs/data preserved; three phases and grants committed. Receipt: $root"
 Write-Output 'Publisher OFF; bootstrap/HTTP smoke/UUID repeat validation remain separate controlled verification steps. No Flutter activation.'
} catch {
 if($history){$history.status='failed_or_requires_inspection';$history|ConvertTo-Json -Depth 6|Set-Content (Join-Path $root 'history.json')}
 throw
} finally {
 foreach($key in $previous.Keys){if($null -eq $previous[$key]){Remove-Item -LiteralPath "Env:$key" -ErrorAction SilentlyContinue}else{[Environment]::SetEnvironmentVariable($key,$previous[$key])}}
 $Credential=$null;$secret=$null
}
