# 📋 Database Structure - Sistem Notaris Blitaris

> Dokumentasi ini dihasilkan dari seluruh file migrasi di `database/migrations/`
> Total: **35 file migrasi** → menghasilkan **~30 tabel** di database

---

## 📊 Ringkasan Tabel

| No | Nama Tabel | Kategori | Keterangan |
|----|-----------|----------|------------|
| 1 | `users` | 👤 User & Akses | Akun pengguna sistem |
| 2 | `petugas` | 👤 User & Akses | Data petugas notaris/PPAT |
| 3 | `pemohon` | 👤 User & Akses | Data pemohon layanan |
| 4 | `groups` | 👤 User & Akses | Grup pengguna (role) |
| 5 | `password_resets` | 👤 User & Akses | Reset password |
| 6 | `sessions` | 👤 User & Akses | Sesi user aktif |
| 7 | `sidebar` | 🔲 Akses & Menu | Menu sidebar navigasi |
| 8 | `sidebar_akses` | 🔲 Akses & Menu | Hak akses sidebar per grup |
| 9 | `personal_access_tokens` | 🔲 Akses & Menu | Token API (Sanctum) |
| 10 | `failed_jobs` | 🔲 Akses & Menu | Job yang gagal |
| 11 | `pekerjaan_jenis` | 💼 Pekerjaan | Jenis pekerjaan |
| 12 | `pekerjaan_notaris` | 💼 Pekerjaan | Daftar pekerjaan notaris |
| 13 | `pekerjaan_ppat` | 💼 Pekerjaan | Daftar pekerjaan PPAT |
| 14 | `pekerjaan_notaris_proses` | 💼 Pekerjaan | Proses alur kerja notaris |
| 15 | `pekerjaan_ppat_proses` | 💼 Pekerjaan | Proses alur kerja PPAT |
| 16 | `pekerjaan_notaris_harga` | 💼 Pekerjaan | Harga pekerjaan notaris |
| 17 | `pekerjaan_ppat_harga` | 💼 Pekerjaan | Harga pekerjaan PPAT |
| 18 | `pekerjaan_notaris_atributs` | 💼 Pekerjaan | Atribut tambahan pekerjaan notaris |
| 19 | `pekerjaan_ppat_atributs` | 💼 Pekerjaan | Atribut tambahan pekerjaan PPAT |
| 20 | `pekerjaan_kategori` | 💼 Pekerjaan | Kategori pekerjaan |
| 21 | `transaksi` | 💰 Transaksi | Data transaksi utama (akta) |
| 22 | `transaksi_status` | 💰 Transaksi | Status transaksi |
| 23 | `transaksi_riwayat_pembayaran` | 💰 Transaksi | Riwayat pembayaran transaksi |
| 24 | `transaksi_detail_proses` | 💰 Transaksi | Detail proses per transaksi |
| 25 | `transaksi_materai` | 💰 Transaksi | Relasi transaksi ↔ materai |
| 26 | `transaksi_cetak_serah_terima` | 💰 Transaksi | Cetak serah terima transaksi |
| 27 | `materais` | 📌 Materai | Stok & pencatatan materai |
| 28 | `pengeluaran` | 📊 Keuangan | Data pengeluaran |
| 29 | `pengeluaran_jenis` | 📊 Keuangan | Jenis pengeluaran |
| 30 | `pembayaran_jenis` | 📊 Keuangan | Jenis pembayaran |
| 31 | `pendapatan` | 📊 Keuangan | Laporan pendapatan |
| 32 | `jenis_kelamin` | 📋 Master Data | Referensi jenis kelamin |
| 33 | `jenis_pajak` | 📋 Master Data | Referensi jenis pajak |
| 34 | `konfigurasi_umum` | ⚙️ Konfigurasi | Pengaturan umum aplikasi |

---

## 👤 1. USER & AKSES

### 1.1 Tabel `users`

Tabel utama untuk akun pengguna sistem.

| Kolom | Tipe | Nullable | Keterangan |
|-------|------|----------|------------|
| `id` | bigint (PK) | ❌ | Auto increment ID |
| `group_id` | integer | ❌ | Foreign key → `groups.id` |
| `username` | string | ❌ | Username login |
| `password` | string | ❌ | Password (hashed) |
| `email` | string | ❌ | Email pengguna |
| `nama` | string | ❌ | Nama lengkap |
| `no_telp` | string | ✅ | Nomor telepon |
| `alamat` | string | ✅ | Alamat rumah |
| `image` | string | ✅ | Path foto profil |
| `created_by` | integer | ✅ | ID user pembuat |
| `updated_by` | integer | ✅ | ID user pengubah |
| `created_at` | timestamp | ✅ | Waktu pembuatan |
| `updated_at` | timestamp | ✅ | Waktu update terakhir |
| `status` | smallInteger | ❌ | Status aktif/nonaktif |

---

### 1.2 Tabel `petugas`

Data petugas notaris/PPAT yang menangani pekerjaan.

