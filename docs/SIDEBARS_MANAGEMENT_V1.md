# System → Sidebars V1 — authentic read-only catalog

Operational activation **OFF**. Operator Windows acceptance **PENDING**.
The existing AppShell, Users/Groups policies and Atur Akses editor are unchanged.
This replaces the 20-row Flutter prototype with actual authenticated PostgreSQL
reads. No metadata CRUD, icon picker, access toggles, SQLite catalog cache or sync.

## API and source contract

New `GET /api/v1/sidebars/catalog`, registered before `/:id`. Existing
`/sidebars`, `/sidebars/tree`, `/sidebars/:id` retain their response/active-only
and two-level tree semantics. Groups snapshots and grant writes are unchanged.

Query: `page` default1, maximum1,000,000; `page_size` default10, maximum50;
`status=all|active|inactive` defaultall; optional `search` up to200 Unicode
characters. Unknown/duplicate/invalid parameters return400. Search is literal
case-insensitive `strpos` over name/code/route/icon/parent name/IDs. `%` and `_`
are not wildcard operators. No caller-controlled SQL order or column names.

Envelope `data:{items,total,page,page_size,total_pages}`. Count and page use one
PostgreSQL statement/MVCC snapshot, ordered `sidebar_index ASC NULLS LAST,id ASC`.
Empty results have one display page. Out-of-range positive pages return empty
items with the requested page and actual totals; UI offers Halaman pertama.

Flat LEFT JOIN by parent ID preserves orphan, inactive-parent and deep rows.
Metadata fields are ID, raw name/code/route/icon/order/status, parent ID/name/
status/existence, created_at. No actor, password, grant or security-version fields.
Nullable historical metadata remains nullable; malformed/unknown status is never
coerced to active. Duplicate names/codes are not deduplicated or certified as
safe permissions. Canonical values are displayed exactly, not renamed/aliased.

Authentication and canonical active `sidebars` READ use the existing middleware:
current active user/group, JWT/security-version policy, default deny and ambiguous
permission denial. An ordinary group with READ is allowed: **no new Superadmin
restriction**. Flutter's gate checks online session claims and exactly one READ
entry; backend remains authoritative for signature/current permissions. Denial,
expiry/revocation, malformed payload, missing endpoint, server error and offline
backend show explicit sanitized states, never prototype or SQLite fallback data.

No production catalog completeness is asserted. In particular `materai` versus
`laporan_materai`, `pendapatan` versus `laporan_pendapatan`, and `konfigurasi`
versus `konfigurasi_umum` remain stored-source distinctions. Displaying them does
not establish action enforcement in the destination module.

## Flutter

`SidebarApiService.catalog`, strict catalog models, Riverpod autoDispose page
provider and the existing Sidebars screen implement search/status/server paging,
refresh, totals, loading/empty/error/denied states. Search submits with Enter or
the Cari icon, resets to page1; status changes also reset to page1. Page size10.
Permission refresh invalidates reads and removes unauthorized table content.

Uses existing MasterDataViewport/MasterDataTableViewport: white/red styling,
neutral header, one scrollbar per axis, shared persistent shell. Unknown icon
references use a neutral glyph alongside the unchanged reference text; never
dynamic asset paths/font codepoints. Nullable names/dates are labeled honestly;
long metadata has bounded cells and full-value tooltips. Created-at uses existing
`syncLocalTime` local-time formatter for timestamps with a timezone. PostgreSQL
timestamps without timezone remain as stored, explicitly labeled `tanpa zona
waktu`; no UTC assumption is invented. Both PostgreSQL timestamp types have
focused regression coverage. No route text is executed as navigation.

## New isolated acceptance profile

Profile: `4e2a7b1e93d8516a2bd6352ff42b2cd3`.
Directory:
`C:\Users\Msi GF63\AppData\Local\Temp\notaris-payment-4e2a7b1e93d8516a2bd6352ff42b2cd3`.

- PostgreSQL `127.0.0.1:55798`, database `sidebars_v1_<id>`, owned pgdata.
- HTTP `127.0.0.1:55886/api/v1`, scope `sidebars-v1/<id>`; authenticated
  attestation queries the actual active DB connection and verifies profile,
  database/host/port/marker/account/group, cloud_sync=false.
