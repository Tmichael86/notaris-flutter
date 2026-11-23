# Monitoring Transaksi XLSX

Laravel sends registration date, domain, job, category, status and officer
filters to `monitoring-fetch`. The browser DataTable applies search. Its XLSX
handler exports the rows held by DataTables, using one displayed row at a time
and summarizing PPAT jobs by transaction number. The controller formats totals
and receivables as Rupiah strings and the handler formats dates with
`localDate`. See `MonitoringController::fetch` and
`public/assets/scripts/administrator/monitoring/index.js` in the legacy checkout.

Flutter exports one row per transaction. It uses the same SQLite predicates and
ordering as Monitoring. Every matching row is selected before workbook
generation, with a 10,000-transaction limit that rejects larger exports.
One SELECT reads transaction data and active payment history in the same
SQLite snapshot and works with the demo's query-only connection.

| XLSX column | SQLite source |
|---|---|
| No | Position in date-descending, ID-descending result |
| Tanggal Daftar | Transaction date as a native Excel date in local time |
| Tanggal Selesai | Blank. SQLite has a deadline and deed dates, but no verified transaction-completion timestamp |
| No. Transaksi | Stored administrative transaction number, text |
| NIK Pemohon, Nama Pemohon | Same active, identity-matching contact join as Monitoring. NIK is text |
| Jenis Pekerjaan | Transaction domain |
| Nama Pekerjaan, Kategori | Distinct snapshots from the transaction's active job details |
| Estimasi Waktu | Distinct saved estimates on active job details |
| Proses | Names of persisted non-deleted processes owned by the active details. There is no inferred current or latest process |
| Total Tagihan | Stored transaction total as numeric Rupiah |
| Sisa Tagihan | Stored total less active payments, validated by the existing payment statement. Invalid history is blank. Historical overpayment remains a negative balance as in Flutter payment history |
| Nama Petugas | Same active, identity-matching officer join as Monitoring |
| Status | Stored transaction status |

Unresolved text references display an em dash. All workbook text, including
search terms and identifiers, is encoded as typed text. Save As uses the Windows
picker. The completed workbook is staged beside the selected file and published
without replacing an existing destination.

## Windows acceptance

Use a new profile prepared by the existing
`scripts\monitoring-demo-acceptance.py prepare` command. The demo opens its own
SQLite in query-only mode with sync and HTTP blocked. Close Flutter before each
postcheck. The signed credentials expire 24 hours after preparation.

1. Sign in as `pembaca.demo` and open Monitoring. Click **Next**, then **Excel**.
   Save to a new file and open it in Microsoft Excel. Confirm all 16 records are
   present in date-descending order, including the rows from the first page.
2. Export Notaris and PPAT separately. Each file has 8 records. Verify that
   transaction numbers and NIK retain leading zeros, dates sort as dates, and
   Rupiah cells can be summed.
3. Filter 15–16 November 2026, then Pembuatan Akta, Kenotariatan, Selesai,
   and Dimas Prasetyo. Expect one record, `1001511260001`, with both jobs
   in its summary. Confirm the applied filters in the worksheet header.
4. Cancel a Save As and confirm no file appears. Select a name already in
   use and confirm the existing workbook is preserved.
5. Close Flutter and run `postcheck`. Repeat the permission check as
   `petugas.demo`, whose sidebar omits Monitoring, then run `postcheck` again.
