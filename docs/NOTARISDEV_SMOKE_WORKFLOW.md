# Synthetic notarisdev smoke workflow

This checkpoint does **not** create permanent notarisdev. First creation requires
explicit owner confirmation plus the provisioning prompt. No pending Cloud Sync
migration proposal is executed. Source schema archive is read, never source rows.

## What is implemented

`internal/devfixture.Build` generates a fixed smoke-v1 business graph. Its SQL is
deterministic given a supplied test-owned bcrypt hash; passwords, bcrypt salt,
database-role secret, JWT signing secret and generation identifier are intentionally
fresh per provisioning. No secret is taken from source application users. A
provisioning administrator authenticates separately to PostgreSQL; those admin
credentials are not copied to the app or fixture. This is not a source-data clone.

61 rows in 19 populated tables; all 38 original public tables restored:

| Rows | Tables |
| --- | --- |
| 1 each | groups, users, konfigurasi_umum |
| 2 | jenis_kelamin |
| 4 each | petugas, transaksi, transaksi_detail_proses, transaksi_riwayat_pembayaran |
| 20 | pemohon |
| 6 each | sidebar, sidebar_akses |
| 1 each | pekerjaan_jenis, pekerjaan_kategori, pengeluaran_jenis, pembayaran_jenis, transaksi_status, pekerjaan_notaris, pekerjaan_notaris_proses, pekerjaan_notaris_harga |

All business transactions use a synthetic Notaris job, valid parent/process links,
100000 total and 25000 installment. PPAT, archive, error/session/token tables are
present but empty. This is a small Notaris smoke profile, not volume/PPAT coverage.
No NIK, phone, real address, original document or original auth hash is imported.
Synthetic emails use example.invalid, document labels FIXTURE-0001..0004. UUIDs in
existing UUID-capable tables are explicit fixture-namespace constants, not a global
integer-ID backfill algorithm. Petugas has no UUID until its migration is approved.

`Validate` checks the graph before SQL emission. Database validation uses a readonly
repeatable snapshot, checks 20 declared smoke relationship edges, exact row counts,
synthetic marker and empty auth/archive tables. It covers the generated graph, not
every historical business relationship in notarislokal. No FK constraints are added.
Sequences are advanced to imported max IDs so ordinary inserts do not collide.

## Preflight (no provisioning)

From the repository root:

```powershell
.\scripts\provision-notarisdev.ps1
```

Defaults: 127.0.0.1:5432/notarisdev; administrative connection is to postgres, never
notarislokal. If no process PGPASSWORD is provided, an interactive local administrator
credential prompt is shown. Do not paste admin credentials into chat or Git.
Checks target absence, required provisioning privileges, reviewed archive SHA256,
and no TABLE DATA/SEQUENCE SET archive entries. Existing target OR private local
development config/profile causes refusal. Read-only preflight performs no CREATE.

Default archive:
`.local/notarisdev-review-20261030-081705-1424d2b5/source-schema.dump` with its
`archive-sha256.json`. Optional `-Archive` and `-PostgresBin` support another reviewed
local installation. The archive stays outside Git. Do not substitute a full dump.

## Apply, only after explicit approval

```powershell
.\scripts\provision-notarisdev.ps1 -Apply -ConfirmTarget '127.0.0.1:5432/notarisdev'
```

The script ALSO requires typing `CREATE notarisdev` in its prompt. It creates one
database using template0, restores schema with no --clean/--create and one restore
transaction, imports fixture in one transaction, validates, then creates a new
non-owner/non-superuser application role and target-only table/sequence grants.
No ALTER of source, no source role/password copying, no automatic migration or
bootstrap. Existing roles are not overwritten. Creation races fail at CREATE DATABASE.
The new application role may inherit PostgreSQL PUBLIC connection privileges on
other databases, but this script grants no source object privileges and launchers
fix the DB target. It never revokes/changes source privileges.

New local artifacts (ignored by Git):

- `.local/notarisdev-<generation>/fixture.sql`, private grant logs, manifest and
  `login.private.json` containing the new fixture.operator password.
- `backend-notaris-go/.env.notarisdev` containing NEW app DB/JWT secrets.
- `.local/notarisdev-profile.json`: non-secret generation/database manifest, written
  only after successful provisioning. No test JWT or harness session file is needed.

Keep private files on a trusted local development machine; never share them or add
them to Git. Test operator password is viewed from login.private.json by the local
user and entered into the ordinary login screen, not auto-injected into Flutter.

