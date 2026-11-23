# Invoice Transaksi lokal

## Pemetaan Laravel ke Flutter

| Laravel | Flutter dan SQLite | Gap dan keputusan |
| --- | --- | --- |
| `index.blade.php`, `index.js`, route GET `cetakInvoices/{no_akta}` dalam grup `auth` dan `authorized` | `TransactionDesktopScreen` membuka `TransactionInvoiceDialog` untuk PK transaksi tersimpan. Repository membaca `transaksis` aktif. | Permission baca Transaksi berlaku saat membuka, menampilkan, dan mencetak. Cetak ulang membaca snapshot baru tanpa menerbitkan nomor atau mengubah transaksi. |
| `TransaksiController::cetakInvoices` mencari `no_akta`; Blade tidak mencetak nomor invoice terpisah. | `transaksis.no_akta` ditampilkan sebagai **No. Transaksi**. | Tidak ada seri invoice baru atau nomor akta legal. Tanggal transaksi ditampilkan jika ada. Tanggal cetak mengikuti waktu perangkat saat snapshot dibuka. Laravel menyiapkan tanggal kini, tetapi Blade tidak merendernya. |
| Nama dan alamat dari `pemohon`; pekerjaan dipilih lewat join Master Notaris/PPAT. | `pemohons` melalui referensi PK dan UUID yang tersedia. `transaksi_details` menyediakan nama dan biaya snapshot aktif, terurut per ID. | Alamat kosong dihilangkan. Identitas pemohon tidak terverifikasi atau rincian silang domain memblokir invoice. Perubahan Master tidak mengubah harga snapshot. |
| Laravel menyimpan satu `transaksi.petugas_id` per baris dan membaca nama lewat join `petugas`. Blok tanda tangan Blade mengambil `namaPenyerah` dari akun yang login atau petugas yang terhubung ke akun itu. | Header Notaris dan PPAT Flutter menyimpan satu penugasan lewat `transaksis.petugas_id` dan `petugas_uuid`. Snapshot invoice membaca hanya `petugas.nama` dari referensi lokal itu. | Jika kedua referensi ada, keduanya harus cocok. Referensi tunggal pada data lama tetap dapat digunakan. Jika nama kosong, referensi hilang atau tidak cocok, invoice menampilkan **Tidak dapat diverifikasi**. Nama dibaca dari Master saat preview dibuka karena transaksi tidak menyimpan snapshot nama PIC. |
| Blade menampilkan biaya pekerjaan dan pajak pihak PPAT bila tersimpan. Controller lama mengurangi jumlah bayar per baris dan mengurangi sekali pada total akhir. | `biaya_layanan`, `biaya_lainnya`, `total_snapshot`, `diskon` dan `transaksis.total` dari repository existing. | Tagihan existing tetap otoritatif. Pembayaran hanya dikurangkan sekali. Jika jumlah snapshot dan potongan tidak sesuai tagihan, cetak ditolak. Flutter belum menyimpan jenis/nilai pajak per pihak. Kuantitas materai belum mempunyai nominal dalam kontrak invoice lokal. Tidak dihitung ulang atau ditambahkan. |
| `transaksi_riwayat_pembayaran` dijumlah dari riwayat berdasarkan nomor transaksi. | Baris aktif dipilih dengan kontrak `getPaymentHistory`. Nominal dan total memakai `paymentRupiah` dan `totalActiveRupiah` dari Slice 4. | Hanya status aktif tanpa tombstone. Koreksi memakai nominal terbaru. Sisa adalah tagihan dikurangi pembayaran aktif; status Lunas berarti sisa nol. Pembayaran historis invalid atau melebihi tagihan memblokir cetak. |
| Blade memakai `konfigurasi_umum`, kop legal, nomor rekening tetap, terbilang, dan nama petugas/user aktif pada blok tanda tangan. | Konfigurasi kantor Flutter masih berupa formulir prototype tanpa sumber SQLite terverifikasi. | Identitas kantor, rekening, blok tanda tangan, dan terbilang legacy tidak diterbitkan di slice ini. Kop memakai nama aplikasi. Kop resmi membutuhkan konfigurasi kantor yang sah. |
| Blade berukuran lebar 210 mm dan memanggil dialog cetak browser. | Renderer PDF A4, font Noto Sans lokal, header tabel berulang dan footer halaman. Preview dan native Windows print menerima byte dari satu snapshot. | Tidak ada ekspor otomatis. Untuk PDF, pilih **Microsoft Print to PDF** dan lokasi yang diizinkan di dialog sistem. |

Invoice dibaca sebagai satu snapshot SELECT SQLite. Proses, akta,
payment audit, publisher, dan sync berada di luar jalur invoice. Tidak ada
migrasi. Jika data memakai karakter di luar dukungan font lokal, cetak
ditolak agar nama atau alamat tidak berubah di dokumen.

## Acceptance Windows

Jalankan dari root repository dengan Flutter tertutup. Launcher menyalin
evidence CANCEL dengan SQLite Backup API dari koneksi read-only ke profil
invoice baru. Profil invoice memakai `PRAGMA query_only`, HTTP diblokir,
dan launcher tidak menggunakan kredensial Slice 4 atau PostgreSQL.

```powershell
python .\scripts\invoice-demo-acceptance.py prepare --source-id 6a1294127b7b65695ea4b28eaceb09e8
$demoId = '<profile dari hasil prepare>'
python .\scripts\invoice-demo-acceptance.py postcheck --id $demoId
python .\scripts\invoice-demo-acceptance.py launch --id $demoId
```

Gunakan akun pembaca fixture lokal `pembaca.demo` dengan password demo
`Baca-Akta-25211`. Akun ini hanya berlaku pada entrypoint demonstrasi
dan cukup untuk preview serta cetak.

1. Buka Transaksi Notaris `1001111260001`, Bagas Pradipta, lalu pilih **Lihat Invoice**. Periksa pekerjaan, **Petugas Penanggung Jawab: Dimas Prasetyo**, tagihan Rp3.000.000, pembayaran Rp500.000, dan sisa Rp2.500.000.
2. Pilih **Cetak** dan pastikan dialog Windows terbuka. Batalkan sekali. Bila menguji PDF, pilih **Microsoft Print to PDF** dan simpan hanya di direktori sementara yang diizinkan.
3. Ulangi pada PPAT `2001111260001`, Laras Mahendra. Pastikan nomor, pemohon, pekerjaan, dan PIC cocok dengan transaksi itu. Profil demo ini menugaskan Dimas Prasetyo pada kedua transaksi.
4. Tutup Flutter dan jalankan ulang `postcheck --id $demoId`. Saldo, fingerprint, dan SHA-256 file harus sama. Pemeriksaan multi-halaman serta koreksi/pembatalan cicilan dicakup focused tests.
