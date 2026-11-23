# Acceptance Windows penyelesaian pekerjaan PPAT

Dari root repository, jalankan persiapan berikut jika belum memiliki profil.
Runner membuat SQLite v22 baru di folder temp, memeriksa fingerprint dan
memeriksa SQLite development v20 secara read-only. Aplikasi demo memakai
login lokal, memblokir HTTP dan sinkronisasi, serta tidak memulai backend.

```powershell
python .\scripts\notaris-completion-acceptance.py prepare --scenario ppat
$ppatId = '<ID dari PREPARED>'
python .\scripts\notaris-completion-acceptance.py launch --scenario ppat --id $ppatId
```

Pastikan banner **PROFIL DEMONSTRASI** tampil. Login dengan `petugas.demo` dan
password lokal `Petugas-Akta-25211`. Buka **Transaksi → PPAT → Cari No.
Transaksi**, pilih `2001111260001` atas nama **Laras Mahendra**. Header dan
kedua detail, **Akta Jual Beli** serta **Balik Nama Sertifikat**, mulai pada
**Dalam Proses**. Baseline memiliki dua proses dan satu pembayaran Rp500.000.

1. **INITIAL.** Buka Status PPAT kedua detail dan periksa status awal serta
   data akta kosong. Tutup dialog tanpa menyimpan.
2. **COMPLETE.** Launch ulang. Ubah hanya Akta Jual Beli menjadi **Selesai**,
   isi **Akta Jual Beli / 25211 / 11/11/2026**, lalu simpan. Periksa pekerjaan
   kedua dan header tetap **Dalam Proses**.
3. **REOPENED.** Launch ulang. Periksa data akta setelah restart, lalu ubah
   hanya Akta Jual Beli ke **Dalam Proses**, simpan, dan pastikan data akta
   tetap bisa dibaca.

Tutup Flutter di akhir setiap fase dan jalankan satu postcheck yang sesuai.
Lanjut hanya setelah hasilnya PASS. Detail proses dan pembayaran boleh
dibuka untuk inspeksi selama skenario utama.

```powershell
python .\scripts\notaris-completion-acceptance.py postcheck --scenario ppat --id $ppatId --expect initial
python .\scripts\notaris-completion-acceptance.py postcheck --scenario ppat --id $ppatId --expect complete
python .\scripts\notaris-completion-acceptance.py postcheck --scenario ppat --id $ppatId --expect reopened
```

### Permission baca

Setelah postcheck `complete`, buka profil yang sama dan login dengan
`pembaca.demo` dan password lokal `Baca-Akta-25211`. Buka Status PPAT
Akta Jual Beli. Periksa status dan data akta terbaca, kontrol terkunci, dan
tombol Simpan tidak tersedia. Tutup Flutter dan ulangi postcheck `complete`
sebelum melanjutkan REOPENED. Tes repository juga memanggil penyimpanan
langsung dengan akun baca saja dan memeriksa bahwa operasi ditolak.

### Akta opsional

```powershell
python .\scripts\notaris-completion-acceptance.py prepare --scenario ppat-optional
$optionalId = '<ID dari PREPARED ppat-optional>'
python .\scripts\notaris-completion-acceptance.py launch --scenario ppat-optional --id $optionalId
```

Pada profil tersebut, simpan Akta Jual Beli sebagai **Selesai** dengan
ketiga field akta kosong. Tutup Flutter dan jalankan:

```powershell
python .\scripts\notaris-completion-acceptance.py postcheck --scenario ppat-optional --id $optionalId --expect complete
```

### Warna status proses

```powershell
python .\scripts\notaris-completion-acceptance.py prepare --scenario ppat-process
$processId = '<ID dari PREPARED ppat-process>'
python .\scripts\notaris-completion-acceptance.py launch --scenario ppat-process --id $processId
```

Pada Akta Jual Beli buka **Daftar Proses**. Badge awal **Belum Diinisialisasi**
netral. Gunakan **Inisialisasi proses**, periksa badge kuning **Belum Valid**,
tutup Flutter, lalu jalankan postcheck `initialized`. Launch ulang dan ubah
switch ke Valid. Gunakan **Simpan** dengan Catatan kosong, lalu periksa badge
hijau. Tutup Flutter dan jalankan postcheck `valid`. Launch ulang dengan ID
yang sama dan periksa badge hijau bertahan. Proses Balik Nama Sertifikat tetap
netral.

```powershell
python .\scripts\notaris-completion-acceptance.py postcheck --scenario ppat-process --id $processId --expect initialized
python .\scripts\notaris-completion-acceptance.py postcheck --scenario ppat-process --id $processId --expect valid
```

### Bukti dan cleanup

Postcheck membaca SQLite tanpa menulis. Untuk skenario utama, hanya status,
tiga field akta dan timestamp pembaruan detail Akta Jual Beli yang boleh
berbeda dari baseline. Header, detail kedua, proses, histori, pembayaran,
dirty flag dan tabel sinkronisasi ikut di-hash. Profil warna menilai histori
yang diharapkan secara terpisah. Review dan simpan output postcheck sebelum
cleanup. Gunakan hanya perintah untuk profil yang benar-benar dibuat.

```powershell
python .\scripts\notaris-completion-acceptance.py cleanup --scenario ppat --id $ppatId
python .\scripts\notaris-completion-acceptance.py cleanup --scenario ppat-optional --id $optionalId
python .\scripts\notaris-completion-acceptance.py cleanup --scenario ppat-process --id $processId
```
