# NOTARISDEV P0 migration rehearsal — 21 November 2026

**P0_MIGRATION_REHEARSAL_PASS. Operational integration remains BLOCKED pending
separate live approval, verified credentials and canonical-code reconciliation.**

Baseline Git `916be51`, branch `feature/pemohon-cloud-sync`. This is a new
restore; neither prior restore cluster nor existing NOTARISDEV/NOTARISLOKAL was
opened. The unrelated untracked preparation document remains untouched.

## Owned disposable identity

- Profile: `df0381ead47449a184e8c1b254bfaca9`.
- PostgreSQL 18.6: `127.0.0.1:55813/notaris_p0_df0381ead474`.
- Fresh bootstrap role: `p0_owner_df0381ea`.
- Private data directory:
  `C:\Users\Msi GF63\AppData\Local\Temp\notaris-restore-df0381ead47449a184e8c1b254bfaca9-b9087mp2\pgdata`.
- Private Windows ACL, SCRAM, fresh temporary credential held only in memory;
  init-password file removed. Inherited PG* and opt-in connection settings
  stripped. Actual database/user/host/port/data-directory/listen-address and
  synthetic marker attested. No archived application password was used.
- Final state: **STOPPED_DATA_RETAINED**, stop exit 0; postmaster PID absent.
  Locks and evidence remain. No automatic cleanup or restore retry.

## Archive and one transactional migration

Input `D:\Download\notarisdevbak.sql` is a PostgreSQL CUSTOM archive.
SHA-256 before/after:
`91e674bf80d94302f06cd263086722821faf76e9b85cb5a3e32e7264f4b262be`.

The proven restore procedure was reused on the new target with no owner/ACL
replay, no --create/--clean, --single-transaction and --exit-on-error. The
complete constraint extractor includes the inline CHECKs validated previously.
Restore baseline: **57 tables / 192 rows / 111 constraints / 89 indexes /
15 FK, orphan 0 / 41 sequences**, all matching the archive.

The actual `20261119_users_security_preflight.sql` ran read-only: exit 0,
zero anomaly rows, no pre-existing partial P0 objects. Its SHA-256 was
`a2cc7cd60a8031d8a1576bc6ea9bd870a968ff1410e31fa3cb5770840297f403`.

The unchanged `20261119_users_security.sql` was applied **once** with psql
`--single-transaction -v ON_ERROR_STOP=1`: exit 0, independently confirmed by
postcheck. Proposal SHA-256:
`e5dcba8f3e9a21f8db6cff4101208a7c9605f6171e8eaa1043443b68d9682228`.

## Exact expected additions and preservation

| Object | Delta |
| --- | --- |
| Columns | `users.revision`, `users.security_version`, `groups.revision`: bigint, non-null, default 1, positive checks |
| Table/sequence | `administrative_audit`, `administrative_audit_id_seq` |
| Unique indexes | `users_username_normalized`, `users_email_normalized`, `sidebar_code_unique`, `sidebar_group_grant_unique` |
| Audit indexes | `administrative_audit_pkey`, `administrative_audit_actor_time` |
| Function/trigger | `deny_administrative_audit_rewrite`, `administrative_audit_immutable` |

Added constraints (15): `users_revision_check`, `users_security_version_check`,
`groups_revision_check`, `users_security_identity_nonempty`,
`groups_security_valid`, `sidebar_security_valid`, `users_security_group_fk`,
`users_security_status`, `grants_security_group_fk`, `grants_security_sidebar_fk`,
`grants_security_flags`, `administrative_audit_pkey`,
`administrative_audit_actor_id_fkey`, `administrative_audit_result_check`,
`administrative_audit_source_check`.

Final inventory: **58 tables / 126 constraints / 95 indexes / 42 sequences**.
All 19 FK validated and independently checked: **0 orphans**. Existing
constraints/indexes unchanged, only the expected table/function/trigger/index
additions. New audit sequence `(last_value=1,is_called=false)`, audit rows 0.

