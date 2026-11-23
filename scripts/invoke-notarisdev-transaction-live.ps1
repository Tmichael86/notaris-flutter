param([Parameter(Mandatory)][string]$PreparedReceipt,[switch]$Apply,[string]$ConfirmTarget='',[string]$ConfirmPlanSha256='')
$ErrorActionPreference='Stop';$repo=Split-Path $PSScriptRoot -Parent;Set-Location $repo
. ./scripts/petugas-operations-common.ps1
. ./scripts/notaris-psql-process.ps1
$root=(Resolve-Path -LiteralPath $PreparedReceipt).Path
if(!$root.StartsWith((Join-Path $repo '.local')+[IO.Path]::DirectorySeparatorChar)){throw 'Owned prepared devices required'}
$meta=Get-Content (Join-Path $root 'prepared.json') -Raw|ConvertFrom-Json;$plan=Get-Content (Join-Path $root 'fixture-plan.json') -Raw|ConvertFrom-Json
$live=$plan.target -ceq '127.0.0.1:5432/notarisdev'
if(!$live -and $plan.target -cnotmatch '^127\.0\.0\.1:55[4-9][0-9]{2}/notaris_publish_test[a-z0-9_]+$'){throw 'Only reviewed development or owned disposable target allowed'}
if($Apply -and ($ConfirmTarget -cne $plan.target -or $ConfirmPlanSha256 -cne $meta.hashes.'fixture-plan.json')){throw 'Apply requires separately approved exact target and plan SHA-256'}
$lock=Join-Path $root 'live-attempted.lock';if(Test-Path $lock){throw 'Prior live attempt exists; inspect read-only, no retry'}
foreach($name in @('fixture-plan.json','publication-allowlist.json','device-a.sqlite','device-b.sqlite')){if((Get-FileHash (Join-Path $root $name)).Hash -cne $meta.hashes.$name){throw "Prepared file changed: $name"}}
if($Apply -and $live -and ((git rev-parse HEAD) -cne $meta.head -or @(git status --porcelain).Count -ne 0)){throw 'Reviewed source checkpoint changed'}
$s=Read-PetugasDevelopmentSettings './backend-notaris-go/.env.notarisdev';$target=$plan.target -split '[:/]';$port=$target[1];$database=$target[2];$httpPort=if($live){'8081'}else{'18081'}
if($s.DB_HOST -cne '127.0.0.1' -or "$($s.DB_PORT)" -cne '5432' -or $s.DB_NAME -cne 'notarisdev' -or $s.PETUGAS_PUBLISHER_ENABLED -cne 'false'){throw 'Reviewed development configuration changed'}
$keys=@('PGHOST','PGPORT','PGDATABASE','PGUSER','PGPASSWORD','PGOPTIONS','DB_HOST','DB_PORT','DB_NAME','DB_USER','DB_PASSWORD','DB_SSLMODE','PORT','JWT_SECRET','JWT_EXPIRE_MINUTES','PETUGAS_PUBLISHER_ENABLED','MASTER_PUBLISH_DSN','TRANSACTION_CONTROLLED_ROOT','TRANSACTION_CONTROLLED_AUTHORIZED','TRANSACTION_CONTROLLED_URL','TRANSACTION_CONTROLLED_TOKEN','TRANSACTION_PUBLISH_EXE','TRANSACTION_EXECUTE_PLAN_SHA256');$old=@{};foreach($k in $keys){$old[$k]=[Environment]::GetEnvironmentVariable($k)}
$backend=$null;$token=$null
$history=[ordered]@{target=$plan.target;status='read_only_preflight';applyAttempted=$false;prepared=$root;startedUtc=[datetime]::UtcNow.ToString('o')}
function Save-History {$history|ConvertTo-Json -Depth 5|Set-Content (Join-Path $root 'live-history.json')}
function Read-Sql([string]$name,[string]$file){$before=$env:PGOPTIONS;$env:PGOPTIONS='-c default_transaction_read_only=on -c statement_timeout=30000';try{$r=Invoke-NotarisPsqlFile -Executable 'D:\Program Files\PostgreSQL\bin\psql.exe' -File $file -Log (Join-Path $root ($name+'.log'));if($r.ExitCode -ne 0){throw "Read-only $name failed"};$rows=@(Get-Content $r.Stdout|Where-Object{$_ -match '^\{'}|ForEach-Object{$_|ConvertFrom-Json});ConvertTo-Json -InputObject $rows -Depth 12|Set-Content (Join-Path $root ($name+'.json'));return $rows}finally{$env:PGOPTIONS=$before}}
function Check-Baseline($b){
 if($b.target.database -cne $database -or $b.target.port -ne [int]$port -or $b.target.host -cne '127.0.0.1/32' -or $b.target.role -cne $s.DB_USER -or $b.target.marker -cne 'NOTARISDEV SYNTHETIC v1' -or $b.account.id -ne 2001 -or $b.account.group_id -ne 11 -or $b.account.status -ne 1){throw 'Target/fixture scope changed'}
 foreach($key in @('transaksi','pekerjaan_notaris','pekerjaan_ppat')){$p=$b.permissions.$key;if(!$p -or $p.status -ne 1 -or $p.read -ne 1 -or $p.create -ne 1 -or $p.update -ne 1 -or $p.delete -ne 1){throw 'Permission changed'}}
 foreach($domain in @('notaris','ppat')){foreach($key in @('last_seq','min_cursor','pending','receipts','events')){if($b.masters.$domain.$key -ne $plan.baseline.masters.$domain.$key){throw 'Master baseline changed'}}}
 foreach($key in @('last_seq','min_cursor','pending','receipts','events','parents','payments')){if($b.transactions.$key -ne $plan.baseline.transactions.$key){throw 'Transaction baseline changed'}}
 if($b.transactions.parents -ne 0 -or $b.transactions.receipts -ne 0 -or $b.transactions.events -ne 0 -or @($b.transactions.counters).Count -ne 0){throw 'This reviewed first slice requires observed empty Transaction baseline'}
 foreach($key in @('pemohon','petugas','category')){if($b.$key.uuid -cne $plan.baseline.$key.uuid -or $b.$key.id -ne $plan.baseline.$key.id){throw 'Reviewed reference identity changed'}}
 if($b.petugas.row_version -ne $plan.baseline.petugas.row_version){throw 'Reviewed officer revision changed'}
}
try{
 $env:PGHOST='127.0.0.1';$env:PGPORT=$port;$env:PGDATABASE=$database;$env:PGUSER=$s.DB_USER;$env:PGPASSWORD=$s.DB_PASSWORD;$env:PGOPTIONS='-c default_transaction_read_only=on'
 $baseline=Read-Sql 'live-before-baseline' './scripts/sql/transaction-live-baseline.sql';Check-Baseline $baseline
 if(!$Apply){Write-Output "TRANSACTION_LIVE_DRY_RUN_OK: $root; no HTTP mutations or publication";exit 0}
 if($baseline.other_sessions -ne 0 -or @(Get-NetTCPConnection -LocalPort $httpPort -State Listen -ErrorAction SilentlyContinue).Count -ne 0 -or @(Get-Process|Where-Object{$_.ProcessName -match '^(dbeaver|frontend_notaris|flutter_tester|backend-notaris-go|backend-notaris|notaris|go)$'}).Count -ne 0){throw 'Maintenance required before live execution'}
 & python ./scripts/build-transaction-live-preservation.py $root;if($LASTEXITCODE -ne 0){throw 'Preservation query preparation failed'}
 $preserved=@(Read-Sql 'live-before-preservation' (Join-Path $root 'preservation.sql'));if($preserved[0].approved_collisions -ne 0){throw 'Fixture UUID collision before write'}
 $backup=Join-Path $root 'before-live.dump';$code=Invoke-PetugasBoundedProcess 'D:\Program Files\PostgreSQL\bin\pg_dump.exe' @('-w','-Fc','--serializable-deferrable','--lock-wait-timeout=5s',('--file='+$backup)) (Join-Path $root 'before-live-backup.log') 120;if($code -ne 0){throw 'Pre-write backup failed'}
 $listing=Join-Path $root 'before-live-backup-toc.log';$code=Invoke-PetugasBoundedProcess 'D:\Program Files\PostgreSQL\bin\pg_restore.exe' @('--list',$backup) $listing 30;if($code -ne 0){throw 'Backup archive unreadable'}
 $toc=Get-Content $listing -Raw;foreach($name in @('transaction_cloud','transaction_cloud_detail','transaction_cloud_process','transaction_cloud_payment','transaction_cloud_number_counter','transaction_cloud_mutation','transaction_cloud_outbox','transaction_cloud_publication','transaksi','transaksi_detail_proses','transaksi_riwayat_pembayaran','pekerjaan_notaris','pekerjaan_ppat')){if($toc -notmatch ("TABLE DATA public "+[regex]::Escape($name)+" ")){throw "Backup missing expected table: $name"}}
 [ordered]@{path=$backup;sha256=(Get-FileHash $backup).Hash}|ConvertTo-Json|Set-Content (Join-Path $root 'before-live-backup.json')
 $env:DB_HOST='127.0.0.1';$env:DB_PORT=$port;$env:DB_NAME=$database;$env:DB_USER=$s.DB_USER;$env:DB_PASSWORD=$s.DB_PASSWORD;$env:DB_SSLMODE='disable';$env:PORT=$httpPort;$env:JWT_SECRET=$s.JWT_SECRET;$env:JWT_EXPIRE_MINUTES='30';$env:PETUGAS_PUBLISHER_ENABLED='false';Remove-Item Env:PGOPTIONS -ErrorAction SilentlyContinue
 Push-Location backend-notaris-go
 try{& go build -o (Join-Path $root 'backend.exe') ./cmd;if($LASTEXITCODE -ne 0){throw 'Backend build failed'};& go build -o (Join-Path $root 'publisher.exe') ./cmd/masterpublish;if($LASTEXITCODE -ne 0){throw 'Publisher build failed'}}finally{Pop-Location}
 $backend=Start-Process -FilePath (Join-Path $root 'backend.exe') -WorkingDirectory (Join-Path $repo 'backend-notaris-go') -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $root 'backend.log') -RedirectStandardError (Join-Path $root 'backend.stderr')
 $ready=$false;for($i=0;$i -lt 100;$i++){if($backend.HasExited){throw 'Owned backend exited'};try{$health=Invoke-RestMethod -Uri "http://127.0.0.1:$httpPort/api/v1/health" -TimeoutSec 2;if($health){$ready=$true;break}}catch{};Start-Sleep -Milliseconds 200};if(!$ready){throw 'Backend readiness timeout'}
 $profile=Get-Content .local/notarisdev-profile.json -Raw|ConvertFrom-Json;$private=Get-Content ('.local/notarisdev-'+$profile.generation+'/login.private.json') -Raw|ConvertFrom-Json
 if($private.username -cne 'fixture.operator' -or !$private.password){throw 'Fixture credential unavailable'}
 $login=Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:$httpPort/api/v1/auth/login" -Body (@{username=$private.username;password=$private.password}|ConvertTo-Json -Compress) -ContentType 'application/json' -TimeoutSec 10
 $private=$null;$token=$login.data.token;if(!$token -or $login.data.user.id -ne 2001 -or $login.data.user.group_id -ne 11){throw 'Authenticated fixture scope mismatch'}
 $fresh=Read-Sql 'immediate-baseline' './scripts/sql/transaction-live-baseline.sql';Check-Baseline $fresh
 $now=@(Read-Sql 'immediate-preservation' (Join-Path $root 'preservation.sql'));if(($now|ConvertTo-Json -Compress -Depth 8) -cne ($preserved|ConvertTo-Json -Compress -Depth 8)){throw 'Source preservation baseline changed'}
 $stream=[IO.File]::Open($lock,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$bytes=[Text.Encoding]::UTF8.GetBytes($ConfirmPlanSha256);$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
 $history.applyAttempted=$true;$history.status='executing_approved_synthetic_plan';Save-History
 $env:MASTER_PUBLISH_DSN="host=127.0.0.1 port=$port dbname=$database sslmode=disable";$env:TRANSACTION_CONTROLLED_ROOT=$root;$env:TRANSACTION_CONTROLLED_AUTHORIZED='APPLY_APPROVED_PLAN';$env:TRANSACTION_CONTROLLED_URL="http://127.0.0.1:$httpPort/api/v1";$env:TRANSACTION_CONTROLLED_TOKEN=$token;$env:TRANSACTION_PUBLISH_EXE=Join-Path $root 'publisher.exe';$env:TRANSACTION_EXECUTE_PLAN_SHA256=$ConfirmPlanSha256
 Push-Location frontend_notaris
 try{& flutter test --no-pub tool/transaction_cloud_execute_prepared.dart --reporter expanded *> (Join-Path $root 'live-flutter.private.log');$testExit=$LASTEXITCODE}finally{Pop-Location}
 $text=Get-Content (Join-Path $root 'live-flutter.private.log') -Raw;$text.Replace($token,'[redacted-token]').Replace($s.DB_PASSWORD,'[redacted-password]')|Set-Content (Join-Path $root 'live-flutter.log');Remove-Item -LiteralPath (Join-Path $root 'live-flutter.private.log')
 if($testExit -ne 0){throw 'Live lifecycle stopped; inspect read-only, no retry or restore'}
 $after=Read-Sql 'live-after-baseline' './scripts/sql/transaction-live-baseline.sql'
 $afterFp=@(Read-Sql 'live-after-preservation' (Join-Path $root 'preservation.sql'))
 if($afterFp[0].approved_collisions -ne 16 -or (($afterFp|Where-Object{$_.table})|ConvertTo-Json -Depth 8 -Compress) -cne (($preserved|Where-Object{$_.table})|ConvertTo-Json -Depth 8 -Compress)){throw 'Legacy preservation failed'}
 if($after.transactions.receipts -ne 6 -or $after.transactions.events -ne 6 -or $after.transactions.pending -ne 0 -or $after.transactions.parents -ne 2 -or $after.transactions.payments -ne 2 -or $after.transactions.last_seq -ne ($plan.baseline.transactions.last_seq+6) -or $after.transactions.min_cursor -ne $plan.baseline.transactions.min_cursor -or @($after.transactions.counters).Count -ne 2 -or @($after.transactions.counters|Where-Object{$_.last_number -ne 1}).Count -ne 0){throw 'Transaction budget/state mismatch'}
 foreach($domain in @('notaris','ppat')){if($after.masters.$domain.pending -ne 0 -or $after.masters.$domain.min_cursor -ne $plan.baseline.masters.$domain.min_cursor -or $after.masters.$domain.last_seq -ne ($plan.baseline.masters.$domain.last_seq+2) -or $after.masters.$domain.receipts -ne ($plan.baseline.masters.$domain.receipts+2) -or $after.masters.$domain.events -ne ($plan.baseline.masters.$domain.events+2)){throw 'Master budget/state mismatch'}}
 $history.status='verified';$history.completedUtc=[datetime]::UtcNow.ToString('o');Save-History;Write-Output "CONTROLLED_TRANSACTION_LIVE_VERIFIED: $root; events=6; Masters=4; pending=0; legacy preserved"
}catch{$history.status=if($history.applyAttempted){'stopped_inspect_readonly_no_retry'}else{'preflight_failed_no_write'};$history.error=$_.Exception.Message;Save-History;throw}finally{if($backend -and !$backend.HasExited){$backend.Kill();$backend.WaitForExit(15000)|Out-Null};$token=$null;$private=$null;foreach($k in $keys){if($null -eq $old[$k]){Remove-Item -LiteralPath "Env:$k" -ErrorAction SilentlyContinue}else{[Environment]::SetEnvironmentVariable($k,$old[$k])}}}
