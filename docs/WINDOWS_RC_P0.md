# Windows Release Candidate P0 — build-only

Status: **build/artifact validation only**. Runtime QA remains **BLOCKED** until a separately approved release-compatible profile/environment exists. This document does not authorize installation launch, PostgreSQL writes, schema migration, sync, publication or server deployment.

## Configuration and safety findings

Normal entrypoint: `lib/main.dart`. Flutter/CMake compile/link the application and native plugins; they do not execute MyApp, AuthService or AppDatabase. Build uses the reserved endpoint:

```text
https://qa-endpoint-unconfigured.invalid/api/v1
```

This URL deliberately cannot identify the development/operational backend. It is compile-time configuration, **not a new security guard or a replacement for runtime scope validation**. Do not point this artifact at notarisdev by editing a file or bypassing existing guards. A future approved endpoint requires a separately built/reviewed artifact.

**Do not run the generated frontend_notaris.exe now**, even offline:

- Default AppDatabase opens `Documents/notaris_offline.sqlite`, schema24. This may be the user's original/daily profile. Merely changing the endpoint does not isolate SQLite.
- Normal AuthService uses secure-storage key `notaris.auth.session.v1`; a remembered session can restore and open the local shell without successful online login.
- The existing Windows development entrypoint, H01/H02 and other acceptance bindings are debug-only. Their DPAPI/profile credentials/manifests are not copied or enabled in release.
- Newest feature demonstrations use separately bound schema25/26/27 profiles. This sprint does not implement H07 release schema/profile binding or migrate existing data.
- USERS_SECURITY_ENABLED is a **backend** prerequisite. It must be explicit true on a reviewed P0-ready deployment with revision/security-version/audit, current permissions and recovery admin. No backend is started; P0 is not disabled for login.
- Existing .env defaults point at notarislokal. Neither Go defaults nor backend configs/secrets are packaged/executed.
- H01 remains DISABLED_BY_POLICY; H02 action-grant repository enforcement remains unchanged. H03–H14, server cutover, offline-policy changes and global/background sync are outside this change.

There is no safe release runtime profile currently approved. Do not reuse H02, promotional, development, historical replay or other accepted SQLite/auth profiles as a fallback. Runtime smoke/login/clean-machine functional acceptance are **BLOCKED**, not inferred PASS from a successful build.

## Narrow branding changes

The original `assets/images/app_logo.png` is preserved byte-for-byte. Windows icon is deterministically encoded from it at16/24/32/48/64/128/256px; no artwork redesigned. `Runner.rc` product/file description and native window title use `MY NOTARIS - SIM Notaris & PPAT`; internal executable filename stays `frontend_notaris.exe`. Legal copyright is unchanged. PNG is registered in pubspec so it is included in the bundle. No Dart UI, service, controller, permission or schema changes.

## Build

From `frontend_notaris`:

```powershell
flutter build windows --release --no-pub -t lib/main.dart --build-name=1.0.0 --build-number=1 --dart-define=API_BASE_URL=https://qa-endpoint-unconfigured.invalid/api/v1
```

No test-profile defines, backend credentials, JWT secret, fixture UUID or publication activation is passed. Version resource is1.0.0.1, product version1.0.0, x64 Release. Output:

```text
frontend_notaris/build/windows/x64/runner/Release/frontend_notaris.exe
```

Toolchain/source commit and actual command, hashes and validation outcomes are captured in the generated sanitized manifest. Build warnings and missing optional toolchains must be recorded honestly. Android license readiness is unrelated to Windows; it is not silently declared PASS. This project currently uses the installed Windows/MSVC toolchain; a compiler upgrade is not part of the sprint.

## Distribution contract

Ship the **whole inspected runtime payload**, with its original hierarchy, plus manifest and a prominent DO_NOT_RUN warning. One reviewed exception: CMake can copy a stale root `native_assets.json` from prior Flutter test/debug tooling. It embeds an absolute build-machine SQLite path and is excluded from the distribution, with its hash/reason recorded. Preserve the actual `data/flutter_assets/NativeAssetsManifest.json` and its bundled `sqlite3.dll` binding. Do not rewrite AOT/runtime metadata or silently drop unknown files. Raw compiler output remains preserved for audit. Never ship only the .exe. The manifest inventories every file by relative path, size and SHA256.

