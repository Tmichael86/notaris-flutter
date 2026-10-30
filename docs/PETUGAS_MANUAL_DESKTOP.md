# Debug-only Petugas Desktop testing

Production main.dart, global SyncCoordinator and other modules' sync providers
are unchanged. Manual controls default OFF. The only supported manual path is
the separate debug target petugas_manual_main.dart with explicit compile opt-in.
Release/profile builds refuse this target. No application auth secure storage,
daily SQLite file, migrations or bootstrap are opened/run by Flutter startup.

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

Automated widget/provider tests cover gating/status/layout. Existing E2E verifies
the core data path. Neither proves interactive Windows Desktop testing succeeded:
that checklist is for the human operator after this checkpoint. Windows Flutter
build tooling must be installed; no system toolchain is installed automatically.
