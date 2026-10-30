# Inactive Petugas sync foundation

The lazy petugasSyncApiProvider uses authenticatedDioProvider, preserving the
configured base URL, JWT interceptor and timeout options. No timer, coordinator,
UI or automatic invocation is installed. Calls use the actual Go sync envelope.
PetugasSyncFailure distinguishes HTTP 400, 401, 403, 409, 410, 422, timeouts,
network failures and server failures; 409 retains the structured canonical error.

Drift schema 11 adds two private SQL journal tables via additive onCreate/upgrade
DDL. petugas_sync_journal keeps acknowledged row versions and exact pending
mutation JSON plus the local snapshot. petugas_sync_feed keeps a deployment/account
scope, cursor and persistent full-resync block. These tables are intentionally
accessed through parameterized custom SQL, without modifying generated table
models or existing Petugas/transaction tables.

Construct PetugasLocalSyncRepository with a stable deployment + account scope
and an explicit PetugasSyncReferences resolver. Scope cannot be silently changed
on an already bound database. The existing identity map itself is not scoped;
switching account/deployment requires a separate database or an explicit reviewed
reconciliation/reset workflow. Multiple repository instances sharing AppDatabase
are serialized in-process. Do not use multiple SQLite connections/isolate writers
to invoke this foundation concurrently; a future multi-process runner needs leases.

Push requires an explicitly registered local_only, verified or server_only mapping.
Unclassified records, ambiguous records and development seeds are blocked. New
cloud UUIDs are separate random identities saved in the pending request. The
entire pending request survives timeout/restart unchanged; never replace it with
another mutation ID just because the local record changed. Acknowledgement records
the server version and map but only clears dirty if all persisted snapshot fields
still match. Local ID and UUID are never rewritten. Canonical response values are
validated for identity/version; acknowledgement never overwrites a concurrent edit.

Pull is blocked while any mutation is pending (avoids creating a duplicate local
identity for a timed-out create). Each historical page, mappings, versions and cursor
commit in one SQLite transaction. Dirty rows or missing references abort that page
without cursor advancement. Old versions of clean mapped rows are idempotently
ignored. New cloud rows get new local identities; tombstones preserve existing
identity/transaction references. No matching by name/email/NIK is performed.

Non-null gender IDs require explicit local/server resolution. user_id must be a
verified server user ID; no user is created or matched automatically. Schema 12
adds VerifiedPetugasReferences with operator-confirmed deployment-scoped gender
mapping and authenticated server-user provenance. See PETUGAS_REFERENCE_RECONCILIATION.md
for evidence requirements and the still-missing automatic gender catalog contract.
Verified legacy mappings can establish their version through explicit
PetugasIdentityReconciliation confirmation; it never clears dirty local data.

HTTP 409 leaves the pending snapshot and dirty record intact for a future explicit
conflict-resolution workflow. HTTP 410 persistently blocks sync pending a future
full-resync workflow; the cursor is never reset. No conflict UI or resync reset API
is provided. Never clear receipts/cursors ad hoc to make requests proceed.

Before manual end-to-end testing: deploy backend migrations, run bootstrap, drain
publication explicitly (there is no automatic publisher scheduler), provide the
reference resolver and stable authenticated scope, and reconcile legacy/seed data.
Fake HTTP + real in-memory SQLite tests exercise this foundation; live Flutter-to-Go
testing and UI activation are outside this checkpoint.
