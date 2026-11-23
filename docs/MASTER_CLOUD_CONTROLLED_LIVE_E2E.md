# Notaris + PPAT controlled live E2E — prepared, not authorized

This procedure is for a later, separately approved test on `127.0.0.1:5432/notarisdev`. No step in this document authorizes a live write. Preserve `.local/combined-cloud-preflight-20261103/apply-attempted.lock`; never rerun migration or publish the legacy Notaris row by inference.

## Before the approved test

Use only the existing `scripts/run-notarisdev-backend.ps1` launcher with background Petugas publisher OFF. Authenticate as the existing Fixture Operators account (group 11), and verify its Notaris and PPAT sidebar permissions. Use two **new disposable** SQLite files with `AppDatabase.forTesting(NativeDatabase(...))`; seed only the verified active server Kategori UUID `fa000002-0000-4000-8000-000000000001` as a clean local reference. Do not open the existing Flutter development profile or daily SQLite. Read-only baseline: server Notaris 1 legacy parent, PPAT 0; both Master outboxes/mutation receipts 0, cursors 0; retain the 16 legacy fingerprints and backup from the combined migration receipt.

Give each test aggregate a fresh random UUID, child UUIDs and three fresh mutation IDs. Use unmistakable names such as `E2E-MASTER-NOTARIS-<run-id>` and `E2E-MASTER-PPAT-<run-id>`, and record all UUIDs in a private receipt. Never match the legacy Notaris by name or integer ID.

## Approved write sequence (not executed here)

1. Device A local SQLite creates one Notaris and one PPAT aggregate with one harga, one proses and one atribut each. Their cloud repositories make authenticated HTTP CREATE requests. Check server parent/children, revision 1, one durable receipt and one pending complete-aggregate outbox event per domain.
2. Publish both pending events with the bounded manual runner, then Device B performs authenticated incremental GET/pull from cursor 0. Verify one unique aggregate per feed and cursor 1. Repeating pull returns 0.
3. Device A performs one UPDATE per domain, retaining child UUIDs; check revision 2 and one additional receipt/outbox event per domain. Publish boundedly; Device B pulls cursor 1→2 and verifies the aggregate snapshot.
4. Device A performs one soft DELETE per domain; check revision 3 and one tombstone event per domain. Publish boundedly; Device B pulls cursor 2→3. Replay from cursor 0 on disposable SQLite produces no duplicate, while dirty local records are protected.
5. Read-only postcheck: exactly 2 new synthetic parent rows total (Notaris +1, PPAT +1); 3 mutation receipts and 3 published events per domain; no pending; sequences 1–3, `last_seq=3`, `min_cursor=0` per feed; correct child UUIDs, FK/integrity, permissions and legacy fingerprints. The original Notaris row keeps its UUID/revision and is not published. Keep HTTP/SQLite/SQL receipts. Stop on any ambiguous commit; no automatic retry or restore.

Each publication is a separate, explicit call after the corresponding HTTP mutation phase. The feeds are independent; a successful Notaris batch does not imply PPAT has committed. Publisher retry selects only rows with null `publication_seq` and never allocates a second sequence for an already published event.

## Manual publisher commands

From the repository root, default dry-run only (read-only):

```powershell
& .\scripts\invoke-notarisdev-master-publisher.ps1 -Domain both -BatchSize 2 -MaxBatches 10 -TimeoutSeconds 60
```

Only after separate approval for the controlled live E2E, run once per planned publication phase and save stdout as a receipt:

```powershell
& .\scripts\invoke-notarisdev-master-publisher.ps1 -Apply -LiveApproved -ConfirmTarget '127.0.0.1:5432/notarisdev' -Domain both -BatchSize 2 -MaxBatches 10 -TimeoutSeconds 60
```

The runner reads only `.env.notarisdev`, checks the restricted app role and synthetic marker, and starts no background worker. `cmd/masterpublish` has a whole-operation timeout and bounded batches; it emits published count, remaining count and cursor per domain. It never opens a Flutter database. Its `--apply` flag is deliberately unavailable on permanent notarisdev without `--live-approved` and exact target confirmation.
