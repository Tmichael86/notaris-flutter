# Groups V2.1 — full supported catalog acceptance

Operational activation OFF. Manual Windows acceptance NOT RUN by Codex.
Reuses the accepted V2 editor, API, locking, audit and recovery policy unchanged.
Standalone System → Sidebars remains the separate listing prototype.

## Coverage preflight and canonical contract

AppShell has 21 destinations and three static container sections
(`frontend_notaris/lib/core/widgets/app_shell.dart`). Laravel's
`database/seeders/SidebarSeeder.php` has 17 destinations and three containers.
The V2 six-editable fixture was deliberately minimal, not an editor limit.

The NEW V2.1 fixture has **21 definitions: 16 destinations + 3 containers +
2 frozen preservation cases**. Exactly **19 editable** definitions. It omits
Konfigurasi Umum from actionable acceptance because its screen remains a
simulated editor without an operational authorization/data contract.

| ID | Name | Canonical code | Parent | Actual supported boundary |
|---:|---|---|---:|---|
| 1 | Users | users | 34 | Online P0 Superadmin + explicit action; ordinary READ is insufficient |
| 2 | Groups | groups | 34 | Online P0 Superadmin + explicit action; ordinary READ is insufficient |
| 3 | Sidebars | sidebars | 34 | Existing Go GET catalog requires READ; no metadata CRUD |
| 4 | Petugas | petugas | 10 | Go CRUD action middleware; local identity/sync safeguards unchanged |
| 10 | Master | master | 0 | Container, route #, not a business API permission |
| 11 | Pemohon | pemohon | 10 | Go CRUD action middleware |
| 22 | Transaksi | transaksi | 0 | Shared domain permission; extra payment/actor/sync guards still apply |
| 23 | Monitoring | monitoring | 0 | Shell READ; data requires Transaksi READ; no independent CRUD |
| 24 | Pengeluaran | pengeluaran | 0 | Local repository READ/CREATE/UPDATE/DELETE |
| 25 | Piutang | piutang | 0 | Local repository READ/report only |
| 26 | Penghasilan | penghasilan | 0 | Local repository READ/report only |
| 27 | Pekerjaan Notaris | pekerjaan_notaris | 10 | Go CRUD middleware; local CRUD authorization gap below |
| 28 | Pekerjaan PPAT | pekerjaan_ppat | 10 | Go CRUD middleware; local CRUD authorization gap below |
| 29 | Kategori Pekerjaan | kategori_pekerjaan | 10 | Go CRUD middleware |
| 30 | Jenis Pengeluaran | jenis_pengeluaran | 10 | Go CRUD middleware |
| 31 | Laporan | laporan | 0 | Container, route # |
| 32 | Materai | laporan_materai | 31 | Local READ; CREATE also requires verified actor/profile, stock provenance |
| 33 | Pendapatan | laporan_pendapatan | 31 | Local READ AND Penghasilan READ AND Pengeluaran READ, valid session |
| 34 | System | system | 0 | Container, route # |
| 20 | Historis | historis | 0 | Inactive, frozen; stored CS flags 1100 preserved |
| 21 | Parent tidak tersedia | unsupported | 999 | Orphan, frozen; stored CS flags 1010 preserved |

Evidence: Go `routes/routes.go`, `middleware/permission_middleware.go`,
`repositories/sidebar_access_repository.go`; Flutter repositories
`pengeluaran_repository.dart`, `piutang_repository.dart`,
`penghasilan_repository.dart`, `materai_repository.dart`,
`materai_stock_repository.dart`, `pendapatan_repository.dart`,
`recycle_bin_repository.dart`, and `models/auth_session.dart`.

- Laravel `materai` / `pendapatan` are not the current local report identifiers.
  Use verified `laporan_materai` / `laporan_pendapatan`, with no aliases/duplicates.
- `konfigurasi` (Laravel/prototype) versus `konfigurasi_umum` (promotional fixture)
  has no implemented operational contract: neither is added to this fixture.
- Hyphens in API paths are not permission codes. The standalone Sidebar mock's
  hyphenated codes are not copied. Canonical Master permission codes use `_`.
- Dashboard remains the authenticated landing page. Log/Monitoring Sinkronisasi
  remain local diagnostics. Recycle Bin derives access from Transaksi/Master
  READ (restore additionally UPDATE and local/cloud protection), not a new grant.
- A checkbox stores an explicit flag, not new module functionality. Unsupported
  CREATE/UPDATE/DELETE actions in reports/containers/Sidebars are NOT acceptance
  claims. Parent bulk selection changes visible explicit flags, not inheritance.
