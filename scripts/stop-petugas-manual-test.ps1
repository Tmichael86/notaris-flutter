param([string]$SessionRoot)
. "$PSScriptRoot/petugas-manual-common.ps1"
if(!$SessionRoot) {
    $pointer=Get-Content -LiteralPath (Join-Path ([IO.Path]::GetTempPath()) 'notaris-petugas-launcher-last.json') -Raw | ConvertFrom-Json
    if($pointer.Repo -ne (Split-Path $PSScriptRoot -Parent)) { throw 'Last session belongs to another checkout; specify -SessionRoot' }
    $SessionRoot=$pointer.Root
}
$SessionRoot=Assert-TestRoot $SessionRoot
$state=Read-State $SessionRoot
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
