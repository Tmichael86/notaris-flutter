# Petugas migration readiness — 31 October 2026

**Current follow-up:** the permanent schema phases have since committed, but
application grants remain missing. Do NOT rerun the first-install procedure below.
See [grants-only recovery review](PETUGAS_GRANTS_ONLY_RECOVERY.md) for the observed
state, explicit authorization boundary and tested recovery. This document retains
the historical readiness/preflight evidence.

Baseline 09a919d. Status: **technically ready for reviewed development rollout,
NOT authorized/applied on permanent notarisdev in this checkpoint**. No UI, shell,
Pemohon, transaction-sync or normal SyncCoordinator behavior changed.

## Actual notarisdev preflight

Explicit private .env.notarisdev only, never ordinary .env. Read-only connection
to 127.0.0.1:5432/notarisdev as nd_app_14af5452144b verified synthetic marker and:

- PostgreSQL 18.6; four Petugas, integer PKs 101,102,103,104, unchanged.
- Legacy columns id bigint, jenis_kelamin/user_id nullable integer, tanggal_lahir
  date, created_at/updated_at timestamp without timezone, status smallint NOT NULL.
- Only Petugas PK index; no uuid, row_version or deleted_at. No petugas_sync tables.
- Zero missing gender/user references. Gender server IDs 11 and 29 both active.
- fixture.operator ID 2001, group 11, both active; Petugas read/create/update/delete
  permissions all 1. user_id is a reference, not record ownership or tenant scope.
- App role has no schema CREATE privilege. DDL must use a separate provisioning
  administrator; the normal backend account is not elevated.
- Development detail-process table has four synthetic rows. These are not the
  7058 source legacy rows; source database was not accessed by these new scripts.

prepare-petugas-dev-migration.ps1 validates this first-install baseline and either
reports it or writes a backup. It has **no Apply option**, so running readiness
cannot silently promote into a permanent migration. Unexpected existing/partial
foundation or different baseline requires operator inspection, not replay/repair.

```powershell
# repository root; read-only, no admin password and no .env fallback
.\scripts\prepare-petugas-dev-migration.ps1
.\scripts\prepare-petugas-dev-migration.ps1 -Backup
```

## Backup actually created and restored for validation

Ignored local directory:
`.local/petugas-migration-20261031-034655-8068394a/`

- notarisdev-before.dump: full custom backup of DEVELOPMENT data only; no source dump.
- preflight.json, sha256.json and toc.txt: target/baseline fingerprints, checksum
  and successful pg_restore listing. No credentials printed or committed.
- pg_dump uses a readonly session; SHA256/listing verified. A full restore into a
  NEW owned temporary cluster also succeeded. This proves restore usability beyond
  simply parsing the archive table of contents.
- Petugas/detail fingerprints before/after backup were equal. Permanent development
  fingerprints were checked again after testing; no foundation was installed there.

Archive contains development password hashes and possibly subsequent developer
data: keep private. It omits ownership/ACLs; preserve .env.notarisdev/private login
files separately and reapply reviewed app object grants after any recovery restore.
Backups are point-in-time. Retake under maintenance immediately before an approved
rollout; the backup here is not a guarantee against later user writes.

## SQL review and required order

First-install entry point remains
backend-notaris-go/migration_proposals/20261030_03_notarisdev_petugas.sql:

1. Explicit NOTARIS_DEV_REVIEWED and NOTARIS_DEV_APP_ROLE are required. Target DB
   must be notarisdev; reject privileged/missing app role or using it as DDL actor.
   First-install/column/reference guards run before DDL. Session search_path and
   lock/statement timeouts apply across included phases.
2. 20261029_01: UUID random backfill (only NULL), row_version=1, deleted_at;
   uniqueness and atomic mutation-receipt/outbox tables. Integer IDs unchanged.
3. 20261030_01: serialized transactional publication counter/min_cursor under lock.
   No ordinary sequence/outbox ID is introduced as a pull cursor.
4. 20261030_02: UUID default+NOT NULL and hardening of old versions. Existing UUIDs
   retained; tested repeated hardening leaves assigned UUIDs identical.
