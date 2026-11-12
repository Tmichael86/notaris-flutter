# Usulan Kontrak V1 Lampiran Transaksi

**Status usulan untuk persetujuan produk.** Baseline desain adalah `ee94b4d`,
Drift v24. Kelola Dokumen tetap nonaktif sampai implementasi dan acceptance
disetujui. Kontrak berlaku sama untuk Notaris dan PPAT.

## 1. Fakta Laravel dan keputusan baru

| Terverifikasi dari checkout Laravel | Usulan produk V1 |
| --- | --- |
| UI aktif memiliki Cetak Invoice dan Cetak Serah Terima. `cetakDokumen` tidak memiliki rantai lengkap dari UI hingga penyimpanan. | Lampiran berupa byte file yang diimpor ke penyimpanan lokal aplikasi. PDF hasil cetak, data Serah Terima, dan data akta tetap fitur terpisah. |
| Tidak ditemukan kepemilikan, versi, izin aksi, atau retensi lampiran transaksi. Validasi unggah gambar akun hanya berlaku untuk akun. | Kepemilikan transaksi dengan detail opsional, PDF/JPEG/PNG hingga 20 MiB per versi, izin per aksi, versi lama dipertahankan, dan arsip tanpa hapus permanen. |

Temuan dan rujukan kode Laravel ada pada [audit Slice 7](TRANSACTION_DOCUMENTS_AUDIT.md).

## 2. Entitas dan kepemilikan

- **Transaksi** memiliki nol atau lebih dokumen. Setiap dokumen memiliki tepat
  satu transaksi dan paling banyak satu `transaksi_details`. Detail wajib
  berada pada transaksi dan domain yang sama. Dokumen, kepemilikan, dan kaitan
  detail tetap sama sepanjang riwayat. Pemindahan dan berbagi lintas transaksi
  berada di luar V1.
- **Dokumen** beridentitas UUID yang dibuat aplikasi. **Versi** adalah satu
  salinan byte yang immutable dengan UUID versi sendiri. Versi 1 lahir saat
  impor. Replace menambah versi dan archive mengubah visibilitas dokumen.
- **Operasi lokal** mengikat percobaan dan hasil ke satu aksi, aktor, profil,
  transaksi, dan dokumen. Nomor transaksi, nama file, hash, dan path tidak
  menjadi bukti kepemilikan. Dua dokumen dengan hash sama tetap terpisah.
- Perintah membawa PK dan UUID lokal transaksi serta konteks domain. Repository
  mencocokkan ketiganya dengan DB profil aktif dan mencari dokumen di bawah
  transaksi tersebut, termasuk saat membuka versi lama. Detail opsional juga
  diverifikasi dengan PK dan UUID lokal. Aksi dari pilihan UI lama ditolak
  saat owner, detail, atau sesi telah berubah.
- Usulan untuk soft delete existing. Transaksi atau detail yang dihapus
  mempertahankan kaitan dan byte lampiran, tetapi dokumen terkait disembunyikan
  dan aksinya diblokir selama owner/detail nonaktif. Restore owner/detail lewat
  alur existing membuat dokumen yang masih aktif terlihat kembali. Arsip tetap
  diarsipkan. Penghapusan fisik atau penggantian identitas owner/detail harus
  ditolak selama masih direferensikan.

## 3. Usulan metadata Drift

Migrasi aditif yang diusulkan adalah v24 → v25. Nama di bawah adalah nama
tabel usulan. Waktu dicatat dalam UTC dan ditampilkan dalam waktu lokal.

| Tabel | Kolom utama dan batasan |
| --- | --- |
| `transaction_document_store` | Satu baris `id = 1` dengan `store_uuid` unik. Dibuat saat inisialisasi penyimpanan untuk DB yang sudah terverifikasi. UUID ini mengikat DB dan manifest direktori file. |
| `transaction_documents` | `document_uuid` PK, `transaksi_id` wajib FK, `transaksi_detail_id` opsional FK, `created_at/by`, `updated_at/by`, `archived_at/by` berpasangan dan awalnya NULL. Indeks `(transaksi_id, archived_at, created_at, document_uuid)` dan indeks untuk FK detail. |
| `transaction_document_versions` | `version_uuid` PK, `document_uuid` FK, `version_number >= 1`, `original_display_name`, `byte_size` dalam 1–20.971.520, `media_type` dari allowlist, `sha256` berbentuk 64 digit heksadesimal lowercase, `created_at/by`. `UNIQUE(document_uuid, version_number)`. Versi aktif adalah versi committed dengan nomor tertinggi. |
| `transaction_document_operations` | `operation_uuid` PK, `action`, `state`, `actor_user_id`, `actor_group_id`, `started_at`, `finished_at`, `transaksi_id`, `transaksi_detail_id` opsional, `document_uuid`, `version_uuid` bila berlaku, `expected_version` bila berlaku, metadata byte terverifikasi setelah staging, dan `error_code` tersanitasi bila gagal. Baris intent boleh menunjuk dokumen/versi yang belum dibuat. Setelah hasil terminal, baris menjadi bukti audit dan idempotency. Indeks `(state, started_at)`. |

