# Isolated Monitoring UI — Windows acceptance

This entry enables manual Transaction sync only for a reviewed **disposable**
SQLite/backend configuration. The normal application and
`scripts/run-notarisdev-flutter.ps1 -UiSmoke` do not enable these controls.
No automatic/global synchronization or background publication is started.

## Current validation

- 82 focused Flutter tests passed (service, UI interactions, Log/Monitoring,
  permission/profile/Smoke, startup/resume/global guards, 409/410 and restart).
- Full Flutter regression: 422 passed, 7 opt-in skipped; analyzer clean.
- Disposable HTTP UI E2E explicitly passed: selected Notaris and PPAT uploads,
  bounded manual publication, second-profile shared pull/replay, stable UUIDs,
  server numbers, snapshots/process/payment identity, restart, cursor and FK/integrity.
- Source-only setup code lives in tests; no generated profiles, databases,
  credentials or execution receipts belong in Git.

## Prepare before interactive acceptance

The automated E2E cleans up its devices and temporary server. It does **not** leave
an interactive environment running. Prepare/review these fresh prerequisites first:

1. An owned PostgreSQL disposable instance on port 55400–55999 and an authenticated
   Go backend on a separate loopback HTTP port (not normal ports 8080/8081).
   Existing test setup is in `backend-notaris-go/routes/transaction_cloud_test.go`;
   do not invoke a permanent migration or restore runner.
2. An active fixture login with `transaksi` permissions; account/group values must
   come from its authenticated server session.
3. Two NEW file-backed SQLite devices, `a.sqlite` and `b.sqlite`, in a system-temp
   directory named `transaction_manual_*`. Seed only verified cloud dependencies
   (Pemohon, Petugas mapping/journal, both Master identities/prices/categories).
   Use existing repositories/reference resolvers; never copy an existing dirty,
   daily or development profile or guess identities from names/amounts/IDs.
4. New local synthetic Transaction records on Device A and no Transaction records
   on Device B. Feed/reference scopes must match the profile's exact account,
   deployment, device, generation and canonical path. The test setup source
   `test/support/transaction_ui_test_support.dart` illustrates the isolated data shape.

Keep a reviewed manifest beside each SQLite file. It contains metadata only,
**never a password or JWT**. Example fields (replace with verified values):

```json
{
  "sqlitePath": "C:\\...\\Temp\\transaction_manual_acceptance_NEW\\a.sqlite",
  "baseUrl": "http://127.0.0.1:18081/api/v1",
  "databaseTarget": "127.0.0.1:55452/notaris_publish_test_ui_acceptance",
  "deployment": "reviewed-disposable-deployment",
  "device": "device-a",
  "generation": "NEW_REVIEWED_GENERATION",
  "accountId": 1,
  "groupId": 1
}
```

Create a separate `b.json` for Device B with its own path/device/scope. These are
examples, not credentials, proof of identity or pre-provisioned profiles.

## Launch after those prerequisites are verified

From `frontend_notaris`, using the actual absolute manifest path:

```powershell
flutter run -d windows -t lib/transaction_monitor_isolated_main.dart `
  --dart-define="TRANSACTION_MONITOR_PROFILE=$env:TEMP\transaction_manual_acceptance_NEW\a.json"
```

The entry is Windows debug-only, checks the manifest location, validates the
canonical disposable file before opening SQLite, and rechecks persisted scope.
Database, HTTP target and auth cache are bound to this isolated configuration.
A missing/invalid manifest fails closed. The entry never selects a normal profile.

1. Confirm banner `DISPOSABLE MANUAL SYNC`, then login to the fixture account.
2. Open System → Monitoring Sinkronisasi through the existing desktop shell.
3. Select Transaksi Notaris / Upload, choose an actual local record, inspect its
   number/type/UUID/dirty-pending state, and confirm. Repeat for PPAT. Cancel must
   send nothing; double-click must not duplicate an operation.
4. An upload ACK is not publication confirmation: expect attention/yellow while
   its event is unobserved. Have the operator publish only the synthetic events
   using the existing bounded allowlisted publisher **on the disposable target**.
   There is no UI/background publisher.
5. Launch Device B with `b.json`. Select Transaksi (feed gabungan) / Download.
   This consumes both domains in order with one cursor and never uploads records.
6. Verify Log/Monitoring evidence, payment/snapshot/number identity, replay without
   duplicates, then restart with the same manifest and check persisted cursor/logs.
   Permission/profile/409/410 errors must preserve dirty state and show a safe
   explanation; do not force-reset or automatically resolve a conflict.

Automatic/session/global synchronization remains blocked throughout this entry;
its regular HTTP client allows reads/login only. Business writes use the guarded
manual Transaction service. Other modes retain their existing behavior.

## Reproduce automated real HTTP acceptance

With an already-owned disposable PostgreSQL instance running, from backend-notaris-go:

```powershell
$env:NOTARIS_SYNC_TEST_DSN='host=127.0.0.1 port=55452 dbname=notaris_transaction_sim user=postgres sslmode=disable'
$env:NOTARIS_TRANSACTION_E2E='1'
go test ./routes -run '^TestTransactionMonitoringUIHTTPPostgres$' -count=1 -v
```

This uses two fresh temporary SQLite files and authenticates against the real Go
HTTP fixture. It is not an instruction to write on permanent notarisdev.
