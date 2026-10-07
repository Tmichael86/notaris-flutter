import 'package:drift/drift.dart';
import 'app_database.dart';

/// Development-only baseline data for the offline-first SQLite database.
///
/// The seeder intentionally uses Drift companions instead of raw SQL so the
/// seed data follows the same schema and foreign-key relationships used by
/// the application.
///
/// Seeded records are marked as already synced:
///   isSyncDirty = false
///
/// This keeps the baseline data out of the first push-sync test. Any record
/// created/updated/deleted through the normal application flow will still be
/// marked dirty by the repositories.
class DevelopmentSeeder {
  DevelopmentSeeder._();

  /// Seeds the database only when the required master data is empty.
  ///
  /// This method is idempotent: existing records are detected by UUID and
  /// will not be duplicated.
  static Future<void> seedIfEmpty(AppDatabase db) async {
    final categories = await db.pekerjaanDao.getActivePekerjaanKategori();

    if (categories.isNotEmpty) {
      return;
    }

    await db.transaction(() async {
      final now = DateTime.now();

      final jualBeli = await _ensureKategori(
        db,
        uuid: 'dev-kategori-jual-beli',
        nama: 'Jual Beli',
        now: now,
      );
      final hibah = await _ensureKategori(
        db,
        uuid: 'dev-kategori-hibah',
        nama: 'Hibah',
        now: now,
      );
      final kuasa = await _ensureKategori(
        db,
        uuid: 'dev-kategori-kuasa',
        nama: 'Kuasa',
        now: now,
      );
      final waris = await _ensureKategori(
        db,
        uuid: 'dev-kategori-waris',
        nama: 'Waris',
        now: now,
      );
      final pembagianHak = await _ensureKategori(
        db,
        uuid: 'dev-kategori-pembagian-hak',
        nama: 'Pembagian Hak Bersama',
        now: now,
      );
      await _ensureKategori(
        db,
        uuid: 'dev-kategori-lainnya',
        nama: 'Lainnya',
        now: now,
      );

      await _seedNotaris(
        db,
        now: now,
        jualBeli: jualBeli,
        hibah: hibah,
        kuasa: kuasa,
        waris: waris,
        pembagianHak: pembagianHak,
      );

      await _seedPpat(
        db,
        now: now,
        jualBeli: jualBeli,
        hibah: hibah,
        pembagianHak: pembagianHak,
      );
    });
  }

  static Future<int> _ensureKategori(
    AppDatabase db, {
    required String uuid,
    required String nama,
    required DateTime now,
  }) async {
    final existing = await (db.select(db.pekerjaanKategoris)
          ..where((t) => t.uuid.equals(uuid)))
        .getSingleOrNull();

    if (existing != null) {
      return existing.id;
    }

    return db.into(db.pekerjaanKategoris).insert(
          PekerjaanKategorisCompanion.insert(
            uuid: uuid,
            nama: nama,
            createdAt: Value(now),
            updatedAt: Value(now),
            isSyncDirty: const Value(false),
          ),
        );
  }

  static Future<int> _ensureNotaris(
    AppDatabase db, {
    required String uuid,
    required String nama,
    required DateTime now,
  }) async {
    final existing = await (db.select(db.pekerjaanNotarisLocals)
          ..where((t) => t.uuid.equals(uuid)))
        .getSingleOrNull();

    if (existing != null) {
      return existing.id;
    }

    return db.into(db.pekerjaanNotarisLocals).insert(
          PekerjaanNotarisLocalsCompanion.insert(
            uuid: uuid,
            nama: nama,
            createdAt: Value(now),
            updatedAt: Value(now),
            isSyncDirty: const Value(false),
          ),
        );
  }

  static Future<int> _ensureNotarisHarga(
    AppDatabase db, {
    required String uuid,
    required int pekerjaanId,
    required String harga,
    required int kategoriId,
    required String estimasiWaktu,
    required DateTime now,
  }) async {
    final existing = await (db.select(db.pekerjaanNotarisHargaLocals)
          ..where((t) => t.uuid.equals(uuid)))
        .getSingleOrNull();

    if (existing != null) {
      return existing.id;
    }

    return db.into(db.pekerjaanNotarisHargaLocals).insert(
          PekerjaanNotarisHargaLocalsCompanion.insert(
            uuid: uuid,
            pekerjaanNotarisId: pekerjaanId,
            harga: harga,
            kategoriPekerjaanId: kategoriId,
            estimasiWaktu: estimasiWaktu,
            createdAt: Value(now),
            updatedAt: Value(now),
            isSyncDirty: const Value(false),
          ),
        );
  }

