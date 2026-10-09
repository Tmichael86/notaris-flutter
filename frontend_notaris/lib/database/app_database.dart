import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'master_tables.dart';
import 'pekerjaan_tables.dart';
import 'daos/pekerjaan_dao.dart';

part 'app_database.g.dart';

// 1. Tabel Pemohon
class Pemohons extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text()();
  TextColumn get nama => text()();
  TextColumn get alamat => text().nullable()();
  IntColumn get jenisKelamin => integer().nullable().references(JenisKelamins, #id)();
  TextColumn get noTelp => text().nullable()();
  TextColumn get nik => text().nullable()();

  // Audit lokal
  IntColumn get createdBy => integer().nullable()();
  IntColumn get updatedBy => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  IntColumn get status => integer().withDefault(const Constant(1))();

  // Kolom Sync & Delta
  BoolColumn get isSyncDirty => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

// 2. Tabel Transaksi
class Transaksis extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text()();
  TextColumn get noAkta => text()();
  RealColumn get total => real()();
  IntColumn get pemohonId => integer().nullable()();
  TextColumn get pemohonUuid => text().nullable()();
  IntColumn get petugasId => integer().nullable()();
  TextColumn get petugasUuid => text().nullable()();
  TextColumn get jenisTransaksi => text().withDefault(const Constant('notaris'))();
  TextColumn get statusTransaksi => text().withDefault(const Constant('Baru'))();
  DateTimeColumn get tanggalTransaksi => dateTime().nullable()();
  DateTimeColumn get tanggalJatuhTempo => dateTime().nullable()();
  RealColumn get diskon => real().withDefault(const Constant(0))();
  RealColumn get pembayaranSekarang => real().withDefault(const Constant(0))();
  TextColumn get metodePembayaran => text().withDefault(const Constant('Cash'))();
  IntColumn get jumlahMaterai => integer().withDefault(const Constant(0))();
  TextColumn get catatan => text().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();

  // Kolom Sync & Delta
  BoolColumn get isSyncDirty => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// One row per job selected in a transaction. Prices and labels are snapshots:
/// later Master changes must not rewrite historical transaction values.
class TransaksiDetails extends Table {
  @override
  String get tableName => 'transaksi_details';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get transaksiId => integer().references(Transaksis, #id)();
  TextColumn get jenisPekerjaan => text()(); // notaris | ppat
  IntColumn get pekerjaanNotarisId =>
      integer().nullable().references(PekerjaanNotarisLocals, #id)();
  IntColumn get pekerjaanPpatId =>
      integer().nullable().references(PekerjaanPpatLocals, #id)();
  TextColumn get namaPekerjaanSnapshot => text()();
  TextColumn get kategoriSnapshot => text().nullable()();
  TextColumn get estimasiWaktuSnapshot => text().nullable()();
  RealColumn get biayaLayanan => real().withDefault(const Constant(0))();
  RealColumn get biayaLainnya => real().withDefault(const Constant(0))();
  RealColumn get totalSnapshot => real().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  IntColumn get status => integer().withDefault(const Constant(1))();
  BoolColumn get isSyncDirty =>
      boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

@DriftDatabase(
  daos: [PekerjaanDao],
  tables: [
    Pemohons,
    Transaksis,
    TransaksiDetails,
    JenisKelamins,
    PekerjaanKategoris,
    PengeluaranJenis,
    PetugasLocals,
    PekerjaanNotarisLocals,
    PekerjaanNotarisHargaLocals,
    PekerjaanNotarisProsesLocals,
    PekerjaanNotarisAtributLocals,
    PekerjaanPpatLocals,
    PekerjaanPpatHargaLocals,
    PekerjaanPpatProsesLocals,
    PekerjaanPpatAtributLocals,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            // Extend the existing local Pemohon table.
            await m.addColumn(pemohons, pemohons.jenisKelamin);
            await m.addColumn(pemohons, pemohons.noTelp);
            await m.addColumn(pemohons, pemohons.createdBy);
            await m.addColumn(pemohons, pemohons.updatedBy);
            await m.addColumn(pemohons, pemohons.createdAt);
            await m.addColumn(pemohons, pemohons.status);

            // Create the new reference/master tables.
            await m.createTable(jenisKelamins);
            await m.createTable(pekerjaanKategoris);
            await m.createTable(pengeluaranJenis);
            await m.createTable(petugasLocals);
          }

          if (from < 3) {
            await m.createTable(pekerjaanNotarisLocals);
            await m.createTable(pekerjaanNotarisHargaLocals);
            await m.createTable(pekerjaanNotarisProsesLocals);
            await m.createTable(pekerjaanNotarisAtributLocals);
            await m.createTable(pekerjaanPpatLocals);
            await m.createTable(pekerjaanPpatHargaLocals);
            await m.createTable(pekerjaanPpatProsesLocals);
            await m.createTable(pekerjaanPpatAtributLocals);
          }

          if (from < 4) {
            await m.addColumn(transaksis, transaksis.petugasId);
            await m.addColumn(transaksis, transaksis.petugasUuid);
            await m.addColumn(transaksis, transaksis.jenisTransaksi);
            await m.addColumn(transaksis, transaksis.statusTransaksi);
            await m.addColumn(transaksis, transaksis.tanggalTransaksi);
            await m.addColumn(transaksis, transaksis.tanggalJatuhTempo);
            await m.addColumn(transaksis, transaksis.diskon);
            await m.addColumn(transaksis, transaksis.pembayaranSekarang);
            await m.addColumn(transaksis, transaksis.metodePembayaran);
            await m.addColumn(transaksis, transaksis.jumlahMaterai);
            await m.addColumn(transaksis, transaksis.catatan);
            await m.addColumn(transaksis, transaksis.createdAt);
            await m.createTable(transaksiDetails);
          }
        },
      );

  // --- QUERY METODE KUSTOM UNTUK SYNC ENGINE ---

  // 1. Ambil semua data pemohon lokal yang belum disinkronkan.
  Future<List<Pemohon>> getDirtyPemohons() {
    return (select(pemohons)..where((t) => t.isSyncDirty.equals(true))).get();
  }

  // 2. Perbarui status sync lokal setelah sukses dikirim.
  Future<int> markAsSynced(String uuid, DateTime syncedAt) {
    return (update(pemohons)..where((t) => t.uuid.equals(uuid))).write(
      PemohonsCompanion(
        isSyncDirty: const Value(false),
        lastSyncedAt: Value(syncedAt),
      ),
    );
  }

  // --- QUERY METODE KUSTOM UNTUK TRANSAKSI ---

  // 1. Ambil semua data transaksi lokal yang belum disinkronkan.
  Future<List<Transaksi>> getDirtyTransaksis() {
    return (select(transaksis)..where((t) => t.isSyncDirty.equals(true))).get();
  }

  // 2. Perbarui status sync lokal setelah sukses dikirim.
  Future<int> markTransaksiAsSynced(String uuid, DateTime syncedAt) {
    return (update(transaksis)..where((t) => t.uuid.equals(uuid))).write(
      TransaksisCompanion(
        isSyncDirty: const Value(false),
        lastSyncedAt: Value(syncedAt),
      ),
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'notaris_offline.sqlite'));
    return NativeDatabase(file);
  });
}
