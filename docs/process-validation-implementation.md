# Process Validation Implementation

Branch: `feature/process-validation-foundation`

## Purpose

Add process-level validation to the local-first Flutter application while preserving the existing Notaris/PPAT transaction and payment flow. Local rules are a first enforcement layer; the Go API must become authoritative when multi-user synchronization is implemented.

## Current local schema

Drift schema version is **7** in `frontend_notaris/lib/database/app_database.dart`.

- `Transaksis`: transaction header and transaction-level status.
- `TransaksiDetails`: one selected job per row, with stable UUID, price/name snapshots, legacy `prosesSnapshot`, active status and soft-delete metadata.
- `TransaksiProses`: normalized process row linked to transaction ID and the stable transaction-detail UUID. Manual process IDs remain optional; process name is snapshotted.
- `TransaksiProsesRiwayat`: append-only transition history with previous/new status, actor, timestamp, note and sync metadata.
- `TransaksiRiwayatPembayarans`: payment history, unchanged by process validation.

The v6 -> v7 migration backfills valid JSON process items from active transaction details only. It preserves the original JSON, copies each item's status to `legacyStatus`, and stores the original item JSON in `legacyData`. Migrated process rows start with `statusProses = null`; no historical validation event is invented. Soft-deleted/inactive details are not backfilled into the active process workflow.

## Stable identity

Transaction detail UUIDs are preserved when a transaction is edited. Existing details are updated by UUID, removed details are soft-deleted, and newly added jobs use their own UUID. Process rows link to `TransaksiDetails.uuid`, not transaction number or Master process ID. This matters because PPAT records may share a `no_akta`, and manual processes may not have a Master ID.

## Process states and allowed transitions

- `belum_dikerjakan -> dalam_pengerjaan`
- `dalam_pengerjaan -> menunggu_validasi`
- `menunggu_validasi -> valid`
- `menunggu_validasi -> perlu_revisi`
- `perlu_revisi -> dalam_pengerjaan`

A legacy process with a null normalized status must be explicitly initialized to `belum_dikerjakan` before it can use normal transitions. This is a new action recorded now, not an inference about the past.

## Repository behavior

Implemented in `frontend_notaris/lib/repositories/transaksi_proses_repository.dart`:

- Reads active process rows and excludes rows whose transaction details are inactive/soft-deleted.
- Checks that process, detail and transaction are active before state changes.
- Rejects unknown statuses and illegal transitions.
- Requires a non-empty note when submitting for validation and when requesting revision.
- Records submitter and submission time on `menunggu_validasi`.
- Rejects approval/revision by the same user who submitted the process.
- Records validator and decision time for `valid` or `perlu_revisi`.
- Clears the latest submission/decision actor metadata when returning from revision to work, while retaining the audit history.
- Updates process state and appends history in the same Drift transaction.

The local actor ID is supplied by the caller. This repository does not itself implement role/permission lookup or user assignment. Local checks are not a security boundary; the Go service must repeat authorization and transition checks server-side.

## Tests

Repository tests are in `frontend_notaris/test/repositories/transaksi_proses_repository_test.dart`. They cover explicit initialization of legacy rows, rejection of illegal transitions, self-validation rejection, revision-note requirements, resubmission and audit-history sequence.

Run from `frontend_notaris`:

```sh
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test test/repositories/transaksi_proses_repository_test.dart
```

These commands must be run in the developer's local environment before considering this stage verified. GitHub file updates do not execute Flutter tests.

## Remaining work

1. Run the generated-code/analyzer/test commands locally and fix any reported issues.
2. Add Riverpod providers and Monitoring UI after repository behavior is verified.
3. Add Go/GORM models, server-side permission checks and atomic transitions before relying on multi-user validation.
4. Test transaction edits, soft deletion, duplicate submissions, self-validation rejection, revision/resubmission and sync retry behavior.

## Explicit non-goals

- Do not rewrite transaction business flow.
- Do not change transaction-level status semantics.
- Do not implement the pending tax calculator, PPAT status prototype, document/note screen, invoice or receipt in this phase.
- Do not treat menu visibility or local checks as authoritative server authorization.
- Do not copy Laravel's page-visit-based unlock behavior into Go.
