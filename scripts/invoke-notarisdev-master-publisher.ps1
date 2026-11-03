param(
 [ValidateSet('notaris','ppat','both')][string]$Domain='both',
 [ValidateRange(1,500)][int]$BatchSize=2,
 [ValidateRange(1,100)][int]$MaxBatches=10,
 [ValidateRange(1,300)][int]$TimeoutSeconds=60,
 [switch]$Apply,
 [switch]$LiveApproved,
 [string]$ConfirmTarget=''
)
$ErrorActionPreference='Stop'
if($Apply -and (!$LiveApproved -or $ConfirmTarget -cne '127.0.0.1:5432/notarisdev')) {
 throw 'Apply requires separate live approval and exact ConfirmTarget'
}
$repo=Split-Path $PSScriptRoot -Parent
Set-Location $repo
. ./scripts/petugas-operations-common.ps1
$settings=Read-PetugasDevelopmentSettings './backend-notaris-go/.env.notarisdev'
if($settings.DB_HOST -cne '127.0.0.1' -or "$($settings.DB_PORT)" -cne '5432' -or $settings.DB_NAME -cne 'notarisdev' -or $settings.PETUGAS_PUBLISHER_ENABLED -cne 'false') {
 throw 'Development target or background publisher configuration mismatch'
}
$names=@('MASTER_PUBLISH_DSN','PGUSER','PGPASSWORD','PGHOST','PGPORT','PGDATABASE')
$prior=@{};foreach($name in $names){$prior[$name]=[Environment]::GetEnvironmentVariable($name)}
try {
 $env:MASTER_PUBLISH_DSN='host=127.0.0.1 port=5432 dbname=notarisdev sslmode=disable'
 $env:PGUSER=$settings.DB_USER;$env:PGPASSWORD=$settings.DB_PASSWORD
 $env:PGHOST='127.0.0.1';$env:PGPORT='5432';$env:PGDATABASE='notarisdev'
 $publisherArgs=@('run','./cmd/masterpublish','--domain',$Domain,'--batch-size',"$BatchSize",'--max-batches',"$MaxBatches",'--timeout',("${TimeoutSeconds}s"))
 if($Apply){$publisherArgs+=@('--apply','--live-approved','--confirm-target',$ConfirmTarget)}
 Push-Location './backend-notaris-go'
 try {
  & go @publisherArgs
  if($LASTEXITCODE -ne 0){throw 'Manual Master publisher stopped; inspect database read-only before any retry'}
 } finally {Pop-Location}
} finally {
 foreach($name in $names){if($null -eq $prior[$name]){Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue}else{[Environment]::SetEnvironmentVariable($name,$prior[$name])}}
}
