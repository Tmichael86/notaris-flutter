# Petugas initial development bootstrap and publication

This is a controlled operator workflow for **127.0.0.1:5432/notarisdev**. The
implementation is ready for review; creating it does **not** authorize permanent
bootstrap, publication drain, worker activation, HTTP writes, or Flutter activation.
No normal backend startup migrates, grants, or bootstraps anything.

## Existing implementation audit

`repositories/petugas_bootstrap.go` locks Petugas in SHARE ROW EXCLUSIVE mode,
captures canonical model snapshots, and inserts only missing `(uuid,row_version)`
events in one transaction. It preserves IDs, UUIDs, versions and business rows.
The lock serializes bootstraps and blocks concurrent Petugas writers during capture.
Legacy CRUD and sync writes already append their next-version outbox events in
their business transaction; enabling bootstrap/publication does not replace CRUD.

`PetugasPublicationRepository.Publish` holds the singleton publication row lock
through commit. It selects committed pending outbox rows in ID order, assigns
publication sequences and updates the counter in that same transaction. A failed
batch rolls back both assignments and counter. Outbox IDs may have gaps and are
never treated as pull cursors. Two publishers cannot commit cursors out of order.
An older uncommitted outbox ID is published later without losing the change.

`Pull` reads committed historical payloads, validates identity/version/tombstone,
and uses publication sequence pagination in a repeatable-read, read-only transaction.
Initial clients obtain existing Petugas only **after** their baseline events are
bootstrapped **and** published. Bootstrap alone leaves the pull feed empty.

The existing runtime worker waits between bounded attempts, backs off on errors,
and observes cancellation. `cmd/main.go` cancels the worker, gracefully shuts down
HTTP and waits for worker completion before closing the database pool. Publisher
configuration remains default OFF in every environment. Flutter's normal
SyncCoordinator is unchanged.

## Runner and preflight

Entry: `scripts/invoke-notarisdev-petugas-operations.ps1`, calling the new explicit
`cmd/petugasops` command. It never loads the ordinary `.env`. It reads only the
reviewed `.env.notarisdev` database settings and requires publisher OFF there.
Host must be exactly `127.0.0.1`, port 5432, database notarisdev, HTTP port 8081,
and a restricted non-owner app role. There is no test-target override in the CLI.

Every invocation requires a successful grants-only receipt. The launcher verifies
COMMIT before the success marker, postchecks, SQL/runner/helper hashes, backup
checksum (hash only; no restore), and the install/backup/UUID fingerprint chain.
It builds a local binary and records its hash, sanitized baseline and JSON events
under `.local/petugas-operations-<UTC timestamp>-<id>/`. Credentials stay in the
child process environment, never command arguments, baseline JSON or logs.

Default invocation is authenticated read-only inspection:

```powershell
.\scripts\invoke-notarisdev-petugas-operations.ps1 `
  -GrantsReceiptDirectory '.local\petugas-grants-20261031-045404-127d93cb'
```

Preflight checks live target/marker/role, catalog definitions/indexes/constraints/
sequence ownership, positive and forbidden grants, original data/UUID hashes,
exact IDs 101–104 with version 1/status 1/no deletion, server references, zero
mutation receipts and valid initial-or-resumable baseline journal/counter state.
It rejects unexpected/corrupted/duplicate snapshots, cursor gaps and retention.
Dry-run transactions are explicitly read-only and never call nextval/setval.

Port 8081 must be free. The Go command holds a loopback reservation for its entire
run, preventing a development backend launch during maintenance. It also rejects
**any other database session**, including sessions of another role whose activity
details are hidden. Stop the backend, DBeaver connections, clients and workers
before running it. It does not terminate another process or connection.

## Separate approval required before applying

The following are review examples, **not approval to execute now**. Each selected
permanent write action needs explicit operator approval. Keep all clients stopped.

```powershell
# Approved action 1: capture the four baselines, without publishing.
.\scripts\invoke-notarisdev-petugas-operations.ps1 `
  -GrantsReceiptDirectory '.local\petugas-grants-20261031-045404-127d93cb' `
  -Apply -ConfirmTarget '127.0.0.1:5432/notarisdev' -MaintenanceConfirmed `
  -Operation bootstrap

# Approved action 2: publish all pending baseline events and verify pull.
.\scripts\invoke-notarisdev-petugas-operations.ps1 `
  -GrantsReceiptDirectory '.local\petugas-grants-20261031-045404-127d93cb' `
  -Apply -ConfirmTarget '127.0.0.1:5432/notarisdev' -MaintenanceConfirmed `
  -Operation drain -BatchSize 2 -MaxBatches 10 -TimeoutSeconds 60
