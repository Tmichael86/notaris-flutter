# Legacy relationship and synthetic fixture review — 30 October 2026

Scope: follow-up to 0c11b3f; no clone, database creation, data migration or source
repair. Findings below distinguish observed SQL results from source intent and
recommendations. All new diagnostics are aggregate-only and read-only.

## What can actually be concluded about the 7058 detail rows?

| Question | Evidence and conclusion |
| --- | --- |
| Where are the rows stored? | public.transaksi_detail_proses, 7058 rows with 7058 distinct non-null UUIDs. |
| Intended parent/key? | DATABASE_STRUCTURE.md:522-543 declares transaksi_id -> transaksi.id; the actual detail column is bigint. This is documented intent, not an enforced server FK. |
| Parent coverage now? | 1879 distinct transaksi_id values, range 1..3241. Current transaksi has zero rows. Numeric archive join finds 289 detail rows on 51 transaksi_old IDs; 6769 match neither table. |
| Does the archive explain all details? | No. Archive has 130 rows; numeric matches do not establish lineage. Do not relink even the 289 automatically. |
| Related history? | transaksi_materai has 5435 rows, 0 current-parent matches, 213 archive-ID matches. Of 2242 payment rows, 0 match current no_akta, 80 match archive no_akta. Document number equality is only a candidate link, not verified identity. |
| Process master link? | Every jenis_pekerjaan_id exists in pekerjaan_jenis. prosesId matches only Notaris master in 1914 rows, both Notaris and PPAT numeric IDs in 4525, neither in 619. A join on prosesId alone is ambiguous; intended master also depends on job type and possibly historical/manual definitions. |
| JSON shape? | All 7058 atribut values are JSON arrays; contents were not exported. Generator needs an approved array template; do not convert to object by assumption. |
| Database enforcement? | No public FK constraints. No noninternal triggers on detail or archive. These facts do not prove when or by whom rows were created. |

Diagnostics: scripts/sql/review-legacy-transaksi.sql:1 opens REPEATABLE READ READ
ONLY, sets timeouts, returns aggregates and migration *names* only, and rolls
back. scripts/review-legacy-transaksi.ps1 fixes connection to localhost:5432 /
notarislokal and restores credential-related environment without printing values.
notarisdev was absent and the source remained accessible during this review.

### Provenance limitations (do not label these rows corrupt)

The migrations ledger includes 2024_05_31_063508_transaksi and
2024_11_02_012533_transaksi_detail_proses. No archive-creation/rename entry appears
in that ledger. Ledger names are metadata, not the original migration source or
proof of every SQL operation ever executed. The repository does not supply the
historical Laravel producer/controller/migration implementing these relationships.
No query here can recover deleted/moved parent records or prove a past rename.

The evidence is compatible with incomplete historical import, archival outside
the tracked migrations, or a previous application lifecycle. None is proven.
The answer to “which historical table originally produced all 7058 rows” is
**unknown with the available source and database snapshot**. The documented
parent is transaksi; the actual historical parent population is not established.
Needed evidence: legacy application models/queries and original migrations,
archive/rename/import scripts and a provenance inventory of older backups.
Review those locally; do not restore raw personal data for this investigation.

### Current Go and Flutter are not the historical producer

- backend-notaris-go/models/transaksi.go:5-18 maps Transaksi to transaksi.
  It contains pemohon_uuid, but the running server table lacks that column.
- backend-notaris-go/services/sync_service.go:24-69 only creates/upserts transaction
  headers by UUID and reads transaksi. It does not write detail rows or query
  transaksi_old. No Go model/repository for transaksi_detail_proses was found in
  the current application source searched. Existing Go SQL migrations only add
  Petugas sync foundation; they do not rename/remove transaction parents.
- frontend_notaris/lib/database/app_database.dart:42-180 declares local
  transaksis -> transaksi_details -> transaksi_proses, including a stable
  transaksiDetailUuid, plus local payment rows keyed by transaksiId. That is NOT
  a one-to-one schema mapping to PostgreSQL transaksi_detail_proses.
- frontend_notaris/lib/repositories/transaction_repository.dart:113,195,385,473
  saves header/jobs/process snapshots in a SQLite transaction. Local UUIDs and
  Petugas references are retained through edits; it does not populate the server
  legacy detail table.
- frontend_notaris/lib/repositories/transaksi_proses_repository.dart:175-205
  verifies active job UUID, transaction ID and parent presence before transitions.
  Drift declares references; actual SQLite FK PRAGMA enforcement was not tested
  in this review. Repository-level checks are separate from database enforcement.
- frontend_notaris/lib/services/sync_service.dart:18-57 imports headers, not the
  server detail hierarchy. Its default absolute LAN base URL is another legacy
  integration risk; do not use that service to infer legacy row provenance or
  enable a new development profile without checking which coordinator calls it.

