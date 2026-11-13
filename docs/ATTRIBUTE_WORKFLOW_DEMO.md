# P0 validasi atribut Notaris

Slice ini dijalankan pada profil demo Windows debug. Launcher membuat cluster PostgreSQL loopback port 55671 dan database `attribute_demo_<id>` dengan marker disposable. API demo port 56781 memverifikasi identitas sesi sebelum Flutter membuka SQLite temporary miliknya. Drift tetap v20. Shared Transaction feed, revision aggregate, ACK, cursor, dan publisher tidak terlibat.

Fixture fiktif memakai Pemohon Bagas Pradipta, petugas Dimas Prasetyo, validator Nabila Putri, pekerjaan Legalisasi Dokumen, proses Pemeriksaan Berkas, dan atribut teks Catatan Pemeriksaan Identitas. NIK ditandai tidak valid. SQLite memakai Master dan jalur save transaksi existing. UUID fixture ditetapkan pada saat provisioning dan tidak diklaim sebagai ACK sync.

## Jalankan demo

1. Dari root repository jalankan `.\scripts\run-attribute-workflow-demo.ps1` di Terminal 1. Tentukan dua password demo berbeda melalui prompt tersembunyi. Pertahankan terminal sampai pengujian selesai. Catat ID setelah `ATTRIBUTE_DEMO_READY`.
2. Dari `frontend_notaris` di Terminal 2 jalankan `flutter run -d windows --debug -t lib/attribute_workflow_demo_main.dart --dart-define=ATTRIBUTE_DEMO_ID=<ID>` dengan ID dari Terminal 1. Verifikasi banner **PROFIL DEMONSTRASI**.
3. Login `demo.dimas`. Buka Transaksi Notaris melalui Cari No. Transaksi `1001011260001`. Buka proses Legalisasi Dokumen lalu **Validasi atribut**. Pilih **Inisialisasi workflow**. Isi nilai teks, simpan draft lokal, lalu ajukan. Status menjadi **Menunggu Konfirmasi** setelah server mengonfirmasi.
4. Logout, login `demo.nabila`, dan buka bel Notifikasi. Buka pengajuan yang belum dibaca, isi alasan, lalu **Minta revisi**. Buka kembali inbox untuk memeriksa indikator dibaca.
5. Login Dimas. Buka notifikasi revisi, simpan nilai revisi, dan ajukan ulang. Login Nabila dan nyatakan versi kedua **Valid**. Login Dimas untuk memeriksa dua hasil dan histori dua versi. Status Transaksi tetap **Baru**.
6. Untuk restart Flutter, pertahankan Terminal 1 dan gunakan ID yang sama. Setelah selesai, tutup Flutter dan tekan Ctrl+C pada Terminal 1. Folder bukti cluster tetap tersedia di `.local`.

Untuk pengujian disposable noninteraktif jalankan `.\scripts\run-attribute-workflow-demo.ps1 -Test`. Profil biasa tidak mendaftarkan API workflow. Pendaftaran definisi dan keanggotaan kantor masih melalui provisioning fixture. Operasi server membutuhkan sesi aktif. Draft lokal dan perintah yang belum terkonfirmasi disimpan per profil, akun, dan proses pada secure storage Flutter.
