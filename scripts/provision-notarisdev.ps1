# Default is read-only preflight. Never connects to the source database.
param([switch]$Apply,[string]$ConfirmTarget,[string]$Archive,[string]$PostgresBin='D:\Program Files\PostgreSQL\bin',
 [string]$Database='notarisdev',[int]$Port=5432,[string]$TestRoot)
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
$temporary=$Database -match '^notaris_fixture_test_[a-f0-9]+$'
if (!$temporary -and ($Database -ne 'notarisdev' -or $Port -ne 5432)) { throw 'Only approved localhost:5432/notarisdev target allowed' }
if ($temporary -and ($Port -eq 5432 -or !$TestRoot)) { throw 'Temporary target requires isolated cluster and non-main port' }
if (!$Archive) { $Archive=Join-Path $repo '.local/notarisdev-review-20261030-081705-1424d2b5/source-schema.dump' }
$Archive=(Resolve-Path -LiteralPath $Archive).Path
$envKeys=@('PGHOST','PGPORT','PGDATABASE','PGUSER','PGPASSWORD','PGOPTIONS','PGCONNECT_TIMEOUT','NOTARIS_DEV_FIXTURE_PASSWORD')
$previous=@{};foreach($k in $envKeys){$previous[$k]=[Environment]::GetEnvironmentVariable($k)}
$location=Get-Location
function Random-Hex { return [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(24)).ToLowerInvariant() }
function Sql([string]$Text) {
 $result=& (Join-Path $PostgresBin 'psql.exe') -X -w -v ON_ERROR_STOP=1 -Atc $Text
 if($LASTEXITCODE){throw 'PostgreSQL provisioning query failed (credentials not logged)'}
 return $result
}
try {
 $env:PGHOST='127.0.0.1';$env:PGPORT="$Port";$env:PGDATABASE='postgres';$env:PGCONNECT_TIMEOUT='5';$env:PGOPTIONS='-c default_transaction_read_only=on'
 if(!$env:PGUSER){$env:PGUSER='postgres'}
 if(!$temporary -and !$env:PGPASSWORD) {
  $credential=Get-Credential -UserName $env:PGUSER -Message 'Local provisioning administrator (not copied into the development app)'
  if(!$credential){throw 'Administrator authentication required'}
  $env:PGUSER=$credential.UserName;$env:PGPASSWORD=$credential.GetNetworkCredential().Password
 }
 if((Sql "SELECT count(*) FROM pg_database WHERE datname='$Database'") -ne '0'){throw 'Target exists: refusing overwrite, restore, or fixture reload'}
 if(!$temporary -and ((Test-Path (Join-Path $repo 'backend-notaris-go/.env.notarisdev')) -or (Test-Path (Join-Path $repo '.local/notarisdev-profile.json')))){throw 'Existing local development config/profile: inspect first; refusing provisioning'}
 if((Sql 'SELECT count(*) FROM pg_roles WHERE rolname=current_user AND (rolsuper OR (rolcreatedb AND rolcreaterole))') -ne '1'){throw 'Provisioning administrator needs CREATE DATABASE / ROLE privileges'}
 if($temporary){
  $root=[IO.Path]::GetFullPath($TestRoot).TrimEnd('\');$temp=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
  if(!$root.StartsWith($temp,[StringComparison]::OrdinalIgnoreCase)){throw 'TestRoot must be temporary'}
  $data=(Sql 'SHOW data_directory').TrimEnd('\')
  if([IO.Path]::GetFullPath($data) -ne [IO.Path]::GetFullPath((Join-Path $root 'data'))){throw 'Cluster data directory mismatch'}
 }
 $toc=& (Join-Path $PostgresBin 'pg_restore.exe') --list $Archive
 if($LASTEXITCODE -or ($toc|Select-String 'TABLE DATA|SEQUENCE SET')){throw 'Archive must be schema-only'}
 $expected=Join-Path (Split-Path $Archive -Parent) 'archive-sha256.json'
 if(!(Test-Path $expected) -or (Get-FileHash $Archive).Hash -ne (Get-Content $expected -Raw|ConvertFrom-Json).Hash){throw 'Archive checksum mismatch or review checksum missing'}
 Write-Output "PREFLIGHT PASS: 127.0.0.1:$Port/$Database absent; reviewed schema-only archive checksum valid. No changes made."
 if(!$Apply){return}
 if($ConfirmTarget -ne "127.0.0.1:$Port/$Database"){throw 'Exact -ConfirmTarget required'}
 if(!$temporary -and (Read-Host 'Type CREATE notarisdev to approve database + restricted role + synthetic data') -cne 'CREATE notarisdev'){throw 'Explicit provisioning confirmation not supplied'}
 $generation=[guid]::NewGuid().ToString('N')
 $artifacts=Join-Path $repo ".local/notarisdev-$generation";New-Item -ItemType Directory -Path $artifacts|Out-Null
 $role='nd_app_'+$generation.Substring(0,12);$dbPassword=Random-Hex;$loginPassword=Random-Hex;$jwt=Random-Hex
 $env:NOTARIS_DEV_FIXTURE_PASSWORD=$loginPassword
 Set-Location (Join-Path $repo 'backend-notaris-go')
 & go run ./cmd/devfixture -mode generate -out (Join-Path $artifacts 'fixture.sql')
 if($LASTEXITCODE){throw 'Fixture generation failed'}
 # Atomic CREATE DATABASE fails if another operator creates the target meanwhile.
 $env:PGOPTIONS=''
 Sql "CREATE DATABASE $Database TEMPLATE template0"|Out-Null
 $env:PGDATABASE=$Database
 & (Join-Path $PostgresBin 'pg_restore.exe') --no-owner --no-privileges --exit-on-error --single-transaction -d $Database $Archive
 if($LASTEXITCODE){throw "Schema restore failed; target retained for inspection: $Database"}
 & (Join-Path $PostgresBin 'psql.exe') -X -w -v ON_ERROR_STOP=1 -f (Join-Path $artifacts 'fixture.sql') *> (Join-Path $artifacts 'fixture-load.log')
 if($LASTEXITCODE){throw 'Fixture load failed; target retained, no automatic deletion'}
 & go run ./cmd/devfixture -mode validate
 if($LASTEXITCODE){throw 'Fixture reference validation failed'}
 # Role is new, non-owner, no CREATEDB/CREATEROLE or schema CREATE rights.
 & (Join-Path $PostgresBin 'psql.exe') -X -w -v ON_ERROR_STOP=1 -c "CREATE ROLE $role LOGIN PASSWORD '$dbPassword' NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT; GRANT CONNECT ON DATABASE $Database TO $role; GRANT USAGE ON SCHEMA public TO $role; GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA public TO $role; GRANT USAGE,SELECT,UPDATE ON ALL SEQUENCES IN SCHEMA public TO $role;" *> (Join-Path $artifacts 'grants.private.log')
 if($LASTEXITCODE){throw 'Restricted role/grants failed; inspect private local log, do not share it'}
 $manifest=@{generation=$generation;database=$Database;port=$Port;fixture='smoke-v1';archiveSha256=(Get-FileHash $Archive).Hash}
 $manifest|ConvertTo-Json|Set-Content (Join-Path $artifacts 'manifest.json')
 @{username='fixture.operator';password=$loginPassword}|ConvertTo-Json|Set-Content (Join-Path $artifacts 'login.private.json')
 if(!$temporary){
  $config=Join-Path $repo 'backend-notaris-go/.env.notarisdev'
  if(Test-Path $config){throw 'Private dev config already exists; refusing overwrite'}
  "DB_HOST=127.0.0.1`nDB_PORT=5432`nDB_NAME=notarisdev`nDB_USER=$role`nDB_PASSWORD=$dbPassword`nDB_SSLMODE=disable`nPORT=8081`nJWT_SECRET=$jwt`nPETUGAS_PUBLISHER_ENABLED=false"|Set-Content $config
  # Pointer only after successful validation; no credentials in this file.
  $manifest|ConvertTo-Json|Set-Content (Join-Path $repo '.local/notarisdev-profile.json')
 }
 Write-Output "PROVISIONED synthetic target only: $Database. Private fixture login: $artifacts/login.private.json"
 Write-Output 'Cloud Sync migrations/bootstrap/publication NOT applied. No automatic rollback/drop.'
} finally {
 Set-Location $location
 foreach($k in $previous.Keys){if($null -eq $previous[$k]){Remove-Item -LiteralPath "Env:$k" -ErrorAction SilentlyContinue}else{[Environment]::SetEnvironmentVariable($k,$previous[$k])}}
}