5. **New required grants**: original provisioning grants on ALL TABLES/SEQUENCES
   apply only to objects existing at that time. They do not cover newly created
   sync objects. Proposal now grants app SELECT/INSERT receipt access, SELECT/
   INSERT/UPDATE outbox, SELECT/UPDATE publication and USAGE/SELECT outbox sequence.
   Identifiers are quoted using format(%I); role validation occurs before DDL.
   No source/global grants or runtime DDL privileges are added.

No change to existing source migrations or record identities was needed for the
observed baseline. The partial UUID unique index from phase 1 covers every row
after UUID NOT NULL hardening; inspect definition/validity, not index name alone.
No new FK or name/email/NIK matching is added. Timestamp timezone interpretation
is unchanged and remains an explicit future data-contract consideration.

Phases have separate commits. Maintain all backend writers, publisher and clients
OFF for the ENTIRE rollout; phase-1 table lock alone does not protect later phases.
Current SQL guard rejects an existing foundation; interrupted installations require
phase-specific recovery, never blind replay of the whole proposal.

## Disposable test evidence

```powershell
.\scripts\test-petugas-dev-readiness.ps1 -BackupDirectory `
  .local\petugas-migration-20261031-034655-8068394a
```

Creates a fresh temporary cluster on 127.0.0.1:55442 and verifies SHOW data_directory
against its owned TEMP path BEFORE creating a disposable DB named notarisdev.
It never connects to port 5432. Restore uses --single-transaction, --no-owner,
--no-privileges; there is no --clean, overwrite or source connection. New test role
readiness_app is nonprivileged. Migration executes only in that isolated cluster.

Actual results, exit 0:

- Restored development archive + first-install migration + app-role grants pass.
- UUIDs valid/stable, four legacy IDs preserved. Repeated UUID-hardening passes.
- Re-running first-install wrapper refuses existing foundation as designed.
- New TestPetugasRestoredDevelopmentReadiness uses the restored public schema,
  NO AutoMigrate, and readiness_app. Real fixture password login produces a new
  test JWT; existing permission middleware applies. Legacy CRUD create/update/
  soft-delete, UUID create/update/delete, exact retry ack, stale-version 409,
  historical pull and tombstone, 410 response all pass.
- Bootstrap appends four baseline events once, retry appends zero; publish then
  retry produces four then zero. Successful sync mutations produce three receipts
  and three outbox events despite replay. Transaction detail fingerprint unchanged.
- Full Go suite against disposable test DSNs: JSON reports 40 pass events, 1 skip,
  no failures. The skip is internal/devfixture.TestSyntheticHTTP (its separate
  synthetic-provisioning opt-in DSN is unset), NOT a skipped Petugas integration.
- Four PostgreSQL concurrency tests repeated 10 times pass: publication A/B commit
  order, publisher rollback/serialization, bootstrap/write concurrency, legacy CRUD
  vs sync concurrency. These existing tests own separate disposable schemas and
  clean only those schemas. No such tests are pointed at a permanent database.
- Flutter Petugas local sync/conflict/reference tests: 34 passed, exit 0. This
  separately verifies persistent 409/410 blocked state and pending/cursor/transaction
  preservation; it is not a new interactive Flutter-to-restored-server E2E claim.
- Owned temporary cluster stopped; its logs/data retained under
  TEMP/notaris-petugas-readiness-28fa430e2fc141a0bf81b94f7231dbd1.

## Publisher / bootstrap / normal Flutter readiness

Publication repo Publish/Pull and worker already exist. .env.notarisdev says
PETUGAS_PUBLISHER_ENABLED=false and run-notarisdev-backend.ps1 forces false.
Do not claim runtime publication is active. No migration or bootstrap is performed
on ordinary backend startup. Bootstrap remains an explicit repository operation,
not a public admin HTTP endpoint or automatic per-login full table scan.

After approved migration/grants, current CRUD and JWT push/pull are compatible with
this schema, as demonstrated on restore. Next controlled deployment step needs a
scoped operator invocation of Bootstrap and publication drain, then counts/UUIDs/
counter/canonical pull verification, before enabling a worker deliberately. There
is not yet a normal-development bootstrap CLI or publisher opt-in launcher; adding
those controlled actions is a separate checkpoint, not hidden startup behavior.

Flutter prerequisites (planning only):

- PetugasSyncApi, PetugasLocalSyncRepository, persistent conflict/410 state,
  PetugasIdentityMapRepository and VerifiedPetugasReferences are available.
- Normal SyncCoordinator still only handles category/expense/Pemohon. Do not wire
  Petugas merely because the server can accept requests.
- Pemohon development fixture resolver is NOT Petugas reference provenance. For
  Petugas, install verified gender mappings using existing scoped reference repo
  and the explicit fixture manifest + authenticated catalog; never compare labels
  or reuse local/server integer coincidence. user_id requires server provenance.
- Pulling four server records into a fresh profile can create server-only mappings
  by cloud UUID without auto-matching. Existing local records remain ambiguous
  until operator confirms mapping; preserve local ID/local UUID/transaction links.
- Keep journal mutation IDs, pending snapshots and existing feed cursor. Scope must
  bind generation/account; mismatched profile stays blocked, never reset. Dirty
  local rows block overwrite; 409 needs explicit resolution, 410 stays blocked as
  full snapshot recovery remains unavailable.
- Development-only feature gate default OFF; typed blocked/conflict UI first, no
  production activation and no silent generic success if dependencies unresolved.

## Exact approval and recovery boundary

Approval must explicitly cover: maintenance of the development backend/clients,
a fresh verified notarisdev backup, executing the three SQL phases + new app grants
on 127.0.0.1:5432/notarisdev with a provisioning role, and post-DDL checks. Approval
to prepare/test is NOT approval to run permanent ALTER TABLE. None was executed.

After approval, operator must verify current_database/server endpoint and table
ownership, use a new interactive provisioning credential (no ordinary .env fallback),
supply the exact app role from private development config, and keep all writers off.
Record phase completion before bootstrap/publisher; recheck IDs, references, valid
UUID unique index/default, positive versions, tombstones, grants, old detail checksum.

If failure: leave backend/clients/worker OFF; retain backup, logs, assigned UUIDs and
events; inspect the completed phase and apply a reviewed repair. No automatic DROP,
TRUNCATE, UUID rewrite or cursor reset. Do not restore over an existing database
blindly. If restore is necessary, request approval for a NEW recovery database,
restore the verified development archive there without --clean/--create, reapply
ACLs, compare all counts/fingerprints and choose a controlled cutover. Such creation
is another explicit authorization, not a fallback this preparation script performs.
Once cloud identities have been observed by clients, pre-migration restore is not
a transparent rollback: identity/replay/feed recovery must be reconciled explicitly.

Remaining limits: shared authorization catalog is not multi-tenant isolation;
retention/full-resync recovery and normal Petugas reference/UI/coordinator wiring
remain pending. Source legacy details and source database are out of scope.

## Rollout preflight follow-up — 31 October 2026

Starting checkpoint d2dd0af, feature/pemohon-cloud-sync, clean working tree.
The owner's rollout request still requires a separate approval AFTER a new
maintenance backup has passed restore verification. That approval is not implied
by the request to prepare the rollout.

Read-only live preflight again verified the server-reported endpoint
127.0.0.1:5432, database notarisdev, synthetic marker, Petugas IDs 101–104,
zero missing gender/user references, active operator permissions and absent sync
foundation. PostgreSQL remains 18.6. Table/database owner postgres is a separate,
login-capable provisioning role; application role still has no schema CREATE.
A passwordless, noninteractive provisioning connection failed authentication;
administrator credentials must be supplied locally, never taken from ordinary
.env or pasted into chat.

The backend was initially listening on 8081 and the development Flutter executable
was active. A later listener check found 8081 closed. Two DBeaver sessions to
notarisdev initially remained open, then disconnected. The final checks found
no 8081 listener, no development Flutter executable, and no other notarisdev
sessions. No process/session was terminated by the agent; PostgreSQL stayed running.

The preparation script now records actual endpoint/ownership, a schema fingerprint,
target-session metadata, and transaction/payment fingerprints as well as the
existing Petugas/detail fingerprints. It refuses -Backup while port 8081 is active
or another target database session exists, and checks for schema/data/session
changes after backup. Parser validation and actual live maintenance-refusal checks
passed. These are detection checks, not a server-wide connection fence: keep
writers/clients closed through the entire rollout and recheck before DDL.

Latest read-only hashes (no data values exported):

| Object | Fingerprint |
| --- | --- |
| Schema visible to application role | 9a1201485ec598806b5dba5334918b14 |
| Four Petugas | eedb14e3f393d42ed3fbdc818a0728e1 |
| Four development detail rows | 7f314987f2e49339875e92cdb79e74c8 |
| Four development transactions | f4af66a193fab2e15c0e2f8bf012ec19 |
| Development payments | e87baa817f065403bf0348df710e29cf |

Fresh backup: `.local/petugas-migration-20261031-040507-fb7e27c8/` contains the
custom archive, listing, SHA256 and current preflight report. All five development
schema/data fingerprints above matched before/after backup AND after disposable
integration testing. Backup checksum:
`FE14A131067DAF488B86EB14948B94FD89569B452A12F69AF734E317B17D85D0`.

Full restore into a NEW owned cluster 127.0.0.1:55442 succeeded. The three actual
SQL phases and app grants, UUID-hardening repeat, first-install replay refusal,
restricted-role legacy CRUD, authenticated HTTP sync, idempotency, 409/410,
bootstrap retry and publication passed there. Go full suite: 40 passed, 1 skipped
(internal/devfixture.TestSyntheticHTTP requires a different opt-in DSN), zero
failures, exit 0. The four PostgreSQL concurrency cases repeated ten times passed,
exit 0. Temporary cluster shutdown passed. Logs/data are retained at
`C:/Users/Msi GF63/AppData/Local/Temp/notaris-petugas-readiness-3fea7a09b3fa41279fddabc1c3121202/`.

The protected source notarislokal was contacted ONLY with an explicitly read-only
catalog query using the development role (no normal .env fallback). It has 38
tables and matching before/after catalog fingerprints
`03b67625aae627db88a2d6b6406450b7`. This catalog-based algorithm differs from the
application-visible information_schema hash above. Source Petugas/detail SELECT
privileges are false: no source rows or historical details were read, exported,
modified or relinked, and no source data-content checksum is claimed. Catalog
before/after JSON and query are in the private new backup directory.

Permanent target remains UNMIGRATED: no UUID/version/delete columns or sync tables.
All migration/CRUD/bootstrap/publication results in the preceding paragraph are
for the restored disposable target, NOT live development rollout results.

The separate permanent-schema approval was requested AFTER the new backup/restore
passed; no answer has been received at this checkpoint. Provisioning authentication
must also be supplied locally before DDL. Keep clients off, recheck target/sessions
and all backup fingerprints immediately before execution; if writes occurred,
retake and verify the backup. Only after approval run the reviewed SQL phases/grants.
Record each phase/grant outcome and source/target checks, never mark partial phases
as overall success. No automatic restore is authorized; use the recovery procedure
above. Never point disposable destructive integration tests at permanent notarisdev.
Publisher and Flutter wiring remain OFF.

Follow-up checks: PowerShell parser exit 0; live read-only preflight and expected
maintenance backup refusal exit 0. Go test -json -count=1 ./... first exited 1
inside the sandbox (TestPublicationEnvironmentConfiguration could not execute
testing.Chdir: access denied). Repeating outside that filesystem restriction exited
0: 24 passed, 17 skipped, zero failed. Integration opt-in DSNs were explicitly unset
in those two initial attempts; the subsequent fresh restore run above actually
executed the PostgreSQL cases. No Go or Flutter source changed.

## Explicit approval received; provisioning authentication gate

The owner subsequently approved the three permanent notarisdev phases, limited
app grants and post-migration checks. Approval is recorded in the conversation;
do NOT request the same approval again. Constraints remain: only
127.0.0.1:5432/notarisdev, preserve IDs/data, stop on failure, no automatic restore,
publisher OFF, no Flutter/SyncCoordinator activation or push/merge. The owner
confirmed closing backend/Flutter/DBeaver and requested local terminal password
entry if the previous provisioning credentials were unavailable.

Latest actual recheck after that approval: correct branch/9ee3ab5, clean tree;
no backend listener, no development Flutter executable or other notarisdev session;
all five development fingerprints still match the verified fresh backup above.
No connection to notarislokal or any other database was made in this continuation.

Original provisioning script used Get-Credential and restored its process
environment; it did not persist the admin credential. Project provisioning
artifacts, process PG environment, and standard APPDATA PostgreSQL pgpass/service
locations did not contain a usable provisioning credential. Do not mine DBeaver's
credential store, fall back to normal .env, elevate the app role, or change HBA.

`scripts/migrate-notarisdev-petugas.ps1` is the local interactive entry point:

```powershell
# Ownership/authentication preflight only, no DDL:
.\scripts\migrate-notarisdev-petugas.ps1 `
  -BackupDirectory '.local\petugas-migration-20261031-040507-fb7e27c8'

# Execute the ALREADY approved rollout, after successful authentication:
.\scripts\migrate-notarisdev-petugas.ps1 -Apply `
  -ConfirmTarget '127.0.0.1:5432/notarisdev' `
  -BackupDirectory '.local\petugas-migration-20261031-040507-fb7e27c8'
```

