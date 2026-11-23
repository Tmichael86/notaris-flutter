# Penghasilan Lokal V1

Penghasilan adalah laporan baca saja dari `transaksi_riwayat_pembayaran`. Satu baris mewakili satu pembayaran aktif yang dapat diverifikasi. Pembayaran awal dan cicilan tampil terpisah, termasuk saat waktu bayarnya sama. Beberapa pekerjaan tampil sebagai snapshot dalam satu baris pembayaran.

| Aspek | Kontrak V1 |
| --- | --- |
| Tanggal laporan | `tanggal_pembayaran` pada kalender lokal, dengan kedua batas tanggal inklusif. Laravel terutama memakai `created_at`. |
| Urutan | Waktu bayar menurun, lalu PK pembayaran menurun. |
| Koreksi | Laporan menampilkan nilai dan tanggal bayar terkini dari ledger. Laporan ini adalah proyeksi ledger yang dapat dikoreksi. |
| Total Dibayar | Jumlah Rupiah bulat seluruh baris terverifikasi yang cocok dengan filter, termasuk baris di halaman lain. |
| Perlu Ditinjau | Nominal, tanggal, identitas, relasi, atau rekonsiliasi yang gagal diperiksa. Rekaman tanpa tanggal tampil terpisah saat filter periode aktif. |
| Status | Status transaksi induk. Status setiap proses pekerjaan memiliki makna tersendiri. |
| Akses | Izin baca pada sidebar aktif `penghasilan` wajib pada UI, provider, dan repository. |

Pembayaran batal, pembayaran soft-deleted, dan transaksi tombstone dikeluarkan. Ringkasan pembayaran pada header hanya dipakai untuk rekonsiliasi. Saldo historis per penerimaan dan kewajiban PPAT termasuk pajak belum mempunyai kontrak data yang terverifikasi. Penghasilan tidak menyediakan Excel karena ekspor Laravel untuk modul ini belum terverifikasi. Laporan Pendapatan memiliki scope tersendiri.

## Acceptance Windows

Runner `scripts/penghasilan-demo-acceptance.py` membuat satu database SQLite disposable v24 dengan dua akun demo terverifikasi. Launcher membuka SQLite dengan `query_only`, memblokir HTTP, dan memeriksa SHA-256 database sebelum serta sesudah sesi. Postcheck membandingkan SHA-256 seluruh SQLite, memeriksa integrity dan FK, serta memverifikasi fingerprint autentikasi dan cursor.

| Filter | Pembayaran terverifikasi | Total Dibayar |
| --- | ---: | ---: |
| Semua | 13 | Rp480.000 |
| Notaris | 7 | Rp295.000 |
| PPAT | 6 | Rp185.000 |
| 10/11/2026 pada kedua batas | 2 | Rp110.000 |
| Cari `PEN-01` | 2 | Rp170.000 |

Halaman pertama berisi 10 baris dan halaman kedua 3 baris, dengan total Rp480.000 di keduanya. Satu pembayaran nominal pecahan tampil di Perlu Ditinjau. Login `superadmin.demo` dapat membaca Penghasilan. Login `pembaca.demo` tidak memiliki izin baca Penghasilan. Kredensial tersedia melalui dialog Windows dari subperintah `credential`.
