# Log Sinkronisasi MVP

Implemented 2026-11-02 ahead of the stated Asana deadline2026-11-07.
This records repository implementation/fixture acceptance, not an Asana task update
or live operational rollout.

## Contract and boundaries

Drift schema14 adds only sync_logs and its newest-first index; migration from13
is transactional and preserves existing data. No generated table model is needed:
the private metadata table uses parameterized Drift SQL, like existing journals.
Each row retains UTC start/end, module, push/pull direction, pending/success/failed,
nullable record count, safe error code/message, operation UUID and attempt UUID.
UI renders timestamps locally and shows the newest500 matches. Histories are not
deleted when retry succeeds. A later attempt of the same module/direction reuses
the operation ID until success; each coordinator run gets a fresh attempt ID.
The unique attempt/module/direction key prevents repeated recording/execution of
the same attempt. Existing coordinator single-flight handles concurrent triggers.

Logging wraps actual active global coordinator stages only: category master,
expense-type master and Pemohon push/pull. It adds no sync scheduling or network
calls. Category/expense push counts are supplied by existing repositories; Pemohon
push count remains unknown (NULL), and pulls count returned records after local
apply completes. Empty push queues produce no success entry; failure during
reference/auth preparation is recorded even with no queued rows. Stages after a
failure are not logged as successful, nor are Petugas or other inactive modules.
Partial failure counts remain unknown; success means that stage completed, not
whole-database or all-device convergence.

Pending initially means operation started without a confirmed completion. A crash
can leave it pending across restart. Offline/timeout/server failures also retain
pending outcome with safe reason and finished timestamp. Other mapped failures
are failed. Old outcomes remain historical even when a new retry succeeds.
No automatic retry is introduced. Logging must persist before network execution;
logging-storage errors stop that run instead of inventing an auditable success.

Sanitization persists only an allowlisted code and fixed explanatory message.
Never persist raw exceptions, Dio request/response, credentials, tokens, personal
payloads or URLs. Existing protocol/entity journals are retained unchanged.

## UI and smoke mode

System → Log Sinkronisasi uses the existing shared shell. Only menu registration
and content routing were added; header/sidebar/footer layout is unchanged. Local
sanitized diagnostics are accessible to signed-in profiles without adding a server
permission or altering business-menu access. Filters: module/status; loading,
empty, safe error and local reload states. Reload does not synchronize anything.
No sample/history backfill is inserted.

Smoke guards return before the log repository/database is resolved by sync, and
HTTP mutation protections remain unchanged. Opening the log page can therefore
show an empty history correctly. This task did not open/migrate daily or existing
development SQLite, contact PostgreSQL, enable Petugas push/publisher/bidirectional
sync, or execute Flutter interactively.

## Verification

- dart format completed; flutter analyze --no-pub: no issues.
- Focused tests: repository success/failure/pending, retry correlation, unique
  attempts, filtering/newest order, sanitized errors, reopen persistence; real
  coordinator integration with fake HTTP verifies reached modules/single-flight;
  UI loading/empty/error; smoke bypass; schema13→14/business UUID/feed preservation.
- Existing migration and smoke-focused run:19 passed; final additional focused
  repository/UI/coordinator run:6 passed (overlapping, not additive totals).
- Full Flutter suite executed once:331 passed,0 failed,3 live opt-in skipped.
  Pemohon and Petugas regression suites are included. All writes use disposable
  fixtures; no testing migration was applied to user databases.
- Logs retained locally under .local/sync-log-mvp.

## Manual development UI

From repository root, backend terminal if login is needed:

```powershell
.\scripts\run-notarisdev-backend.ps1
```

Flutter terminal:

```powershell
.\scripts\run-notarisdev-flutter.ps1 -UiSmoke
```

On FIRST user-driven opening, Drift will upgrade that existing development file
from13 to14 by adding log storage. The implementation agent has NOT performed this
upgrade on it. Keep the intended development profile and appropriate backup; do
not substitute daily main.dart or restore a historical backup automatically.

Login; System → Log Sinkronisasi; check empty state or real previously generated
history, filters and local reload. Click global Sync in smoke mode: it must not
create activity/success or send writes. Petugas4/Pemohon20 remain visible. Do not
disable smoke or seed fake logs merely to populate the screen. Success/failure/
retry histories are verified by disposable tests; a live sync acceptance to
populate the real history is a separate authorized operational checkpoint.