FK memakai `RESTRICT` untuk data yang sudah committed. Periksa relasi detail
ke transaksi/domain dan immutability owner/versi di repository dan dengan
guard SQL terarah. `AppDatabase` mencatat bahwa koneksi lama tidak selalu
mengaktifkan FK global. Ikuti pola trigger terarah pada `_protectPengeluaranReferences`
agar insert/rekey/delete yang merusak hubungan tetap ditolak dengan FK OFF.
Jangan mengubah perilaku FK seluruh DB dalam slice ini. Record audit memakai ID
aktor yang berasal dari sesi terverifikasi pada profil, sehingga perubahan
nama akun tidak menulis ulang histori. Token, password, hash password, dan
path sumber tidak disimpan.

## 4. Direktori dan binding profil

Gunakan binding `AppDatabase` dari provider aktif. Lokasi daily default dan
profil development atau disposable berasal dari entrypoint yang sudah
memverifikasi profil masing-masing. Repository dokumen menerima binding itu
bersama root data profil yang terverifikasi. Profil tanpa binding eksplisit
gagal tertutup. Jangan mencari DB lain berdasarkan nama file.

Di bawah direktori lokal yang dikelola aplikasi untuk profil tersebut:

```text
transaction-documents/<store_uuid>/
  manifest.json                         # versi format dan binding profil/store
  staging/<operation_uuid>.part
  blobs/<version_uuid>.<ext>             # ext kanonis pdf, jpg, png
```

Root dan manifest harus cocok dengan DB dan konteks profil/deployment aktif.
Gunakan direktori privat pengguna Windows dan verifikasi ACL, lokasi lokal,
serta ketiadaan junction/symlink/reparse point di jalur managed. Verifikasi
ulang pada open, publish, dan recovery dengan primitif OS yang menjaga binding
selama operasi. Bila jaminan path atau atomic publish tidak bisa ditegakkan,
tolak aksi. UUID versi dan tipe terverifikasi membentuk path relatif secara
deterministik. Nama tampilan tidak pernah membentuk path managed. Salinan DB
untuk uji/restore memerlukan root terisolasi dan binding yang diverifikasi
secara eksplisit. Duplikat DB tidak boleh membuka store profil asal secara
otomatis.

## 5. Kontrak operasi dan izin

| Aksi | Syarat sesi | Hasil |
| --- | --- | --- |
| List dan inspect | Read `transaksi` | Daftar dokumen aktif pada owner yang diminta. Histori versi dan arsip melalui tampilan eksplisit. Metadata atau kondisi file ditampilkan sesuai bukti yang tersedia. |
| Open | Read `transaksi` | Buka versi yang dipilih atau versi terakhir, sesudah verifikasi owner, ukuran dan SHA-256 dari byte yang sama dengan yang diberikan ke viewer. Gunakan viewer yang disetujui, baca saja, dengan akses ke file managed melalui handle yang tervalidasi atau salinan baca terisolasi. |
| Export | Read `transaksi` | Salin byte versi terverifikasi ke tujuan lokal pilihan pengguna. Gunakan publish tanpa overwrite, termasuk saat tujuan muncul sesudah dialog. Tolak tujuan yang mengarah ke store aplikasi atau DB. Jangan meninggalkan file tujuan parsial yang terlihat berhasil. |
| Import | Read + Update `transaksi` | Salin file yang dipilih, validasi, lalu commit dokumen baru dan versi 1. Sumber tetap utuh. |
| Replace | Read + Update `transaksi` dan `groupType == 'superadmin'` terverifikasi | Tambah versi dengan nomor berikutnya hanya jika versi yang diharapkan masih aktif dan dokumen belum diarsipkan. Versi lama dan byte lama tetap tersedia. |
| Archive | Read + Update `transaksi` dan `groupType == 'superadmin'` terverifikasi | Commit perubahan `archived_at/by` dan audit. Gunakan versi yang diharapkan dan tolak perubahan bersamaan. File dan histori tetap tersedia pada tampilan arsip. |

