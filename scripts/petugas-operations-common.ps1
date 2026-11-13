# Shared by the launcher and dependency-free guard tests. No action on import.
function Read-PetugasDevelopmentSettings([string]$File) {
 $settings=@{}
 foreach($line in Get-Content -LiteralPath $File){
  if($line -match '^\s*([A-Z_]+)\s*=\s*(.*)$'){
   if($settings.ContainsKey($matches[1])){throw 'Duplicate development configuration key'}
   $settings[$matches[1]]=$matches[2].Trim().Trim('"').Trim("'")
  }
 }
 if($settings.DB_HOST -cne '127.0.0.1' -or $settings.DB_PORT -cne '5432' -or $settings.DB_NAME -cne 'notarisdev' -or $settings.PORT -cne '8081' -or $settings.PETUGAS_PUBLISHER_ENABLED -cne 'false' -or
    $settings.DB_USER -notmatch '^[a-z_][a-z0-9_]{0,62}$' -or $settings.DB_USER -eq 'postgres' -or !$settings.DB_PASSWORD){throw 'Explicit restricted development configuration and publisher OFF required'}
 return $settings
}

function Assert-PetugasOperationsRequest([bool]$Apply,[string]$ConfirmTarget,[bool]$MaintenanceConfirmed,[bool]$RequirePublishedBaseline) {
 if($Apply -and ($ConfirmTarget -cne '127.0.0.1:5432/notarisdev' -or !$MaintenanceConfirmed)){throw 'Apply requires exact -ConfirmTarget and -MaintenanceConfirmed after separate permanent-write approval'}
 if($Apply -and $RequirePublishedBaseline){throw 'Published-baseline startup gate must remain read-only'}
}

