# Notaris/PPAT Stabilization: Git Workflow and Hard-Won Lessons

> Living handoff document for future contributors and future AI sessions. Read this before changing branches, database migrations, sync behavior, or the backend API.

## Current checkpoint

- Repository: [Tmichael86/notaris-flutter](https://github.com/Tmichael86/notaris-flutter)
- Stabilization branch: `integration/notaris-stabilization`
- Last recorded integration checkpoint: `956bbe5` (`merge: integrate notaris stabilization`)
- `main` was intentionally left untouched. Do not promote or merge into `main` without explicit approval.
- Laravel reference repository: [Tmichael86/backend-notaris-laravel](https://github.com/Tmichael86/backend-notaris-laravel)
- Flutter app: `frontend_notaris`
- Go API: `backend-notaris-go`
- Local persistence: SQLite through Drift; intended remote persistence: PostgreSQL.

This is a documented checkpoint, not a claim that every command has been rerun against the current checkout. Verify the actual branch, HEAD, and working tree before continuing.

## The hard-won lessons

### 1. A branch name is not a branch's ancestry

The feature and fix branches in this project have been used as **stacked branches**. A branch may contain earlier work because it descends from another feature branch. It is not necessarily an independent change based on `main`.

Before merging, rebasing, cherry-picking, deleting, or opening/changing a PR:

1. Inspect the current branch and HEAD.
2. Inspect the commit graph and compare base/head relationships.
3. Identify which commits are unique to the branch and which are inherited.
4. Preserve the intended stack and PR base relationships.
5. Do not infer ancestry from names alone.

A plausible-looking branch name is not evidence of a safe merge. Git will happily let humans be confidently wrong.

### 2. Integrate in a sandbox before touching `main`

`integration/notaris-stabilization` is the place to assemble and verify the accumulated changes before promotion. Keep `main` untouched until the user explicitly approves promotion.

At the last recorded checkpoint, the integration branch was pushed at `956bbe5`. The local working tree was reported clean at that time. Those are historical facts; inspect the current remote and local state before assuming they remain true.

### 3. Resolve conflicts by preserving behavior, not by blindly choosing a side

The integration merge produced a conflict in `frontend_notaris/test/widget_test.dart`. The resolution preserved the meaningful desktop login test and overrode the auth provider for the test. A related Material ancestor issue around `CheckboxListTile` also had to be corrected.

Lesson: a conflict-free compile is not enough. Keep the test's intent, make its dependencies explicit, and rerun the relevant test and the complete suite. Do not use “accept ours/theirs” as a substitute for understanding the widget or provider behavior.

### 4. Documentation can silently become a lie

The process-validation implementation note still described Drift schema version 7 after the integration branch had advanced to schema version 9. That mismatch is documentation drift, not a harmless typo: it can mislead future migration work and AI-assisted changes.

When a schema migration lands, audit and update:
- schema version references in docs;
- migration history and test fixtures;
- table and index descriptions;
- implementation checklists that may now be stale.

Treat schema numbers in docs as claims that must match `frontend_notaris/lib/database/app_database.dart`.

### 5. The Laravel app is a behavioral reference, not automatically the Flutter API

The Laravel repository is the legacy business-behavior and schema reference. Its transaction functionality is largely implemented through session-based web routes under `routes/web.php`, with authentication/session middleware. The current `routes/api.php` does not expose a complete transaction REST API for Flutter.

Do not point Flutter at the Laravel web routes and assume they are a stable REST contract. Extract and document the required behavior, request/response shapes, authorization rules, and data relationships, then implement an explicit API contract in Go.

When investigating Laravel behavior, inspect the actual route, controller, model, and migration together. Do not infer behavior from a route name or a single model file.

### 6. A sync service existing in the repository does not mean sync is ready

At the last GitHub audit on the stabilization branch:
- there was no registered `GET /api/v1/transaksi` endpoint;
- the Go sync controller/service existed but were not wired into the running route setup;
- the draft sync shape covered only a small transaction-header subset;
- authentication/authorization integration, conflict policy, delta/cursor semantics, relational details, payment history, process validation/history, and deletion semantics were not yet a complete sync contract.

Do not start “bidirectional sync” merely because a `sync_service.go` file exists. First establish a secure, tested contract and explicit ownership/conflict rules. An endpoint that moves incomplete or unauthorized data faster is not progress.

### 7. Local validation is not server authorization

The Drift process repository enforces local transition rules and writes the state change plus audit history in one local transaction. The local actor ID is supplied by the caller, so local checks are not a security boundary.

The Go service must independently enforce authenticated identity, permissions, legal transitions, no self-validation, required notes, and atomic state-plus-history writes. Never trust client-supplied actor identity as proof of authorization.

The agreed process flow is:

- `belum_dikerjakan -> dalam_pengerjaan`
- `dalam_pengerjaan -> menunggu_validasi`
- `menunggu_validasi -> valid`
- `menunggu_validasi -> perlu_revisi`
- `perlu_revisi -> dalam_pengerjaan`

Submission for validation and requesting revision require a non-empty note. The submitter cannot validate or request revision on their own submission. Legacy rows with a null normalized status must be explicitly initialized to `belum_dikerjakan`; do not invent historical transitions.

### 8. UUIDs, snapshots, and soft deletion are part of the data contract

The local schema has transaction headers, transaction details, normalized process rows, process history, and payment history. Transaction details have stable UUIDs and can represent multiple jobs under one transaction. A transaction is handled by one staff member. Names/prices and process definitions may be snapshotted to preserve historical meaning.

Do not model a transaction as only `uuid + no_akta + total + pemohon_uuid` and call the sync problem solved. Before syncing, reconcile:
- stable UUID identity and legacy IDs;
- transaction header/detail/process/payment relationships;
- snapshot fields versus master references;
- soft-deleted rows and deletion propagation;
- audit metadata and actor identity;
- idempotency, retries, conflicts, and pull cursors.

Do not assume the Go GORM model, PostgreSQL schema, local Drift schema, and legacy Laravel schema are identical. Verify migrations and actual columns before writing mapping code.

### 9. Green tooling output has a scope

The last recorded integration validation was:
- Flutter analyzer: no issues reported;
- Flutter tests: 25 passed;
- Go `go test ./...`, `go vet ./...`, and `go build ./...`: commands exited successfully.

Important qualification: the Go packages reported `[no test files]`, so successful Go commands did **not** establish broad backend business-rule coverage. Add meaningful tests for API authorization, process transitions, transaction boundaries, sync idempotency, and conflicts.

GitHub file/commit operations do not run Flutter or Go tests. After code changes, run the relevant checks in a real development environment and report what actually ran.

## Architecture and implementation facts to preserve

- Flutter desktop/mobile app uses Flutter, Riverpod, Drift/SQLite, and generated code.
- The app is local-first. Offline behavior is intentional, not a temporary network-error fallback.
- Online authentication provides server-controlled sidebar permissions. Remember-me offline login was implemented with a seven-day local credential/session cache; server-side permissions still remain authoritative online.
- Master data feeds transaction forms. Job/price/category snapshots must remain coherent when a transaction is edited.
- A transaction may contain multiple jobs/details but has one assigned staff member.
- Transaction-level statuses include `Baru`, `Dalam Proses`, and `Selesai`; do not conflate them with individual process states.
- SQLite migrations and generated schema snapshots are high-risk areas. Test upgrades from the previous supported version, not only fresh database creation.
- Preserve the shared desktop shell and mobile navigation conventions while adding pages.

## Agreed next direction

Do not begin full bidirectional sync as the next step. The safer sequence is:

1. **Audit and document the data/API contract.** Compare Drift schema v9, Go GORM models/migrations, and the Laravel routes/controllers/models/migrations. Resolve UUID mapping and field compatibility first.
2. **Implement server-authoritative process validation in Go.** Add authorization, allowed transitions, no-self-validation, required notes, atomic history writes, and meaningful tests.
3. **Add a protected read-only transaction REST vertical slice.** Define list/detail responses, pagination, relations, permissions, and error behavior before wiring Flutter to it.
4. **Design sync after the contract is trustworthy.** Define idempotent push, incremental pull, conflict policy, retry behavior, soft-delete propagation, and handling for details, payments, processes, and history.
5. **Polish UI after the data and behavior contracts stop moving.** Avoid spending time decorating a room whose plumbing is not installed.

The order of steps 2 and 3 can be adjusted after the schema/API audit, but the audit comes first.

## Working protocol for the next session

Before editing:
- confirm the active branch, HEAD, and clean/dirty status;
- inspect ancestry and PR base/head if branches are involved;
- read the current implementation and its tests, not just this note;
- use the Laravel repository as a reference, not as proof that a REST endpoint exists;
- state the intended scope before making a broad change.

After editing:
- run targeted tests, then the relevant full checks;
- inspect the diff and ensure generated files/migrations are intentional;
- update docs in the same change when schema, routes, behavior, or status changes;
- commit/push only to the intended branch;
- do not merge into `main` without explicit approval.

## Related documentation

- [Process validation implementation](process-validation-implementation.md)
- [Flutter app database schema](../frontend_notaris/lib/database/app_database.dart)
- [Go API routes](../backend-notaris-go/routes/routes.go)
- [Laravel API routes](https://github.com/Tmichael86/backend-notaris-laravel/blob/main/routes/api.php)
- [Laravel web routes](https://github.com/Tmichael86/backend-notaris-laravel/blob/main/routes/web.php)

---

Last updated: 2026-10-15