| Kolom | Tipe | Nullable | Keterangan |
|-------|------|----------|------------|
| `id` | bigint (PK) | ❌ | Auto increment ID |
| `nik` | string | ✅ | Nomor Induk Kependudukan |
| `nama` | string | ❌ | Nama petugas |
| `alamat` | string | ✅ | Alamat petugas |
| `tempat_lahir` | string | ✅ | Tempat lahir |
| `tanggal_lahir` | date | ✅ | Tanggal lahir |
| `jenis_kelamin` | integer | ✅ | Foreign key → `jenis_kelamin.id` |
| `no_telp` | string | ✅ | Nomor telepon |
| `email` | string | ❌ | Email petugas |
| `user_id` | integer | ✅ | Foreign key → `users.id` (akun terkait) |
| `created_by` | integer | ✅ | ID user pembuat |
| `updated_by` | integer | ✅ | ID user pengubah |
| `created_at` | timestamp | ✅ | Waktu pembuatan |
| `updated_at` | timestamp | ✅ | Waktu update terakhir |
| `status` | smallInteger | ❌ | Status aktif/nonaktif |

> **Catatan:** Tabel ini memiliki relasi ke `users` (via `user_id`) dan `jenis_kelamin` (via `jenis_kelamin`).

---

### 1.3 Tabel `pemohon`

Data pemohon yang menggunakan layanan notaris/PPAT.

| Kolom | Tipe | Nullable | Keterangan |
|-------|------|----------|------------|
| `id` | bigint (PK) | ❌ | Auto increment ID |
| `nama` | string | ❌ | Nama pemohon |
| `alamat` | string | ✅ | Alamat pemohon |
| `jenis_kelamin` | integer | ✅ | Foreign key → `jenis_kelamin.id` |
| `no_telp` | string | ✅ | Nomor telepon |
| `nik` | string | ✅ | Nomor Induk Kependudukan |
| `created_by` | integer | ✅ | ID user pembuat |
| `updated_by` | integer | ✅ | ID user pengubah |
| `created_at` | timestamp | ✅ | Waktu pembuatan |
| `updated_at` | timestamp | ✅ | Waktu update terakhir |
| `status` | smallInteger | ❌ | Status aktif/nonaktif |

---

### 1.4 Tabel `groups`

Grup/role pengguna untuk kontrol akses.

| Kolom | Tipe | Nullable | Default | Keterangan |
|-------|------|----------|---------|------------|
| `id` | bigint (PK) | ❌ | - | Auto increment ID |
| `group_nama` | string | ❌ | - | Nama grup |
| `group_jenis` | enum | ❌ | `'user'` | Jenis: `superadmin` atau `user` |
| `created_by` | integer | ✅ | - | ID user pembuat |
| `updated_by` | integer | ✅ | - | ID user pengubah |
| `created_at` | timestamp | ✅ | - | Waktu pembuatan |
| `updated_at` | timestamp | ✅ | - | Waktu update terakhir |
| `status` | smallInteger | ❌ | - | Status aktif/nonaktif |

---

### 1.5 Tabel `password_resets`

Tabel untuk menyimpan token reset password.

| Kolom | Tipe | Nullable | Keterangan |
|-------|------|----------|------------|
| `email` | string (PK) | ❌ | Email yang minta reset |
| `token` | string | ❌ | Token reset password |
| `created_at` | timestamp | ✅ | Waktu token dibuat |

---

### 1.6 Tabel `sessions`

Menyimpan data sesi user yang sedang login.

| Kolom | Tipe | Nullable | Keterangan |
|-------|------|----------|------------|
| `id` | string (PK) | ❌ | Session ID |
| `user_id` | bigint (FK) | ✅ | Foreign key → `users.id` (indexed) |
| `ip_address` | string(45) | ✅ | IP address pengguna |
| `user_agent` | text | ✅ | Informasi browser/device |
| `payload` | longText | ❌ | Data sesi (serialized) |
| `last_activity` | integer | ❌ | Timestamp aktivitas terakhir (indexed) |

---

## 🔲 2. AKSES & MENU

### 2.1 Tabel `sidebar`

Menu navigasi sidebar aplikasi.

| Kolom | Tipe | Nullable | Keterangan |
|-------|------|----------|------------|
| `id` | bigint (PK) | ❌ | Auto increment ID |
| `sidebar_parent_id` | integer | ✅ | ID parent (0 = root) — hierarki menu |
| `sidebar_nama` | string | ❌ | Nama tampilan menu |
| `sidebar_route` | string | ❌ | Route/path URL |
| `sidebar_kode` | string | ❌ | Kode unik menu |
| `sidebar_icon` | string | ❌ | Icon (class icon library) |
| `sidebar_index` | mediumInteger | ❌ | Urutan tampilan menu |
| `created_by` | integer | ✅ | ID user pembuat |
| `updated_by` | integer | ✅ | ID user pengubah |
| `created_at` | timestamp | ✅ | Waktu pembuatan |
| `updated_at` | timestamp | ✅ | Waktu update terakhir |
| `status` | smallInteger | ❌ | Status aktif/nonaktif |

> **Catatan:** Mendukung struktur hierarki via `sidebar_parent_id`.

---

### 2.2 Tabel `sidebar_akses`

Hak akses CRUD per menu untuk setiap grup.

