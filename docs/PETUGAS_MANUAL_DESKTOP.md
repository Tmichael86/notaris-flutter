# Debug-only Petugas Desktop testing

Production main.dart, global SyncCoordinator and other modules' sync providers
are unchanged. Manual controls default OFF. The only supported manual path is
the separate debug target petugas_manual_main.dart with explicit compile opt-in.
Release/profile builds refuse this target. No application auth secure storage,
daily SQLite file, migrations or bootstrap are opened/run by Flutter startup.

## Normal development versus isolated Petugas testing

Normal development is unchanged (uses your normal configured database/profile):

```powershell
# Terminal 1, backend-notaris-go
go run ./cmd
# Terminal 2, frontend_notaris
flutter run -d windows
```

For Petugas Cloud Sync testing, open two PowerShell terminals at the repository
root. Neither command requires DSN, JWT, nonce, session path or PostgreSQL PATH:

```powershell
# Terminal 1: starts/reuses isolated PostgreSQL, test backend and publisher
.\scripts\run-petugas-test-backend.ps1
# Terminal 2: waits for the existing ready backend, opens isolated Flutter debug
.\scripts\run-petugas-test-flutter.ps1
```

Wait for Terminal 1 to print `Petugas TEST backend ready` before Terminal 2.
Terminal 2 provides the Flutter console, including hot reload/quit. Closing its
Flutter app leaves the test backend ready for another Flutter launch. Terminal 1
Ctrl+C requests testing cleanup; closing a terminal forcibly may bypass finally,
so use STOP below if needed. The supervisor still expires after 30 minutes.
`run-petugas-test-backend.ps1 -ReadyOnly` prepares the backend and returns for
automation. No normal application process or normal database is started by these
commands. The backend terminal prints readiness, not the JWT or private session.

## One-command Windows launcher (alternative)

From the repository root in PowerShell (Go and Flutter must be in PATH):

```powershell
.\scripts\start-petugas-manual-test.ps1
# Later, in another PowerShell terminal in this checkout:
.\scripts\stop-petugas-manual-test.ps1
```

START discovers PostgreSQL binaries through PATH, then
`D:\Program Files\PostgreSQL\bin` or `C:\Program Files\PostgreSQL\18\bin`.
Use `-PostgresBin 'X:\path\to\bin'` for another installation. No installation,
service change or normal backend .env loading is performed by the launcher.
An occupied 55439 causes a safe refusal. PostgreSQL on 5432 is untouched.

When no healthy session exists, START creates `notaris-petugas-launcher-<guid>` under Windows TEMP,
initializes a fresh trust-authenticated loopback-only cluster on 55439, verifies
`SELECT 1`, then starts the isolated Go fixture and waits for its session file.
The debug Flutter target receives only that path and explicit sync opt-in.
The fixture applies migrations, bootstrap and publication in its own random
schema; it never targets the development database. Local programs can access
the temporary trust cluster: use only on a trusted development machine.

A detached hidden PowerShell supervisor owns the session. It records process
IDs plus creation times in state.json and monitors Go and Flutter. START returning
`Ready` means the harness is ready and the Flutter command was launched; the
first Windows build can still take minutes. Inspect flutter.log / flutter.log.err
under the printed session directory for compiler failures. No JWT is printed.
Do not share session.json or logs containing private session paths.

Session expiry (30 minutes) or STOP triggers cleanup. STOP
first closes only owned Flutter windows, signals Go via harness.stop and waits
for deferred schema cleanup, then stops only the recorded PostgreSQL data
directory. A stuck owned process tree may be terminated after its grace period.
Data directories, test SQLite, session files and logs are retained. No directory
is deleted. The testing cluster is unavailable after STOP. Run START for a fresh
session/profile; credentials from an expired session are not reused.

For diagnostics use START `-BackendOnly`. STOP defaults to the latest session
from this checkout, or accepts `-SessionRoot '<printed session directory>'`.
Missing/reused process IDs are checked before targeting processes. A stop timeout
requires log inspection; do not stop PostgreSQL by process name. Script syntax
and guard tests: `& .\scripts\test-petugas-manual-launcher.ps1`.

## Manual terminals (alternative)

1. Provision a NEW temporary PostgreSQL cluster as documented in
   PETUGAS_CONTROLLED_E2E.md. Keep it on 127.0.0.1:55439. Do not use .env or an
   active development/production database. Keep this cluster running for testing.
2. In backend-notaris-go, set the explicit test DSN, then start the manual harness:

```powershell
$env:NOTARIS_SYNC_TEST_DSN='host=127.0.0.1 port=55439 user=notaris_test dbname=postgres sslmode=disable'
$env:NOTARIS_FLUTTER_E2E='1'
$env:NOTARIS_MANUAL_DESKTOP='1'
go test -v -count=1 -timeout 35m -run TestPetugasSyncHTTPPostgres ./routes
```

