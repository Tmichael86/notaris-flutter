# Superadmin promotional demo after Users P0

Prepared from `ea7e697` on `feature/pemohon-cloud-sync`. This environment is
separate from the earlier academic presentation and every acceptance profile.
**Operator recording has not started. Native interactive acceptance is pending.**

## Verified environment

| Item | Dedicated value |
| --- | --- |
| Profile | `8dabee307092ae7f6398de5b55d95dc8` |
| Root | `%TEMP%\notaris-payment-8dabee307092ae7f6398de5b55d95dc8` |
| SQLite | `offline.sqlite`, explicit MateraiProfileDatabase v27 |
| Scope/cache | `promotional/8dabee307092ae7f6398de5b55d95dc8` / `notaris.promotional.<id>.auth` |
| HTTP | `127.0.0.1:55882`, loopback only |
| PostgreSQL | `127.0.0.1:55794/promotional_8dabee307092ae7f6398de5b55d95dc8` |
| Database marker | `NOTARIS PROMOTIONAL DISPOSABLE <profile>` |
| DB roles | `promo_owner` bootstrap; `promo_app` runtime |
| Account/group | `superadmin.promo`, 104/104, active `superadmin` |
| JWT | Existing AuthService, HS256, issuer, exp 120 minutes, security version 1 |

No environment DSN, production host, default DB, or HTTP target override is
accepted. Bootstrap verifies the live database/host/port and exact owned data
directory, uses an exclusive attempted lock and only a brand-new database.
The reviewed `20261119_users_security.sql` is applied transactionally there;
the original operational migration proposal remains unapproved/unapplied.
No AutoMigrate or public bootstrap/promotion endpoint is added.

Windows user/SYSTEM-only directory ACL, per-profile Ed25519 signature and Windows
DPAPI protect generated owner/app/login/JWT credentials. The one-use initdb
password file is deleted. Nothing secret is printed. `session.exe` is rebuilt
and hash-checked by the launcher; profile ownership/signature is checked again
by the runtime. A source/helper mismatch stops execution instead of silently
reissuing accounts or accepting an old executable.

All **21 current AppShell destinations** have explicit Group grants, checked
against current source routing and authenticated backend sidebar output. No
username-based role bypass or per-user override exists. Users/Groups CRUD grants
are explicit for the P0 recovery invariant; Sidebars READ supports the current
grant-management architecture. The promo HTTP wrapper nevertheless blocks every
mutation except normal login. The runtime PostgreSQL role has no Users/Groups/
Sidebar business DML. These are recording restrictions, not a claim that
operational administration has been activated.

`/api/v1/development/promotional` is authenticated and queries the active
PostgreSQL connection to attest database, address, marker and scope. Flutter
requires this attestation after normal login/restoration/permission refresh.
Backend restart checks owned target/recovery readiness; HTTP health verifies
normal authenticated login/RBAC. No offline login fallback is accepted by the
promotional entrypoint. Logout clears only its scoped secure-storage session.
An expired token requires legitimate login again with the same account; no
expiry extension, universal password or reprovisioning is used.

## Fictional local data and source-of-truth checks

The v27 profile was created through existing Drift creation and repositories;
the ordinary application and older demo versions are unchanged. Runtime opens
this file with migrations disabled, exact schema validation, FK checks and
`query_only=ON`. The recording is deliberately **read-only**. AppShell remains
persistent; Users/Groups/Sidebars/Configuration content is visibly marked as
prototype with its input disabled only inside this promotional scope.

| Data | Verified fixture |
| --- | --- |
| Notaris | `1001911260001`, Bagas Pradipta, Pembuatan Akta Fidusia |
| PPAT | `2001911260001`, Laras Mahendra, Akta Jual Beli |
| PIC | Rani Wulandari, one local Petugas bound to verified promo user 104 |
| Status/date/deadline | Dalam Proses; 19 November 2026; 22 November 2026 |
| Bill | Rp2,500,000 each; Rp5,000,000 total |
| Initial payments | Exactly two, Rp500,000 each; Rp1,000,000 total |
| Piutang | Rp4,000,000 |
| Pengeluaran | One ATK item, Rp85,000 |
| Pendapatan | Penerimaan Rp1,000,000 minus Pengeluaran Rp85,000 = Rp915,000 |
| Materai | Fictional verified opening 20 + accepted stock-in 5 − usage 0 = 25 sheets |

These are fictional **local** administrative numbers, not cloud-issued numbers.
No real NIK, personal contacts, client documents, bank details, tax calculations
or inventory valuation is supplied. Reports derive from the existing payment,
expense and ledger repositories; the difference above is not labelled profit.
No cloud mapping/reconciliation or financial contract is invented for recording.
Binary document fixtures are not provisioned; document mutation features are
not exposed by this read-only profile.

## Operator commands

Run from repository root. **Use the existing ID; do not run `prepare` to resume.**

Terminal 1 — start only the retained dedicated cluster/backend:

```powershell
$promoId = '8dabee307092ae7f6398de5b55d95dc8'
python .\scripts\promotional-demo.py backend --id $promoId
```

