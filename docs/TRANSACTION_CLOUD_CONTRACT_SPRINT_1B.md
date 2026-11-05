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
No receipt/outbox/HTTP transaction CREATE or Device A→B aggregate acceptance is
claimed by these helper tests. Aggregate storage/API, durable snapshot, local
atomic apply/cursor and real HTTP E2E remain to implement; no permanent DB touched.