Password input is hidden (Read-Host -AsSecureString), passed to child psql through
the process environment, never a command-line password or stored credential file.
The environment is restored in finally. Default provisioning username postgres
is the observed existing table owner, NOT the application account. If a narrower
provisioning login already exists, use -ProvisioningUser; required privileges are
available table-owner rights and public schema CREATE, plus ownership/grant rights
on the new objects. The launcher does not create/elevate roles or require
CREATEDB/CREATEROLE. If privileges/authentication fail, stop before DDL. An operator
using the existing postgres owner should recognize that it is an administrator,
not claim that its cluster-wide privileges are least-privilege.

The launcher verifies explicit private config/publisher OFF, archive checksum and
all baseline fingerprints; rejects app DDL and active backend/target sessions;
rechecks after password entry; then invokes the reviewed SQL. The SQL now runs a
read-only anonymous target/owner/maintenance assertion BEFORE EACH phase and
before grants. No new persistent function or schema object is added by the guard.
psql's connected PORT is recorded once; the permanent launcher fixes it to 5432
(the existing separate disposable harness uses 55442). Successful phase commits
emit explicit markers. Grants form one transaction; schema phases retain their
previous transaction boundaries. No schema/data migration algorithm was changed.

Private `.local/petugas-rollout-*/history.json` records SQL SHA256s, archive/target,
role names, psql exit status and per-phase commit markers. Failures remain failures
even if earlier phases committed. Postflight compares original Petugas values
excluding the three new columns, transaction/detail/payment hashes, IDs, UUID
uniqueness/default/index, versions, empty journals/feed and initial counter. It
authenticates as the app for actual SELECTs and checks each necessary/forbidden
grant individually. No automatic replay, restore, bootstrap, publication or HTTP
write test is hidden in this launcher.

Checks executed before handing the terminal step to the operator:

- PowerShell parser passed; wrong target refused before authentication.
- Explicit application credential refused by the launcher.
- Actual psql target guard rejected the app role in a read-only notarisdev session
  (expected psql exit 3), BEFORE DDL. Preflight afterward confirmed no sync schema.
- Go test -json -count=1 ./... exited 0: 24 passed, 17 opt-in tests skipped, no
  failures. Integration DSNs deliberately unset to avoid connections while the
  operator may run migration. This is not a new PostgreSQL success-path test.

Permanent phase execution remains unconfirmed pending local provisioning password
entry. Do not claim the new execution/postflight success path, live CRUD/bootstrap,
UUID repeat or HTTP 409/410 were run on permanent notarisdev until receipts and
direct verification prove it. No new source-data assertion is made here. Keep
backend/clients/publisher OFF until migration outcome and postchecks are reviewed.
