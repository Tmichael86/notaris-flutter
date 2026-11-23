param(
 [ValidateSet('Check','Backend','Dependencies','ResumeDependencies','DeviceA','DeviceB','PublishNotaris','PublishPPAT')][string]$Stage='Check',
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
$names=@('NOTARIS_UI_ACCEPTANCE_PLAN','NOTARIS_UI_ACCEPTANCE_SHA256','NOTARIS_UI_DEPENDENCIES_RESUME','NOTARIS_UI_DEPENDENCIES_APPROVED','NOTARIS_UI_PROFILE_DIRECTORY','NOTARIS_UI_RECEIPT','NOTARIS_UI_TOKEN','NOTARIS_UI_PLAN_SHA256');$old=@{};foreach($key in $names){$old[$key]=[Environment]::GetEnvironmentVariable($key)}
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
 if($Stage -in @('Dependencies','ResumeDependencies')){
  $resume=$Stage -eq 'ResumeDependencies'
  if($resume){
   $review=Get-Content (Join-Path $root 'resume-review.json') -Raw|ConvertFrom-Json
   if(!(Test-Path (Join-Path $root 'ui-dependencies-attempted.lock')) -or (Get-FileHash (Join-Path $root 'ui-dependencies-attempted.lock')).Hash -cne $review.originalLockSha256 -or $review.planSha256 -cne $hash){throw 'Original attempt/plan mismatch'}
   foreach($device in @('a','b')){if((Get-FileHash $review.sqlite.$device.path).Hash -cne $review.sqlite.$device.sha256 -or (Test-Path ($review.sqlite.$device.path+'-wal'))){throw 'Reviewed SQLite changed or active WAL; stop'}}
   $sql=Join-Path $review.audit 'audit.sql'
   if((Get-FileHash $sql).Hash -cne $review.sqlHash){throw 'Read-only verification SQL changed'}
   . ./scripts/notaris-psql-process.ps1
   $pgkeys=@('PGHOST','PGPORT','PGDATABASE','PGUSER','PGPASSWORD','PGOPTIONS');$saved=@{};foreach($k in $pgkeys){$saved[$k]=[Environment]::GetEnvironmentVariable($k)}
   try{
    $env:PGHOST='127.0.0.1';$env:PGPORT='5432';$env:PGDATABASE='notarisdev';$env:PGUSER=$s.DB_USER;$env:PGPASSWORD=$s.DB_PASSWORD;$env:PGOPTIONS='-c default_transaction_read_only=on'
    $v=Invoke-NotarisPsqlFile -Executable 'D:\Program Files\PostgreSQL\bin\psql.exe' -File $sql -Log (Join-Path $root 'resume-readonly.log')
    if($v.ExitCode -ne 0){throw 'Resume verification SQL failed'}
    $b=(Get-Content $v.Stdout|Where-Object{$_ -match '^\{'}|Select-Object -First 1)|ConvertFrom-Json
    if(@($b.notaris.parents).Count -ne 1 -or @($b.notaris.receipts).Count -ne 1 -or @($b.notaris.events).Count -ne 1 -or $b.notaris.parents[0].uuid -cne $review.ack.uuid -or $b.notaris.parents[0].revision -ne 1 -or $b.notaris.parents[0].status -ne 1 -or $null -ne $b.notaris.parents[0].deleted_at -or $b.notaris.receipts[0].request_hash -cne $review.requestHash -or ($b.notaris.receipts[0].ack|ConvertTo-Json -Compress) -cne ($review.ack|ConvertTo-Json -Compress) -or $b.notaris.events[0].id -ne $review.outboxId -or $b.notaris.events[0].uuid -cne $review.ack.uuid -or $b.notaris.events[0].revision -ne 1 -or $b.notaris.events[0].operation -cne 'create' -or $b.notaris.receipts[0].actor_id -ne 2001 -or $null -ne $b.notaris.events[0].sequence -or $b.notaris.pending_total -ne 1 -or $b.notaris.publication.last_seq -ne 5 -or $b.notaris.harga -ne 1 -or $b.notaris.proses -ne 1 -or $b.notaris.atribut -ne 1 -or $b.ppat.parents -ne 0 -or $b.ppat.receipts -ne 0 -or $b.ppat.events -ne 0 -or $b.ppat.pending_total -ne 0 -or $b.ppat.publication.last_seq -ne 5 -or $b.transactions.receipts -ne 6 -or $b.transactions.events -ne 6 -or $b.transactions.pending -ne 0 -or $b.transactions.publication.last_seq -ne 6){throw 'Resume baseline mismatch; no recovery write'}
   }finally{foreach($k in $pgkeys){[Environment]::SetEnvironmentVariable($k,$saved[$k])}}
   $env:NOTARIS_UI_DEPENDENCIES_RESUME='NOTARIS_ACKED_PENDING_PUBLICATION'
  }

  $lock=Join-Path $root $(if($resume){'ui-dependencies-resume-attempted.lock'}else{'ui-dependencies-attempted.lock'})
  $f=[IO.File]::Open($lock,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);$f.Dispose()
  $env:NOTARIS_UI_DEPENDENCIES_APPROVED='CREATE_TWO_ALLOWLISTED_MASTERS';$env:NOTARIS_UI_PROFILE_DIRECTORY=$prep.profiles;$env:NOTARIS_UI_RECEIPT=$root;$env:NOTARIS_UI_TOKEN=$token;$env:NOTARIS_UI_PLAN_SHA256=$hash
  Set-Location (Join-Path $repo 'frontend_notaris')
  & flutter test tool/notarisdev_ui_dependencies.dart --reporter expanded *> (Join-Path $root $(if($resume){'ui-dependencies-resume.log'}else{'ui-dependencies.log'}))
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
