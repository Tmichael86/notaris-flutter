# Global Hardening H02 — Local Master CRUD authorization

Status: implementation and automated checks described below; operator Windows acceptance **PENDING**. Operational activation **OFF**. H01 remains the production containment policy. No schema migration.

## Authority and source map

| Canonical Sidebar | Repository (lib/repositories) | User write entrypoints | Controller/provider |
|---|---|---|---|
| `pekerjaan_notaris` | `pekerjaan_repository.dart / PekerjaanNotarisRepository` | `create`, `createAggregate`, `updateNama`, `updateAggregate`, `delete` → `deleteAggregate` | `pekerjaanNotarisControllerProvider` |
| `pekerjaan_ppat` | `pekerjaan_repository.dart / PekerjaanPpatRepository` | same domain-specific parent/aggregate methods | `pekerjaanPpatControllerProvider` |
| `kategori_pekerjaan` | `pekerjaan_kategori_repository.dart` | `create`, `update`, `delete`; legacy untrusted-list `syncFromCloud`, legacy local ACK path `syncToCloud` | `pekerjaanKategoriControllerProvider` |
| `jenis_pengeluaran` | `pengeluaran_jenis_repository.dart` | `create`, `update`, `delete`; legacy untrusted-list cache/ACK paths | `pengeluaranJenisControllerProvider` |
| `petugas` | `people_repository.dart / PetugasRepository` | `create`, `update`, `delete` | `petugasControllerProvider` |
| `pemohon` | `people_repository.dart / PemohonRepository` | `create`, `update`, `delete`; legacy untrusted-list cache/ACK paths | `pemohonControllerProvider` |

Canonical codes match the existing sidebar registry (no aliases or registry changes). Controllers obtain the scoped repositories from `pekerjaan_provider.dart` / `people_provider.dart`. All listed interactive CUD paths require `LocalMasterAuthorization`; constructing a repository without it permits reads but **denies writes**.

`RecycleBinRepository.restore` of Notaris/PPAT is UPDATE and uses the same authority. Transaction restore is unchanged (H03). Master soft deletion retains the existing parent/child provenance event, timestamps, identities and validation. Category/type/person deletion retains existing soft-delete behavior. Master form validation, child ownership/ordering, category validity, linked-record guards, and UUID collision behavior are preserved.

Raw DAO/Drift access is the trusted persistence layer, not an interactive authority or public privileged repository escape. Migration and scoped fixture preparation still use this layer. `petugas_manual_main.dart` now explicitly inserts its already-scoped fixture through Drift rather than pretending fixture setup is an authenticated user mutation. Modern verified aggregate importers and selective publishers retain their existing scope/receipt/reference/dirty guards; H02 does not change their protocol.

## Enforcement and races

`lib/services/local_master_authorization.dart` and its provider resolve the **current** AuthSession and **current AppDatabase instance**, with explicit module/action and optional claimed actor. Missing context, disposed provider, wrong database/profile, switched session, malformed/expired token, known identity mismatch/inactive status, duplicate/missing canonical grants, inactive/parent-only menu, or false READ/action grant fail closed. A display name, administrative Group name or `superadmin` classification cannot substitute for a grant.

Normal AuthSession authenticity remains established by AuthService/backend. Local code checks known JWT issuer/identity/expiry, **does not claim client cryptographic JWT verification**. Signed disposable sessions must additionally match the verified bootstrap profile and expiry. No new offline policy: the existing AuthService grace bound is reused; locally known expiry is denied. Offline revocation not yet received from server remains an H09 limitation.

An authorized write checks before admission, again inside the SQLite transaction, and after the operation before commit. Any account/profile/permission change causes rollback, including already-written aggregate children/history/dirty state. Claimed created/updated actor cannot differ from the session; Petugas linked `userId` remains a distinct relationship.

New identity requires CREATE; existing record modification UPDATE; deactivation DELETE. Legacy raw cache lists classify each actual row within a transaction, protect dirty rows, recheck all used actions before commit, and cannot use CREATE to overwrite. A denied batch rolls back earlier members. Their legacy outbound ACK writes revalidate the same action and active session inside a local transaction after the API response. API payload/POST/PUT/publication behavior is unchanged; H04 is not implemented.

Six existing screens watch session changes and derive C/U/D control availability from this same authority. Open forms retain the opening account and database identity and revalidate on submit. If grants/session change while a dialog is open, a stale Save attempt is denied without a write; it does not become a false success. The persistent shell, read lists and dialog layouts are retained.

## New owned Windows environment

