Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Assert-TestRoot([string]$Root) {
    $full = [IO.Path]::GetFullPath($Root).TrimEnd('\')
    $temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if (!$full.StartsWith($temp, [StringComparison]::OrdinalIgnoreCase) -or (Split-Path $full -Leaf) -notmatch '^notaris-petugas-launcher-[a-f0-9]{32}$') { throw 'Invalid launcher session root' }
    return $full
}
function Read-State([string]$Root) { Get-Content -LiteralPath (Join-Path (Assert-TestRoot $Root) 'state.json') -Raw | ConvertFrom-Json }
function Save-State($State,[string]$Root) {
    $target = Join-Path (Assert-TestRoot $Root) 'state.json'
    $State | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath "$target.new" -Encoding UTF8
    if ([IO.File]::Exists($target)) {
        [IO.File]::Replace("$target.new", $target, [NullString]::Value)
    } else {
        [IO.File]::Move("$target.new", $target)
    }
}
function Start-Owned([string]$Script,[hashtable]$Parameters,[string]$Log) {
    $code = '& ' + "'" + $Script.Replace("'","''") + "'"
    foreach ($key in $Parameters.Keys) { $code += ' -' + $key + " '" + ([string]$Parameters[$key]).Replace("'","''") + "'" }
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($code))
    $exe = (Get-Process -Id $PID).Path
    $process = Start-Process -FilePath $exe -ArgumentList @('-NoProfile','-EncodedCommand',$encoded) -WindowStyle Hidden -RedirectStandardOutput $Log -RedirectStandardError "$Log.err" -PassThru
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
