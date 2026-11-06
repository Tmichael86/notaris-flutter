param(
 [ValidateSet('Check','Backend','Dependencies','DeviceA','DeviceB','PublishNotaris','PublishPPAT')][string]$Stage='Check',
 [string]$Receipt='.local/transaction-live-readiness-20261106-113242',
 [string]$ApprovedPlanSha256=''
)
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
Set-Location $repo
$root=(Resolve-Path -LiteralPath $Receipt).Path
if(!$root.StartsWith((Join-Path $repo '.local')+[IO.Path]::DirectorySeparatorChar)){throw 'Owned receipt required'}
$prep=Get-Content (Join-Path $root 'ui-preparation.json') -Raw|ConvertFrom-Json
$plan=Join-Path $root 'ui-publication-allowlist.json'
$hash=(Get-FileHash -LiteralPath $plan -Algorithm SHA256).Hash
if($hash -cne $prep.allowlistSHA256){throw 'Prepared plan hash changed'}
$allow=Get-Content $plan -Raw|ConvertFrom-Json
if($allow.target -cne '127.0.0.1:5432/notarisdev' -or @($allow.events).Count -ne 4 -or @($allow.events|Where-Object{$_.operation -cne 'create' -or $_.revision -ne 1}).Count){throw 'Four CREATE-only events required'}
. ./scripts/petugas-operations-common.ps1
$s=Read-PetugasDevelopmentSettings './backend-notaris-go/.env.notarisdev'
if($s.DB_HOST -cne '127.0.0.1' -or $s.DB_NAME -cne 'notarisdev' -or "$($s.DB_PORT)" -cne '5432' -or "$($s.PORT)" -cne '8081' -or $s.PETUGAS_PUBLISHER_ENABLED -cne 'false'){throw 'Backend target mismatch'}
foreach($device in @('a','b')){
 $file=Join-Path $prep.profiles "$device.json"
 $m=Get-Content $file -Raw|ConvertFrom-Json
 if($m.generation -cne $prep.planLabel -or $m.device -cne ($prep.planLabel+'-'+$device) -or $m.deployment -cne 'NOTARISDEV SYNTHETIC v1' -or $m.sqlitePath -cne (Join-Path $prep.profiles "$device.sqlite") -or $m.baseUrl -cne 'http://127.0.0.1:8081/api/v1' -or $m.databaseTarget -cne $allow.target -or $m.accountId -ne 2001 -or $m.groupId -ne 11 -or $m.acceptanceSha256 -ine $hash -or $m.acceptancePlan -cne $plan){throw 'Manifest mismatch'}
}
if($Stage -eq 'Check'){Write-Output "PREPARED_NO_WRITE: $hash; two temporary profiles; approval required";return}
if($ApprovedPlanSha256 -ine $hash){throw 'Separate explicit approval and exact reviewed plan SHA256 required'}
$names=@('NOTARIS_UI_ACCEPTANCE_PLAN','NOTARIS_UI_ACCEPTANCE_SHA256','NOTARIS_UI_DEPENDENCIES_APPROVED','NOTARIS_UI_PROFILE_DIRECTORY','NOTARIS_UI_RECEIPT','NOTARIS_UI_TOKEN','NOTARIS_UI_PLAN_SHA256');$old=@{};foreach($key in $names){$old[$key]=[Environment]::GetEnvironmentVariable($key)}
$token=$null
try {
 if($Stage -eq 'Backend'){
  $env:NOTARIS_UI_ACCEPTANCE_PLAN=$plan;$env:NOTARIS_UI_ACCEPTANCE_SHA256=$hash
  & ./scripts/run-notarisdev-backend.ps1
  return
 }
 # Credentials/token remain in process memory, never a manifest or command line.
 $profile=Get-Content '.local/notarisdev-profile.json' -Raw|ConvertFrom-Json
 $login=Get-Content ('.local/notarisdev-'+$profile.generation+'/login.private.json') -Raw|ConvertFrom-Json
 if($login.username -cne 'fixture.operator'){throw 'Fixture account required'}
 $r=Invoke-RestMethod -Method Post -Uri 'http://127.0.0.1:8081/api/v1/auth/login' -Body (@{username=$login.username;password=$login.password}|ConvertTo-Json -Compress) -ContentType 'application/json' -TimeoutSec 10 -MaximumRedirection 0
 $token=$r.data.token
 if(!$token -or $r.data.user.id -ne 2001 -or $r.data.user.group_id -ne 11){throw 'Authenticated account mismatch'}
 $att=Invoke-RestMethod -Uri 'http://127.0.0.1:8081/api/v1/development/transaction-acceptance' -Headers @{Authorization="Bearer $token"} -TimeoutSec 10 -MaximumRedirection 0
 $d=$att.data
 if($d.database -cne 'notarisdev' -or $d.host -cne '127.0.0.1' -or $d.port -ne 5432 -or $d.marker -cne 'NOTARISDEV SYNTHETIC v1' -or $d.plan_sha256 -ine $hash -or $d.account_id -ne 2001 -or $d.group_id -ne 11){throw 'Runtime HTTP/database attestation mismatch'}
 $d|ConvertTo-Json|Set-Content (Join-Path $root 'attestation.json')
 if($Stage -eq 'Dependencies'){
  $lock=Join-Path $root 'ui-dependencies-attempted.lock'
  $f=[IO.File]::Open($lock,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);$f.Dispose()
  $env:NOTARIS_UI_DEPENDENCIES_APPROVED='CREATE_TWO_ALLOWLISTED_MASTERS';$env:NOTARIS_UI_PROFILE_DIRECTORY=$prep.profiles;$env:NOTARIS_UI_RECEIPT=$root;$env:NOTARIS_UI_TOKEN=$token;$env:NOTARIS_UI_PLAN_SHA256=$hash
  Set-Location (Join-Path $repo 'frontend_notaris')
  & flutter test tool/notarisdev_ui_dependencies.dart --reporter expanded *> (Join-Path $root 'ui-dependencies.log')
  if($LASTEXITCODE){throw 'Dependency setup stopped; inspect read-only, do not retry or delete lock'}
  return
 }
 if(!(Test-Path (Join-Path $root 'dependencies-ready.json'))){throw 'Verified Master receipts/publication/pull required first'}
 if($Stage -like 'Publish*'){
  $domain=if($Stage -eq 'PublishNotaris'){'notaris'}else{'ppat'}
  $e=@($allow.events|Where-Object{$_.kind -eq 'transaction' -and $_.domain -eq $domain})[0]
  & ./scripts/invoke-notarisdev-master-publisher.ps1 -Transaction -Domain $domain -BatchSize 1 -MaxBatches 1 -Apply -LiveApproved -ConfirmTarget $allow.target -OnlyUuid $e.uuid -ExpectedRevision 1 -ExpectedOperation create -ExpectedLastSeq $e.expected_last_seq -Allowlist $plan -ConfirmAllowlistSha256 $hash
  return
 }
 $device=if($Stage -eq 'DeviceA'){'a'}else{'b'}
 Set-Location (Join-Path $repo 'frontend_notaris')
 & flutter run -d windows --debug -t lib/transaction_monitor_isolated_main.dart --dart-define="TRANSACTION_MONITOR_PROFILE=$(Join-Path $prep.profiles "$device.json")"
 if($LASTEXITCODE){throw 'Flutter acceptance stopped'}
} finally { $token=$null;$login=$null;Set-Location $repo;foreach($key in $names){[Environment]::SetEnvironmentVariable($key,$old[$key])} }
