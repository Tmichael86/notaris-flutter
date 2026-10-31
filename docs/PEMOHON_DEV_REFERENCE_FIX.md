# Pemohon development reference fix — 31 October 2026

Baseline d58a9f8; target is the approved synthetic notarisdev, not notarislokal.
No PostgreSQL schema/data migration, no SQLite reset, no Petugas runtime activation.

## Root cause proved from source

Backend models/pemohon.go and PemohonRepository.FindActive select both
`jenis_kelamin` (server integer ID) and `jenis_kelamin_nama` (joined display label).
Flutter PemohonApiModel already parses both. The old syncFromCloud ignored the
server ID, seeded only dev-* Laki-laki/Perempuan and looked up local rows by
normalized display name. The fixture producer instead creates server gender IDs
11/29 labelled Fixture Gender A/B. Normal dev bootstrap previously isolated the
database/auth cache but did not supply any reference mapping to SyncCoordinator.

Thus HTTP 200 / receiving 20 rows succeeded, but index 0 failed resolving its
label. Pemohon batch is one SQLite transaction: record/reference writes inside
that transaction roll back on error. Earlier category/expense sync is separate
and is not rolled back. Pemohon has NO incremental cursor/checkpoint today:
getAllPages assembles a list, then syncFromCloud applies the complete list.
There is no Pemohon cursor to advance or reset, and no success status after failure.

## Focused implementation

1. `go run ./cmd/devfixture -mode references` exports non-secret explicit
   server-ID/local-UUID pairs from the SAME fixture builder that generated the
   database. It does not read any database or emit fixture credentials. This is
   a local fixture contract, not an invented global canonical gender code.
2. run-notarisdev-flutter.ps1 checks smoke-v1, adds the existing profile generation
   and passes this manifest in process environment. notaris_dev_main requires
   generation equality, installs pemohonGenderReferencesProvider only for that
   explicit debug target. Normal main.dart does not load fixture mappings.
3. DevelopmentPemohonGenderReferences.prepare validates unique verified pairs,
   authenticated active server catalog IDs, then bootstraps local references by
   exact fixture-owned UUID. Local IDs are allocated independently. Existing rows
   are never reused by name or server integer coincidence; no local ID/UUID is
   changed and dirty/local labels are not overwritten. Missing/inactive/ambiguous
   references fail blocked_reference with no fallback to label matching.
4. Catalog is the EXISTING GET /petugas/references/jenis-kelamin. It is read-only
   and does not require the Petugas sync tables. The fixture account has its
   existing Petugas-read permission. Other accounts without that permission are
   blocked; permission is not broadened or bypassed. A future general reference
   API may use a different permission contract, but no endpoint is added here.
5. Coordinator injects this resolver into PemohonRepository. prepare is called
   before push/pull, outside the record-write transaction (no network inside it).
   Dependency reference inserts commit atomically on their own; the whole Pemohon
   business batch still rolls back on an unresolved record. Dirty local Pemohon
   remain untouched on pull. No journal, identity map or feed cursor is cleared.
6. Pull uses item.jenisKelamin server ID -> explicit local UUID -> actual local ID.
   Changing a display label does not remap identities. A label-only response on
   this verified path is blocked instead of guessed.
7. Development push resolves local UUID back to the verified server ID and sends
   existing `jenis_kelamin`, omitting `jenis_kelamin_nama`. Go SyncUpsert ALREADY
   accepts this field and checks that server ID exists. No backend API or schema
   change is needed. Mutation IDs/row-version protocol for Pemohon are not added.

The optional resolver seam preserves the existing non-development Pemohon path
and tests, including its legacy name contract. That path is NOT advertised as
canonical/verified and still needs a separate production reference-contract review.
No new fixture-label hardcoding was added to Flutter production. Tests explicitly
use renamed server labels and a same-label unrelated local row with ID 29 to prove
the development route does not silently fall back to names or integer equality.

## Re-run on the existing development profile

Keep the existing backend on 8081. Exit the current Flutter process (e.g. `q` in
its terminal), then launch from repository root:

```powershell
.\scripts\run-notarisdev-flutter.ps1
```

A full relaunch is required to receive the new reference-manifest environment;
hot reload of a process started with the old launcher is insufficient. This uses
the SAME profile generation and SQLite file. Do NOT delete the profile, regenerate
the database, or clear auth/pending state. Successful session restoration/login
triggers the existing initial coordinator; the manual sync button uses that same
dependency path. Fixture references are ready before Pemohon pull is applied.

Pending local Pemohon that refer to a different unverified legacy gender UUID
remain blocked for explicit reconciliation. Do not rename/copy IDs or reclassify
them automatically. Catalog/network failure similarly preserves all pending data.

## Validation actually executed

- Dart format; analyzer exit 0.
- Full Flutter suite: 258 passed, 2 skipped, exit 0. The skipped tests are the two
  opt-in live tests; the new Pemohon development smoke was run separately below.
- New SQLite/fake HTTP tests cover A/B mapping with unequal IDs, renamed labels,
  missing/duplicate/unverified references, failed second record rolling back the
  entire batch, retry after explicit mapping, dirty local preservation, verified
  server-ID push and label-only rejection. A sentinel Petugas cursor is checked
  unchanged solely to assert no unrelated checkpoint manipulation; it is NOT a
  Pemohon cursor or a new shared-feed contract.
- Go full suite exit 0 with integration DSNs unset. Only generator command code
  changed on Go; no API runtime/schema change. Existing PostgreSQL mutation tests
  were not rerun against a main database.
- New opt-in GET-only smoke used fixture login on the ALREADY running 8081 backend,
  real APIs and a new in-memory SQLite database. Actual SyncCoordinator initial
  run saved all 20 synthetic Pemohon with verified references; a second manual run
  succeeded with exactly 20 rows, no duplicates, status success. Test interceptor
  rejects every server mutation except POST auth/login; no user SQLite was opened.
- Launcher parser validated. No interactive Flutter UI success is claimed.

Reproduce the smoke in a local terminal (backend already running):

```powershell
$repo = (Get-Location).Path
Push-Location backend-notaris-go
$env:NOTARIS_DEV_REFERENCE_MANIFEST = (go run ./cmd/devfixture -mode references) -join "`n"
Pop-Location
$env:NOTARIS_DEV_SMOKE_ROOT = $repo
$env:NOTARIS_PEMOHON_DEV_SMOKE = '1'
Push-Location frontend_notaris
flutter test test/e2e/pemohon_dev_pull_test.dart --reporter expanded
Pop-Location
Remove-Item Env:NOTARIS_DEV_REFERENCE_MANIFEST,Env:NOTARIS_DEV_SMOKE_ROOT,Env:NOTARIS_PEMOHON_DEV_SMOKE
```

## Petugas remains separate

SyncCoordinator in providers/pekerjaan_provider.dart still only synchronizes
category, expense type and Pemohon. The Petugas manual debug target is separate.
notarisdev was restored without Petugas UUID/row_version/deleted_at, receipt,
outbox/publication migrations. This task neither applies nor re-audits that DB
schema; the existing provisioning evidence records them as pending. Prerequisites
remain approved migration+validation, bootstrap/publication, verified identity and
references, conflict/recovery review, then separately approved normal-app wiring.
The source 7058 legacy process rows and all Petugas business logic are untouched.
