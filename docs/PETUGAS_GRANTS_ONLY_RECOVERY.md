# Petugas grants-only recovery review — 31 October 2026

**Subsequent checkpoint:** the operator has since completed grants recovery;
receipt `.local/petugas-grants-20261031-045404-127d93cb` has verified COMMIT and
postchecks. Do not repeat GRANTs. See [development operations](PETUGAS_DEVELOPMENT_OPERATIONS.md)
for the implemented runner and the separate permanent-bootstrap/publication
approval boundary. The original review/evidence below is retained historically.

Status: source/scripts/tests authorized and implemented; **permanent GRANT NOT
authorized or executed in this checkpoint**. Branch feature/pemohon-cloud-sync,
starting HEAD 9ee3ab5. No Flutter, CRUD, publisher algorithm or SyncCoordinator
changes. No connection to notarislokal by these recovery/test operations.

## Proven installation state and provenance

The operator previously ran the approved permanent migration against
127.0.0.1:5432/notarisdev. The private execution receipt is
`.local/petugas-rollout-20261031-041442-025400db/`.

| Stage | Observed evidence |
| --- | --- |
| Identity/mutation/outbox | Phase 1 COMMIT marker in migration.log; new columns/tables/indexes visible |
| Publication | Phase 2 COMMIT marker; counter schema/constraints visible |
| UUID hardening | NOT NULL + random default visible from a separate session, hence committed; marker was lost |
| Grants | Application sync table/sequence privileges absent; rollout not complete |

Four Petugas IDs 101–104 remain. UUIDs are valid/unique, row_version=1 and
deleted_at=NULL. Legacy Petugas, transaction/detail/payment hashes match the
pre-migration development backup. The assigned UUID mapping fingerprint is
2119c076bef291e285848f95e5753473; this is an integrity checksum, NEVER a global
identity derived from integer IDs. Assigned UUIDs are preserved, not regenerated.

The operator separately executed authenticated BEGIN READ ONLY / SELECT / ROLLBACK
and reported: database notarisdev, address 127.0.0.1, port 5432, read_only=on;
publication exactly id=1,last_seq=0,min_cursor=0; mutation/outbox counts zero;
sequence last_value=1,is_called=false. These are operator-provided query results,
not an admin query executed by the agent. No repeat password/counter request was
needed in this checkpoint.

The agent's additional app-authenticated catalog-only check confirmed owner
postgres on Petugas/three sync tables/sequence; permanent relations and no RLS;
valid/ready indexes; and sequence dependency type `a` (OWNED BY) on
petugas_sync_outbox.id. UUID/legacy hashes still match, other target sessions=0,
app SELECT on all three sync tables still false. Private output:
`.local/petugas-recovery-catalog.log`. This session used default_transaction_read_only
and BEGIN READ ONLY; it did not read or mutate protected journals/counter data.

The verified pre-migration archive remains
`.local/petugas-migration-20261031-040507-fb7e27c8/notarisdev-before.dump`, SHA256
FE14A131067DAF488B86EB14948B94FD89569B452A12F69AF734E317B17D85D0.
It was previously restore-tested. It is retained as recovery evidence, NOT
automatically restored by the new workflow.

## Diagnosis and code changes

prepare-petugas-dev-migration.ps1 line 57 correctly rejects any installed foundation.
It is first-install validation, not a classifier or a resumable migration runner.
Its safety check remains intact. A retry after committed schema is not permitted
to fall back into identity/publication/UUID migrations.

The first runner streamed native stderr through `*>` with ErrorActionPreference=Stop.
On Windows PowerShell 5, a PostgreSQL NOTICE can become NativeCommandError even
though SQL continues/commits. A read-only diagnostic reproduced this. The original
error stream was incompletely recorded, so there is no claim of an original SQL
transaction failure merely because the PowerShell wrapper failed.

scripts/notaris-psql-process.ps1 now invokes psql directly via Start-Process with
separate stdout/stderr files and -Wait -PassThru. Actual process exit code and an
expected completion marker are required. NOTICE remains in stderr while exit 0
succeeds; genuine SQL errors remain visible with nonzero exit. Windows argv quoting
is tested for spaces, quotes, apostrophes and backslashes. No shell command or
password argument is constructed. The first-install runner uses the same helper;
missing commit markers mean unconfirmed state, not proof of rollback.