Gunakan `AuthSession.hasTransactionAccess` untuk permission dan pola role
terverifikasi seperti koreksi pembayaran. Otorisasi ada di repository/service
melalui sesi yang dikelola provider, tanpa menerima role atau actor dari
form. Verifikasi konteks sesi pada awal dan sebelum commit atau penyerahan
byte. Pembaca tidak boleh menjalankan mutasi melalui pemanggilan repository
langsung. `AuthService` tetap menentukan kelayakan sesi offline dan penolakan
token. Sesi demo tetap mengikuti verifikasi, binding profil, dan expiry
existing. Aksi dokumen tidak melakukan panggilan jaringan untuk memperoleh
izin atau melonggarkan aturan sesi.

Pakai satu `operation_uuid` untuk retry aksi yang sama. Kecocokan profil,
aktor, target, jenis aksi, versi yang diharapkan, dan hash byte ketika tersedia
wajib diperiksa. Retry hasil committed mengembalikan hasil lama tanpa versi
baru. Pemakaian ulang ID dengan input berbeda ditolak. Gunakan single-flight
di UI dan cek konkurensi di service/DB. Pesan sukses hanya muncul setelah
commit terkonfirmasi. UI membedakan menunggu, gagal, file hilang, dan file
rusak. Tidak ada fallback otomatis ke dokumen lain atau versi lama.

## 6. Validasi, histori, dan retensi

- Allowlist PDF, JPG/JPEG dan PNG. Batas 20 MiB (20.971.520 byte) per versi
  diterapkan selama streaming terhadap byte yang disalin. File kosong, format
  lain, dan konten executable ditolak. Ekstensi harus cocok dengan tipe hasil
  validasi. MIME dari pemilih file dan magic bytes saja tidak cukup.
- Periksa signature dan struktur dengan parser/decoder yang dibatasi sumber
  dayanya. Tetapkan batas dimensi/decode gambar dan kompleksitas PDF sebelum
  implementasi. File rusak, ambigu, tidak dapat divalidasi, atau memerlukan
  password ditolak pada usulan V1. Usulan PDF hanya untuk dokumen pasif.
  Konten aktif atau attachment tertanam ditolak dan viewer tidak menjalankan
  skrip, aksi eksternal, atau membuka koneksi jaringan. Tipe file yang sah
  tetap diperlakukan sebagai input tidak tepercaya.
- Simpan nama asli sebagai teks tampilan. Saat render, escape karakter
  kontrol dan tampilkan nama panjang dengan truncation yang bisa diperluas.
  Saran nama ekspor harus disanitasi untuk Windows. Simpan ukuran aktual dan
  SHA-256 dari byte final yang diverifikasi. Nama sama tidak memicu overwrite
  atau deduplikasi lintas dokumen.
- Histori menampilkan versi, nama file pada versi itu, aktor dan waktu.
  Arsip mempertahankan seluruh versi, metadata, dan byte. V1 tidak menyediakan
  rename, restore arsip, hapus permanen, atau retensi otomatis. Jika disk
  penuh, laporkan kegagalan sebelum metadata dokumen dipublikasikan. Ruang
  penyimpanan perlu dimasukkan dalam backup profil.

## 7. Staging, commit, dan recovery

1. Validasi sesi, profil, owner, dan detail. Buat intent SQLite dengan ID
   operasi/dokumen/versi yang tetap pada retry. Serialisasi staging dan
   recovery dengan lock per store yang juga berlaku lintas proses. Buka file
   sumber yang dipilih secara eksplisit, sebagai file reguler, untuk baca.
2. Salin ke staging secara eksklusif. Validasi, hash, flush file, dan tutup
   handle. Simpan metadata byte terverifikasi pada intent. Tahap ini belum
   membuat versi terlihat oleh daftar dokumen.
3. Publikasikan staging ke nama akhir dengan rename atomik **tanpa overwrite**
   pada volume yang sama. Cek ukuran dan hash file final sebelum commit.
   Gunakan jaminan flush platform yang tersedia. Volume atau mekanisme yang
   tidak bisa memenuhi syarat publikasi ditolak.