- Profile: `132e95a5a87be8307d0c719197b08d6a`
- Root: `C:\Users\Msi GF63\AppData\Local\Temp\notaris-payment-132e95a5a87be8307d0c719197b08d6a`
- SQLite: `offline.sqlite`, v27; migrations disabled when launching H02.
- PostgreSQL: owned `pgdata`, loopback **55802**, `profile_v1_<profile>`.
- HTTP: loopback **55890**, not operational 8081.
- Signed manifest / DPAPI material and `h02-owner` bind this new root, account/scope, helper and targets. No credential printed in this document.
- `h02-baseline.json` protects all original table rows, financial/Materai/transaction children, dirty/pending/ACK/cursors and all PostgreSQL state. Only one new category lifecycle is allowed.
- `h02-postcheck-initial-1795228193758826400.json`: **H02_INITIAL_PASS**, integrity `ok`, FK zero. Cluster stopped after prepare.
- Initial fixture provisioning was interrupted before SQLite creation by Flutter native-assets DLL locking. `h02-finish-attempted.lock` preserves the guarded one-time continuation evidence; no cluster bootstrap or fixture reset was repeated. Old profiles were not used.

Normal `lib/main.dart` runs with H02-specific verified binding, `UiSmoke=false`, and no manual-sync configuration/coordinator override. A secondary HTTP adapter logs request attempts without headers/body/secrets and allows only authentication and read-only account/attestation/Profile endpoints. PostgreSQL runtime role is SELECT-only/default read-only. This does not replace H01: focused H01 tests still exercise the actual no-transport global policy.

| Account | UID/Group | Master authority |
|---|---|---|
| `user.profile` | 201/201 | READ six modules; no CUD |
| `admin.profile` | 101/101 | explicit READ+CUD six modules |
| `admin.biasa` | 202/202 | READ+CREATE; no UPDATE/DELETE |
| `recovery.profile` | 102/102 | no Master grants, despite verified recovery Superadmin classification |

All six modules have direct controller/repository matrix tests. To keep Windows work short, the only authorized manual data change is category `Kategori H02` → `Kategori H02 diperiksa` → soft delete. created_by must remain 101; updated_by is NULL at CREATE and 101 after UPDATE. Same PK/UUID/created_at, dirty true, ACK unchanged. Do not edit fixture Masters/transactions or press unrelated sync controls.

## Operator commands (not executed interactively)

Run from the repository root in PowerShell. Set explicit variables in each terminal:

```powershell
Set-Location 'D:\Perkuliahan\MAGANG\Works\Web\project-flutter-notaris'
$h02Id = '132e95a5a87be8307d0c719197b08d6a'
$h02Runner = '.\scripts\h02-acceptance.py'
```

Terminal 1 (keep running):

```powershell
python $h02Runner backend --id $h02Id
```

Terminal 2, obtain credentials through the existing protected Windows dialog (never paste credentials into chat):

```powershell
python $h02Runner credential --id $h02Id --account user.profile
python $h02Runner launch --id $h02Id
```

Close Flutter normally before every postcheck; leave backend running. If a lock remains after an abnormal exit, **STOP** for investigation; do not delete locks, reset data or reprovision. All postchecks preserve evidence in the owned root. Their marker is `H02_<PHASE>_PASS` (hyphens converted to underscores); data checks do not certify a human click by themselves.

### Short manual sequence

1. **READ-ONLY / CREATE-DENIED / UPDATE-DENIED / DELETE-DENIED.** Login `user.profile`. Open each allowed Master; rows remain visible, Add/Edit/Delete disabled. No mutation attempt through UI is needed for disabled buttons; direct calls are automated. Close Flutter. Run each exact phase:

```powershell
python $h02Runner postcheck --id $h02Id --expect read-only
python $h02Runner postcheck --id $h02Id --expect create-denied
python $h02Runner postcheck --id $h02Id --expect update-denied
python $h02Runner postcheck --id $h02Id --expect delete-denied
```

2. **NO-GRANT.** Obtain `recovery.profile` credential, relaunch, switch accounts through logout/login. Master navigation must be denied; verified Superadmin classification alone does not grant local CRUD. Close; `postcheck --expect no-grant`.
3. **EDITOR-CREATE.** Obtain `admin.profile` credential, relaunch and login. Master → Kategori Pekerjaan → Add exact name **Kategori H02** once. Close; checkpoint records its actual PK/UUID:

```powershell
python $h02Runner postcheck --id $h02Id --expect editor-create
```

4. **EDITOR-UPDATE.** Relaunch as admin, rename only the new category to **Kategori H02 diperiksa**, Save once. Close:

```powershell
python $h02Runner postcheck --id $h02Id --expect editor-update
```

