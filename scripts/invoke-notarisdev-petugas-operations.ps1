# Explicit development maintenance. Default is authenticated read-only inspection.
param(
 [Parameter(Mandatory)][string]$GrantsReceiptDirectory,
 [switch]$Apply,[string]$ConfirmTarget,[switch]$MaintenanceConfirmed,
 [ValidateSet('bootstrap','drain','bootstrap-and-drain')][string]$Operation='bootstrap-and-drain',
 [ValidateRange(1,500)][int]$BatchSize=100,[ValidateRange(1,100)][int]$MaxBatches=10,
 [ValidateRange(1,300)][int]$TimeoutSeconds=60,[switch]$RequirePublishedBaseline
)
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'petugas-operations-common.ps1')
Assert-PetugasOperationsRequest ([bool]$Apply) $ConfirmTarget ([bool]$MaintenanceConfirmed) ([bool]$RequirePublishedBaseline)
$settings=Read-PetugasDevelopmentSettings (Join-Path $repo 'backend-notaris-go/.env.notarisdev')
$GrantsReceiptDirectory=(Resolve-Path -LiteralPath $GrantsReceiptDirectory).Path
$baseline=Get-PetugasOperationsBaseline $GrantsReceiptDirectory $repo $settings.DB_USER
$probe=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,8081)
try{$probe.Start()}catch{throw 'Maintenance required: development backend port 8081 is occupied'}finally{$probe.Stop()}
$root=Join-Path $repo ('.local/petugas-operations-'+[datetime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $root|Out-Null
$baselineFile=Join-Path $root 'baseline.json'
[IO.File]::WriteAllText($baselineFile,($baseline|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
$history=[ordered]@{target='127.0.0.1:5432/notarisdev';mode='dry_run';operation=$Operation;status='started';startedUtc=[datetime]::UtcNow.ToString('o');grantsReceipt=$GrantsReceiptDirectory;grantsReceiptSha256=(Get-FileHash (Join-Path $GrantsReceiptDirectory 'history.json')).Hash;baselineSha256=(Get-FileHash $baselineFile).Hash;runnerSha256=(Get-FileHash $PSCommandPath).Hash;batchSize=$BatchSize;maxBatches=$MaxBatches;timeoutSeconds=$TimeoutSeconds;requirePublishedBaseline=[bool]$RequirePublishedBaseline}
if($Apply){$history.mode='apply'}
function Save-OperationsHistory {$history|ConvertTo-Json -Depth 5|Set-Content (Join-Path $root 'history.json')}
$previous=@{};$location=Get-Location
try {
 $history.helperSha256=(Get-FileHash (Join-Path $PSScriptRoot 'petugas-operations-common.ps1')).Hash
 Save-OperationsHistory
 # Set only reviewed DB variables; do not copy unrelated private configuration.
 foreach($key in @('DB_HOST','DB_PORT','DB_NAME','DB_USER','DB_PASSWORD','PETUGAS_PUBLISHER_ENABLED')){$previous[$key]=[Environment]::GetEnvironmentVariable($key);[Environment]::SetEnvironmentVariable($key,$settings[$key])}
 Set-Location (Join-Path $repo 'backend-notaris-go')
 $binary=Join-Path $root 'petugasops.exe'
 $go=(Get-Command go -ErrorAction Stop).Source
 $buildExit=Invoke-PetugasBoundedProcess $go @('build','-o',$binary,'./cmd/petugasops') (Join-Path $root 'build.log') 120
 if($buildExit -ne 0){throw "Build failed; inspect $root/build.log.stderr"}
 $history.binarySha256=(Get-FileHash $binary).Hash;Save-OperationsHistory
 $arguments=@('--baseline',$baselineFile,'--operation',$Operation,'--batch-size',"$BatchSize",'--max-batches',"$MaxBatches",'--timeout',($TimeoutSeconds.ToString()+'s'))
 if($Apply){$arguments+=@('--apply','--confirm-target',$ConfirmTarget,'--maintenance-confirmed')}
 if($RequirePublishedBaseline){$arguments+='--require-published-baseline'}
 $exitCode=Invoke-PetugasBoundedProcess $binary $arguments (Join-Path $root 'operations.jsonl') ($TimeoutSeconds+15)
 $history.exitCode=$exitCode
 $events=@(Get-Content (Join-Path $root 'operations.jsonl')|ConvertFrom-Json)
 $expected=if($Apply){'complete'}else{'dry_run_verified'}
 if($exitCode -ne 0 -or !$events.Count -or $events[-1].stage -cne $expected){throw "Operation stopped; inspect $root. Prior commits may persist; no automatic retry/reset/restore"}
 $history.status=if($Apply){'applied_and_verified'}else{'verified_readonly'}
 $history.finalState=$events[-1].state;$history.finishedUtc=[datetime]::UtcNow.ToString('o');Save-OperationsHistory
 Write-Output "PETUGAS_OPERATIONS_$($history.status.ToUpperInvariant()): $root"
 Write-Output ($events[-1]|ConvertTo-Json -Compress -Depth 4)
} catch {
 $history.status='failed_requires_inspection';$history.finishedUtc=[datetime]::UtcNow.ToString('o');Save-OperationsHistory;throw
} finally {
 Set-Location $location
 foreach($key in $previous.Keys){if($null -eq $previous[$key]){Remove-Item -LiteralPath "Env:$key" -ErrorAction SilentlyContinue}else{[Environment]::SetEnvironmentVariable($key,$previous[$key])}}
}