4. Dalam satu transaksi Drift, validasi ulang sesi dan owner/detail, versi
   yang diharapkan, dan status arsip. Tulis dokumen/versi, audit, dan status
   `committed` intent. Archive memakai commit SQLite yang sama tanpa tahap
   file. Konflik atau kegagalan commit tidak mengubah versi sebelumnya.
5. Recovery memeriksa hasil dari intent dan metadata SQLite. Jika commit
   ambigu, baca state dengan koneksi yang sehat sebelum melaporkan hasil atau
   mengizinkan retry. Jika versi sudah committed, cek kembali byte dan
   laporkan kondisi aktual. Jika hanya ada stage/blob tanpa commit, tandai
   operasi terputus. Retry eksplisit dengan otorisasi yang masih sah boleh
   memakai byte terverifikasi dari intent yang sama, setelah memeriksa kembali
   hash, owner, dan versi yang diharapkan. Startup tidak menerbitkan versi
   secara otomatis. Byte mismatch atau intent tidak lengkap memerlukan review.

Status intent yang diusulkan adalah `staging`, `verified`, `interrupted`,
`committed`, dan `rejected`. `committed` dan `rejected` adalah hasil terminal.
`verified` menyimpan ukuran, tipe, dan hash sehingga recovery dapat mengenali
stage atau blob final tanpa bergantung pada catatan filesystem tambahan.
Status `interrupted` tidak menyatakan bahwa versi sudah committed.

SQLite dan filesystem tidak berbagi transaksi atomik. Listrik padam atau
kerusakan disk tetap bisa meninggalkan blob tanpa metadata, atau metadata
committed dengan blob hilang. Keduanya harus terdeteksi. Blob tanpa commit
tetap tidak terlihat dan dipertahankan untuk review. Cleanup otomatis hanya
boleh menyasar file `.part` yang jelas dimiliki operasi aktif yang sedang
membatalkan salinannya sendiri, dengan lock dan validasi path. File tak dikenal,
blob final, dan sisa operasi lama tidak dihapus otomatis. Backup yang dapat
dipulihkan memasangkan snapshot konsisten SQLite, manifest, dan semua blob
yang dirujuk di bawah maintenance lock. Uji restore pada profil terisolasi
dan periksa hash setiap versi yang dirujuk.

## 8. Batas offline dan cloud

Provider Drift dan Riverpod mengamati dokumen lokal saja. Mutasi dokumen
tidak menyentuh parent/child transaksi, dirty flag, revision, ACK, mutation
journal, cursor, pembayaran, akta, atau data Serah Terima. Tidak ada endpoint,
PostgreSQL, publisher, unggahan byte, atau path dalam payload cloud.

`TransactionHandoverRepository.cloudBlockReason` memberi preseden guard lokal
yang digunakan serializer dan readiness Upload. Usulan V1 memblokir Upload
transaksi yang punya dokumen committed, termasuk arsip, di kedua jalur agar
serialisasi aggregate tidak diam-diam menghilangkan lampiran. Mutasi dokumen
juga ditolak bila ada jurnal cloud yang belum selesai untuk owner itu. Pada
commit, cek jurnal di transaksi SQLite yang sama dengan mutasi dokumen.
Pembuatan jurnal Upload perlu mengecek dokumen di transaksi SQLite yang sama
dengan reservasi request, sehingga salah satu operasi menolak bila berlomba.
Saat replay masuk, pertahankan dokumen jika identitas owner/detail stabil. Tombstone
owner/detail mengikuti aturan visibilitas lokal. Bila apply akan memindahkan
atau memutus hubungan, gagal atomik tanpa memajukan cursor. Jangan mengubah
payload pending atau memicu Download untuk memperbaiki hubungan.

## 9. Threat model

