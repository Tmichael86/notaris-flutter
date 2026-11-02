# Monitoring Sinkronisasi MVP — read-only capability checkpoint

Implemented2026-11-02 ahead of the stated Asana deadline2026-11-14. Manual Windows
acceptance is still pending. No Asana record was changed by this task.

System → Monitoring Sinkronisasi reuses the existing shell and Drift14. No schema
change, migration execution, sync engine, network probe, timer or worker is added.
Snapshot reads run in one local transaction. Log changes invalidate the displayed
snapshot; Refresh is a local read only. Header/sidebar/footer layout and Master Data
are preserved; only menu registration/content routing were added.

## Facts and color precedence

Per module, latest attempt per direction comes from persisted sync_logs, without
the history page's500-row limit. Last attempt and last success are shown separately.
An old failed attempt remains in Log; a successful retry can supersede that outcome
for the same direction. Dirty rows are always checked, even after logged success.
For Petugas, pending UUIDs are the union of dirty records and journal mutations
(no double count); open/held conflicts and blocked feed also contribute.

- Red: latest failed operation, unresolved Petugas conflict or blocked feed.
- Yellow: dirty/pending records or latest deferred operation.
- Green: relevant latest recorded operations succeeded, with no known local
  pending/error. This is NOT a proof of cloud convergence or freshness, nor proof
  that a module with only one recorded direction completed both directions.
- Neutral: no known completed operation/status evidence and no known blocker.

Pending record counts and pending operation counts are separate. Error counts are
known latest failed directions plus unresolved conflict rows/feed blocker, not an
invented count of failed records. Progress reports unconfirmed completion markers
only; interrupted attempts can remain unconfirmed after restart. No percentage,
ETA, bytes or total transfer count is fabricated. Offline/session absence is shown
separately and never represents a successful online health check. No personal
payload, raw journal/conflict JSON or raw exception is displayed.

## Capability audit and deliberate disabled actions

- Category master / expense-type master / Pemohon: push/pull repositories exist,
  but the existing guarded coordinator only exposes an ordered global batch. There
  is no public module+direction entry sharing that coordinator's exclusion and
  authorization boundaries. Direct repository calls would bypass that integration.
  Upload and Download are DISABLED pending a focused coordinator extension.
- Petugas: controlled baseline exists; normal push/coordinator/publisher remain
  OFF. Both manual directions disabled; baseline is not a general selective API.
- Pekerjaan Notaris/PPAT and Transaksi: local data exists but a safe complete sync
  contract/coordinator integration is not available; both directions disabled.

The UI offers module/direction selection and shows a reason; execute is disabled
in every mode. A fail-closed executeSelectedSync rejects programmatic calls too.
It never invokes global synchronizeNow or a repository. No action bypasses
permissions/offline/single-flight checks because no manual execution is exposed.
In UI Smoke the reason explicitly identifies its sync prohibition. This is the
read-only fallback requested by the task, not a claim of completed selective sync.

## Validation and manual UI

Final validation: dart format completed; flutter analyze reports no issues;
focused run10 passed plus journal/conflict run4 passed (overlapping tests);
one full suite336 passed,0 failed,3 live opt-ins skipped.

Focused tests cover all four colors; dirty data overriding success; pending logs;
retry keeping old history; Petugas journal/dirty UUID deduplication, conflicts and
blocked feed; rejecting every module/direction; smoke dropdown changes unable to
execute; offline/empty display. Existing Log/coordinator/smoke regression tests
remain included. Full Flutter suite is run once before the local commit, with
all live opt-ins off. No real SQLite/PostgreSQL database is opened for testing.

From repository root, existing development backend in one terminal (publisher OFF):

```powershell
.\scripts\run-notarisdev-backend.ps1
```

Flutter in another terminal:

```powershell
.\scripts\run-notarisdev-flutter.ps1 -UiSmoke
```

Login, open System → Monitoring Sinkronisasi, inspect colors/last timestamps/counts,
change module and Upload/Download and confirm execute stays disabled with reason.
Refresh must only reload local status. Neutral entries are expected where there
has been no real activity; do not seed sample logs or disable smoke to manufacture
green status. Check System → Log Sinkronisasi and Petugas4/Pemohon20 regression.
No interactive Flutter application was launched by the implementation agent.
