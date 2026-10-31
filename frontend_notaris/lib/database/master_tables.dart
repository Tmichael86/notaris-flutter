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

  BoolColumn get isSyncDirty => boolean().withDefault(const Constant(true))();
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

  BoolColumn get isSyncDirty => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

@DataClassName('PengeluaranJenisData')
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

  BoolColumn get isSyncDirty => boolean().withDefault(const Constant(true))();
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

  BoolColumn get isSyncDirty => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// Reconciliation metadata for a local Petugas identity.
///
/// `localUuid` is deliberately the primary key. It is immutable local
/// identity and may already be referenced by local transaction snapshots.
/// Cloud identity is stored separately so an explicit reconciliation never
/// rewrites local IDs, local UUIDs, or transaction references.
class PetugasIdentityMaps extends Table {
  @override
  String get tableName => 'petugas_identity_map';

  TextColumn get localUuid => text().references(PetugasLocals, #uuid)();
  TextColumn get cloudUuid => text().nullable()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get state => text().customConstraint(
    "NOT NULL CHECK (state IN ('local_only', 'verified', 'ambiguous', "
    "'server_only', 'development'))",
  )();
  TextColumn get evidence => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {localUuid};

  @override
  List<String> get customConstraints => const [
    "CHECK ((state IN ('verified', 'server_only') "
        'AND cloud_uuid IS NOT NULL AND server_id IS NOT NULL) '
        "OR (state IN ('local_only', 'ambiguous', 'development') "
        'AND cloud_uuid IS NULL AND server_id IS NULL))',
  ];
}