function Get-PetugasOperationsBaseline([string]$ReceiptDirectory,[string]$Repository,[string]$AppRole) {
 $ReceiptDirectory=(Resolve-Path -LiteralPath $ReceiptDirectory).Path
 $h=Get-Content -LiteralPath (Join-Path $ReceiptDirectory 'history.json') -Raw|ConvertFrom-Json
 if($h.target -cne '127.0.0.1:5432/notarisdev' -or $h.mode -cne 'grants_only' -or $h.status -cne 'grants_and_postchecks_verified' -or $h.grantsCommitConfirmed -ne $true){throw 'Successful grants-only development receipt required'}
 foreach($name in @('verify.log','grants.log','post-verify.log')){
  if($h.($name+'_exit') -ne 0 -or (Get-Item -LiteralPath (Join-Path $ReceiptDirectory ($name+'.stderr'))).Length -ne 0){throw 'Grants receipt has unsuccessful SQL evidence'}
 }
 $lines=Get-Content -LiteralPath (Join-Path $ReceiptDirectory 'grants.log')
 $commit=[array]::IndexOf($lines,'COMMIT');$marker=[array]::IndexOf($lines,'PETUGAS_GRANTS_ONLY_COMMITTED')
 if($commit -lt 0 -or $marker -le $commit){throw 'Missing ordered COMMIT and grants success marker'}
 foreach($name in @('verify.log','post-verify.log')){
  if(!(Get-Content -LiteralPath (Join-Path $ReceiptDirectory $name)|Where-Object {$_ -ceq 'PETUGAS_EXISTING_VERIFIED'})){throw 'Missing verified postcheck marker'}
 }
 $expected=@('verify_petugas_grants.sql','recover_petugas_grants_only.sql','petugas_grants_context.sql','petugas_grants_existing_guard.sql','petugas_grants_target_guard.sql')
 if(@($h.sql).Count -ne $expected.Count -or @($h.sql.file|Select-Object -Unique).Count -ne $expected.Count){throw 'Unexpected receipt SQL list'}
 foreach($entry in $h.sql){
  if($entry.file -cnotin $expected -or (Get-FileHash -LiteralPath (Join-Path $Repository ('backend-notaris-go/migration_proposals/'+$entry.file))).Hash -cne $entry.sha256){throw 'Reviewed grants SQL checksum changed'}
 }
 if((Get-FileHash -LiteralPath (Join-Path $Repository 'scripts/recover-notarisdev-petugas-grants.ps1')).Hash -cne $h.runnerSha256 -or
    (Get-FileHash -LiteralPath (Join-Path $Repository 'scripts/notaris-psql-process.ps1')).Hash -cne $h.nativeHelperSha256){throw 'Reviewed recovery runner/helper checksum changed'}
 $backup=(Resolve-Path -LiteralPath $h.backup).Path
 $before=Get-Content -LiteralPath (Join-Path $backup 'preflight.json') -Raw|ConvertFrom-Json
 $install=Get-Content -LiteralPath (Join-Path $h.installationReceipt 'history.json') -Raw|ConvertFrom-Json
 $identity=Get-Content -LiteralPath (Join-Path $h.installationReceipt 'recovery-inspection.json') -Raw|ConvertFrom-Json
 if($before.database -cne 'notarisdev' -or $before.server_address -cne '127.0.0.1' -or $before.server_port -ne 5432 -or $before.marker -cne 'NOTARISDEV SYNTHETIC v1' -or $before.app_role -cne $AppRole -or
    $install.target -cne $h.target -or $install.appRole -cne $AppRole -or [IO.Path]::GetFullPath($install.backup) -cne $backup -or $install.backupSha256 -cne $h.backupSha256 -or
    (Get-FileHash -LiteralPath (Join-Path $backup 'notarisdev-before.dump')).Hash -cne $h.backupSha256 -or
    $identity.database -cne 'notarisdev' -or $identity.address -cne '127.0.0.1' -or $identity.port -ne 5432 -or $identity.uuid_fingerprint -cne $h.uuidFingerprint -or
    $identity.legacy_petugas_fingerprint -cne $before.petugas_fingerprint -or $identity.transaction_fingerprint -cne $before.transaction_fingerprint -or $identity.detail_fingerprint -cne $before.detail_fingerprint -or $identity.payment_fingerprint -cne $before.payment_fingerprint){throw 'Grants/install/backup identity chain mismatch'}
 $baseline=[ordered]@{app_role=$AppRole;petugas_hash=$before.petugas_fingerprint;uuid_hash=$h.uuidFingerprint;transaction_hash=$before.transaction_fingerprint;detail_hash=$before.detail_fingerprint;payment_hash=$before.payment_fingerprint}
 foreach($key in @('petugas_hash','uuid_hash','transaction_hash','detail_hash','payment_hash')){if($baseline[$key] -cnotmatch '^[a-f0-9]{32}$'){throw 'Missing verified baseline fingerprint'}}
 return $baseline
}

function Invoke-PetugasBoundedProcess([string]$Executable,[string[]]$Arguments,[string]$Log,[int]$TimeoutSeconds,[switch]$KillTreeOnTimeout) {
 # Native Windows quoting; credentials are inherited only via process environment.
 $quoted=($Arguments|ForEach-Object {'"'+[regex]::Replace([regex]::Replace($_,'(\\*)"','$1$1\"'),'(\\+)$','$1$1')+'"'}) -join ' '
 $process=Start-Process -FilePath $Executable -ArgumentList $quoted -WindowStyle Hidden -PassThru -RedirectStandardOutput $Log -RedirectStandardError ($Log+'.stderr')
 $handle=$process.Handle
 if(!$process.WaitForExit($TimeoutSeconds*1000)){
  # Only the exact child object started here; no process-name/service termination.
  if($KillTreeOnTimeout){$process.Kill($true)}else{$process.Kill()}
  $process.WaitForExit()
  throw "Owned command timed out; inspect $Log. Earlier commits may persist; no automatic retry"
 }
 return [int]$process.ExitCode
}
