# Groups V2 — Atur Akses

Operational activation **OFF**. Operator Windows acceptance **PENDING**.
Implemented after accepted Groups V1 (`946d072`). No schema migration or local
Groups ledger. System → Sidebars remains its existing listing prototype; the
permission editor belongs to **System → Groups → Atur Akses**.

## Authorization and snapshot

`GET /api/v1/groups/:id/sidebar-access` now returns the P0 envelope with
`data:{group,catalog_fingerprint,entries}`. The old Group-access adapter is updated
with this endpoint. `/auth/me/sidebar-access` retains its operational list contract.

- `group`: ID/name/type/status/revision/active-member count, no member PII.
- `entries`: authoritative Sidebar ID/code/name/parent/route/icon/order/status,
  stored READ/CREATE/UPDATE/DELETE, server-derived editable/reason.
- A read-only REPEATABLE READ transaction captures group, definitions and grants
  in one PostgreSQL MVCC snapshot. No independent revision/checkbox reads.
- Catalog SHA-256 uses deterministic ID-ordered JSON of authoritative identity,
  parent, code, name, route/navigability, icon, order and status. Nil/zero root
  representations are preserved; Flutter never invents identifiers/aliases.
- At most 1,000 total definitions; overflow/ambiguous or orphan stored grants
  fail closed. Every definition is represented; cycles/orphans/inactive ancestors
  are visible read-only. Valid deeper trees remain editable.

Both read and write require enabled P0, valid expiring/versioned JWT, current
active user/group, exact current Superadmin classification, canonical active
`groups` READ; write additionally requires UPDATE. No implicit Superadmin bypass,
no `sidebars` UPDATE requirement. Superadmin targets are view-only; PUT rejects
**every** non-ordinary target regardless of available recovery administrators.
Inactive target cannot be mutated. No membership/classification writer is added.

## PUT contract and preservation

```json
{
  "expected_revision": 1,
  "catalog_fingerprint": "<64 lowercase SHA-256 characters>",
  "access": [
    {"sidebar_id": 4,"read": 1,"create": 0,"update": 0,"delete": 0}
  ]
}
```

The array must contain **exactly** every current editable ID, once, with every
flag explicitly present. Unchecked means four explicit zeros. This example is
illustrative, not a complete request for the prepared fixture (six editable IDs).
Missing/null/malformed access, missing flags, duplicates, invalid flags and CUD
without READ are rejected. Unknown/frozen IDs cannot be submitted. Limits remain
32 KiB and 1,000 input items. Zero editable entries: only an explicit `[]` can
produce an audited no-op revision increment; the UI offers no unchanged save.

The existing P0 transaction takes advisory lock **71920261119**, reauthorizes,
locks the target FOR UPDATE, validates revision/catalog/completeness, and upserts
only the server-defined editable set. Grants outside that set are neither echoed
from Flutter nor deleted: their PK, flags, created/updated provenance remain
unchanged. All-zero editable rows remain explicit. No other Group is modified.

The catalog is checked again after reconciliation before audit/commit. A SELECT
level table lock protects against destructive catalog DDL without giving the
runtime metadata UPDATE privileges. All **supported** Users/Groups/grants writers
share AdminLock. No application Sidebar metadata writer exists. Arbitrary external
DML does not acquire this advisory lock; a write after the final catalog check
cannot be promised safe. Operational rollout MUST prohibit/drain such writers.
Any future metadata writer must join AdminLock. This is not a guarantee against
DBA/superuser bypass, and no new migration/SECURITY DEFINER privilege was added.

Recovery and authorization are rechecked, and successful `group_grants` audit
commits atomically with revision+1. Audit before/after includes the safe complete
snapshot and both revisions; request UUID/actor/target/outcome/timestamp reuse P0.
Audit failure rolls back grants/revision. Safe denials remain independently audited.
JWT security versions, user membership/credentials/status do not change on grants.

Errors: 400 invalid/incomplete input; 401 invalid session; 403 protected/forbidden;
404 inactive/unavailable target; 409 stale_revision/stale_catalog/concurrent_change;
422 invalid reference/catalog/snapshot or oversized catalog; sanitized 500 failures.
Success is HTTP200 `data:null`, never a fabricated local Group record.

