# Konfigurasi Umum V1 — authenticated read-only acceptance

## Scope and source contract

Canonical Sidebar code is `konfigurasi` (Laravel SidebarSeeder); `konfigurasi_umum` is NOT an alias. An explicit new canonical entry is provisioned only in this new disposable catalog. Actual operational registry remains unverified; operational activation OFF.

`GET /api/v1/konfigurasi` requires P0 enabled, valid HS256 JWT issuer/expiry/security version, active current User/Group, exactly one active canonical READ grant. Ordinary reader is supported; no Superadmin bypass. No configuration mutation routes. No migration proposal or SQLite configuration table.

Response: `{success:true,data:{id:1,development_data:bool,...13 fields}}`. Seven nullable strings: alamat, telp_rumah, telp_pertama, telp_kedua, email, notaris_bersangkutan, ppat_bersangkutan. Six nullable **unsigned integer decimal strings**: besaran_nilai_tidak_kena_pajak, pengecekan, surat_kuasa_membebankan_hak_tanggungan, ploting_validasi, harga_beli_materai, harga_jual_materai. Decimal strings preserve full uint64 precision (Dart BigInt); null is not zero. No floating-point currency conversion.

One SELECT, LIMIT 2, counts all rows in its statement snapshot: no row=404 configuration_missing; multiple rows=409 configuration_ambiguous; sole row not active ID 1 or invalid amount=422 configuration_invalid; unavailable schema=503 configuration_unavailable. No first-row fallback, auto-seed or unlockData. HTTP no-store. Only whitelisted DTO values exposed, sanitized errors.

The existing `NOTARISDEV SYNTHETIC v1` value stays unchanged in notaris_bersangkutan. UI explains development context instead of showing it as an official notary identity. It is never wired into invoice, tax, payments, Materai, numbering, deployment, Profile or sync.

## New Windows-owned profile

Runner: `scripts/office-v1-acceptance.py` reuses existing reviewed DPAPI, profile binding, credential dialog, PostgreSQL and SQLite snapshot primitives. New owner marker `office-v1-owner`, own secrets/manifest/scope; no old profile accepted. All roots are `%TEMP%/notaris-payment-<id>`; no free-form database target. PostgreSQL 127.0.0.1:55799, HTTP 127.0.0.1:55887, database `office_v1_<id>`; profile attestation checks actual active connection/database comment. Read-only runtime SQL role has SELECT only and default_transaction_read_only=on. SQLite v27 uses existing profile subclass, query_only and migrations disabled.

Fixture: four users/groups (admin.office, recovery.office, reader.office, denied.office); 26 Sidebar definitions including new canonical ID 40; canonical grants READ=1/CUD=0 for reader/admin/recovery, none for denied. Two local transaction aggregates (Notaris/PPAT), payment/process/master fixture data protected by all-table SQLite fingerprints. PostgreSQL also contains one locked transaction witness. No operational data used. Credentials via Windows dialog only, never printed in logs.

Expected values (development-only):
- alamat: Kantor Demonstrasi, Jalan Uji 12
- telp_rumah: 021000001; telp_pertama: Belum diisi; telp_kedua: 021000003
- email: kantor@example.invalid
- notaris_bersangkutan: development indication, NOT a genuine name
- ppat_bersangkutan: PPAT Demonstrasi
- besaran_nilai_tidak_kena_pajak: Rp 80.000.000
- pengecekan: Rp 0; SKMHT: Belum diisi
- ploting_validasi: Rp 18.446.744.073.709.551.615 (boundary fixture, NOT business default)
- harga_beli_materai: Rp 10.000; harga_jual_materai: Rp 12.000

## Commands and stages

From repository root in PowerShell:

```powershell
$runner = '.\scripts\office-v1-acceptance.py'
# Preparation creates ONE new profile; do not re-run to resume an existing one.
python $runner prepare
$id = '<NEW_OFFICE_V1_PROFILE from prepare>'
```

Preparation stops its cluster and prints OFFICE_V1_INITIAL_PASS. No manual Flutter acceptance is performed by preparation.

Terminal 1:
```powershell
python .\scripts\office-v1-acceptance.py backend --id '<same id>'
```

Terminal 2:
```powershell
python $runner credential --id $id --account reader.office
python $runner launch --id $id
```