| Kolom | Tipe | Nullable | Keterangan |
|-------|------|----------|------------|
| `id` | bigint (PK) | ❌ | Auto increment ID |
| `sidebar_id` | integer | ❌ | Foreign key → `sidebar.id` |
| `group_id` | integer | ❌ | Foreign key → `groups.id` |
| `read` | smallInteger | ❌ | 1 = boleh lihat, 0 = tidak |
| `create` | smallInteger | ❌ | 1 = boleh buat, 0 = tidak |
| `update` | smallInteger | ❌ | 1 = boleh edit, 0 = tidak |
| `delete` | smallInteger | ❌ | 1 = boleh hapus, 0 = tidak |
| `created_by` | integer | ✅ | ID user pembuat |
| `updated_by` | integer | ✅ | ID user pengubah |
| `created_at` | timestamp | ✅ | Waktu pembuatan |
| `updated_at` | timestamp | ✅ | Waktu update terakhir |

> **Catatan:** Tabel pivot antara `sidebar` dan `groups` dengan flag CRUD.

---

### 2.3 Tabel `personal_access_tokens`

Token API untuk autentikasi (Laravel Sanctum).

| Kolom | Tipe | Nullable | Keterangan |
|-------|------|----------|------------|
| `id` | bigint (PK) | ❌ | Auto increment ID |
| `tokenable_type` | string | ❌ | Tipe model (polymorphic) |
| `tokenable_id` | bigint | ❌ | ID model (polymorphic) |
| `name` | string | ❌ | Nama token |
| `token` | string(64) | ❌ | Token hash (unique) |
| `abilities` | text | ✅ | Izin/abilitas token |
| `last_used_at` | timestamp | ✅ | Terakhir digunakan |
| `expires_at` | timestamp | ✅ | Waktu kadaluarsa |
| `created_at` | timestamp | ✅ | Waktu pembuatan |
| `updated_at` | timestamp | ✅ | Waktu update terakhir |

---

### 2.4 Tabel `failed_jobs`

Logging job yang gagal dieksekusi.

| Kolom | Tipe | Nullable | Keterangan |
|-------|------|----------|------------|
| `id` | bigint (PK) | ❌ | Auto increment ID |
| `uuid` | string | ❌ | UUID unik (unique) |
| `connection` | text | ❌ | Nama koneksi queue |
| `queue` | text | ❌ | Nama queue |
| `payload` | longText | ❌ | Data job |
| `exception` | longText | ❌ | Pesan error |
| `failed_at` | timestamp | ❌ | Waktu gagal (default: now) |

---

## 💼 3. PEKERJAAN

### 3.1 Tabel `pekerjaan_jenis`

Jenis umum pekerjaan (Notaris atau PPAT).

| Kolom | Tipe | Nullable | Keterangan |
|-------|------|----------|------------|
| `id` | bigint (PK) | ❌ | Auto increment ID |
| `nama` | string | ❌ | Nama jenis pekerjaan |
| `created_by` | integer | ✅ | ID user pembuat |
| `updated_by` | integer | ✅ | ID user pengubah |
| `created_at` | timestamp | ✅ | Waktu pembuatan |
| `updated_at` | timestamp | ✅ | Waktu update terakhir |
| `status` | smallInteger | ❌ | Status aktif/nonaktif |

---

### 3.2 Tabel `pekerjaan_notaris`

Daftar pekerjaan notaris yang tersedia.

| Kolom | Tipe | Nullable | Keterangan |
|-------|------|----------|------------|
| `id` | bigint (PK) | ❌ | Auto increment ID |
| `nama` | string | ❌ | Nama pekerjaan notaris |
| `created_by` | integer | ✅ | ID user pembuat |
| `updated_by` | integer | ✅ | ID user pengubah |
| `created_at` | timestamp | ✅ | Waktu pembuatan |
| `updated_at` | timestamp | ✅ | Waktu update terakhir |
| `status` | smallInteger | ❌ | Status aktif/nonaktif |

---

### 3.3 Tabel `pekerjaan_ppat`

Daftar pekerjaan PPAT yang tersedia.

| Kolom | Tipe | Nullable | Keterangan |
|-------|------|----------|------------|
| `id` | bigint (PK) | ❌ | Auto increment ID |
| `nama` | string | ❌ | Nama pekerjaan PPAT |
| `created_by` | integer | ✅ | ID user pembuat |
| `updated_by` | integer | ✅ | ID user pengubah |
| `created_at` | timestamp | ✅ | Waktu pembuatan |
| `updated_at` | timestamp | ✅ | Waktu update terakhir |
| `status` | smallInteger | ❌ | Status aktif/nonaktif |

---

### 3.4 Tabel `pekerjaan_notaris_proses`

Alur proses/ tahapan untuk pekerjaan notaris.

| Kolom | Tipe | Nullable | Keterangan |
|-------|------|----------|------------|
| `id` | bigint (PK) | ❌ | Auto increment ID |
| `pekerjaan_notaris_id` | unsignedInteger | ❌ | Foreign key → `pekerjaan_notaris.id` |
| `nama` | string | ❌ | Nama tahapan proses |
| `detail` | text | ❌ | Deskripsi detail proses |
| `created_by` | integer | ✅ | ID user pembuat |
| `updated_by` | integer | ✅ | ID user pengubah |
| `created_at` | timestamp | ✅ | Waktu pembuatan |
| `updated_at` | timestamp | ✅ | Waktu update terakhir |
| `status` | smallInteger | ❌ | Status aktif/nonaktif |

---

### 3.5 Tabel `pekerjaan_ppat_proses`

Alur proses/tahapan untuk pekerjaan PPAT.

