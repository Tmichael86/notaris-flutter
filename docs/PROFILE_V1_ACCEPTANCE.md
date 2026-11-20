# Profile V1 — secure online self-service

## Contract

Canonical routes: `GET /api/v1/profile`, `PATCH /api/v1/profile`. P0 must be enabled; mandatory HS256 issuer/expiry/security-version JWT; active current User and Group. Subject comes only from server JWT middleware context. No target ID, Profile Sidebar, administrative grants or Superadmin shortcut. Query targeting and X-User-ID/X-Target-User-ID/X-Group-ID headers are rejected. No password/avatar/username/email/status/group mutation endpoints.

GET/PATCH return `{success:true,data:{id,nama,no_telp,alamat,username,email,group_id,group_nama,group_jenis,status,revision}}`. No password/hash/security_version/JWT/admin metadata. Responses no-store, sanitized errors, server-generated X-Request-ID.

PATCH is complete editable-field replacement: **all four keys required**, exactly once: expected_revision (positive integer), nama (nonblank string), no_telp (string/null), alamat (string/null). Missing/duplicate/unknown/trailing JSON and invalid UTF-8 rejected, body max 32 KiB. Null/empty trimmed telephone/address becomes null; omission never clears a value. Strings are trimmed, name max160 Unicode codepoints, phone max32, address max255 (compatible with legacy varchar255); NUL/control characters rejected, address permits newline/tab. Telephone is a string, not a numeric quantity. All security/identity fields outside this whitelist are rejected.

Dedicated ProfileService uses the existing AdminLock, current User row lock, current Group/security-version recheck, expected revision and atomic update/audit/recovery invariant. Only nama/no_telp/alamat plus revision and updated_at/updated_by change. Security version/password/group/status/login identity unchanged, current JWT stays valid. Stale revision 409; revoked actor 401/403; audit failure rolls back the whole update. No automatic retry.

Audit uses existing append-only administrative_audit without a migration. `source=online_admin_api` is the existing constrained online account-administration transport channel; it does NOT declare an actor Superadmin. Distinct `action=profile_self_update`, `target_type=self_profile`, actor_id=target_id and summary `origin=self_service_profile` classify SELF SERVICE explicitly. Before/after contain revision and submitted allowed field names, not private contact values, password, hash or tokens. Successful committed updates create one success audit; rejected requests return sanitized errors and never create a successful event.

## Flutter

Existing account menu opens one guarded Profile dialog over the same persistent AppShell. Read-only current account; edit three fields; Refresh/Cancel/dirty-discard/ESC, progress and single-flight reuse existing dialog components. Save requires PATCH ACK, authoritative GET readback and AuthSession permission/identity refresh; no logout for ordinary changes. On 409/unknown outcome no automatic retry or revision replacement: Refresh/review explicitly. Ordinary UiSmoke disables editing and its direct Dio mutation guard remains unchanged. No SQLite Users/cache table; secure-storage AuthSession refresh only. No transaction unlock, financial/office/Materai mutation, sync activation or profile reconciliation.

## New isolated Windows environment

Runner: `scripts/profile-v1-acceptance.py`. Reuses existing DPAPI, owner ACL, sealed manifest, source/helper pin, credential dialog and SQLite snapshot primitives, but creates a NEW profile. PostgreSQL **127.0.0.1:55800**, HTTP **127.0.0.1:55888**, database `profile_v1_<id>`, scope `profile-v1/<id>`. Runtime attestation reads the actual active database connection and owned database comment. No operational connection input/fallback.

Actors: admin.profile (101, Superadmin), recovery.profile (102, protected recovery Superadmin), user.profile (201, ordinary), admin.biasa (202, ordinary Admin), inactive.profile (203), groupinactive.profile (204). Five Groups. Six accounts have independent sealed passwords. No Profile grant created. Inactive actors cannot authenticate. Dedicated acceptance transport only exposes login/current-session/attestation/Profile. PostgreSQL app role has SELECT for identity resolution, column-only User UPDATE for allowed fields/revision/update metadata, audit INSERT/sequence USAGE; no update of group/status/password/security_version or other tables.

Manual fixture permits **one Save of user.profile only**, expected revision1. Core Profile API supports all active account types; direct PostgreSQL HTTP tests independently prove this. Acceptance-only runtime checks and UI disable editing after revision2 or for other actors. This is a bounded test profile, not an operational authorization policy. No automatic valid PATCH is performed during preparation.

Protected fixtures: locked server transaction witness; server financial/Materai witness records; complete local Notaris/PPAT transactions, prices/process/payment/master data and verified synthetic Materai opening20. SQLite v27 read-only at runtime (query_only, migrations disabled). Every SQLite table fingerprint preserved. Server fingerprints cover all tables except explicitly approved user201 text/revision/update-metadata and the one self-service audit/its sequence. Other Users, user201 password/security_version/group/status/username/email/image, Group/Sidebar/grants, configuration marker, locks and financial/Materai state stay identical.

## Commands and deterministic manual stages

From repository root, prepare ONCE only:
```powershell
python .\scripts\profile-v1-acceptance.py prepare
```
Preparation prints NEW_PROFILE_V1_PROFILE and PROFILE_V1_INITIAL_PASS, then stops its cluster. Do not prepare again to resume the same ID.

Terminal1:
```powershell
python .\scripts\profile-v1-acceptance.py backend --id '<new id>'
```
Terminal2:
```powershell
$runner = '.\scripts\profile-v1-acceptance.py'
$id = '<same new id>'
python $runner credential --id $id --account user.profile
python $runner launch --id $id
```
Credentials appear only in the reviewed Windows dialog; never paste them into chat/logs. Profile opens from the account/avatar menu, not Users or a new Sidebar.

