# Local Recycle Bin MVP

System > Recycle Bin reuses MasterDataViewport, the System white card and the
existing desktop shell. It lists soft-deleted Pekerjaan Notaris, Pekerjaan PPAT
and both Transaction domains, newest deletion first. Module filters, identity,
name/number, deletion time, confirmation, loading/error/empty states and a local
restore history are included. There is no hard delete or retention policy.

## Restore contract

- Discovery requires the source module's read permission. Restore rechecks read
  and update permission, selected PK/UUID/domain and deletion state inside a
  SQLite transaction. No new backend permission is invented.
- Masters use status=0 plus deleted_at; restore recovers the parent and proven cascade children.
  Aggregate delete captures the exact child IDs/UUIDs/statuses in the existing
  recovery log. Restore clears only those cascade tombstones in the same SQLite
  transaction; previously removed children remain deleted. Missing or mismatched
  provenance blocks recovery. Active category/process ownership is validated.
- Transaction delete previously overwrote the business status with Dihapus and
  tombstoned its current details. New deletes atomically capture the exact prior
  status, cascade detail UUIDs/statuses and deletion timestamp. Restore uses that
  evidence only. Older deletions without it remain visible but blocked; no prior
  business status is guessed.
- Only details captured in that exact delete are restored. Earlier detail/process
  tombstones stay deleted. Applicant/officer ID+UUID, job domain/ownership and
  available price/category provenance must still be valid and active.
- PKs, UUIDs, business numbers, historical snapshots, processes, process audit and
  payments are retained. No payment is regenerated and no current Master values
  overwrite a historical snapshot. Restored rows are locally dirty.
- Cloud identity, pending/ACKED mutation, lastSyncedAt or synchronized child evidence
  blocks local restore. No server calls, receipt changes, cursor advances or
  implicit pushes occur. Proper cloud RESTORE with expected revision, durable
  receipt and publication is a separate, unimplemented contract.

## Small storage upgrade

Drift v18 -> v19 adds **one** private table, recycle_bin_events, for deletion
provenance and actual restore outcomes. Existing business/sync tables and data
are not rewritten. Success audit commits with restoration; failure audit is
written after data rollback, using fixed error codes rather than exception text,
credentials or personal payloads. Attempts are visible in Histori pemulihan.
This is local recovery history, not a fake successful cloud sync log.

Only disposable SQLite is used in validation. Existing development/daily SQLite
has not been opened or upgraded. Before manual acceptance on an existing profile,
perform the separately reviewed backup/upgrade step; launching the new app would
apply v19 automatically. PostgreSQL is unaffected.

## Manual acceptance on a disposable profile

Use the already reviewed isolated Windows debug entry and disposable manifest
documented in TRANSACTION_MONITOR_ISOLATED_UI.md. Do not point it at existing
development/daily data. Use synthetic local aggregates that have **never** been
uploaded or queued for cloud mutation, with valid local dependencies.

1. Create then soft-delete one local Master per domain and a Transaction per
   domain through existing forms. Keep their UUIDs, numbers and payment count.
2. Open System > Recycle Bin, filter each module and confirm Restore. Cancel must
   do nothing. Check restored source lists, same identity and unchanged snapshots,
   payment/process history. Reopen/restart the same disposable profile.
3. Review Histori pemulihan. Revoking permission or invalidating a dependency
   before confirmation must fail without partial changes.
4. A cloud-synced tombstone stays disabled with its reason; old Transaction
   deletions lacking status provenance are also disabled. There is no workaround
   button to enable cloud RESTORE or global synchronization.

Automated coverage uses SQLite memory/file fixtures: both domains, preservation,
permission/reference rejection, transaction rollback, cloud barriers, migration,
restart, UI confirmation/cancel/filter/loading/error states and narrow desktop.
