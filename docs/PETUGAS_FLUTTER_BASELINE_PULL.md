# Petugas Flutter baseline pull — preparation checkpoint

Scope: server→Flutter import of four published version-1 Petugas baseline events
through cursor4, with fixture validation and a separate controlled live GET test.
The normal Petugas SyncCoordinator remains OFF. No user SQLite file was opened.
The regular suite uses fixtures; the explicit live test below uses server reads
and a fresh owned SQLite only, without publisher/bootstrap/drain/schema/grants.

Server evidence is in `.local/petugas-drain-execution-20261102/REPORT.md`:
four published events, cursor0→2→4, latest cursor4 empty. Initial preparation used
in-process fixtures. The subsequent opt-in live checkpoint demonstrated real
Flutter/Dart HTTP GET → production baseline service → disposable SQLite, including
restart/replay. This remains separate from interactive app/coordinator activation.

## Audit of existing components

| Component | Existing contract and resulting boundary |
|---|---|
| Drift schema | Version13 remains unchanged. V10 adds identity metadata/unique active cloud-UUID and server-ID indexes; V11 feed/journal; V12 scoped gender/user provenance; V13 persistent conflicts. Existing migrations are transactional and preserve local identities. No new schema migration is introduced. |
| Petugas DAO | Auto-increment local PK and immutable local UUID are independent of server ID/UUID. Keep them, together with all transaction references/snapshots. |
| Identity map | `local_uuid` is the map PK; `cloud_uuid`/`server_id` are separate, uniquely mapped when active. Operator reconciliation supplies provenance. Neither matching names/email nor matching numeric IDs proves identity. |
| References | Gender server IDs require explicit mapping to local gender UUID/PK; user IDs require authenticated server provenance. Pemohon fixture reference reconciliation is not automatically Petugas reference evidence. |
| Cursor | `petugas_sync_feed` has one singleton owner scope per physical SQLite. The controlled scope includes API deployment, notarisdev generation, account, stable device ID and canonical DB path. Another account/device/profile is refused rather than silently sharing/resetting its cursor. |
| Atomicity | Page rows, mappings, row-version journal and cursor commit together. A failed page rolls back; already committed pages remain a durable prefix. |
| Normal coordinator | `providers/pekerjaan_provider.dart` still syncs category/expense/Pemohon, including pushes. It does not invoke Petugas. Startup/resume/global sync and UI shell remain unchanged. |
| UI | Shared desktop shell, sidebar/header/footer, Master Data screens and normal manual-sync buttons are unchanged. |

`transaksis.petugas_id` and `petugas_uuid` are currently logical references/snapshots,
not declared SQLite FOREIGN KEY constraints. Both are preserved exactly. Actual
gender/identity-map references are also tested with SQLite foreign_keys=ON and
foreign_key_check. This checkpoint does not retrofit FK constraints onto legacy
user data or enable FK enforcement globally.

## Focused changes

- `PetugasBaselinePull` uses the existing local sync repository and authenticated
  API contract. It exposes pull only; its API capability rejects push. Bearer
  session/account/origin are checked before and after HTTP and inside page apply.
- A `PetugasBaselinePlan` requires four distinct authenticated baseline identities
  and sequences1–4, each with an explicit existing-local-UUID selection or reviewed
  server-only decision and evidence. The complete pre-existing local UUID inventory
  must have been reviewed. Unreviewed rows block before HTTP.
- Existing clean selected rows are linked inside the page transaction without
  initializing their journal version prematurely. Payload application then writes
  the version and cursor. Dirty/deleted/development identities and conflicting
  mappings stop for review; they are never cleaned or reassigned silently.
- Previously established version metadata is checked against the canonical payload
  before skipping a baseline event. An old push-reconciliation acknowledgement
  without an applied payload cannot make stale local data look successfully pulled.
- Newly materialized rows use fresh local UUIDs/PKs, never server numeric IDs.
  Repeat/restart uses their persisted identity map and journal, preventing duplicates.
- The existing pull loop now rejects publication gaps, malformed required payloads,
  invalid references/dates, oversized pages and cursor races after HTTP. An explicit
  throughCursor4 bound keeps this checkpoint from importing later events.
- `AppDatabase.forIsolatedPetugasPull` accepts only an explicit canonical
  `.../notarisdev/<32-hex-generation>/offline.sqlite` file with an existing profile
  directory. It rejects the daily file and links/junctions before Drift opens it,
  while allowing legitimate Windows short-path aliases. A labelled DB handle and
  reference resolver from that exact DB are required by the baseline service.