- **Sidebars READ is currently not Superadmin-only in Go**. Groups/Users admin
  are Superadmin-only. Changing catalog-read classification requires separate
  policy approval; this sprint neither tightens nor bypasses it.

## Proven gaps / production prerequisites

`PekerjaanNotarisRepository` / `PekerjaanPpatRepository` accept a DAO without a
session dependency. Therefore local Master CRUD cannot be certified as enforcing
all action grants merely because shell visibility and Go middleware pass.
Master cloud middleware authorization is covered; local action-level hardening
requires its own focused scope before claiming end-to-end least privilege.
The analogous local Master screens must be reviewed before operational rollout.
No broad business repository rewrite is included here.

No operational catalog is inspected or seeded. A later rollout must separately
verify real canonical codes, unique grants, P0 migration readiness and least
privilege, exclude uncoordinated external catalog writers, resolve the above
gaps, then obtain deployment approval. No production activation is implied.

## Implementation boundary

`internal/devfixture/groups_catalog.go` supplies the opt-in fixture only. Existing
IDs 1/2/3/4/10/11/20/21 are retained; Users/Groups/Sidebars are now under System.
`groups-v2-init-full` binds `full-v2.1` into the signed/DPAPI-protected new profile
manifest and secrets. It cannot upgrade/reuse an existing profile. The helper
only populates the new owned cluster before its baseline; no operational seed.

The existing Python runner adds `prepare --catalog full`, exact full-fixture
postcheck selections and phase aliases. Catalog choice is rejected for every
command except prepare. Existing reduced-profile predicates remain supported.
Old profiles/files are untouched; source/helper pinning is not automatically
rewritten for old acceptance profiles.

No editor, operational service, middleware, shell, schema or sync changes.
The existing V2 HTTP regression's native SQLite checks use WidgetTester.runAsync
so SQLite completion is not stranded behind the widget fake clock. Assertions
and protected-data requirements are retained.

## New disposable expected state

- PostgreSQL 127.0.0.1:55797, HTTP 127.0.0.1:55885; owned fresh data_directory,
  exact `groups_v2_<profile>` database and per-profile marker/DPAPI binding.
- 18 Groups (17 active), 17 Users (16 active), 62 grants:
  protected groups 101/102 each 20, ordinary CS 201 has 21, group 202 has one.
- CS: seven active members; all 19 editable grants initially 0000. Frozen
  entries keep the exact original flags and identity. No default ordinary access.
- SQLite v27, two fictitious transactions and two payments. Query-only,
  migrations disabled, HTTP clients outside the Groups allowlist blocked.
  All table/financial/Materai/sync fingerprints, counts, FK and integrity guarded.
- Revision 1 → SAVE 2 → REVOKE 3 → one explicit CONFLICT edit 4. Final:
  Petugas READ-only, all other editable entries 0000; frozen unchanged;
  three successful grant audits + one stale_revision denial. Membership,
  classification, security versions and unrelated grants remain identical.

## Operator commands and stages

Run from repository root. Prepare is NEW profile only (already done for the
delivered profile; do not run it again to start acceptance):

```powershell
python .\scripts\groups-v2-acceptance.py prepare --catalog full
```

Set `$id` to the delivered NEW V2.1 profile ID, never the accepted V2 profile.
Terminal 1:

```powershell
$runner = '.\scripts\groups-v2-acceptance.py'
$id = '84e640c5ffcc312ea210dc92e4b26756'
python $runner backend --id $id
```

Terminal 2 (same `$runner` and `$id`):

```powershell
python $runner check --id $id --expect initial
python $runner check --id $id --expect catalog
python $runner credential --id $id --account admin.groups
python $runner launch --id $id
```

Credentials appear only in the native Windows dialog. Do not record/scan them.
Inside Flutter: System → Groups → CS → Atur Akses. No change to standalone
Sidebars is expected. The full catalog belongs to this editor.

