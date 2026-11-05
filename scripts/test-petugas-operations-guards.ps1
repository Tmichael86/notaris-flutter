# Dependency-free parser/approval/receipt guards. No database connection.
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'petugas-operations-common.ps1')
$checks=0
function Check([bool]$Condition,[string]$Name){if(!$Condition){throw "FAILED: $Name"};$script:checks++}
function Refuses([scriptblock]$Action,[string]$Name){$refused=$false;try{& $Action|Out-Null}catch{$refused=$true};Check $refused $Name}
foreach($name in @('petugas-operations-common.ps1','invoke-notarisdev-petugas-operations.ps1','run-notarisdev-backend.ps1','test-petugas-operations.ps1','test-petugas-operations-guards.ps1')){
 $tokens=$null;$parseErrors=$null
 [void][Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot $name),[ref]$tokens,[ref]$parseErrors)
 Check (!$parseErrors.Count) "parser $name"
}
Assert-PetugasOperationsRequest $false '' $false $false;$checks++
Assert-PetugasOperationsRequest $true '127.0.0.1:5432/notarisdev' $true $false;$checks++
Refuses {Assert-PetugasOperationsRequest $true '' $true $false} 'missing apply target'
Refuses {Assert-PetugasOperationsRequest $true '127.0.0.1:5432/notarislokal' $true $false} 'wrong apply database'
Refuses {Assert-PetugasOperationsRequest $true '127.0.0.1:5432/notarisdev' $false $false} 'missing maintenance acknowledgment'
Refuses {Assert-PetugasOperationsRequest $true '127.0.0.1:5432/notarisdev' $true $true} 'write through read-only publisher gate'
$root=Join-Path ([IO.Path]::GetTempPath()) ('notaris-ops-guards-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root|Out-Null
$settingsFile=Join-Path $root 'dev.env'
$config="DB_HOST=127.0.0.1`nDB_PORT=5432`nDB_NAME=notarisdev`nDB_USER=ops_app`nDB_PASSWORD=synthetic-only`nPORT=8081`nPETUGAS_PUBLISHER_ENABLED=false"
$config|Set-Content $settingsFile
Check ((Read-PetugasDevelopmentSettings $settingsFile).DB_USER -eq 'ops_app') 'valid configuration'
foreach($bad in @($config.Replace('notarisdev','notarislokal'),$config.Replace('127.0.0.1','localhost'),$config.Replace('5432','55445'),$config.Replace('ops_app','postgres'),$config.Replace('ENABLED=false','ENABLED=true'),($config+"`nDB_NAME=notarislokal"))){
 $bad|Set-Content $settingsFile;Refuses {Read-PetugasDevelopmentSettings $settingsFile} 'unsafe configuration'
}
$backup=Join-Path $root 'backup';$install=Join-Path $root 'install';$receipt=Join-Path $root 'receipt'
foreach($dir in @($backup,$install,$receipt)){New-Item -ItemType Directory -Path $dir|Out-Null}
'not an archive; test checksum bytes only'|Set-Content (Join-Path $backup 'notarisdev-before.dump')
$sha=(Get-FileHash (Join-Path $backup 'notarisdev-before.dump')).Hash
$hash='a'*32
@{database='notarisdev';server_address='127.0.0.1';server_port=5432;marker='NOTARISDEV SYNTHETIC v1';app_role='ops_app';petugas_fingerprint=$hash;transaction_fingerprint=$hash;detail_fingerprint=$hash;payment_fingerprint=$hash}|ConvertTo-Json|Set-Content (Join-Path $backup 'preflight.json')
@{target='127.0.0.1:5432/notarisdev';appRole='ops_app';backup=$backup;backupSha256=$sha}|ConvertTo-Json|Set-Content (Join-Path $install 'history.json')
@{database='notarisdev';address='127.0.0.1';port=5432;uuid_fingerprint=$hash;legacy_petugas_fingerprint=$hash;transaction_fingerprint=$hash;detail_fingerprint=$hash;payment_fingerprint=$hash}|ConvertTo-Json|Set-Content (Join-Path $install 'recovery-inspection.json')
$sql=@('verify_petugas_grants.sql','recover_petugas_grants_only.sql','petugas_grants_context.sql','petugas_grants_existing_guard.sql','petugas_grants_target_guard.sql')
$h=@{target='127.0.0.1:5432/notarisdev';mode='grants_only';status='grants_and_postchecks_verified';grantsCommitConfirmed=$true;backup=$backup;backupSha256=$sha;installationReceipt=$install;uuidFingerprint=$hash;
 sql=@($sql|ForEach-Object {@{file=$_;sha256=(Get-FileHash (Join-Path $repo ('backend-notaris-go/migration_proposals/'+$_))).Hash}});
 runnerSha256=(Get-FileHash (Join-Path $repo 'scripts/recover-notarisdev-petugas-grants.ps1')).Hash;nativeHelperSha256=(Get-FileHash (Join-Path $repo 'scripts/notaris-psql-process.ps1')).Hash;
 'verify.log_exit'=0;'grants.log_exit'=0;'post-verify.log_exit'=0}
function Save-FixtureHistory {$h|ConvertTo-Json -Depth 6|Set-Content (Join-Path $receipt 'history.json')}
Save-FixtureHistory
foreach($name in @('verify.log','post-verify.log')){'PETUGAS_EXISTING_VERIFIED'|Set-Content (Join-Path $receipt $name);[IO.File]::WriteAllText((Join-Path $receipt ($name+'.stderr')),'')}
@('BEGIN','COMMIT','PETUGAS_GRANTS_ONLY_COMMITTED')|Set-Content (Join-Path $receipt 'grants.log')
[IO.File]::WriteAllText((Join-Path $receipt 'grants.log.stderr'),'')
Check ((Get-PetugasOperationsBaseline $receipt $repo 'ops_app').uuid_hash -ceq $hash) 'complete receipt chain'
Refuses {Get-PetugasOperationsBaseline $receipt $repo 'wrong_app'} 'wrong application role'
foreach($field in @('target','mode','status','runnerSha256','nativeHelperSha256','uuidFingerprint','backupSha256')){
 $saved=$h[$field];$h[$field]='invalid';Save-FixtureHistory
 Refuses {Get-PetugasOperationsBaseline $receipt $repo 'ops_app'} "invalid receipt $field"
 $h[$field]=$saved
}
$h.grantsCommitConfirmed=$false;Save-FixtureHistory
Refuses {Get-PetugasOperationsBaseline $receipt $repo 'ops_app'} 'unconfirmed COMMIT'
$h.grantsCommitConfirmed=$true;Save-FixtureHistory
@('BEGIN','PETUGAS_GRANTS_ONLY_COMMITTED','COMMIT')|Set-Content (Join-Path $receipt 'grants.log')
Refuses {Get-PetugasOperationsBaseline $receipt $repo 'ops_app'} 'success marker before COMMIT'
@('BEGIN','COMMIT','PETUGAS_GRANTS_ONLY_COMMITTED')|Set-Content (Join-Path $receipt 'grants.log')
$saved=$h.sql[0].file;$h.sql[0].file='../unexpected.sql';Save-FixtureHistory
Refuses {Get-PetugasOperationsBaseline $receipt $repo 'ops_app'} 'unreviewed SQL path'
$h.sql[0].file=$saved;Save-FixtureHistory
'changed'|Set-Content (Join-Path $backup 'notarisdev-before.dump')
Refuses {Get-PetugasOperationsBaseline $receipt $repo 'ops_app'} 'changed backup checksum'
$nativeFile=Join-Path $root 'native probe with spaces.ps1'
@'
param([string]$Value)
Write-Output $Value
[Console]::Error.WriteLine('NOTICE: synthetic native stderr')
'@|Set-Content $nativeFile
$nativeLog=Join-Path $root 'native.log'
$exitCode=Invoke-PetugasBoundedProcess (Get-Command powershell.exe).Source @('-NoProfile','-ExecutionPolicy','Bypass','-File',$nativeFile,'value with spaces and trailing\') $nativeLog 10
Check ($exitCode -eq 0 -and (Get-Content $nativeLog) -ceq 'value with spaces and trailing\') 'native quoting and exit code'
Check ([bool](Get-Content ($nativeLog+'.stderr')|Select-String 'NOTICE: synthetic native stderr')) 'native stderr retained'
$pidFile=Join-Path $root 'timeout-child.pid'
'param([string]$PidFile); $PID | Set-Content $PidFile; Start-Sleep -Seconds 10'|Set-Content $nativeFile
Refuses {Invoke-PetugasBoundedProcess (Get-Command powershell.exe).Source @('-NoProfile','-ExecutionPolicy','Bypass','-File',$nativeFile,$pidFile) (Join-Path $root 'timeout.log') 2} 'bounded native timeout'
$childPid=[int](Get-Content $pidFile)
Check ($null -eq (Get-Process -Id $childPid -ErrorAction SilentlyContinue)) 'only owned timed-out process stopped'
$leafFile=Join-Path $root 'owned-leaf.ps1'
$leafPidFile=Join-Path $root 'owned-leaf.pid'
'param([string]$PidFile); $PID | Set-Content $PidFile; Start-Sleep -Seconds 30'|Set-Content $leafFile
@'
param([string]$PidFile,[string]$Leaf)
$child=Start-Process -FilePath (Get-Command powershell.exe).Source -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$Leaf+'"'),('"'+$PidFile+'"')) -WindowStyle Hidden -PassThru
$child.WaitForExit()
'@|Set-Content $nativeFile
Refuses {Invoke-PetugasBoundedProcess (Get-Command powershell.exe).Source @('-NoProfile','-ExecutionPolicy','Bypass','-File',$nativeFile,$leafPidFile,$leafFile) (Join-Path $root 'tree-timeout.log') 3 -KillTreeOnTimeout} 'bounded owned-tree timeout'
Check (Test-Path -LiteralPath $leafPidFile) 'owned grandchild actually started'
$leafPid=[int](Get-Content $leafPidFile)
$remainingLeaf=Get-Process -Id $leafPid -ErrorAction SilentlyContinue
if($remainingLeaf){$remainingLeaf.Kill();throw 'Owned Flutter-like descendant survived tree timeout'}
$checks++
Write-Output "PETUGAS_OPERATIONS_GUARDS_PASS: $checks checks; artifacts: $root"