| Kolom | Tipe | Nullable | Keterangan |
|-------|------|----------|------------|
| `id` | bigint (PK) | ❌ | Auto increment ID |
| `pekerjaan_ppat_id` | unsignedInteger | ❌ | Foreign key → `pekerjaan_ppat.id` |
| `nama` | string | ❌ | Nama tahapan proses |
| `detail` | text | ❌ | Deskripsi detail proses |
| `created_by` | integer | ✅ | ID user pembuat |
| `updated_by` | integer | ✅ | ID user pengubah |
| `created_at` | timestamp | ✅ | Waktu pembuatan |
| `updated_at` | timestamp | ✅ | Waktu update terakhir |
| `status` | smallInteger | ❌ | Status aktif/nonaktif |

---

### 3.6 Tabel `pekerjaan_notaris_harga`

Harga satuan untuk pekerjaan notaris.

| Kolom | Tipe | Nullable | Keterangan |
|-------|------|----------|------------|
| `id` | bigint (PK) | ❌ | Auto increment ID |
| `pekerjaan_notaris_id` | integer | ❌ | Foreign key → `pekerjaan_notaris.id` |
| `harga` | string | ❌ | Harga layanan |
| `kategori_pekerjaan_id` | integer | ❌ | Foreign key → `pekerjaan_kategori.id` |
| `estimasi_waktu` | string | ❌ | Estimasi waktu pengerjaan |
| `created_by` | integer | ✅ | ID user pembuat |
| `updated_by` | integer | ✅ | ID user pengubah |
| `created_at` | timestamp | ✅ | Waktu pembuatan |
| `updated_at` | timestamp | ✅ | Waktu update terakhir |
| `status` | smallInteger | ❌ | Status aktif/nonaktif |

---

### 3.7 Tabel `pekerjaan_ppat_harga`

Harga satuan untuk pekerjaan PPAT.

| Kolom | Tipe | Nullable | Keterangan |
|-------|------|----------|------------|
| `id` | bigint (PK) | ❌ | Auto increment ID |
| `pekerjaan_ppat_id` | integer | ❌ | Foreign key → `pekerjaan_ppat.id` |
| `harga` | string | ❌ | Harga layanan |
| `kategori_pekerjaan_id` | integer | ❌ | Foreign key → `pekerjaan_kategori.id` |
| `estimasi_waktu` | string | ❌ | Estimasi waktu pengerjaan |
| `created_by` | integer | ✅ | ID user pembuat |
| `updated_by` | integer | ✅ | ID user pengubah |
| `created_at` | timestamp | ✅ | Waktu pembuatan |
| `updated_at` | timestamp | ✅ | Waktu update terakhir |
| `status` | smallInteger | ❌ | Status aktif/nonaktif |

---

### 3.8 Tabel `pekerjaan_notaris_atributs`

Atribut/form tambahan untuk pekerjaan notaris per tahapan.

| Kolom | Tipe | Nullable | Keterangan |
|-------|------|----------|------------|
| `id` | bigint (PK) | ❌ | Auto increment ID |
| `pekerjaan_notaris_id` | foreignId | ❌ | Foreign key → `pekerjaan_notaris.id` |
| `proses_pekerjaan_notaris_id` | foreignId | ❌ | Foreign key → `pekerjaan_notaris_proses.id` |
| `atribut` | string | ✅ | Nama atribut form |
| `created_by` | integer | ✅ | ID user pembuat |
| `updated_by` | integer | ✅ | ID user pengubah |
| `created_at` | timestamp | ✅ | Waktu pembuatan |
| `updated_at` | timestamp | ✅ | Waktu update terakhir |
| `status` | smallInteger | ❌ | Status aktif/nonaktif |

---

### 3.9 Tabel `pekerjaan_ppat_atributs`

Atribut/form tambahan untuk pekerjaan PPAT per tahapan.

| Kolom | Tipe | Nullable | Keterangan |
|-------|------|----------|------------|
| `id` | bigint (PK) | ❌ | Auto increment ID |
| `pekerjaan_ppat_id` | foreignId | ❌ | Foreign key → `pekerjaan_ppat.id` |
| `proses_pekerjaan_ppat_id` | foreignId | ❌ | Foreign key → `pekerjaan_ppat_proses.id` |
| `atribut` | string | ✅ | Nama atribut form |
| `created_by` | integer | ✅ | ID user pembuat |
| `updated_by` | integer | ✅ | ID user pengubah |
| `created_at` | timestamp | ✅ | Waktu pembuatan |
| `updated_at` | timestamp | ✅ | Waktu update terakhir |
| `status` | smallInteger | ❌ | Status aktif/nonaktif |

---

### 3.10 Tabel `pekerjaan_kategori`

Kategori pekerjaan untuk pengelompokan harga.

| Kolom | Tipe | Nullable | Keterangan |
|-------|------|----------|------------|
| `id` | bigint (PK) | ❌ | Auto increment ID |
| `nama` | string | ❌ | Nama kategori |
| `created_by` | integer | ✅ | ID user pembuat |
| `updated_by` | integer | ✅ | ID user pengubah |
| `created_at` | timestamp | ✅ | Waktu pembuatan |
| `updated_at` | timestamp | ✅ | Waktu update terakhir |
| `status` | smallInteger | ❌ | Status aktif/nonaktif |

---

## 💰 4. TRANSAKSI

### 4.1 Tabel `transaksi` ⭐ (Tabel Inti)

