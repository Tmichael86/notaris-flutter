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
# Reproduce the old Get-Content sharing violation with an exclusive file handle.
$path = Join-Path $root 'state.json'
$exclusive = [IO.File]::Open($path, 'Open', 'ReadWrite', 'None')
try {
    $failed = $false
    try { Get-Content -LiteralPath $path -Raw -ErrorAction Stop | Out-Null } catch { $failed = $true }
    if (!$failed) { throw 'Exclusive-lock reproduction did not fail as expected' }
    $clock = [Diagnostics.Stopwatch]::StartNew()
    $failed = $false
    try { Read-LauncherJson $path -Attempts 3 | Out-Null } catch { $failed = $true }
    if (!$failed -or $clock.Elapsed.TotalSeconds -gt 5) { throw 'Read retry was not bounded' }
} finally { $exclusive.Dispose() }
$checks++
# A different process holds a transient lock; the reader must eventually recover.
$signal = Join-Path $root 'locked.signal'
$job = Start-Job -ArgumentList $path,$signal -ScriptBlock {
    param($path,$signal)
    $handle = [IO.File]::Open($path, 'Open', 'ReadWrite', 'None')
    try { [IO.File]::WriteAllText($signal, 'locked'); Start-Sleep -Milliseconds 500 }
    finally { $handle.Dispose() }
}
try {
    $deadline = [datetime]::UtcNow.AddSeconds(20)
    while (!(Test-Path $signal)) {
        if ([datetime]::UtcNow -gt $deadline) { throw 'Lock fixture timeout' }
        Start-Sleep -Milliseconds 10
    }
    if ((Read-State $root).Revision -ne 19) { throw 'Transient lock recovery failed' }
    $job | Wait-Job -Timeout 10 | Receive-Job -ErrorAction Stop
} finally { $job | Remove-Job -Force }
$checks++
# Replacement must not invalidate a reader holding the previous snapshot.
$reader = [IO.File]::Open($path, 'Open', 'Read', ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
try { Save-State @{Revision=20} $root; if ((Read-State $root).Revision -ne 20) { throw 'Atomic replacement failed' } }
finally { $reader.Dispose() }
$checks++
# The writer must also tolerate an external exclusive lock without losing state.
$signal = Join-Path $root 'writer-locked.signal'
$job = Start-Job -ArgumentList $path,$signal -ScriptBlock {
    param($path,$signal)
    $handle = [IO.File]::Open($path, 'Open', 'ReadWrite', 'None')
    try { [IO.File]::WriteAllText($signal, 'locked'); Start-Sleep -Milliseconds 500 }
    finally { $handle.Dispose() }
}
try {
    $deadline = [datetime]::UtcNow.AddSeconds(20)
    while (!(Test-Path $signal)) {
        if ([datetime]::UtcNow -gt $deadline) { throw 'Writer lock fixture timeout' }
        Start-Sleep -Milliseconds 10
    }
    Save-State @{Revision=21} $root
    if ((Read-State $root).Revision -ne 21) { throw 'Writer lock recovery failed' }
    $job | Wait-Job -Timeout 10 | Receive-Job -ErrorAction Stop
} finally { $job | Remove-Job -Force }
$checks++
Write-Output "PASS: $checks parser/ownership/root checks; no processes stopped."
