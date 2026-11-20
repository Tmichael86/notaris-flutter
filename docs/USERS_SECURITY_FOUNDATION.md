# Users P0 security foundation

Status: implemented for isolated verification; operational activation **OFF**.
Architecture remains User → one Group → Sidebar grants. Flutter Users V1 now
uses this API; see [Users V1](USERS_MANAGEMENT_V1.md). This does not grant an
account or deployment any access. The recorded promotional profile remains isolated.

## Authorization and supported operations

`USERS_SECURITY_ENABLED=false` is the default. It blocks Users administration
(including listing), Groups administration (including read) and grant replacement with HTTP 503.
There is no fallback to the old unversioned writers. Ordinary login and existing
local-first operations remain available before the coordinated JWT cutover.

When enabled, Users READ/CREATE/UPDATE/DELETE require the current active backend
user, current active Group with exact `group_jenis=superadmin`, a matching token
security version, and exactly one active canonical `users` grant. READ plus the
requested action must be 1. No display name, account ID or JWT group label grants
authority. Groups administrative reads/mutations use the same role check and the `groups` action.
Ambiguous duplicate grants fail closed; they are never merged permissively.

All registered Users/Groups/grant writers use `services.Administration`. The old
UserService/GroupService mutators and SidebarService.ReplaceGroupAccess reject
calls. Low-level repositories are not HTTP authorization boundaries; trusted
provisioners/DB owners must not be exposed as request writers.

| Endpoint under `/api/v1` | Contract |
| --- | --- |
| GET `/users` | Strict Users READ; bounded page object, active/inactive, literal search, group/status filters; see V1 contract |
| GET `/users/:id` | Strict Users READ; current safe profile/revision for explicit conflict review |
| GET `/users/assignable-groups` | Strict Users READ; active `user` Groups only |
| POST `/users` | Users CREATE; group_id, username, email, nama, optional no_telp/alamat, password and password_confirm |
| PUT `/users/:id` | Users UPDATE; same profile fields, required expected_revision; no password/status/role/audit fields |
| DELETE `/users/:id` | Users DELETE; body `{ "expected_revision": n }`; soft deactivate only |
| POST `/users/:id/password-reset` | Users UPDATE; expected_revision, password, password_confirm |
| GET/POST/PUT/DELETE `/groups` or `/groups/:id` | Strict Groups action; bounded listing/current detail; ordinary lifecycle only, Superadmin targets protected; revision and deactivation membership confirmation required; see [Groups V1](GROUPS_MANAGEMENT_V1.md) |
| PUT `/groups/:id/sidebar-access` | Strict Groups UPDATE; expected_revision and access array; atomic replacement |
| GET `/petugas/references/users/:id` | Petugas READ; one active user/group reference, **only id/status**, no Users listing |

Requests are bounded to 32 KiB and unknown administration fields are rejected.
Username: trimmed ASCII letters/digits/`._-`, 1–64 bytes; name: 1–160 bytes;
email: a plain parsed address ≤254 bytes; phone ≤32, address ≤1000 bytes.
Password: 12–72 bytes, exact nonempty confirmation, server-side bcrypt default
cost. No plaintext/hash is returned or written to the audit. CREATE cannot
assign a Superadmin Group; transitions out of privileged Groups are also blocked
pending a reviewed promotion/demotion policy. Self group, login-identity,
deactivation and administrative reset changes are rejected. Profile password
change and explicit reactivation are not implemented here. Edits preserve
inactive state. Existing client CRUD payloads must adopt this versioned contract
in Flutter Users V1; they are intentionally not silently downgraded.

## Atomicity, recovery and audit

Each administration write takes transaction advisory lock `71920261119`, then
locks its target row, checks expected_revision, validates references and policy,
mutates explicit columns and increments revision. Under PostgreSQL READ COMMITTED,
the shared lock serializes all supported recovery-sensitive writers. Authorization
and the recovery invariant are checked again before the audit/commit. No physical
user deletion or Superadmin-classification writer is exposed.

A recovery-capable administrator is an active user with a parseable bcrypt
credential in an active exact Superadmin Group; unambiguous, active, routed
`users` and `groups` definitions must each have READ/CREATE/UPDATE/DELETE, and
`sidebars` must have READ. Grant editing is currently a Groups UPDATE operation;
there are **no Sidebar disable/delete HTTP routes**. Any future Sidebar writer
must join this same transaction lock/invariant before being exposed. Direct DBA
SQL, obsolete backend instances and external writers cannot be serialized by
this application guard: deployment must prohibit/drain those paths.

Every successful account, Group or grant change commits together with an
`administrative_audit` row: verified actor, target, action, database timestamp,
server-generated UUID request ID, non-secret before/after state and safe source.
Group assignment is visible in the user_update before/after group_id delta.
The audit trigger rejects UPDATE/DELETE/TRUNCATE. Administrative policy/input
denials use an independent bounded DB operation after rollback, so their events
survive. A failed denial audit returns `security_event_failed`, never a false
audit-success claim. Invalid JWTs are rejected before trusted actor extraction
and are not attributed to an arbitrary account. Failed/unavailable database
logging cannot be claimed durable. Successful mutation cannot commit if its
mandatory audit insert fails.

Expected response classes: 200/201 success; 400 malformed/bounded/unknown input;
401 invalid session; 403 forbidden/self/privileged transition; 404 unavailable
target; 409 stale revision/unique identity/recovery protection/concurrent change;
422 invalid assignable reference; 500 sanitized internal/audit failure; 503
cutover disabled. Bodies expose stable `code` and `request_id`, no SQL/bcrypt
error detail. Sensitive mutation SQL logging is disabled to prevent bind-value
leakage on errors.

