# Development selective Transaction sync — Check checkpoint

Execution remains OFF. No approved development HTTP configuration is created by this change.

## Verified local inventory (read-only)

Profile: `notarisdev/14af5452144b42d0be2ad88bac41b656/offline.sqlite` under the existing application support directory.
Schema 19; integrity OK; foreign-key violations 0; no WAL at inspection.
20 Pemohon, 4 Petugas, 3 dirty active Transaksi (Notaris IDs 1 and 3, PPAT ID 2).
No Transaction identity, pending mutation or feed rows. No Master cloud identities.
IDs 1 and 2 lack historical price/category UUID provenance. ID 3 has provenance UUIDs, but its Master is not cloud-bound. None is eligible for upload.
Petugas cursor remains 4 under its existing baseline-import scope; do not replace this scope with the disposable service scope.

## Implemented boundary

The existing development entry enables read-only record preview, including UI Smoke. It does not construct an execution service/configuration. Each record shows blockers. The normal/daily entry remains unchanged.
The existing manual service exposes read-only per-record Check (profile, session/permission, identity scope, mutation identity, dependency UUIDs and process actor provenance), and repeats it before non-delete dispatch. Existing repository validation remains authoritative for immutable payloads, payment history and revisions. Check does not bind feeds, create mutations, write success logs or issue HTTP requests.
Single-record Upload and shared-feed Download contracts remain unchanged. No publication or automatic dependency upload is added.

## Manual procedure

1. Close Flutter and run from repository root:
   `python .\scripts\check-notarisdev-transaction-readiness.py --stage Check`
   This uses SQLite URI `mode=ro`, `query_only`, a consistent read transaction and the exact reviewed profile path. No Drift migration.
2. For visual review only: `.\scripts\run-notarisdev-flutter.ps1 -UiSmoke`.
   Open Monitoring → Pusat Sinkronisasi. Inspect Notaris and PPAT blockers. Upload/Download remain disabled.
3. Stop before Upload. A development execution factory/runtime backend attestation, reviewed account/device/generation/deployment scope binding, and valid active cloud Master references are still required. Missing historical provenance must not be guessed or rewritten. Prefer a newly reviewed transaction using verified references.
4. Only after a concrete eligible record, verified target/permission, SQLite backup and bounded UUID/write plan exist, request separate approval for its first Upload. No existing acceptance plan authorizes these development records.

No PostgreSQL writes, development SQLite writes, migration, reconciliation, cursor reset, cleanup, global sync or publisher activation were performed.
