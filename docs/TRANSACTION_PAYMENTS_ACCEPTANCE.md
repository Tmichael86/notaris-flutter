# Acceptance disposable untuk pembayaran Transaksi

Siapkan Windows demo lokal dengan SQLite v23 baru, tanpa HTTP, publisher, atau
sinkronisasi. Jangan gunakan launcher development yang membuka SQLite v20.
Siapkan akun operator dengan akses baca dan ubah Transaksi, akun superadmin
terverifikasi dengan izin yang sama, dan akun baca saja. Akun superadmin dipakai
untuk koreksi dan pembatalan. Ulangi alur pada satu transaksi Notaris dan satu
transaksi PPAT yang independen.

Fixture Notaris memakai pemohon Bagas Pradipta dan pekerjaan Pembuatan Akta
Fidusia. Untuk PPAT gunakan Laras Mahendra dan Akta Jual Beli. Keduanya memakai
Master, harga, dan kategori fixture lokal yang valid. Gunakan tagihan
Rp3.000.000 dan pembayaran awal Rp500.000. Ambil baseline nomor transaksi,
detail, proses, completion, jurnal, cursor, dan seluruh riwayat sebelum
memulai acceptance.

| Aksi di Riwayat Pembayaran | Total dibayar | Sisa |
|---|---:|---:|
| Buka transaksi awal | Rp500.000 | Rp2.500.000 |
| Tambah cicilan Rp750.000 | Rp1.250.000 | Rp1.750.000 |
| Koreksi ke Rp800.000 dengan alasan bukti setor | Rp1.300.000 | Rp1.700.000 |
| Batalkan cicilan karena salah transaksi, dengan konfirmasi | Rp500.000 | Rp2.500.000 |

Setelah restart, verifikasi baris kedua tetap ada dengan status Dibatalkan,
nomor urut dan UUID tetap, serta audit memuat aktor, alasan dan nilai
sebelum/sesudah. Tambah cicilan baru dan pastikan nomor urutnya 3. Periksa
bahwa pengurangan tagihan di bawah pembayaran aktif ditolak. Akun operator
hanya dapat menambah, sedangkan akun baca saja hanya dapat melihat riwayat.

Tutup Flutter sebelum postcheck read-only. Gunakan kriteria ledger repository
yang sama. Pembayaran aktif memiliki status 1 dan deleted_at kosong. Untuk
baris baru, baca nominal_rupiah dan cocokkan dengan nominal. Untuk baris
historis, gunakan nominal hanya bila nilainya rupiah bulat yang valid.
Jumlahkan pembayaran aktif dan kurangi dari total tagihan, lalu bandingkan
dengan cache header. Periksa FK/integrity dan pastikan perubahan
terbatas pada pembayaran, audit, serta cache saldo transaksi yang dipilih.
Periksa detail pekerjaan, proses, completion, jurnal, cursor dan transaksi
lain terhadap baseline. Data ini merupakan ledger lokal.