5. **PERMISSION-REFRESH / SESSION-SWITCH.** Relaunch. Refresh current session using existing Profile/session refresh; explicit admin grants remain effective. Logout/login as `admin.biasa`: Add enabled, Edit/Delete disabled. Switch to `user.profile`: CUD disabled. Do not add/edit/delete here. Open-dialog revocation, account-switch and queued profile-switch rejection are covered by automation; do not mutate PostgreSQL grants to simulate revocation. Close:

```powershell
python $h02Runner postcheck --id $h02Id --expect permission-refresh
python $h02Runner postcheck --id $h02Id --expect session-switch
```

6. **EDITOR-DELETE.** Relaunch as `admin.profile`; delete only **Kategori H02 diperiksa**, confirm once. Close:

```powershell
python $h02Runner postcheck --id $h02Id --expect editor-delete
```

7. **OFFLINE / RESTART / FINAL.** Valid offline Master CUD admission is covered on disposable SQLite by automated tests, without changing H09 policy. For Windows, login admin while backend is available, then stop only the HTTP server with Ctrl+C after startup (owned PostgreSQL remains running); navigate/read local Masters, do not modify protected fixtures. Close and run offline postcheck (helper reads owned PostgreSQL directly). Restart backend with Terminal 1 command, relaunch Flutter and confirm cached-session restoration and unchanged soft-deleted category. Close:

```powershell
python $h02Runner postcheck --id $h02Id --expect offline
python $h02Runner postcheck --id $h02Id --expect restart
python $h02Runner postcheck --id $h02Id --expect final
```

After final review, Ctrl+C backend, then `python $h02Runner stop --id $h02Id`. Data, baseline and receipts remain. No automatic cleanup/restore.

## Validation evidence

Actual execution: **347-test focused regression PASS, 18 opt-in tests SKIPPED**, followed by the final **107-test authorization suite PASS** (including 3 additional ACK-revocation tests). There are **350 unique passing tests** across these runs, zero failures. The opt-in tests are prior profile provisioning / live PostgreSQL E2E and were not enabled. The new H02 preparation explicitly ran two fixture tests successfully in the new profile only. No operator acceptance is claimed.

The 347-test focused run contained 104 new repository/controller/security tests, 61 existing six-module CRUD tests, 9 new permission/lifecycle widget tests, 43 H01/transport/coordinator/session/manual-sync tests, and 130 related Master/cloud-local/Recycle Bin/layout/ESC tests. Those counts are components of the 347-pass run, not additional tests. After adding the three API-double ACK-revocation tests, the authorization file was rerun in full: 107 PASS, and analyze was rerun clean. All-table before/after snapshots, SQLite FK/integrity, restart, action classification, claimed identity, profile/account switch and mid-aggregate rollback are asserted. In-memory databases and independent temporary reopen handles produce Drift's multi-instance debug warning; no executor or database file is shared by concurrent writes.

From `frontend_notaris`, the exact focused set (rerunning current source includes the three new cases):

```powershell
$h02Tests = @(
  'test/database/groups_acceptance_profile_test.dart'
  'test/database/groups_v2_acceptance_profile_test.dart'
  'test/database/h02_acceptance_profile_test.dart'
  'test/database/materai_usage_demo_profile_test.dart'
  'test/database/office_v1_acceptance_profile_test.dart'
  'test/database/presentation_demo_profile_test.dart'
  'test/database/profile_v1_acceptance_profile_test.dart'
  'test/database/promotional_demo_profile_test.dart'
  'test/database/sidebars_v1_acceptance_profile_test.dart'
  'test/database/users_acceptance_profile_test.dart'
  'test/e2e/pekerjaan_notaris_cloud_live_e2e_test.dart'
  'test/e2e/pekerjaan_ppat_cloud_live_e2e_test.dart'
  'test/e2e/petugas_live_e2e_test.dart'
  'test/providers/sync_coordinator_test.dart'
  'test/repositories/local_master_authorization_test.dart'
  'test/repositories/pekerjaan_kategori_repository_test.dart'
  'test/repositories/pekerjaan_notaris_cloud_repository_test.dart'
  'test/repositories/pekerjaan_ppat_cloud_repository_test.dart'
  'test/repositories/pekerjaan_ppat_repository_test.dart'
  'test/repositories/pekerjaan_repository_test.dart'
  'test/repositories/pemohon_dev_reference_test.dart'
  'test/repositories/pemohon_repository_test.dart'
  'test/repositories/pengeluaran_jenis_repository_test.dart'
  'test/repositories/petugas_conflict_resolution_test.dart'
  'test/repositories/petugas_identity_map_repository_test.dart'
  'test/repositories/petugas_local_sync_test.dart'
  'test/repositories/petugas_reference_reconciliation_test.dart'
  'test/repositories/petugas_repository_test.dart'
  'test/repositories/recycle_bin_repository_test.dart'
  'test/services/h01_transport_test.dart'
  'test/services/session_sync_controller_test.dart'
  'test/services/transaction_manual_sync_service_test.dart'
  'test/widgets/h01_startup_containment_test.dart'
  'test/widgets/local_master_permissions_test.dart'
  'test/widgets/master_data_layout_test.dart'
  'test/widgets/master_form_escape_test.dart'
  'test/widgets/petugas_manual_sync_test.dart'
  'test/widgets/recycle_bin_screen_test.dart'
)
flutter test --no-pub @h02Tests --reporter expanded
flutter test --no-pub test/repositories/local_master_authorization_test.dart --reporter expanded
flutter analyze --no-pub
```

