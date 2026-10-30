# Controlled Petugas E2E (development/testing only)

For one-command Windows manual Desktop setup/cleanup, use
`scripts/start-petugas-manual-test.ps1` and `scripts/stop-petugas-manual-test.ps1`
from the repository root. See [PETUGAS_MANUAL_DESKTOP.md](PETUGAS_MANUAL_DESKTOP.md).
The provisioning instructions below remain an alternative for automated E2E.

Reference contract: GET /api/v1/petugas/references/jenis-kelamin requires JWT,
active user/group and existing Petugas read permission. Standard success envelope
contains data.items with id (server integer), nama (display label), status=1.
No global canonical code/UUID is invented. An empty list means no active reference;
unavailable storage returns generic reference_unavailable. Names are not matching
keys. Flutter PetugasReferenceApi retrieves this list; an operator must explicitly
select and confirm the local UUID/server ID pair through VerifiedPetugasReferences.

The E2E fixture manifest explicitly pairs local-e2e-gender with server row 2.
The local ID is deliberately 1. This is controlled fixture confirmation, not
automatic reconciliation. Production reference choices still require operator
evidence; an official immutable canonical code contract remains undefined.

Prerequisites: Go, Flutter, PostgreSQL binaries and an unused loopback port 55439.
Use a fresh temporary cluster, never an application's active .env database.
Example PowerShell from the repository root (adjust binary path if necessary):

```powershell
$pgBin = 'D:\Program Files\PostgreSQL\bin'
$testCluster = Join-Path ([IO.Path]::GetTempPath()) ('notaris-e2e-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testCluster | Out-Null
& "$pgBin\initdb.exe" -D "$testCluster\data" -U notaris_test --auth=trust --encoding=UTF8 --no-locale
if ($LASTEXITCODE -ne 0) { throw 'initdb failed' }
& "$pgBin\pg_ctl.exe" -D "$testCluster\data" -l "$testCluster\postgres.log" -o '-h 127.0.0.1 -p 55439' -w start
if ($LASTEXITCODE -ne 0) { throw 'test cluster startup failed' }
try {
  $env:NOTARIS_SYNC_TEST_DSN = 'host=127.0.0.1 port=55439 user=notaris_test dbname=postgres sslmode=disable'
  Push-Location backend-notaris-go
  try {
    go test -count=1 ./...
    if ($LASTEXITCODE -ne 0) { throw 'Go suite failed' }
    $env:NOTARIS_FLUTTER_E2E = '1'
    go test -v -count=1 -run TestPetugasSyncHTTPPostgres ./routes
    if ($LASTEXITCODE -ne 0) { throw 'Flutter HTTP E2E failed' }
  } finally { Pop-Location }
} finally {
  Remove-Item Env:NOTARIS_SYNC_TEST_DSN -ErrorAction SilentlyContinue
  Remove-Item Env:NOTARIS_FLUTTER_E2E -ErrorAction SilentlyContinue
  & "$pgBin\pg_ctl.exe" -D "$testCluster\data" -m fast -w stop
}
```

Trust authentication above is only for this short-lived loopback cluster, which
contains no real data. Nothing connects to an existing PostgreSQL service or
loads backend application .env. No shared-server database is created. The fixture
creates one random schema and drops only that schema afterward. The temporary
cluster directory/log remains for inspection after shutdown; no user SQLite is
opened or deleted.

The Go HTTP test fixture builds auth/master prerequisites, applies identity ->
publication -> UUID-hardening SQL in order, inserts a clearly labeled legacy
Petugas, calls Bootstrap, starts the real publication worker and a loopback HTTP
server with the real router/JWT/permission stack. It starts flutter test as a child
with ephemeral server URL and signed test token in environment variables, not CLI
arguments or log output. Go checks that the device write actually reached
PostgreSQL. Server/worker stop and test schemas close on test completion.

Flutter creates its own temp SQLite file, confirms the fixture reference mapping,
reconciles its new local Petugas as local-only, pushes, polls incremental pull,
verifies the legacy baseline, then closes/reopens SQLite and checks cursor and
identity persistence. It uses real Dio HTTP, not fake responses. The ordinary
Flutter suite intentionally skips this one live test without the harness; the
opt-in Go run must report one live Flutter test passed, not skipped. The normal
Go HTTP test runs its original auth/conflict/reference tests with opt-in unset.

This establishes an automated Flutter-test-client/Go/PostgreSQL roundtrip, not
interactive Windows Desktop UI validation. No UI/SyncCoordinator is activated.
409/410 preservation remains covered by existing SQLite/fake HTTP tests and Go
HTTP integration; this initial live scenario does not attempt expired-cursor
recovery. Full-resync recovery, operator UI and production rollout remain blockers.
