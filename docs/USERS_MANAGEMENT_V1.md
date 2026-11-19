# Users Management V1

Online Users administration implemented on the existing P0 security foundation.
Operational activation **OFF**; manual Windows acceptance **PENDING**. No
operational DDL/grants or account mutations are authorized by this implementation.

## Source and authorization

PostgreSQL is authoritative. Flutter stores neither Users nor password hashes in
SQLite and has no administrative outbox/offline mutation queue. Ordinary
operational offline access is unchanged; Users requires an online, unexpired,
versioned Superadmin session and exactly one active canonical `users` grant with
READ and the requested action. The server rechecks current active actor/group,
security version, permission, target policy and recovery invariant. Superadmin
is not a grant bypass. The promotional InheritedWidget scope short-circuits
Users before resolving its API provider; the recorded profile is not upgraded.

## HTTP contract under `/api/v1`

| Method/path | Request | Successful result |
| --- | --- | --- |
| GET `/users` | `page` >=1, `page_size` 1..50 (Flutter 10), optional `search` <=100 bytes, `group_id` positive, `status` 0/1 | `data: {items,total,page,page_size,groups}` |
| GET `/users/:id` | Positive ID | Safe current profile/revision |
| GET `/users/assignable-groups` | None | Active ordinary group references |
| POST `/users` | group_id, nama, username, email, optional no_telp/alamat, password, password_confirm | 201 + committed safe profile |
| PUT `/users/:id` | Profile fields + expected_revision | 200 + committed safe profile |
| DELETE `/users/:id` | expected_revision | 200; soft deactivate |
| POST `/users/:id/password-reset` | expected_revision, password, password_confirm | 200; reset separately from profile edit |

All use the existing success/data/request_id envelope. Profile projection:
`id, group_id, nama, username, email, no_telp, alamat, status, revision,
group_nama, group_jenis, group_status`. No hash/security_version/photo/secret is
returned by Users endpoints. Group filter references contain only ID, name,
classification and status (bounded to 500). The page and total share a single
SQL CTE snapshot, ordered by unique user ID. Search uses parameterized literal
case-insensitive substring matching; `%` is not an unrestricted wildcard.

Edit never includes password/status/image/audit fields. Unknown fields are
rejected by the bounded P0 decoder. Status 0 is retained after edit; malformed or
missing response status is an error rather than an active account. Group
assignment uses actual IDs, only active ordinary groups, and revokes old JWTs
through security_version. No automatic Petugas creation/linking occurs.

## UX and failure semantics

Existing persistent AppShell, MasterDataViewport/table scrolling and guarded
white/red edit dialog are reused. Server pagination/search/group/status filters,
refresh, loading/empty/offline/denied states replace the prototype list. Self and
privileged targets are visible but protected. Reset and Nonaktifkan Akun are
separate confirmed actions. No activation, Superadmin promotion/creation, hard
delete, photo, Groups/grants editor or global sync is introduced.

ESC/Cancel/close use showEditDialog: dirty discard, controller lifetime until
route completion, dropdown overlay teardown and no dismissal while saving.
Single-flight covers group loading and mutation. 409 loads the current target
but blocks resubmission until the operator explicitly reviews server data.
Unknown network/5xx mutation outcome also blocks retry: close, refresh, inspect
server state first. Never infer success from local form state.

401 invalidates only the request's current scoped session. 403 refreshes effective
permissions; unavailable refresh marks the session offline. Safe code/request ID
messages never echo SQL, arbitrary backend bodies or request credentials. P0
transactional audit/recovery/concurrency rules remain unchanged. See
[security foundation](USERS_SECURITY_FOUNDATION.md) for deployment prerequisites.

## Disposable Windows acceptance

New profile: `03504cd666bcbd8c3e80e395b260d529`.
Root: `%TEMP%\notaris-payment-03504cd666bcbd8c3e80e395b260d529`.
Owned PostgreSQL **127.0.0.1:55795**, HTTP **127.0.0.1:55883**,
database `users_v1_<profile>`, marker `NOTARIS USERS V1 DISPOSABLE <profile>`.
Distinct DPAPI/signed secrets, manifest/owner marker and helper hash; no caller
DSN or operational fallback. Generated passwords appear only in a Windows dialog,
never in reports/postcheck JSON. Do not scan/share that dialog. Ctrl+C copies
the native MessageBox contents on Windows if needed; paste only into the intended
password field and clear the clipboard afterwards.

