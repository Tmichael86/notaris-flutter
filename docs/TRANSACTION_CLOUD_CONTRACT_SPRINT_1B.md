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

## UPDATE / soft DELETE Notaris checkpoint (2026-11-05)

Implemented using the CREATE adapter and authenticated `transaksi` update/delete
permissions: `/transaksi-notaris/sync/update` and `/transaksi-notaris/sync/delete`.
The additive `20261105_transaction_notaris_mutations.sql` proposal raises the
revision constraint, retains removed children with tombstones and permits one
complete outbox event per aggregate revision. All testing uses disposable schemas.

- Parent row lock + expected revision; mutation fingerprint includes operation,
  and durable actor-bound receipt is checked before the revision. Identical retry
  returns the same receipt. Conflict 409 keeps the immutable local pending request.
- Final number is never reassigned. Committed payment rows must match exactly;
  UPDATE never replaces, deletes, corrects or adds payments. Payment operations
  need a separate contract. Removed details/processes are retained, never reparented.
- Process transitions without cloud actor provenance are blocked before push;
  the server also rejects changes to process validation status without a contract.
  Existing local audit rows remain untouched. Non-transition snapshot edits work.
- DELETE follows existing unconditional local soft deletion, retains historical
  payment/process snapshots and mutation actors, and publishes a full tombstone.
- Drift v18 preserves existing mapping, cursor, pending payload and final number,
  enables revisions >1 and records pending operation. Pull updates existing local
  PKs atomically with children/journal/cursor, checks dependencies and payments,
  and refuses dirty/pending local rows. Unsent local child tombstones are retained
  conservatively rather than implicitly clearing their dirty flags.

Validation: 389 Flutter tests passed / 6 opt-in skipped, analyzer clean, focused
Go PostgreSQL/HTTP tests plus Master route regression passed. Separate real HTTP
Device A/B E2E passed CREATE→UPDATE→DELETE, receipt replay, local conflict retention,
atomic rollback, payment/actor guards, pagination/replay/restart and SQLite FK /
integrity. In the A/B slice there are three receipts/events, cursor 3 on both
devices and only one number allocation. Logs: `.local/transaction-mutations-*.log`.

```powershell
# Same owned disposable DSN and Go test as CREATE, with these opt-in flags:
$env:NOTARIS_TRANSACTION_E2E='1'
$env:NOTARIS_TRANSACTION_MUTATIONS_E2E='1'
go test ./routes -run '^TestTransactionCloudHTTPPostgres$' -count=1 -v
```

No permanent PostgreSQL migration, existing SQLite profile upgrade, operational
sync activation or publisher activation follows from this checkpoint. PPAT
transaction cloud, explicit conflict resolution and payment/process actor
contracts remain separate work.

## PPAT transaction CRUD checkpoint (2026-11-05)

The existing transaction repository, receipt/outbox, publisher and Drift apply
now support both domains. PPAT uses `/transaksi-ppat/sync/{create,update,delete,pull}`
with the same authenticated `transaksi` operation permissions. Mutation domain
must match the endpoint; omitted domain remains supported for legacy Notaris
requests without changing their receipt fingerprint. New events carry domain.

`20261105_transaction_ppat_domain.sql` follows the three transaction proposals
(numbering, CREATE, mutations) and both Master schema proposals. It adds parent
domain and PPAT-specific detail/price FKs, plus a composite parent/domain FK and
checks forbidding mixed-domain references. All applications so far were to
disposable schemas only. Drift remains v18; local tables already store domain.

Transaction UUID remains deployment-global: same UUID submitted in the other
domain is rejected (409), never relinked or reconciled. Master job/price UUIDs may
be identical across their separate domains; resolution uses the correct domain
tables. Domain cannot change on UPDATE. PPAT numbers use `200{ddMMyy}{seq4}` with
the existing independent daily WIB counter. Receipt, revision, payment, actor
audit and dirty/tombstone protections are shared with Notaris.

There is ONE authorized transaction feed/cursor for both domains, not a filtered
feed with hidden sequence gaps. Either pull route returns complete domain-tagged
events; the common Drift adapter applies each to its proper local references.
`otherMasterScope` can provide a distinct reference scope for the other domain.

Validation: 389 Flutter tests passed / 6 opt-in skipped; analyzer clean. Focused
Go reference/numbering, both transaction HTTP CRUD and both Master HTTP regressions
passed. Real HTTP A/B E2E passed separately for Notaris and PPAT. The PPAT case
also imports a new Notaris CREATE through the same SQLite/feed: PPAT lifecycle
is seq 1–3 and Notaris CREATE seq 4; each domain allocates only number 0001.
Tests cover same aggregate UUID rejection, Notaris-only reference rejection on
PPAT, cross-domain update/delete rejection, correct server/local job FKs despite
identical Master UUIDs, conflict retention, replay/restart and FK/integrity.
Logs: `.local/transaction-ppat-{go,e2e,flutter-full}.log`.

```powershell
# backend-notaris-go; same owned disposable DSN as above
$env:NOTARIS_TRANSACTION_E2E='1'
$env:NOTARIS_TRANSACTION_MUTATIONS_E2E='1'
go test ./routes -run '^TestTransaction(Ppat)?CloudHTTPPostgres$' -count=1 -v
```

Next checkpoint is combined Transaction rollout preflight, backup/restore
simulation, legacy preservation and least-privilege grant review. Existing
PostgreSQL/SQLite profiles have NOT been upgraded, and this is not permission
to apply or activate synchronization. Payment corrections/additions, process
actor provenance and conflict resolution UI remain separate contracts.

## Combined Transaction preflight (2026-11-05)

Read-only audit of notarisdev found four legacy transactions, four process details
and four payment records. Actual Master category/price schemas use status without
`deleted_at`; the resolver now accepts that legacy shape while still rejecting
optional tombstones when present. Focused tests cover both domains; the restricted
app role also resolved the active legacy Notaris UUID on the restored clone and
rejected the deleted PPAT UUID. No identity matching by name/PK was introduced.

The PostgreSQL backup restored successfully on isolated port 55452. Combined
schema/grants simulation passed final-stage failure rollback, successful COMMIT
and second-apply rejection. All 49 original table fingerprints and 38 old sequence
states were preserved; eight new tables, two unused sequences, 13 validated FKs,
least-privilege grants and empty cloud/counter/feed state were verified.

Existing development SQLite remains v16 with two dirty transactions/details and
no price provenance. A backup-API disposable copy upgraded to v18 with all 31
original table fingerprints preserved; original file hash remained unchanged.
Petugas cloud/local UUID proof matched all four server identities; all 20 clean
Pemohon UUIDs matched active server rows. No source profile migration occurred.

Migration-only readiness does not imply live reference readiness: the active
legacy Notaris is unpublished, and no active PPAT exists. Later live E2E needs
separately approved fresh synthetic Master references/publication. Existing local
dirty data must remain excluded. Backup, combined guarded SQL, hashes, simulation
receipts and the live plan are under `.local/transaction-rollout-preflight-20261105-071615`.
No permanent Transaction migration/CRUD/publication has been performed.
