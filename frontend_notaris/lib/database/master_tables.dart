import 'package:drift/drift.dart';

/// Master/reference data used by the offline-first SQLite database.
///
/// These tables intentionally mirror the current Laravel/Go database
/// terminology while adding UUID + sync metadata for future synchronization.
class JenisKelamins extends Table {
  @override
  String get tableName => 'jenis_kelamin';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get nama => text()();

  IntColumn get createdBy => integer().nullable()();
  IntColumn get updatedBy => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  IntColumn get status => integer().withDefault(const Constant(1))();

  BoolColumn get isSyncDirty =>
      boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

class PekerjaanKategoris extends Table {
  @override
  String get tableName => 'pekerjaan_kategori';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get nama => text()();

  IntColumn get createdBy => integer().nullable()();
  IntColumn get updatedBy => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  IntColumn get status => integer().withDefault(const Constant(1))();

  BoolColumn get isSyncDirty =>
      boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

class PengeluaranJenis extends Table {
  @override
  String get tableName => 'pengeluaran_jenis';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get nama => text()();

  IntColumn get createdBy => integer().nullable()();
  IntColumn get updatedBy => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  IntColumn get status => integer().withDefault(const Constant(1))();

  BoolColumn get isSyncDirty =>
      boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

class PetugasLocals extends Table {
  @override
  String get tableName => 'petugas';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();

  TextColumn get nik => text().nullable()();
  TextColumn get nama => text()();
  TextColumn get alamat => text().nullable()();
  TextColumn get tempatLahir => text().nullable()();
  DateTimeColumn get tanggalLahir => dateTime().nullable()();
  IntColumn get jenisKelamin =>
      integer().nullable().references(JenisKelamins, #id)();
  TextColumn get noTelp => text().nullable()();
  TextColumn get email => text()();
  IntColumn get userId => integer().nullable()();

  IntColumn get createdBy => integer().nullable()();
  IntColumn get updatedBy => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  IntColumn get status => integer().withDefault(const Constant(1))();

  BoolColumn get isSyncDirty =>
      boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

