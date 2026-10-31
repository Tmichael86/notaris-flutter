Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Assert-TestRoot([string]$Root) {
    $full = [IO.Path]::GetFullPath($Root).TrimEnd('\')
    $temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if (!$full.StartsWith($temp, [StringComparison]::OrdinalIgnoreCase) -or (Split-Path $full -Leaf) -notmatch '^notaris-petugas-launcher-[a-f0-9]{32}$') { throw 'Invalid launcher session root' }
    return $full
}
function Read-LauncherText([string]$Path, [int]$Attempts = 60) {
    for ($attempt = 0; $attempt -lt $Attempts; $attempt++) {
        $stream = $null; $reader = $null
        try {
            # Allow Windows atomic replacement while an old snapshot is being read.
            $share = [IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete
            $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, $share)
            $reader = [IO.StreamReader]::new($stream)
            return $reader.ReadToEnd()
        } catch [IO.IOException] {
            if ($attempt -eq $Attempts - 1) { throw "Cannot read launcher JSON after $Attempts attempts: $Path. Close the locking program or retry; no state was deleted." }
        } finally {
            if ($reader) { $reader.Dispose() } elseif ($stream) { $stream.Dispose() }
        }
        Start-Sleep -Milliseconds 50
    }
}
function Read-LauncherJson([string]$Path, [int]$Attempts = 60) {
    Read-LauncherText $Path $Attempts | ConvertFrom-Json
}
function Write-LauncherJson($Value, [string]$Path) {
    $temporary = "$Path.$([guid]::NewGuid().ToString('N')).tmp"
    try {
        [IO.File]::WriteAllText($temporary, ($Value | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))
        for ($attempt = 0; $attempt -lt 60; $attempt++) {
            try {
                if ([IO.File]::Exists($Path)) { [IO.File]::Replace($temporary, $Path, [NullString]::Value) }
                else { [IO.File]::Move($temporary, $Path) }
                return
            } catch [IO.IOException] {
                if ($attempt -eq 59) { throw "Cannot replace launcher JSON (locked): $Path. Previous state retained." }
            }
            Start-Sleep -Milliseconds 50
        }
    } finally {
        if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) }
    }
}
function Read-State([string]$Root) { Read-LauncherJson (Join-Path (Assert-TestRoot $Root) 'state.json') }
function Save-State($State,[string]$Root) { Write-LauncherJson $State (Join-Path (Assert-TestRoot $Root) 'state.json') }
function Enter-LauncherLock {
    # All checkouts share port 55439. Serialize START/STOP/Flutter attachment.
    $mutex = [Threading.Mutex]::new($false, 'Local\NotarisPetugasManual55439')
    try {
        try { $acquired = $mutex.WaitOne(120000) } catch [Threading.AbandonedMutexException] { $acquired = $true }
        if (!$acquired) { throw 'Another START/STOP is still running; retry shortly.' }
        return $mutex
    } catch { $mutex.Dispose(); throw }
}
function Enter-StateLock([string]$Root) {
    $name = 'Local\' + (Split-Path (Assert-TestRoot $Root) -Leaf)
    $mutex = [Threading.Mutex]::new($false, $name)
    try {
        try { $acquired = $mutex.WaitOne(10000) } catch [Threading.AbandonedMutexException] { $acquired = $true }
        if (!$acquired) { throw 'Session state update is busy; retry shortly.' }
        return $mutex
    } catch { $mutex.Dispose(); throw }
}
function Get-SessionPointer([string]$Repo) {
    $path = Join-Path ([IO.Path]::GetTempPath()) 'notaris-petugas-launcher-last.json'
    if (!(Test-Path -LiteralPath $path)) { return $null }
    $pointer = Read-LauncherJson $path
    if ($pointer.Repo -ne $Repo) { throw 'Last session belongs to another checkout; stop it from that checkout first.' }
    [void](Assert-TestRoot $pointer.Root)
    return $pointer
}
function Test-SessionHealthy($State, [string]$Root) {
    if ($State.Phase -ne 'Running' -or !$State.ClusterStarted -or !(Get-Owned $State.Supervisor) -or !(Get-Owned $State.Go)) { return $false }
    if (!$State.SessionFile -or !(Test-Path -LiteralPath $State.SessionFile)) { return $false }
    if (Test-Path -LiteralPath (Join-Path $Root 'stop.request')) { return $false }
    if (!(Test-Path -LiteralPath (Join-Path $Root 'data/postmaster.pid'))) { return $false }
    Assert-OwnedCluster $State $Root
    & (Join-Path $State.PgBin 'psql.exe') -h 127.0.0.1 -p 55439 -U notaris_test -d postgres -Atc 'SELECT 1' *> $null
    return $LASTEXITCODE -eq 0
}
function Assert-OwnedCluster($State, [string]$Root) {
    $data = Join-Path (Assert-TestRoot $Root) 'data'
    $pidFile = Join-Path $data 'postmaster.pid'
    if (!(Test-Path -LiteralPath $pidFile)) { return }
    $lines = [IO.File]::ReadAllLines($pidFile)
    if ($lines.Count -lt 4 -or [IO.Path]::GetFullPath($lines[1]).TrimEnd('\') -ne [IO.Path]::GetFullPath($data).TrimEnd('\') -or $lines[3] -ne '55439') { throw 'Cluster ownership/port mismatch; refusing recovery.' }
    $process = Get-Process -Id ([int]$lines[0]) -ErrorAction SilentlyContinue
    if ($process) {
        $expected = Join-Path $State.PgBin 'postgres.exe'
        if ($process.Path -ne $expected -or [Math]::Abs(($process.StartTime.ToUniversalTime() - [DateTimeOffset]::FromUnixTimeSeconds([long]$lines[2]).UtcDateTime).TotalSeconds) -gt 10) { throw 'Cluster PID ownership mismatch; refusing recovery.' }
    }
}
function Start-Owned([string]$Script,[hashtable]$Parameters,[string]$Log,[switch]$Foreground,[ref]$ProcessHandle) {
    $code = '& ' + "'" + $Script.Replace("'","''") + "'"
    foreach ($key in $Parameters.Keys) {
        if ($Parameters[$key] -is [bool]) { $code += ' -' + $key + ':$' + ([string]$Parameters[$key]).ToLowerInvariant() }
        else { $code += ' -' + $key + " '" + ([string]$Parameters[$key]).Replace("'","''") + "'" }
    }
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($code))
    $exe = (Get-Process -Id $PID).Path
    if ($Foreground) {
        $process = Start-Process -FilePath $exe -ArgumentList @('-NoProfile','-EncodedCommand',$encoded) -NoNewWindow -PassThru
    } else {
        $process = Start-Process -FilePath $exe -ArgumentList @('-NoProfile','-EncodedCommand',$encoded) -WindowStyle Hidden -RedirectStandardOutput $Log -RedirectStandardError "$Log.err" -PassThru
    }
    if ($ProcessHandle) { $ProcessHandle.Value = $process }
    return @{ Id=$process.Id; Started=$process.StartTime.ToUniversalTime().ToString('o') }
}
function Get-Owned($Record) {
    if ($null -eq $Record) { return $null }
    $process = Get-Process -Id $Record.Id -ErrorAction SilentlyContinue
    if ($null -eq $process) { return $null }
    if ($process.StartTime.ToUniversalTime().Ticks -ne ([datetime]$Record.Started).ToUniversalTime().Ticks) { throw 'PID reused; refusing to stop unrelated process' }
    return $process
}
function Stop-Owned($Record) {
    $process = Get-Owned $Record
    if ($null -eq $process) { return }
    # Only descendants of the verified launcher process may receive WM_CLOSE.
    $all = @(Get-CimInstance Win32_Process)
    $ids = [Collections.Generic.HashSet[int]]::new(); [void]$ids.Add($process.Id)
    do { $added=$false; foreach($child in $all) { if($ids.Contains([int]$child.ParentProcessId) -and $ids.Add([int]$child.ProcessId)) { $added=$true } } } while($added)
    foreach($idValue in $ids) { $child=Get-Process -Id $idValue -ErrorAction SilentlyContinue; if($null -ne $child -and $child.MainWindowHandle -ne 0) { [void]$child.CloseMainWindow() } }
    try { Wait-Process -Id $process.Id -Timeout 8 -ErrorAction Stop } catch {
        if ($null -ne (Get-Owned $Record)) { & taskkill.exe /PID $process.Id /T /F | Out-Null }
    }
}
function Stop-Session($State,[string]$Root) {
    $rootFull=Assert-TestRoot $Root
    $stateLock = Enter-StateLock $rootFull
    try {
        $State = Read-State $rootFull
        if ($State.ClusterStarted) { Assert-OwnedCluster $State $rootFull }
        # Prevent a new Flutter attachment racing session expiry/cleanup.
        $State.Phase = 'Stopping'
        Save-State $State $rootFull
    } finally { $stateLock.ReleaseMutex(); $stateLock.Dispose() }
    Stop-Owned $State.Flutter
    # Go watches this file and returns through testing.T cleanup / DB close.
    New-Item -ItemType File -Path (Join-Path $rootFull 'harness.stop') -Force | Out-Null
    $go=Get-Owned $State.Go
    if($null -ne $go) { try { Wait-Process -Id $go.Id -Timeout 20 -ErrorAction Stop } catch { Stop-Owned $State.Go } }
    if($State.ClusterStarted) {
        $data=Join-Path $rootFull 'data'
        & (Join-Path $State.PgBin 'pg_ctl.exe') -D $data status >> (Join-Path $rootFull 'postgres-control.log') 2>&1
        if($LASTEXITCODE -eq 0) {
            & (Join-Path $State.PgBin 'pg_ctl.exe') -D $data -m fast -w stop >> (Join-Path $rootFull 'postgres-control.log') 2>&1
            if($LASTEXITCODE -ne 0) { throw 'Unable to stop owned test cluster; inspect postgres-control.log' }
        } elseif($LASTEXITCODE -ne 3) { throw 'Unable to verify owned test cluster status' }
        $State.ClusterStarted=$false
    }
    $State.Phase='Stopped'; Save-State $State $rootFull
}
