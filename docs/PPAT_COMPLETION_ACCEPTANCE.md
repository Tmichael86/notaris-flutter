# Rencana acceptance penyelesaian pekerjaan PPAT

Siapkan profil Windows demo lokal baru dengan SQLite v22, banner **PROFIL
DEMONSTRASI**, akun fixture dengan akses baca dan ubah Transaksi, serta HTTP dan
sinkronisasi diblokir. Gunakan Master PPAT dengan kategori dan harga yang
terdaftar. Buat satu transaksi PPAT atas nama Laras Mahendra dengan dua detail
ber-UUID berbeda, **Akta Jual Beli** dan **Balik Nama Sertifikat**. Mulai kedua
detail pada **Dalam Proses** dan catat baseline nomor transaksi administratif,
detail, proses, histori, pembayaran, dan jurnal.

1. Buka **Status PPAT** pada detail Akta Jual Beli. Pilih **Selesai**, isi
   judul *Akta Jual Beli*, nomor 25211, dan tanggal 11/11/2026, lalu simpan.
2. Buka kedua detail. Pastikan hanya Akta Jual Beli yang selesai. Bandingkan
   snapshot dengan baseline, termasuk nomor dan status header, detail kedua,
   proses, histori, pembayaran, serta jurnal.
3. Restart aplikasi. Buka Status PPAT pada detail pertama dan periksa ketiga
   nilai akta. Ubah status detail ke **Dalam Proses**, simpan, lalu buka kembali
   untuk memastikan data akta masih tersedia.
4. Ulangi tampilan detail dengan akun fixture baca saja dan periksa bahwa
   penyimpanan tidak tersedia.
5. Uji warna pada profil disposable terpisah. Setelah **Inisialisasi proses**,
   badge berubah dari netral ke kuning. Ubah switch ke Valid dan periksa warna
   setelah **Simpan**. Badge menjadi hijau hanya pada proses yang disimpan.
   Periksa kembali setelah restart dan di Monitoring yang memakai daftar
   proses yang sama.

Periksa integrity_check, foreign_key_check, dan fingerprint tiap tahap
dengan SQLite read-only setelah aplikasi ditutup. Profil Notaris Completion
yang lama dipatok ke v21 dan tetap menjadi bukti. Gunakan profil v22 baru
untuk skenario PPAT ini.