| Risiko | Kontrol V1 |
| --- | --- |
| Tebak UUID, ganti transaksi/detail, atau pindah profil | Query selalu di bawah owner dan profil terikat. Sesi diverifikasi saat baca dan mutasi. Constraint hubungan dan larangan rekey melindungi metadata. |
| Traversal, UNC, junction, alternate data stream, dan race path Windows | Root terverifikasi lokal, nama blob kanonis, no-follow/handle yang tervalidasi, create eksklusif dan publish tanpa overwrite. Tolak path/device yang tidak dapat divalidasi. |
| File berbahaya atau resource exhaustion | Streaming dengan batas byte, validasi struktur yang dibatasi, viewer tanpa aksi aktif, dan error aman saat kapasitas habis. Tidak memakai shell command dengan nama input. |
| Double click, replace serentak, atau crash | Intent durable, ID idempotency, lock store, cek versi, transaksi SQLite, verifikasi byte, dan recovery non-destruktif. |
| Kebocoran lewat log, cache, atau ekspor | Log memakai ID operasi dan kode tersanitasi. Lindungi store dan salinan viewer dengan ACL. Ekspor membuat salinan terpisah dengan akses di luar kendali aplikasi. |

ACL profil membatasi akses aplikasi dan pengguna OS lain sesuai konfigurasi
host. Pengguna Windows yang sama atau administrator dengan akses disk dapat
membaca atau mengubah file. Hash mendeteksi perbedaan terhadap metadata yang
masih tepercaya. V1 tidak menyediakan enkripsi aplikasi atau bukti audit
tahan manipulasi oleh administrator lokal.

## 10. Acceptance dan urutan implementasi

| Fase setelah persetujuan | Bukti wajib pada fixture disposable |
| --- | --- |
| 1. Metadata dan guard | Fresh schema dan upgrade Drift v24 → v25 melalui migrasi existing. Fingerprint seluruh tabel lama, transaksi, child, pembayaran, dan sync state identik. Integrity OK dan FK 0. Coba FK OFF, detail lintas transaksi/domain, rekey, akses tanpa izin, sesi expired, dan lintas profil. |
| 2. Storage dan operasi | Uji PDF/JPEG/PNG valid, boundary 20 MiB, ekstensi palsu, corrupt, konten aktif, path Windows berbahaya, nama Unicode/panjang/duplikat, disk penuh, sumber tetap identik, serta hash byte. Injeksi kegagalan di setiap tahap, termasuk sebelum/sesudah rename dan commit ambigu. Uji retry, restart, replace serentak, arsip, file hilang, restore pasangan snapshot/blob, dan histori. |
| 3. UI dan acceptance Windows | Hubungkan aksi pada Dokumen & Catatan setelah fase sebelumnya lulus. Gunakan profil baru, satu transaksi per domain, operator Update, pembaca dan superadmin terverifikasi, serta sampel ber-hash. Verifikasi initial → import → open/export → replace/archive → restart. Periksa byte, izin, owner dan fingerprint data terlindungi setelah tiap fase. |
| 4. Readiness rollout | Regresi guard Upload dan replay, termasuk konflik detail dan tombstone. Dokumentasikan recovery, backup dan batas viewer. Rollout serta migrasi profil development asli memerlukan persetujuan terpisah. |

Reuse Drift `AppDatabase`, provider database dan sesi, serta pola repository
Transaksi dan Serah Terima. Tambahkan repository dokumen dan komponen storage
yang menerima binding profil dari wiring existing. Jangan menambahkan router,
mesin sync, atau mengganti shared shell. Fase desain saat ini hanya mengubah
dokumen ini. SQLite development asli, PostgreSQL, dan profil demo tidak dibuka.

## 11. Keputusan yang perlu disetujui produk

1. Setujui kepemilikan opsional per detail, visibilitas setelah soft delete
   owner/detail, serta akses read untuk histori versi dan arsip.
2. Setujui PDF pasif/JPEG/PNG hingga 20 MiB, penolakan PDF berpassword atau
   berfitur aktif, batas decoding, dan viewer Windows yang disetujui. Usulan
   tujuan ekspor dibatasi ke volume lokal, tanpa overwrite.
3. Setujui izin per aksi, replace/archive khusus superadmin dengan izin Update,
   dan retensi semua versi tanpa restore arsip atau hapus permanen di V1.
   Putuskan apakah kuota per profil diperlukan sebelum rollout.
4. Setujui blok Upload selama transaksi memiliki lampiran, termasuk arsip, dan
   kebijakan gagal tertutup saat replay akan memutus hubungan. Putuskan apakah
   cakupan fase pertama hanya profil demonstrasi atau profil lokal lainnya.
5. Setujui backup berpasangan dan proses review untuk blob yatim atau file
   hilang sebelum menentukan pengelola recovery. Storage ber-ACL tanpa
   enkripsi aplikasi perlu diterima sebagai batas proteksi V1.
