# Slice 7 — Audit Kelola Dokumen Transaksi

**Status: BLOCKED untuk pengelolaan lampiran.** Audit menggunakan checkout
Laravel lokal `notaris.blitaris.test`. Validasi tidak membuka database atau
memeriksa isi direktori dokumen pengguna.

| Perilaku Laravel yang ditemukan | Flutter existing | SQLite v24 | Gap | Keputusan |
| --- | --- | --- | --- | --- |
| Form Transaksi aktif menyediakan **Cetak Invoice** dan **Cetak Serah Terima**. JS juga memiliki handler `#cetakDokumen` untuk URL Notaris/PPAT. Route Notaris menunjuk metode `cetakDokumenNotaris` yang tidak ditemukan pada controller/interface checkout ini. Route PPAT yang dipanggil JS tidak terdaftar. | Langkah **Dokumen & Catatan** memiliki tombol prototype yang hanya membuka pesan. Invoice dan Serah Terima punya aksi terpisah. | Data transaksi, pekerjaan, pembayaran, akta, dan data cetak Serah Terima tersedia. | Tidak ditemukan rantai UI → handler → metadata → penyimpanan untuk file lampiran. | Pertahankan langkah dan Catatan. Nonaktifkan tombol Kelola Dokumen dengan alasan yang terlihat untuk kedua jenis transaksi. |
| Upload yang ditemukan di controller Profil/Pengguna menyimpan gambar akun dengan validasi jenis dan batas ukuran. Form multipart di halaman Transaksi yang ditemukan mengarah ke Master Pemohon. | Tidak ada pemilih file atau penyimpanan lampiran transaksi. | Tidak ditemukan tabel metadata lampiran transaksi dalam skema Drift atau padanan pada migrasi Laravel checkout ini. | Aturan format, batas ukuran, path, kategori, kepemilikan header/detail, sharing, audit, dan versi dokumen tidak terverifikasi. | Jangan menerapkan aturan unggah gambar akun ke transaksi. Tunda import, buka, preview file, ekspor, rename, replace, dan remove. |
| Route cetak berada pada grup auth/authorized. Middleware legacy memeriksa izin baca sidebar. Invoice dihasilkan dari data transaksi, sedangkan `TransaksiCetakSerahTerima` menyimpan data persiapan cetak seperti uraian dan keperluan. | Izin Invoice dan Serah Terima sudah ditegakkan pada repository masing-masing. | Akta/Completion menyimpan metadata penyelesaian. Invoice menghasilkan PDF saat diminta. Data cetak Serah Terima menyimpan teks dan audit akun. | Tidak ada bukti izin akses file per operasi, hubungan file dengan transaksi lain, aturan file hilang, atau retensi. | Pertahankan kontrak fitur yang sudah diterima. Jangan memperlakukan PDF hasil cetak, template, metadata akta, atau data Serah Terima sebagai file impor. |

## Sumber audit

- `resources/views/administrator/transaksi/index.blade.php` pada tombol cetak dan form Tambah Pemohon.
- `public/assets/scripts/administrator/transaksi/index.js` pada handler `#cetakDokumen`, Invoice, dan Serah Terima.
- `routes/web.php`, `routes/api.php`, `app/Http/Controllers/Administrator/TransaksiController.php`, dan `app/Http/Controllers/Abstract/TransaksiInterface.php`.
- `app/Http/Middleware/Authorization.php` dan controller Profil/Pengguna untuk membedakan otorisasi baca dan upload gambar akun.
- `database/migrations`, model `TransaksiCetakSerahTerima`, dan `cetak-pemohon.blade.php`.

## Syarat kelanjutan

Gunakan sumber legacy yang menunjukkan lampiran nyata, atau tetapkan kontrak
lokal baru secara eksplisit. Kontrak perlu mencakup pemilik file (header atau
detail), operasi dan izin per aksi, format dan batas ukuran, serta kebijakan
replace/remove dan retensi. Tambahkan penyimpanan profil-terisolasi dan
migrasi setelah kontrak disetujui. Future cloud contract juga membutuhkan
identitas dan versi dokumen, metadata, transfer byte terverifikasi dengan
hash, tombstone, dan resolusi konflik sebelum upload dapat dipertimbangkan.

Belum ada acceptance file Windows pada checkpoint ini. Regresi UI memakai
fixture SQLite in-memory yang terpisah. Profil acceptance sebelumnya dan
SQLite development tidak diperlukan untuk memverifikasi keadaan ini.
