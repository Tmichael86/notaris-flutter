# Materai V2 Slice 2 — Pemakaian dari Transaksi

Pemakaian awal merupakan efek CREATE Transaksi berdasarkan jumlah lembar pada `transaksis.jumlah_materai`. Laravel juga mengambil nilai tersebut sekali dari request Notaris atau PPAT dan memeriksanya pada jalur CREATE Transaksi. Form Flutter kini memvalidasi integer mentah sebelum simpan. Kuantitas berada pada header, sehingga beberapa pekerjaan PPAT memakai satu mutasi.

`TransactionRepository.save` menyerahkan simpan CREATE dengan pemakaian positif kepada repository Materai. Satu transaksi Drift/SQLite pada koneksi yang sama memeriksa baseline, aktor dan stok, menyimpan header, pembayaran dan detail, lalu menambahkan mutasi. Drift Native menggunakan `BEGIN IMMEDIATE`. Writer kedua membaca saldo setelah transaksi pertama atau menerima konflik SQLite yang dapat diperiksa ulang. UUID transaksi stabil menjadi bagian dari identitas unik `local:materai:<profile>:transaction:<uuid>`. Provenance memuat PK/UUID Transaksi, domain, Petugas, user/grup, timestamp, tanggal bisnis dan hash request. Retry dengan isi yang sama mengembalikan PK sebelumnya dan tidak menjalankan penulisan detail lagi.

Profil yang mengadopsi Slice 2 memerlukan binding eksplisit dan saldo pembuka yang memberikan bukti adopsi. Saldo diverifikasi dari rantai penuh, dengan batas 1–10.000 lembar per pemakaian, stok tidak boleh negatif dan tanggal bisnis tidak boleh mendahului mutasi terakhir. Sesi terverifikasi wajib mempunyai `transaksi` READ + CREATE dan satu relasi Petugas aktif. Grant manual `laporan_materai` CREATE terpisah. Profil standar dan acceptance lama tetap memakai kontrak header lama. Explicit stock-out tanpa binding ditolak, begitu pula simpan positif lewat repository tanpa binding pada profil yang sudah mengadopsi fitur ini. Kuantitas nol tetap mengikuti penyimpanan Transaksi biasa.

Dokumen ini tidak mengubah skema v27 atau memigrasikan profil lama. Jumlah pemakaian serta pembatalan/penghapusan transaksi tertaut ditahan sampai kontrak koreksi tersedia. Edit lain tetap mengikuti validasi Transaksi. Membuka transaksi, pencetakan invoice, baca laporan, dan replay cloud tidak menghasilkan pengurangan stok. Transaksi dengan mutasi Materai tersimpan diblokir oleh guard sinkronisasi lokal.

## Acceptance Windows

Gunakan runner `scripts/materai-usage-demo-acceptance.py`. Tutup Flutter setiap kali sebelum postcheck dan sebelum membuka fase selanjutnya. Credential dibuka melalui dialog Windows. Saldo awal 20 lembar.

| Fase | Akun | Skenario |
| --- | --- | --- |
| initial | — | Ledger pembuka 20 dan 16 transaksi lama, tanpa mutasi keluar. |
| notaris | `admin.demo` | Pilih `Materai Uji Notaris`, harga Rp100.000, pemakaian 3 lembar, pembayaran awal Rp20.000. Stok 17, satu header, satu detail, satu pembayaran awal dan satu mutasi. |
| restart | `admin.demo` | Cari dan buka Notaris yang baru dibuat, lalu cek mutasi serta stok 17. |
| ppat | `admin.demo` | Pilih `Materai Uji PPAT A` dan `Materai Uji PPAT B`, masing-masing Rp100.000, pemakaian total 4 lembar, pembayaran awal Rp30.000. Stok 13, satu header, dua detail, satu pembayaran dan satu mutasi. |
| insufficient | `admin.demo` | Coba buat Notaris dengan 14 lembar saat stok 13. Pesan stok tidak cukup dan semua data tetap. |
| read | `pembaca.demo` | Laporan memiliki tiga baris termasuk pembuka, 7 lembar keluar, 0 masuk, stok tercatat 13 pada baris terbaru. Akun tidak dapat membuat Transaksi atau stok masuk. |
| denied | `petugas.demo` | Menu Materai tidak tersedia dan simpan Transaksi baru diblokir. |
| final | — | Dua mutasi keluar unik, data terdahulu dan tabel terlindungi identik, integrity ok dan FK 0. |

Untuk setiap transaksi pilih Pemohon `Laras Pradépta`, Petugas `Rani Wulandari`, kategori `Category`, status `Baru`, pembayaran `Cash`, dan isi Jatuh Tempo pada langkah pembayaran. Registrasi otomatis memakai tanggal perangkat. Pada 17/11/2026 nomor yang diharapkan adalah `1001711260001` dan `2001711260002`. Postcheck memverifikasi nomor dari tanggal yang benar-benar direkam dan menampilkan UUID serta namespace aktual. Simpan checkpoint Notaris dan PPAT segera setelah masing-masing CREATE agar tahap selanjutnya dapat membuktikan hasil sebelumnya tetap utuh.

Aktivasi operasional menunggu baseline berizin, bukti urutan dan profil yang disetujui, serta pemetaan akun/Petugas operasional terverifikasi. Koreksi, pengembalian, stok keluar manual, valuasi dan sinkronisasi Materai tetap di luar slice ini.
