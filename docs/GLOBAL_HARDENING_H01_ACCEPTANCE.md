# H01 — fail-closed startup/automatic sync

Automatic/global activation remains OFF. Manual Windows acceptance PENDING.
No approved global activation contract exists. This change cannot enable one.

## Enforcement

- AuthStartupGate mounts the persistent shell without a sync observer/callback.
- SessionSyncController and PeriodicSyncRunner retain inert compatibility APIs:
  callbacks are not retained/executed; no timer is registered.
- SyncCoordinator accepts no database/HTTP work callback. Every invocation throws
  SyncFailure(disabledByPolicy) and reports SyncStatus.disabledByPolicy before
  resolving any SQLite/HTTP/log provider. No flag/env/JWT/profile enables it.
- SKIPPED is distinct from success; failure mappings remain. No initial green
  success snackbar. Manual selective service/receipt/publication contracts are
  unchanged and remain separately guarded. Raw repository sync methods and H10
  general transport inheritance are not certified or redesigned by H01.

## New owned Windows profile

ID: `60635db070a04898c96a8859f4295f35`.
Directory: `%TEMP%/notaris-payment-60635db070a04898c96a8859f4295f35`.
Entrypoint: **lib/main.dart**, the normal MyApp/AuthStartupGate/AppShell.
UiSmoke=false; isolated transaction configuration=null; no coordinator override.
A debug-only manifest/DPAPI/helper-pinned binding redirects storage/auth to this
NEW profile. Release builds reject the acceptance define, with no normal DB
fallback. The signed helper reuses Profile V1 identity primitives on fixed NEW
ports: PostgreSQL55801, HTTP55889, database `profile_v1_<new-id>`. H01 ownership
marker and port-bound manifest reject previous profiles. Existing Profile V1
ports were occupied and were neither reused nor stopped.

SQLite v27 is query-only at runtime with migrations disabled and FK enabled.
The baseline protects all 44 tables, including transaction children, payments,
Materai, dirty category/Pemohon/Jenis rows, one pending and one ACK journal,
one identity/revision/final-number witness, and shared cursor9. Journal/identity
witnesses are synthetic **non-sendable** containment fixtures, not evidence of
real cloud publication. No operation may publish them.

Backend security versions remain enabled; the dedicated H01 runtime SQL role
has SELECT only/default_transaction_read_only. The H01 HTTP handler refuses
business mutation methods. Flutter traces ALL HTTP attempts before its secondary
allowlist guard. Tests also prove global denial without that transport guard.
Trace stores only event/time, endpoint path/method/status, account ID and policy
outcome: never credentials, tokens, request body or query parameters.

INITIAL passed, integrity ok/FK0. Cluster stopped after preparation. No Flutter
interactive acceptance was started. Existing accepted profiles were not opened.

## Operator commands (repository root, two terminals)

Terminal 1:
```powershell
Set-Location 'D:\Perkuliahan\MAGANG\Works\Web\project-flutter-notaris'
python .\scripts\h01-acceptance.py backend --id 60635db070a04898c96a8859f4295f35
```
Terminal 2:
```powershell
Set-Location 'D:\Perkuliahan\MAGANG\Works\Web\project-flutter-notaris'
$runner = '.\scripts\h01-acceptance.py'
$id = '60635db070a04898c96a8859f4295f35'
python $runner credential --id $id --account admin.profile
python $runner launch --id $id
```
Use the Windows credential dialog; do not screenshot/log the password. Login
admin.profile and keep remember-me checked. No transaction/master/profile edits.
Only existing local read views and explicit auth/permission reads are needed.

Close the Flutter window and exit flutter run normally (q if necessary) before
postcheck. An interrupted/ambiguous launch retains its lock: STOP for review;
never delete it or repair baseline automatically.

