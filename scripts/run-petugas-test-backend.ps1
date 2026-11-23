# Terminal 1: isolated backend, migrations/fixtures/publication managed for you.
param([switch]$ReadyOnly)
. "$PSScriptRoot/petugas-manual-common.ps1"
$repo = Split-Path $PSScriptRoot -Parent
& "$PSScriptRoot/start-petugas-manual-test.ps1" -BackendOnly
$pointer = Get-SessionPointer $repo
Write-Output 'Petugas TEST backend ready. Terminal 2: .\scripts\run-petugas-test-flutter.ps1'
Write-Output 'Ctrl+C stops this testing session. Session lifetime: 30 minutes.'
if ($ReadyOnly) { $global:LASTEXITCODE = 0; return }
try {
    while ((Read-State $pointer.Root).Phase -eq 'Running') { Start-Sleep -Seconds 1 }
} finally {
    & "$PSScriptRoot/stop-petugas-manual-test.ps1" -SessionRoot $pointer.Root
}