## Flutter and refresh

Active ordinary Group rows expose **Atur Akses** only with verified Groups UPDATE.
The dedicated guarded white/red dialog reuses showEditDialog and the persistent
AppShell. Snapshot loading/errors/read-only reasons are explicit. READ and CUD
are per row; enabling CUD enables READ, disabling READ clears that row's CUD.
Parent bulk selection affects itself plus **visible editable descendants** only,
with mixed/indeterminate state. Collapsed descendants and frozen rows are untouched.
Collapse has no persistence effect; iterative traversal prevents recursive cycles.
Parent grants never authorize child endpoints implicitly.

Single-flight blocks saving close/ESC/double click. Dirty cancel asks discard;
409/404 keeps edits and blocks resubmit until explicit reload/discard. No merge or
automatic write retry. Timeout/5xx/malformed success is unconfirmed and blocks a
blind retry. After commit the authoritative listing and acting session refresh;
refresh failure is distinguished from a committed grant mutation.

Account menu **Muat Ulang Izin** calls the existing authenticated
`/auth/me/sidebar-access`, without password reset, JWT reissue, polling or sync.
403 still refreshes; 401 invalidates the scoped session. Offline read refresh can
verify connectivity again, but cached offline authority cannot administer Groups.
Other devices receive no push; they must refresh/login. Backend reads current
Group grants on their next protected request, including revocations. Ordinary
membership with admin-menu flags does not make a user Superadmin.

## Executed automated validation

- Focused P0/Groups V1/V2 PostgreSQL tests, including malformed payloads, hidden
  preservation, revision/catalog conflicts, consistent concurrent reads, zero
  editable catalog, ambiguous grants, rollback, isolation and next-request RBAC.
- Actual authenticated Flutter HTTP Groups V2 save/reopen/revoke/restore using a
  minimum SQL runtime role, same member JWT; Users V1 and Groups V1 HTTP regressions.
- Focused Flutter API/widgets/auth/refresh/guards, four AppShell desktop sizes:
  1920x1080,1728x900,1366x768,1080x640. Query-only/in-memory SQLite protections.
- Python predicates test exact final state and reject grant/catalog/user/SQLite
  drift. Dedicated Windows helper tests verify DPAPI/profile isolation, actual
  HTTP binding and least privilege without changing the fresh INITIAL fixture.
- Final test counts/analyze/build results are recorded in the implementation
  report. No full regression or interactive Windows acceptance is claimed.

Final executed results (20 November2026): **56 Go leaf scenarios PASS, no skipped
cases** in the opt-in disposable run, including the three authenticated Flutter
HTTP wrappers (Users V1, Groups V1, Groups V2). **78 focused Flutter tests PASS**,
plus those3 real HTTP tests and1 new-profile SQLite provisioning test. Windows
helper2 tests PASS on this fresh profile; Python Groups V1/V2 predicates4 PASS.
`flutter analyze`: no issues. Windows debug build of
`groups_v2_acceptance_main.dart` with this profile/helper pin: PASS.

Ignored evidence logs: `.local/groups-v2-focused-final.log`,
`.local/groups-v2-runtime-guards.log`, `.local/groups-v2-http.log`,
`.local/groups-v2-http-final.log`, `.local/groups-v2-go-final.log`,
`.local/groups-v2-prepare.log`, `.local/groups-v2-analyze.log`.

## New Windows acceptance fixture (actual INITIAL output)

ID **be7c9302104004c5d6be7f8289f1e161**.
Root `%TEMP%\notaris-payment-be7c9302104004c5d6be7f8289f1e161`.
PostgreSQL **127.0.0.1:55797**, HTTP **127.0.0.1:55885**,
database `groups_v2_be7c9302104004c5d6be7f8289f1e161`.
Marker `NOTARIS GROUPS V2 DISPOSABLE <id>`; DPAPI/sealed manifest, owner ACL,
source/helper hash pin, exact live database/data_directory/role binding.

