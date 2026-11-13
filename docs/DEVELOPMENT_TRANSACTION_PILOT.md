# Pilot CREATE Transaksi Notaris development

Check read-only 9 November 2026 mengonfirmasi `E2E-TX-e4d625c2-NOTARIS` (`19566301-0540-4e1a-8b17-948bc3dec96e`), revision 1, publication sequence 6. Harga `ef324a08-d51f-49ea-b4f9-08a0c8305d96` Rp100.000 dan kategori `fa000002-0000-4000-8000-000000000001` cocok dengan payload published. Master aktif `Synthetic Notarial Job` belum published sehingga tidak dipakai. Pemohon cloud `fa000001-0000-4000-8000-000000000001` dan mapping Petugas server 101 revision 1 tersedia di profil lokal. Akun 2001/group 11 aktif dengan izin read Master dan read/create Transaksi di database.

## Check

Tutup Flutter. Dari root repository jalankan `./scripts/check-notarisdev-transaction-pilot.ps1 -Stage Check`. Bila tersedia salinan SQLite v19 terkini, tambahkan `-Backup './.local/<folder>/<backup>.sqlite'`. Check memvalidasi target dan marker PostgreSQL, izin, replay metadata Master sequence 1–6, kategori dan collision UUID lokal, scope Petugas, ketiadaan binding/mutation Master dan Transaksi, serta integritas dan fingerprint SQLite. Pembacaan PostgreSQL memakai transaksi read-only. Pembacaan SQLite memakai `mode=ro` dan `query_only`.

Salinan `migration-check.sqlite` dari acceptance Recycle Bin berbeda dari SQLite development sekarang. Backup terkini dibuat lewat SQLite Backup API dengan sumber read-only dan cocok secara logis. Receipt lokal tersedia di `.local/development-transaction-pilot-backup.json`. Ulangi Check dengan path `backup` pada receipt sebelum apply lokal. Bila sumber berubah, buat backup terkini lagi. Verifikasi juga backup recovery PostgreSQL sebelum Upload. Check SQL membuktikan target PostgreSQL dan permission tersimpan. Attestation HTTP dari proses backend yang nanti dipakai masih perlu dibuktikan dengan sesi terautentikasi dan hash plan pilot.

## Satu rencana eksekusi

1. Setelah approval tahap lokal, pin profil canonical `notarisdev/<generation>/offline.sqlite`, account 2001, group 11, deployment `NOTARISDEV SYNTHETIC v1`, generation `14af5452144b42d0be2ad88bac41b656`, dan device existing `ndpetugas-b49369a4fdaf38d731905f080cddc68c`. Pertahankan scope Petugas baseline lama secara persis. Gunakan scope Master dan Transaksi dari format `TransactionManualProfile.scope` dengan suffix `/masters` dan `/transactions`. Factory development harus memvalidasi scope Petugas lama secara terpisah, karena formatnya berbeda dari profil disposable.
2. Gunakan GET autentik `pekerjaan-notaris/sync/pull` dan `PekerjaanNotarisCloudRepository.pullPage` dari cursor awal 0 hingga 6. Replay keenam event berurutan, termasuk tombstone historis, karena importer menerapkan revision dan cursor bersama. Batasi replay ke snapshot yang direview dan stop jika event berubah. Import menambah identity Master cloud dengan UUID aslinya. Perubahan revision/tombstone replay hanya mengenai Master yang baru diterima. Check memeriksa UUID parent, harga, proses, atribut, dan kategori sebelum tahap ini. Jangan set cursor langsung ke 5 atau menautkan Master lama menurut nama/ID. Bandingkan fingerprint ketiga transaksi lama dan child sebelum/sesudah.
3. Simpan satu draft Notaris `PILOT-DEV-NOTARIS-01` lewat alur save existing. Pilih Pemohon, Petugas, Master, harga, dan kategori sesuai [resep pilot](../scripts/plans/notarisdev-transaction-pilot.json). Gunakan status Baru, satu pekerjaan Rp100.000, diskon/biaya lain/materai dan pembayaran awal nol. Gunakan snapshot proses Master tanpa transisi actor. Alur save mengalokasikan UUID baru. Catat UUID tersebut dan snapshot payload, jalankan Check eligibility service, serta pastikan server belum punya parent/receipt/outbox untuk UUID itu. Review draft sebelum meminta approval Upload.
4. Factory development menggunakan mode pilot terpisah pada launcher dan guard acceptance. Setelah approval checkpoint, launcher membuat dan memeriksa recovery archive PostgreSQL dari target yang diattest, lalu membuka Pusat Sinkronisasi existing. Guard mengikat `POST /api/v1/transaksi-notaris/sync/create` ke satu UUID, mutation ID, dan SHA-256 payload checkpoint, expected revision 0, satu detail, serta pembayaran nol. Endpoint attestation memeriksa target, role, izin, referensi, dan baseline shared feed 8, termasuk ketiadaan receipt/aggregate/outbox pilot. Mode acceptance empat event dan kontrak shared Download existing tetap tersedia pada profilnya.
5. Batasi write server pada satu aggregate CREATE beserta child snapshot, satu alokasi nomor, satu receipt dan satu outbox pending. Simpan ACK lokal lewat repository existing. Verifikasi revision 1, receipt, dan outbox. Publication memerlukan tahap tersendiri sehingga cursor server tetap 8 pada pilot CREATE. Jika hasil ambigu, periksa receipt/outbox secara read-only sebelum mengambil keputusan lebih lanjut.

Approval tahap lokal mencakup apply replay Master dan binding di SQLite serta save satu draft baru setelah backup diverifikasi. Approval Upload diberikan terpisah setelah UUID dan payload aktual bisa ditinjau. Recipe dan keluaran Check adalah bahan review. Eksekusi HTTP development tetap terkunci dan UI Smoke tetap menolak HTTP sync.

## Launcher tahap lokal

Tutup Flutter development dan kosongkan port HTTP 8081. PostgreSQL development tetap tersedia. Dari root repository:

```powershell
.\scripts\run-notarisdev-transaction-pilot.ps1 -Stage Check
```

Review `LOCAL_BOOTSTRAP_REVIEW_SHA256` dan receipt Check. Approval tahap ini hanya mencakup replay enam event Master, scope lokal, satu draft dan satu mutation `pending`. Setelah approval hash tersebut:

```powershell
.\scripts\run-notarisdev-transaction-pilot.ps1 -Stage LocalBootstrap -ApprovedSha256 '<SHA-256 Check yang disetujui>'
```

Launcher memakai backend loopback yang dimilikinya. Setelah attestation, transaksi SQLite tunggal mengikat cursor Master dan menyimpan draft beserta payload beku melalui repository existing. Receipt `development-transaction-pilot-checkpoint.json` ditulis setelah COMMIT. Receipt memuat UUID, mutation ID, hash payload, scope, identity kosong, dan state `pending`. Tahap ini selesai tanpa mengirim mutation bisnis.

Jika ada attempt lock, `Check` memeriksa SQLite secara read-only. `CHECKPOINT_PRESENT_PENDING` menunjukkan receipt cocok dengan jurnal lokal. `BOOTSTRAP_OUTCOME_REVIEW_REQUIRED` berarti hasil perlu diperiksa sebelum mengambil tindakan lain. `UPLOAD_ATTEMPTED_REVIEW_REQUIRED` berarti periksa receipt/outbox PostgreSQL untuk UUID itu meskipun ACK lokal belum terlihat. Pertahankan lock dan jurnal untuk audit. Tidak ada retry atau restore otomatis.