Analyze: **No issues found**. Windows debug build: **PASS** (`build/windows/x64/runner/Debug/frontend_notaris.exe`), no interactive launch performed. Exact build invocation from `frontend_notaris`:

```powershell
$h02HelperHash = (Get-FileHash -LiteralPath 'C:\Users\Msi GF63\AppData\Local\Temp\notaris-payment-132e95a5a87be8307d0c719197b08d6a\session.exe' -Algorithm SHA256).Hash.ToLowerInvariant()
flutter build windows --debug --no-pub -t lib/main.dart --dart-define=NOTARIS_H02_ID=132e95a5a87be8307d0c719197b08d6a --dart-define=NOTARIS_H02_LAUNCH=build-only "--dart-define=NOTARIS_H02_HELPER_SHA256=$h02HelperHash"
```

Final read-only INITIAL recheck after build (44 tables, schema 27, integrity `ok`, FK zero, protected counts and fingerprints unchanged): **H02_INITIAL_PASS**, evidence `h02-postcheck-initial-1795229136150220000.json`; cluster stopped again. No Flutter app or manual acceptance was launched.

From `backend-notaris-go`:

```powershell
go test ./cmd/paymentdemo -run 'Test(H02|H01|ProfileV1ManifestIsolation)' -count=1 -v
```

**3 PASS**: only H02/H01 ownership/target rejection and manifest mode isolation; no operational database connections.

From repository root:

```powershell
python scripts/test_h02_acceptance.py
```

**2 PASS**: exact new category actor/PK/UUID/title/dirty/tombstone predicate; denied HTTP/global-success evidence. CREATE expects `updated_by=NULL`, UPDATE/DELETE expect the verified editor 101, matching the existing repository audit convention.

New environment fixture commands (already completed; **do not rerun**):

```powershell
# frontend_notaris; environment was scoped to the new H02 ID by the runner.
$env:NOTARIS_PROFILE_V1_PREPARE = '132e95a5a87be8307d0c719197b08d6a'
flutter test --no-pub test/database/profile_v1_acceptance_profile_test.dart --reporter expanded
Remove-Item Env:NOTARIS_PROFILE_V1_PREPARE
$env:NOTARIS_H02_PREPARE = '132e95a5a87be8307d0c719197b08d6a'
flutter test --no-pub test/database/h02_acceptance_profile_test.dart --reporter expanded
Remove-Item Env:NOTARIS_H02_PREPARE
```

**2 PASS**, then runner `H02_INITIAL_PASS`; cluster stopped. `.local/h02-focused-final.log`, `h02-focused-files.txt`, `h02-security-final.log`, `h02-go-final.log`, `h02-analyze-final.log`, `h02-windows-build.log`, `h02-finish-prepare.log` retain local execution evidence and are not committed.

Test compatibility updates supply canonical test authority in existing fixture source without accessing or modifying any accepted profile. One preexisting restart test falsely relabeled a current database as v18 and collided with existing indexes; it now tests actual current-schema reopening/restore persistence and does **not** claim v18 migration coverage. No migration implementation changed.

## Scope closure and limitations

H02 protects the named application repository/controller CUD surfaces, not arbitrary hostile code already holding a raw SQLite/DAO handle. No generic privileged bypass flag is introduced. Fixture tests now supply explicit test authority or use scoped trusted setup; this is source compatibility, not modification of prior accepted data. Existing Master read repositories remain available to reference consumers; shell READ navigation remains authoritative at that layer.

H03 transaction authorization, H04 server action parity, H09 server-revocation freshness while offline, and operational activation remain separate. No Users/Groups policy, canonical registry, Go API mutation semantics, financial calculation, Materai ledger, transaction/payment repository, schema, background publisher or global SyncCoordinator activation is changed. No original development/daily SQLite or operational PostgreSQL is accessed. No push/merge. Manual Windows acceptance remains **PENDING**.
