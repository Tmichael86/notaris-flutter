# Pengeluaran local-first Windows acceptance

Use the isolated profile ID supplied for this test. The existing Go provisioner
authenticates all three demo accounts against an attested disposable PostgreSQL
cluster on loopback port 55674, then stops it. Signed sessions expire after 24
hours and require the Windows account that prepared them. Flutter opens only
the disposable SQLite, with migration disabled, foreign keys enabled, and
HTTP and synchronization blocked.

Run from the repository root in PowerShell. Close Flutter before each
postcheck and relaunch the same profile for each subsequent stage.

```powershell
$runner = '.\scripts\pengeluaran-demo-acceptance.py'
$id = '<prepared profile ID>'
python $runner postcheck --id $id --expect initial
python $runner credential --id $id --account petugas.demo
python $runner launch --id $id
```

| Stage | UI action and expectation |
|---|---|
| Initial | Sign in as `petugas.demo`. Open Pengeluaran. Expect 12 active rows, total Rp120.000, and types ATK and Transport. |
| Filters | Next shows 2 rows and the same Rp120.000 total. Date 1–4 Nov 2026 shows 4 rows for Rp40.000. Add ATK to get 2 rows for Rp20.000. Search `DEMO-03` or `ATK kantor 3` to get one row for Rp10.000. Search `NO-MATCH` for the empty state, then Reset. |
| Create | Add faktur `PT-ACCEPT-01`, date **14 Nov 2026**, type **ATK**, nominal **15000**, description **Berkas kantor sintetis**. Expect 13 active rows and Rp135.000. |
| Edit | Find `PT-ACCEPT-01`. Keep its faktur, change date to **15 Nov 2026**, type to **Transport**, nominal to **20000**, and description to **Kurir kantor sintetis**. Expect 13 active rows and Rp140.000. |
| Restart | Reopen and find the edited expense by faktur and description. Verify the date, type, and amount. Reset filters and verify Rp140.000. Close without changes. |
| Delete | Reopen and delete only `PT-ACCEPT-01` via confirmation. Expect it to disappear from search and the unfiltered list. Reset and confirm 12 active rows and Rp120.000. |
| Reader | Sign in as `pembaca.demo`. View Pengeluaran and use its filters. Add/Edit/Hapus must be unavailable. |
| Denied | Sign in as `admin.demo` in this specific disposable profile. Pengeluaran must be absent from the sidebar, even though the account has the verified demo superadmin role. |

After CREATE, close Flutter. Run the following in order. Each launch pauses
for the corresponding manual stage. Close Flutter to proceed to its postcheck.

```powershell
python $runner postcheck --id $id --expect create
python $runner launch --id $id # Edit
python $runner postcheck --id $id --expect edit
python $runner launch --id $id # Restart and read only
python $runner postcheck --id $id --expect restart
python $runner launch --id $id # Soft delete
python $runner postcheck --id $id --expect delete
python $runner credential --id $id --account pembaca.demo
python $runner launch --id $id # Read-only permission
python $runner postcheck --id $id --expect reader
python $runner credential --id $id --account admin.demo
python $runner launch --id $id # No Pengeluaran access
python $runner postcheck --id $id --expect denied
```

If any command reports BLOCKED, stop and retain the profile and receipts.
Postchecks read SQLite in read-only mode and write evidence separately. They
verify integrity, foreign keys, schema, all other tables and sequences, the
original expense rows, and the expected pilot row. The pilot must keep its
original UUID/PK across edit and restart and still exist after soft deletion.
No full-file hash is required after approved expense writes. The operator
records the UI permission outcomes separately from database evidence.

Windows acceptance remains pending. Invoice numbering, actor provenance,
expense XLSX, and Laporan Pendapatan integration remain open parity items.
