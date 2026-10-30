# Transactional Petugas repository checkpoint

`NewPetugasSyncRepository(db).Apply(ctx, mutation, authenticatedActorID)`
requires the existing `20261029_01_petugas_cloud_sync.sql` migration. This
checkpoint does not apply it or connect the repository to any route.

Create uses `expected_row_version: null` and a new UUID. Update and delete
require the current positive version. Existing integer IDs are preserved.
An existing UUID with a create request, a missing update target, a stale
version, or an upsert against a tombstone returns `PetugasVersionConflict`.
Its `Current` field contains the database row, including UUID, integer ID,
version and deletion state (nil only for an absent target). A later controller
should map this error and `ErrMutationReuse` to HTTP 409.

The caller must authenticate and authorize the operation before calling Apply.
The request fingerprint includes actor, operation, UUID, version and payload.
Successful receipts are kept indefinitely in this checkpoint. Exact retries
return the original acknowledgement even after subsequent row changes. Reuse
with a different request or actor fails. A failed mutation has no receipt and
can be retried after correcting the failure. New mutation IDs against an
already deleted row require its current version, record a receipt, and create
no extra deletion event. Tombstones cannot be resurrected through upsert.

Transaction-scoped advisory locks serialize mutation IDs then record UUIDs,
including concurrent inserts. A row lock protects existing rows. Explicit
READ COMMITTED isolation lets a waiter observe its predecessor's committed
receipt. The entire mutation, receipt and unpublished outbox snapshot commit
together. PostgreSQL integrity errors wrap `ErrPetugasConstraint`, retaining
the original SQLSTATE via errors.As. Connection/serialization/deadlock errors
are returned to the caller, which can retry the same mutation ID.

Reference values are server IDs from this PostgreSQL deployment. The repository
checks existence and holds key-share locks until commit. It never translates
SQLite IDs, matches names, or creates users. An integer alone cannot prove its
origin; the future client adapter must resolve local references before sending.
No policy excluding inactive referenced rows is inferred by this checkpoint.

Outbox `payload` is an internal JSON snapshot of the database Petugas row,
including version and deletion metadata. A later publisher must transform it
to the public pull contract. No publication sequence is allocated here.
Allocating a normal sequence in multiple publisher transactions would still
be unsafe: publisher A can allocate 1 and commit after B publishes 2. Before
pull activation, implement a transactional counter row locked until commit
to serialize publication batches, with event assignment and counter update in
the same transaction. SKIP LOCKED alone does not provide this guarantee.

Legacy CRUD remains unchanged and does not yet increment row_version or write
outbox events. Consequently concurrency protection currently covers only Apply
calls; sync endpoints must remain disabled until all legacy writes participate.
The inherited migration backfills legacy UUIDs using an ID-derived hash. That
is not globally unique across independent installations; before deployment,
replace that unapplied backfill with a durable random UUID strategy. This
repository accepts an explicit UUID and does not derive one from integer IDs.

## Verification

Run `go test ./...`. PostgreSQL tests skip unless `NOTARIS_SYNC_TEST_DSN`
explicitly identifies a disposable test database. The tests never read the
application configuration or .env. They create a unique schema, restrict
search_path, build a legacy fixture, apply the actual migration there, and
drop only that generated schema afterward. The test role needs CREATE SCHEMA.

Integration cases cover create, concurrent same/different mutation creates,
receipt replay, changed-request rejection, stale concurrent updates, delete,
repeat delete, missing references, database constraints and an injected outbox
failure after row write. Unit tests cover fingerprints and version decisions.
Run `go test -race ./repositories ./synccontract` where CGO and a C compiler
are available. A skipped integration test is not evidence of PostgreSQL
transaction, locking or migration correctness.
