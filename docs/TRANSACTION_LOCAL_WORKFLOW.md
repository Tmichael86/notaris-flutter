# Local Transaction workflow readiness

Checkpoint 2026-11-03, branch `feature/pemohon-cloud-sync`.

Notaris and PPAT forms select local Pemohon, Petugas and the matching local
Pekerjaan aggregate. The chosen category/price/estimate and process checklist
are snapshots in Drift transaction detail; process snapshot now carries Master
attributes too. Search/reopen reads saved transaction rows, not demo picker data.
On edit of the same Master job, the form preserves the selected snapshot rather
than silently replacing price/category/estimate/process data with newer Master
values. Changing the chosen job explicitly loads new Master values.

Repository `save` validates active local Pemohon/Petugas and matching UUIDs, and
active Master job of the requested type, inside the existing atomic transaction.
It refuses cross-type references. Header, detail, process and first payment
history are committed together. Edits retain matching detail UUIDs and payment
history. Existing local number generation and unique index protect duplicate
numbers; no server numbering or cloud contract is claimed. Payment history UI
is read-only. Process validation is local only; server authorization remains
future work.

Tests use disposable SQLite (memory and one temporary file). Focused transaction
tests: 15 passed, including file reopen persistence.
Flutter analyze clean. Full regression: 362 passed, 3 opt-in skipped, 0 failed.
No development/daily SQLite or PostgreSQL mutation was performed by this work.

## Manual acceptance preparation

Development launcher: `scripts/run-notarisdev-flutter.ps1 -UiSmoke` from repo
root. It targets the existing generation-scoped notarisdev SQLite under Roaming
AppData, never the daily Documents database. Smoke guard disables startup/resume
and global synchronization; HTTP business mutations are blocked. Local Drift
CRUD remains enabled. Use existing backend only for online login, publisher OFF.

Before manual CRUD, close Flutter and other writers. Verify exact profile path,
WAL/SHM state and baseline counts. Make a fresh backup using SQLite's backup API
while holding a source read handle that denies writers, then reopen the backup
read-only and check integrity_check, foreign_key_check, schema, table counts and
SHA-256. Never copy only the main file while WAL is active or force checkpoint.
Existing backup helper/evidence pattern: `.local/master-crud-ui-backup-20261103-090154/`.
Retain that earlier backup; make a new one for the current state before testing.

Create one synthetic Notaris and one PPAT Master job if their manual-acceptance
records were soft-deleted. Choose one actual local Pemohon, one Petugas, a valid
category/price, and a process with an attribute. Create each transaction with
different generated local number and a small initial payment. Search/reopen;
check job type, snapshots, process/attribute and payment history. Edit one
transaction and reopen; verify detail identity and one unchanged initial payment.
Close/restart Flutter, search/reopen both again, and check Pemohon/Petugas counts.
Do not delete or alter existing non-synthetic records. No Cloud Sync Transaksi,
publisher or global sync is authorized by this checkpoint.
