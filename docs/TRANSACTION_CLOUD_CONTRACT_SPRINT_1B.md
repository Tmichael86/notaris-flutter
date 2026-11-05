# Sprint 1B: transaction cloud boundary (2026-11-03)

This is an implementation gate, not a live sync activation.

| Module | UUID cloud/local | Push | Pull | Dependency | Main gap |
| --- | --- | --- | --- | --- | --- |
| Pemohon | Local UUID in API; no transaction reference proof | Existing global flow | Existing global flow | Auth | No transaction-scoped reference receipt |
| Petugas | Separate cloud/local UUID, verified map | Mutation contract exists; normal activation OFF | Baseline pull accepted | Gender/user provenance | Normal push/recovery OFF |
| Kategori Pekerjaan | Same UUID in local/API | Existing global flow | Existing full-list flow | Auth | No versioned publication/cursor |
| Jenis Pengeluaran | Same UUID in local/API | Existing global flow | Existing full-list flow | Auth | No versioned publication/cursor |
| Pekerjaan Notaris/PPAT | Local UUID per parent/child | None | None | Kategori cloud UUID | No cloud aggregate, identity map, receipt or feed |
| Transaksi | Local UUID per parent/detail/process/payment | None | None | Pemohon, Petugas, both job Masters | Go model is header-only; no aggregate API/storage/feed |

First safe dependency is verified cloud identity for Pekerjaan Notaris/PPAT
and their category references. A name or local integer PK is never an identity
claim. Existing Petugas reconciliation and publication pattern can inform the
implementation; it must not be applied to unrelated tables without a scoped
schema, permission and recovery contract. Dirty local records are retained.

## Aggregate contract to implement after the Master dependency

- One immutable mutation ID with actor/scope and expected aggregate revision;
  retry of identical intent returns the durable receipt. A changed payload with
  the same mutation ID is rejected. UUIDs identify transaction and each child;
  integer IDs remain database-local.
- Resolve each Pemohon/Petugas/Pekerjaan/Kategori cloud UUID from a verified
  mapping or same-UUID contract. Reject absent, ambiguous, deleted or dirty
  unresolved dependencies before an aggregate write.
- One PostgreSQL transaction validates permission and revision, locks aggregate,
  writes header, details, process snapshots and payment history, then receipt and
  outbox. A failed child rolls back all writes. Snapshots retain historical
  price/category/process/attribute values independent of later Master edits.
- One publication event contains the complete committed aggregate. Publisher
  assigns commit-safe sequence; pull pagination never splits an aggregate.
  SQLite applies entity/mappings/journal/cursor in one transaction. Replay is
  idempotent, and pending dirty edits are never overwritten silently.
- Soft delete uses explicit tombstones and version checks. 409 retains local
  mutation for conflict review; 410 blocks feed and preserves local state until
  a defined recovery path exists. Cursor and journal are scoped to profile,
  account, device, deployment and generation.
- Server allocates final business number on accepted create; offline number is
  a temporary display value, never the cloud identity or idempotency key.
  Final CREATE numbering follows the approved 2026-11-05 contract below.

No transaction aggregate endpoint, PostgreSQL child schema or Master identity
feed exists yet. A disposable end-to-end transaction write would have to invent
those contracts and cannot be described as a tested slice today. Do not enable
normal/global sync or publisher on the basis of this document.

## 2026-11-05: approved numbering and implemented reference foundation

Business decision FINAL: administrative transaction number (not official deed
number) is `{jenis}00{ddMMyy}{urutan4}`, type 1 Notaris / 2 PPAT. Code 00 means
single-office deployment. Each domain has its own daily sequence 0001–9999,
reset by Asia/Jakarta calendar date at server CREATE issuance, independent of
the user-entered transaction date. Reject exhaustion without wrap. PostgreSQL
must allocate in the same transaction as aggregate, mutation receipt and outbox;
identical mutation retry returns its saved number before allocating. Final number
needs a unique constraint; UPDATE/delete never recycle it. Ack stores the final
number locally without replacing UUID or local PK.