```

`bootstrap-and-drain` combines these actions but still commits bootstrap and each
publication batch independently. It requires approval covering **both** actions.
Drain loops until pending is zero; reaching the deadline/batch bound is a failure,
not a successful partial drain. Final successful drain requires four retained
baseline snapshots, last_seq=4, min_cursor=0, pending=0, and incremental pull
pages returning all four exact identities and payloads with monotonic cursors.
No transaction or detail legacy table is modified. Hashes of **all** legacy public
tables (including Petugas) and legacy sequences are compared before/after phases.

An advisory lock on one pinned session excludes another operations runner.
Each write phase revalidates under Petugas/outbox/publication table locks and
invokes the existing repository methods through nested transactions. Schema and
grants are only inspected. No second publication algorithm is implemented.

## Interrupted execution and retry

The receipt's `bootstrap_committed` and `publication_batch_committed` events are
emitted only after the corresponding outer transaction successfully commits.
Inspect `operations.jsonl`, stderr and history.json after any failure. Missing
completion or a lost commit acknowledgement means **inspect the database with a
new dry-run**, not assume the last transaction rolled back.

Committed bootstrap events and publication batches survive process termination.
A subsequent approved retry uses the same baseline, appends zero duplicate
baselines and publishes only pending events. Sequence gaps after aborted inserts
are valid; sequences/cursors are never reset and outbox rows are never deleted.
Timeout defaults to 60 seconds (range 1–300), statement timeout to 15 seconds,
lock timeout to 5 seconds, batch size to 100 and maximum batches to 10.
The wrapper bounds build time and gives the Go process 15 seconds of cleanup
grace after its operation deadline. It kills only its exact owned child on timeout.

External maintenance is still necessary: a port reservation/advisory lock cannot
prevent an administrator or unrelated client opening a fresh database connection.
New sessions observed by phase checks fail closed. Unexpected data, grants,
schema, mutation or retention changes require inspection; there is no automatic
retry, revoke, migration, reset or restore fallback. This runner is for the initial
four-record rollout and deliberately refuses later changed live business data.

## Explicit development worker startup, after separate approval

`run-notarisdev-backend.ps1` remains publisher OFF by default. Its new opt-in:

```powershell
# Future approved activation only; not executed at this implementation checkpoint.
.\scripts\run-notarisdev-backend.ps1 -EnablePetugasPublisher `
  -PetugasGrantsReceiptDirectory '.local\petugas-grants-20261031-045404-127d93cb'
```

Before starting HTTP or the worker, it calls a **read-only** published-baseline gate
(`-RequirePublishedBaseline`). This gate verifies live target/maintenance/schema/
grants, contiguous committed publication history, and that the first four pull
events preserve the approved IDs/UUIDs/version-1 baseline. It refuses an empty or
partially published installation. It permits later legitimate CRUD, receipts and
pending events so restarting a development worker remains possible. It does not
bootstrap/drain during startup. Retention/full-resync remains a separate future
checkpoint; min_cursor>0 blocks this initial-baseline gate for inspection.

With publisher OFF, authenticated HTTP reads remain available; pending events
become visible in incremental pull only after publication. This checkpoint does
not launch a permanent backend or claim an interactive Flutter test.

## Validation

```powershell
# Dependency-free guards, also run with Windows PowerShell 5.
.\scripts\test-petugas-operations-guards.ps1

# Creates/owns/stops a NEW loopback cluster on 55445; no restore or permanent DSN.
.\scripts\test-petugas-operations.ps1
```

The harness verifies its unique data_directory/port before creating an empty
disposable database. A small in-code synthetic fixture receives the existing
migrations and a restricted NOINHERIT, non-owner app role. No such schema/grants
actions target permanent data. Full Go regression includes the HTTP Petugas test,
initial bootstrap/retry, paginated pull, unchanged identities/legacy data/sequences,
interruption after bootstrap commit, one-batch partial publication/reconnect/retry,
concurrent-runner exclusion, schema/grants/data/maintenance refusal and worker
restart after subsequent CRUD. Existing publication/rollback/bootstrap-vs-writer/
legacy-vs-sync concurrency cases run five additional times in random test schemas.
Restore-readiness and synthetic-login tests stay skipped without their independent
opt-in DSNs; no new restored-schema or Flutter-interactive result is claimed.

Current evidence and exact counts are recorded in the local implementation report.
No permanent bootstrap, publication, HTTP write smoke, worker or Flutter activation,
notarislokal modification, restore/reset, push or merge is part of this checkpoint.
