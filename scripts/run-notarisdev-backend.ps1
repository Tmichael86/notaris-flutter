# Normal Go entry point, fail-closed development target. No migrations/bootstrap.
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$file = Join-Path $repo 'backend-notaris-go/.env.notarisdev'
if (!(Test-Path $file)) { throw 'Blocked: create private .env.notarisdev from the example AFTER sanitization/migration approval.' }
$settings = @{}
foreach ($line in Get-Content $file) {
    if ($line -match '^\s*([A-Z_]+)\s*=\s*(.*)$') { $settings[$matches[1]] = $matches[2].Trim().Trim('"').Trim("'") }
}
if ($settings['DB_NAME'] -ne 'notarisdev' -or $settings['DB_HOST'] -notin @('localhost','127.0.0.1') -or $settings['DB_PORT'] -ne '5432' -or $settings['PORT'] -ne '8081') { throw 'Only localhost:5432/notarisdev and HTTP port 8081 allowed' }
foreach ($key in @('DB_USER','DB_PASSWORD','JWT_SECRET')) { if (!$settings[$key]) { throw "Missing private development setting: $key" } }
if ($settings['DB_USER'] -eq 'postgres') { throw 'Use a dedicated least-privilege notarisdev application role' }
$previous=@{}; $location=Get-Location
$settings['PETUGAS_PUBLISHER_ENABLED']='false'
try {
    foreach ($key in $settings.Keys) { $previous[$key]=[Environment]::GetEnvironmentVariable($key); [Environment]::SetEnvironmentVariable($key,$settings[$key]) }
    Set-Location (Join-Path $repo 'backend-notaris-go')
    Write-Output 'Normal Go backend -> localhost:5432/notarisdev; publisher OFF. No migrations/bootstrap.'
    & go run ./cmd
    if ($LASTEXITCODE) { throw "Go backend exited with code $LASTEXITCODE" }
} finally {
    Set-Location $location
    foreach ($key in $previous.Keys) {
        if ($null -eq $previous[$key]) { Remove-Item -LiteralPath "Env:$key" -ErrorAction SilentlyContinue }
        else { [Environment]::SetEnvironmentVariable($key,$previous[$key]) }
    }
}
