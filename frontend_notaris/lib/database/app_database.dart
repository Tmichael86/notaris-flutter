import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

// 1. Tabel Pemohon
class Pemohons extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text()();
  TextColumn get nama => text()();
  TextColumn get alamat => text().nullable()();
  TextColumn get nik => text().nullable()();
  
  // Kolom Sync & Delta
  BoolColumn get isSyncDirty => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
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

  
  // Kolom Sync & Delta
  BoolColumn get isSyncDirty => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

@DriftDatabase(tables: [Pemohons, Transaksis])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // --- QUERY METODE KUSTOM UNTUK SYNC ENGINE ---

  // 1. Ambil semua data pemohon lokal yang belum disinkronkan (isSyncDirty == true)
  Future<List<Pemohon>> getDirtyPemohons() {
    return (select(pemohons)..where((t) => t.isSyncDirty.equals(true))).get();
  }

  // 2. Perbarui status sync lokal setelah sukses dikirim ke AdonisJS
  Future<int> markAsSynced(String uuid, DateTime syncedAt) {
    return (update(pemohons)..where((t) => t.uuid.equals(uuid))).write(
      PemohonsCompanion(
        isSyncDirty: const Value(false),
        lastSyncedAt: Value(syncedAt),
      ),
    );
  }

  // --- QUERY METODE KUSTOM UNTUK TRANSAKSI ---

  // 1. Ambil semua data transaksi lokal yang belum disinkronkan (isSyncDirty == true)
  Future<List<Transaksi>> getDirtyTransaksis() {
    return (select(transaksis)..where((t) => t.isSyncDirty.equals(true))).get();
  }

  // 2. Perbarui status sync transaksi lokal setelah sukses dikirim ke AdonisJS
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