## Two ordinary development terminals

After approved successful provisioning:

```powershell
# Terminal 1, repository root
.\scripts\run-notarisdev-backend.ps1
# Terminal 2, repository root
.\scripts\run-notarisdev-flutter.ps1
```

Backend wraps `go run ./cmd`, verifies the target marker read-only using the new app
credentials, fixes database notarisdev/5432, refuses postgres as app role, uses HTTP
8081 and publisher OFF. Flutter launches a debug-only normal MyApp/AuthStartupGate,
normal JWT login, menu/permission flow and existing session sync for other masters.
DEV notarisdev banner distinguishes the mode. Petugas is not added to the global
coordinator; no production/manual Petugas flag is enabled.

SQLite is `<application-support>/notarisdev/<generation>/offline.sqlite`, never
Documents/notaris_offline.sqlite. Secure-storage auth key is namespaced by generation.
No old DB, journal, cursor, mappings or cached token is copied. Normal main.dart and
its auth key remain unchanged. Rebuild a server generation only through a reviewed
new profile; do not reset the daily database. Missing provisioning manifest blocks
the launcher. Missing/invalid generation blocks the development entry point before
opening any database. Normal development commands remain separate and are not a
safe substitute for these launchers when testing notarisdev.

## Known integration limits

The schema archive lacks Petugas uuid/row_version/deleted_at and all sync foundation
tables. Current Go Petugas GET/writer code expects them. Therefore **server Petugas
CRUD/push/pull are blocked until separately approved Cloud Sync migration**. Do not
run the proposal to make this smoke pass. Local Petugas CRUD and transaction creation
can be tested offline; SQLite does not automatically import these server transaction
fixtures or all Petugas. Explicit reconciliation is still required for future sync.

The legacy transaction Go sync contract also differs from the full server required
columns and Drift job graph; no transaction E2E readiness is claimed. The test proves
ordinary login/JWT/permission and category read, not every application endpoint.
PPAT coverage, five devices, retention/410 recovery and manual interactive testing
remain separate checkpoints.

## Isolated verification and recovery

```powershell
.\scripts\test-notarisdev-provision.ps1
```

Creates a fresh cluster in Windows TEMP on loopback 55441, verifies SHOW data_directory,
uses a strictly named notaris_fixture_test_<guid> target, exercises dry-run, restore,
validator, login/permission, broken-reference rejection, existing-target refusal and
nonempty fixture reload refusal. Stops only its owned cluster in finally, retains
logs/data for review. No target/role/database is dropped automatically. Temporary
testing can be repeated with a new cluster. This script never connects to port 5432.

On failed permanent provisioning: stop access, preserve logs/target and inspect the
completed phase; subsequent attempts refuse an existing target. Restore failure is
transactional; fixture failure rolls back row inserts (sequence changes are not a
promise of full transactional rollback). No destructive cleanup is built in. Removal
of an explicitly verified disposable target/role requires a separate owner-approved
operation. Do not “recover” by dropping tables, applying Cloud Sync or editing source.

## Actual validation for this checkpoint

- Two isolated provisioning runs passed on PostgreSQL 18.6, schema 38 tables,
  61 synthetic rows, 20 graph edges; no FK additions or Cloud Sync migration.
- Go generator determinism/broken parent/duplicate-PK tests and actual Gin
  controller login/JWT/permission/category smoke passed; anonymous read rejected.
- Full Go suite exited 0 without production/development DSNs. Existing PostgreSQL
  sync tests and opt-in synthetic HTTP test skip in that run without DSNs; synthetic
  HTTP test was explicitly executed separately against the temporary fixture.
- Flutter analyzer exit 0; full suite 250 passed / 1 skipped (opt-in live E2E),
  exit 0; four profile/auth/SQLite tests also passed explicitly. The new SQLite
  file test preserves dirty normal rows and cursor 17 while dev starts empty; auth
  cache tests preserve the daily key and test backward-compatible default key.
- Source structural fingerprint matches previous archive review; read-only legacy
  aggregate remains 7058 detail rows. This does not exclude concurrent changes by
  other apps, but none of the provisioning/generation code connects to the source.
- No permanent notarisdev created. No interactive Flutter UI success claimed.
- Flutter Windows debug build of lib/notaris_dev_main.dart exited 0; the binary
  was built only, not launched for interactive verification.

The profile/launcher is implemented, but readiness for the whole normal app must
not be confused with approval of pending Petugas schema changes.
