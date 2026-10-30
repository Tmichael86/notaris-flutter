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
to the public pull contract. The publication repository now provides this
projection directly from historical snapshots; it never reads latest Petugas
state to reconstruct an earlier event.

Apply `20261030_01_petugas_publication.sql` after the identity migration. It
adds a singleton transactional counter, initialized under an outbox table lock.
`PetugasPublicationRepository.Publish` locks the counter FOR UPDATE until commit,
then assigns publication_seq and published_at to committed unpublished events.
All publishers must use this protocol. No SKIP LOCKED or PostgreSQL sequence is
used to allocate the pull cursor. The preexisting BIGSERIAL outbox ID is only a
batch ordering key. An event with a smaller ID that commits later gets a later
publication sequence and remains discoverable by incremental pull.

Counter update and event assignment commit together. A publisher transaction
rollback (including connection loss before commit) rolls back both; retry after
commit sees events already assigned and does not republish them. Publishers
are serialized deliberately; throughput can be optimized in a later checkpoint.
Published snapshots must remain immutable. No scheduler or HTTP route is wired.

`Pull` uses one read-only REPEATABLE READ snapshot for counter bounds and event
selection. It returns at most limit events, next_cursor (last returned sequence,
or the input for an empty page), and has_more based on one extra row. Historical
tombstones carry identity/version and no active payload. Negative/future cursors
and limits outside 1..500 fail. Malformed snapshots fail without advancing the
cursor. The database column is publication_seq; the Go contract calls the value
publication_sequence. No second synonymous sequence column is introduced.

The counter's min_cursor is initially zero. A future retention transaction must
delete only a published prefix and advance min_cursor atomically under the
counter lock; Pull reports ErrPetugasCursorExpired for older clients. Retention
and full resync are not implemented yet; keep all published events. A future
resync must preserve dirty local records and capture its snapshot plus cursor
consistently. Database replacement/feed epochs require a future cursor contract.

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
