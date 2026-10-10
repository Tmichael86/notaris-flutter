# Process Validation Implementation Baseline

Branch: `feature/process-validation-foundation`

## Purpose

Add process-level validation to the local-first Flutter application while preserving the Laravel Notaris/PPAT business flow. This document records the schema audit and the implementation contract.

## Audited local schema

Current Drift schema version is **6** in `frontend_notaris/lib/database/app_database.dart`.

Relevant tables:

- `Transaksis` (`transaksis`): transaction header, UUID, number, type, status, applicant/officer references, dates and sync flags.
- `TransaksiDetails` (`transaksi_details`): one row per selected job; contains a unique UUID, transaction ID, job type, Master job references, name/category/time snapshots, `prosesSnapshot` JSON, price snapshots, active status, sync flags and soft-delete timestamp.
- `TransaksiRiwayatPembayarans`: individual payment history rows.
- Master process tables are local Drift tables in `frontend_notaris/lib/database/pekerjaan_tables.dart`.

The current application has **no normalized local row per transaction process**. Process checklists are stored as JSON in `transaksi_details.prosesSnapshot`, with JSON items currently shaped like `{ "id": "...", "name": "...", "status": "..." }`.

## Identity-preservation implementation

The original `TransactionRepository.save()` soft-deleted every active detail row on each edit and inserted fresh rows with random UUIDs. This made any process-level status/history association unstable.

On this branch, the first compatibility change has been made:

- Each `DummyTransactionJob` gets a stable local detail UUID when it is created.
- Loading an existing transaction restores each job's stored detail UUID.
- `TransactionJobInput` carries that UUID to the repository.
- Editing updates existing detail rows by UUID, soft-deletes only rows removed from the form, and inserts only newly added jobs.
- The transaction header update, payment history behavior, job snapshots and process snapshot remain within the existing local transaction workflow.

This is a persistence refactor, not a change to the user's transaction business flow. It has not yet been run through Flutter analyzer or runtime tests in this environment; it must be verified locally before merge.

## Laravel compatibility rules

- Legacy `status` on a record means active/inactive. It is not the validation state.
- Laravel `transaksi_detail_proses` stores process snapshots with `transaksi_id`, `prosesId`, `pekerjaanNama`, `kategoriNama`, `prosesNama`, `atribut`, `catatan`, `isValidate`, audit actor IDs and timestamps.
- Notaris: one transaction may have many process details.
- PPAT: multiple transaction rows can share a `no_akta`; `no_akta` must not replace transaction identity.
- Master changes must not silently rewrite transaction snapshots.
- Preserve existing transaction-level statuses and payment/business side effects.

## New process-validation behavior

Initial process states:

- `belum_dikerjakan`
- `dalam_pengerjaan`
- `menunggu_validasi`
- `valid`
- `perlu_revisi`

Allowed transitions:

- `belum_dikerjakan -> dalam_pengerjaan`
- `dalam_pengerjaan -> menunggu_validasi`
- `menunggu_validasi -> valid`
- `menunggu_validasi -> perlu_revisi`
- `perlu_revisi -> dalam_pengerjaan`

Every submit, approval and revision decision must record actor, timestamp and note/reason where applicable. A worker must not validate their own work. Admin, Notaris and PPAT validation capability is controlled by explicit permission, not merely by menu visibility.

These states are new behavior; they are not claimed to exist in the legacy Laravel runtime.

## Proposed normalized data (not yet migrated)

A normalized process-state record should contain at least:

- stable process UUID
- transaction UUID and stable detail/job UUID
- optional Master process reference (nullable for manually-added processes)
- process name snapshot
- `status_proses`
- optional assigned worker (assignment semantics still need confirmation in the existing UI)
- submit/validation actor IDs and timestamps
- latest note/revision reason
- `is_sync_dirty`, `last_synced_at`, and soft-delete marker if required by sync conventions

A history record should capture process UUID, previous/new state, actor, timestamp, note and sync metadata.

The migration/backfill must be idempotent and must not fabricate past validation decisions. Existing free-form `status` values in JSON must be preserved as legacy data until their exact meaning is mapped; they must not be blindly converted into an approval decision.

## Recommended implementation sequence

1. Verify the detail-UUID-preserving transaction edit refactor using Flutter analyzer and create/edit/remove/reopen regression tests.
2. Add a normalized local process table and process-transition history table using stable detail/job identity.
3. Add Drift migration from schema v6 to v7, including safe backfill from existing `prosesSnapshot` JSON without inventing validation history.
4. Add repository methods and tests for process state transitions and audit history.
5. Add Riverpod providers and Monitoring UI.
6. Add the equivalent PostgreSQL/GORM model, service-level authorization and transactional state transitions in Go.
7. Test edit-preservation, Notaris/PPAT identity, soft deletion, duplicate submit, self-validation rejection, revision/resubmission, and sync retry behavior.

## Explicit non-goals for this phase

- Do not rewrite transaction business flow.
- Do not change transaction-level status semantics.
- Do not implement the pending tax calculator, PPAT status prototype, document/note screen, invoice or receipt here.
- Do not treat local UI permission checks as authoritative server authorization.
- Do not copy Laravel's page-visit-based unlock behavior into Go.