Implemented independently, not yet wired to an accepted CREATE:

- Go `ResolveTransactionCloudReferences`: active exact UUID resolution and SHARE
  locks in an explicit transaction, separate domain tables, selected price UUID
  must belong to the selected job and category. Reject unresolved/ambiguous refs.
- Flutter `TransactionCloudReferences.prepare`: read-only scoped Master/Petugas
  mapping checks, clean/acknowledged dependency checks and explicit selected price
  provenance. Returns candidate cloud references; server must revalidate them.
  Petugas local/cloud UUIDs remain distinct. Normal synchronization stays OFF.
- Private server number allocator plus counter migration proposal, tested only on
  disposable PostgreSQL for concurrent allocation, WIB reset, exhaustion and
  rollback. This is not a migrated/operational aggregate table or CREATE API.

Existing transaction details preserve category labels but not selected price UUID.
They MUST NOT be mapped using label, current price, name or integer-ID guessing.
The new resolver requires explicit reviewed price selection per detail. A future
CREATE journal must persist that provenance with the immutable aggregate snapshot.
Those helper tests alone do not establish Device A→B aggregate acceptance.

## CREATE Notaris slice implementation (2026-11-05)

- Drift v17 adds nullable `harga_uuid` / `kategori_uuid` to transaction details
  plus private transaction identity, immutable pending request and cursor tables.
  Legacy rows stay NULL; there is no provenance backfill. Form selection captures
  actual UUIDs, edit/reopen retains them and historical snapshots.
- `POST /api/v1/transaksi-notaris/sync/create` and authenticated incremental
  `GET /api/v1/transaksi-notaris/sync/pull` require the existing `transaksi` menu
  create/read permissions respectively, in the single-office authorized catalog.
- The two 20261105 PostgreSQL proposals are applied only to disposable schemas.
  New `transaction_cloud*` tables store complete header/detail/process/payment
  snapshots; they do not alias or rewrite the incomplete legacy Go header model.
  Accepted CREATE commits numbering, children/FKs, fingerprint receipt and whole
  aggregate outbox together. Publication is a bounded explicit repository call;
  its HTTP test hook exists only in disposable Go tests.
- Explicit Flutter `TransactionCloudRepository` persists immutable intent before
  HTTP, applies final number without replacing UUID/local PK, protects later edits,
  and applies dependencies/mapping/children/cursor in one Drift transaction.
  It is not registered with global or normal SyncCoordinator.
- Process transition audits with unresolved user identities are explicitly blocked
  before push; this slice covers initial process snapshots and payment history,
  not a new process validation/actor contract. UPDATE/DELETE/PPAT not implemented.

Validation commands (owned disposable PostgreSQL DSN only):

```powershell
# backend-notaris-go; never point this at port 5432
$env:NOTARIS_SYNC_TEST_DSN='host=127.0.0.1 port=55451 user=notaris_test dbname=postgres sslmode=disable'
go test ./routes -run '^TestTransactionCloudHTTPPostgres$' -count=1
$env:NOTARIS_TRANSACTION_E2E='1'
go test ./routes -run '^TestTransactionCloudHTTPPostgres$' -count=1 -v
```

The HTTP E2E creates two NEW temporary SQLite files; it never opens development
or daily profiles. Permanent PostgreSQL rollout and existing SQLite profile
upgrade remain separate approval checkpoints. No normal sync activation follows
from this test.

Checkpoint validation: 388 Flutter tests passed / 6 opt-in skipped, analyzer
clean. The opt-in transaction HTTP E2E separately passed against disposable
PostgreSQL and two fresh SQLite files, including replay/restart, local page
rollback and dirty protection. Go HTTP tests passed idempotent receipt/number,
changed-payload rejection, failed child rollback after allocation, concurrent
CREATE, bounded publication and permission rejection; existing Master route
tests also passed. Logs remain in `.local/transaction-cloud-*.log`.