  static Future<int> _ensureNotarisProses(
    AppDatabase db, {
    required String uuid,
    required int pekerjaanId,
    required String nama,
    required String detail,
    required DateTime now,
  }) async {
    final existing = await (db.select(db.pekerjaanNotarisProsesLocals)
          ..where((t) => t.uuid.equals(uuid)))
        .getSingleOrNull();

    if (existing != null) {
      return existing.id;
    }

    return db.into(db.pekerjaanNotarisProsesLocals).insert(
          PekerjaanNotarisProsesLocalsCompanion.insert(
            uuid: uuid,
            pekerjaanNotarisId: pekerjaanId,
            nama: nama,
            detail: detail,
            createdAt: Value(now),
            updatedAt: Value(now),
            isSyncDirty: const Value(false),
          ),
        );
  }

  static Future<void> _ensureNotarisAtribut(
    AppDatabase db, {
    required String uuid,
    required int pekerjaanId,
    required int prosesId,
    required String atribut,
    required DateTime now,
  }) async {
    final existing = await (db.select(db.pekerjaanNotarisAtributLocals)
          ..where((t) => t.uuid.equals(uuid)))
        .getSingleOrNull();

    if (existing != null) {
      return;
    }

    await db.into(db.pekerjaanNotarisAtributLocals).insert(
          PekerjaanNotarisAtributLocalsCompanion.insert(
            uuid: uuid,
            pekerjaanNotarisId: pekerjaanId,
            prosesPekerjaanNotarisId: prosesId,
            atribut: Value(atribut),
            createdAt: Value(now),
            updatedAt: Value(now),
            isSyncDirty: const Value(false),
          ),
        );
  }

  static Future<void> _seedNotaris(
    AppDatabase db, {
    required DateTime now,
    required int jualBeli,
    required int hibah,
    required int kuasa,
    required int waris,
    required int pembagianHak,
  }) async {
    final aktaJualBeli = await _ensureNotaris(
      db,
      uuid: 'dev-notaris-akta-jual-beli',
      nama: 'Akta Jual Beli',
      now: now,
    );

    await _ensureNotarisHarga(
      db,
      uuid: 'dev-notaris-ajb-harga-2500000',
      pekerjaanId: aktaJualBeli,
      harga: '2500000',
      kategoriId: jualBeli,
      estimasiWaktu: '7 Hari',
      now: now,
    );

    await _ensureNotarisHarga(
      db,
      uuid: 'dev-notaris-ajb-harga-3500000',
      pekerjaanId: aktaJualBeli,
      harga: '3500000',
      kategoriId: jualBeli,
      estimasiWaktu: '10 Hari',
      now: now,
    );

    final pemeriksaan = await _ensureNotarisProses(
      db,
      uuid: 'dev-notaris-ajb-proses-pemeriksaan',
      pekerjaanId: aktaJualBeli,
      nama: 'Pemeriksaan Dokumen',
      detail: 'Memeriksa kelengkapan dan keabsahan dokumen para pihak.',
      now: now,
    );

    await _ensureNotarisAtribut(
      db,
      uuid: 'dev-notaris-ajb-atribut-ktp',
      pekerjaanId: aktaJualBeli,
      prosesId: pemeriksaan,
      atribut: 'KTP Para Pihak',
      now: now,
    );

    await _ensureNotarisAtribut(
      db,
      uuid: 'dev-notaris-ajb-atribut-sertifikat',
      pekerjaanId: aktaJualBeli,
      prosesId: pemeriksaan,
      atribut: 'Sertifikat Tanah',
      now: now,
    );

    final penandatanganan = await _ensureNotarisProses(
      db,
      uuid: 'dev-notaris-ajb-proses-penandatanganan',
      pekerjaanId: aktaJualBeli,
      nama: 'Penandatanganan Akta',
      detail: 'Pelaksanaan penandatanganan akta oleh para pihak.',
      now: now,
    );

    await _ensureNotarisAtribut(
      db,
      uuid: 'dev-notaris-ajb-atribut-pembayaran',
      pekerjaanId: aktaJualBeli,
      prosesId: penandatanganan,
      atribut: 'Bukti Pembayaran',
      now: now,
    );

    final pendaftaran = await _ensureNotarisProses(
      db,
      uuid: 'dev-notaris-ajb-proses-pendaftaran',
      pekerjaanId: aktaJualBeli,
      nama: 'Pendaftaran',
      detail: 'Penyelesaian proses administrasi dan pendaftaran.',
      now: now,
    );

    await _ensureNotarisAtribut(
      db,
      uuid: 'dev-notaris-ajb-atribut-sppt',
      pekerjaanId: aktaJualBeli,
      prosesId: pendaftaran,
      atribut: 'SPPT PBB',
      now: now,
    );

    final aktaHibah = await _ensureNotaris(
      db,
      uuid: 'dev-notaris-akta-hibah',
      nama: 'Akta Hibah',
      now: now,
    );

    await _ensureNotarisHarga(
      db,
      uuid: 'dev-notaris-hibah-harga-2000000',
      pekerjaanId: aktaHibah,
      harga: '2000000',
      kategoriId: hibah,
      estimasiWaktu: '5 Hari',
      now: now,
    );

    final hibahDokumen = await _ensureNotarisProses(
      db,
      uuid: 'dev-notaris-hibah-proses-dokumen',
      pekerjaanId: aktaHibah,
      nama: 'Pemeriksaan Dokumen',
      detail: 'Memeriksa dokumen pemberi dan penerima hibah.',
      now: now,
    );

    await _ensureNotarisAtribut(
      db,
      uuid: 'dev-notaris-hibah-atribut-ktp',
      pekerjaanId: aktaHibah,
      prosesId: hibahDokumen,
      atribut: 'KTP Pemberi dan Penerima',
      now: now,
    );

    await _ensureNotaris(
      db,
      uuid: 'dev-notaris-akta-kuasa',
      nama: 'Akta Kuasa',
      now: now,
    );

    await _ensureNotarisHarga(
      db,
      uuid: 'dev-notaris-kuasa-harga-1500000',
      pekerjaanId: await _ensureNotaris(
        db,
        uuid: 'dev-notaris-akta-kuasa',
        nama: 'Akta Kuasa',
        now: now,
      ),
      harga: '1500000',
      kategoriId: kuasa,
      estimasiWaktu: '3 Hari',
      now: now,
    );

    await _ensureNotaris(
      db,
      uuid: 'dev-notaris-akta-waris',
      nama: 'Akta Waris',
      now: now,
    );

    await _ensureNotarisHarga(
      db,
      uuid: 'dev-notaris-waris-harga-1750000',
      pekerjaanId: await _ensureNotaris(
        db,
        uuid: 'dev-notaris-akta-waris',
        nama: 'Akta Waris',
        now: now,
      ),
      harga: '1750000',
      kategoriId: waris,
      estimasiWaktu: '7 Hari',
      now: now,
    );

    final pembagian = await _ensureNotaris(
      db,
      uuid: 'dev-notaris-pembagian-hak',
      nama: 'Pembagian Hak Bersama',
      now: now,
    );

    await _ensureNotarisHarga(
      db,
      uuid: 'dev-notaris-pembagian-hak-harga-3000000',
      pekerjaanId: pembagian,
      harga: '3000000',
      kategoriId: pembagianHak,
      estimasiWaktu: '7 Hari',
      now: now,
    );
  }

