# REVIEW / explicit operator execution only. Default is read-only. No migration,
# bootstrap, publisher, restore, or first-install fallback exists in this entry.
param([switch]$ApplyGrants,[string]$ConfirmTarget,
 [Parameter(Mandatory)][string]$BackupDirectory,
 [Parameter(Mandatory)][string]$InstallationReceiptDirectory,
 [string]$ProvisioningUser='postgres',[PSCredential]$Credential,
 [string]$PostgresBin='D:\Program Files\PostgreSQL\bin')
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'notaris-psql-process.ps1')
if($ApplyGrants -and $ConfirmTarget -cne '127.0.0.1:5432/notarisdev'){throw 'Separate explicit grants-only target approval required'}
$BackupDirectory=(Resolve-Path -LiteralPath $BackupDirectory).Path
$InstallationReceiptDirectory=(Resolve-Path -LiteralPath $InstallationReceiptDirectory).Path
$before=Get-Content (Join-Path $BackupDirectory 'preflight.json') -Raw|ConvertFrom-Json
$checksum=Get-Content (Join-Path $BackupDirectory 'sha256.json') -Raw|ConvertFrom-Json
$installation=Get-Content (Join-Path $InstallationReceiptDirectory 'history.json') -Raw|ConvertFrom-Json
$identity=Get-Content (Join-Path $InstallationReceiptDirectory 'recovery-inspection.json') -Raw|ConvertFrom-Json
if($before.database -ne 'notarisdev' -or $before.server_address -ne '127.0.0.1' -or $before.server_port -ne 5432 -or $before.marker -ne 'NOTARISDEV SYNTHETIC v1' -or
 $installation.target -ne '127.0.0.1:5432/notarisdev' -or [IO.Path]::GetFullPath($installation.backup) -ne $BackupDirectory -or
 $identity.database -ne 'notarisdev' -or $identity.address -ne '127.0.0.1' -or $identity.port -ne 5432 -or
 $identity.legacy_petugas_fingerprint -ne $before.petugas_fingerprint -or
 (Get-FileHash (Join-Path $BackupDirectory 'notarisdev-before.dump')).Hash -ne $checksum.Hash -or
 $installation.backupSha256 -ne $checksum.Hash){throw 'Unexpected verified backup/installed identity receipt'}
