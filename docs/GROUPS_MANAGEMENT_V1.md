# Groups Management V1

Secure online lifecycle for ordinary Groups, built on Users P0. PostgreSQL is
sole authority; no SQLite Groups ledger, offline writes, queue or sync is added.
Operational activation **OFF**. Operator Windows acceptance **PENDING**.

## Contract and security

All Groups administrative GET/POST/PUT/DELETE paths require enabled P0, a valid
HS256 issuer/expiry/versioned JWT, current active user/group, exact current
`superadmin` classification and one active routed canonical `groups` grant.
READ is required alongside the requested action. GET group sidebar-access is
also strict Groups READ. `/users/assignable-groups` stays independent Users READ:
only active ordinary groups, with stable IDs. Petugas reference policy is unchanged.

| HTTP `/api/v1` | Request | Committed result |
| --- | --- | --- |
| GET `/groups` | page>=1, page_size1..50 (UI10), search<=100 UTF-8 bytes, group_jenis user/superadmin, status1(default)/0/all | data:{items,total,page,page_size} |
| GET `/groups/:id` | Positive ID | Current safe record, including inactive/protected |
| POST `/groups` | group_nama, group_jenis:user | 200 data:null; ordinary active group, revision1, zero members/grants |
| PUT `/groups/:id` | group_nama, group_jenis:user, expected_revision | 200 data:null; active ordinary rename only, revision+1 |
| DELETE `/groups/:id` | expected_revision, expected_membership | 200 data:null; active ordinary soft deactivation, revision+1 |

Projection: id,group_nama,group_jenis,status,revision,active_members,total_members,
membership. No associated account identity/PII/password/security_version is returned.
Counts and page/total come from one SQL statement/snapshot, ordered by unique ID.
Search is parameterized literal case-insensitive substring (`strpos`); `%` and `_`
are text. Names are trimmed, 1..160 UTF-8 bytes; duplicate labels remain legal.
IDs, not names, identify mutations. No new schema/migration/name uniqueness rule.

`active_members` means users with status1 in the group, not a guarantee of access.
`total_members` retains inactive users. The opaque membership token is MD5 of an
ordered numeric member-ID/status snapshot (no credentials); it is a confirmation
change detector, not authentication. DELETE recomputes it under the shared P0
advisory lock **71920261119**, then checks revision/status/current authority and
recovery. Assignment/user activation changes cannot silently expand the confirmed
impact. A changed token returns409 membership_changed; grant replacement changes
Group revision and yields409 stale_revision. No automatic retry.

ALL `superadmin` Group targets are read-only for this lifecycle API, independently
of name/ID/actor. Existing P0 grant replacement remains separate and recovery-safe;
no grant controls/writers are added to the screen or acceptance server. Ordinary
promotion, privileged demotion, reactivation, hard delete and membership reassignment
are not implemented. Deactivation retains memberships/accounts/grants and increments
all affected users' security_version. Existing active sessions are rejected server-side.

Shared row locking, authorization recheck, last-recovery invariant and atomic
append-only audit are reused. group_create/group_update/group_deactivate successes
commit with the change; failures roll back; safe denials remain durable where DB
logging is available. Successful audit failure cannot leave a committed mutation.
Direct DBA/external obsolete writers must be prohibited/drained at deployment.

## Flutter

GroupsDesktopScreen replaces four dummy records and checkbox grant editor with
Riverpod server pagination, search, type/status filters, member counts, explicit
active/protected badges and guarded white dialogs. Existing AppShell and viewport
scrolling stay unchanged. Current detail is fetched before edit/deactivation;
confirmed member impact is explicit. No arbitrary save delays or fake persistence.

GroupApiService validates status/type/IDs/revision/counts/token fail-closed and
accepts P0 data:null success responses. UI reloads authoritative listing afterwards.
409 fetches current detail but requires explicit review/action before resubmission.
Unknown network, 5xx or malformed success blocks a blind retry and does not report
success. 401/403 reuse scoped logout/permission refresh. Error bodies are sanitized.
Single-flight, saving close guard and dirty/discard ESC reuse showEditDialog and
TransactionReviewDialog; controllers live through route teardown. Normal UiSmoke
still blocks writes. Promotional preview short-circuits the provider and is read-only.

## NEW disposable Windows profile

