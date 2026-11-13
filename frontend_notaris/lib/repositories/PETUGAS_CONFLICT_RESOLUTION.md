# Persistent conflict and recovery foundation

Drift v13 adds only petugas_sync_conflict and its unique unresolved-local index.
The stored scope, mutation ID/JSON, original local snapshot, latest observed local
snapshot, base version, full structured HTTP error, state, note and update time
survive restart. Data comes from actual Go errors.code/errors.current, not a new
response envelope. All 409 variants are retained; only a validated version_conflict
with matching cloud identity and positive canonical ID/version is resolvable here.
Missing canonical rows, mutation_reuse and constraint_conflict remain for operator
investigation. Mutation, dirty flag, identity mapping and cursor are not discarded
when recording a conflict. A conflict blocks ordinary push of that record.

Public repository APIs (extension in the same library as PetugasLocalSyncRepository):
listConflicts, currentLocalSnapshot, holdConflict, chooseServer, chooseLocal,
recoveryStatus. They can be called by a future UI/provider; none starts a sync
timer or is wired into UI/SyncCoordinator. Inspection remains available during
full_resync_required. Decisions require confirmed=true, the reviewed server version
and the complete reviewed local snapshot. Extra local edits require new review.

Freshness uses the existing backend contract: a rejected mutation whose base is
strictly lower than the canonical version can only remain stale while backend
versions are monotonic. Replaying exactly that mutation obtains another 409 with
current canonical state (including tombstones unavailable via legacy GET). A
create collision with expected_row_version=null also cannot update an existing
UUID. Changed server data updates the stored conflict and requires fresh operator
review. No automatic last-write-wins occurs. A version that could succeed on
replay is not used as a freshness probe; this needs a future canonical read
endpoint covering deleted rows. Unexpected acknowledgement blocks recovery.
This assumes the same database/deployment epoch with versions never rewound;
restoring/replacing a database needs an explicit recovery protocol.

Choose server applies the reviewed, revalidated snapshot in one SQLite transaction,
preserving local ID/UUID and transaction references. Original local data remains
in the resolved conflict archive. It does not update the server or advance pull
cursor. A server edit immediately after revalidation can still occur: it remains
in the publication feed for subsequent pull. There is no cross-network lock or
claim of atomic latest-server visibility at SQLite commit.

Choose local preserves the current reviewed local edit, archives the original
conflict, and replaces the rejected pending mutation with a new random mutation ID
using the verified server version. It prepares, but does not automatically send,
that mutation. Later push retains normal optimistic concurrency; another server
edit yields a new persisted conflict, and timeout retries retain the new ID. The
original rejected mutation remains archived. Server tombstones are not resurrected
by upsert; choosing local for that case stays blocked. Reference resolution still
must succeed before any replacement mutation is saved. Other mapping constraints
and scope/pending checks remain enforced. No identity auto-matching is performed.

HTTP 410 keeps the nonzero cursor, journal, dirty data, references, mappings and
transactions. full_resync_required persists in the feed; sync/resolution writes
stay blocked. Backend currently has incremental pull and operator bootstrap, but
no consistent full-snapshot/expired-cursor recovery endpoint. Bootstrap does not
substitute for that protocol. Recovery needs a scoped snapshot token/epoch, a
consistent row snapshot and feed boundary, resumable pagination, retained changes
through completion, and a local merge preserving dirty/pending/conflict data.
No API here clears the block, resets a cursor or deletes local SQLite.

Tests use real on-disk SQLite with restart plus fake HTTP. They do not establish
Flutter-to-Go-to-PostgreSQL end-to-end behavior. Production deployment, manual
operator decisions, full-resync protocol and UI activation remain separate work.