SQLite is a newly provisioned v27 fixture: two fictional transactions with
500,000 initial payments each. All tables, including Materai, cloud mappings,
cursors and ACK state, are fingerprinted. Startup disables migration and enables
query_only; no SQLite Users is added. The normal authenticated client retains
UiSmoke. Only the dedicated Users API override can mutate: it repeats live
HTTP→owned PostgreSQL attestation and P0 online/action checks. Other operations,
cloud sync and background publishers stay blocked. API exposes no Groups/grants
or cloud writer. App role has Users SELECT/INSERT/UPDATE, reference SELECT,
audit INSERT and required sequence USAGE; no DDL or DELETE privilege.

The source hash pin intentionally rejects a changed helper. Never repin an old
profile automatically. Only `prepare` creates a new ID; it cannot reset/reuse
the promotional or earlier financial/Materai profiles.

### Operator startup (not executed on the operator's behalf)

From the repository root, Terminal 1:

```powershell
$id = '03504cd666bcbd8c3e80e395b260d529'
$runner = '.\scripts\users-v1-acceptance.py'
python $runner backend --id $id
```

Leave backend running. Terminal 2 uses the same two variables:

```powershell
$id = '03504cd666bcbd8c3e80e395b260d529'
$runner = '.\scripts\users-v1-acceptance.py'
python $runner check --id $id --expect initial
python $runner credential --id $id --account admin.users
python $runner launch --id $id
```

Login normally as `admin.users`; open System → Users. The backend performs real
bcrypt/JWT authentication. The shared sidebar/shell remains persistent. All
postchecks except the explicit conflict setup require Flutter closed. Commands
`check`, `state` and `postcheck` do not mutate business data. They write local
audit evidence only. `launch` verifies actual target and protected fingerprints,
not a stale INITIAL state after later phases. Do not run prepare again.

### Deterministic sequence and postchecks

17 initial users: admin 101, protected recovery 102, ordinary admin 201,
Petugas/CS 202, targets 301..312, inactive 399. Groups: privileged 101/102;
ordinary active 201 Operasional, 202 Pelayanan, 203 Arsip; inactive 204.
All initial revisions/security versions 1; two legitimate recovery administrators.
No account identity is inferred from its name. Passwords are random per profile.

For each row, close Flutter then run
`python $runner postcheck --id $id --expect <phase>`.
Expected marker: `USERS_V1_<PHASE>_PASS` (hyphen becomes underscore).
An unchanged database postcheck alone does not prove the operator saw the UI;
record the visual result separately. Do not add exploratory mutations.

| Phase | Explicit UI action / expected screen | Expected committed DB |
| --- | --- | --- |
| initial | Before UI | 17 users, audit 0; protected fingerprints match |
| list | Open Users as admin; real data, active/nonactive badges | Unchanged |
| search | Search `operator.01`, then a nonexistent value; clear | One matching user, empty state; DB unchanged |
| filter | Group Pelayanan; status Nonaktif; clear filters | Actual ID filter; inactive399 visible under its group; DB unchanged |
| pagination | Next then Previous with no filters | 10 / 7 rows, correct disabled state; DB unchanged |
| create | Tambah User: Nama **Operator Baru**, username **operator.baru**, email **operator.baru@example.invalid**, group **Operasional**. Obtain initial password via `credential --account operator.baru`; enter confirmation. Save once | ID1001 active, revision1/sv1; user_create audit1 |
| edit | Search operator.baru; Edit name **Operator Baru Diperbarui** only | ID1001 revision2/sv1, user_update audit2; no password/status change |
| group-assign | Edit same target; group **Arsip** only | ID1001 group203 revision3/sv2; audit3 |
| deactivate | Nonaktifkan same target; cancel once (no write), reopen, confirm once | Row retained status0 revision4/sv3; user_deactivate audit4 |
| password-reset | See explicit setup below; reset active **operator.02** (ID302), not the inactive created target | ID302 remains active revision2/sv2; password_reset audit5, old JWT401 |
| conflict | See explicit setup below; stale editor gets409, reloads server record; close without saving again | ID301 name Operator 01 Terbaru revision2/sv1, audit6 success + audit7 stale_revision denied |
| denied | Logout; login **admin.biasa**, then **petugas.users** using each own credential dialog; open Users | Denied/no mutation actions despite ordinary group's explicit grants; DB unchanged |
| offline | Login admin online; stop Terminal1 backend Ctrl+C; Refresh Users in Flutter. No create from unavailable data, no queue. Close Flutter; restart backend for postcheck | Error, no false success; all business state unchanged |
| restart | Restart launch; login admin if needed; inspect saved/inactive target and protected accounts, no save | Same state and revisions |
| final | Inspect all evidence and close | 18 users, 6 success +1 denied audit, all protected references/financial/Materai/cursor fingerprints unchanged |

