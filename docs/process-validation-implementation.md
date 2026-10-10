# Process Validation Implementation Baseline

Branch: `feature/process-validation-foundation`

## Purpose

Add process-level validation to the local-first Flutter application while preserving the Laravel Notaris/PPAT business flow. This document records the schema audit and the implementation contract before introducing a database migration.

## Audited local schema

Current Drift schema version is **6** in `frontend_notaris/lib/database/app_database.dart`.

Relevant tables:

- `Transaksis` (`transaksis`): transaction header, UUID, number, type, status, applicant/officer references, dates and sync flags.
- `TransaksiDetails` (`transaksi_details`): one row per selected job; contains a unique UUID, transaction ID, job type, Master job references, name/category/time snapshots, `prosesSnapshot` JSON, price snapshots, active status, sync flags and soft-delete timestamp.
- `TransaksiRiwayatPembayarans`: individual payment history rows.
- Master process tables are local Drift tables in `pekerjaan_tables.dart`.

The current application has **no normalized local row per transaction process**. Process checklists are stored as JSON in `transaksi_details.prosesSnapshot`.

## Critical compatibility finding

In `TransactionRepository.save()`, editing an existing transaction currently:

1. soft-deletes all active `transaksi_details` rows for the transaction;
2. inserts fresh detail rows with new random UUIDs;
3. writes the new process snapshot JSON onto each newly inserted row.

Therefore, attaching process status/history only to the current `transaksi_details.id` or UUID would make that association unstable across an ordinary transaction edit. A process-validation migration must not be added until the implementation preserves or deliberately migrates process identity across detail replacement.

This is an internal persistence concern. The user-facing Laravel business flow must remain unchanged.

## Laravel compatibility rules

- `status` on a record means active/inactive in the legacy CRUD helper. It is not the validation state.
- Laravel `transaksi_detail_proses` stores a process snapshot with `transaksi_id`, `prosesId`, `pekerjaanNama`, `kategoriNama`, `prosesNama`, `atribut`, `catatan`, `isValidate`, audit actor IDs and timestamps.
- Notaris: one transaction may have many process details.
- PPAT: multiple transaction rows can share a `no_akta`; `no_akta` must not replace the transaction identity.
- Master changes must not silently rewrite transaction snapshots.
- Preserve the existing transaction-level statuses and payment/business side effects.

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

## Recommended implementation sequence

1. Introduce a stable identity for each transaction job/process that survives transaction edits. Prefer preserving detail UUIDs for matching jobs; explicitly handle removed and newly added jobs. Do not infer identity from display names alone.
2. Add a normalized local process table and an append-only process-transition history table only after stable identity is established.
3. Add Drift migration from schema v6 to v7, including safe backfill from existing `prosesSnapshot` JSON. Backfill must be idempotent and must not fabricate validation decisions.
4. Add repository methods and tests for process state transitions and audit history.
5. Add Riverpod providers and Monitoring UI.
6. Add the equivalent PostgreSQL/GORM model, service-level authorization and transactional state transitions in Go.
7. Test edit-preservation, Notaris/PPAT identity, soft deletion, duplicate submit, self-validation rejection, revision/resubmission, and sync retry behavior.

## Proposed normalized data (not yet migrated)

A process state record should contain at least:

- stable `uuid`
- `transaksi_uuid`
- stable job/detail identity
- optional Master process reference (nullable for manually-added processes)
- process name snapshot
- `status_proses`
- optional assigned worker
- submit/validation actor IDs and timestamps
- latest note/revision reason
- `is_sync_dirty`, `last_synced_at`, and soft-delete marker if required by sync conventions

A history record should capture process UUID, previous/new state, actor, timestamp, note and sync metadata.

The exact foreign-key strategy and backfill are intentionally deferred until stable job/process identity is implemented. This avoids orphaning process status when the current transaction editor replaces detail rows.

## Explicit non-goals for this phase

- Do not rewrite transaction business flow.
- Do not change transaction-level status semantics.
- Do not implement the pending tax calculator, PPAT status prototype, document/note screen, invoice or receipt here.
- Do not treat local UI permission checks as authoritative server authorization.
- Do not copy Laravel's page-visit-based unlock behavior into Go.
