# Dependency-free checks; no database, GUI or service is started/stopped.
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/petugas-manual-common.ps1"
$checks = 0
foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1') {
    $tokens = $null; $errors = $null
    [void][Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
    if ($errors.Count) { throw ($errors | Out-String) }
    $checks++
}
foreach ($invalid in @('C:\', (Join-Path ([IO.Path]::GetTempPath()) 'other-session'))) {
    $rejected = $false
    try { [void](Assert-TestRoot $invalid) } catch { $rejected = $true }
    if (!$rejected) { throw 'Unsafe root accepted' }
    $checks++
}
$process = Get-Process -Id $PID
$record = @{ Id = $PID; Started = $process.StartTime.ToUniversalTime().ToString('o') }
# Round-trip matches state.json, including PowerShell versions that parse dates.
$record = $record | ConvertTo-Json | ConvertFrom-Json
if ((Get-Owned $record).Id -ne $PID) { throw 'Owned process not recognized' }
$checks++
$record.Started = [datetime]::UtcNow.AddDays(-1).ToString('o')
$rejected = $false
try { [void](Get-Owned $record) } catch { $rejected = $true }
if (!$rejected) { throw 'Reused PID was accepted' }
$checks++
if ($null -ne (Get-Owned $null)) { throw 'Null process not accepted' }
$checks++
$root = Join-Path ([IO.Path]::GetTempPath()) ('notaris-petugas-launcher-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root | Out-Null
for ($i = 0; $i -lt 20; $i++) {
    Save-State @{ Revision = $i } $root
    if ((Read-State $root).Revision -ne $i) { throw 'State replacement failed' }
}
$checks++
Write-Output "PASS: $checks parser/ownership/root checks; no processes stopped."
