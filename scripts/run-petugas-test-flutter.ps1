# Terminal 2: foreground Flutter console (hot reload/quit supported).
. "$PSScriptRoot/petugas-manual-common.ps1"
$repo = Split-Path $PSScriptRoot -Parent
$lock = Enter-LauncherLock
$record = $null
$child = $null
$stateLock = $null
try {
    $pointer = Get-SessionPointer $repo
    if (!$pointer) { throw 'Start Terminal 1 first: .\scripts\run-petugas-test-backend.ps1' }
    $stateLock = Enter-StateLock $pointer.Root
    $state = Read-State $pointer.Root
    if (!(Test-SessionHealthy $state $pointer.Root)) { throw 'Test backend not ready. Run .\scripts\run-petugas-test-backend.ps1 first.' }
    if (Get-Owned $state.Flutter) { throw 'Flutter testing is already running; use its existing window or STOP first.' }
    # Own a dedicated child, never the user's interactive PowerShell process.
    $record = Start-Owned "$PSScriptRoot/petugas-manual-process.ps1" @{Role='Flutter';SessionRoot=$pointer.Root;RepoRoot=$repo} '' -Foreground -ProcessHandle ([ref]$child)
    $state.Flutter = $record
    Save-State $state $pointer.Root
} finally {
    if ($stateLock) { $stateLock.ReleaseMutex(); $stateLock.Dispose() }
    $lock.ReleaseMutex(); $lock.Dispose()
}
try {
    if ($child) {
        $child.WaitForExit()
        if ($child.ExitCode -ne 0 -and !(Test-Path (Join-Path $pointer.Root 'stop.request'))) { throw "Flutter exited with code $($child.ExitCode)" }
    }
} finally {
    Stop-Owned $record
    $lock = Enter-LauncherLock
    $stateLock = $null
    try {
        $stateLock = Enter-StateLock $pointer.Root
        $state = Read-State $pointer.Root
        if ($state.Phase -eq 'Running' -and $state.Flutter -and $state.Flutter.Id -eq $record.Id) {
            $state.Flutter = $null
            Save-State $state $pointer.Root
        }
    } finally {
        if ($stateLock) { $stateLock.ReleaseMutex(); $stateLock.Dispose() }
        $lock.ReleaseMutex(); $lock.Dispose()
    }
    if ($child) { $child.Dispose() }
}
$global:LASTEXITCODE = 0
