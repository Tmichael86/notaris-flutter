# Data Cetak Serah Terima Transaksi

## Audit dan keputusan lokal

| Laravel | Flutter/SQLite sebelum Slice 6 | Implementasi atau blocker |
| --- | --- | --- |
| Tombol **Cetak Serah Terima** membuka daftar `cetakPemohonFetch/{no_akta}`; `setCetakSerahTerima` menambah baris dan `cetakPemohonUpdate/{id}` mengedit baris tertentu. Controller menulis langsung melalui model `TransaksiCetakSerahTerima`. | Layar Transaksi menyimpan header lokal dan detail pekerjaan. Belum ada tabel data cetak. | Satu header Notaris/PPAT dapat mempunyai beberapa data cetak, mengikuti daftar berdasarkan nomor transaksi di legacy. SQLite memakai FK ke PK header agar perubahan nomor tidak memutus relasi. Data cetak juga memiliki UUID dan revisi lokal. |
| Form aktif mengisi `uraian` dan `keperluan` dengan Summernote. `list_keperluan` nullable dan kontrolnya dikomentari. | Tidak ada editor serah terima atau migrasi konten legacy. | Gunakan uraian dan keperluan sebagai teks biasa. Setidaknya salah satu diisi saat menyimpan lokal. Kolom tetap nullable. |
| Route berada di balik auth dan permission baca. Tombol Edit diperiksa terhadap izin update di UI legacy. `System::crudIdentity` menyimpan akun dan waktu buat/ubah. | Flutter memiliki izin aksi dan sesi offline terverifikasi. | Repository memerlukan baca untuk daftar, baca+tambah untuk buat, dan baca+ubah untuk edit. Actor tersimpan sebagai akun pencatat, tanpa menyatakan dia penyerah. Retry create dengan UUID dan isi sama tidak menambah baris. Edit stale ditolak. |
| Status 1 menyatakan baris data cetak aktif. Tidak ada tombol atau route pembatalan sendiri. Pada penghapusan transaksi, service menonaktifkan data cetak yang berkaitan. | Transaksi menggunakan soft delete dan dapat dipulihkan. | Daftar hanya dapat diakses pada transaksi aktif. Data cetak dipertahankan selama soft delete. Tidak ada penghapusan data cetak, workflow penyerahan, atau histori before/after baru. |
| Blade `cetak-pemohon` memakai nama pemohon transaksi, nomor transaksi, uraian, keperluan, tanggal ketika dicetak, dan nama user login pada tempat tanda tangan. Join Petugas tidak membuktikan pihak penyerah. Kop dan kontak ditulis langsung di Blade. | Master Pemohon dan Petugas tersedia melalui referensi lokal. Identitas kantor resmi dan penyerah terverifikasi belum tersedia. | Dialog menampilkan konteks Pemohon dan PIC yang dapat ditelusuri. Nama penerima aktual, waktu penyerahan, penandatangan dan kop resmi membutuhkan sumber sah. Cetak resmi diblokir. |
| Route dan penyimpanan memakai nomor transaksi bersama. JS lama mengambil nilai `#no_akta_notaris`. Tidak ada relasi data cetak ke detail PPAT, aturan status Selesai, atau validasi lunas pada handler ini. | Header Notaris dan PPAT terpisah, PPAT punya detail pekerjaan. | Aksi sama untuk kedua jenis, dibatasi header yang dipilih. Status pekerjaan, akta, pembayaran dan proses tetap utuh. |

SQLite v24 menambah tabel dan indeks. Draft hanya lokal. Staging mutation
dan apply perubahan cloud untuk transaksi yang mempunyai draft diblokir.
Pembuatan draft juga diblokir jika masih ada jurnal upload yang belum selesai.
Tidak ada perubahan kontrak cloud atau cursor.

## Acceptance Windows

Gunakan salinan disposable terpisah. Persiapan menggunakan SQLite Backup API
dan meng-upgrade salinan saja melalui Drift. Profil Invoice dan Pembayaran
tetap di v23. Demo memblokir HTTP dan sinkronisasi.

```powershell
python .\scripts\handover-demo-acceptance.py prepare --source-id 3d70fd9e72424e4ca2054eb462579df9
$demoId = '<ID setelah PREPARED>'
python .\scripts\handover-demo-acceptance.py postcheck --id $demoId --expect initial
python .\scripts\handover-demo-acceptance.py launch --id $demoId
```

1. Login fixture sebagai `petugas.demo` dengan password demo `Petugas-Akta-25211`.
   Buka Serah Terima Notaris `1001111260001` untuk Bagas Pradipta. Isi Uraian
   **Salinan Akta Fidusia** dan Keperluan **Arsip pemohon**, lalu simpan.
2. Pada PPAT `2001111260001` untuk Laras Mahendra, simpan Uraian
   **Salinan Akta Jual Beli** dan Keperluan **Arsip pemohon**. Pastikan PIC kedua
   transaksi sesuai fixture, Dimas Prasetyo. Tutup Flutter dan jalankan postcheck
   dengan `--expect create`.
3. Buka ulang. Edit uraian Notaris menjadi **Salinan Akta Fidusia dan lampiran**.
   Tutup Flutter dan jalankan postcheck dengan `--expect edit`.
4. Buka ulang sebagai `pembaca.demo` dengan password demo `Baca-Akta-25211`.
   Pastikan kedua catatan terbaca dan tambah, edit, serta cetak resmi tidak
   tersedia. Tutup Flutter dan jalankan postcheck dengan `--expect restart`.

Postcheck memverifikasi isi per transaksi, revisi, actor, fingerprint tabel
terlindungi, integritas, dan FK.