## Recovery contract

The new entry is scripts/recover-notarisdev-petugas-grants.ps1. Default mode is
**read-only verification**, using verify_petugas_grants.sql. Explicit -ApplyGrants
and exact -ConfirmTarget are required to invoke recover_petugas_grants_only.sql.
There is no migration include, first-install call, ALTER, reset, bootstrap,
publisher or restore fallback in this path.

SQL inputs bind the verified backup's original data fingerprints to the installed
UUID snapshot in recovery-inspection.json. The launcher reads ONLY private
.env.notarisdev; host/port/database are fixed to loopback:5432/notarisdev, with
publisher configured OFF. It rejects an app credential used for provisioning.
Passwords are hidden local Read-Host input, inherited by child psql in the process
environment, restored in finally, and never saved or printed. Secrets are never
psql variables/arguments.

petugas_grants_existing_guard.sql checks:

- Actual database/address/expected port, synthetic marker and exclusive maintenance
  session; regular permanent tables, RLS off, no unexpected triggers/rules.
- All required sync columns/types/nullability/defaults and exact new-table column
  counts; Petugas integer PK + installed UUID/row-version/tombstone definitions.
- Nine required indexes: table, key, uniqueness, btree method, validity/readiness,
  immediacy and predicates. The known partial UUID index is valid because UUID is
  NOT NULL; a full unique UUID index is also accepted.
- PKs, outbox publication uniqueness and three validated publication CHECKs;
  unexpected key/check/FK/exclusion constraints block recovery.
- Outbox sequence namespace/type, owner matching outbox, automatic dependency on
  its id column, nextval default, bigint bounds/start/increment/cache/no-cycle.
- Four legacy IDs, preserved installed UUID mapping, positive baseline versions,
  no tombstones, original data fingerprints, and valid server user/gender references.
- Counter/journal/sequence equal the verified pre-activation baseline. Any mutation,
  publication, used sequence or new row blocks this deliberately narrow recovery.
- App login attributes, no schema CREATE/owner membership, no excess effective
  table/sequence permissions or GRANT OPTION (including MAINTAIN on PostgreSQL 17+).

The grantor needs ownership of the three sync tables/sequence (or available owner
rights), USAGE public and SELECT on original Petugas/master/transaction tables
needed for validation. It does NOT need ownership/ALTER of legacy Petugas, schema
CREATE, CREATEDB or CREATEROLE. A restricted nonsuperuser grantor with those limited
rights is tested. Current permanent owner postgres is an existing administrator;
using it does not make its cluster-wide privileges least-privilege. No role,
membership or object ownership is changed on the permanent server by recovery.

Exactly these grants form ONE transaction, after repeated target/schema checks:

| Object | Application permission |
| --- | --- |
| petugas_sync_mutations | SELECT, INSERT |
| petugas_sync_outbox | SELECT, INSERT, UPDATE |
| petugas_sync_publication | SELECT, UPDATE |
| petugas_sync_outbox_id_seq | USAGE, SELECT |

SHARE locks protect the three sync tables. ACCESS SHARE on existing business tables
requires only SELECT and protects definitions; the external maintenance gate must
keep writers off throughout. The gate detects sessions; it is not a server-wide
connection fence. No privileges are revoked or widened to ALL/default/global scope.

Each run retains private stdout/stderr, baseline/backup/SQL/helper/runner hashes,
exit codes and status under `.local/petugas-grants-*/`. No completion is claimed
without exit 0 and commit marker. A crash/lost response leaves commit unconfirmed;
inspect ACLs/logs before a deliberate retry, never infer rollback from a missing
marker. Replaying the SAME grants is idempotent under an unchanged verified state.
There is no automatic retry. UUIDs/cursor/rows/sequence are never rewritten/reset.

After a successful grant commit, the script repeats read-only guard checks, then
authenticates as the app for actual table/sequence SELECTs and individual required
write-permission checks. No nextval or DML permission probe is run on permanent
data. HTTP CRUD/push/pull/bootstrap regression remains a subsequent explicitly
controlled step, not hidden activation.