  static Future<int> _ensurePpat(
    AppDatabase db, {
    required String uuid,
    required String nama,
    required DateTime now,
  }) async {
    final existing = await (db.select(db.pekerjaanPpatLocals)
          ..where((t) => t.uuid.equals(uuid)))
        .getSingleOrNull();

    if (existing != null) {
      return existing.id;
    }

    return db.into(db.pekerjaanPpatLocals).insert(
          PekerjaanPpatLocalsCompanion.insert(
            uuid: uuid,
            nama: nama,
            createdAt: Value(now),
            updatedAt: Value(now),
            isSyncDirty: const Value(false),
          ),
        );
  }

  static Future<int> _ensurePpatHarga(
    AppDatabase db, {
    required String uuid,
    required int pekerjaanId,
    required String harga,
    required int kategoriId,
    required String estimasiWaktu,
    required DateTime now,
  }) async {
    final existing = await (db.select(db.pekerjaanPpatHargaLocals)
          ..where((t) => t.uuid.equals(uuid)))
        .getSingleOrNull();

    if (existing != null) {
      return existing.id;
    }

    return db.into(db.pekerjaanPpatHargaLocals).insert(
          PekerjaanPpatHargaLocalsCompanion.insert(
            uuid: uuid,
            pekerjaanPpatId: pekerjaanId,
            harga: harga,
            kategoriPekerjaanId: kategoriId,
            estimasiWaktu: estimasiWaktu,
            createdAt: Value(now),
            updatedAt: Value(now),
            isSyncDirty: const Value(false),
          ),
        );
  }