| Stage | Operator action / expected state | Postcheck `--expect` |
|---|---|---|
| INITIAL | Close Flutter, baseline rev1 / 0 audits | initial |
| CATALOG | 21 definitions, 19 editable, 2 frozen; read-only snapshot | catalog |
| OPEN | Open CS editor, revision1, 7 active members | open |
| EXPAND | Inspect Master, Laporan, System hierarchy; close/reopen sections | expand |
| GRANT | Explicit selection below, not yet saved | grant |
| SAVE | Save once; close Flutter, revision2 / 1 success audit | save |
| REOPEN | Reopen; saved flags identical; close Flutter | reopen |
| PERMISSION-REFRESH | Login admin.biasa; refresh permissions; navigation and read access reflect grants; not Superadmin | permission-refresh |
| REVOKE | admin.groups: clear READ on every editable row, Save once; close | revoke |
| BACKEND-DENIED | admin.biasa refresh: Petugas probe denied, business navigation removed; diagnostics remain | backend-denied |
| CONFLICT | Open CS revision3, change flags without saving; run conflict-edit in Terminal2, then Save stale UI once; 409 retains unsaved selection | conflict |
| PROTECTED | Protected Superadmin targets read-only, no attempted escalation/membership mutation | protected |
| RESTART | Restart with same profile, revision4 / frozen grants intact | restart |
| FINAL | Three successes, one stale_revision denial; all protected fingerprints unchanged | final |

Exact GRANT selection: READ on every editable entry. Add CREATE/UPDATE/DELETE
only on IDs **4,11,22,24,27,28,29,30**. ID32 Materai: READ+CREATE only. IDs
1,2,3,10,23,25,26,31,33,34: READ-only. No frozen checkbox can be changed.
These are acceptance flags, not an expansion of available functionality.
Do not perform financial/Materai/Master CRUD against the protected SQLite.

Generic phase postcheck (close Flutter except read-only OPEN/EXPAND/GRANT):

```powershell
python $runner postcheck --id $id --expect save # substitute the phase above
```

The one explicit conflict writer uses the existing scoped helper:

```powershell
python $runner conflict-edit --id $id
# Then click Save once in stale Flutter, observe 409, close Flutter.
python $runner postcheck --id $id --expect conflict
```

Do not replay mutations after an ambiguous result. Keep locks/evidence. No
cleanup is part of acceptance. After closing Flutter/backend Ctrl+C:

```powershell
python $runner stop --id $id
```

## Validation evidence

Focused tests cover full canonical identities/tree, save/reopen/collapse at
1366×768 and 1920×1080, current-permission middleware and refreshed local
repository gates, dependency denial, administrative classification, frozen rows,
catalog/revision conflicts, audit/locking/recovery regression, and query-only
SQLite integrity. Actual execution results and new profile ID are reported with
the delivery. Manual visual/interaction acceptance remains for the operator.

Delivered profile: `84e640c5ffcc312ea210dc92e4b26756`, under
`C:\Users\Msi GF63\AppData\Local\Temp\notaris-payment-84e640c5ffcc312ea210dc92e4b26756`.
Official INITIAL and independent owned-role/HTTP read-only check both PASS.
Latest evidence: `postcheck-initial-1795158079874380800.json` in that directory.
Cluster stopped; no Flutter acceptance launched. All 44 SQLite table snapshots
remain identical; schema27 / integrity ok / FK0, two transactions/two payments.
CS revision1, zero administrative audits, 62 grants as listed above.

Catalog SHA256:
`061869ffd7a7a9b1a96a7eab6e7bfe2f1d1e0b01b73c3a01e19641ed8769aab5`.
Canonical JSON SHA256 of the complete protected SQLite snapshot:
`f44b861d1479c599d4a664c64a6e3462a9b12e48926ffcece09c38088fe808a3`.

Executed validation (latest applicable result for each case):

- 59 Go route/security leaf scenarios PASS: accepted Users/Groups V1/V2
  regression plus three V2.1 cases. V2.1 final runner PASS on a fresh owned
  PostgreSQL cluster; original focused run exposed fixture/test-clock issues,
  corrected without changing operational behavior.
- Three additional Go catalog/Windows manifest/owned-role scenarios PASS.
- 71 focused Flutter widget/API/guard/local repository cases PASS;
  four authenticated real HTTP Flutter cases PASS (Users V1, Groups V1,
  Groups V2 and full V2.1); one new-profile SQLite provisioning test PASS.
- Three Python acceptance-predicate cases PASS, including full selection,
  unsupported-action rejection, phase ordering and reduced-fixture regression.
- Windows debug build of `groups_v2_acceptance_main.dart` PASS.

Ignored local execution logs: `.local/groups-v21-focused.log`,
`groups-v21-local-permissions-final.log`, `groups-v21-go-http-final.log`
(existing regression cases), `groups-v21-final-http.log` (final V2.1),
`groups-v21-initial-owned-check.log`, `groups-v21-prepare.log`,
`groups-v21-windows-build.log`, `groups-v21-analyze-clean.log`.
These artifacts and the new disposable data are not committed.
