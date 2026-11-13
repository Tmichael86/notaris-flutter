param([string]$PostgresBin,[switch]$BackendOnly,[switch]$Supervisor,[string]$SessionRoot)
. "$PSScriptRoot/petugas-manual-common.ps1"
$repo=Split-Path $PSScriptRoot -Parent
if(!(Test-Path -LiteralPath (Join-Path $repo 'backend-notaris-go/routes/petugas_flutter_e2e_test.go')) -or !(Test-Path -LiteralPath (Join-Path $repo 'frontend_notaris/lib/petugas_manual_main.dart'))) { throw 'Launcher must belong to the Notaris repository' }
if(!$PostgresBin) {
    $candidates=@('D:\Program Files\PostgreSQL\bin','C:\Program Files\PostgreSQL\18\bin')
    $pg=Get-Command pg_ctl.exe -ErrorAction SilentlyContinue
    if($pg) { $candidates=@((Split-Path $pg.Source -Parent))+$candidates }
    $PostgresBin=$candidates | Where-Object { (Test-Path -LiteralPath (Join-Path $_ 'initdb.exe')) -and (Test-Path -LiteralPath (Join-Path $_ 'pg_ctl.exe')) -and (Test-Path -LiteralPath (Join-Path $_ 'psql.exe')) } | Select-Object -First 1
}
if(!$PostgresBin) { throw 'PostgreSQL binaries missing. Pass -PostgresBin with initdb.exe, pg_ctl.exe, psql.exe.' }
$PostgresBin=(Resolve-Path -LiteralPath $PostgresBin).Path
foreach($binary in @('initdb.exe','pg_ctl.exe','psql.exe')) {
    if(!(Test-Path -LiteralPath (Join-Path $PostgresBin $binary))) { throw "Missing PostgreSQL binary: $binary" }
}
if(!$Supervisor) {
    $lifecycle = Enter-LauncherLock
    try {
    foreach($tool in @('go','flutter')) { if(!(Get-Command $tool -ErrorAction SilentlyContinue)) { throw "$tool missing from PATH" } }
    $pointer = Get-SessionPointer $repo
    if ($pointer) {
        $stateLock = Enter-StateLock $pointer.Root
        try {
        $old = Read-State $pointer.Root
        if ($old.Repo -ne $repo) { throw 'Session repository mismatch' }
        if (Test-SessionHealthy $old $pointer.Root) {
            if (!$BackendOnly -and !(Get-Owned $old.Flutter)) {
                $old.Flutter = Start-Owned (Join-Path $PSScriptRoot 'petugas-manual-process.ps1') @{Role='Flutter';SessionRoot=$pointer.Root;RepoRoot=$repo} (Join-Path $pointer.Root 'flutter.log')
                Save-State $old $pointer.Root
            }
            Write-Output "Reusing healthy session: $($pointer.Root)"
            $global:LASTEXITCODE = 0
            return
        }
        } finally { $stateLock.ReleaseMutex(); $stateLock.Dispose() }
        # STOP verifies recorded process creation times and cluster data/PID/port.
        & (Join-Path $PSScriptRoot 'stop-petugas-manual-test.ps1') -SessionRoot $pointer.Root
    }
    # Bind probe rejects another service on the fixed testing port.
    $probe=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,55439)
    try { $probe.Start() } catch { throw 'Port 55439 is occupied. Stop the previous test session; no existing service was touched.' } finally { $probe.Stop() }
    $SessionRoot=Join-Path ([IO.Path]::GetTempPath()) ('notaris-petugas-launcher-'+[guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $SessionRoot | Out-Null
    $state=@{ Phase='Starting'; Repo=$repo; PgBin=$PostgresBin; ClusterStarted=$false; Go=$null; Flutter=$null; Supervisor=$null; SessionFile=$null; BackendOnly=[bool]$BackendOnly; Error=$null }
    Save-State $state $SessionRoot
    # Switch parameters cannot receive strings through an encoded invocation.
    $entry="& '"+$PSCommandPath.Replace("'","''")+"' -Supervisor -SessionRoot '"+$SessionRoot.Replace("'","''")+"' -PostgresBin '"+$PostgresBin.Replace("'","''")+"'"
    if($BackendOnly) { $entry+=' -BackendOnly' }
    $encoded=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($entry))
    $super=Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList @('-NoProfile','-EncodedCommand',$encoded) -WindowStyle Hidden -RedirectStandardOutput (Join-Path $SessionRoot 'supervisor.log') -RedirectStandardError (Join-Path $SessionRoot 'supervisor.err') -PassThru
    Write-LauncherJson @{Root=$SessionRoot;Repo=$repo} (Join-Path ([IO.Path]::GetTempPath()) 'notaris-petugas-launcher-last.json')
    Write-Output "Session: $SessionRoot"
    $deadline=[DateTime]::UtcNow.AddMinutes(4)
    while([DateTime]::UtcNow -lt $deadline) {
        $s=Read-State $SessionRoot
        if($s.Phase -eq 'Running') { Write-Output "Ready. Logs: $SessionRoot | Stop: .\scripts\stop-petugas-manual-test.ps1"; $global:LASTEXITCODE=0; return }
        if($s.Phase -in @('Failed','Stopped')) { throw "Startup stopped: $($s.Error). Logs: $SessionRoot" }
        if($super.HasExited) { throw "Supervisor exited. Logs: $SessionRoot" }
        Start-Sleep -Milliseconds 500
    }
    New-Item -ItemType File -Path (Join-Path $SessionRoot 'stop.request') -Force | Out-Null
    throw "Startup timeout; stop requested. Logs: $SessionRoot"
    } finally { $lifecycle.ReleaseMutex(); $lifecycle.Dispose() }
}
$SessionRoot=Assert-TestRoot $SessionRoot
$state=Read-State $SessionRoot
$state.Supervisor=@{Id=$PID;Started=(Get-Process -Id $PID).StartTime.ToUniversalTime().ToString('o')}; Save-State $state $SessionRoot
try {
    & (Join-Path $PostgresBin 'initdb.exe') -D (Join-Path $SessionRoot 'data') -U notaris_test --auth=trust --encoding=UTF8 --no-locale >> (Join-Path $SessionRoot 'postgres-control.log') 2>&1
    if($LASTEXITCODE -ne 0) { throw 'initdb failed' }
    # Record ownership before spawning, so startup timeout/failure also cleans up.
    $state.ClusterStarted=$true; Save-State $state $SessionRoot
    # Do not pipe pg_ctl output through PowerShell or use Start-Process -Wait:
    # inherited handles / descendant waiting can wait for PostgreSQL's lifetime.
    $ctl=Start-Process -FilePath (Join-Path $PostgresBin 'pg_ctl.exe') -ArgumentList @('-D',('"'+(Join-Path $SessionRoot 'data')+'"'),'-l',('"'+(Join-Path $SessionRoot 'postgres.log')+'"'),'-o','"-h 127.0.0.1 -p 55439"','-w','start') -WindowStyle Hidden -RedirectStandardOutput (Join-Path $SessionRoot 'pg-start.log') -RedirectStandardError (Join-Path $SessionRoot 'pg-start.err') -PassThru
    if(!$ctl.WaitForExit(45000) -or $ctl.ExitCode -ne 0) { throw 'pg_ctl start failed (port conflict or permissions)' }
    $state.ClusterStarted=$true; Save-State $state $SessionRoot
    & (Join-Path $PostgresBin 'psql.exe') -h 127.0.0.1 -p 55439 -U notaris_test -d postgres -Atc 'SELECT 1' >> (Join-Path $SessionRoot 'postgres-control.log') 2>&1
    if($LASTEXITCODE -ne 0) { throw 'PostgreSQL readiness failed' }
    $state.Go=Start-Owned (Join-Path $PSScriptRoot 'petugas-manual-process.ps1') @{Role='Go';SessionRoot=$SessionRoot;RepoRoot=$repo} (Join-Path $SessionRoot 'go.log'); Save-State $state $SessionRoot
    $deadline=[DateTime]::UtcNow.AddMinutes(2)
    while([DateTime]::UtcNow -lt $deadline) {
        if(Test-Path -LiteralPath (Join-Path $SessionRoot 'stop.request')) { throw 'Stop requested' }
        if($null -eq (Get-Owned $state.Go)) { throw 'Go harness exited before readiness' }
        $log=Join-Path $SessionRoot 'go.log'
        if(Test-Path -LiteralPath $log) {
            $match=Select-String -LiteralPath $log -Pattern 'MANUAL_SESSION_FILE=(.+?) \(contains' | Select-Object -First 1
            if($match) { $candidate=$match.Matches[0].Groups[1].Value; if(Test-Path -LiteralPath $candidate) { $state.SessionFile=$candidate; break } }
        }
        Start-Sleep -Milliseconds 250
    }
    if(!$state.SessionFile) { throw 'No harness session file received' }
    Save-State $state $SessionRoot
    if(!$BackendOnly) { $state.Flutter=Start-Owned (Join-Path $PSScriptRoot 'petugas-manual-process.ps1') @{Role='Flutter';SessionRoot=$SessionRoot;RepoRoot=$repo} (Join-Path $SessionRoot 'flutter.log') }
    $state.Phase='Running'; Save-State $state $SessionRoot
    while(!(Test-Path -LiteralPath (Join-Path $SessionRoot 'stop.request'))) {
        $state=Read-State $SessionRoot
        if($null -eq (Get-Owned $state.Go)) { throw 'Go harness ended (session expired or failure)' }
        # Flutter may close/reopen independently in the two-terminal workflow.
        Start-Sleep -Milliseconds 500
    }
} catch {
    $errorMessage = $_.Exception.Message
    $stateLock = Enter-StateLock $SessionRoot
    try { $state=Read-State $SessionRoot; $state.Error=$errorMessage; $state.Phase='Failed'; Save-State $state $SessionRoot }
    finally { $stateLock.ReleaseMutex(); $stateLock.Dispose() }
}
finally {
    $failure=$state.Error
    $state=Read-State $SessionRoot
    try { Stop-Session $state $SessionRoot } catch { $failure="Cleanup failed: $($_.Exception.Message)" }
    if($failure) { $state.Error=$failure; $state.Phase='Failed'; Save-State $state $SessionRoot }
}
