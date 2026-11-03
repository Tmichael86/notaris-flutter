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
  Final numbering, amendment rules and collision handling require an approved
  business contract before enabling transaction push.

No transaction aggregate endpoint, PostgreSQL child schema or Master identity
feed exists yet. A disposable end-to-end transaction write would have to invent
those contracts and cannot be described as a tested slice today. Do not enable
normal/global sync or publisher on the basis of this document.
