import 'package:drift/drift.dart';

/// Offline-first tables for Notaris and PPAT work definitions.
///
/// The structure mirrors the Laravel master data:
/// pekerjaan -> harga, proses -> atribut.
///
/// UUID and sync metadata are local additions for the future sync layer.

class PekerjaanNotarisLocals extends Table {
  @override
  String get tableName => 'pekerjaan_notaris';

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

class PekerjaanNotarisHargaLocals extends Table {
  @override
  String get tableName => 'pekerjaan_notaris_harga';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get pekerjaanNotarisId =>
      integer().references(PekerjaanNotarisLocals, #id)();
  TextColumn get harga => text()();
  IntColumn get kategoriPekerjaanId =>
      integer().references(PekerjaanKategoris, #id)();
  TextColumn get estimasiWaktu => text()();

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

class PekerjaanNotarisProsesLocals extends Table {
  @override
  String get tableName => 'pekerjaan_notaris_proses';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get pekerjaanNotarisId =>
      integer().references(PekerjaanNotarisLocals, #id)();
  TextColumn get nama => text()();
  TextColumn get detail => text()();

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

class PekerjaanNotarisAtributLocals extends Table {
  @override
  String get tableName => 'pekerjaan_notaris_atributs';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get pekerjaanNotarisId =>
      integer().references(PekerjaanNotarisLocals, #id)();
  IntColumn get prosesPekerjaanNotarisId =>
      integer().references(PekerjaanNotarisProsesLocals, #id)();
  TextColumn get atribut => text().nullable()();

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

class PekerjaanPpatLocals extends Table {
  @override
  String get tableName => 'pekerjaan_ppat';

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

class PekerjaanPpatHargaLocals extends Table {
  @override
  String get tableName => 'pekerjaan_ppat_harga';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get pekerjaanPpatId =>
      integer().references(PekerjaanPpatLocals, #id)();
  TextColumn get harga => text()();
  IntColumn get kategoriPekerjaanId =>
      integer().references(PekerjaanKategoris, #id)();
  TextColumn get estimasiWaktu => text()();

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

class PekerjaanPpatProsesLocals extends Table {
  @override
  String get tableName => 'pekerjaan_ppat_proses';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get pekerjaanPpatId =>
      integer().references(PekerjaanPpatLocals, #id)();
  TextColumn get nama => text()();
  TextColumn get detail => text()();

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

class PekerjaanPpatAtributLocals extends Table {
  @override
  String get tableName => 'pekerjaan_ppat_atributs';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get pekerjaanPpatId =>
      integer().references(PekerjaanPpatLocals, #id)();
  IntColumn get prosesPekerjaanPpatId =>
      integer().references(PekerjaanPpatProsesLocals, #id)();
  TextColumn get atribut => text().nullable()();

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