- `notaris_dev_main.dart` uses that file factory for its same isolated profile; it
  does not configure or invoke baseline pull. Normal `appDatabaseProvider` still
  uses its existing daily path. No fallback opens that file for this service.
- `petugasBaselinePullConfigurationProvider` defaults to null. Reading the lazy
  baseline provider in the normal app returns null without opening DB/auth or
  starting any task. Approved future callers must inject an explicit configuration
  and call pull manually; it is not wired to startup, resume, timers or global sync.

## Error and recovery behavior

401/403/409 propagate explicit typed failures and preserve local payloads/cursor.
An initial singleton scope binding at cursor0 may remain, intentionally preventing
another account from taking ownership. 409 on pull does not invent a push conflict
or resend a mutation. Existing push conflict archives remain unchanged.

410 persists `full_resync_required` and blocks future pulls, including after restart.
No local rows, pending mutations or cursor are deleted/reset. Network interruption
after page1 keeps cursor2 and resumes there; a failure before cursor commit rolls
that whole page back. Wrong account/origin/device/profile, unknown identities,
missing reference evidence and dirty local data require review. No automatic
merge, overwrite, cursor rewind, scope reset, remote write or full-resync fallback.

## Safe execution now: disposable fixtures

From `frontend_notaris`:

```powershell
# No credentials, live server or existing application DB required.
flutter test --no-pub test/repositories/petugas_baseline_pull_test.dart
flutter analyze --no-pub
flutter test --no-pub
```

Leave NOTARIS_E2E_URL/NOTARIS_E2E_TOKEN unset and NOTARIS_PEMOHON_DEV_SMOKE off.
The baseline tests create a unique TEMP directory, dedicated labelled profile and
SQLite file; only those test-owned files are deleted afterwards. Dio fixtures
accept GET only. They exercise the real Drift schema, identity/reference mapping,
authenticated adapter and provider boundary. Existing tests also cover Pemohon,
schema migrations, conflicts, manual sync and desktop layouts.

Evidence includes empty-db import of four unique Petugas, explicit reuse of four
existing rows with intentionally colliding/reversed server/local IDs, unchanged
transaction references, cursor4 replay, reopened-file persistence, injected failure
at cursor commit, restart after partial pagination, scope/account/origin rejection,
401/403/409/410, malformed/gapped pages, missing references, stale-version metadata,
cursor race, baseline upper bound, and default-disabled/explicit-provider behavior.
Exact final results/logs are retained under `.local/petugas-flutter-baseline-20261102/`.

Validated on 2 November 2026: `flutter analyze --no-pub` reports no issues;
full `flutter test --no-pub` reports **312 passed, 0 failed, 3 live-E2E skips**.
This includes 19 baseline-boundary tests and 29 Pemohon repository/API/reference
tests. The skipped cases are the independently opted-in Petugas mutation roundtrip,
Pemohon live test and new GET-only baseline test. No server is contacted by the
default suite. The new GET-only live test passed separately with explicit opt-in.

## Controlled live GET test with a new disposable profile

`test/e2e/petugas_baseline_get_live_test.dart` uses the actual IOHttpClientAdapter,
not a mock, and production PetugasBaselinePull, identity/reference repositories
and Drift storage. It never starts the Flutter UI or normal SyncCoordinator.

Required preflight/runner inputs (not supplied automatically by the test):

1. Verify the local provisioning manifest, exact notarisdev identity/marker, four
   published events, cursor4, no pending mutations and stable legacy fingerprints.
   Keep before/after PostgreSQL snapshots and verify maintenance before startup.
2. Create a fresh workspace-owned `.local/petugas-baseline-live-<unique-id>` audit
   directory and nonsecret `ownership.json`: kind=petugas-baseline-get-live-v1,
   exact target, verified generation/account/group, a unique device_id,
   postgres_preflight_verified=true, and expected_events from the verified outbox
   (petugas_id/uuid/sequences). That flag must represent actual validation.
3. Verify the real local fixture credential through the existing AuthService.Login
   (active user/group and bcrypt) under a read-only PostgreSQL connection. Use its
   returned JWT in memory; do not invent claims, print credentials/tokens, save a
   token file, or perform an HTTP login POST. Stop if credentials/provenance fail.
4. Start the existing normal Go entry point with explicit reviewed development
   config, PETUGAS_PUBLISHER_ENABLED=false and PGOPTIONS enforcing
   default_transaction_read_only=on. Own/bound its process lifetime. No normal
   Flutter startup, worker, bootstrap or migration is invoked.