SQLite **v27**, integrity **ok**, FK **0**, **44** protected table fingerprints;
two fictional Notaris/PPAT transactions and two500,000 payments. Query-only runtime,
startup migrations disabled, all other HTTP clients remain UiSmoke, sync OFF.

PostgreSQL baseline: **18 groups** (17 active/1 inactive), **17 users**, **23 grants**,
audit0. Protected Superadmin groups101/102 each have7 grants. Group201 **CS** has
7 active/8 total members and8 grants. Group202 has1 grant; Group203 has none.
All Group revisions and user security versions start1.

Editable Sidebar IDs: **1 Users,2 Groups,3 Sidebars,4 Petugas,10 Master,11 Pemohon**.
Master10 is non-navigable parent of4 and11. CS editable flags start **0000**.
Frozen:20 Historis/inactive flags **1100**;21 unsupported parent999 flags **1010**.
Both frozen grant records and all other Groups' grants must remain byte-for-byte
equivalent in PostgreSQL row fingerprints throughout acceptance.
Catalog fingerprint:
`2d337206565264e564704ab34248777b9746834c0b51c488c1bd626362ef91c3`.

App SQL role has reference SELECT, Group revision-only UPDATE, grant INSERT and
flag/provenance-column UPDATE, audit INSERT and required sequence USAGE. No user
identity writes, metadata writes, grant DELETE or mutable audit privilege. This
acceptance backend exposes access PUT only; Group lifecycle/User mutations are
not registered here. Normal Groups V1 lifecycle remains tested in the real router.

INITIAL passed before UI. Latest evidence:
`%TEMP%\notaris-payment-be7c9302104004c5d6be7f8289f1e161\postcheck-initial-1795142201815839600.json`.
Cluster is stopped. Do not rerun prepare or repin this profile. Old Users/Groups V1,
promotional, financial and Materai profiles are not reused or modified.

## Operator commands — NOT executed interactively by Codex

Terminal1 at repository root:

```powershell
$id = 'be7c9302104004c5d6be7f8289f1e161'
$runner = '.\scripts\groups-v2-acceptance.py'
python $runner backend --id $id
```

Terminal2, same variables:

```powershell
$id = 'be7c9302104004c5d6be7f8289f1e161'
$runner = '.\scripts\groups-v2-acceptance.py'
python $runner check --id $id --expect initial
python $runner credential --id $id --account admin.groups
python $runner launch --id $id
```

Passwords appear only in a topmost native Windows credential dialog. Do not
scan/log/share them. Sign in normally; System → Groups; search **CS** (ID201).
Only exercise Atur Akses in this profile; no operational transaction/Master edits.
Launch again with the same command as needed. Backend stays up for postchecks.

Flags below use READ/CREATE/UPDATE/DELETE order. Every row except Petugas4 retains
its baseline flags. Stages OPEN through ENABLE-CUD may be checked with Flutter
open because they are unsaved UI steps; other postchecks require Flutter closed.
Never close/discard before SAVE if continuing those unsaved checkbox steps.