Tabel utama pencatatan transaksi/akta notaris.

| Kolom | Tipe | Nullable | Keterangan |
|-------|------|----------|------------|
| `id` | bigint (PK) | ❌ | Auto increment ID |
| `no_akta` | string | ❌ | Nomor akta |
| `tanggal_daftar` | date | ❌ | Tanggal pendaftaran |
| `tanggal_selesai` | date | ❌ | Tanggal selesai |
| `jatuh_tempo` | date | ❌ | Jatuh tempo |
| `keterangan` | text | ✅ | Keterangan umum |
| **— Biaya —** | | | |
| `biaya_layanan` | unsignedBigInteger | ❌ | Biaya layanan |
| `biaya_lainnya` | unsignedBigInteger | ❌ | Biaya lain-lain |
| `petugas_id` | integer | ❌ | Foreign key → `petugas.id` |
| `sub_total` | string | ❌ | Sub total biaya |
| `potongan_biaya` | string | ❌ | Diskon/potongan |
| `total` | unsignedBigInteger | ❌ | Total biaya |
| **— Pajak —** | | | |
| `acuan_hitung_pajak` | unsignedInteger | ✅ | Dasar pengenaan pajak |
| `nilai_pengurang` | unsignedInteger | ✅ | Nilai pengurang pajak |
| `besaran_pajak_pihak_pertama` | unsignedInteger | ✅ | Pajak ditanggung pihak pertama |
| `besaran_pajak_pihak_kedua` | unsignedInteger | ✅ | Pajak ditanggung pihak kedua |
| **— Tidak Kena Pajak —** | | | |
| `besaran_nilai_tidak_kena_pajak` | unsignedBigInteger | ✅ | Besaran nilai tidak kena pajak |
| `besaran_tidak_kena_pajak` | unsignedBigInteger | ✅ | Besaran tidak kena pajak |
| `nilai_pajak_jika` | unsignedBigInteger | ✅ | Nilai pajak jika ada |
| `pengecekan` | unsignedBigInteger | ✅ | Biaya pengecekan |
| `surat_kuasa_membebankan_hak_tanggungan` | unsignedBigInteger | ✅ | SK MHT |
| `ploting_validasi` | unsignedBigInteger | ✅ | Ploting validasi |
| **— Foreign Key —** | | | |
| `pemohon_id` | integer | ❌ | Foreign key → `pemohon.id` |
| `jenis_pekerjaan_id` | integer | ❌ | Foreign key → `pekerjaan_jenis.id` |
| `pekerjaan_id` | integer | ❌ | FK → `pekerjaan_notaris.id` atau `pekerjaan_ppat.id` |
| `kategori_pekerjaan_id` | integer | ❌ | Foreign key → `pekerjaan_kategori.id` |
| `status_id` | integer | ❌ | Foreign key → `transaksi_status.id` |
| `jenis_pajak_id` | foreignId | ✅ | Foreign key → `jenis_pajak.id` |
| `jenis_pembayaran_id` | integer | ❌ | Foreign key → `pembayaran_jenis.id` |
| **— Cetak —** | | | |
| `uraian_cetak_pemohon` | text | ✅ | Uraian untuk cetak pemohon |
| `keperluan_cetak_pemohon` | text | ✅ | Keperluan untuk cetak |
| **— Form Tambahan Notaris —** | | | |
| `judul` | string | ✅ | Judul akta |
| `nomor_akta` | string | ✅ | Nomor akta (unique) |
| `tanggal_akta` | date | ✅ | Tanggal akta |
| **— Audit —** | | | |
| `created_by` | integer | ✅ | ID user pembuat |
| `updated_by` | integer | ✅ | ID user pengubah |
| `created_at` | timestamp | ✅ | Waktu pembuatan |
| `updated_at` | timestamp | ✅ | Waktu update terakhir |
| `status` | smallInteger | ❌ | Status record (aktif/hapus) |
| **— Locking (ditambahkan via migrasi terpisah) —** | | | |
| `locked_by` | integer | ✅ | ID user yang mengunci |
| `locked_at` | timestamp | ✅ | Waktu penguncian |

> **Catatan Penting:**
> - `pekerjaan_id` bersifat polymorphic — bisa merujuk ke `pekerjaan_notaris` atau `pekerjaan_ppat` tergantung `jenis_pekerjaan_id`.
> - Kolom `locked_by` dan `locked_at` ditambahkan melalui migrasi terpisah (`2026_09_03_103456`).

---

### 4.2 Tabel `transaksi_status`

Status yang mungkin untuk sebuah transaksi.

| Kolom | Tipe | Nullable | Keterangan |
|-------|------|----------|------------|
| `id` | bigint (PK) | ❌ | Auto increment ID |
| `nama` | string | ❌ | Nama status (contoh: Diproses, Selesai, dll) |
| `created_by` | integer | ✅ | ID user pembuat |
| `updated_by` | integer | ✅ | ID user pengubah |
| `created_at` | timestamp | ✅ | Waktu pembuatan |
| `updated_at` | timestamp | ✅ | Waktu update terakhir |
| `status` | smallInteger | ❌ | Status aktif/nonaktif |

---

### 4.3 Tabel `transaksi_riwayat_pembayaran`

Riwayat/catatatan pembayaran untuk setiap transaksi.