## Commands for review; do not run ApplyGrants before separate approval

```powershell
# Default read-only existing-schema verification; password stays local.
.\scripts\recover-notarisdev-petugas-grants.ps1 `
  -BackupDirectory '.local\petugas-migration-20261031-040507-fb7e27c8' `
  -InstallationReceiptDirectory '.local\petugas-rollout-20261031-041442-025400db'

# ONLY after separate permanent GRANT approval:
.\scripts\recover-notarisdev-petugas-grants.ps1 -ApplyGrants `
  -ConfirmTarget '127.0.0.1:5432/notarisdev' `
  -BackupDirectory '.local\petugas-migration-20261031-040507-fb7e27c8' `
  -InstallationReceiptDirectory '.local\petugas-rollout-20261031-041442-025400db'
```

Use -ProvisioningUser for an existing authorized grantor. No credentials are copied
from normal .env or DBeaver. Keep backend/Flutter/DBeaver target disconnected. If
any condition changed, stop and inspect; do not disable guards, drop objects or
restore over the database. Publisher and Flutter SyncCoordinator remain OFF.

## Test evidence

`./scripts/test-petugas-grants-recovery.ps1` creates a NEW owned temporary PostgreSQL
cluster on 127.0.0.1:55443. It verifies data_directory/port before creating its own
database named notarisdev and loads only a small in-code synthetic fixture. It
does not restore an archive, connect to 5432, or touch notarislokal. All malformed
schema/GRANT tests run there; negative changes are transactionally rolled back.
The final used-sequence rejection intentionally allocates only on this disposable
cluster and never resets it. Cluster data/logs are retained after stopping it.

Coverage: phase-1-only and missing hardening; missing/wrong indexes; extra column;
unvalidated/wrong constraint; sequence dependency/definition/used state; advanced
counter; modified data/UUID; nonempty receipt/outbox; excess privileges/grant option;
wrong database/port/app actor; missing approval; first-install refusal retained;
real GRANT rollback on injected SQL error before COMMIT; restricted grantor;
successful/idempotent grants-only; authenticated app read/write probes rolled back
without consuming sequences; forbidden receipt DELETE; data/identity preservation.
Windows PowerShell 5 runs actual parser, quoting and NOTICE/error logging checks.

The Go suite runs with NOTARIS_SYNC_TEST_DSN pointing only to the owned cluster;
its tests own separate disposable schemas. Restore-readiness and synthetic-HTTP
fixture opt-in DSNs remain unset. Their skips are reported, not called passes.
Permanent integration and interactive Flutter testing are NOT claimed here.

Final execution (PostgreSQL 18.6): **38 recovery checks passed, zero failed or
skipped recovery cases; harness exit 0**. Go test -json -count=1 ./...: **39 test
passes, 2 skips, zero failures, exit 0**. Skips are
routes.TestPetugasRestoredDevelopmentReadiness and
internal/devfixture.TestSyntheticHTTP; their separate opt-in DSNs were unset.
The ordinary PostgreSQL mutation/publication/HTTP integration cases did execute
against the owned temporary cluster. A restricted grantor with no superuser,
schema CREATE or legacy Petugas ownership successfully performed grants-only.
The owned cluster was stopped and port 55443 no longer listened.

Final logs:
`C:/Users/Msi GF63/AppData/Local/Temp/notaris-grants-test-fd6de1b0ecf641bf87f9f44ea13334cb/`.
The permanent interactive recovery launcher has been parsed/refusal-tested on
Windows PowerShell 5, but its successful permanent run is intentionally unexecuted.
Core SQL and the shared native execution helper were tested on the isolated target.

Approval now requested ONLY for the four GRANT statements above on permanent
127.0.0.1:5432/notarisdev, with repeated read-only validation and app postchecks.
Schema phases, UUIDs, data, publication/cursors and role/object ownership must not
change. No automatic rollback/retry/revoke is authorized. Keep publisher and
Flutter integration OFF. If approved, operator password entry remains local;
the previously completed counter diagnostic does not need to be requested again.
