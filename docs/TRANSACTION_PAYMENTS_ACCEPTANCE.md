# Acceptance disposable untuk pembayaran Transaksi

Jalankan dari root repository pada Windows, dengan Flutter Notaris tertutup.

```powershell
python .\scripts\payment-demo-acceptance.py prepare
$demoId = '<profile dari output prepare>'
python .\scripts\payment-demo-acceptance.py postcheck --id $demoId --expect initial
python .\scripts\payment-demo-acceptance.py launch --id $demoId
```

Provisioning membuat PostgreSQL sementara di port 55674 dengan autentikasi
SCRAM. Go memverifikasi login dan membaca role grup aktif serta izin Transaksi
melalui endpoint `sidebar-access`. PostgreSQL berhenti sebelum fixture SQLite
v23 disiapkan. Flutter demo memblokir HTTP dan sinkronisasi.

Sesi demo berlaku 24 jam sejak login Go. Helper Windows menyegel sesi per
akun dan profil dengan DPAPI pengguna Windows serta tanda tangan yang terikat
ke ID profil. Sesi development dan penyimpanan aplikasi utama berada di luar
jalur ini. Launcher memverifikasi helper terhadap build source tepercaya.
Role berasal dari sesi yang ditandatangani. Saat beralih akun, logout lalu
login menggunakan password akun tujuan. Saat restart, login kembali.

Untuk melihat password akun, jalankan dari terminal kedua. Windows
menampilkannya dalam dialog lokal. Terminal menunggu sampai dialog ditutup.
Jika dialog belum terlihat, periksa taskbar atau tekan Alt+Tab. Ctrl+C di
terminal membatalkan dan menutup helper. Untuk login, ketik baris password
atau salin dengan Ctrl+C saat dialog aktif dan tempel ke kolom Password.
Flutter demo mengenali salinan dialog jika nama akun sesuai dengan Username.
Jalankan ulang dengan nama akun tujuan saat berganti akun.

```powershell
python .\scripts\payment-demo-acceptance.py credential --id $demoId --account petugas.demo
```

- `petugas.demo` dapat melihat dan menambah cicilan. Repository pembayaran
  mensyaratkan izin ubah Transaksi untuk menambah cicilan.
- `admin.demo` dapat mengoreksi dan membatalkan dengan role superadmin dan
  izin ubah Transaksi.
- `pembaca.demo` dapat melihat riwayat pembayaran.

Cari transaksi Notaris `1001111260001`, Bagas Pradipta dan Pembuatan Akta
Fidusia. PPAT `2001111260001`, Laras Mahendra dan Akta Jual Beli, menjadi
pembanding yang dilindungi fingerprint. Kedua transaksi bertagihan
Rp3.000.000 dengan pembayaran awal Rp500.000.

| Aksi di Riwayat Pembayaran | Total dibayar | Sisa |
|---|---:|---:|
| Buka transaksi awal | Rp500.000 | Rp2.500.000 |
| Tambah cicilan Rp750.000 | Rp1.250.000 | Rp1.750.000 |
| Koreksi ke Rp800.000 dengan alasan bukti setor | Rp1.300.000 | Rp1.700.000 |
| Batalkan cicilan karena salah transaksi, dengan konfirmasi | Rp500.000 | Rp2.500.000 |

Tutup Flutter sesudah setiap fase. Jalankan satu postcheck sesuai fase
sebelum meluncurkan ulang profil yang sama. Saat koreksi, ubah nominal dan
isi alasan. Pertahankan tanggal, metode, dan keterangan cicilan.

```powershell
python .\scripts\payment-demo-acceptance.py postcheck --id $demoId --expect add
python .\scripts\payment-demo-acceptance.py postcheck --id $demoId --expect edit
python .\scripts\payment-demo-acceptance.py postcheck --id $demoId --expect cancel
python .\scripts\payment-demo-acceptance.py postcheck --id $demoId --expect restart
```

Untuk fase `restart`, buka ulang setelah `cancel` lulus. Login sebagai
pembaca dan periksa saldo serta baris Dibatalkan, lalu tutup Flutter. Postcheck
memeriksa jejak peluncuran ulang, role dan expiry, audit, integritas, FK,
saldo, dan fingerprint tabel terlindungi. Lakukan cleanup setelah evidence
selesai ditinjau.

```powershell
python .\scripts\payment-demo-acceptance.py cleanup --id $demoId
```