## Session cutover and Flutter compatibility

All JWT parsing requires HS256, issuer `backend-notaris-go`, valid mandatory exp,
positive uid/gid. Enabled cutover additionally requires positive `sv`, current
active user/group and exact users.security_version on **every** JWT-protected
route including `/auth/me`, sidebar access, references and ordinary CRUD.
The stale gid claim cannot grant current permissions.

Login issues sv after cutover. Administrative password reset, group assignment,
username/email security changes and deactivation increment the target version;
group deactivation revokes all member versions. Effective grants are read from
the database per request. A grant edit therefore takes effect immediately even
without reissuing JWTs. Group name edits do not confer privileges.

Legacy versionless JWTs are rejected after cutover: **all accounts must log in
again**, across every backend instance. Before cutover they cannot access Users
administration. Do not roll back to an older binary that reopens unsafe writers.

Flutter binds authenticated requests to the configured HTTP origin, attaches the
existing token, rejects offline/expired/versionless/non-admin
Users and Groups mutation requests before HTTP, and still relies on backend RBAC.
401 clears only scoped authentication; 403 refreshes online permission evidence.
Connectivity failure preserves operational local data and marks the session
offline rather than conferring cached administrative privileges. Seven-day
operational fallback cannot administer Users. DPAPI, signed offline demo role
verification, SQLite schema, financial rules and sync activation are unchanged.
Petugas provenance now uses the narrow reference endpoint; exact-one active
Petugas rules remain in the existing operational repositories.

## Migration and deployment gate (not executed operationally)

Proposals:

- `backend-notaris-go/migration_proposals/20261119_users_security_preflight.sql`
- `backend-notaris-go/migration_proposals/20261119_users_security.sql`

The first is read-only and enumerates normalized identity/cross-login collisions,
duplicate grants/codes, invalid references/status/flags, and conflicting metadata.
The second must run **once inside an approved transaction**, adding user revision
and security_version, Group revision, normalized unique login indexes, unique
grant/code indexes, NOT NULL/FK/status constraints and append-only audit metadata.
It does not normalize, clean up, assign grants or change any password. Reapply
fails; no IF NOT EXISTS shortcut conceals a partially conflicting schema.
No startup AutoMigrate or automatic operational DDL is introduced.

Before a permanent rollout, separately approve and verify:

1. Exact target/owner/application role, schema, existing data/constraints, identity
   collisions and canonical menu codes. Resolve anomalies by reviewed decisions;
   the migration must not automatically repair them.
2. Consistent verified backup, maintenance/drain of old administrative writers,
   rehearsal on an actual approved restore, and at least one valid recovery admin.
3. Least-privilege app role: required SELECT and scoped Users/Groups/grant DML;
   INSERT (and approved audit READ) on administrative_audit plus sequence USAGE.
   No audit rewrite, DDL, table ownership, bypass trigger or implicit GRANT here.
   Real operational ownership, privileges and existing admin fitness are **unverified**.
4. Atomic proposal apply with ON_ERROR_STOP, independent postcheck, deployment of
   all new backend instances, then explicit security cutover and coordinated re-login.
5. On ambiguity stop and investigate read-only. No retry/drop/restore automatically.
   Before commit, rollback the transaction. After commit, preserve version/audit
   evidence and disable administration using the new binary while reviewing a
   forward fix; do not restore old unsafe administration or discard audits.

Startup checks required columns/audit table and recovery capability before serving
when enabled. This is a fail-closed prerequisite check, not production schema,
ownership or migration approval.

## Isolated verification

`python .\scripts\test-users-security-disposable.py` owns a fresh temporary
SCRAM PostgreSQL cluster, exact loopback port 55793, database
`users_security_disposable` and a verified synthetic marker. It cannot accept an
arbitrary target; inherited PG configuration and other opt-ins are removed.
Migration, HTTP authentication/authorization, concurrency and audit-failure tests
run there. No live data, SQLite development or prior demo profile is opened.
The cluster is stopped after success/failure. Go opt-in tests without the dedicated
DSN are skipped rather than silently targeting a default database.

Next sprint: Flutter Users V1 UI, versioned payload adapter/assignable Groups,
explicit password-reset UI and approved online integration. Operational migration,
promotion/reactivation policy, deployment RBAC review and Windows manual acceptance
remain separate gates. No global/background/bidirectional sync is activated.

### Verification checkpoint, 19 November 2026

- Fresh PostgreSQL disposable: **15 scenarios PASS** (7 HTTP authorization/auth,
  7 atomic/concurrency/recovery/audit, 1 migration guards). Cluster stopped.
- Existing Go services, middleware, config, paymentdemo and devfixture package
  regressions PASS; controllers compile. Separate opt-ins are not treated as
  executed operational integration tests.
- **87 focused Flutter tests PASS**, covering new auth gates plus Petugas
  references, isolated profiles, UI Smoke, Notaris/PPAT references, payment,
  Materai exact-one actor and AppShell startup. Existing Drift diagnostics about
  multiple isolated test connections are warnings, not failed tests.
- `flutter analyze`: no issues; Windows debug build PASS, binary **not launched**.
- No operational DB inspection/DDL/DML, original SQLite access, prior acceptance
  profile modification, operational credential issuance or production activation.
