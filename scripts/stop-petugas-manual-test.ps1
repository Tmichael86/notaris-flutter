param([string]$SessionRoot)
. "$PSScriptRoot/petugas-manual-common.ps1"
$global:LASTEXITCODE=0
$lifecycle=Enter-LauncherLock
try {
if(!$SessionRoot) {
    $pointer=Get-SessionPointer (Split-Path $PSScriptRoot -Parent)
    if (!$pointer) { Write-Output 'No testing session to stop.'; return }
    $SessionRoot=$pointer.Root
}
$SessionRoot=Assert-TestRoot $SessionRoot
$state=Read-State $SessionRoot
if ($state.Repo -ne (Split-Path $PSScriptRoot -Parent)) { throw 'Session belongs to another checkout' }
if($state.Phase -eq 'Stopped') { Write-Output 'Already stopped; data/logs retained.'; return }
New-Item -ItemType File -Path (Join-Path $SessionRoot 'stop.request') -Force | Out-Null
$deadline=[DateTime]::UtcNow.AddSeconds(45)
while([DateTime]::UtcNow -lt $deadline) {
    $state=Read-State $SessionRoot
    if($state.Phase -eq 'Stopped') { Write-Output "Stopped owned testing processes. Data/logs retained: $SessionRoot"; return }
    if($null -eq (Get-Owned $state.Supervisor)) { Stop-Session $state $SessionRoot; Write-Output 'Supervisor unavailable; verified owned processes stopped.'; return }
    Start-Sleep -Milliseconds 250
}
throw "Stop timeout. Inspect logs and state in $SessionRoot; no unrelated process was targeted."
} finally { $lifecycle.ReleaseMutex(); $lifecycle.Dispose() }
