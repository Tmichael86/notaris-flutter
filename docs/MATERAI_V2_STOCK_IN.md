# Materai V2 Slice 1 — Penerimaan Stok Manual

V2 memakai ledger v27 yang sama. Identitas penerimaan adalah UUID operasi dalam namespace `local:materai:<profile>:receipt:<uuid>`, dengan `source_id=1`. Constraint unik v27 mencegah operasi ganda. Namespace khusus saldo pembuka menyimpan provenance dan fingerprint yang dipasangkan ke binding profil oleh runner. Snapshot stok dihitung dari rantai mutasi yang valid dalam profil yang sama.

## Syarat dan perilaku

- Penerimaan hanya aktif pada launcher disposable Windows dengan binding eksplisit, akun valid yang terikat profil, sidebar aktif `laporan_materai` dengan READ dan CREATE, dan satu relasi Petugas aktif lewat `petugas.user_id`. Akun tidak dapat memilih Petugas pengganti.
- Transaksi SQLite memverifikasi saldo pembuka, urutan, hash, detail provenance, predecessor yang ditinjau, dan grant sebelum insert. Jika dua perintah membawa predecessor yang sama, paling banyak satu dapat memajukan ledger. Retry dengan UUID dan isi yang sama mengembalikan baris tersimpan. Isi berbeda dengan UUID sama ditolak.
- Batas per penerimaan 1–10.000 lembar, saldo maksimal 9.007.199.254.740.991, dan keterangan maksimal 250 karakter. Tanggal bisnis paling awal sama dengan mutasi terakhir. Timestamp pencatatan memakai jam perangkat dan harus lebih baru dari mutasi terakhir.
- Draf UI disimpan dalam folder fixture sebelum insert. Jika sesi terputus, buka kembali formulir dan lanjutkan draf dengan ID yang sama. Tombol Selesai mengakui hasil yang sudah commit. Jika draf rusak atau milik akun lain, jalur UI tertutup untuk review.
- Stok tercatat adalah saldo per mutasi. Filter laporan hanya membatasi baris yang terlihat dan total lembar masuk/keluar. Saldo pada dialog berasal dari pemeriksaan rantai penuh.

Profil reguler dan V1 tetap pada mode baca. Sebelum penerimaan operasional dapat diaktifkan, diperlukan baseline stok berizin beserta bukti dan urutan yang bisa direkonsiliasi, binding profil yang disetujui, grant CREATE aktual, dan pemetaan Petugas terverifikasi. Slice ini belum mencakup pemakaian oleh transaksi, koreksi historis, penyesuaian, stok keluar, valuasi, atau sync.

## Acceptance Windows

Runner `scripts/materai-stock-demo-acceptance.py` memakai profil terisolasi dengan saldo pembuka sintetis 20, lalu penerimaan fixture 5 sehingga saldo awal uji adalah 25. Kredensial demo ditampilkan oleh dialog Windows. Tutup Flutter sebelum menjalankan checkpoint atau berpindah fase.

| Tahap | Akun | Hasil yang diperiksa |
| --- | --- | --- |
| INITIAL | — | Dua mutasi, stok 20 dan 25. |
| CREATE | `admin.demo` | Buka Laporan → Materai. Batal pertama untuk mengecek bahwa jumlah baris tetap dua. Buka lagi, isi tanggal 17/11/2026, 7 lembar dan keterangan `Penerimaan materai uji Windows`. Simpan, lalu Selesai. Tepat satu baris baru, stok 32, total masuk 12 dan keluar 0. |
| RESTART | `admin.demo` | Buka laporan dengan mode baca dan lihat baris baru serta stok tercatat 32. |
| READ-ONLY | `pembaca.demo` | Laporan dapat dibaca. Aksi Tambah tidak tampil. |
| DENIED | `petugas.demo` | Menu Materai tidak tersedia. |
| FINAL | — | Ledger lama, semua tabel di luar Materai, audit, dan metadata sync sama dengan baseline. |

Gunakan `credential` dan `launch` dengan `--id <id> --stage <fase>` untuk fase interaktif. Gunakan `postcheck --id <id> --stage <fase>` untuk checkpoint. Fingerprint SQLite seluruh file berubah setelah CREATE, tetapi fingerprint objek skema dan isi tabel yang dilindungi wajib tetap sama.
