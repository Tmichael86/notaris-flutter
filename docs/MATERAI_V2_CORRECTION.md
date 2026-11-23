# Materai V2 Slice 3 — Koreksi pemakaian Transaksi

Edit memakai `TransactionRepository.save` dan satu transaksi Drift pada koneksi SQLite yang sama dengan ledger v27. Repository memeriksa izin READ dan UPDATE Transaksi, sesi terverifikasi, profil, Petugas aktif, saldo pembuka, rantai ledger, serta hubungan mutasi awal dengan header. Kuantitas lama harus sama dengan pemakaian bersih yang terbukti di ledger. Revisi berasal dari fingerprint header dan detail aktif. Revisi dan predecessor ledger diverifikasi lagi di transaksi tulis.

Selisih kuantitas baru dan lama menentukan satu mutasi tambahan pemakaian atau pengembalian, dengan kuantitas dalam lembar. Kuantitas boleh menjadi nol. Edit dengan selisih nol tidak menambah mutasi. Stok tidak mencukupi, rantai atau revisi berubah, atau kegagalan insert membatalkan edit. Penggantian kuantitas historis tanpa relasi stok yang terverifikasi tetap mengikuti kontrak informasional profil tersebut.

Identitas koreksi `local:materai:<profile>:transaction:<uuid>:adjustment:<operation-uuid>` mengikat transaksi serta operasi. Provenance menyimpan mutasi awal, predecessor, fingerprint permintaan, kuantitas lama/baru, delta, saldo, aktor/Petugas, dan waktu serta tanggal lokal posting. Retry UUID dan isi yang sama mengembalikan PK sebelumnya. UUID yang sama dengan isi berbeda ditolak. Rantai stok tetap memuat saldo dan mutasi yang sebelumnya terbit. Laporan membedakan `Pengembalian meterai` dan `Tambahan pemakaian meterai` pada uraian.

Adopsi koreksi perlu marker profil dan bukti saldo pembuka yang dipin. Profil Slice 2 tetap dapat menggunakan stock-out awal tanpa adopsi koreksi. Izin koreksi berasal dari izin edit Transaksi dan tidak memberikan izin penerimaan manual. Tidak ada perubahan skema, cursor, ACK, atau sinkronisasi. Hapus lokal memakai soft delete dan menampilkan transaksi di Recycle Bin. Pembatalan pembayaran memiliki audit tersendiri. Keduanya belum memberikan kontrak atomik untuk membatalkan transaksi, menjaga histori finansial, dan mengembalikan lembar tepat sekali. Hapus dan batal transaksi tertaut tetap diblokir.

## Acceptance Windows

Gunakan satu profil baru dari `scripts/materai-correction-demo-acceptance.py`. Jalankan `prepare` hanya jika operator belum diberi profil. Credential dibuka melalui dialog Windows. Tutup Flutter sebelum setiap postcheck. Simpan tahap secara berurutan.

Untuk CREATE pilih Pemohon `Laras Pradépta`, Petugas `Rani Wulandari`, kategori `Category`, status `Baru`, pembayaran `Cash`, dan isi Jatuh Tempo. Nomor registrasi memakai tanggal perangkat. Pada 17/11/2026 nomor yang diharapkan adalah `1001711260001` dan `2001711260002`.

| Tahap | Tindakan | Stok / baris ledger |
| --- | --- | --- |
| `initial` | Postcheck profil baru. | 20 / 1 |
| `notaris` | Buat satu Transaksi `Materai Uji Notaris` Rp100.000 dengan 3 lembar dan pembayaran awal Rp20.000. | 17 / 2 |
| `ppat` | Buat satu Transaksi dengan `Materai Uji PPAT A` dan `Materai Uji PPAT B`, masing-masing Rp100.000. Isi total 4 lembar dan pembayaran awal Rp30.000. | 13 / 3 |
| `notaris-return` | Buka Notaris yang baru dibuat, ubah 3 → 1, simpan dan konfirmasi pengembalian 2. | 15 / 4 |
| `notaris-increase` | Ubah Notaris 1 → 4, simpan dan konfirmasi tambahan 3. | 12 / 5 |
| `ppat-return` | Ubah PPAT 4 → 2 dan konfirmasi satu pengembalian 2. | 14 / 6 |
| `insufficient` | Coba Notaris 4 → 19. Tambahan 15 ditolak, penggunaan tetap 4. | 14 / 6 |
| `zero-delta` | Ubah hanya Catatan Notaris menjadi `Catatan uji koreksi Materai`. Simpan dengan 4 lembar. | 14 / 6 |
| `restart` | Buka kedua transaksi dan pastikan pemakaian 4/2 bertahan. Periksa uraian koreksi di laporan. | 14 / 6 |
| `read` | Login sebagai `pembaca.demo`. Periksa laporan dan pastikan edit tidak tersedia. | 14 / 6 |
| `denied` | Login sebagai `petugas.demo`. Pastikan laporan dan simpan tidak tersedia. | 14 / 6 |
| `final` | Postcheck menghitung enam baris, termasuk pembuka, dua pemakaian awal, dan tiga koreksi. Total pergerakan 4 masuk dan 10 keluar. | 14 / 6 |

```powershell
$runner = '.\scripts\materai-correction-demo-acceptance.py'
$id = '<ID profil yang sudah diprovisikan>'
python $runner postcheck --id $id --stage initial
$stage = 'notaris'
python $runner credential --id $id --stage $stage
python $runner launch --id $id --stage $stage
# Tutup Flutter setelah tindakan fase ini.
python $runner postcheck --id $id --stage $stage
# Ulangi tiga perintah tahap untuk ppat sampai denied sesuai urutan tabel.
python $runner postcheck --id $id --stage final
```

Postcheck menerima hanya perubahan header dan ledger yang diharapkan per tahap. Ia membandingkan detail, proses, pembayaran, seluruh tabel terlindungi dan urutan SQLite dengan checkpoint. Tahap tanpa penulisan memerlukan hash SQLite yang sama. Verifikasi mencakup `integrity_check` dan foreign key. Aktivasi operasional memerlukan saldo pembuka, profil, dan pemetaan Petugas yang disetujui secara terpisah.