ID: **eb362ab61a5961e96c0733d70bffca69**.
Root: `%TEMP%\notaris-payment-eb362ab61a5961e96c0733d70bffca69`.
PostgreSQL **127.0.0.1:55796**, HTTP **127.0.0.1:55884**,
database `groups_v1_eb362ab61a5961e96c0733d70bffca69`.
Marker `NOTARIS GROUPS V1 DISPOSABLE <id>`. Source-pinned signed/DPAPI manifest,
Windows-owner ACL, exact connection database/host/port/role/data_directory checks.
Runtime HTTP attestation repeats before each Groups request; no caller DSN or
operational fallback. SQLite is newly provisioned v27, no startup migrations,
query_only, 44 protected table fingerprints. Two fictional transactions, two
500,000 initial payments; all cursors/ACK/Materai protected. No operational profile opened.

App role: reference SELECT, Groups INSERT/UPDATE, only users.security_version UPDATE,
audit INSERT and required sequence USAGE. No Users insert/identity change, DDL,
physical DELETE or mutable audit privilege. Only Groups lifecycle routes and a
read-only Users assignable reference exist on this isolated server. Other clients
retain UiSmoke; background/global sync and publishers remain OFF.

INITIAL fixture (derived from actual provisioned baseline): 18 groups =17 active,
1 inactive; 17 users; zero audit. Two protected Superadmin groups101/102 with one
recovery account each. Group201 Operasional:7 active/8 total; group202 Pelayanan:
7 active/7 total. Ordinary groups203 Arsip,204 Nonaktif and301..312 Grup Arsip1..12.
All revisions/security versions initially1. Sequence permits next new Group ID1001.

Do not reuse Users profile03504cd666bcbd8c3e80e395b260d529 or promotional
8dabee307092ae7f6398de5b55d95dc8. No files/data in either were accessed/changed.
Do not rerun prepare for this profile. A changed source/helper hash must stop;
never repin an existing profile or overwrite its evidence automatically.

### Startup commands (operator only, not run interactively by Codex)

Repository-root PowerShell Terminal1:

```powershell
$id = 'eb362ab61a5961e96c0733d70bffca69'
$runner = '.\scripts\groups-v1-acceptance.py'
python $runner backend --id $id
```

Keep backend up. Terminal2:

```powershell
$id = 'eb362ab61a5961e96c0733d70bffca69'
$runner = '.\scripts\groups-v1-acceptance.py'
python $runner check --id $id --expect initial
python $runner credential --id $id --account admin.groups
python $runner launch --id $id
```

Credential appears only in a Windows dialog. Do not scan/share/log it. Native
MessageBox Ctrl+C can copy its text if needed; transfer only the intended password
and clear clipboard afterwards. Login normally online, then System → Groups.
No hardcoded role or bypass. `admin.biasa` is an ordinary denied account with
explicit Groups grants: classification must still deny administration.

### Exact ordered phases

Close Flutter before every postcheck, except explicit conflict setup. For each
phase run its exact command below. PASS marker is `GROUPS_V1_<PHASE>_PASS`.
Postchecks are read-only business queries plus local evidence JSON. A PASS does
not alone prove the operator performed/saw the UI; record the visual result separately.
No exploratory mutations or protected-target attempts in this exact sequence.

| Phase | Operator action / visible expectation | PostgreSQL expected change | Exact command |
| --- | --- | --- | --- |
| INITIAL | Before UI |18 groups/17 users/audit0 | `python $runner postcheck --id $id --expect initial` |
| LIST | Real rows, member counts, active/protected labels | None | `python $runner postcheck --id $id --expect list` |
| SEARCH | Search Operasional:1 row; missing text:empty; clear | None | `python $runner postcheck --id $id --expect search` |
| FILTER | Type Superadmin:2 protected rows; Nonaktif:ID204; clear back to active | None | `python $runner postcheck --id $id --expect filter` |
| PAGINATION | Active default:10 then7 rows; Previous/Next disabled correctly | None | `python $runner postcheck --id $id --expect pagination` |
| CREATE | Tambah Grup, name **Grup Baru**, save once; ordinary/no automatic access | ID1001 active revision1, zero members/grants; audit1 group_create | `python $runner postcheck --id $id --expect create` |
| RENAME | Search Grup Baru; Ubah nama to **Grup Baru Diperbarui** only | ID1001 revision2; audit2 group_update | `python $runner postcheck --id $id --expect rename` |
| CONFLICT | Use setup below; stale save returns409; close/discard without resubmitting | Group201 name Operasional Terbaru revision2; audit3 success +audit4 denied stale_revision | `python $runner postcheck --id $id --expect conflict` |
| DEACTIVATE | Search Pelayanan ID202; Nonaktifkan; inspect7 active members; cancel once; reopen, explicitly confirm once | Group202 status0 revision2; all7 member security_versions2, identity/membership retained; audit5 group_deactivate | `python $runner postcheck --id $id --expect deactivate` |
| DENIED | Logout, credential admin.biasa, login; Groups denied; no action | None;17 users retained | `python $runner postcheck --id $id --expect denied` |
| OFFLINE | Login admin online; stop backend Ctrl+C; Refresh Groups; error, no offline mutation/queue. Close Flutter; restart Terminal1 backend for postcheck | None | `python $runner postcheck --id $id --expect offline` |
| RESTART | Relaunch, login if needed; inspect created/renamed/inactive/protected groups, no save | Same state | `python $runner postcheck --id $id --expect restart` |
| FINAL | Close Flutter; final protected-state verification |19 groups:17 active/2 inactive;17 users;4 success+1 denied audit; unchanged grants/protected rows/44 SQLite fingerprints | `python $runner postcheck --id $id --expect final` |