Required top-level binaries:

- frontend_notaris.exe
- flutter_windows.dll
- file_selector_windows_plugin.dll
- flutter_secure_storage_windows_plugin.dll
- printing_plugin.dll
- sqlite3.dll
- pdfium.dll
- notaris_document_store.dll
- notaris_document_pdf.exe

Required data:

- data/app.so: Dart x64 ELF AOT snapshot (it is **not a PE DLL** despite the Windows package).
- data/icudtl.dat.
- Entire data/flutter_assets tree: AssetManifest.bin, FontManifest.json, fonts, images, licenses, shaders and package assets as generated.

The optional JNI CMake target is not assumed to yield a DLL: inspect actual installed build output/imports. Do not fabricate a jni.dll requirement or copy Java runtimes opportunistically. Native helper/PDFium paths are relative to the executable in the existing loader; retain same-directory layout. Exact static and dynamic imports are recorded; host dependency resolution does not prove clean-machine readiness.

No .env, password/JWT secret, SQL/dump/SQLite, WAL/SHM, DPAPI sealed account material, private key, session.exe, acceptance manifests/credentials or build .local directories may enter the distribution. No installer/shortcut/autostart service is created. Debug .pdb symbols, if generated, belong in a separate private symbol archive, not a required runtime installation.

## Visual C++ and platform prerequisites

Windows x64; runner manifest declares Windows10/11 compatibility and PerMonitorV2 DPI. This is a declared target, not a test on every Windows build. Use a supported Microsoft Visual C++ **v14 x64 Redistributable** compatible with the newest toolchain/prebuilt dependency used. Do not copy random runtime DLLs from the developer's System32. Runtime installation, if needed, must be reviewed on the QA machine and is not performed here.

