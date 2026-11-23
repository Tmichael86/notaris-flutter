# Restores ONLY a notarisdev backup to a newly owned disposable cluster.
param([Parameter(Mandatory)][string]$BackupDirectory,[string]$PostgresBin='D:\Program Files\PostgreSQL\bin')
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
$BackupDirectory=(Resolve-Path -LiteralPath $BackupDirectory).Path
$metadata=Get-Content (Join-Path $BackupDirectory 'preflight.json') -Raw|ConvertFrom-Json
if($metadata.database -ne 'notarisdev' -or $metadata.marker -ne 'NOTARISDEV SYNTHETIC v1'){throw 'Expected development backup manifest'}
$archive=Join-Path $BackupDirectory 'notarisdev-before.dump'
if((Get-FileHash $archive).Hash -ne (Get-Content (Join-Path $BackupDirectory 'sha256.json') -Raw|ConvertFrom-Json).Hash){throw 'Backup checksum mismatch'}
$root=Join-Path ([IO.Path]::GetTempPath()) ('notaris-petugas-readiness-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root|Out-Null
$keys=@('PGHOST','PGPORT','PGDATABASE','PGUSER','PGPASSWORD','PGOPTIONS','NOTARIS_SYNC_TEST_DSN','NOTARIS_READINESS_TEST_DSN','NOTARIS_READINESS_FIXTURE_PASSWORD','NOTARIS_FLUTTER_E2E')
$previous=@{};foreach($k in $keys){$previous[$k]=[Environment]::GetEnvironmentVariable($k)}
$location=Get-Location;$started=$false
function Sql([string]$Text){$r=& (Join-Path $PostgresBin 'psql.exe') -X -w -v ON_ERROR_STOP=1 -Atc $Text;if($LASTEXITCODE){throw 'Disposable SQL failed'};return $r}
try {
 $probe=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,55442);try{$probe.Start()}finally{$probe.Stop()}
 & (Join-Path $PostgresBin 'initdb.exe') -D (Join-Path $root 'data') -U notaris_test --auth=trust --encoding=UTF8 --no-locale *> (Join-Path $root 'init.log')
 if($LASTEXITCODE){throw 'initdb failed'}
 $started=$true
 $ctl=Start-Process -FilePath (Join-Path $PostgresBin 'pg_ctl.exe') -ArgumentList @('-D',('"'+(Join-Path $root 'data')+'"'),'-l',('"'+(Join-Path $root 'postgres.log')+'"'),'-o','"-h 127.0.0.1 -p 55442"','-w','start') -WindowStyle Hidden -RedirectStandardOutput (Join-Path $root 'start.log') -RedirectStandardError (Join-Path $root 'start.err') -PassThru
 if(!$ctl.WaitForExit(45000) -or $ctl.ExitCode -ne 0){throw 'Disposable start failed'}
 $env:PGHOST='127.0.0.1';$env:PGPORT='55442';$env:PGUSER='notaris_test';$env:PGDATABASE='postgres';Remove-Item Env:PGPASSWORD,Env:PGOPTIONS,Env:NOTARIS_FLUTTER_E2E -ErrorAction SilentlyContinue
 if([IO.Path]::GetFullPath((Sql 'SHOW data_directory').TrimEnd('\')) -ne [IO.Path]::GetFullPath((Join-Path $root 'data'))){throw 'Wrong cluster'}
 Sql 'CREATE DATABASE notarisdev TEMPLATE template0'|Out-Null
 $env:PGDATABASE='notarisdev'
 & (Join-Path $PostgresBin 'pg_restore.exe') --exit-on-error --single-transaction --no-owner --no-privileges -d notarisdev $archive
 if($LASTEXITCODE){throw 'Disposable full restore failed'}
 $fingerprint=Sql "SELECT md5(COALESCE(jsonb_agg(to_jsonb(d) ORDER BY id)::text,'[]')) FROM public.transaksi_detail_proses d"
 if($fingerprint -ne $metadata.detail_fingerprint){throw 'Restored detail fingerprint mismatch'}
 Sql 'CREATE ROLE readiness_app LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE; GRANT CONNECT ON DATABASE notarisdev TO readiness_app; GRANT USAGE ON SCHEMA public TO readiness_app; GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA public TO readiness_app; GRANT USAGE,SELECT,UPDATE ON ALL SEQUENCES IN SCHEMA public TO readiness_app'|Out-Null
 & (Join-Path $PostgresBin 'psql.exe') -X -w -v NOTARIS_DEV_REVIEWED=true -v NOTARIS_DEV_APP_ROLE=readiness_app -f (Join-Path $repo 'backend-notaris-go/migration_proposals/20261030_03_notarisdev_petugas.sql') *> (Join-Path $root 'migration.log')
 if($LASTEXITCODE){throw "Disposable migration failed; logs $root"}
 $uuidBefore=Sql "SELECT string_agg(uuid::text,',' ORDER BY id) FROM petugas"
 & (Join-Path $PostgresBin 'psql.exe') -X -w -v ON_ERROR_STOP=1 -f (Join-Path $repo 'backend-notaris-go/migrations/20261030_02_petugas_uuid_hardening.sql') *> (Join-Path $root 'backfill-repeat.log')
 if($LASTEXITCODE -or (Sql "SELECT string_agg(uuid::text,',' ORDER BY id) FROM petugas") -ne $uuidBefore){throw 'UUID backfill not stable'}
 & (Join-Path $PostgresBin 'psql.exe') -X -w -v NOTARIS_DEV_REVIEWED=true -v NOTARIS_DEV_APP_ROLE=readiness_app -f (Join-Path $repo 'backend-notaris-go/migration_proposals/20261030_03_notarisdev_petugas.sql') *> (Join-Path $root 'expected-first-install-refusal.log')
 if($LASTEXITCODE -eq 0){throw 'Existing foundation was not refused'}
 $profile=Get-Content (Join-Path $repo '.local/notarisdev-profile.json') -Raw|ConvertFrom-Json
 $env:NOTARIS_READINESS_FIXTURE_PASSWORD=(Get-Content (Join-Path $repo ".local/notarisdev-$($profile.generation)/login.private.json") -Raw|ConvertFrom-Json).password
 $env:NOTARIS_READINESS_TEST_DSN='host=127.0.0.1 port=55442 user=readiness_app dbname=notarisdev sslmode=disable'
 $env:NOTARIS_SYNC_TEST_DSN='host=127.0.0.1 port=55442 user=notaris_test dbname=postgres sslmode=disable'
 Set-Location (Join-Path $repo 'backend-notaris-go')
 & go test -json -count=1 ./... > (Join-Path $root 'go-tests.jsonl')
 if($LASTEXITCODE){throw "Go suite failed; $root/go-tests.jsonl"}
 $events=Get-Content (Join-Path $root 'go-tests.jsonl')|ConvertFrom-Json
 $events|Where-Object Test|Group-Object Action|Where-Object Name -in @('pass','fail','skip')|Select-Object Name,Count|Format-Table
 & go test -count=10 -run 'TestPetugasPublicationCommitOrderPostgres|TestPetugasPublisherRollbackAndSerializationPostgres|TestPetugasBootstrapConcurrentPostgres|TestPetugasLegacySyncConcurrencyPostgres' ./repositories > (Join-Path $root 'concurrency.log')
 if($LASTEXITCODE){throw 'Repeated PostgreSQL concurrency failed'}
 if((Sql "SELECT md5(COALESCE(jsonb_agg(to_jsonb(d) ORDER BY id)::text,'[]')) FROM public.transaksi_detail_proses d") -ne $fingerprint){throw 'Transaction details changed'}
 Write-Output "READINESS_PASS: restored archive + actual migration + restricted-role CRUD/sync + bootstrap retry + publisher concurrency x10. Logs: $root"
} finally {
 Set-Location $location
 if($started){& (Join-Path $PostgresBin 'pg_ctl.exe') -D (Join-Path $root 'data') -m fast -w stop *> (Join-Path $root 'stop.log');if($LASTEXITCODE){Write-Warning "Stop failed: $root"}}
 foreach($k in $previous.Keys){if($null -eq $previous[$k]){Remove-Item -LiteralPath "Env:$k" -ErrorAction SilentlyContinue}else{[Environment]::SetEnvironmentVariable($k,$previous[$k])}}
}
