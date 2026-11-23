# H03 — local Transaction mutation authorization

Baseline: `791c423`, branch `feature/pemohon-cloud-sync`.
Scope: local Transaction CUD and related payment, process, PPAT completion and
Recycle Bin mutation boundaries. No server/API action-parity or activation work.

## Contract

- The canonical Sidebar code is **`transaksi`** for both Notaris and PPAT.
  Exactly one active grant must include `read` and the actual action:
  `create`, `update`, or `delete`. Names, domain labels, parent menus and a
  Superadmin label never confer CUD. READ cannot authorize the write wrapper.
- `save(id:null)` requires CREATE; `save(id:existing)` requires UPDATE.
  Missing IDs never fall back to CREATE/upsert. Existing Notaris completion's
  additional UPDATE requirement is preserved. PPAT CREATE requires CREATE even
  when Materai binding is absent/disabled or quantity is zero.
- Soft delete requires DELETE. Local restore, PPAT job completion, payments and
  process validation/transitions require UPDATE. Existing payment-correction
  Superadmin checks and business validations remain additional requirements.
- Missing runtime authority fails closed. The repository, not only the button
  or controller, enforces the policy. Read-only repository use stays available
  through the existing read contracts; there is no anonymous mutation default.

`LocalTransactionAuthorization` reuses the identity/profile validation extracted
as `LocalMasterAuthorization.requireContext`. H02's Master grant resolver and
its existing checks are unchanged: live session/database identity, claimed
actor, token identity/expiry, current statuses, verified demo expiry/profile and
existing AuthService offline policy. No new offline policy, session fabrication,
JWT injection or Superadmin bypass is introduced.

Every operation revalidates before entering the SQLite transaction, inside it,
and after the complete operation before Drift commits. Changed session/account,
active database or revoked grants roll back the aggregate, child/process rows,
payment history/audit, dirty state and Materai movements together. Materai's
existing busy/read-only failure contract is preserved for the new outer
transaction; no retry or stock-calculation change is added.

Recycle Bin cannot log a denied restore as a SQLite write. Authorized reference
failures can still be logged. Successful transaction restore/delete audit uses
the actual validated actor. Existing cloud-evidence, historical-reference and
pending-mutation restore protections remain in force; cloud RESTORE is not added.

## UI and binding

The existing providers supply live AuthController and AppDatabase context.
Forms/dialogs retain the session/profile they were opened with. Confirmation,
async save and controller dispatch cannot adopt another account/profile silently.
Search/reopen explicitly obtains fresh authority; stale forms retain their data
and explain that they must be reopened. Permission refresh updates availability.
PPAT and process editors, payment dialogs and Recycle Bin keep the original
repository/context across awaits. No persistent shell or visual redesign.

Already verified Go/DPAPI demo launchers pass their independently verified
profile ID to the existing shared bootstrap. It is not inferred from a session,
and missing binding remains denied. No demo is reprovisioned or opened here.
Unbound legacy headless/demo seeders are not a bypass: they must supply a verified
authority before their mutation entrypoints can be used again. This sprint does
not authorize rerunning old pilot/bootstrap or live E2E scripts.

## Validation

Final focused suite: **384 PASS, 0 failed, 0 skipped**, across31 directly related
test files; includes **61 direct H03 authorization tests +4 H03 widget tests**.
Coverage includes explicit action combinations, absent/malformed context,
canonical-code/duplicate-grant checks, stale sessions/profiles, mid-SQL revocation,
PPAT without Materai binding, authorized CRUD/restore, stable child/payment
history, actor audit, restart, actual stock-out rollback, concurrent stock safety,
and preserved cursor/ACK/dirty state. All mutation fixtures are newly allocated
temporary/in-memory SQLite, including fresh v27 H07 profiles.

Existing tests now provide explicit test-only authority rather than relying on
anonymous constructors. Test fixtures are not compiled into normal release.
Old opt-in acceptance profiles and live PostgreSQL E2E were not executed.
H01 containment, H02 repository/widget enforcement and H07 profile/auth isolation
regressions are included. Debug Drift warnings about multiple test database
objects use separate test-owned executors; no production profile is involved.

`flutter analyze --no-pub`: **No issues found**.
Windows normal-main compilation uses only the explicit disconnected H07 settings:

```powershell
flutter build windows --release --no-pub -t lib/main.dart --build-name=1.0.0 --build-number=3 --dart-define=NOTARIS_RELEASE_ENV=qa-disconnected --dart-define=NOTARIS_RELEASE_DEPLOYMENT=qa-h07-internal-v1 --dart-define=NOTARIS_RELEASE_SCHEMA=27 --dart-define=API_BASE_URL=https://qa-endpoint-unconfigured.invalid/api/v1
```

Windows x64 Release compilation: **PASS** (build1.0.0+3, 88.3 seconds).
Actual build result is recorded in `.local/h03/windows-release-build.log`.
This is compilation validation, not a new packaged RC or runtime acceptance.
The executable is not launched; the frozen H07 bundle remains separate.

Local evidence: `.local/h03/focused-test-files.txt`, `validation-pass.log`,
`security-and-ui-final.log`, `analyze-final.log`, `windows-release-build.log`.
Earlier failed logs are retained to distinguish fixture/selector corrections
from the final passing run. No full-project regression was run.

## Remaining gates and safety

H03 real Windows release CRUD/auth acceptance remains a separate checkpoint;
unit/widget tests do not substitute for it. H02 manual Windows acceptance remains
PENDING. H04 backend action parity remains OPEN. No backend login/integration or
operational readiness is claimed from compilation.

No original development SQLite, prior acceptance database, NOTARISDEV or
NOTARISLOKAL was opened or changed. No PostgreSQL connection/cluster, migration,
fixture reset, live Upload/Download, publication or automatic sync was performed.
H01 stays `DISABLED_BY_POLICY`; H07 schema27, profile/auth namespace and
disconnected endpoint policy stay unchanged. Operational activation remains OFF.