Approved ONE edit values:
- Nama: `Rani Profil Diperbarui`
- Nomor Telepon: `+62 812-3456-7890`
- Alamat: `Alamat demonstrasi diperbarui`

| Stage | UI operation | Expected persisted state | Postcheck |
|---|---|---|---|
| INITIAL | Preparation only | User201 Rani Profil; contacts null; revision1; audit0 | --expect initial |
| VIEW | Login, account > Profile, inspect identity/null fields; close Flutter | same baseline | --expect view |
| EDIT | Edit then Cancel/ESC; confirm discard; close Flutter | same baseline, no PATCH | --expect edit |
| SAVE | Relaunch, edit EXACT three values above, Save ONCE; close Flutter | revision2; audit1; same JWT/security_version/group/login | --expect save |
| REOPEN | Relaunch same ID, open Profile, check readback and disabled acceptance editing | same revision2/audit1 | --expect reopen |
| REFRESH | Refresh Profile and inspect server values; close Flutter | same revision2/audit1 | --expect refresh |
| FORGED-DENIED | Automated helper issues injected group payload (400 before Save; budget403 after Save), never valid mutation | no protected changes | --expect forged-denied |
| INACTIVE-DENIED | Obtain inactive.profile credential; logout; attempt login; must be rejected | no protected changes | --expect inactive-denied |
| OFFLINE | First login user.profile online. Stop HTTP Ctrl+C (leave owned PG running); Refresh Profile; close Flutter | honest offline error, no fallback write | --expect offline |
| RESTART | Restart backend, relaunch same ID; authenticate if required, read Profile | revision2/audit1 and updated fields remain | --expect restart |
| FINAL | Close Flutter | protected hashes/SQLite integrity/FK/recovery/least privilege pass | --expect final |

After EACH matching UI phase, close Flutter then run:
```powershell
python $runner postcheck --id $id --expect view
# Replace only expect with the matching stage from the table.
```
Postchecks prove persisted state and automated HTTP safety probes, not that visual operations were performed. Operator confirmation remains required. CONFLICT races and audit-failure rollback are exercised in separate automated owned PostgreSQL schemas, not by modifying this manual profile or invalidating its baseline. No manual Users/Groups changes are authorized during this scenario.

On any fingerprint/state mismatch preserve evidence/lock and stop; never rebaseline, repair, reset revision or retry Save automatically. `stop` requires closing Flutter and stopping HTTP first; it stops the owned cluster and retains data. No destructive cleanup command.

## Deferred password/avatar and deployment

Password change is NOT implemented. Future policy: active P0 session + current password verification + confirmed new bcrypt-compatible12–72 byte password; expected revision/shared lock; atomic hash update/audit and security_version increment; revoke all sessions including current; login again, no replacement token. Avatar requires separately approved storage/privacy contract.

No new production migration is needed by this slice. Operational activation remains OFF; requires separate P0 schema/unique/FK/audit readiness, least-privilege deployment, coordinated writer locking and recovery-admin verification approval. No existing protected profile, original development SQLite, operational PostgreSQL, grants or credentials are modified by this preparation.

## Prepared instance — 21 November 2026

Manual Windows acceptance: **PENDING**. Owned PostgreSQL cluster: **STOPPED**. No valid PATCH has been executed on this manual profile.

- ID: `fe2611d1519c1769e03c0c403691d53b`.
- Directory: `C:/Users/Msi GF63/AppData/Local/Temp/notaris-payment-fe2611d1519c1769e03c0c403691d53b`.
- INITIAL evidence: `postcheck-initial-1795199612809093700.json`.
- Baseline file SHA-256: `df1ce6207e463112778db32802ba385680ef10527e4453fef69a8e714cb10c8c`.
- Actual User201: revision1, Group201, ordinary user, security_version1, audit0. Contacts null; name Rani Profil. Same account login identity remains user.profile.
- Actual PG fixture: six Users, five Groups, one locked transaction witness, financial witness500000 and Materai witness20. The configuration synthetic marker remains unchanged. Active ordinary/Admin/Superadmin/recovery GETs pass; inactive User and inactive Group login both return401. Least privilege/recovery/integrity PASS.
- SQLite: v27, integrity ok, FK0; 44 protected table fingerprints; two transactions/detail/process/payment rows, two local Master categories, one Master per domain, two Petugas and one verified Materai opening20.
- Protected PG lock hash: `237265e3b057dd16aeceab6f0da7b5bd7b2fdb7e6f15c0b6c9d81351b744cfb0`.
- Protected PG User/security-state hash: `19fb3b5634ab3cb8d33de8459e2abde796697c2c2ef1ae2ddfebe80bfca7e770`.
- Validation: 29 focused Flutter tests, real authenticated UI/PATCH/readback/AuthSession refresh/reopen HTTP test, disposable Profile and P0 Users/Groups tests, three Python acceptance-predicate tests, owned manifest/HTTP/permission tests, clean flutter analyze and Windows debug build. Unrelated Users/Groups Flutter opt-ins remain skipped; no full-project regression requested.

Resume directly, never re-run prepare for this ID:
```powershell
# Terminal1, repository root
python .\scripts\profile-v1-acceptance.py backend --id fe2611d1519c1769e03c0c403691d53b
# Terminal2, repository root
$runner = '.\scripts\profile-v1-acceptance.py'
$id = 'fe2611d1519c1769e03c0c403691d53b'
python $runner credential --id $id --account user.profile
python $runner launch --id $id
# Close Flutter after VIEW, then:
python $runner postcheck --id $id --expect view
```

After approved SAVE exactly once, expected User201 revision2/audit1, unchanged Group201/type user/security_version1/username/email/password; same JWT still works. Protected hashes must remain identical. Any unexpected extra edit requires review, never automatic repair or baseline replacement.