| Stage | Exact UI action / expected visible result | PostgreSQL | Exact postcheck |
| --- | --- | --- | --- |
| INITIAL | Before UI |CS revision1, editable0000,audit0 | `python $runner postcheck --id $id --expect initial` |
| LIST | Real Groups/CS row, protected labels |Unchanged | `python $runner postcheck --id $id --expect list` |
| OPEN | Atur Akses CS; identity/revision1/7active; historical rows disabled |Unchanged | `python $runner postcheck --id $id --expect open` |
| EXPAND | Collapse/re-expand Master; no checkbox change |Unchanged | `python $runner postcheck --id $id --expect expand` |
| ENABLE-READ | Check **Petugas READ only**; do not save/close yet |Unchanged | `python $runner postcheck --id $id --expect enable-read` |
| ENABLE-CUD | Check Petugas CREATE/UPDATE/DELETE, leave all other editable rows0000. Parent is mixed; no implicit READ inheritance |Unchanged | `python $runner postcheck --id $id --expect enable-cud` |
| SAVE | Simpan Perubahan once; close Flutter |CS revision2,Petugas1111,audit1success; backend probes all200 | `python $runner postcheck --id $id --expect save` |
| REOPEN | Open same editor: Petugas1111, others unchanged; close without saving |Same revision2/audit1 | `python $runner postcheck --id $id --expect reopen` |
| REVOKE | As admin, uncheck Petugas READ: CUD clears; save once, close |CS revision3,Petugas0000,audit2success; probes403 | `python $runner postcheck --id $id --expect revoke` |
| PERMISSION-REFRESH | Login admin.biasa (CS), use account → Muat Ulang Izin; Petugas absent. Inspect no administrative access. Close |Same revision3; membership/SV unchanged | `python $runner postcheck --id $id --expect permission-refresh` |
| CONFLICT | Admin opens CS revision3, unsaved edit; run guarded conflict-edit below; save stale UI once →409; preserve/review edits then discard without retry; close |CS revision4,Petugas1000; audit3success +audit4denied stale_revision | `python $runner postcheck --id $id --expect conflict` |
| DENIED | Login admin.biasa; Groups unavailable; no mutation attempt |Same; backend read200/CUD403 | `python $runner postcheck --id $id --expect denied` |
| PROTECTED | Login admin; protected Superadmin rows show no Atur Akses action; do not forge a manual request |Same | `python $runner postcheck --id $id --expect protected` |
| RECOVERY | Verify both protected recovery Groups still active/read-only; close |Recovery PASS | `python $runner postcheck --id $id --expect recovery` |
| RESTART | Relaunch; CS revision4/Petugas1000 and frozen rows retained; close |Same | `python $runner postcheck --id $id --expect restart` |
| FINAL | Close Flutter; verify all protections |18groups/17users/23grants;3success+1denied; protected fingerprints unchanged | `python $runner postcheck --id $id --expect final` |

For affected-user addition visibility, after SAVE optionally login admin.biasa,
use **Muat Ulang Izin**, inspect Petugas visible, then logout/admin before REVOKE.
No business actions. This creates no audit/membership changes. Same-token stale
client refresh and immediate backend enforcement are additionally proved by the
automated authenticated HTTP test, not inferred merely from hidden navigation.

Credentials for denied/affected account:

```powershell
python $runner credential --id $id --account admin.biasa
```

Conflict setup, **only after PERMISSION-REFRESH**:

1. Login admin.groups, open Atur Akses CS at revision3, change a checkbox without
   saving. Leave Flutter open.
2. Another terminal:

```powershell
python $runner conflict-edit --id $id
```

The guarded single invocation performs one ordinary authenticated access PUT,
Petugas1000 at expected revision3. Lock/evidence retained on ambiguity; no retry.
3. Return to stale editor, Save once. Expect409; do not reload/resubmit in this
   exact scenario. Discard, close Flutter, run CONFLICT postcheck.

Every postcheck compares SQLite44 fingerprints, integrity/FK, Group metadata,
memberships/security versions, protected/hidden grants, catalog and exact audit.
When backend is running it also performs authenticated **read-only** permission
probes through the actual Go middleware: no financial/Master mutation is needed.
Probe GETs do not append administrative denials. Negative payload/protected PUT,
stale catalog, rollback and concurrent cases run only in automated fresh clusters.

At any mismatch stop; never rewrite baseline, remove ambiguous locks, retry a
write automatically, reset/restore or edit protected data. Read-only diagnosis:
`python $runner state --id $id`.

Finish: close Flutter, Ctrl+C backend, then:

```powershell
python $runner stop --id $id
```

Data/evidence retained; no destructive cleanup.

## Operational prerequisites and deferred scope

Operational use requires separately approved schema/P0 deployment review, backup,
runtime minimum SQL grants (including unique-index-backed grant upsert), verified
recovery accounts, coordinated frontend/API cutover, and exclusion of obsolete or
external uncoordinated writers. No operational migration/grant/activation occurred.
All old acceptance profiles remain untouched. Sidebar definitions CRUD/listing
wiring, role promotion, membership editing, per-user overrides, reactivation,
offline administration and Groups/cloud/bidirectional sync remain outside this work.
