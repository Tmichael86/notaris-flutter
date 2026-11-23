# Laporan Mutasi Materai Lokal V1

Laporan baca saja menampilkan satu baris per mutasi dari ledger SQLite profil terikat. Semua kuantitas dalam lembar. **Stok tercatat** adalah snapshot milik mutasi itu. Total masuk dan keluar menjumlahkan mutasi terverifikasi yang cocok dengan filter di seluruh halaman. Saldo awal/akhir periode dan stok saat ini belum tersedia. Kuantitas pada header Transaksi tidak dipakai untuk membentuk riwayat stok.

## Profil dan penyimpanan

`MateraiProfileDatabase` adalah profil eksplisit versi 27. Upgrade disposable dari v24, v25, atau v26 menjalankan tahapan Serah Terima, Dokumen, dan Siklus Dokumen yang belum tersedia menurut versi asal, lalu menambah tabel dan indeks Materai. Profil reguler tetap v24, profil dokumen existing tetap v25/v26. Laporan pada profil tanpa ledger menampilkan status belum diimpor. Pengikatan penyimpanan ke profil operasional menunggu kontrak sumber.

`materai_movements` menyimpan PK lokal, ruang nama dan PK sumber, tanggal bisnis, timestamp pencatatan sumber, jumlah masuk/keluar, stok tercatat, keterangan, ID dan nama snapshot Petugas, status sumber, provenance JSON, fingerprint SHA-256, dan alasan tinjau. Kombinasi ruang nama dan PK sumber unik. Relasi transaksi dapat dipertahankan sebagai provenance sumber. Laporan tidak menggabungkan baris transaksi saat menghitung jumlah lembar.

| Sumber Laravel | Penyimpanan lokal |
| --- | --- |
| `materais.id` | `source_id`, bersama namespace snapshot yang disetujui |
| `date` dan `created_at` | Tanggal kalender ISO dan waktu sumber terverifikasi dalam epoch milidetik |
| `materai_masuk`, `materai_keluar`, `stok_materai` | Integer lembar dan snapshot saldo sumber, tanpa pembulatan |
| `keterangan`, `petugas_id`, `status` | Deskripsi, referensi/nama Petugas yang diverifikasi, dan status sumber |
| Audit sumber dan `transaksi_materai` | Provenance asli, termasuk relasi jika bukti tersedia; tanpa FK silang yang ditebak |

Loader **hanya ada pada tes**. Loader mengambil input sintetis berurutan dan katalog Petugas eksplisit. Identitas hilang atau duplikat membatalkan seluruh snapshot. Pengulangan snapshot identik tidak menulis lagi. Isi, status, atau cakupan yang berubah pada namespace yang sama ditolak untuk tinjau sumber. Nilai yang dapat dipertahankan tetap disimpan bersama payload asli jika catatan gagal divalidasi.

Jika saldo pembuka dan urutan diketahui, pemeriksaan menggunakan saldo sebelumnya ditambah masuk dikurangi keluar. Backdating, celah urutan, status nonaktif, dan saldo yang bertentangan memutus rantai verifikasi. Catatan bermasalah dipisahkan dari total dan saldo sumber tetap utuh. Baris berstatus nonaktif disimpan sebagai bukti dan tidak ditampilkan pada daftar aktif. Tanggal bisnis yang tidak valid masuk tinjauan di luar periode. Urutan tampilan berdasarkan waktu pencatatan, ID sumber, lalu namespace, semuanya menurun.

## Akses dan sumber nyata

Layar, provider, dan repository mensyaratkan akun aktif dengan izin baca pada sidebar aktif `laporan_materai`. Kode itu terverifikasi pada fixture bertanda tangan. Kode Laravel `materai` dan placeholder `laporan-materai` tidak disetarakan. Verifikasi grant profil operasional diperlukan sebelum rollout.

Impor operasional menunggu snapshot berizin dengan identitas namespace, fingerprint dan cakupan, urutan serta zona waktu sumber, bukti saldo pembuka, katalog Petugas dan metadata audit. Aturan koreksi, perubahan status, dan penyelesaian saldo yang bertentangan tetap perlu keputusan produk. Tidak ada importer startup, mutasi stok, integrasi pemakaian ke Transaksi, penilaian rupiah, XLSX/PDF, atau sync Materai.

## Ekspektasi fixture Windows

| Filter | Mutasi terverifikasi | Masuk | Keluar |
| --- | ---: | ---: | ---: |
| Semua | 12 | 20 | 12 |
| 10/11/2026, kedua batas | 10 | 0 | 10 |
| Nadia Pertiwi | 6 | 0 | 7 |
| Cari `PPAT` | 1 | 0 | 2 |

Halaman pertama berisi 10 mutasi, halaman kedua berisi 2. Stok sumber untuk mutasi pertama adalah 20, pemakaian PPAT 18, dan mutasi valid terakhir 8. Satu mutasi PPAT punya dua asosiasi sumber. Satu saldo kontradiktif muncul di **Perlu Ditinjau**. Satu mutasi nonaktif tersimpan sebagai bukti. Runner membuka profil disposable dengan `query_only` dan membandingkan SHA-256 seluruh SQLite sebelum dan sesudah. Kredensial memakai autentikasi demo terverifikasi dan dialog Windows.