5. In that controlled child environment only, set NOTARIS_PETUGAS_BASELINE_LIVE=1,
   NOTARIS_BASELINE_LIVE_ROOT to the owned audit directory and
   NOTARIS_BASELINE_LIVE_TOKEN to the credential-verified JWT, then run:

```powershell
flutter test --no-pub --reporter expanded test/e2e/petugas_baseline_get_live_test.dart
```

The test refuses an existing profile/SQLite file. It discovers both baseline pages
and required references through authenticated GET, checks deployment identities,
creates local gender UUIDs from explicit active catalog selections, verifies each
non-null server user reference, and records four server-only decisions after an
empty local inventory check. NULL user_id is preserved, not guessed or replaced
with the authenticated account. Only needed gender/user references are installed.

The production service then imports pages0→2→4 into a fresh labelled SQLite file,
closes/reopens it, replays cursor4, and checks unique maps/independent local PKs,
persisted cursor, integrity_check and foreign_key_check. Requests are restricted
to GET on the exact loopback API origin; logs retain request metadata without
Authorization headers. SQLite and sanitized diagnostics remain even on failure.

After completion stop only the owned backend and compare complete business/
journal/counter snapshots plus all72 legacy fingerprints. Preserve the file and
audit material. Do not reset/reuse the same profile for another test run, activate
normal sync, or silently retry existing-file writes after a failure.

Completed live evidence: `.local/petugas-baseline-live-20261102-cf7a632f/` contains
the retained local orchestration, credential-verification adapter using existing
Login, server process/config proof, Dart request trace, SQLite and before/after
server snapshots. Live import=4, local IDs1–4 versus server101–104, cursor0→4,
restart4/replay4 with zero added events, integrity=ok/FK violations0. The actual
payloads required gender11 (mapped to local ID1) and had user_id=NULL. Source
production components, user databases and PostgreSQL state remained unchanged.

## Controlled pull to an existing profile — approval still required

Do not launch the normal application or call its global synchronizeNow merely to
perform this test: its existing initial/Pemohon synchronization can push other
entities. That workflow is unchanged; only the explicitly scoped disposable live
test above contacted notarisdev, using GET and read-only database connections.

After a separate approved target/backup review, the bounded application call is:

```dart
final context = PetugasBaselineContext(
  generation: approvedGeneration,
  accountId: authenticatedSession.userId,
  deviceId: persistedDeviceId,
  databasePath: approvedIsolatedFile.path,
);
final db = AppDatabase.forIsolatedPetugasPull(approvedIsolatedFile);
final references = VerifiedPetugasReferences(db, scope: context.scope);
// Install reviewed gender/user provenance first. No name/ID equality inference.
final plan = PetugasBaselinePlan(
  scope: context.scope,
  reviewedLocalUuids: reviewedInventory,
  selections: fourExplicitSelectionsFromAuthenticatedFeed,
);
await PetugasBaselinePull(
  db: db, dio: authenticatedDio, context: context, plan: plan,
  references: references, session: () => currentOnlineSession,
).pull(limit: 2);
```

The equivalent lazy Riverpod configuration is `PetugasBaselinePullConfiguration`
with the same explicit database/context/plan/references. Existing mappings must be
selected with `PetugasBaselineSelection.existing`; new rows require an evidenced
`serverOnly` choice. Keep the same generation/path/account/device identity across
restart. This is deliberately limited to the four-event baseline, not a general
background Petugas coordinator or later push/update synchronization.

Persistent target location for the normal development profile is
`<applicationSupportDirectory>/notarisdev/<generation>/offline.sqlite`. The normal
daily file remains `<applicationDocumentsDirectory>/notaris_offline.sqlite` and
must not be used. No concrete user file was resolved/opened during this task.

Before touching an existing development file, obtain separate approval specifying
its resolved absolute path, generation/account/device, existing rows/maps/pending
state, schema version and exact identity/reference decisions. Close other writers
and take a verified SQLite backup that handles WAL coherently (clean shutdown or
SQLite backup API), not a live main-file copy alone. Retain row counts, FK/snapshot
and file checksums. Existing older schema versions may run the already-existing
Drift migrations when opened; no new migration was added here.

The approved local effects would include the feed owner/cursor, identity/version
journal and reference evidence, new server-only rows or canonical payload updates
on explicitly selected clean rows. Dirty edits and their transaction references
must be preserved for a separate conflict/reconciliation decision. Full-resync/410,
future events beyond cursor4, background publication, UI activation and push remain
separate checkpoints. No normal persistent pull is authorized by this document.
