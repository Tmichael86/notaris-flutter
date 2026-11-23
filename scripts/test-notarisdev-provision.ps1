# Safe live acceptance: owns a fresh temp cluster, never connects to port 5432.
param([string]$PostgresBin='D:\Program Files\PostgreSQL\bin')
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
$root=Join-Path ([IO.Path]::GetTempPath()) ('notaris-fixture-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root|Out-Null
$target='notaris_fixture_test_'+[guid]::NewGuid().ToString('N')
$keys=@('PGHOST','PGPORT','PGDATABASE','PGUSER','PGPASSWORD','PGOPTIONS','NOTARIS_FIXTURE_HTTP_DSN','NOTARIS_DEV_FIXTURE_PASSWORD')
$previous=@{};foreach($k in $keys){$previous[$k]=[Environment]::GetEnvironmentVariable($k)}
$location=Get-Location;$started=$false
function Psql([string]$Text){$value=& (Join-Path $PostgresBin 'psql.exe') -X -w -v ON_ERROR_STOP=1 -Atc $Text;if($LASTEXITCODE){throw 'Test SQL failed'};return $value}
try {
 $probe=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,55441);try{$probe.Start()}finally{$probe.Stop()}
 & (Join-Path $PostgresBin 'initdb.exe') -D (Join-Path $root 'data') -U notaris_test --auth=trust --encoding=UTF8 --no-locale *> (Join-Path $root 'init.log')
 if($LASTEXITCODE){throw 'initdb failed'}
 $started=$true
 $ctl=Start-Process -FilePath (Join-Path $PostgresBin 'pg_ctl.exe') -ArgumentList @('-D',('"'+(Join-Path $root 'data')+'"'),'-l',('"'+(Join-Path $root 'postgres.log')+'"'),'-o','"-h 127.0.0.1 -p 55441"','-w','start') -WindowStyle Hidden -RedirectStandardOutput (Join-Path $root 'start.log') -RedirectStandardError (Join-Path $root 'start.err') -PassThru
 if(!$ctl.WaitForExit(45000) -or $ctl.ExitCode -ne 0){throw 'test pg_ctl start failed'}
 $env:PGHOST='127.0.0.1';$env:PGPORT='55441';$env:PGUSER='notaris_test';$env:PGDATABASE='postgres';Remove-Item Env:PGPASSWORD,Env:PGOPTIONS -ErrorAction SilentlyContinue
 & "$PSScriptRoot/provision-notarisdev.ps1" -Database $target -Port 55441 -TestRoot $root
 if((Psql "SELECT count(*) FROM pg_database WHERE datname='$target'") -ne '0'){throw 'Dry run created database'}
 & "$PSScriptRoot/provision-notarisdev.ps1" -Database $target -Port 55441 -TestRoot $root -Apply -ConfirmTarget "127.0.0.1:55441/$target"
 $blocked=$false;try{& "$PSScriptRoot/provision-notarisdev.ps1" -Database $target -Port 55441 -TestRoot $root}catch{$blocked=$true}
 if(!$blocked){throw 'Existing target not refused'}
 $env:PGDATABASE=$target
 if((Psql "SELECT count(*) FROM pg_constraint WHERE contype='f' AND connamespace='public'::regnamespace") -ne '0'){throw 'Unexpected FK addition'}
 $manifest=Get-ChildItem (Join-Path $repo '.local') -Directory -Filter 'notarisdev-*'|ForEach-Object { $file=Join-Path $_.FullName 'manifest.json';if(Test-Path $file){$m=Get-Content $file -Raw|ConvertFrom-Json;if($m.database -eq $target){$_.FullName}}}|Select-Object -First 1
 if(!$manifest){throw 'Test manifest missing'}
 $env:NOTARIS_DEV_FIXTURE_PASSWORD=(Get-Content (Join-Path $manifest 'login.private.json') -Raw|ConvertFrom-Json).password
 $env:NOTARIS_FIXTURE_HTTP_DSN="host=127.0.0.1 port=55441 user=notaris_test dbname=$target sslmode=disable"
 Set-Location (Join-Path $repo 'backend-notaris-go')
 & go test -v -count=1 ./internal/devfixture
 if($LASTEXITCODE){throw 'Generator/normal HTTP integration test failed'}
 & go run ./cmd/devfixture -mode validate
 if($LASTEXITCODE){throw 'Baseline validation failed'}
 Psql 'UPDATE transaksi_detail_proses SET transaksi_id=999999 WHERE id=601'|Out-Null
 & go run ./cmd/devfixture -mode validate *> (Join-Path $root 'expected-broken-reference.log')
 if($LASTEXITCODE -eq 0){throw 'Broken reference not detected'}
 Psql 'UPDATE transaksi_detail_proses SET transaksi_id=501 WHERE id=601'|Out-Null
 & go run ./cmd/devfixture -mode validate
 if($LASTEXITCODE){throw 'Repaired synthetic baseline invalid'}
 & (Join-Path $PostgresBin 'psql.exe') -X -w -v ON_ERROR_STOP=1 -f (Join-Path $manifest 'fixture.sql') *> (Join-Path $root 'expected-reload-refusal.log')
 if($LASTEXITCODE -eq 0){throw 'Nonempty fixture reload accepted'}
 Write-Output "PASS: dry-run, schema restore, synthetic graph, HTTP login/permission, broken-edge detection, duplicate provisioning/reload refusal. Logs: $root"
} finally {
 Set-Location $location
 if($started){& (Join-Path $PostgresBin 'pg_ctl.exe') -D (Join-Path $root 'data') -m fast -w stop *> (Join-Path $root 'stop.log');if($LASTEXITCODE){Write-Warning "Test cluster stop failed; inspect $root"}}
 foreach($k in $previous.Keys){if($null -eq $previous[$k]){Remove-Item -LiteralPath "Env:$k" -ErrorAction SilentlyContinue}else{[Environment]::SetEnvironmentVariable($k,$previous[$k])}}
}
