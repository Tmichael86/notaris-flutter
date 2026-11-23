# Fresh owned disposable cluster only. No archive restore or permanent connection.
param([string]$PostgresBin='D:\Program Files\PostgreSQL\bin')
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'petugas-operations-common.ps1')
$root=Join-Path ([IO.Path]::GetTempPath()) ('notaris-petugas-operations-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root|Out-Null
$data=Join-Path $root 'data';$started=$false;$location=Get-Location
$keys=@('PGHOST','PGPORT','PGDATABASE','PGUSER','PGPASSWORD','PGOPTIONS','PGCONNECT_TIMEOUT','NOTARIS_SYNC_TEST_DSN','NOTARIS_OPS_TEST_DSN','NOTARIS_READINESS_TEST_DSN','NOTARIS_FIXTURE_HTTP_DSN','NOTARIS_FLUTTER_E2E')
$previous=@{};foreach($key in $keys){$previous[$key]=[Environment]::GetEnvironmentVariable($key)}
function Sql([string]$Text){$result=& (Join-Path $PostgresBin 'psql.exe') -X -w -At -v ON_ERROR_STOP=1 -c $Text;if($LASTEXITCODE){throw 'Disposable SQL failed'};return $result}
try {
 $probe=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,55445);try{$probe.Start()}finally{$probe.Stop()}
 $exitCode=Invoke-PetugasBoundedProcess (Join-Path $PostgresBin 'initdb.exe') @('-D',$data,'-U','notaris_test','--auth=trust','--encoding=UTF8','--no-locale') (Join-Path $root 'init.log') 60
 if($exitCode){throw 'Disposable initdb failed'}
 $started=$true
 $exitCode=Invoke-PetugasBoundedProcess (Join-Path $PostgresBin 'pg_ctl.exe') @('-D',$data,'-l',(Join-Path $root 'postgres.log'),'-o','-h 127.0.0.1 -p 55445','-w','start') (Join-Path $root 'start.log') 60
 if($exitCode){throw 'Disposable start failed'}
 $env:PGHOST='127.0.0.1';$env:PGPORT='55445';$env:PGDATABASE='postgres';$env:PGUSER='notaris_test';$env:PGCONNECT_TIMEOUT='5'
 Remove-Item Env:PGPASSWORD,Env:PGOPTIONS,Env:NOTARIS_READINESS_TEST_DSN,Env:NOTARIS_FIXTURE_HTTP_DSN,Env:NOTARIS_FLUTTER_E2E -ErrorAction SilentlyContinue
 $owned=Sql "SELECT json_build_object('directory',current_setting('data_directory'),'port',inet_server_port())"|ConvertFrom-Json
 if([IO.Path]::GetFullPath($owned.directory) -ne [IO.Path]::GetFullPath($data) -or $owned.port -ne 55445){throw 'Wrong owned cluster; database creation refused'}
 $owned|ConvertTo-Json|Set-Content (Join-Path $root 'identity.json')
 Sql 'CREATE DATABASE notarisdev TEMPLATE template0'|Out-Null
 $env:NOTARIS_SYNC_TEST_DSN='host=127.0.0.1 port=55445 user=notaris_test dbname=postgres sslmode=disable'
 $env:NOTARIS_OPS_TEST_DSN='host=127.0.0.1 port=55445 user=notaris_test dbname=notarisdev sslmode=disable'
 & (Join-Path $PSScriptRoot 'test-petugas-operations-guards.ps1')
 Set-Location (Join-Path $repo 'backend-notaris-go')
 & go test -json -count=1 ./... 1> (Join-Path $root 'go-tests.jsonl') 2> (Join-Path $root 'go-tests.stderr')
 $testExit=$LASTEXITCODE
 $events=Get-Content (Join-Path $root 'go-tests.jsonl')|ConvertFrom-Json
 $summary=[ordered]@{exitCode=$testExit;passes=@($events|Where-Object {$_.Test -and $_.Action -eq 'pass'}).Count;failures=@($events|Where-Object {$_.Test -and $_.Action -eq 'fail'}).Count;skips=@($events|Where-Object {$_.Test -and $_.Action -eq 'skip'}|ForEach-Object {$_.Package+'.'+$_.Test});logs=$root}
 $summary|ConvertTo-Json|Set-Content (Join-Path $root 'summary.json')
 $summary|ConvertTo-Json
 if($testExit){throw "Go regression/operations integration failed; inspect $root"}
 # Repeat the existing destructive/concurrency fixtures only in the postgres
 # database's random schemas. The initial-rollout public fixture is not replayed.
 & go test -count=5 -run 'TestPetugasPublicationCommitOrderPostgres|TestPetugasPublisherRollbackAndSerializationPostgres|TestPetugasBootstrapConcurrentPostgres|TestPetugasLegacySyncConcurrencyPostgres' ./repositories 1> (Join-Path $root 'concurrency.log') 2> (Join-Path $root 'concurrency.stderr')
 if($LASTEXITCODE){throw "Repeated concurrency failed; inspect $root"}
 Write-Output "PETUGAS_OPERATIONS_TESTS_PASS: full suite + concurrency x5; $root"
} finally {
 Set-Location $location
 if($started){& (Join-Path $PostgresBin 'pg_ctl.exe') -D $data -m fast -w stop *> (Join-Path $root 'stop.log');if($LASTEXITCODE){Write-Warning "Owned cluster stop failed: $root"}}
 foreach($key in $previous.Keys){if($null -eq $previous[$key]){Remove-Item -LiteralPath "Env:$key" -ErrorAction SilentlyContinue}else{[Environment]::SetEnvironmentVariable($key,$previous[$key])}}
}