The application can manage relationships without PostgreSQL FKs through query
filters, domain validation and transactional writes. Current Flutter demonstrates
that pattern; it does not prove the absent historical producer used identical rules.

## Synthetic fixture design (not generated or loaded)

Use a fresh development generation and the complete reviewed 38-table schema-only
archive. Review default expressions, extension ownership and functions before
restoring schema. Never use a raw data clone as the starting point. Every row
below is synthesized from constants/PRNG rules and approved aggregate volumes,
not source names, identifiers, documents, financial values, hashes or tokens.

### Separate profiles instead of pretending incompatible goals are identical

1. **consistent-smoke**: small, valid relational graph for normal login, Petugas
   migration/CRUD/sync and SQLite identity tests. Four Petugas, six users, two
   gender master rows, at least two groups and both Notaris/PPAT job hierarchies,
   20 Pemohon, 16 current transaction headers, 64 server process rows; two archive
   examples are explicit fixtures, not alleged recovered originals.
2. **consistent-volume**: 2070 synthetic Pemohon, 4 Petugas, 6 users, 1879 current
   parent headers and 7058 process rows, plus 130 independent archive examples.
   Each parent gets three process rows (5637 total), the first 1421 get a fourth:
   5637 + 1421 = 7058. Match selected business volumes (2242 payments, 5435 stamp
   links) through generated relationships. Current parent count deliberately
   differs from source's zero: valid relationships and exact source shape cannot
   both be achieved here. Obtain supervisor approval for this explicit difference.
3. **legacy-shape-negative**: separate offline fixture/test dataset emulates zero
   current parents, 1879 referenced parent values, partial archive matches and
   unresolved process IDs, solely to verify migration does not rewrite/delete
   history or invent relationships. Never overlay on the normal dev dataset or
   feed into active transaction sync. It contains synthetic values only.

Other 38-table volumes are recorded in ignored .local/notarisdev-review-*/
table-counts.json. Use them as sizing targets only; don't copy source rows or
assume random independent counts form a coherent financial/relational graph.

### Generation order and explicit links

1. Generate fixture master IDs first: types/status/payment/gender, group and sidebar
   permission graph. Suggested server IDs: gender 11/29, users 2001..2006, Petugas
   101/103/107/109. Deliberately use different SQLite IDs (e.g. 1/2 for gender).
   Fixture manifest explicitly declares job-type codes, not inference from names.
2. Users reference generated group IDs. Fresh bcrypt hashes (backend-notaris-go/
   services/auth_service.go:41 uses bcrypt comparison), generated per-account test
   secrets saved only locally, no shared source hash. Operator, reviewer and
   read-only identities test existing permission middleware. No JWT preloading:
   obtain JWT/permission by normal login. Sessions/reset/token/job-error tables
   start empty; no attempt to preserve sensitive auth-row volume.
3. Petugas reference the generated server users or NULL and the fixture gender
   master. All start active for the baseline; deletion tests create a dedicated
   additional record later. Contact fields use reserved synthetic email domains,
   clearly marked names/addresses, synthetic NIK values passing local validators
   and non-deliverable telephone placeholders; no external contact is attempted.
4. Generate Pemohon, job/category/pricing/process/attribute masters. Every process
   key includes job type + process ID; same numeric ID in two master tables is
   intentional test coverage, never reason to combine them. Retain fixture PKs
   across rebuilds of the SAME manifest, not source record IDs/identity mappings.
5. Generate transactions with Petugas/Pemohon/status/job/tax/payment references,
   then process rows with matching parent, job type and master. Snapshot labels
   come from fixture masters. atribut is a typed synthetic array; preserve JSON
   field types by an approved contract, not by copying source payloads.
6. Generate synthetic document identifiers via one manifest dictionary reused by
   payment/print no_transaksi links. Fill all server required header columns, not
   merely the limited GORM fields. Generate dates from an artificial base, amounts
   from whole synthetic units; recompute payments, discounts, balances and stocks.
   Duplicate installment links allowed, duplicate unique document keys rejected.
7. Populate archive/copy tables from separate synthetic examples, never move or
   delete active fixture parents implicitly. Configure office identity, invoices,
   audit users and free text synthetically. Empty sessions, reset tokens, personal
   tokens and failed jobs. Preserve schema for all unused tables, even if empty.
8. Validate all proposed/implicit edges before enabling clients, plus per-type
   process resolution, required/non-null/unique domains and sequence next values
   greater than max fixture PK. No source-PII-derived UUID/hash/label generation.

### Sync-state lifecycle and offline-first matrix

Load baseline legacy-shaped Petugas BEFORE future approved identity migration;
after that migration every integer PK stays unchanged and server UUID is random,
row_version=1, deleted_at=NULL. Assigned UUIDs must survive rerun/rollback; do not
seed UUID from PK or use dev-* cloud identity. Generate other entity UUIDs freshly
and keep all UUID references in the manifest consistent. Server generation change
requires a fresh isolated SQLite profile, never copying daily identity maps/cursor.