Launch again for each applicable phase using the same `python $runner launch --id $id`.
Conflict setup, after RENAME with backend up:

1. Launch, search Operasional (ID201), open Ubah Nama at revision1. Enter
   `Input tertinggal` but **do not save yet**.
2. Another terminal:

```powershell
python $runner conflict-edit --id $id
```

This one-time guarded normal HTTP PUT renames201 to Operasional Terbaru at revision1.
It retains conflict-attempted.lock. No automatic retry on ambiguity. Return to stale
Flutter dialog and Save once. Expect409 and server-review option. For this scenario,
close/discard without another save. Close Flutter, run conflict postcheck.

Denied login credential:

```powershell
python $runner credential --id $id --account admin.biasa
```

Then relaunch/login as required. Backend and fixture source remain the same. Stop
at any state/audit/fingerprint/role/ownership mismatch; never rewrite baseline,
restore, remove attempted locks or retry an ambiguous mutation automatically.
For read-only diagnosis: `python $runner state --id $id`.

Finish: close Flutter, Ctrl+C backend, then:

```powershell
python $runner stop --id $id
```

Cluster data/evidence retained. No automatic destructive cleanup.

## Validation and deployment gates

- `python scripts/test-users-security-disposable.py --flutter` creates a fresh owned
  PostgreSQL55793 cluster for Groups/P0 and real Flutter HTTP tests, then stops it.
- Focused API/provider/widgets cover paging/filter/status/permissions/sanitized
  failures/data:null, conflict/timeout, saving/single-flight/ESC/discard and shared
  shell layouts1920x1080,1728x900,1366x768,1080x640.
- Dedicated helper tests verify cross-profile isolation, real authenticated HTTP
  binding, least privilege and unchanged INITIAL data on the NEW Groups profile.
- Python predicate tests check exact group/revision/member revocation/audit and
  rejection of protected SQLite/grant/user drift.
- Windows debug build is not an interactive acceptance result.

Executed validation (20 November 2026, not historical-only evidence):

| Check | Actual result |
| --- | --- |
| Groups/P0 disposable PostgreSQL suite | 31 leaf scenarios PASS; owned cluster stopped |
| Authenticated Flutter HTTP | Groups lifecycle and Users V1 regression, both PASS; Groups ran under minimum SQL runtime privileges |
| Focused Flutter | 74 distinct API/auth/provider/widget/protected-operation tests PASS across focused runs |
| New-profile SQLite provisioning | 1 PASS; v27, integrity ok, FK0, 44 protected table fingerprints |
| Windows helper | 2 PASS, including actual new-profile DPAPI/HTTP/least-privilege read-only checks |
| Python acceptance predicates | Groups2 + Users2 PASS |
| flutter analyze | No issues |
| Windows debug build | PASS, groups_acceptance_main.dart with this profile/helper pin |
| New-profile INITIAL | GROUPS_V1_INITIAL_PASS; no operator UI acceptance performed |

Repository-local ignored logs: `.local/groups-v1-disposable-tests.log`,
`.local/groups-v1-flutter-focused.log`, `.local/groups-v1-final-focused.log`,
`.local/groups-v1-protected-regression.log`, `.local/groups-v1-prepare.log`.
Latest INITIAL evidence is
`%TEMP%\notaris-payment-eb362ab61a5961e96c0733d70bffca69\postcheck-initial-1795133761618780500.json`.
The new acceptance cluster is stopped; no backend/Flutter acceptance process is
left running. No full regression or operational database test was performed.

Operational deployment is NOT approved: verify current schema/proposal, backup,
least-privilege Groups sequence/table grants and users.security_version column
UPDATE; compatible backend/frontend rollout, drain legacy writers, coordinated
P0 JWT cutover and proven recovery admins require their own review/approval.
No production DDL/activation is performed here. Sidebar editing, role promotion,
reactivation, hard delete, automatic reassignment, per-user overrides and cloud
administration remain outside V1.