- New owner marker, Windows owner ACL, DPAPI/signature, manifest/helper hash.
  No existing profile reuse or configurable operational DSN fallback.
- Runtime `sidebars_v1_app`: SELECT-only on users/groups/sidebar/sidebar_akses,
  no mutation/sequence grants, default_transaction_read_only=on. HTTP exposes
  authentication, attestation and Sidebars GETs only. No Groups write endpoints.
- SQLite v27, migrations disabled, query_only=ON. All other API clients stay
  UiSmoke guarded, no coordinator/publisher. All44 table fingerprints protected,
  two fictional transactions/two payments; integrity ok, FK0.
- Four Groups/four Users, 47 grants: protected Superadmin groups101/102 have
  23 each; ordinary reader201 has only Sidebars READ; denied202 has no grants.
  Revisions/security versions1, administrative audits0. Recovery invariant valid.
- `reader.catalog` is the normal acceptance login; `denied.catalog` verifies
  denial. `admin.catalog`/`recovery.catalog` remain verified recovery identities.
  Passwords only in native credential dialog, never report/log/chat.
- Catalog25 definitions: **23 active, 2 inactive**; three non-navigable `#`
  containers plus an inactive `#` container, orphan21→999, inactive35→active36,
  deep38→36, literal-name37, unknown icon37 and missing icon38.

INITIAL and the independent owned-role/authenticated HTTP observational check
PASS; cluster stopped, Flutter not launched. Latest evidence:
`postcheck-initial-1795162198209044100.json` in the profile directory.
Catalog fingerprint: `6e21c51e47b30fd0d52dbe47f87d12d161effc2b63977b8be28ba10a357add0e`.
Protected44-table snapshot SHA256:
`71900fb431ded07855cc6faf9e1479edb56eb36b6f806fa20409e11edac10324`.
PostgreSQL fingerprints recorded in that evidence and
`.local/sidebars-v1-owned-final.log`; complete state and SQLite equality required
at every postcheck, including users, memberships, grants, audits, financial/
Materai/sync metadata. No ordinary read generates an administrative audit.

Pre-compatibility candidate `e35a666b7f5ea2ad1dfcdd3fdc6923b7` is retained
untouched, with its old helper/baseline/evidence; do not launch it. The delivered
final profile above was newly provisioned after timestamp compatibility was
completed. No helper/baseline was automatically repinned or overwritten.

## Operator commands

Run from repository root. The delivered profile is already prepared. Do not
reprovision it. Future NEW profile only: `python .\scripts\sidebars-v1-acceptance.py prepare`.

Terminal1:

```powershell
$id = '4e2a7b1e93d8516a2bd6352ff42b2cd3'
python .\scripts\sidebars-v1-acceptance.py backend --id $id
```

Terminal2:

```powershell
$id = '4e2a7b1e93d8516a2bd6352ff42b2cd3'
$runner = '.\scripts\sidebars-v1-acceptance.py'
python $runner check --id $id --expect initial
python $runner credential --id $id --account reader.catalog
python $runner launch --id $id
```

Login with the account's own credential; open System → Sidebars. Do not record
the password dialog or use credentials from another profile. Only inspect this
catalog; no business-data operations in other menus. Close Flutter before every
postcheck. Relaunch with the same ID for the next phase. Postchecks prove source
preservation, not that an operator performed visual actions.

