# Opt-in live test: creates only the dedicated loopback testing cluster.
param([switch]$KeepRunning)
. "$PSScriptRoot/petugas-manual-common.ps1"
$repo = Split-Path $PSScriptRoot -Parent
$root = Join-Path ([IO.Path]::GetTempPath()) ('notaris-petugas-launcher-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root | Out-Null
function Run-Pair([string]$Script, [hashtable]$Parameters) {
    $children = @()
    try {
        foreach ($number in 1..2) {
            $code = "& '" + $Script.Replace("'", "''") + "'"
            foreach ($key in $Parameters.Keys) {
                if ($Parameters[$key] -is [bool]) { $code += ' -' + $key + ':$' + ([string]$Parameters[$key]).ToLowerInvariant() }
                else { $code += ' -' + $key + " '" + ([string]$Parameters[$key]).Replace("'", "''") + "'" }
            }
            $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($code))
            $log = Join-Path $root "pair-$([IO.Path]::GetFileNameWithoutExtension($Script))-$number.log"
            # Keep the actual process handle to collect exit codes even on fast exits.
            $child = Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList @('-NoProfile','-EncodedCommand',$encoded) -WindowStyle Hidden -RedirectStandardOutput $log -RedirectStandardError "$log.err" -PassThru
            $children += @{Process=$child; Record=@{Id=$child.Id;Started=$child.StartTime.ToUniversalTime().ToString('o')}}
        }
        foreach ($entry in $children) {
            $child = $entry.Process
            if (!$child.WaitForExit(120000)) { throw 'Concurrent lifecycle timeout' }
            if ($child.ExitCode -ne 0) { throw "Concurrent command failed (exit $($child.ExitCode)); logs: $root" }
        }
    } finally { foreach ($entry in $children) { Stop-Owned $entry.Record; $entry.Process.Dispose() } }
}
Run-Pair "$PSScriptRoot/run-petugas-test-backend.ps1" @{ReadyOnly=$true}
$pointer = Get-SessionPointer $repo
$state = Read-State $pointer.Root
if (!(Test-SessionHealthy $state $pointer.Root)) { throw 'Session is not healthy' }
foreach ($number in 1..2) {
    $text = Read-LauncherText (Join-Path $root "pair-run-petugas-test-backend-$number.log")
    if (!$text.Contains($pointer.Root)) { throw 'Concurrent START did not reuse the same session' }
}
Write-Output 'PASS: concurrent START reused one healthy session.'
if (!$KeepRunning) {
    Run-Pair "$PSScriptRoot/stop-petugas-manual-test.ps1" @{SessionRoot=$pointer.Root}
    & "$PSScriptRoot/stop-petugas-manual-test.ps1" -SessionRoot $pointer.Root
    if ((Read-State $pointer.Root).Phase -ne 'Stopped') { throw 'Concurrent STOP did not finish' }
    Write-Output 'PASS: concurrent STOP and repeated STOP.'
}
Write-Output "Lifecycle logs: $root"