| Kolom | Tipe | Nullable | Keterangan |
|-------|------|----------|------------|
| `id` | bigint (PK) | ❌ | Auto increment ID |
| `tanggal_pembayaran` | date | ❌ | Tanggal pembayaran dilakukan |
| `no_transaksi` | string | ✅ | Nomor referensi transaksi |
| `jumlah_dibayar` | unsignedBigInteger | ❌ | Jumlah uang yang dibayar |
| `pembayaran_ke` | integer | ❌ | Urutan pembayaran ke-berapa |
| `keterangan` | text | ✅ | Keterangan pembayaran |
| `created_by` | integer | ✅ | ID user pembuat |
| `updated_by` | integer | ✅ | ID user pengubah |
| `created_at` | timestamp | ✅ | Waktu pembuatan |
| `updated_at` | timestamp | ✅ | Waktu update terakhir |
| `status` | smallInteger | ❌ | Status aktif/nonaktif |

---

### 4.4 Tabel `transaksi_detail_proses`

Detail tahapan proses yang sudah dilakukan untuk setiap transaksi.

| Kolom | Tipe | Nullable | Keterangan |
|-------|------|----------|------------|
| `id` | bigint (PK) | ❌ | Auto increment ID |
| `transaksi_id` | foreignId | ❌ | Foreign key → `transaksi.id` |
| `jenis_pekerjaan_id` | foreignId | ❌ | Foreign key → `pekerjaan_jenis.id` |
| `prosesId` | foreignId | ❌ | FK → `pekerjaan_notaris_proses` / `pekerjaan_ppat_proses` |
| `pekerjaanNama` | string | ❌ | Snapshot nama pekerjaan |
| `kategoriNama` | string | ❌ | Snapshot nama kategori |
| `prosesNama` | string | ❌ | Snapshot nama proses |
| `atribut` | json | ✅ | Data atribut form (JSON) |
| `catatan` | text | ✅ | Catatan pada tahapan |
| `isValidate` | smallInteger | ❌ | 0 = belum divalidasi, 1 = sudah |
| `created_by` | integer | ✅ | ID user pembuat |
| `updated_by` | integer | ✅ | ID user pengubah |
| `status` | smallInteger | ❌ | Status aktif/nonaktif |
| `created_at` | timestamp | ✅ | Waktu pembuatan |
| `updated_at` | timestamp | ✅ | Waktu update terakhir |

---

### 4.5 Tabel `transaksi_materai`

Tabel pivot relasi antara transaksi dan materai.

| Kolom | Tipe | Nullable | Keterangan |
|-------|------|----------|------------|
| `id` | bigint (PK) | ❌ | Auto increment ID |
| `transaksi_id` | integer | ❌ | Foreign key → `transaksi.id` |
| `materai_id` | integer | ❌ | Foreign key → `materais.id` |
| `status` | smallInteger | ❌ | Status |

---

### 4.6 Tabel `transaksi_cetak_serah_terima`

Data cetak serah terima dokumen transaksi.

| Kolom | Tipe | Nullable | Keterangan |
|-------|------|----------|------------|
| `id` | bigint (PK) | ❌ | Auto increment ID |
| `no_transaksi` | string | ❌ | Nomor referensi transaksi |
| `list_keperluan` | string | ✅ | Daftar keperluan |
| `uraian` | string | ✅ | Uraian pekerjaan |
| `keperluan` | string | ✅ | Keperluan |
| `created_by` | integer | ❌ | ID user pembuat |
| `updated_by` | integer | ✅ | ID user pengubah |
| `status` | smallInteger | ❌ | Status |
| `created_at` | timestamp | ✅ | Waktu pembuatan |
| `updated_at` | timestamp | ✅ | Waktu update terakhir |

---

## 📌 5. MATERAI

### 5.1 Tabel `materais`

Pencatatan stok materai (masuk, keluar, sisa).

| Kolom | Tipe | Nullable | Keterangan |
|-------|------|----------|------------|
| `id` | bigint (PK) | ❌ | Auto increment ID |
| `date` | date | ❌ | Tanggal pencatatan |
| `materai_masuk` | unsignedInteger | ❌ | Jumlah materai masuk |
| `materai_keluar` | unsignedInteger | ❌ | Jumlah materai keluar |
| `stok_materai` | unsignedInteger | ❌ | Sisa stok materai |
| `keterangan` | text | ❌ | Keterangan pencatatan |
| `petugas_id` | integer | ❌ | ID petugas pencatat *(ditambah via migrasi)* |
| `is_transaksi` | integer | ✅ | Apakah dari transaksi? *(ditambah via migrasi)* |
| `is_add_materai` | integer | ✅ | Apakah penambahan stok? *(ditambah via migrasi)* |
| `created_by` | integer | ✅ | ID user pembuat |
| `updated_by` | integer | ✅ | ID user pengubah |
| `created_at` | timestamp | ✅ | Waktu pembuatan |
| `updated_at` | timestamp | ✅ | Waktu update terakhir |
| `status` | smallInteger | ❌ | Status aktif/nonaktif |

---

## 📊 6. KEUANGAN

### 6.1 Tabel `pengeluaran`

Pencatatan pengeluaran kantor.

