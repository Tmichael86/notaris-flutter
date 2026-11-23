# Piutang Layanan Lokal V1

Piutang membaca transaksi Notaris/PPAT dan ledger pembayaran SQLite. Tagihan adalah total tersimpan yang cocok dengan snapshot biaya pekerjaan setelah diskon. Pembayaran aktif dijumlahkan sekali per ID transaksi. Nilai pembayaran pada header hanya dipakai untuk rekonsiliasi. Pekerjaan selesai dengan saldo positif tetap tampil. Transaksi lunas dan tombstone tidak masuk daftar piutang aktif.

Kasus dengan nominal historis invalid, pembayaran melebihi tagihan, ledger dan ringkasan yang berbeda, snapshot tidak konsisten, relasi pemohon/petugas yang tidak cocok, atau nomor administratif ambigu masuk **Perlu Ditinjau**. Hasil tersebut tampil terpisah dan dikeluarkan dari total dan ekspor terverifikasi. Tenggat kosong tetap diterima ketika filter tanggal kosong.

XLSX memakai sepuluh kolom Laravel dan menyimpan nominal sebagai angka. Setiap transaksi memiliki satu baris. Nama pekerjaan dan kategori disusun menurut ID detail, dengan satu baris teks per pekerjaan di masing-masing sel. Kategori kosong memakai `—` agar posisi tetap sejajar. Nomor administratif dan NIK adalah teks literal. Seluruh hasil filter, termasuk pencarian, diekspor dari satu snapshot SQLite. Laravel memakai seluruh data tabel yang dimuat setelah filter tanggal/jenis dan mengabaikan pencarian browser saat ekspor.

Nominal hanya mencakup **layanan lokal**. Pajak PPAT kedua pihak dalam Laravel memerlukan kontrak data terverifikasi sebelum bisa diproyeksikan. CRUD Piutang, pengelolaan ulang ledger, aturan overdue, dan integrasi Pendapatan berada di luar V1. Pengoperasian Piutang tidak menulis ke database atau memicu sinkronisasi.

## Acceptance Windows

Jalankan launcher `scripts/piutang-demo-acceptance.py` dari root repository. `prepare` membuat satu SQLite v24 baru dan memverifikasi XLSX di `query_only`. Akun `superadmin.demo` memiliki izin baca dari provisioning Go terverifikasi. Akun `pembaca.demo` berasal dari bundle autentikasi terpisah yang tidak memperoleh `piutang.read`. Kedua sesi memakai satu SQLite demo dengan `query_only` dan HTTP diblokir.

| Pemeriksaan | Harapan fixture |
| --- | --- |
| Tanpa filter | 13 piutang, Rp 1.055.000, 1 Perlu Ditinjau. Halaman kedua memuat 3 baris. |
| Notaris / PPAT | 7 / 6 piutang, Rp 605.000 / Rp 450.000. |
| Notaris, 10 November 2026 sebagai kedua batas | 3 piutang, Rp 305.000. |
| `Salinan` | 1 piutang, tagihan Rp 180.000, pembayaran Rp 50.000, sisa Rp 130.000. |
| `PIU-13` | Tampil tanpa filter tanggal; dikeluarkan saat filter tanggal aktif. |
| `PIU-03` / `PIU-14` / `PIU-15` | Selesai dan menunggak / lunas sehingga tidak tampil / review karena ringkasan pembayaran tidak cocok. |
| Ekspor tanpa filter dari halaman kedua | 13 baris, `SUM(I10:I22)` = 1.055.000; nomor dan NIK `B22`/`C22` tetap teks. |

Catat `postcheck --expect initial` sebelum membuka aplikasi dan `postcheck --expect final` setelah menutupnya. Keduanya mencocokkan SHA-256 seluruh SQLite, integrity, FK, jumlah baris terlindungi, dan cursor dengan baseline.
