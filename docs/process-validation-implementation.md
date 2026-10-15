# Process Validation Implementation

Origin: `feature/process-validation-foundation`
Current reference branch: `integration/notaris-stabilization`

## Purpose

Add process-level validation to the local-first Flutter application while preserving the existing Notaris/PPAT transaction and payment flow. Local rules are a first enforcement layer; the Go API must become authoritative when multi-user synchronization is implemented.

## Current local schema

Drift schema version is **9** in `frontend_notaris/lib/database/app_database.dart` on the stabilization branch. Keep this number aligned with the actual `schemaVersion` value whenever migrations are added.

Relevant tables:

- `Transaksis`: transaction header and transaction-level status.
- `TransaksiDetails`: one selected job per row, with stable UUID, price/name snapshots, legacy `prosesSnapshot`, active status and soft-delete metadata.
- `TransaksiProses`: normalized process row linked to transaction ID and the stable transaction-detail UUID. Manual process IDs remain optional; process name is snapshotted.
- `TransaksiProsesRiwayat`: append-only transition history with previous/new status, actor, timestamp, note and sync metadata.
- `TransaksiRiwayatPembayarans`: payment history, separate from process validation.

Migration notes:

- **v6 -> v7:** backfills valid JSON process items from active transaction details only. It preserves the original JSON, copies each item's status to `legacyStatus`, and stores the original item JSON in `legacyData`. Migrated process rows start with `statusProses = null`; no historical validation event is invented. Soft-deleted/inactive details are not backfilled into the active process workflow.
- **v8:** adds unique UUID indexes for `pemohons.uuid` and `transaksis.uuid`.
- **v9:** adds duplicate transaction-number checks and a unique expression index for active transaction numbers after trimming.

This document previously said schema version 7 after the integration branch had advanced to version 9. That was documentation drift. When changing schema/migrations, update this document and related handoff notes in the same change, and verify the version against `app_database.dart`.

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

## Remaining work and verification warning

This document originated on `feature/process-validation-foundation`. Its original implementation checklist may be stale on the later integration branch. Inspect the actual files and tests before treating any UI/provider item as incomplete or complete.

Known backend work from the last audit of `integration/notaris-stabilization`:

1. Add Go/GORM models and verify them against actual PostgreSQL migrations/schema and the Laravel reference. Do not assume all three schemas match.
2. Implement server-side permission checks and authoritative process transitions, including no self-validation, required notes, and atomic state/history writes.
3. Add meaningful Go tests for authorization, transitions, and transaction boundaries. Earlier `go test ./...` runs reported `[no test files]` for the Go packages, so successful command exit alone did not prove business behavior.
4. Test transaction edits, soft deletion, duplicate submissions, self-validation rejection, revision/resubmission and eventual sync retry behavior.
5. Re-audit Riverpod providers and Monitoring UI on the current integration branch rather than relying on this historical checklist.

## Explicit non-goals

- Do not rewrite transaction business flow.
- Do not change transaction-level status semantics.
- Do not implement the pending tax calculator, PPAT status prototype, document/note screen, invoice or receipt in this phase unless the project scope is explicitly revised.
- Do not treat menu visibility or local checks as authoritative server authorization.
- Do not copy Laravel's page-visit-based unlock behavior into Go.
- Do not start full bidirectional sync before the API contract, authorization, conflict policy, idempotency, delta pull, and deletion semantics are defined and tested.