The existing test harness creates one random test schema, applies migrations in
order, bootstraps a legacy Petugas and starts the real publisher. It exposes the
real loopback HTTP router/JWT/permission stack for 30 minutes. A harness-only
authenticated Petugas testing/status route proves its nonce; no production
admin endpoint is installed. It prints MANUAL_SESSION_FILE=<temporary path>.
The file contains an ephemeral JWT: never paste/share its contents or commit it.
No normal username/password is needed; the debug target uses this test session.

3. In a SECOND terminal under frontend_notaris, set the printed file path and run:

```powershell
$env:NOTARIS_MANUAL_SESSION='<path printed by the running Go harness>'
flutter run -d windows --debug -t lib/petugas_manual_main.dart --dart-define=PETUGAS_MANUAL_SYNC=true
```

The backend URL comes only from that harness file, must be loopback, and is
verified with its nonce before opening any database. The file must reside under
the OS temp directory in petugas-manual-*; SQLite is always petugas-manual.sqlite
beside it. API_BASE_URL and the daily app database are not used by this target.
The same AppShell/header/sidebar/footer and Petugas page are used directly,
without AuthStartupGate's automatic session sync. Only the Petugas menu is granted
in the test session. Missing/expired harness configuration stops startup safely.

4. Open Master > Petugas. Manual sync is initially disabled. Click Siapkan fixture
   and explicitly confirm the controlled manifest pair: local fixture UUID ->
   server gender ID 2. The catalog must contain that active server row. This is
   an operator confirmation for fixture data only, not name/ID auto-matching.
   On an empty test profile, preparation creates one Manual E2E Petugas with
   manual@e2e.invalid and confirms ONLY that new row as local-only. Existing rows
   are never bulk-classified. user_id is NULL; adding one requires server-scoped
   provenance through the existing resolver, not guessing a local user integer.
5. Click Sync Petugas manual. It pushes dirty reconciled records then pulls;
   the legacy server fixture should appear and the status become success. Edit
   the dedicated local fixture and retry to inspect changed row versions. Existing
   pagination remains 10 rows/page with horizontal/vertical scroll. New records
   created using Tambah remain unclassified and intentionally block sync until
   explicit reconciliation; no large reconciliation/conflict UI is provided.

Statuses are idle, syncing, success, pending, blocked and failed. Network/timeout
keeps the stable pending mutation for retry. Invalid references, ambiguous/dev
records, 409 conflicts and 410 full-resync blocks retain local data; resolve using
the repository foundation, not raw SQL/cursor resets. Do not reset SQLite to make
the status green. Full-resync recovery remains unavailable.

Closing Flutter disables this path. Closing/stopping the harness stops the worker
and test server; let it finish for schema cleanup, then stop only the temporary
PostgreSQL cluster using pg_ctl as in the provisioning guide. A hard interrupt
may leave the generated schema in that disposable cluster. SQLite/session files
are retained for inspection; do not reuse credentials after the harness expires.
Each new harness session gets a new directory/profile. No user database is deleted.

## State locking and recovery

START, STOP and Flutter attachment use one per-user named Windows mutex for port
55439, including across checkouts. Concurrent START waits then reuses the same
healthy supervisor/Go session instead of provisioning a second cluster. A session
from another checkout is refused until stopped from that checkout. A busy port
with no verified owned session is refused, never killed.
Short per-session mutex sections protect Flutter attachment versus supervisor
expiry/cleanup. Cleanup marks the session Stopping before releasing that lock,
so a late attachment cannot be lost by a stale supervisor snapshot.

JSON reads use FileShare.ReadWrite/Delete plus at most 60 attempts (50ms retry
delay). Each write uses a unique temporary file, closes it, then atomically
replaces/renames; replacement retries transient sharing violations. Readers see
one complete old/new snapshot. A sustained external exclusive lock produces a
bounded actionable error; active state is never removed. The pointer uses the
same mechanism. No security software exclusions are installed.

For stale state, START requests graceful cleanup first. Process IDs are checked
against recorded creation times; PostgreSQL postmaster.pid must match the exact
temporary data directory and port, binary path and process start time before
recovery can stop it. A mismatch refuses cleanup. Logs/SQLite remain available.
The reported previous file-lock holder cannot be inferred from stale state;
tests reproduce the sharing violation but do not attribute it to antivirus or
a particular historical launcher process.

```powershell
.\scripts\test-petugas-manual-launcher.ps1  # parser, exclusive lock, retry, ownership
.\scripts\test-petugas-manual-lifecycle.ps1 # live isolated concurrent START/STOP
```

The live test requires port 55439 free or a disposable launcher session from this
checkout. It intentionally stops that test session. Never run it during manual
work you want to keep open. The normal Go/Flutter entry points and production
sync coordinator are not invoked or changed by these checks.

Automated widget/provider tests cover gating/status/layout. Existing E2E verifies
the core data path. Neither proves interactive Windows Desktop testing succeeded:
that checklist is for the human operator after this checkpoint. Windows Flutter
build tooling must be installed; no system toolchain is installed automatically.