Primary references: [Flutter Windows distribution guidance](https://docs.flutter.dev/platform-integration/windows/building), [Microsoft supported v14 Redistributable](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist/), [MSVC runtime compatibility](https://learn.microsoft.com/en-us/cpp/porting/binary-compat-2015-2017). A complete Flutter bundle and compatible VC++ runtime are required. Actual import names/host resolution are evidence; clean-machine installer/runtime smoke remains a separate gate. Native PDFium pin comes from the existing printing plugin build configuration; dependency security certification/upgrades are not claimed.

## Validation

Packaging tests inspect files/PE/resources/AOT without launching frontend_notaris.exe:

```powershell
# Repository root; Windows Python standard library only.
$env:NOTARIS_RC_BUNDLE = '<absolute owned RC distribution path>'
python .\scripts\test_windows_rc_packaging.py -v
Remove-Item Env:NOTARIS_RC_BUNDLE
```

An alternate owned copied bundle can be inspected with `NOTARIS_RC_BUNDLE=<absolute path>`. This is a read-only test path, not an execution/profile bypass flag. Checks cover required binaries/assets, x64/no debug CRT imports, Release version/brand, icon frame integrity, original PNG equivalence, compiled .invalid endpoint, no profile/credential/database files, and dependency files present or resolvable on the build host.

Focused Flutter checks exercise existing H01/H02 on disposable test databases and fresh temporary files only. Native document/preview tests use the actual Release helper/DLL through their existing test-only defines; they do not launch the application or use an acceptance profile. Their pass/fail/counts are recorded in manifest/evidence. No full regression, operational login or live E2E is claimed.

## Artifact inspection / future installation

Current artifact is **BUILD_ONLY_DO_NOT_RUN**. It may be stored for offline inspection; it is not an approved operational client. The generated INSTALL_ROLLBACK.md names the exact zip/directory and gives exact checksum/extraction verification commands. Those commands do not launch the app.

Before runtime installation or Monday internal QA (23 November2026):

1. Complete H02 manual acceptance and applicable H03/H04/H05/H07–H10 gates; do not represent this branding/package commit as closing them.
2. Approve a release-compatible **new owned** SQLite/profile/auth namespace and environment/actor/generation/deployment binding. Define schema startup compatibility without touching original profiles. No release test may fall back to Documents or the global secure-storage cache.
3. Verify isolated QA backend identity using its active connection, explicit P0=true, current canonical grants/recovery, least-privilege runtime credentials, secrets injection and protected transport. No PostgreSQL credential belongs in Flutter.
4. Rebuild with the exact approved endpoint/configuration, freeze commit/bundle hashes, verify distribution and sign/scan according to the release policy (current executable may be unsigned).
5. Extract side-by-side into a version-specific QA directory; verify all file hashes before launch. Install/check Microsoft runtime through its approved official installer. Test on a clean machine with the owned QA profile, without pointing it at any existing personal/development files.
6. Only then test login/session restoration, profile isolation, authorized reads, local CRUD, document worker/printing/XLSX and denied actions. Sync/publication stays OFF unless a separate bounded window/allowlist is approved.

No launch command is provided for this blocked artifact.

## Rollback

Retain the previous **approved, hash-verified and schema-compatible** bundle side-by-side; do not overwrite it. Stop only the QA app after an approved runtime test, preserve its logs/profile, and switch back only if that prior release/profile combination is compatible. An executable rollback is not a database downgrade. Never restore/reset/migrate SQLite or reset cursor/ACK as part of uninstall/rollback.

This is the first RC: if no previous approved release exists, rollback means **stop testing and quarantine the new bundle**, not fall back to a Debug build or daily profile. Existing SQLite, secure storage, documents and PostgreSQL remain untouched. No automatic deployment/rollback script is introduced.

## Validation checkpoint — 21 November 2026

- Actual release build PASS, version1.0.0+1, x64. Flutter3.47.1/Dart3.13.1; Windows Visual Studio Build Tools2019 16.11.42, MSVC14.29.30133, SDK10.0.22000.0.
- Packaging tests: **9 PASS**, zero skipped, against the owned distribution copy. The additional portability test rejects root debug-only native_assets.json and verifies the preserved runtime native-assets binding.
- Focused Flutter/native smoke: **140 PASS**, zero skipped. Includes actual Release document DLL/PDF worker on new temp synthetic files, H01 startup/transport/coordinator containment and H02 direct repository/UI permission/profile-switch tests. Existing Drift isolated-multiple-instance warnings do not indicate shared original-profile access.
- Flutter analyze: **No issues found**. No full regression or live HTTP E2E.
- Host VC++ x64 installed14.51.36247; imported MSVCP140/VCRUNTIME140/VCRUNTIME140_1/UCRT dependencies resolve on this build host. Clean-machine installation/runtime remains unverified.
- Raw compiler output contains29 files after test tooling; distribution contains28 runtime payload files, including9 native PE executables/DLLs plus x64 ELF AOT and assets/data. Only the identified root debug native_assets.json is excluded, not any executable/DLL/data asset. User PNG SHA256 unchanged.
- **Application runtime smoke BLOCKED**: frontend_notaris.exe was never launched. Owned release-compatible SQLite/auth binding is absent. Existing acceptance profiles and credentials were not reused.

Exact focused command from frontend_notaris:

```powershell
flutter test --no-pub --dart-define=NOTARIS_DOCUMENT_TEST_DLL=D:/Perkuliahan/MAGANG/Works/Web/project-flutter-notaris/frontend_notaris/build/windows/x64/runner/Release/notaris_document_store.dll --dart-define=NOTARIS_DOCUMENT_TEST_PDF=D:/Perkuliahan/MAGANG/Works/Web/project-flutter-notaris/frontend_notaris/build/windows/x64/runner/Release/notaris_document_pdf.exe test/services/windows_transaction_document_store_test.dart test/services/transaction_document_preview_test.dart test/repositories/local_master_authorization_test.dart test/widgets/local_master_permissions_test.dart test/widgets/h01_startup_containment_test.dart test/providers/sync_coordinator_test.dart test/services/h01_transport_test.dart test/services/session_sync_controller_test.dart --reporter expanded
flutter analyze --no-pub
```

Local build/test logs and final artifact manifest are under ignored `.local/windows-rc-p0`; no database, secrets or build outputs are committed. The prior untracked NOTARISDEV preparation report remains separate and unchanged.