Receipts/outbox initially empty, publication singleton last_seq/min_cursor=0 on
a fresh database. After approved bootstrap, baseline events come through the
existing locked repository; do not invent receipts or hand-number publication
sequences. Publisher serializes committed publication using its transactional
counter. Mutation UUID, Petugas UUID, row_version and pull cursor stay distinct.

Then test via actual mutation/CRUD repositories and HTTP (not static fabricated
acknowledgments): create v1; update v2; stale expected version -> 409; replay same
mutation -> same receipt with one outbox event; concurrent CRUD/sync; delete ->
tombstone with incremented version. Retain transaction Petugas integer links.
Two new SQLite profiles intentionally use different local IDs/UUIDs and explicit
verified identity/reference mappings. Include local-only, server-only, ambiguous,
dev-seed blocked, local edit during push, pull retry, restart and 410 blocked state.
No real tokens from either profile/server are copied. Invalid references belong
to negative fixtures only; the baseline has zero unresolved active edges.

The broader transaction sync contract is NOT ready merely because Petugas sync
passes: Go's missing pemohon_uuid/required header fields and the different Flutter
job hierarchy need a separate design. Petugas-only tests can preserve synthetic
transaction links without claiming transaction/process end-to-end coverage.

## Migration proposal review and categories

**Required for Petugas sync**: preserve integer PK/user/gender links; random UUID
identity/default/uniqueness; row_version optimistic concurrency; status/deleted_at
tombstone; mutation receipt + outbox atomicity; serialized publication counter,
historical payload and cursor bounds; controlled bootstrap and reference/identity
reconciliation. CRUD compatibility requires all foundation phases before running
the current Go Petugas writer. Full rollback to an old writer would stop journaling:
keep writes OFF until a compatible writer is deployed, then reconcile/bootstrap.

**Recommended, separately reviewable**: future named CHECK constraints on positive
versions/publication pairing, index-definition assertions (not just index name),
schema migration ledger/checksums, least-privilege roles, full source fingerprint
and object definition preflight, bounded lock timeouts, fixture integrity scanner,
explicit timezone handling, FK additions only after each edge's semantics are known.
Do not add global email/NIK uniqueness or legacy FKs to make tests green.

**Supervisor approval required**: real historical parent semantics, any archive
relink/repair, transaction/process schema/API changes, source personal-data export,
sanitization manifest, synthetic-volume parent-count difference, DB/role provisioning,
actual migration execution and publication/client activation. None authorized here.

Revised proposal is first-install-only and fails if sync foundation objects already
exist; partial installation recovery must inspect phase/object definitions. It
checks target DB, existing sync-column types and server references before DDL.
Session search_path and bounded timeouts cover all included files (SET LOCAL
previously ended at the first COMMIT). The phase-1 table lock does not protect phases 2/3;
all writers/client/publisher must remain in maintenance through the entire rollout.
Existing migrations and API behavior are not changed by this review.

Phases: identity/receipt/outbox -> publication counter -> UUID hardening -> validate
objects/IDs/relations -> locked bootstrap -> controlled publisher -> manual clients.
If a phase fails, stop access, capture object definitions and reconcile that phase;
do not re-run the whole first-install proposal or reset counters. Retain UUIDs and
events; no destructive down migration. Historical transaction/detail rows must
remain byte-for-byte unchanged by the Petugas migration, checked with private
test-fixture checksums and PK/reference counts in the eventual isolated tests.

## Next provisioning proposal (needs approval, not executed)

Approve consistent-smoke and consistent-volume manifests first. Build/test a pure
synthetic generator plus schema/edge validator without touching either live DB.
Review complete schema archive/extension permissions; recheck target absence;
create notarisdev once with a restricted application role; restore reviewed schema
without --clean/--create; load synthetic baseline; apply reviewed Petugas migrations
under maintenance; verify old CRUD and bootstrap before publication. Finally add
the isolated normal Flutter SQLite/auth profile. Keep publication and UI default OFF.

Acceptance: no source data values/secrets in generated artifacts; complete schema;
approved fixture counts, valid active graph and explicit negative graph isolation;
source access/structure unchanged; stable IDs/UUIDs and receipts on retries; historical
rows untouched; actual Go/PostgreSQL/Flutter tests before calling the new workflow
ready. This review does not claim an executed migration, fixture load or E2E run.

Validation performed: new PowerShell script parsed successfully; aggregate SQL ran
twice with exit 0 in REPEATABLE READ READ ONLY, each ending ROLLBACK; five result
sections were parsed and parent/master classification arithmetic verified. Source
remained accessible, notarisdev absent, PostgreSQL service Running. git diff --check
passed. The migration proposal was inspected as text only, not executed (including
its guards). No new Go/Flutter runtime code changed; suites were not rerun for this
documentation/read-only review. Actual DDL compatibility remains an isolated-test
acceptance condition after approval, not something proved by these diagnostics.
