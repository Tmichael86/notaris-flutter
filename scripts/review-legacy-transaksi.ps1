param([string]$PostgresBin='D:\Program Files\PostgreSQL\bin')
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
$settings=@{}
foreach($line in Get-Content (Join-Path $repo 'backend-notaris-go/.env')) {
    if($line -match '^\s*(DB_[A-Z_]+)\s*=\s*(.*)$') { $settings[$matches[1]]=$matches[2].Trim().Trim('"').Trim("'") }
}
$previous=@{}
foreach($key in @('PGPASSWORD','PGOPTIONS','PGCONNECT_TIMEOUT')) { $previous[$key]=[Environment]::GetEnvironmentVariable($key) }
try {
    $env:PGPASSWORD=$settings['DB_PASSWORD']; $env:PGOPTIONS='-c default_transaction_read_only=on'; $env:PGCONNECT_TIMEOUT='5'
    & (Join-Path $PostgresBin 'psql.exe') -X -w -h localhost -p 5432 -U $settings['DB_USER'] -d notarislokal -At -f (Join-Path $PSScriptRoot 'sql/review-legacy-transaksi.sql')
    if($LASTEXITCODE) { throw "Read-only legacy diagnostics failed (exit $LASTEXITCODE)" }
} finally {
    foreach($key in $previous.Keys) {
        if($null -eq $previous[$key]) { Remove-Item -LiteralPath "Env:$key" -ErrorAction SilentlyContinue }
        else { [Environment]::SetEnvironmentVariable($key,$previous[$key]) }
    }
}
