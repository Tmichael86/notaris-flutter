# Petugas sync HTTP checkpoint

PUT /api/v1/petugas/sync/:uuid accepts the existing PetugasMutation JSON:
mutation_id, petugas_uuid (equal to the path), operation (upsert/delete),
expected_row_version (null for create), and payload (required for upsert,
absent for delete). Payload fields follow PetugasPayload; references are
jenis_kelamin_id and user_id from this server. Unknown JSON fields, malformed
identifiers, trailing JSON, and bodies exceeding 1 MiB are rejected.

JWT plus current active user/group/menu read permission is mandatory. Create,
update and delete additionally require the corresponding Petugas permission.
As with legacy CRUD, the data is shared among authorized Petugas readers, not
filtered by user_id (which links an account, not ownership). No tenant/owner
scope exists in this schema; do not enable this API for an assumed multi-tenant
deployment without an explicit scope model.

Success uses the existing success/message/data envelope with acknowledgement
and record. The record is the exact acknowledged version from historical outbox,
including on retry after later mutations. It omits actor audit metadata. HTTP
409 errors contain code version_conflict plus current canonical record, or
mutation_reuse/constraint_conflict. Invalid references return 422. Unexpected
database errors return generic sync_failed; SQL errors are never returned.

GET /api/v1/petugas/sync/pull?cursor=0&limit=100 returns data.changes,
next_cursor and has_more. Limits are 1..500. Invalid/future cursors return 400
with code invalid_cursor; expired cursors return 410 with cursor_expired.
Historical snapshots and tombstones come from the publication repository.
Keep acknowledged outbox snapshots as long as mutation receipts may replay;
future retention must preserve replay data or extend stored receipts.

Bootstrap is available as PetugasPublicationRepository.Bootstrap for an explicit
deployment/admin workflow. It holds SHARE ROW EXCLUSIVE on Petugas, captures rows
without a matching current-version outbox event, and appends canonical snapshots
in the same transaction. All writes either finish before capture or append their
next version afterward. Retrying bootstrap does not duplicate existing events.
Publish the resulting outbox normally; no MAX(sequence) cursor is fabricated.
PostgreSQL tests verify both bootstrap/write lock orders and baseline HTTP pull.
Run bootstrap then drain publication before initial cursor=0 client sync.
No automatic bootstrap or administrative HTTP trigger is installed. This baseline
requires retained history; retention/full-resync for expired clients remains a
future contract. Large datasets may require a different snapshot strategy to avoid
a long table lock. No Flutter client or publisher scheduler is activated.

Legacy routes and their permission/validation code remain intact. The HTTP
integration test uses the real router, JWT and database-backed permission checks
against a unique schema on an explicit test DSN; it never loads application .env.
