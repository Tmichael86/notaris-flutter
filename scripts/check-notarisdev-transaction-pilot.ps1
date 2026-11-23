param([ValidateSet('Check')][string]$Stage = 'Check', [string]$Backup = '')
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$planPath = Join-Path $PSScriptRoot 'plans/notarisdev-transaction-pilot.json'
$plan = Get-Content -LiteralPath $planPath -Raw | ConvertFrom-Json
. (Join-Path $PSScriptRoot 'petugas-operations-common.ps1')
$settings = Read-PetugasDevelopmentSettings (Join-Path $repo 'backend-notaris-go/.env.notarisdev')
$pg = @{
 PGHOST = '127.0.0.1'; PGPORT = '5432'; PGDATABASE = 'notarisdev'
 PGUSER = $settings.DB_USER; PGPASSWORD = $settings.DB_PASSWORD
 PGOPTIONS = '-c default_transaction_read_only=on -c statement_timeout=5000'
 PGCONNECT_TIMEOUT = '4'
}
$saved = @{}
foreach ($key in $pg.Keys) { $saved[$key] = [Environment]::GetEnvironmentVariable($key) }
try {
 foreach ($key in $pg.Keys) { [Environment]::SetEnvironmentVariable($key, $pg[$key]) }
 $sql = Join-Path $PSScriptRoot 'sql/notarisdev-transaction-pilot-check.sql'
 $snapshot = & 'D:/Program Files/PostgreSQL/bin/psql.exe' -X -w -qAt -v ON_ERROR_STOP=1 `
  -v "APP_ROLE=$($settings.DB_USER)" -v "PEMOHON_UUID=$($plan.pemohon_uuid)" `
  -v "PETUGAS_UUID=$($plan.petugas_uuid)" -f $sql
 if ($LASTEXITCODE -ne 0 -or !$snapshot) { throw 'Read-only PostgreSQL Check failed or target refused' }
} finally {
 foreach ($key in $pg.Keys) { [Environment]::SetEnvironmentVariable($key, $saved[$key]) }
}
$arguments = @((Join-Path $PSScriptRoot 'check-notarisdev-transaction-pilot.py'))
if ($Backup) { $arguments += @('--backup', $Backup) }
$snapshot | & python @arguments
if ($LASTEXITCODE -ne 0) { throw 'Development pilot Check failed' }
