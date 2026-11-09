param(
 [ValidateSet('Check','LocalBootstrap','UploadPilot')][string]$Stage = 'Check',
 [string]$ApprovedSha256 = ''
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$local = Join-Path $repo '.local'
$checkFile = Join-Path $local 'development-transaction-pilot-check.json'
$checkpoint = Join-Path $local 'development-transaction-pilot-checkpoint.json'
$bootstrapLock = Join-Path $local 'development-transaction-pilot-bootstrap.lock'
$uploadLock = Join-Path $local 'development-transaction-pilot-upload-attempt.lock'
$backupReceipt = Join-Path $local 'development-transaction-pilot-backup.json'
$flutterDir = Join-Path $repo 'frontend_notaris'
$backendDir = Join-Path $repo 'backend-notaris-go'
$psqlBin = 'D:/Program Files/PostgreSQL/bin'

function Read-Json([string]$File) { Get-Content -LiteralPath $File -Raw | ConvertFrom-Json }
function Get-Sha([string]$File) { (Get-FileHash -LiteralPath $File -Algorithm SHA256).Hash.ToLowerInvariant() }
function Write-Json([string]$File, $Value) { [IO.File]::WriteAllText($File, ($Value | ConvertTo-Json -Depth 20)) }
function Assert-Approved([string]$File) {
 if ($ApprovedSha256 -notmatch '^[a-fA-F0-9]{64}$' -or (Get-Sha $File) -ine $ApprovedSha256) {
  throw "Stage $Stage requires separate approval of the exact SHA-256 of $File"
 }
}
function Assert-Closed([string]$File) {
 foreach ($suffix in @('-wal','-shm','-journal')) {
  if (Test-Path -LiteralPath ($File+$suffix)) { throw 'Close development SQLite writers before the pilot' }
 }
}

if ($Stage -eq 'Check' -and (Test-Path -LiteralPath $bootstrapLock)) {
 & python (Join-Path $PSScriptRoot 'check-notarisdev-transaction-pilot.py') --inspect
 if ($LASTEXITCODE) { throw 'Read-only checkpoint inspection failed' }
 return
}
$backup = Read-Json $backupReceipt
if ((Get-Sha $backup.backup) -ine $backup.backup_sha256) { throw 'SQLite backup checksum mismatch' }
if ($Stage -eq 'Check') {
 $result = & (Join-Path $PSScriptRoot 'check-notarisdev-transaction-pilot.ps1') -Stage Check -Backup $backup.backup
 $value = ($result -join "`n") | ConvertFrom-Json
 if ($value.backup -ne 'matches') { throw 'Current consistent SQLite backup required' }
 if (!(Test-Path -LiteralPath $checkFile) -or
     ((Read-Json $checkFile) | ConvertTo-Json -Depth 20 -Compress) -cne ($value | ConvertTo-Json -Depth 20 -Compress)) {
  Write-Json $checkFile $value
 }
 $value
 Write-Output "LOCAL_BOOTSTRAP_REVIEW_SHA256: $(Get-Sha $checkFile)"
 return
}

if ($env:NOTARIS_DEV_UI_SMOKE -eq '1') { throw 'UI Smoke blocks execution' }
$check = Read-Json $checkFile
$planFile = Join-Path $PSScriptRoot 'plans/notarisdev-transaction-pilot.json'
$recipe = Read-Json $planFile
$sqlite = Join-Path $env:APPDATA ('com.notaris/frontend_notaris/notarisdev/'+$recipe.generation+'/offline.sqlite')
Assert-Closed $sqlite
if ($check.sqlite -cne $sqlite -or $check.sqlite -cne $backup.source -or $check.backup -cne 'matches' -or
    $check.plan_sha256 -cne (Get-Sha $planFile) -or $check.sqlite_sha256 -cne $backup.source_sha256) {
 throw 'Check, profile and backup do not match'
}
$pilot = @{stage=$Stage}
if ($Stage -eq 'LocalBootstrap') {
 Assert-Approved $checkFile
 if ((Test-Path -LiteralPath $bootstrapLock) -or (Test-Path -LiteralPath $checkpoint) -or (Get-Sha $sqlite) -cne $check.sqlite_sha256) {
  throw 'Previous bootstrap attempt or changed source. Run Check for read-only inspection'
 }
 $fresh = & (Join-Path $PSScriptRoot 'check-notarisdev-transaction-pilot.ps1') -Stage Check -Backup $backup.backup
 $fresh = ($fresh -join "`n") | ConvertFrom-Json
 if (($fresh | ConvertTo-Json -Depth 20 -Compress) -cne ($check | ConvertTo-Json -Depth 20 -Compress)) {
  throw 'Approved Check evidence changed'
 }
} else {
 Assert-Approved $checkpoint
 $receipt = Read-Json $checkpoint
 if (!(Test-Path -LiteralPath $bootstrapLock) -or (Test-Path -LiteralPath $uploadLock) -or
     $receipt.status -cne 'LOCAL_COMMITTED_PENDING' -or $receipt.check_sha256 -cne (Get-Sha $checkFile) -or
     $receipt.uuid -cnotmatch '^[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}$' -or
     $receipt.mutation_id -cnotmatch '^[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}$' -or
     $receipt.payload_sha256 -cnotmatch '^[a-f0-9]{64}$') {
  throw 'Checkpoint invalid or Upload already attempted. Run Check and inspect the outcome'
 }
 foreach ($key in @('uuid','mutation_id','payload_sha256')) { $pilot[$key] = $receipt.$key }
}

. (Join-Path $PSScriptRoot 'petugas-operations-common.ps1')
$settings = Read-PetugasDevelopmentSettings (Join-Path $backendDir '.env.notarisdev')
$probe = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,8081)
try { $probe.Start() } finally { $probe.Stop() }
$run = Join-Path $local ('development-pilot-run-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $run | Out-Null
$runtime = Join-Path $run 'runtime-plan.json'
Write-Json $runtime @{target='127.0.0.1:5432/notarisdev';events=@();pilot=$pilot}
$manifestFile = Join-Path $run 'manifest.json'
$manifest = @{stage=$Stage;sqlite=$sqlite;runtime_plan=$runtime;runtime_sha256=(Get-Sha $runtime);
 check=$checkFile;check_sha256=(Get-Sha $checkFile);backup=$backup.backup;backup_sha256=$backup.backup_sha256}
$vars = @{
 NOTARIS_UI_ACCEPTANCE_PLAN=$runtime;NOTARIS_UI_ACCEPTANCE_SHA256=$manifest.runtime_sha256
 PGHOST='127.0.0.1';PGPORT='5432';PGDATABASE='notarisdev';PGUSER=$settings.DB_USER;PGPASSWORD=$settings.DB_PASSWORD
 PGOPTIONS=$(if ($Stage -eq 'LocalBootstrap') {'-c default_transaction_read_only=on'} else {$null});PGCONNECT_TIMEOUT='5'
 DEVELOPMENT_PILOT_BOOTSTRAP_MANIFEST=$null;DEVELOPMENT_PILOT_BOOTSTRAP_TOKEN=$null;DEVELOPMENT_PILOT_MANIFEST_SHA256=$null
}
foreach ($key in @('DB_HOST','DB_PORT','DB_NAME','DB_USER','DB_PASSWORD','DB_SSLMODE','PORT','JWT_SECRET','JWT_EXPIRE_MINUTES','PETUGAS_PUBLISHER_ENABLED')) {
 $vars[$key] = $settings[$key]
}
$saved = @{}
foreach ($key in $vars.Keys) { $saved[$key] = [Environment]::GetEnvironmentVariable($key) }
$location = Get-Location
$owned = $null
try {
 foreach ($key in $vars.Keys) { [Environment]::SetEnvironmentVariable($key,$vars[$key]) }
 Set-Location $backendDir
 $binary = Join-Path $run 'backend.exe'
 & go build -o $binary ./cmd
 if ($LASTEXITCODE) { throw 'Pilot backend build failed' }
 $owned = Start-Process -FilePath $binary -WorkingDirectory $backendDir -WindowStyle Hidden -PassThru `
  -RedirectStandardOutput (Join-Path $run 'backend.log') -RedirectStandardError (Join-Path $run 'backend.stderr')
 $base = 'http://127.0.0.1:8081/api/v1'
 $ready = $false
 for ($i=0; $i -lt 20 -and !$ready; $i++) {
  if ($owned.HasExited) { throw 'Owned backend stopped before attestation' }
  try { Invoke-RestMethod -Uri "$base/health" -TimeoutSec 2 -MaximumRedirection 0 | Out-Null; $ready = $true }
  catch { Start-Sleep -Milliseconds 300 }
 }
 if (!$ready -or $owned.HasExited -or
     !(Get-NetTCPConnection -LocalAddress '127.0.0.1' -LocalPort 8081 -State Listen -OwningProcess $owned.Id -ErrorAction SilentlyContinue)) {
  throw 'Port 8081 is not owned by the pilot backend'
 }
 $login = Read-Json (Join-Path $local ('notarisdev-'+$recipe.generation+'/login.private.json'))
 if ($login.username -cne 'fixture.operator') { throw 'Fixture login required' }
 $auth = Invoke-RestMethod -Method Post -Uri "$base/auth/login" -ContentType 'application/json' `
  -Body (@{username=$login.username;password=$login.password} | ConvertTo-Json -Compress) -TimeoutSec 10 -MaximumRedirection 0
 $token = $auth.data.token
 $login = $null
 if (!$token -or $auth.data.user.id -ne 2001 -or $auth.data.user.group_id -ne 11) { throw 'Fixture account mismatch' }
 $headers = @{Authorization="Bearer $token"}
 $att = (Invoke-RestMethod -Uri "$base/development/transaction-acceptance" -Headers $headers -TimeoutSec 10 -MaximumRedirection 0).data
 if ($owned.HasExited -or $att.database -cne 'notarisdev' -or $att.host -cne '127.0.0.1' -or $att.port -ne 5432 -or
     $att.marker -cne 'NOTARISDEV SYNTHETIC v1' -or $att.role -cne 'nd_app_14af5452144b' -or $att.account_id -ne 2001 -or $att.group_id -ne 11 -or
     $att.pilot_stage -cne $Stage -or $att.plan_sha256 -cne $manifest.runtime_sha256) { throw 'Runtime attestation mismatch' }
 Write-Json (Join-Path $run 'attestation.json') $att
 if ($Stage -eq 'UploadPilot') {
  # Obtain a fresh recovery archive from the attested target. Decode it without restoring.
  $dump = Join-Path $run 'recovery.dump'
  $env:PGOPTIONS = '-c default_transaction_read_only=on'
  try {
   & (Join-Path $psqlBin 'pg_dump.exe') -w -h 127.0.0.1 -p 5432 -U $settings.DB_USER -d notarisdev -Fc -f $dump
   if ($LASTEXITCODE) { throw 'PostgreSQL recovery backup failed' }
  } finally { Remove-Item Env:PGOPTIONS -ErrorAction SilentlyContinue }
  $toc = & (Join-Path $psqlBin 'pg_restore.exe') --list $dump
  if ($LASTEXITCODE) { throw 'PostgreSQL recovery archive unreadable' }
  foreach ($table in @('transaction_cloud','transaction_cloud_detail','transaction_cloud_process','transaction_cloud_payment',
      'transaction_cloud_mutation','transaction_cloud_outbox','transaction_cloud_publication','transaction_cloud_number_counter')) {
   if (!($toc | Where-Object { $_ -match " TABLE DATA public $table " })) { throw "Recovery archive missing $table" }
  }
  & (Join-Path $psqlBin 'pg_restore.exe') --file=NUL $dump
  if ($LASTEXITCODE) { throw 'Recovery archive decode failed' }
  foreach ($key in @('uuid','mutation_id','payload_sha256')) { $manifest[$key]=$receipt.$key }
  $manifest.checkpoint_sha256 = $ApprovedSha256.ToLowerInvariant()
  $manifest.recovery_backup = $dump
  $manifest.recovery_sha256 = Get-Sha $dump
 }
 Write-Json $manifestFile $manifest
 $manifestHash = Get-Sha $manifestFile
 Set-Location $flutterDir
 if ($Stage -eq 'LocalBootstrap') {
  $env:DEVELOPMENT_PILOT_BOOTSTRAP_MANIFEST = $manifestFile
  $env:DEVELOPMENT_PILOT_MANIFEST_SHA256 = $manifestHash
  $env:DEVELOPMENT_PILOT_BOOTSTRAP_TOKEN = $token
  & flutter test tool/notarisdev_transaction_pilot_bootstrap.dart --reporter expanded *> (Join-Path $run 'bootstrap.log')
  if ($LASTEXITCODE -or !(Test-Path -LiteralPath $checkpoint)) { throw 'Bootstrap outcome requires read-only Check. Keep the attempt lock' }
  Read-Json $checkpoint
  Write-Output "LOCAL_COMMITTED_PENDING: $(Get-Sha $checkpoint)"
 } else {
  & flutter run -d windows --debug -t lib/transaction_monitor_isolated_main.dart `
   "--dart-define=DEVELOPMENT_PILOT_MANIFEST=$manifestFile" "--dart-define=DEVELOPMENT_PILOT_MANIFEST_SHA256=$manifestHash"
  if ($LASTEXITCODE) { throw 'Pilot UI stopped. Run read-only Check before further action' }
 }
} finally {
 try {
  if ($owned -and !$owned.HasExited) { $owned.Kill(); [void]$owned.WaitForExit(5000) }
 } finally {
  $token = $null
  $auth = $null
  $headers = $null
  Set-Location $location
  foreach ($key in $saved.Keys) { [Environment]::SetEnvironmentVariable($key,$saved[$key]) }
 }
}
