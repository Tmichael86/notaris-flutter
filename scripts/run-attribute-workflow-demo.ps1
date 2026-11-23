[CmdletBinding()]
param([switch]$Test)
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
$port=55671
if (@(Get-NetTCPConnection -State Listen | Where-Object LocalPort -eq $port).Count) {
    throw 'Disposable PostgreSQL port 55671 is already in use.'
}
$bin='D:/Program Files/PostgreSQL/bin'
$id=[guid]::NewGuid().ToString('N').Substring(0,12)
$db="attribute_demo_$id"
$root=Join-Path $repo ".local/attribute-disposable-$id"
New-Item -ItemType Directory -Path $root | Out-Null
$data=Join-Path $root 'pgdata'
$envKeys=@('NOTARIS_ATTRIBUTE_TEST_DSN','NOTARIS_ATTRIBUTE_DEMO','NOTARIS_ATTRIBUTE_FLUTTER_E2E',
 'NOTARIS_ATTRIBUTE_DIMAS_PASSWORD','NOTARIS_ATTRIBUTE_NABILA_PASSWORD',
 'NOTARIS_UI_ACCEPTANCE_PLAN','NOTARIS_UI_ACCEPTANCE_SHA256')
$prior=@{}
foreach($key in $envKeys){$prior[$key]=[Environment]::GetEnvironmentVariable($key)}
$location=Get-Location
$started=$false
try {
    Remove-Item Env:NOTARIS_UI_ACCEPTANCE_PLAN,Env:NOTARIS_UI_ACCEPTANCE_SHA256 -ErrorAction SilentlyContinue
    & "$bin/initdb.exe" -D $data -U postgres -A trust --no-locale -E UTF8 *> (Join-Path $root 'initdb.log')
    if($LASTEXITCODE){throw "Disposable initdb failed. Evidence: $root"}
    & "$bin/pg_ctl.exe" start -D $data -l (Join-Path $root 'postgres.log') -o "-h 127.0.0.1 -p $port" -w
    if($LASTEXITCODE){throw 'Disposable PostgreSQL did not start.'}
    $started=$true
    $instance=& "$bin/psql.exe" -X -w -h 127.0.0.1 -p $port -U postgres -d postgres -Atc 'SHOW data_directory'
    if($LASTEXITCODE -or [IO.Path]::GetFullPath($instance) -ne [IO.Path]::GetFullPath($data)){
        throw 'PostgreSQL instance is outside the owned directory.'
    }
    & "$bin/createdb.exe" -h 127.0.0.1 -p $port -U postgres $db
    if($LASTEXITCODE){throw 'Disposable database creation failed.'}
    & "$bin/psql.exe" -X -w -h 127.0.0.1 -p $port -U postgres -d $db -v ON_ERROR_STOP=1 -qc "COMMENT ON DATABASE $db IS 'NOTARIS ATTRIBUTE DISPOSABLE $db'"
    if($LASTEXITCODE){throw 'Disposable marker installation failed.'}
    $env:NOTARIS_ATTRIBUTE_TEST_DSN="postgres://postgres@127.0.0.1:${port}/${db}?sslmode=disable"
    Set-Location (Join-Path $repo 'backend-notaris-go')
    "Disposable evidence: $root"
    if($Test) {
        $env:NOTARIS_ATTRIBUTE_FLUTTER_E2E='1'
        & go test ./routes -run '^TestAttributeWorkflow(Postgres|FlutterPostgres)$' -count=1 -v |
            Tee-Object -FilePath (Join-Path $root 'focused-e2e.log')
    } else {
        $env:NOTARIS_ATTRIBUTE_DIMAS_PASSWORD=[Net.NetworkCredential]::new('',(Read-Host 'Password demo.dimas, minimal 12 karakter' -AsSecureString)).Password
        $env:NOTARIS_ATTRIBUTE_NABILA_PASSWORD=[Net.NetworkCredential]::new('',(Read-Host 'Password demo.nabila, berbeda dan minimal 12 karakter' -AsSecureString)).Password
        $env:NOTARIS_ATTRIBUTE_DEMO='1'
        & go test ./routes -run '^TestAttributeWorkflowDemo$' -timeout 90m -count=1 -v
    }
    if($LASTEXITCODE){throw 'Disposable workflow run failed.'}
} finally {
    Set-Location $location
    foreach($key in $envKeys){[Environment]::SetEnvironmentVariable($key,$prior[$key])}
    if($started){& "$bin/pg_ctl.exe" stop -D $data -m fast -w}
}