| Stage | Actual operator action / expected evidence | Postcheck --expect |
|---|---|---|
| INITIAL | Already prepared; all-table baseline/integrity verified | initial |
| LOGIN | Login; no startup sync success notice or cloud attempt | login |
| RESTORE | Relaunch same ID; remembered session restored | restore |
| WAIT | Leave authenticated window open at least **5m30s after login** | wait |
| RESUME | Minimize/restore (or Alt-Tab away/back); lifecycle trace pair | resume |
| RECONNECT | Stop ONLY HTTP via Ctrl+C in Terminal1; Akun > Muat Ulang Izin must fail safely. Restart same backend command; Muat Ulang Izin succeeds; no dirty-drain | reconnect |
| DIRECT-BLOCK | Master Data > Kategori Pekerjaan > Sinkronkan; DISABLED_BY_POLICY, not success | direct-block |
| STATUS | Review Log/Monitoring: previous evidence retained, no fabricated successful global sync | status |
| RESTART | Close/relaunch same ID, read data and restored session | restart |
| FINAL | All fingerprints/PG state unchanged; restore/wait/resume/reconnect/direct-block evidence present | final |

Example after closing the corresponding UI stage:
```powershell
python $runner postcheck --id $id --expect login
```
Replace login with the matching table value. RESTORE/WAIT/RESUME/RECONNECT/
DIRECT-BLOCK/STATUS can share one launch, **after performing all actual actions**;
then close and run each matching postcheck. Never use postchecks to manufacture
manual visual acceptance. LOGIN and RESTART are separate launches.

Expected markers: H01_INITIAL_PASS, H01_LOGIN_PASS, H01_RESTORE_PASS,
H01_WAIT_PASS, H01_RESUME_PASS, H01_RECONNECT_PASS, H01_DIRECT_BLOCK_PASS,
H01_STATUS_PASS, H01_RESTART_PASS, H01_FINAL_PASS. Visual observations still
require operator confirmation. Any forbidden request, changed fingerprint,
wrong target, missing lifecycle/reconnect proof, or ambiguous lock FAILS CLOSED.

After FINAL, Ctrl+C HTTP then:
```powershell
python $runner stop --id $id
```
Only this owned cluster stops; data/evidence remain. No automatic cleanup/restore.
Future NEW provisioning only: `python .\scripts\h01-acceptance.py prepare`.
Do not prepare again for the delivered ID.

## Automated validation / scope

Focused tests cover normal login/restoration, simulated timer passage/resume,
permission refresh/reconnect/navigation/logout/account change; alternate Dio,
forbidden GET and mutation verbs; preserved full SQLite snapshot/journal/cursor;
manual selective security/service/UI; auth/payment/Master/Pengeluaran regression.
Go tests cover H01/old-manifest separation and bounded publication allowlist.
Python tests cover strict HTTP/outcome predicates and actual authenticated WAIT
time (build/login delay cannot count). This is not a live cloud E2E rerun.

H02-H14, production schema/profile/canonical registry, general H10 Dio cloning,
and operational activation are out of scope. No operational PostgreSQL access,
original development SQLite access, previous-profile edits or sync activation.

## Validation checkpoint

- Final focused suite: **122 Flutter tests PASS** (`.local/h01-focused-final.log`).
- Two new-profile provisioning tests PASS during prepare.
- Three Go tests PASS: H01/old Profile manifest isolation and transaction
  publication allowlist (`.local/h01-go.log`).
- Three Python predicate tests PASS (`python scripts/test_h01_acceptance.py`).
- Flutter analyze: no issues. Windows debug main.dart build PASS
  (`.local/h01-windows-build.log`). The first build reported generic MSB8066;
  a standalone verbose rebuild passed. No infrastructure diagnosis is claimed
  from the generic first error.
- INITIAL evidence: `h01-postcheck-initial-1795225237571377700.json` inside the
  new profile. v27 / integrity ok / FK0 / 44 protected table fingerprints /
  two journal rows (one pending, one ACK), one identity and one cursor row.
- No `h01-events.jsonl` exists yet: manual app launch was NOT performed.
- Operational activation OFF; operator Windows acceptance PENDING.