| Kolom | Tipe | Nullable | Keterangan |
|-------|------|----------|------------|
| `id` | bigint (PK) | ❌ | Auto increment ID |
| `no_faktur` | string | ❌ | Nomor faktur |
| `jenis_pengeluaran_id` | integer | ❌ | Foreign key → `pengeluaran_jenis.id` |
| `jumlah` | string | ❌ | Jumlah nominal pengeluaran |
| `tanggal_pengeluaran` | dateTime | ❌ | Tanggal & waktu pengeluaran |
| `keterangan` | text | ❌ | Keterangan pengeluaran |
| `created_by` | integer | ✅ | ID user pembuat |
| `updated_by` | integer | ✅ | ID user pengubah |
| `created_at` | timestamp | ✅ | Waktu pembuatan |
| `updated_at` | timestamp | ✅ | Waktu update terakhir |
| `status` | smallInteger | ❌ | Status aktif/nonaktif |

---

### 6.2 Tabel `pengeluaran_jenis`

Jenis/kategori pengeluaran.

| Kolom | Tipe | Nullable | Keterangan |
|-------|------|----------|------------|
| `id` | bigint (PK) | ❌ | Auto increment ID |
| `nama` | string | ❌ | Nama jenis pengeluaran |
| `created_by` | integer | ✅ | ID user pembuat |
| `updated_by` | integer | ✅ | ID user pengubah |
| `created_at` | timestamp | ✅ | Waktu pembuatan |
| `updated_at` | timestamp | ✅ | Waktu update terakhir |
| `status` | smallInteger | ❌ | Status aktif/nonaktif |

---

### 6.3 Tabel `pembayaran_jenis`

Jenis metode pembayaran (tunai, transfer, dll).

| Kolom | Tipe | Nullable | Keterangan |
|-------|------|----------|------------|
| `id` | bigint (PK) | ❌ | Auto increment ID |
| `nama` | string | ❌ | Nama jenis pembayaran |
| `created_by` | integer | ✅ | ID user pembuat |
| `updated_by` | integer | ✅ | ID user pengubah |
| `created_at` | timestamp | ✅ | Waktu pembuatan |
| `updated_at` | timestamp | ✅ | Waktu update terakhir |
| `status` | smallInteger | ❌ | Status aktif/nonaktif |

---

### 6.4 Tabel `pendapatan`

Rekap/laporan pendapatan harian.

| Kolom | Tipe | Nullable | Keterangan |
|-------|------|----------|------------|
| `id` | bigint (PK) | ❌ | Auto increment ID |
| `jenis_pembayaran_id` | integer | ✅ | Foreign key → `pembayaran_jenis.id` |
| `tanggal` | date | ❌ | Tanggal laporan |
| `penghasilan` | integer | ❌ | Total penghasilan (default: 0) |
| `pengeluaran` | integer | ❌ | Total pengeluaran (default: 0) |
| `pendapatan` | integer | ❌ | Pendapatan bersih (default: 0) |
| `saldo` | integer | ❌ | Saldo (default: 0) |
| `created_by` | integer | ✅ | ID user pembuat |
| `updated_by` | integer | ✅ | ID user pengubah |
| `created_at` | timestamp | ✅ | Waktu pembuatan |
| `updated_at` | timestamp | ✅ | Waktu update terakhir |
| `status` | smallInteger | ❌ | Status aktif/nonaktif |

---

## 📋 7. MASTER DATA

### 7.1 Tabel `jenis_kelamin`

Referensi jenis kelamin.

| Kolom | Tipe | Nullable | Keterangan |
|-------|------|----------|------------|
| `id` | bigint (PK) | ❌ | Auto increment ID |
| `nama` | string | ❌ | Nama (Laki-laki / Perempuan) |
| `created_by` | integer | ✅ | ID user pembuat |
| `updated_by` | integer | ✅ | ID user pengubah |
| `created_at` | timestamp | ✅ | Waktu pembuatan |
| `updated_at` | timestamp | ✅ | Waktu update terakhir |
| `status` | smallInteger | ❌ | Status aktif/nonaktif |

---

### 7.2 Tabel `jenis_pajak`

Referensi jenis pajak.

| Kolom | Tipe | Nullable | Keterangan |
|-------|------|----------|------------|
| `id` | bigint (PK) | ❌ | Auto increment ID |
| `nama_pajak` | string(100) | ❌ | Nama jenis pajak |
| `created_by` | integer | ✅ | ID user pembuat |
| `updated_by` | integer | ✅ | ID user pengubah |
| `created_at` | timestamp | ✅ | Waktu pembuatan |
| `updated_at` | timestamp | ✅ | Waktu update terakhir |
| `status` | smallInteger | ❌ | Status aktif/nonaktif |

---

## ⚙️ 8. KONFIGURASI

### 8.1 Tabel `konfigurasi_umum`

Pengaturan umum aplikasi (satu baris, singleton).

