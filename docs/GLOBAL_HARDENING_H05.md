# H05 — Backend P0 security release gate

Baseline `edf1cc0`, branch `feature/pemohon-cloud-sync`.
Scope: normal Go HTTP backend startup. Operational activation remains OFF.

## Previous behavior

`config.LoadConfig` implicitly read the working-directory `.env`, defaulted
`USERS_SECURITY_ENABLED` to false, and coerced malformed boolean values through
Viper. `Administration.Ready` returned success when disabled and otherwise
checked only three column names, audit-table existence, and recovery-account
presence. Normal HTTP bound `:PORT` except for the special acceptance path.
This allowed ordinary startup without current-session security-version checks
and could inherit a historical NOTARISLOKAL target.

## Explicit configuration contract

Normal `go run ./cmd`/compiled-backend startup now reads **process environment
only**. It never automatically loads `.env`, `.env.notarisdev`, acceptance
credentials, or a default recovery account. A deployment launcher must export
its reviewed configuration explicitly. Loader failures return sanitized errors
before `ConnectDB`, workers, routes, or listeners are reached.

| Setting | Required contract |
| --- | --- |
| `BACKEND_ENV` | Exactly `local`, `staging`, `production`, or `release`; no default |
| `BACKEND_DEPLOYMENT_ID` | Explicit 3–80 character non-secret identity using letters/digits/dot/underscore/hyphen |
| `USERS_SECURITY_ENABLED` | Explicit exact `true`; unset/empty/false/1/yes/other malformed values rejected |
| `HTTP_HOST`, `PORT` | Explicit IP and valid port; no implicit wildcard bind |
| `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_NAME` | Explicit reviewed database target and role; no historical-file fallback |
| `DB_SSLMODE` | Explicit supported PostgreSQL SSL mode; transport approval remains separate |
| `JWT_SECRET` | Required externally supplied nonempty secret; never logged or defaulted |
| `DB_PASSWORD` | Externally supplied if the reviewed PostgreSQL authentication requires it; never bundled/logged |

`JWT_EXPIRE_MINUTES` retains its existing positive/default-120 policy.
Petugas publisher settings retain their existing behavior and default OFF;
H05 does not enable a worker. `GIN_MODE` cannot select a security mode or bypass
the gate; normal router initialization uses Gin release mode.

All four modes require P0. There is **no insecure local legacy exception**.
`local` additionally requires literal loopback HTTP and PostgreSQL IPs
(`127.0.0.1`/`::1`, not an unverified hostname). Staging/production/release may
bind their explicitly reviewed IP. The protected database name `notarislokal`
is rejected case-insensitively in every mode. Existing acceptance target checks
remain exact and additionally require the explicit HTTP loopback host.

Older launchers/private configurations lacking these settings intentionally
stop; do not fix that by switching P0 OFF. H05 does not approve running them
against any existing database.

## Pre-listen readiness

`internal/backendstartup.Open` is the normal entrypoint's single pre-bind path:
validate config, verify actual `current_database()` equals the reviewed name,
run `Administration.Ready`, then and only then call `net.Listen`. The same path
is tested with listener spies and real OS-assigned disposable sockets. A failed
gate never invokes the listen function. HTTP serving and publication-worker
startup occur after successful readiness. Database pools close on failed
readiness; no startup migration or administrator bootstrap is performed.

P0 readiness runs in a **read-only, repeatable-read transaction**. It checks:

- Five actual tables and their primary keys, security-version/revision types,
  NOT NULL/default/positive-value contracts, and required audit metadata.
- The approved validated CHECK/FK definitions for users/groups, canonical
  Sidebar/grant relationships, and administrative audit actor/source/result.
- Valid, ready, live, immediate identity/grant unique indexes with the correct
  expressions/keys and no partial predicate; the audit actor/time index.
- The enabled audit immutability trigger, its event set, and rejecting function.
- The existing active recovery-capable superadmin with explicit Users/Groups/
  Sidebars grants and a parseable bcrypt hash. No name-based privilege bypass.

Names alone do not pass: NOT VALID foreign keys, CHECK(true), incorrect index
keys, disabled audit triggers and ineffective trigger functions fail closed.
Schema comparison follows the approved proposal's PostgreSQL catalog
representation, ignoring formatting whitespace outside quoted tokens only.
The actual-backup rehearsal subsequently verified both TEXT and built-in
VARCHAR column variants: the checker selects their exact expected casts from
the actual column type. It never removes arbitrary casts. An unrecognized type,
constraint variant or PostgreSQL representation still requires review; it is
not automatically normalized, repaired or declared compatible.

Recovery presence/hash format does not prove a human possesses the password,
successful login, network/TLS readiness, or deployment authorization. Those
remain separate checks. Initial GORM connection diagnostics are suppressed so
driver connection details cannot bypass the sanitized startup error.

## Executed focused validation

```powershell
python .\scripts\test-users-security-disposable.py --h05
cd backend-notaris-go
go vet ./config ./cmd ./database ./internal/backendstartup ./services ./middleware ./repositories ./routes
```

The existing runner creates/owns a new PostgreSQL cluster on port 55793, checks
its directory and database marker, applies the existing P0 proposal only to
fresh disposable schemas, and stops the cluster. No operational DSN is accepted.

Final focused run: **37 Go top-level tests / 197 leaf cases PASS**, including
**106 H05** and **37 H04** cases; **0 failures and 0 skips**. Tests cover the
actual main rejection path, explicit configuration, local bind containment,
complete/incomplete P0 schemas, no listener on failure, actual HTTP/JWT handling,
revoked/disabled/missing identities, and accepted Users/Groups/action policies.
Full table/sequence fingerprints demonstrate readiness/failed startup do not
mutate fixture business or audit state. `go vet` passes. Evidence:
`.local/h05/disposable-go.log`. Earlier diagnostic logs remain local; only
disposable catalog representation was inspected, never credentials or live data.

Flutter runtime/wire code is unchanged; no Flutter suite, Windows build, live
E2E, SQLite migration or release packaging was necessary or performed.

## Remaining deployment gates

NOTARISDEV has **not** been connected to, migrated, or verified by this sprint.
Its P0 migration, ownership/grants, actual catalog compatibility, real recovery
account and explicit environment/target configuration need separately approved
preflight/cutover. A verified read-only credential is still needed for live
inspection. No default administrator or credential is created by H05.

TLS/reverse proxy, PostgreSQL transport policy and complete secret management
remain H08/deployment blockers. H02/H03 manual acceptance remains pending.
H01 stays `DISABLED_BY_POLICY`; H02/H03/H04 and H07 profile binding are preserved.
No NOTARISLOKAL, original SQLite, prior acceptance profile, or existing restore
cluster was opened. No live migration/write, sync/publication activation,
deployment, push or merge is authorized by this checkpoint.

Actual backup follow-up: see `NOTARISDEV_P0_MIGRATION_REHEARSAL_20261121.md`.
The necessary VARCHAR compatibility correction passed 38 Go top-level tests /
201 leaf cases and read-only H05 checks on the newly restored/migrated clone.
The P0 proposal was unchanged; no existing database was connected to.
