import 'dart:io';

import 'dart:convert';

import 'package:uuid/uuid.dart';
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
  IntColumn get jenisKelamin =>
      integer().nullable().references(JenisKelamins, #id)();
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
  TextColumn get jenisTransaksi =>
      text().withDefault(const Constant('notaris'))();
  TextColumn get statusTransaksi =>
      text().withDefault(const Constant('Baru'))();
  DateTimeColumn get tanggalTransaksi => dateTime().nullable()();
  DateTimeColumn get tanggalJatuhTempo => dateTime().nullable()();
  RealColumn get diskon => real().withDefault(const Constant(0))();
  RealColumn get pembayaranSekarang => real().withDefault(const Constant(0))();
  TextColumn get metodePembayaran =>
      text().withDefault(const Constant('Cash'))();
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
  // Process checklist captured when this job is attached to a transaction.
  // Keep it as a snapshot so manually-added processes survive reloads.
  TextColumn get prosesSnapshot => text().nullable()();
  RealColumn get biayaLayanan => real().withDefault(const Constant(0))();
  RealColumn get biayaLainnya => real().withDefault(const Constant(0))();
  RealColumn get totalSnapshot => real().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  IntColumn get status => integer().withDefault(const Constant(1))();
  BoolColumn get isSyncDirty => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// Current process state for one transaction job.
/// Legacy snapshots remain available until their status meaning is mapped.
class TransaksiProses extends Table {
  @override
  String get tableName => 'transaksi_proses';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();

  IntColumn get transaksiId => integer().references(Transaksis, #id)();
  TextColumn get transaksiDetailUuid =>
      text().references(TransaksiDetails, #uuid)();

  /// Original process identifier. May be a Master ID or a manual ID.
  TextColumn get sourceProcessId => text().nullable()();

  TextColumn get namaProsesSnapshot => text()();

  /// Null means the legacy state has not been safely mapped yet.
  TextColumn get statusProses => text().nullable()();
  TextColumn get legacyStatus => text().nullable()();
  TextColumn get legacyData => text().nullable()();

  TextColumn get catatan => text().nullable()();

  IntColumn get submittedByUserId => integer().nullable()();
  DateTimeColumn get submittedAt => dateTime().nullable()();

  IntColumn get validatedByUserId => integer().nullable()();
  DateTimeColumn get validatedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  BoolColumn get isSyncDirty => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// Audit trail for explicit process-state transitions.
class TransaksiProsesRiwayat extends Table {
  @override
  String get tableName => 'transaksi_proses_riwayat';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();

  IntColumn get transaksiProsesId =>
      integer().references(TransaksiProses, #id)();

  TextColumn get statusSebelumnya => text().nullable()();
  TextColumn get statusBaru => text()();

  IntColumn get actorUserId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get catatan => text().nullable()();

  BoolColumn get isSyncDirty => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
}

/// Individual payment records. Each installment is stored independently.
class TransaksiRiwayatPembayarans extends Table {
  @override
  String get tableName => 'transaksi_riwayat_pembayaran';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  IntColumn get transaksiId => integer().references(Transaksis, #id)();
  DateTimeColumn get tanggalPembayaran => dateTime()();
  RealColumn get nominal => real()();
  TextColumn get metodePembayaran =>
      text().withDefault(const Constant('Cash'))();
  TextColumn get keterangan => text().nullable()();
  IntColumn get urutanPembayaran => integer().withDefault(const Constant(1))();
  IntColumn get status => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get isSyncDirty => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
}

@DriftDatabase(
  daos: [PekerjaanDao],
  tables: [
    Pemohons,
    Transaksis,
    TransaksiDetails,
    TransaksiRiwayatPembayarans,
    TransaksiProses,
    TransaksiProsesRiwayat,
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
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _createUuidUniqueIndexes();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // Keep all pending migration steps atomic. If V8 UUID validation fails,
      // earlier DDL and backfill work must roll back with it.
      await transaction(() async {
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

        if (from < 5) {
          await m.createTable(transaksiRiwayatPembayarans);
        }

        if (from < 6) {
          await m.addColumn(transaksiDetails, transaksiDetails.prosesSnapshot);
        }

        if (from < 7) {
          // The enclosing upgrade transaction also covers V7 DDL and backfill.
          await m.createTable(transaksiProses);
          await m.createTable(transaksiProsesRiwayat);

          final legacyDetails = await (select(transaksiDetails)..where(
            (detail) => detail.deletedAt.isNull() & detail.status.equals(1),
          )).get();
          const uuidGenerator = Uuid();

          for (final detail in legacyDetails) {
            final snapshot = detail.prosesSnapshot;
            if (snapshot == null || snapshot.trim().isEmpty) {
              continue;
            }

            dynamic decoded;
            try {
              decoded = jsonDecode(snapshot);
            } on FormatException {
              // Keep malformed legacy JSON untouched in the original snapshot.
              continue;
            }

            if (decoded is! List) {
              continue;
            }

            for (final item in decoded) {
              if (item is! Map) {
                continue;
              }

              final name = item['name']?.toString().trim() ?? '';
              if (name.isEmpty) {
                continue;
              }

              await into(transaksiProses).insert(
                TransaksiProsesCompanion.insert(
                  uuid: uuidGenerator.v4(),
                  transaksiId: detail.transaksiId,
                  transaksiDetailUuid: detail.uuid,
                  sourceProcessId: Value(item['id']?.toString()),
                  namaProsesSnapshot: name,
                  statusProses: const Value(null),
                  legacyStatus: Value(item['status']?.toString()),
                  legacyData: Value(jsonEncode(item)),
                  createdAt: Value(detail.createdAt),
                  updatedAt: Value(detail.updatedAt),
                  isSyncDirty: const Value(true),
                ),
              );
            }
          }
        }

        if (from < 8) {
          await _validateUuidValuesForUniqueIndexes();
          await _createUuidUniqueIndexes();
        }
      });
    },
  );

  Future<void> _createUuidUniqueIndexes() async {
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_pemohons_uuid_unique '
      'ON pemohons (uuid)',
    );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_transaksis_uuid_unique '
      'ON transaksis (uuid)',
    );
  }

  /// Refuse to guess which local record owns a duplicate identity. Rewriting
  /// UUIDs automatically could break links to server records during sync.
  Future<void> _validateUuidValuesForUniqueIndexes() async {
    for (final table in const ['pemohons', 'transaksis']) {
      final blankRows = await customSelect(
        "SELECT COUNT(*) AS count FROM $table WHERE TRIM(uuid) = ''",
      ).getSingle();
      final blankCount = blankRows.read<int>('count');
      if (blankCount > 0) {
        throw StateError(
          'Cannot upgrade to schema V8: $table contains $blankCount '
          'blank UUID value(s). Repair these records before retrying.',
        );
      }

      final duplicates = await customSelect(
        'SELECT uuid, COUNT(*) AS occurrences FROM $table '
        'GROUP BY uuid HAVING COUNT(*) > 1 LIMIT 1',
      ).get();
      if (duplicates.isNotEmpty) {
        final row = duplicates.first;
        final uuid = row.read<String>('uuid');
        final count = row.read<int>('occurrences');
        throw StateError(
          'Cannot upgrade to schema V8: UUID "$uuid" appears $count times '
          'in $table. Resolve duplicates before retrying.',
        );
      }
    }
  }

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