Keep Terminal 1 open after `PROMOTIONAL_BACKEND_READY`. Terminal 2:

```powershell
$promoId = '8dabee307092ae7f6398de5b55d95dc8'
python .\scripts\promotional-demo.py health --id $promoId
python .\scripts\promotional-demo.py credential --id $promoId
# Close the credential dialog before any recording/window sharing.
python .\scripts\promotional-demo.py launch --id $promoId
```

Login as `superadmin.promo` with the password from the local Windows dialog.
Do not paste credentials into terminals/chat. The launcher binds the existing
profile and helper digest to `lib/promotional_demo_main.dart`; it takes a
single-launch lock and verifies baseline/health before opening Flutter. Choose
1920×1080, inspect the DEMO/FIKTIF/BACA SAJA banner and login screen first.
Automated tests also cover 1728×900 and 1366×768.

To renew: logout/login normally. If needed reopen `credential` using the same ID;
never run prepare/renew/reseed on this profile. If the backend is unavailable,
start Terminal 1; there is no production/offline fallback.

After closing Flutter, while the dedicated cluster is still up:

```powershell
python .\scripts\promotional-demo.py check --id $promoId
# Stop the foreground backend with Ctrl+C in Terminal 1, then:
python .\scripts\promotional-demo.py stop --id $promoId
```

`check` compares every SQLite table fingerprint, schema/integrity/FK and the
PostgreSQL auth/RBAC/audit fingerprints with the frozen baseline. It does not
rewrite the baseline. `stop` verifies owned DB identity and stops only that
cluster; it does not delete the profile, credentials or evidence. Keep this
TEMP folder during the recording period; Windows disk cleanup may remove
temporary data. Do not move/clone it into another profile or Windows account.

For a future separate environment only, `prepare` creates a new profile. A failed
preparation retains evidence. `validate --id ...` resumes **read-only validation**
of a fully seeded fixture, never reimports or overwrites an existing baseline.
Do not delete attempted/launch locks to force retries after an ambiguous failure;
review process state first.

## Suggested read-only walkthrough and honest narration

1. Login: “Akun demonstrasi terverifikasi pada backend yang terisolasi.”
2. Dashboard: “Ringkasan operasional ini berasal dari SQLite lokal.”
3. Sidebar: show the current 21 destinations and persistent shell.
4. Transaksi → search Notaris `1001911260001`, inspect work/PIC/payment history.
5. Search PPAT `2001911260001`, inspect its own domain/snapshot.
6. Monitoring Transaksi: inspect statuses/deadlines; do not change processes.
7. Pengeluaran: “Catatan operasional terpisah dari pembayaran pelanggan.”
8. Piutang: show Rp4,000,000 remaining from the accepted local payment ledger.
9. Penghasilan: show two active receipts totalling Rp1,000,000.
10. Laporan Materai: “Stok fiktif 20 ditambah penerimaan 5 menjadi 25 lembar.”
11. Pendapatan: select November 2026 if needed; show receipts/expenses/difference.
12. Users, Groups, Sidebars: “Fondasi keamanan backend diuji; UI administrasi
    masih pratinjau dan tidak melakukan pengelolaan akun.”
13. Configuration is also prototype. Log/Monitoring Sync and Recycle Bin are
    implemented local views; empty/unknown states are genuine in this new profile.
14. Return to Dashboard, logout, stop capture. Do not demonstrate destructive
    operations, sync, unfinished CRUD, or claim cloud publication from this demo.

Functional local views: Dashboard, Transaksi, Monitoring, Pengeluaran, Piutang,
Penghasilan, six Master menus, Materai and Pendapatan. Three additional local
diagnostic/recovery destinations are available read-only. Four System content
screens are prototypes. No new grants imply those prototypes have become live.
Capture only the Flutter window; keep terminals, credential dialog and debug
consoles out of footage. No video is generated or published by this task.

## Current validation evidence and boundaries

- New account bootstrap, reviewed SQL constraints, bcrypt/normal JWT, current
  grants/recovery invariant, expired/missing/revoked token rejection and role
  enforcement tested on the dedicated disposable PostgreSQL.
- Real native backend HTTP login/RBAC smoke PASS; active-connection attestation
  tested through authenticated HTTP against that PostgreSQL.
- Fixture repository reconciliation PASS; SQLite v27 integrity OK, FK 0.
- All 21 routes PASS at three sizes with the actual fixture opened query-only;
  a small preview-only scroll wrapper fixes the discovered compact prototype
  overflow. No business UI was redesigned.
- Online demo auth + P0 auth/AppShell focused tests PASS (15); old DPAPI tests
  remain intact. Analyzer and profile-bound Windows debug build PASS.
- Fixture seed ran once. Later verification skips seeding explicitly and proves
  baseline preservation. No original development SQLite, earlier presentation,
  financial/Materai acceptance profile, or operational PostgreSQL was opened.
- Manual native Windows credential entry, final visual approval and recording
  remain **OPERATOR PENDING**. No operational Users activation, cloud/bidirectional
  sync, production grants/migration, video publication, Git push or merge occurred.