  static Future<int> _ensurePpatProses(
    AppDatabase db, {
    required String uuid,
    required int pekerjaanId,
    required String nama,
    required String detail,
    required DateTime now,
  }) async {
    final existing = await (db.select(db.pekerjaanPpatProsesLocals)
          ..where((t) => t.uuid.equals(uuid)))
        .getSingleOrNull();

    if (existing != null) {
      return existing.id;
    }

    return db.into(db.pekerjaanPpatProsesLocals).insert(
          PekerjaanPpatProsesLocalsCompanion.insert(
            uuid: uuid,
            pekerjaanPpatId: pekerjaanId,
            nama: nama,
            detail: detail,
            createdAt: Value(now),
            updatedAt: Value(now),
            isSyncDirty: const Value(false),
          ),
        );
  }

  static Future<void> _ensurePpatAtribut(
    AppDatabase db, {
    required String uuid,
    required int pekerjaanId,
    required int prosesId,
    required String atribut,
    required DateTime now,
  }) async {
    final existing = await (db.select(db.pekerjaanPpatAtributLocals)
          ..where((t) => t.uuid.equals(uuid)))
        .getSingleOrNull();

    if (existing != null) {
      return;
    }

    await db.into(db.pekerjaanPpatAtributLocals).insert(
          PekerjaanPpatAtributLocalsCompanion.insert(
            uuid: uuid,
            pekerjaanPpatId: pekerjaanId,
            prosesPekerjaanPpatId: prosesId,
            atribut: Value(atribut),
            createdAt: Value(now),
            updatedAt: Value(now),
            isSyncDirty: const Value(false),
          ),
        );
  }

  static Future<void> _seedPpat(
    AppDatabase db, {
    required DateTime now,
    required int jualBeli,
    required int hibah,
    required int pembagianHak,
  }) async {
    final jualBeliTanah = await _ensurePpat(
      db,
      uuid: 'dev-ppat-akta-jual-beli-tanah',
      nama: 'Akta Jual Beli Tanah',
      now: now,
    );

    await _ensurePpatHarga(
      db,
      uuid: 'dev-ppat-ajb-tanah-harga-2500000',
      pekerjaanId: jualBeliTanah,
      harga: '2500000',
      kategoriId: jualBeli,
      estimasiWaktu: '7 Hari',
      now: now,
    );

    final pemeriksaan = await _ensurePpatProses(
      db,
      uuid: 'dev-ppat-ajb-tanah-proses-pemeriksaan',
      pekerjaanId: jualBeliTanah,
      nama: 'Pemeriksaan Dokumen',
      detail: 'Memeriksa dokumen pertanahan dan identitas para pihak.',
      now: now,
    );

    await _ensurePpatAtribut(
      db,
      uuid: 'dev-ppat-ajb-tanah-atribut-sertifikat',
      pekerjaanId: jualBeliTanah,
      prosesId: pemeriksaan,
      atribut: 'Sertifikat Tanah',
      now: now,
    );

    await _ensurePpatAtribut(
      db,
      uuid: 'dev-ppat-ajb-tanah-atribut-ktp',
      pekerjaanId: jualBeliTanah,
      prosesId: pemeriksaan,
      atribut: 'KTP Para Pihak',
      now: now,
    );

    final aktaHibahTanah = await _ensurePpat(
      db,
      uuid: 'dev-ppat-akta-hibah-tanah',
      nama: 'Akta Hibah Tanah',
      now: now,
    );

    await _ensurePpatHarga(
      db,
      uuid: 'dev-ppat-hibah-tanah-harga-2000000',
      pekerjaanId: aktaHibahTanah,
      harga: '2000000',
      kategoriId: hibah,
      estimasiWaktu: '5 Hari',
      now: now,
    );

    final hibahProses = await _ensurePpatProses(
      db,
      uuid: 'dev-ppat-hibah-tanah-proses-akta',
      pekerjaanId: aktaHibahTanah,
      nama: 'Pembuatan Akta',
      detail: 'Penyusunan dan penandatanganan akta hibah tanah.',
      now: now,
    );

    await _ensurePpatAtribut(
      db,
      uuid: 'dev-ppat-hibah-tanah-atribut-ktp',
      pekerjaanId: aktaHibahTanah,
      prosesId: hibahProses,
      atribut: 'KTP Pemberi dan Penerima',
      now: now,
    );

    final pembagian = await _ensurePpat(
      db,
      uuid: 'dev-ppat-pembagian-hak',
      nama: 'Pembagian Hak Bersama',
      now: now,
    );

    await _ensurePpatHarga(
      db,
      uuid: 'dev-ppat-pembagian-hak-harga-3000000',
      pekerjaanId: pembagian,
      harga: '3000000',
      kategoriId: pembagianHak,
      estimasiWaktu: '7 Hari',
      now: now,
    );
  }
}