$settings=@{}
foreach($line in Get-Content (Join-Path $repo 'backend-notaris-go/.env.notarisdev')){
 if($line -match '^([A-Z_]+)=(.*)$'){$settings[$matches[1]]=$matches[2].Trim().Trim('"').Trim("'")}
}
if($settings.DB_NAME -ne 'notarisdev' -or $settings.DB_HOST -notin @('127.0.0.1','localhost') -or $settings.DB_PORT -ne '5432' -or $settings.PETUGAS_PUBLISHER_ENABLED -ne 'false' -or $installation.appRole -ne $settings.DB_USER){throw 'Explicit development config/publisher OFF required; no .env fallback'}
if(($Credential -and $Credential.UserName -eq $settings.DB_USER) -or (!$Credential -and $ProvisioningUser -eq $settings.DB_USER)){throw 'Application role cannot provision grants'}
$variables=@{EXPECTED_PORT='5432';NOTARIS_DEV_APP_ROLE=$settings.DB_USER;PETUGAS_HASH=$before.petugas_fingerprint;UUID_HASH=$identity.uuid_fingerprint;TRANSACTION_HASH=$before.transaction_fingerprint;DETAIL_HASH=$before.detail_fingerprint;PAYMENT_HASH=$before.payment_fingerprint}
foreach($key in @('PETUGAS_HASH','UUID_HASH','TRANSACTION_HASH','DETAIL_HASH','PAYMENT_HASH')){
 if($variables[$key] -notmatch '^[a-f0-9]{32}$'){throw 'Missing verified baseline fingerprint'}
}
$probe=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,8081)
try{$probe.Start()}catch{throw 'Maintenance required: development backend port 8081 is occupied'}finally{$probe.Stop()}
if(!$Credential){$secret=Read-Host "Password provisioning role $ProvisioningUser (hidden; not saved)" -AsSecureString;$Credential=[PSCredential]::new($ProvisioningUser,$secret)}
$keys=@('PGHOST','PGPORT','PGDATABASE','PGUSER','PGPASSWORD','PGOPTIONS','PGCONNECT_TIMEOUT')
$previous=@{};foreach($key in $keys){$previous[$key]=[Environment]::GetEnvironmentVariable($key)}
$root=Join-Path $repo ('.local/petugas-grants-'+[datetime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $root|Out-Null
$sqlRoot=Join-Path $repo 'backend-notaris-go/migration_proposals'
$files=@('verify_petugas_grants.sql','recover_petugas_grants_only.sql','petugas_grants_context.sql','petugas_grants_existing_guard.sql','petugas_grants_target_guard.sql')
$history=[ordered]@{target='127.0.0.1:5432/notarisdev';mode='verify_only';status='started';startedUtc=[datetime]::UtcNow.ToString('o');installationReceipt=$InstallationReceiptDirectory;backup=$BackupDirectory;backupSha256=$checksum.Hash;uuidFingerprint=$identity.uuid_fingerprint;grantsCommitConfirmed=$false;sql=@($files|ForEach-Object {@{file=$_;sha256=(Get-FileHash (Join-Path $sqlRoot $_)).Hash}});runnerSha256=(Get-FileHash $PSCommandPath).Hash;nativeHelperSha256=(Get-FileHash (Join-Path $PSScriptRoot 'notaris-psql-process.ps1')).Hash}
function Save-History {$history|ConvertTo-Json -Depth 6|Set-Content (Join-Path $root 'history.json')}
function Run-ReviewedSql([string]$Name,[string]$Log,[string]$Marker){
 $result=Invoke-NotarisPsqlFile -Executable (Join-Path $PostgresBin 'psql.exe') -File (Join-Path $sqlRoot $Name) -Log (Join-Path $root $Log) -Variables $variables
 $history[($Log+'_exit')]=$result.ExitCode;Save-History
 if($result.ExitCode -ne 0 -or !(Get-Content $result.Stdout|Where-Object {$_ -ceq $Marker})){throw "Stopped; inspect $root/$Log and its .stderr. No automatic retry/restore"}
}
try {
 $env:PGHOST='127.0.0.1';$env:PGPORT='5432';$env:PGDATABASE='notarisdev';$env:PGUSER=$Credential.UserName;$env:PGPASSWORD=$Credential.GetNetworkCredential().Password
 $env:PGCONNECT_TIMEOUT='5';$env:PGOPTIONS='-c default_transaction_read_only=on'
 Save-History
 Run-ReviewedSql 'verify_petugas_grants.sql' 'verify.log' 'PETUGAS_EXISTING_VERIFIED'
 $history.status='existing_verified_readonly';Save-History
 if(!$ApplyGrants){Write-Output "VERIFIED_READONLY: no grants applied. Receipt: $root";return}
 $history.mode='grants_only';$history.status='applying_grants';Save-History
 $env:PGOPTIONS='-c lock_timeout=5s -c statement_timeout=60s'
 $variables.NOTARIS_DEV_GRANTS_APPROVED='true'
 Run-ReviewedSql 'recover_petugas_grants_only.sql' 'grants.log' 'PETUGAS_GRANTS_ONLY_COMMITTED'
 $history.grantsCommitConfirmed=$true;Save-History
 $env:PGOPTIONS='-c default_transaction_read_only=on'
 Run-ReviewedSql 'verify_petugas_grants.sql' 'post-verify.log' 'PETUGAS_EXISTING_VERIFIED'
 # Actual authenticated reads as the app; no INSERT, nextval, setval or UPDATE.
 $env:PGUSER=$settings.DB_USER;$env:PGPASSWORD=$settings.DB_PASSWORD
 $appFile=Join-Path $root 'app-verification.sql'
 @'
\pset format unaligned
\pset tuples_only on
BEGIN READ ONLY;
SELECT json_build_object('database',current_database(),'address',inet_server_addr(),'port',inet_server_port(),
 'can_ddl',has_schema_privilege(current_user,'public','CREATE'),
 'receipts',(SELECT count(*) FROM public.petugas_sync_mutations),
 'outbox',(SELECT count(*) FROM public.petugas_sync_outbox),
 'counter',(SELECT count(*) FROM public.petugas_sync_publication WHERE id=1 AND last_seq=0 AND min_cursor=0),
 'sequence_unused',(SELECT last_value=1 AND NOT is_called FROM public.petugas_sync_outbox_id_seq),
 'allowed',has_table_privilege(current_user,'public.petugas_sync_mutations','INSERT')
 AND has_table_privilege(current_user,'public.petugas_sync_outbox','INSERT')
 AND has_table_privilege(current_user,'public.petugas_sync_outbox','UPDATE')
 AND has_table_privilege(current_user,'public.petugas_sync_publication','UPDATE')
 AND has_sequence_privilege(current_user,'public.petugas_sync_outbox_id_seq','USAGE'));
ROLLBACK;
'@|Set-Content $appFile
 $result=Invoke-NotarisPsqlFile -Executable (Join-Path $PostgresBin 'psql.exe') -File $appFile -Log (Join-Path $root 'app.log')
 if($result.ExitCode -ne 0){throw 'Application verification failed; inspect receipt, no automatic rollback'}
 $app=(Get-Content $result.Stdout|Where-Object {$_ -match '^\{'}|ConvertFrom-Json)
 if($app.database -ne 'notarisdev' -or $app.address -ne '127.0.0.1' -or $app.port -ne 5432 -or $app.can_ddl -or !$app.allowed -or !$app.sequence_unused -or $app.receipts -ne 0 -or $app.outbox -ne 0 -or $app.counter -ne 1){throw 'Unexpected application verification result'}
 $history.status='grants_and_postchecks_verified';$history.finishedUtc=[datetime]::UtcNow.ToString('o');Save-History
 Write-Output "GRANTS_VERIFIED: no schema/data/UUID/cursor changes. Receipt: $root"
 Write-Output 'Bootstrap, publisher, HTTP write smoke and Flutter activation were NOT run.'
} catch {
 $history.status='failed_requires_inspection';Save-History;throw
} finally {
 foreach($key in $previous.Keys){if($null -eq $previous[$key]){Remove-Item -LiteralPath "Env:$key" -ErrorAction SilentlyContinue}else{[Environment]::SetEnvironmentVariable($key,$previous[$key])}}
 $Credential=$null;$secret=$null
}