| Kolom | Tipe | Nullable | Keterangan |
|-------|------|----------|------------|
| `id` | bigint (PK) | ❌ | Auto increment ID |
| **— Alamat & Data Notaris —** | | | |
| `alamat` | string | ✅ | Alamat kantor notaris |
| `telp_rumah` | string(13) | ✅ | Telp rumah |
| `telp_pertama` | string(13) | ✅ | Telp utama |
| `telp_kedua` | string(13) | ✅ | Telp sekunder |
| `email` | string | ✅ | Email kantor |
| `notaris_bersangkutan` | string | ✅ | Nama notaris |
| `ppat_bersangkutan` | string | ✅ | Nama PPAT |
| **— Pajak APHB —** | | | |
| `besaran_nilai_tidak_kena_pajak` | unsignedBigInteger | ✅ | Batas nilai tidak kena pajak |
| **— Pajak APTH —** | | | |
| `pengecekan` | unsignedBigInteger | ✅ | Biaya pengecekan |
| `surat_kuasa_membebankan_hak_tanggungan` | unsignedBigInteger | ✅ | Biaya SK MHT |
| `ploting_validasi` | unsignedBigInteger | ✅ | Biaya ploting validasi |
| **— Materai —** | | | |
| `harga_beli_materai` | unsignedBigInteger | ✅ | Harga beli materai per lembar |
| `harga_jual_materai` | unsignedBigInteger | ✅ | Harga jual materai per lembar |
| **— Audit —** | | | |
| `created_by` | integer | ✅ | ID user pembuat |
| `updated_by` | integer | ✅ | ID user pengubah |
| `created_at` | timestamp | ✅ | Waktu pembuatan |
| `updated_at` | timestamp | ✅ | Waktu update terakhir |
| `status` | smallInteger | ❌ | Status |

---

## 🔗 9. DIAGRAM RELASI (Entity Relationship)

```
┌─────────────┐       ┌──────────────┐       ┌─────────────┐
│   groups     │◄──────│    users      │──────►│   petugas   │
│  (role)     │ 1:N   │  (akun login) │  1:1  │ (petugas)   │
└──────┬──────┘       └──────────────┘       └──────┬──────┘
       │                                            │
       │ 1:N                                        │ 1:N
       ▼                                            ▼
┌──────────────┐                            ┌──────────────┐
│ sidebar_akses │                            │  transaksi   │ ←── Tabel Inti
│ (CRUD akses) │                            │   (akta)     │
└──────┬───────┘                            └──────┬───────┘
       │ N:1                                       │
       ▼                                      ┌────┼────┬────────┬─────────┬────────────┐
┌──────────────┐                              │    │    │        │         │            │
│   sidebar    │                              ▼    ▼    ▼        ▼         ▼            ▼
│  (menu nav)  │                      transaksi_  transaksi_  transaksi_  transaksi_  transaksi_
└──────────────┘                      riwayat_    detail_     materai     cetak_      status
                                      pembayaran  proses      (pivot)     serah_      (master)
                                                                      terima
┌──────────────────┐                                                    ┌──────────────┐
│ pekerjaan_notaris │────► pekerjaan_notaris_proses                     │  materais    │
│     (master)      │────► pekerjaan_notaris_harga                      │  (stok)      │
│                   │────► pekerjaan_notaris_atributs                   └──────────────┘
└──────────────────┘
                                          ┌──────────────────┐
┌──────────────────┐                      │   pemohon        │
│  pekerjaan_ppat  │────► pekerjaan_ppat_proses            │  (pelanggan)  │
│     (master)     │────► pekerjaan_ppat_harga               └──────────────┘
│                  │────► pekerjaan_ppat_atributs
└──────────────────┘

┌──────────────────┐    ┌────────────────┐    ┌──────────────────┐
│ pengeluaran_jenis │───►│  pengeluaran   │    │  pembayaran_jenis │
│   (master)        │   │  (pengeluaran) │    │    (master)       │
└──────────────────┘    └────────────────┘    └────────┬─────────┘
                                                       │
                               ┌───────────────────────┘
                               ▼
                        ┌──────────────┐    ┌──────────────────┐
                        │  pendapatan  │    │  pekerjaan_kategori │
                        │ (rekap harian)│   │      (master)        │
                        └──────────────┘    └──────────────────┘

┌──────────────┐    ┌──────────────┐    ┌──────────────────┐
│jenis_kelamin │    │  jenis_pajak  │    │ konfigurasi_umum │
│   (master)   │    │   (master)    │    │ (pengaturan app) │
└──────────────┘    └──────────────┘    └──────────────────┘
```

---

## 📝 10. CATATAN TAMBAHAN

### Pola Umum yang Digunakan di Semua Tabel

| Kolom | Keterangan |
|-------|------------|
| `id` | Primary key auto-increment (`bigint`) |
| `created_by` | ID user yang membuat record (audit trail) |
| `updated_by` | ID user yang terakhir mengubah record (audit trail) |
| `created_at` | Timestamp otomatis saat record dibuat |
| `updated_at` | Timestamp otomatis saat record diperbarui |
| `status` | Flag `smallInteger` — umumnya `1` = aktif, `0` = nonaktif/dihapus |

### Migrasi Tambahan (Alter Table)

| Migrasi | Aksi | Tabel | Kolom Ditambahkan |
|---------|------|-------|-------------------|
| `2024_08_21_070538` | ALTER TABLE | `materais` | `petugas_id`, `is_transaksi`, `is_add_materai` |
| `2026_09_03_103456` | ALTER TABLE | `transaksi` | `locked_by`, `locked_at` |

### Fitur Locking pada Transaksi

Ditambahkan pada migrasi terbaru (`2026_09-03`):
- `locked_by` — ID user yang mengunci transaksi (mencegah edit bersamaan)
- `locked_at` — Timestamp saat transaksi dikunci

---

*📅 Dokumen ini dihasilkan dari 35 file migrasi di `database/migrations/`*
*📆 Terakhir diperbarui: September 2026*
