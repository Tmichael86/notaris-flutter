# Laporan Pendapatan Lokal V1

Laporan menggunakan satu `SELECT` SQLite untuk mengambil pembayaran dan pengeluaran dalam snapshot yang sama. Query menggabungkan dua sumber dengan `UNION ALL`; rincian pekerjaan hanya menjadi konteks agregat pembayaran dan tidak memperbanyak penerimaan. UI dan Excel memakai proyeksi yang sama. Ekspor membaca snapshot terverifikasi setelah Save As dipilih.

| Ukuran | Sumber dan aturan |
| --- | --- |
| Penerimaan Tercatat | Pembayaran Notaris/PPAT aktif dan belum dihapus. Identitas pembayaran harus unik. Nominal integer harus cocok dengan nilai ledger, atau nilai historis harus dapat diverifikasi bulat positif. Relasi dan jumlah ledger induk harus lolos rekonsiliasi Penghasilan. Transaksi dibatalkan/dihapus dikecualikan. Status lain yang belum dikenali ditinjau. |
| Pengeluaran Tercatat | Catatan aktif pada tabel Pengeluaran, identitas unik, kategori sah, tanggal kalender valid, dan nominal SQLite integer positif. Edit atau soft delete tercermin dari state terbaru. |
| Selisih Penerimaan–Pengeluaran | Jumlah penerimaan dikurangi pengeluaran per tanggal dan periode dengan Rupiah bulat `BigInt`. Pembayaran audit menjadi histori perubahan, sedangkan tagihan dan ringkasan header dipakai untuk rekonsiliasi. |

Hari laporan memakai WIB UTC+07:00. Timestamp epoch pada pembayaran dikelompokkan berdasarkan instan yang benar-benar tersimpan. Pembayaran awal dapat mewarisi timestamp registrasi dan operator dapat mengisi tanggal melalui editor pembayaran. Tanggal Pengeluaran disimpan sebagai marker kalender tengah malam UTC dan komponen tanggalnya dibaca langsung. Penghasilan V1 tetap memakai kalender perangkat. Kedua batas periode inklusif dan default mengikuti bulan WIB. Catatan invalid atau tidak terverifikasi dikecualikan dan ditampilkan pada Perlu Ditinjau. Tanggal yang tidak terverifikasi ditampilkan terpisah dari anomali periode.

Izin memerlukan sesi sah dan tiga grant READ sidebar aktif dengan kode `laporan_pendapatan`, `penghasilan`, dan `pengeluaran`. Fixture presentasi bertanda tangan mengonfirmasi ketiga kode. Profil yang tidak menerima grant tersebut dari server ditolak, tanpa alias atau bypass berdasarkan nama atau role. Sesi demo memakai expiry yang diverifikasi helper. Sesi Go menggunakan klaim issuer, identitas, dan expiry dari sesi yang sudah dibentuk auth aplikasi. Izin diperiksa lagi sebelum file dipublikasikan. Tidak ada migrasi Drift. Saldo kas historis, pajak PPAT, valuasi materai, dan laba berada di luar kontrak.

Workbook menggunakan nama `Pendapatan_Data.xlsx`, satu worksheet `Pendapatan Data`, dan lima kolom No, Tanggal, Penerimaan Tercatat, Pengeluaran Tercatat, Selisih Penerimaan–Pengeluaran. Header diikuti seluruh baris harian terfilter. Excel menerima tanggal bertipe date, angka Rupiah numerik dan negatif, tanpa formula. Nilai atau total di luar 15 digit presisi ditolak. Hasil kosong menghasilkan header saja. Save As dapat dibatalkan dan publikasi menolak overwrite.

## Acceptance Windows

Gunakan ID yang diberikan pada laporan implementasi. Runner menggunakan satu dataset SQLite v27 dan bundel kredensial penolakan tanpa SQLite. Tutup Flutter sebelum postcheck dan jalankan setiap tahap dari root proyek. Kredensial tampil lewat dialog Windows. Jika bulan WIB sudah berganti, pilih tanggal November 2026 secara manual untuk menguji fixture. Reset harus selalu kembali ke bulan WIB berjalan.

| Tahap | Skenario dan hasil |
| --- | --- |
| `initial` | Postcheck saja. SQLite v27, integrity OK, FK 0, cursor 3, ACK tetap. |
| `report` | Login `superadmin.demo`, buka Laporan → Pendapatan. Periode November 2026 memuat 13 hari, penerimaan Rp78.000, pengeluaran Rp93.000, selisih **−Rp15.000**. Terdapat satu anomali bertanggal 4 November dan nol tanpa tanggal. Tanggal 12 November hanya mempunyai pengeluaran Rp12.000. |
| `date-filter` | Pilih 11–13 November 2026. Hasil 3 hari, penerimaan Rp30.000, pengeluaran Rp38.000, selisih **−Rp8.000**. Kedua tanggal batas tampil dan anomali 4 November keluar dari periode. Coba Reset. |
| `pagination` | Dengan periode penuh, halaman 1 memuat 13–4 November, penerimaan Rp30.000 dan pengeluaran Rp87.000. Halaman 2 memuat 3–1 November, penerimaan Rp48.000 dan pengeluaran Rp6.000. Kartu tetap memakai total seluruh periode. |
| `excel` | Dari halaman 2 dengan periode penuh, klik Excel dan Save As ke path yang dicetak runner. Buka workbook di Microsoft Excel. Periksa 13 baris, tanggal 13–1 November, nilai negatif numerik, dan jumlah kolom Rp78.000/Rp93.000/−Rp15.000. Tutup Excel dan Flutter sebelum postcheck. |
| `read-only` | Buka ulang, baca laporan, ubah periode dan pindah halaman. Batalkan Save As bila dicoba. File Excel dan SQLite tetap identik. |
| `denied` | Login `pembaca.demo`. Menu Pendapatan tidak tersedia, laporan dan aksi ekspor ditolak. |
| `final` | Postcheck saja. Konfirmasi hash SQLite, cursor dan ACK, integrity/FK, serta hash dan isi Excel yang sudah diperiksa. |

```powershell
$runner = '.\scripts\pendapatan-demo-acceptance.py'
$id = '<ID yang diberikan>'
python $runner postcheck --id $id --stage initial
$stage = 'report'
python $runner credential --id $id --stage $stage
python $runner launch --id $id --stage $stage
# Tutup Flutter sebelum postcheck.
python $runner postcheck --id $id --stage $stage
# Ulangi tiga perintah tahap untuk date-filter, pagination, excel, read-only, denied.
python $runner postcheck --id $id --stage final
```

Postcheck memeriksa data, file, dan integritas sesuai fase. Aksi dan tampilan UI dinilai oleh operator pada checklist di atas. Profil memakai SQLite native read-only ditambah `query_only`, serta konfigurasi demo tanpa HTTP. Hash seluruh SQLite mencakup transaksi, pembayaran, audit, pengeluaran, Materai, dan metadata sync.
