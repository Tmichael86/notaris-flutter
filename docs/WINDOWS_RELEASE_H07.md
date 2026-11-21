# H07 — normal Windows release, isolated disconnected QA

Validated 21 November 2026. Scope: **ISOLATED_STARTUP_VERIFIED_DISCONNECTED**.
This supersedes the runtime blocker for the NEW H07 build only. The RC P0
`1463c82` BUILD_ONLY archive remains quarantined and must not be launched.
No operational deployment, successful login, CRUD or cloud acceptance is claimed.

## Startup and binding

`main.dart` selects the release branch before the legacy/debug ProviderScope.
Four explicit compile-time values are required; missing or ambiguous values show
the blocked-startup screen before profile, authentication or database access.
H01/H02 acceptance defines are rejected in release.

`releaseQaApplication` obtains the native application-support directory, opens a
`ReleaseQaProfile`, then uses ordinary `MyApp → AuthStartupGate → AuthService`.
The existing authenticated shell is unchanged. Provider overrides bind the same
owned database to repositories, H02 authorization and the document profile.
They bind both ordinary and authenticated Dio providers to a disconnected
transport; no authenticated-client clone can silently lose that transport.

Only `qa-disconnected`, the reviewed `.invalid` endpoint, schema27 and a bounded
`qa-…` deployment label are accepted. No command-line/environment database path,
fixture UUID, acceptance JWT, copied database or production fallback is accepted.
Debug launchers are unchanged; this is the normal release `lib/main.dart`.

Actual new root, created by the application on first launch:

```text
%APPDATA%\MY NOTARIS\MY NOTARIS - SIM Notaris & PPAT\qa-release-v1\qa-h07-internal-v1
```

The generated `binding.json` holds installation, device, generation and profile
UUIDs, deployment/environment/endpoint, schema and NTFS database identity.
`profile.lock` prevents concurrent openers. Reparse points, hard-linked files,
identity replacement, unexpected binding fields and existing non-v27 databases
fail closed. Interrupted initialization never resets/imports an existing DB;
committed v27 initialization can resume with the same identities. Ambiguous
allocation or orphan manifest requires investigation, not automatic repair.

Actual application-generated profile:
`e0eae95e-f487-4f09-9fce-80eada289f0c/offline.sqlite` beneath that root.
No account is preassigned. Account/group come only from the real AuthService.

Windows secure-storage's existing plugin uses one shared file even for different
keys. Merely renaming the key would still open the old container. H07 therefore
injects a narrow `AuthSessionCache` implementation into the unchanged AuthService
authentication flow: current-Windows-user DPAPI, profile-scope entropy, encrypted
account/group/session envelope, and an exact profile-derived key. Only the owned
`session.dpapi` can be read/written/deleted. No `readAll`, old-cache fallback,
hardcoded role or login account is supplied. The original storage adapter remains
the default for pre-existing callers. Existing server verification, seven-day
offline grace, rejection behavior, logout and permission rules are unchanged.
DPAPI is local at-rest protection, not a replacement for backend authentication.

## Actual schema and runtime evidence

The current features require v27: completion21/22, payment23, handover24,
documents25/26 and Materai27. `ReleaseQaDatabase` uses the existing Drift onCreate
path and a verified explicit executor; it does not fabricate migration history
or change `AppDatabase`'s legacy schema declaration. Non-v27 existing files are
rejected before Drift could upgrade them. No existing profile was migrated.

Actual release startup and restart through Windows Computer Use both displayed
the branded login screen, `QA · v27` banner and the explicit disconnected message.
No credentials were entered, restored or fabricated. The application was closed
after both observations. Backend-unavailable login handling was exercised through
the real AuthService/controller in focused tests, **not** submitted in the runtime
login UI. A live process TCP inspection found no connections at that observation;
this is not a continuous network trace.

Read-only inspection of the newly created QA database after each close:

- user_version27; 44 application tables plus sqlite_sequence; all45 empty.
- integrity_check `ok`; foreign_key_check zero rows; startup connection FK ON.
- All installation/device/generation/profile identities retained on restart.
- Database SHA256 unchanged across restart:
  `a718ae4a24255662ccdeba51bfa18ad04095524f1fd8bbe497fdb90a801cdb43`.
