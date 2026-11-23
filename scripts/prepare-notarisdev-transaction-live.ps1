param([string]$Receipt='')
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent;Set-Location $repo
. ./scripts/petugas-operations-common.ps1
. ./scripts/notaris-psql-process.ps1
$s=Read-PetugasDevelopmentSettings './backend-notaris-go/.env.notarisdev'
$migration=Join-Path $repo '.local/transaction-rollout-preflight-20261105-071615/execution-20261106-025302-50be6028'
$h=Get-Content (Join-Path $migration 'history.json') -Raw|ConvertFrom-Json
$lines=Get-Content (Join-Path $migration 'apply.log')
if($h.status -cne 'verified' -or !$h.commitConfirmed -or $h.applyExitCode -ne 0 -or [array]::IndexOf($lines,'COMMIT') -lt 0 -or [array]::IndexOf($lines,'COMBINED_TRANSACTIONS_MIGRATION_COMMITTED') -le [array]::IndexOf($lines,'COMMIT')){throw 'Verified Transaction migration receipt required; never rerun migration'}
if(!$Receipt){$Receipt=Join-Path $repo ('.local/transaction-live-readiness-'+[datetime]::UtcNow.ToString('yyyyMMdd-HHmmss'))}
$Receipt=[IO.Path]::GetFullPath($Receipt)
if(!$Receipt.StartsWith((Join-Path $repo '.local')+[IO.Path]::DirectorySeparatorChar)){throw 'Owned .local receipt required'}
New-Item -ItemType Directory -Path $Receipt -ErrorAction Stop|Out-Null
$keys=@('PGHOST','PGPORT','PGDATABASE','PGUSER','PGPASSWORD','PGOPTIONS','TRANSACTION_CONTROLLED_ROOT','TRANSACTION_CONTROLLED_MODE');$old=@{};foreach($k in $keys){$old[$k]=[Environment]::GetEnvironmentVariable($k)}
try{
 $env:PGHOST='127.0.0.1';$env:PGPORT='5432';$env:PGDATABASE='notarisdev';$env:PGUSER=$s.DB_USER;$env:PGPASSWORD=$s.DB_PASSWORD;$env:PGOPTIONS='-c default_transaction_read_only=on -c statement_timeout=30000'
 $r=Invoke-NotarisPsqlFile -Executable 'D:\Program Files\PostgreSQL\bin\psql.exe' -File './scripts/sql/transaction-live-baseline.sql' -Log (Join-Path $Receipt 'baseline.log')
 if($r.ExitCode -ne 0){throw 'Read-only live baseline failed'}
 $json=Get-Content $r.Stdout|Where-Object{$_ -match '^\{'}|Select-Object -First 1;$b=$json|ConvertFrom-Json
 if($b.target.database -cne 'notarisdev' -or $b.target.host -cne '127.0.0.1/32' -or $b.target.port -ne 5432 -or $b.target.marker -cne 'NOTARISDEV SYNTHETIC v1' -or $b.target.role -cne $s.DB_USER -or $b.account.id -ne 2001 -or $b.account.group_id -ne 11 -or $b.account.status -ne 1){throw 'Target/scope mismatch'}
 foreach($key in @('transaksi','pekerjaan_notaris','pekerjaan_ppat')){$p=$b.permissions.$key;if(!$p -or $p.status -ne 1 -or $p.read -ne 1 -or $p.create -ne 1 -or $p.update -ne 1 -or $p.delete -ne 1){throw 'Fixture permission mismatch'}}
 if(!$b.pemohon.uuid -or !$b.petugas.uuid -or !$b.category.uuid -or $b.transactions.pending -ne 0 -or $b.masters.notaris.pending -ne 0 -or $b.masters.ppat.pending -ne 0){throw 'Reference or pending-event readiness mismatch'}
 $json|Set-Content (Join-Path $Receipt 'references.json')
 $env:TRANSACTION_CONTROLLED_ROOT=$Receipt;$env:TRANSACTION_CONTROLLED_MODE='prepare'
 Push-Location frontend_notaris
 try{& flutter test --no-pub tool/transaction_cloud_controlled_live_entry.dart --reporter expanded *> (Join-Path $Receipt 'prepare-flutter.log');if($LASTEXITCODE -ne 0){throw 'Offline fixture preparation failed'}}finally{Pop-Location}
 $hashes=[ordered]@{};foreach($name in @('fixture-plan.json','publication-allowlist.json','device-a.sqlite','device-b.sqlite')){$hashes[$name]=(Get-FileHash (Join-Path $Receipt $name)).Hash}
 [ordered]@{target='127.0.0.1:5432/notarisdev';head=(git rev-parse HEAD);mode='prepared_no_live_write';migrationReceipt=$migration;hashes=$hashes;createdUtc=[datetime]::UtcNow.ToString('o')}|ConvertTo-Json -Depth 5|Set-Content (Join-Path $Receipt 'prepared.json')
 Write-Output "TRANSACTION_LIVE_PREPARED_NO_WRITE: $Receipt"
}finally{foreach($k in $keys){if($null -eq $old[$k]){Remove-Item -LiteralPath "Env:$k" -ErrorAction SilentlyContinue}else{[Environment]::SetEnvironmentVariable($k,$old[$k])}}}