After each UI stage close Flutter normally, then:
```powershell
python $runner postcheck --id $id --expect view
python $runner postcheck --id $id --expect refresh
python $runner postcheck --id $id --expect denied
python $runner postcheck --id $id --expect offline
python $runner postcheck --id $id --expect restart
python $runner postcheck --id $id --expect final
```

Run only the matching postcheck after performing that stage; do not run them as a batch claiming visual PASS.

| Stage | UI action | Expected API/UI | Marker |
|---|---|---|---|
| INITIAL | None, preparation only | singleton valid, marker intact, integrity/recovery/read-only role verified | OFFICE_V1_INITIAL_PASS |
| VIEW | Login reader.office, System > Konfigurasi Umum | authenticated GET 200, all 13 values, no Edit/Save | OFFICE_V1_VIEW_PASS |
| REFRESH | Click Refresh | fresh GET, same authoritative values | OFFICE_V1_REFRESH_PASS |
| DENIED | Logout; credential command for denied.office; login | menu unavailable; helper also proves GET 403, no fallback | OFFICE_V1_DENIED_PASS |
| OFFLINE | First login reader while backend runs. Stop only HTTP with Ctrl+C in Terminal 1; keep cluster running; Refresh | explicit backend-unavailable state, no cached authoritative claim | OFFICE_V1_OFFLINE_PASS |
| RESTART | Restart backend with same command; relaunch same id, authenticate if needed | real GET, same values, no SQLite migration/write | OFFICE_V1_RESTART_PASS |
| FINAL | Close Flutter | all-table/sequence hashes identical, locks/config/users/groups/grants/audits unchanged; local financial/Materai/cursors/ACK protected | OFFICE_V1_FINAL_PASS |

Postcheck proves preservation and automated HTTP access checks, not completion of human visual actions. Operator must confirm visual results. All evidence JSON stays under the new profile. Ambiguous launcher lock is retained, not removed automatically. Stop HTTP before `python $runner stop --id $id`; data/evidence retained, no destructive cleanup.

## Future editable release (not implemented)

Requires separate product approval: canonical operational readiness, singleton/revision schema, explicit editable fields/ranges and nullability, verified Superadmin plus READ/UPDATE, shared P0 lock/atomic audit/conflict checks, protected development marker separation. No UPDATE endpoint, financial recalculation or sync activation in V1.

## Prepared instance (20 November 2026)

Manual acceptance is PENDING. The prepared cluster is STOPPED.

- Profile ID: `7194810847336569c4cadca3f70a3263`.
- Directory: `C:/Users/Msi GF63/AppData/Local/Temp/notaris-payment-7194810847336569c4cadca3f70a3263`.
- INITIAL evidence: `postcheck-initial-1795181680108846600.json` in that directory.
- SQLite: v27, integrity `ok`, FK 0; two transactions, two detail/process/payment rows, all local table fingerprints protected.
- PostgreSQL: one configuration, four users, four groups, 26 Sidebar rows (24 active/2 inactive), 49 grants, one transaction-lock witness, zero administrative audits.
- Configuration SHA-256: `e3ca939ae07f0d9508cba08616f0eef1f9e757252b1223a2bc76534b29192a9f`.
- Transaction-lock witness SHA-256: `237265e3b057dd16aeceab6f0da7b5bd7b2fdb7e6f15c0b6c9d81351b744cfb0`.
- Marker preserved, SQL runtime SELECT-only/read-only, all PostgreSQL table and sequence digests unchanged across authenticated HTTP self-check.
- Automated validation: 28 focused Flutter tests; real UI/provider -> authenticated HTTP -> PostgreSQL test; owned-profile manifest/read-only HTTP tests; Python preservation predicates; flutter analyze and Windows debug build. See local `.local/office-v1-http-tests.log` for disposable route/P0 regression output. No manual stage is certified by these automated checks.

Resume without running prepare again:

```powershell
# Terminal 1 (repository root)
python .\scripts\office-v1-acceptance.py backend --id 7194810847336569c4cadca3f70a3263
# Terminal 2 (repository root)
$runner = '.\scripts\office-v1-acceptance.py'
$id = '7194810847336569c4cadca3f70a3263'
python $runner credential --id $id --account reader.office
python $runner launch --id $id
# Close Flutter after VIEW, then:
python $runner postcheck --id $id --expect view
```

No operational PostgreSQL mutation, production configuration change, original development SQLite access, prior acceptance profile modification, recovery-admin change or sync activation was performed. Operational activation remains OFF.
