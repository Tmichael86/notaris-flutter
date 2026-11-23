# Acceptance Windows untuk penyelesaian Transaksi Notaris

Runner ini menyiapkan SQLite v21 baru di folder temp. Login demo berlangsung di
proses Flutter tanpa backend. Aplikasi memakai UI Transaksi dan permission
read/update yang sama dengan aplikasi biasa. Transport HTTP dan sync diblokir
di entrypoint demo. PostgreSQL, profil development dan profil harian tidak
dipakai untuk login maupun penyimpanan.

## Siapkan dan buka

Tutup semua jendela Flutter Notaris. Dari root repository, jalankan

```powershell
python .\scripts\notaris-completion-acceptance.py prepare
```

Simpan ID dari baris `PREPARED`. Gunakan ID yang sama untuk launch, restart,
postcheck dan cleanup. Prepare membuat profil baru setiap kali.

```powershell
$demoId = '<ID dari PREPARED>'
python .\scripts\notaris-completion-acceptance.py launch --id $demoId
```

Pastikan banner **PROFIL DEMONSTRASI** tampil. Login dengan `petugas.demo` dan
password fixture `Petugas-Akta-25211`. Kredensial ini hanya dikenali oleh
entrypoint demo lokal. Setiap restart memerlukan login kembali.

## Checklist

1. Buka **Transaksi → Notaris → Cari No. Transaksi**. Pilih
   `1001111260001` atas nama Bagas Pradipta untuk Pembuatan Akta Fidusia.
2. Buka langkah **Selesai Transaksi**. Pastikan status awal **Dalam Proses**
   dan field akta belum tampil. Catat proses **Pemeriksaan dokumen jaminan**
   dan satu pembayaran awal Rp500.000.
3. Pilih **Selesai**, biarkan semua field akta kosong, lalu klik **Simpan
   Perubahan**. Validasi harus tampil. Tutup Flutter dan jalankan postcheck
   `initial` untuk memeriksa bahwa status yang tersimpan masih **Dalam Proses**.
4. Launch ulang dengan ID yang sama. Pilih **Selesai**, isi **Fidusia** dan
   **25211**, lalu pilih **11 November 2026** pada kalender. Simpan. Buka kembali
   transaksi dan periksa status dan ketiga field.
5. Tutup Flutter, jalankan postcheck `complete`, lalu launch ulang dengan ID
   yang sama. Periksa kembali status dan data akta setelah restart.
6. Ubah status ke **Dalam Proses** dan simpan. Saat status itu aktif, field akta
   disembunyikan. Untuk memeriksa bahwa nilai lama masih ada, pilih **Selesai**
   sekali lagi dan lihat ketiga field terisi. Tinggalkan perubahan terakhir ini
   tanpa menyimpan. Periksa detail pekerjaan, proses dan pembayaran.
7. Pilih **PPAT → Cari No. Transaksi** dan buka `2001111260001` sebagai pembanding.
   Pilih **Selesai** pada langkah terakhir dan pastikan field akta header Notaris
   tidak muncul. Tutup tanpa menyimpan.
8. Tutup Flutter dan jalankan postcheck `reopened`.

## Postcheck dan cleanup

```powershell
python .\scripts\notaris-completion-acceptance.py postcheck --id $demoId --expect initial
python .\scripts\notaris-completion-acceptance.py postcheck --id $demoId --expect complete
python .\scripts\notaris-completion-acceptance.py postcheck --id $demoId --expect reopened
```

Jalankan satu perintah yang sesuai dengan langkah terakhir. Postcheck membaca
SQLite dengan koneksi read-only setelah Flutter ditutup. Ia memeriksa schema,
integrity dan FK, identitas serta nomor transaksi, nilai akta, dan fingerprint
detail, proses, pembayaran, PPAT, tabel lain serta state sinkronisasi. Ia juga
membandingkan ulang schema v20 dan SHA-256 file development asli. Bukti tanpa
write PostgreSQL berasal dari profil lokal yang tidak memiliki koneksi backend.

Setelah hasil ditinjau, perintah ini menghapus hanya berkas milik profil temp
yang ID dan marker-nya cocok. Simpan output postcheck lebih dahulu bila diperlukan.

```powershell
python .\scripts\notaris-completion-acceptance.py cleanup --id $demoId
```