Password-reset setup, **after deactivate**, with Flutter closed and backend up:

```powershell
python $runner reset-capture --id $id
python $runner credential --id $id --account reset.operator.02
python $runner launch --id $id
```

Search exact username operator.02, separate Reset Password dialog, paste generated
reset password twice and explicitly confirm. Close Flutter, postcheck
`--expect password-reset`. Capture retains the original signed JWT encrypted with
profile-bound DPAPI; proof checks it is still unexpired and rejected401 after
reset. Complete reset→FINAL within its 120-minute validity. If proof expires,
STOP for review; no expiry override, silent recapture or reset retry.

Conflict setup, after password-reset, backend running:

1. Launch, search operator.01 and open Edit at revision1. Change name to
   `Input tertinggal` but do not save yet.
2. Another terminal: `python $runner conflict-edit --id $id`. This is one explicit
   bounded normal HTTP update of ID301, expected_revision1, name
   `Operator 01 Terbaru`. Its attempted lock is retained; never retry on ambiguity.
3. Save the stale Flutter dialog once. Expect409, no overwrite, fresh server
   detail. The reload button requires explicit review; for this scenario close
   and discard input, **do not save again**. Close Flutter; postcheck conflict.

`credential --account admin.biasa` / `petugas.users` obtains other login fixtures.
Do not attempt a protected account edit: those paths are covered by automated
tests and would deliberately add denied audit entries outside this exact sequence.

Stop: close Flutter, Ctrl+C backend, then `python $runner stop --id $id`.
Data/evidence remain; no automatic cleanup, reset, restore or audit rewriting.

## Automated validation and remaining gates

`python scripts/test-users-security-disposable.py --flutter` owns a separate
temporary PostgreSQL55793 cluster, applies the existing P0 proposal, runs P0 and
V1 endpoint tests plus actual Flutter UI→HTTP mutations and verifies committed
revisions/security versions, audit and unchanged grants. It stops its cluster.
It does not mutate the prepared manual profile. Focused Flutter tests cover
API DTOs, lifecycle/permissions/conflict, reference compatibility and layout at
1920×1080, 1728×900, 1366×768 and 1080×640. The dedicated v27 fixture test provisions
only a NEW profile when passed its explicit Users marker.

Manual operator acceptance remains separate. Operational cutover requires the
P0 backup/migration/recovery review, least-privilege grants and all-instance JWT
cutover approval. No production schema, RBAC, account, profile or cloud setting
is changed by a successful disposable test.

Validation executed on 19 November 2026:

- 17 Go endpoint/security/atomicity/migration/real-HTTP scenarios passed on the
  owned 55793 cluster (including Flutter UI create/edit/group/deactivate/reset).
- Two Windows helper isolation/active-connection/least-privilege tests passed,
  including read-only verification on the new Users profile.
- 58 focused Flutter service/widget/auth/Petugas/Materai/payment tests passed;
  the real HTTP widget path and new-profile fixture test also passed separately.
- Two Python predicate tests passed: strict account/revision/audit expectations,
  protected-data mismatch and active-launch rejection.
- `flutter analyze`: no issues. Dedicated Windows debug build: passed, not run.
- New profile INITIAL passed, 44 SQLite tables fingerprinted, schema27,
  integrity ok/FK0; 17 PostgreSQL users, audit0, recovery/integrity PASS.
  Evidence: `postcheck-initial-1795076689601999900.json` inside its profile root.
- PostgreSQL55793 test cluster stopped/deleted by its owner; new acceptance
  PostgreSQL55795 stopped and retained. Operator phases after INITIAL not run.
