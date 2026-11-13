# Monitoring Transaksi V1 Windows acceptance

Use the fresh synthetic profile ID printed by
`python .\scripts\monitoring-demo-acceptance.py prepare`. The provisioner
authenticates demo accounts against its own attested PostgreSQL cluster on
`127.0.0.1:55674` and stops the cluster before Flutter runs. Offline sessions
are signed and bound to the Windows user and profile, with a 24-hour expiry.
The app opens only that profile's v24 SQLite with migrations disabled and
`query_only` enabled. HTTP and sync are disabled in this entrypoint.

From the repository root in PowerShell, use the profile prepared for this run.

```powershell
$runner = '.\scripts\monitoring-demo-acceptance.py'
$id = '<prepared profile ID>'
python $runner credential --id $id --account pembaca.demo
python $runner launch --id $id
```

Sign in as `pembaca.demo` using the Windows credential dialog. In the sidebar
open **Monitoring**. Record PASS or FAIL for each scenario.

| Scenario | Expected result |
|---|---|
| Domains | Semua shows 16 rows over two pages. Notaris and PPAT each show 8. |
| Filters | Set 15–16 Nov 2026. The two boundary dates are included. Filter by Pembuatan Akta, Kenotariatan, Selesai, and Dimas Prasetyo to isolate Notaris on 15 Nov. Reset returns 16. Filter independently by Nadia Pertiwi or Pertanahan to exercise PPAT. |
| Search and pages | Search `1001511260001` or Bagas Pradipta; try NIK `0000000000000002`. With filters reset, page 1 starts on 16 Nov and page 2 starts on 6 Nov. Use Previous, then Next and change Petugas on page 2. It returns to page 1 with filtered totals and no stale rows. |
| Details | Open Notaris `1001511260001` and PPAT `2001611260001`. Each has two jobs. Check the separate category and process list for each job, including Pemeriksaan Berkas / Administrasi. No edit or validation action is available in the modal. |
| Small window | Reduce the app window, scroll the table horizontally to Detail, and check that the detail can scroll and close. |

Close Flutter after the first session and run the postcheck. Repeat with the
second account and confirm the Monitoring menu is hidden, while Transaksi is
visible. Close Flutter and run the final postcheck.

```powershell
python $runner postcheck --id $id
python $runner credential --id $id --account petugas.demo
python $runner launch --id $id
python $runner postcheck --id $id
```

Each postcheck checks schema, integrity, FK, transaction counts, cursor, and the
full SQLite SHA-256. Byte equality with the original fixture covers all rows
and schema, including payment, process, audit, dirty, identity, and mutation
state. The manual acceptance record is pending until both sessions and their
postchecks pass. Excel remains disabled and is outside read-only V1.