All **57/57 original-column table fingerprints** and all **192 original rows**
match before/after. This includes user/group classifications, 24 grants,
transactions, details, processes, payments, mutation receipts, outbox and
publication. Added revision/security-version values are 1 for both users and
both groups; no promotion, grant changes or credential changes occurred.
All 41 existing sequence states/ownership remain unchanged; no nextval invoked.
Marker remains `NOTARISDEV SYNTHETIC v1`; feed heads Notaris 6, PPAT 6, Petugas 4,
Transaction 9. No publication, mutation replay or sync operation occurred.

## Actual H05 compatibility defect and narrow correction

Before migration, actual H05 readiness rejected incomplete schema and never
reached the listener callback. After a successful migration it initially
rejected `users.users_security_identity_nonempty`: legacy identity/catalog
columns are `varchar(255)`, whereas earlier P0 fixtures used `text`.

PostgreSQL legitimately emits explicit `::text` casts for the same approved
proposal over VARCHAR columns, including the normalized indexes and group-type
array comparison. No migration or data correction was necessary.

`users_security_schema.go` now selects exact expected expressions from the
actual built-in VARCHAR/text type. No generic cast stripping, alternate
permission, CHECK relaxation, proposal rewrite or schema change was added.
The shared test fixture can establish legacy types before applying the same
proposal; wrong CHECKs, wrong index expressions and partial indexes still fail.

One read-only H05 recheck after focused tests passed verified **ready=true**,
explicit P0=true, owned target match, insecure configuration rejected, and
listener gate eligible. The callback deliberately never creates an HTTP socket.
Complete table fingerprints (including new columns) and all sequence states
were identical before/after readiness. Migration was not repeated.

Recovery prerequisites pass the existing active/explicit-grants/bcrypt-format
policy. **Full authentication and possession of recovery credentials are
UNVERIFIED**: no login attempt, no archived password comparison, no token issued.

## Canonical Sidebar reconciliation remains separate

| Existing PK | Current code | Required Flutter code | Preserve |
| --- | --- | --- | --- |
| 10 | `laporan-materai` | `laporan_materai` | `/laporan/materai`, existing status/PK and one grant row |
| 12 | `laporan-pendapatan` | `laporan_pendapatan` | `/laporan/pendapatan`, existing status/PK and one grant row |

References: `materai_repository.dart:6`, `pendapatan_repository.dart:12`, and the
accepted catalog definitions in `internal/devfixture/groups_catalog.go:20`.
That disposable catalog is **not** a seed for deployment. A separately reviewed
two-code metadata mapping must preserve the actual PKs, routes, statuses and
grant relationships, check collisions and invalidate/refetch affected cached
permissions as appropriate. **No mapping or alias was applied here.**

## Evidence, commands and remaining gates

Evidence directory:
`.local/notarisdev-p0-rehearsal-df0381ead47449a184e8c1b254bfaca9/`.
`receipt.json`, `apply-tags.log`, `schema-after.json`, `h05-before-migration.json`,
`h05-after-migration.json`, `h05-after-source-fix.json`, and
`canonical-mapping-review.json` preserve outcomes, hashes and object metadata.
No business rows, archived password hashes or temporary credentials were logged.

The completed one-shot local runner was
`python .local/p0-migration-rehearsal-20261121.py`. **Do not rerun it**; its
attempt locks are preserved. Existing previous profiles were not reused.
The ignored readiness probe lives under
`backend-notaris-go/.local/p0-rehearsal-readiness/`; it is not a product factory.

Relevant regression: `python scripts/test-users-security-disposable.py --h05`:
**38 Go top-level tests / 201 leaf cases PASS**, 0 failed/skipped; includes four
new legacy-type cases plus H04 and Users/Groups regression. Log:
`.local/h05/p0-legacy-compatibility.log`.
`go vet ./services ./routes ./config ./cmd ./internal/backendstartup` passed.
No Flutter rebuild or Windows packaging.

Before real NOTARISDEV integration: obtain verified read-only access, attest
the actual live target/baseline and a fresh recovery backup; review the two-code
mapping and actual recovery credentials; separately approve live P0 migration,
least-privilege grants and explicit H05 environment/deployment configuration.
TLS/reverse-proxy/secret management and H02/H03 manual acceptance remain gates.
No existing database or original SQLite was opened. H01 remains
`DISABLED_BY_POLICY`; no operational activation, live migration, reset/reseed,
deployment, cloud publication, push or merge occurred.
