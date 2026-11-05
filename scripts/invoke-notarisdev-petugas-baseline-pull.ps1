# Existing-profile, GET-only maintenance entry. Default performs NO SQLite writes.
param(
 [Parameter(Mandatory)][string]$PreparedReceiptDirectory,
 [switch]$Apply,[string]$ConfirmTarget,[switch]$MaintenanceConfirmed
)
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
$profile=Get-Content (Join-Path $repo '.local/notarisdev-profile.json') -Raw|ConvertFrom-Json
$target=Join-Path ([Environment]::GetFolderPath('ApplicationData')) ('com.notaris/frontend_notaris/notarisdev/'+$profile.generation+'/offline.sqlite')
$target=[IO.Path]::GetFullPath($target)
if($Apply -and (!$MaintenanceConfirmed -or $ConfirmTarget -cne $target)){throw 'Apply requires separate final approval, exact -ConfirmTarget and -MaintenanceConfirmed'}
$root=(Resolve-Path -LiteralPath $PreparedReceiptDirectory).Path
if(!$root.StartsWith((Join-Path $repo '.local')+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Workspace-owned preparation receipt required'}
$prepared=Get-Content (Join-Path $root 'preparation.json') -Raw|ConvertFrom-Json
if($profile.database -cne 'notarisdev' -or $profile.port -ne 5432 -or $profile.fixture -cne 'smoke-v1' -or
   $prepared.kind -cne 'existing-petugas-baseline-v1' -or $prepared.generation -cne $profile.generation -or
   $prepared.database_path -cne $target -or $prepared.account_id -ne 2001 -or $prepared.group_id -ne 11 -or
   !$prepared.backup.verified_reopened -or !$prepared.source_unchanged){throw 'Reviewed target/backup mismatch'}
if([IO.Path]::GetFullPath($prepared.backup.path) -cne (Join-Path $root 'before-import.sqlite')){throw 'Backup must be inside the prepared receipt'}
$identity=Get-Content (Join-Path $repo ('.local/notarisdev-'+$profile.generation+'/petugas-device.json')) -Raw|ConvertFrom-Json
$machine=(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Cryptography').MachineGuid.Trim().ToLowerInvariant()
$sha=[Security.Cryptography.SHA256]::Create()
try{$machineHash=([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($machine)))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose();$machine=$null}
if($identity.kind -cne 'notaris-petugas-profile-v1' -or $identity.database_path -cne $target -or
   $identity.generation -cne $profile.generation -or $identity.device_id -cne $prepared.device_id -or
   $identity.device_id -notmatch '^ndpetugas-[a-f0-9]{32}$' -or $identity.machine_fingerprint -cne $machineHash){throw 'Stable machine/profile device identity mismatch; no automatic rebind'}
function Assert-BaselineSource {
 # Deny a concurrent writable handle, including an idle DBeaver SQLite writer.
 # DBeaver running against another database is not itself a target writer.
 $readLock=[IO.File]::Open($target,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
 try {
 if(!(Test-Path -LiteralPath $target) -or (Get-FileHash -LiteralPath $target).Hash.ToLowerInvariant() -cne $prepared.source.sha256 -or
    (Get-FileHash -LiteralPath $prepared.backup.path).Hash.ToLowerInvariant() -cne $prepared.backup.sha256){throw 'Source/backup changed; STOP without import'}
 foreach($suffix in @('-wal','-shm','-journal')){if(Test-Path -LiteralPath ($target+$suffix)){throw 'SQLite sidecar appeared; STOP without checkpoint'}}
 }finally{$readLock.Dispose()}
}
Assert-BaselineSource
$clients=@(Get-CimInstance Win32_Process|Where-Object {$_.Name -in @('frontend_notaris.exe','flutter_tester.exe') -or ($_.Name -in @('dart.exe','dartvm.exe') -and $_.CommandLine -match 'flutter_tools.*\brun\b')})
if($clients.Count){throw 'Development client/writer active; stop it before this operation'}
if(@(Get-NetTCPConnection -LocalPort 8081 -State Listen -ErrorAction SilentlyContinue).Count){throw 'Backend port occupied; will not reuse or terminate another process'}
$mode=if($Apply){'apply'}else{'dry-run'}
$attempt=Join-Path $root ($mode+'-attempt.json')
if(Test-Path -LiteralPath $attempt){throw 'Existing attempt retained: inspect before another invocation; no automatic retry'}
if($Apply){
 $review=Get-Content (Join-Path $root 'pull-preflight.json') -Raw|ConvertFrom-Json
 if($review.status -cne 'dry_run_ready_awaiting_approval' -or $review.applied -or $review.scope -cne $prepared.scope -or
    $review.source_sha256 -cne $prepared.source.sha256 -or $review.backup_sha256 -cne $prepared.backup.sha256){throw 'Successful matching read-only preflight required'}
}
. (Join-Path $PSScriptRoot 'petugas-operations-common.ps1')
$settings=Read-PetugasDevelopmentSettings (Join-Path $repo 'backend-notaris-go/.env.notarisdev')
$credentialFile=Join-Path $repo ('.local/notarisdev-'+$profile.generation+'/login.private.json')
$credentials=Get-Content -LiteralPath $credentialFile -Raw|ConvertFrom-Json
if($credentials.username -cne 'fixture.operator' -or !$credentials.password -or !$settings.JWT_SECRET){throw 'Trusted fixture credential unavailable'}
$oldLocation=Get-Location
$keys=@('DB_HOST','DB_PORT','DB_NAME','DB_USER','DB_PASSWORD','DB_SSLMODE','PORT','JWT_SECRET','JWT_EXPIRE_MINUTES','PETUGAS_PUBLISHER_ENABLED','PGOPTIONS','PGAPPNAME','PGCONNECT_TIMEOUT','NOTARIS_FIXTURE_LOGIN','NOTARIS_FIXTURE_PASSWORD','NOTARIS_EXISTING_BASELINE_RECEIPT','NOTARIS_EXISTING_BASELINE_APPLY','NOTARIS_EXISTING_BASELINE_CONFIRM','NOTARIS_BASELINE_LIVE_TOKEN','NOTARIS_E2E_URL','NOTARIS_E2E_TOKEN','NOTARIS_PEMOHON_DEV_SMOKE','NOTARIS_PETUGAS_BASELINE_LIVE')
$previous=@{};foreach($key in $keys){$previous[$key]=[Environment]::GetEnvironmentVariable($key)}
$backend=$null;$authProcess=$null;$completed=$false
try {
 Set-Location (Join-Path $repo 'backend-notaris-go')
 $go=(Get-Command go -ErrorAction Stop).Source
 $backendExe=Join-Path $root ('backend-'+$mode+'.exe');$authExe=Join-Path $root ('auth-'+$mode+'.exe')
 if((Invoke-PetugasBoundedProcess $go @('build','-o',$backendExe,'./cmd') (Join-Path $root ('build-backend-'+$mode+'.log')) 120) -ne 0){throw 'Backend build failed'}
 if((Invoke-PetugasBoundedProcess $go @('build','-o',$authExe,(Join-Path $PSScriptRoot 'petugas-baseline-auth.go')) (Join-Path $root ('build-auth-'+$mode+'.log')) 120) -ne 0){throw 'Auth adapter build failed'}
 foreach($key in @('DB_HOST','DB_PORT','DB_NAME','DB_USER','DB_PASSWORD','JWT_SECRET')){[Environment]::SetEnvironmentVariable($key,$settings[$key])}
 $env:DB_SSLMODE='disable';$env:PORT='8081';$env:JWT_EXPIRE_MINUTES='5';$env:PETUGAS_PUBLISHER_ENABLED='false'
 $env:PGOPTIONS='-c default_transaction_read_only=on -c statement_timeout=10000 -c lock_timeout=5000';$env:PGAPPNAME='petugas-existing-baseline-readonly';$env:PGCONNECT_TIMEOUT='5'
 $env:NOTARIS_FIXTURE_LOGIN=$credentials.username;$env:NOTARIS_FIXTURE_PASSWORD=$credentials.password
 $start=[Diagnostics.ProcessStartInfo]::new();$start.FileName=$authExe;$start.WorkingDirectory=(Get-Location).Path;$start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
 $authProcess=[Diagnostics.Process]::new();$authProcess.StartInfo=$start
 if(!$authProcess.Start()){throw 'Credential verification could not start'}
 $privateOutput=$authProcess.StandardOutput.ReadToEndAsync();$privateError=$authProcess.StandardError.ReadToEndAsync()
 if(!$authProcess.WaitForExit(20000)){$authProcess.Kill();throw 'Credential verification timeout'}
 if($authProcess.ExitCode -ne 0){throw 'Read-only deployment/baseline/credential check failed; no bypass'}
 try{$auth=$privateOutput.GetAwaiter().GetResult()|ConvertFrom-Json}catch{throw 'Private authentication response invalid'}
 if(!$auth.credential_verified -or $auth.account_id -ne 2001 -or $auth.group_id -ne 11 -or !$auth.token){throw 'Authenticated account mismatch'}
 $privateOutput=$null;$privateError=$null;$credentials=$null
 Remove-Item Env:NOTARIS_FIXTURE_LOGIN,Env:NOTARIS_FIXTURE_PASSWORD -ErrorAction SilentlyContinue
 [ordered]@{accountId=2001;groupId=11;credentialVerifiedBy='existing AuthService.Login bcrypt + active account/group';serverReadOnly=$true;serverPublished=4;pending=0;lastSeq=4;minCursor=0;httpLoginPost=$false;tokenPersisted=$false;publisherEnabled=$false}|ConvertTo-Json|Set-Content (Join-Path $root ('auth-proof-'+$mode+'.json'))
 $backend=Start-Process -FilePath $backendExe -WorkingDirectory (Join-Path $repo 'backend-notaris-go') -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $root ('backend-'+$mode+'.log')) -RedirectStandardError (Join-Path $root ('backend-'+$mode+'.stderr'))
 $handle=$backend.Handle
 $deadline=[datetime]::UtcNow.AddSeconds(20)
 while($true){
  if($backend.HasExited){throw 'Owned read-only backend stopped before readiness'}
  if(@(Get-NetTCPConnection -LocalPort 8081 -State Listen -ErrorAction SilentlyContinue|Where-Object {$_.OwningProcess -eq $backend.Id}).Count){break}
  if([datetime]::UtcNow -gt $deadline){throw 'Owned backend startup timeout'}
  Start-Sleep -Milliseconds 100
 }
 Assert-BaselineSource
 $env:NOTARIS_EXISTING_BASELINE_RECEIPT=$root;$env:NOTARIS_EXISTING_BASELINE_APPLY=if($Apply){'1'}else{'0'};$env:NOTARIS_EXISTING_BASELINE_CONFIRM=$ConfirmTarget;$env:NOTARIS_BASELINE_LIVE_TOKEN=$auth.token;$auth=$null
 Remove-Item Env:NOTARIS_E2E_URL,Env:NOTARIS_E2E_TOKEN,Env:NOTARIS_PEMOHON_DEV_SMOKE,Env:NOTARIS_PETUGAS_BASELINE_LIVE -ErrorAction SilentlyContinue
 # The marker precedes any possible SQLite reference/feed/page write.
 [ordered]@{mode=$mode;target=$target;scope=$prepared.scope;startedUtc=[datetime]::UtcNow.ToString('o');runnerSha256=(Get-FileHash $PSCommandPath).Hash;sourceSha256=$prepared.source.sha256;backupSha256=$prepared.backup.sha256;automaticRetry=$false}|ConvertTo-Json|Set-Content $attempt
 Set-Location (Join-Path $repo 'frontend_notaris')
 $flutterBin=Split-Path (Get-Command flutter -ErrorAction Stop).Source -Parent
 $dart=Join-Path $flutterBin 'cache/dart-sdk/bin/dart.exe';$tool=Join-Path $flutterBin 'cache/flutter_tools.snapshot'
 $exit=Invoke-PetugasBoundedProcess $dart @('--disable-dart-dev',$tool,'test','--no-pub','--reporter','expanded','tool/petugas_existing_baseline_entry.dart') (Join-Path $root ('flutter-'+$mode+'.log')) 120 -KillTreeOnTimeout
 if($exit -ne 0){throw 'Entry stopped; preserve receipts and inspect read-only; no retry/restore'}
 $output=Join-Path $root $(if($Apply){'pull-apply.json'}else{'pull-preflight.json'})
 $result=Get-Content $output -Raw|ConvertFrom-Json
 $expected=if($Apply){'applied_cursor4_reopened'}else{'dry_run_ready_awaiting_approval'}
 if($result.status -cne $expected){throw 'Incomplete acceptance; stop for read-only inspection'}
 if($Apply){
  $python=(Get-Command python -ErrorAction Stop).Source
  if((Invoke-PetugasBoundedProcess $python @((Join-Path $PSScriptRoot 'petugas-baseline-sqlite.py'),'--receipt',$root,'--verify-after') (Join-Path $root 'sqlite-postcheck.log') 30) -ne 0){throw 'Postcheck mismatch; STOP without retry/restore'}
 }else{Assert-BaselineSource}
 $completed=$true
}finally{
 if($backend -and !$backend.HasExited){$backend.Kill();$backend.WaitForExit(15000)|Out-Null}
 if($backend){[ordered]@{ownedPid=$backend.Id;stopped=$backend.HasExited;publisherEnabled=$false;postgresReadOnly=$true}|ConvertTo-Json|Set-Content (Join-Path $root ('backend-'+$mode+'-state.json'))}
 if($authProcess){$authProcess.Dispose()}
 $auth=$null;$credentials=$null;$privateOutput=$null;$privateError=$null
 foreach($key in $previous.Keys){if($null -eq $previous[$key]){Remove-Item -LiteralPath "Env:$key" -ErrorAction SilentlyContinue}else{[Environment]::SetEnvironmentVariable($key,$previous[$key])}}
 Set-Location $oldLocation
}
if($completed){
 if(@(Get-NetTCPConnection -LocalPort 8081 -State Listen -ErrorAction SilentlyContinue).Count){throw 'Residual listener: inspect ownership, do not kill another process'}
 if(Get-Content (Join-Path $root ('backend-'+$mode+'.log'))|Select-String 'petugas publication worker enabled'){throw 'Unexpected publisher activation; STOP'}
 [ordered]@{status=$expected;sqliteWrites=[bool]$Apply;backendStopped=$true;publisherEnabled=$false;finishedUtc=[datetime]::UtcNow.ToString('o');receipt=$root}|ConvertTo-Json|Set-Content (Join-Path $root ($mode+'-complete.json'))
 Write-Output ('PETUGAS_BASELINE_'+$expected.ToUpperInvariant()+': '+$root)
}