| Phase / `--expect` | Flutter action and expected real response | Visible expectation |
|---|---|---|
| initial | Before launch; native self-check/read-only HTTP200 and denied403 | 25 definitions,23active/2inactive; baseline unchanged |
| list | Default Semua; GET catalog page1 size10 statusall →200,total25,pages3 | IDs1,2,3,4,35,10,11,20,21,22; all raw metadata |
| search | Enter `%_`, press Enter →200,total1,pages1 | ID37 `Referensi %_ Literal`, unknown icon reference unchanged |
| status-filter | Clear search; Aktif →200,total23,pages3 | First IDs1,2,3,4,10,11,21,22,23,24; no inactive rows |
| pagination | Semua, no search; Next twice →200,pages2/3 | Page2 IDs23–32; page3 IDs33,34,36,37,38; Previous/Next boundaries correct |
| parent-metadata | Search `unsupported`, then `anak_arsip`, then `detail_tingkat_tiga` →200,total1 each | Orphan ID999 labeled missing; row36 parent35 Nonaktif; row38 parent36, missing icon shown honestly |
| inactive | Nonaktif, no search →200,total2,pages1 | Arsip Nonaktif(ID35), Historis(ID20); both navigation buttons disabled |
| denied | Login denied.catalog; no Sidebars nav/table; raw GET is403 in authenticated helper checks | No catalog disclosure, no fake populated table |
| offline | Login reader first; stop backend Ctrl+C in Terminal1, Refresh | Honest offline error and no table; PG remains running for postcheck |
| restart | Restart backend, relaunch same profile/login reader, inspect catalog | Actual GET200 and original totals25/23/2 |
| final | Close Flutter; all states equal baseline | Audit0; membership/grants and44 SQLite hashes unchanged |

```powershell
python $runner postcheck --id $id --expect list # substitute exact phase above
```

Each successful phase prints `SIDEBARS_V1_<PHASE>_PASS`, e.g.
`SIDEBARS_V1_STATUS_FILTER_PASS`, and a new evidence path. The offline postcheck
does not issue HTTP if the backend is absent; source preservation still checked
through the owned PG cluster. For the next launch, start backend again.
If Flutter exits ambiguously, preserve launch.lock and investigate; do not delete
it automatically. No cleanup/restore/retry is part of acceptance.

After Flutter and backend are closed:

```powershell
python $runner stop --id $id
```

## Validation and rollout limits

Focused tests cover literal search, filtering/pagination/tie ordering/counts,
null/duplicate historical metadata, parent/orphan/deep records, strict parsing,
401/403, offline/error/empty/loading, no mutation controls, permission refresh,
four desktop sizes and persistent shell. Real Flutter HTTP reads run against
the owned disposable PostgreSQL runner, not mocks exclusively. Existing Groups
V2/V2.1 snapshots, UI, P0 authorization and legacy endpoints remain regression
requirements. New-profile provisioning, read-only role/attestation and fail-closed
Python predicates are independently checked. No full-project test sweep.

Execution logs (ignored `.local`): `sidebars-v1-focused-final.log`,
`sidebars-v1-contract-final.log`, `sidebars-v1-groups-regression.log`,
`sidebars-v1-analyze-release.log`, `sidebars-v1-build-final.log`,
`sidebars-v1-prepare-final.log`, `sidebars-v1-owned-final.log`.

Actual final results: 38 Go route/security leaf scenarios PASS (including real
Flutter HTTP); two existing opt-in Groups HTTP wrappers intentionally SKIPPED,
their Go snapshot/security and Flutter widget/API regressions PASS. Two owned
Windows manifest/SELECT-only/attestation cases PASS. 55 focused Flutter tests
PASS (28 Sidebars +27 Groups), one authenticated HTTP Flutter test PASS, one
final-profile SQLite provisioning test PASS. Two Python predicate cases PASS.
Analyzer: no issues. Windows debug build PASS. Manual acceptance is PENDING.

Changed implementation: Go Sidebar repository/service/controller, additive
route and catalog DTO; Flutter SidebarApiService/models, catalog provider and
existing Sidebars screen. Supporting changes: opt-in fixture catalog,
paymentdemo Sidebars-only dispatcher/helper, dedicated Windows debug entry,
runner and isolated fixtures/tests. Existing Groups editor/snapshot services,
AppShell, business schemas and sync engine are not modified.

No operational PostgreSQL writes, production grants/definitions, original
development SQLite access, previous acceptance/promotional profile changes or
sync activation. No deployment migration. Operational rollout needs separate
review of the actual catalog/P0 activation and deployment of matching backend/
Flutter versions. This catalog does not resolve local Master action-level gaps
identified in Groups V2.1, or certify inactive/unused definitions as functional.
AppShell's existing name-based visibility policy also remains unchanged: legacy
labels that differ from shell labels need separate rollout review, not silent
aliases or catalog-driven navigation changes here.