- Auth account null and no session.dpapi on both starts. No sync/publish events.

Local evidence (not packaged as database/session contents):

```text
.local/h07-runtime/runtime-first.json
.local/h07-runtime/runtime-restart.json
.local/h07-runtime/preservation-before.json
.local/h07-runtime/preservation-after.json
.local/h07-runtime/focused-tests.log
.local/h07-runtime/analyze.log
.local/h07-runtime/release-build.log
.local/h07-runtime/packaging-tests.log
```

Filesystem byte/size/mtime comparison: 469 inventoried protected files unchanged,
zero newly created files in those protected inventories. This includes original
Documents SQLite, actual development SQLite and old secure-storage container,
existing acceptance SQLite/markers, the two backup archives and prior restore
rehearsal pg_control. They were hashed as files; no old SQLite was opened through
a database engine, no auth container was decoded, and no PostgreSQL connection
was made. Hash preservation establishes unchanged inventoried bytes, not an OS
access-trace proof that every unrelated file was never read.

## Build, tests and delivery

From `frontend_notaris`, using the existing Windows toolchain:

```powershell
flutter build windows --release --no-pub -t lib/main.dart --build-name=1.0.0 --build-number=2 --dart-define=NOTARIS_RELEASE_ENV=qa-disconnected --dart-define=NOTARIS_RELEASE_DEPLOYMENT=qa-h07-internal-v1 --dart-define=NOTARIS_RELEASE_SCHEMA=27 --dart-define=API_BASE_URL=https://qa-endpoint-unconfigured.invalid/api/v1
```

Result: x64 Release build PASS (1.0.0.2). Analyze: no issues. Focused Flutter:
141 PASS, 2 opt-in acceptance-profile tests skipped; includes18 new H07 tests,
H01 startup/transport, H02 repository authorization, administration auth and
Materai schema compatibility. Multiple-test-database debug warnings refer to
separate test-owned executors; no production/shared profile is used. Packaging:
9 PASS on the actual copied distribution, with expected build2 explicitly set.
No full regression or PostgreSQL tests were needed/run.

New artifact root:
`.local/h07-runtime/MY-NOTARIS-1.0.0-H07-QA/`.
Actual tested executable: `runtime/frontend_notaris.exe` under that root.
The entire runtime directory is required: nine native EXE/DLL files plus the
whole data directory (28 compiled files total). Manifest inventories exact sizes,
SHA256, PE imports, toolchain, source commit and limitations. Reviewed root-level
debug native_assets.json is excluded from the copied distribution only; the
real data/flutter_assets/NativeAssetsManifest.json and sqlite3.dll are retained.
No SQLite, DPAPI bytes, credentials, tokens, backend .env or SQL dumps are bundled.
Original app_logo.png is unchanged. No new branding or shell redesign.

Use supported Microsoft Visual C++ v14 x64 Redistributable and Windows x64.
Host runtime resolution passed; clean-machine runtime/installer and signing
remain UNVERIFIED (artifact unsigned). Do not copy DLLs from System32. See the
generated BUILD_MANIFEST.json, SHA256SUMS.txt and INSTALL_ROLLBACK.md for exact
side-by-side extraction, verification and rollback commands. Preserve the whole
bundle; do not install only frontend_notaris.exe.

## Remaining gates

H01 stays `DISABLED_BY_POLICY`; H02 is unchanged. Global SyncCoordinator,
background publisher and operational activation remain OFF.

This artifact intentionally cannot contact a backend. Next: approve a reviewed
P0-ready NOTARISDEV backend with USERS_SECURITY_ENABLED=true, verified current
permissions/security versions/recovery administrator and runtime target
attestation; specify its endpoint and deployment/profile boundary; separately
review the narrowly scoped connected-release binding; then build a NEW artifact
and authorize real login/local CRUD/selective sync tests. Do not repoint this
artifact, disable P0, reuse development/acceptance credentials or open the old
BUILD_ONLY artifact as a workaround. No database connection, reset, reseed,
publication or deployment is authorized by H07.
