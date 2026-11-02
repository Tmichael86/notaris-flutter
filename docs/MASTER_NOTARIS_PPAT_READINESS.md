# Master Pekerjaan Notaris/PPAT readiness

Date2026-11-02; branch feature/pemohon-cloud-sync. No fixture reprovisioning,
permanent database write, grant, cloud sync, publisher or shell permission bypass.

## Confirmed access cause

devfixture.Build originally contains six sidebar definitions ending with
pekerjaan_notaris and grants each to group11. It omits pekerjaan_ppat entirely.
Read-only inspection of127.0.0.1:5432/notarisdev confirms exactly those six menus
and six group11 access rows. Marker NOTARISDEV SYNTHETIC v1, group11 Fixture
Operators and fixture.operator/user2001 identify the development fixture.
Evidence: .local/masters-readiness-20261102/preflight.json and preflight SQL/logs.

The real auth/session sidebar-access response is based on database sidebar/access
rows. AppShell's existing masterMenus includes both masters, and its name/read
permission check hides PPAT when the session lacks an allowed sidebar. Its switch
already routes Pekerjaan PPAT to PekerjaanPPATDesktopScreen. Therefore this is a
fixture permission omission, not an absent screen or a Flutter routing defect.
Backend code-based permission lookup also joins sidebar/access and requires an
active non-placeholder route. No auth/menu checks were weakened.

Future fixture generation now APPENDS pekerjaan_ppat/Pekerjaan PPAT at index7,
route/pekerjaan_ppat, with the same read/create/update/delete flags as Notaris,
only for group11. Existing menu indices1-6 and other fixture identities remain
unchanged. This source change does not populate the existing development DB.

## Local functionality audit

Both masters already have repository-backed Drift create/read/update/soft-delete
for aggregates: prices by category, ETA, processes and attributes. Writes are
transactional. Updates validate child ownership/preserve existing child IDs;
removals soft-delete rather than recycle IDs. Forms enforce names, nonzero prices,
unique categories, ETA and process name/detail. Search by name and pagination10
already exist. Do not rebuild these flows or infer cloud readiness from local CRUD.

Proven gaps fixed:

- Repository aggregate create/update now checks each category exists and is active,
  not deleted, inside the same transaction for BOTH masters. Invalid/missing
  categories fail before aggregate writes. No schema change.
- PPAT used an unbounded Padding/Column under the shell scroll view, unlike
  Notaris' MasterDataViewport. It now reuses that viewport and
  MasterDataTableViewport for bounded height and single scrollbar rails. Search
  uses Expanded instead of infinity width inside Row; header text can wrap.
  Existing Notaris screen and shared shell layout remain unchanged.

TransactionRepository persists job/category/price/process snapshots to protect
history. Master aggregate updates/soft deletion do not rewrite transaction
snapshots or relocate IDs/UUIDs. Actual existing SQLite transaction data was not
opened or changed in this audit. Transaction editing/aggregate cloud integration
remains a separate checkpoint. Standard master CRUD remains LOCAL in UI Smoke;
changing test masters can create dirty rows for a future approved sync stage.

## Existing notarisdev permission proposal — awaiting separate approval

Prepared file:
`backend-notaris-go/migration_proposals/notarisdev_fixture_ppat_permission.sql`.
It is NOT a schema migration and has NOT been executed. Source review/Go fixture
tests establish generator intent; SQL apply/idempotency has not been claimed as
a completed database acceptance run.

Expected writes after approval: insert one active PPAT sidebar if absent, then
one CRUD access row for group11 if absent, using existing serial defaults.
No access rows for any other group are inserted/updated/deleted. It does not call
ReplaceForGroup, regenerate fixtures or grant SQL privileges. Existing differing
PPAT definitions/revoked flags/duplicates fail for review instead of being widened
silently. Compatible existing rows make repeat application a no-op.

Required preflight immediately before apply: target/marker, exact group/account,
current sidebar/access snapshot, no ambiguous PPAT definition, serial state/defaults
and least necessary maintenance-role privileges. The proposal locks only the two
permission tables, checks sequences are not behind max IDs and stops rather than
resetting them. Sequence values may advance on an aborted insert; gaps are not
repaired automatically. Keep baseline snapshots and backup/recovery evidence.
Current preflight found serials public.sidebar_id_seq/sidebar_akses_id_seq; their
live values and apply privileges still require fresh verification before approval.

After separate explicit approval, a reviewed maintenance connection can execute:

```powershell
# Connection must explicitly target127.0.0.1:5432/notarisdev; no credentials in CLI.
psql -X -w -v ON_ERROR_STOP=1 -v approved_target=127.0.0.1:5432/notarisdev `
  -f backend-notaris-go/migration_proposals/notarisdev_fixture_ppat_permission.sql
```

Without the approved_target parameter, the script exits before writing. The exact
target/fixture checks run again in SQL. Postcheck: ordered COMMIT/success marker,
one matching PPAT sidebar and group11 CRUD row, old permissions/business data
unchanged. On error or ambiguous commit stop for read-only investigation; no
automatic retry/restore, sequence repair or permission expansion.

## Flutter acceptance after approved permission apply

Start the existing development backend (publisher OFF) and Flutter via
scripts/run-notarisdev-flutter.ps1 -UiSmoke. Logout/login or restart ONLINE so
/auth/me/sidebar-access refreshes permissions; an old offline cached session is
not proof of the new permission. Verify both Master menu entries, create a local
test aggregate with a valid active category, restart/read it, edit preserving
relations, search/paginate and soft-delete the test entry. UI Smoke prohibits
network mutation; no new cloud synchronization is introduced. Recheck Pemohon20,
Petugas4 and shared header/sidebar/footer. Do not use the daily launcher/database.

## Tests

Go devfixture tests pass, including both menu routes, one scoped grant each and
CRUD flags. Flutter analyze clean. Focused suite67 passed: both existing aggregate
CRUD/ownership/soft-delete suites plus new missing/inactive category checks;
PPAT joins the Master Data viewport matrix; actual AppShell allow/deny read tests
show that the existing permission check remains authoritative. Full regression
passed:353 tests,0 failed,3 live opt-ins skipped (one full run).
All Flutter writes use disposable SQLite.
