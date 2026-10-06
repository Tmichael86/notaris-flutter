import 'package:drift/drift.dart';

import '../app_database.dart';
import '../pekerjaan_tables.dart';

part 'pekerjaan_dao.g.dart';

@DriftAccessor(
  tables: [
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
class PekerjaanDao extends DatabaseAccessor<AppDatabase>
    with _$PekerjaanDaoMixin {
  PekerjaanDao(super.db);

  Future<List<PekerjaanKategori>> getActivePekerjaanKategori() =>
      (select(attachedDatabase.pekerjaanKategoris)
            ..where((t) => t.status.equals(1) & t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.nama)]))
          .get();

  Stream<List<PekerjaanKategori>> watchActivePekerjaanKategori() =>
      (select(attachedDatabase.pekerjaanKategoris)
            ..where((t) => t.status.equals(1) & t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.nama)]))
          .watch();

  Stream<List<PekerjaanNotarisLocal>> watchPekerjaanNotaris() =>
      (select(pekerjaanNotarisLocals)
            ..where((t) => t.status.equals(1) & t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.nama)]))
          .watch();

  Future<List<PekerjaanNotarisLocal>> getPekerjaanNotaris() =>
      (select(pekerjaanNotarisLocals)
            ..where((t) => t.status.equals(1) & t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.nama)]))
          .get();

  Future<PekerjaanNotarisLocal?> getPekerjaanNotarisById(int id) =>
      (select(pekerjaanNotarisLocals)
            ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
          .getSingleOrNull();

  Future<PekerjaanNotarisLocal?> getPekerjaanNotarisByUuid(String uuid) =>
      (select(pekerjaanNotarisLocals)
            ..where((t) => t.uuid.equals(uuid) & t.deletedAt.isNull()))
          .getSingleOrNull();

  Future<int> insertPekerjaanNotaris(
    PekerjaanNotarisLocalsCompanion entry,
  ) =>
      into(pekerjaanNotarisLocals).insert(entry);

  Future<bool> updatePekerjaanNotaris(
    int id,
    PekerjaanNotarisLocalsCompanion entry,
  ) =>
      (update(pekerjaanNotarisLocals)..where((t) => t.id.equals(id)))
          .write(entry)
          .then((count) => count > 0);

  Future<bool> softDeletePekerjaanNotaris(int id, DateTime now) =>
      (update(pekerjaanNotarisLocals)..where((t) => t.id.equals(id)))
          .write(PekerjaanNotarisLocalsCompanion(
            status: const Value(0),
            deletedAt: Value(now),
            updatedAt: Value(now),
            isSyncDirty: const Value(true),
          ))
          .then((count) => count > 0);

  Future<List<PekerjaanNotarisHargaLocal>> getHargaNotaris(int pekerjaanId) =>
      (select(pekerjaanNotarisHargaLocals)
            ..where((t) =>
                t.pekerjaanNotarisId.equals(pekerjaanId) &
                t.status.equals(1) &
                t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .get();

  Future<int> insertHargaNotaris(
    PekerjaanNotarisHargaLocalsCompanion entry,
  ) =>
      into(pekerjaanNotarisHargaLocals).insert(entry);

  Future<bool> updateHargaNotaris(
    int id,
    PekerjaanNotarisHargaLocalsCompanion entry,
  ) =>
      (update(pekerjaanNotarisHargaLocals)..where((t) => t.id.equals(id)))
          .write(entry)
          .then((count) => count > 0);

  Future<bool> softDeleteHargaNotaris(int id, DateTime now) =>
      (update(pekerjaanNotarisHargaLocals)..where((t) => t.id.equals(id)))
          .write(PekerjaanNotarisHargaLocalsCompanion(
            status: const Value(0),
            deletedAt: Value(now),
            updatedAt: Value(now),
            isSyncDirty: const Value(true),
          ))
          .then((count) => count > 0);

  Future<List<PekerjaanNotarisProsesLocal>> getProsesNotaris(int pekerjaanId) =>
      (select(pekerjaanNotarisProsesLocals)
            ..where((t) =>
                t.pekerjaanNotarisId.equals(pekerjaanId) &
                t.status.equals(1) &
                t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .get();

  Future<int> insertProsesNotaris(
    PekerjaanNotarisProsesLocalsCompanion entry,
  ) =>
      into(pekerjaanNotarisProsesLocals).insert(entry);

  Future<bool> updateProsesNotaris(
    int id,
    PekerjaanNotarisProsesLocalsCompanion entry,
  ) =>
      (update(pekerjaanNotarisProsesLocals)..where((t) => t.id.equals(id)))
          .write(entry)
          .then((count) => count > 0);

  Future<bool> softDeleteProsesNotaris(int id, DateTime now) =>
      (update(pekerjaanNotarisProsesLocals)..where((t) => t.id.equals(id)))
          .write(PekerjaanNotarisProsesLocalsCompanion(
            status: const Value(0),
            deletedAt: Value(now),
            updatedAt: Value(now),
            isSyncDirty: const Value(true),
          ))
          .then((count) => count > 0);

  Future<List<PekerjaanNotarisAtributLocal>> getAtributNotaris(int prosesId) =>
      (select(pekerjaanNotarisAtributLocals)
            ..where((t) =>
                t.prosesPekerjaanNotarisId.equals(prosesId) &
                t.status.equals(1) &
                t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .get();

  Future<int> insertAtributNotaris(
    PekerjaanNotarisAtributLocalsCompanion entry,
  ) =>
      into(pekerjaanNotarisAtributLocals).insert(entry);

  Future<bool> updateAtributNotaris(
    int id,
    PekerjaanNotarisAtributLocalsCompanion entry,
  ) =>
      (update(pekerjaanNotarisAtributLocals)..where((t) => t.id.equals(id)))
          .write(entry)
          .then((count) => count > 0);

  Future<bool> softDeleteAtributNotaris(int id, DateTime now) =>
      (update(pekerjaanNotarisAtributLocals)..where((t) => t.id.equals(id)))
          .write(PekerjaanNotarisAtributLocalsCompanion(
            status: const Value(0),
            deletedAt: Value(now),
            updatedAt: Value(now),
            isSyncDirty: const Value(true),
          ))
          .then((count) => count > 0);

  Stream<List<PekerjaanPpatLocal>> watchPekerjaanPpat() =>
      (select(pekerjaanPpatLocals)
            ..where((t) => t.status.equals(1) & t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.nama)]))
          .watch();

  Future<List<PekerjaanPpatLocal>> getPekerjaanPpat() =>
      (select(pekerjaanPpatLocals)
            ..where((t) => t.status.equals(1) & t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.nama)]))
          .get();

  Future<PekerjaanPpatLocal?> getPekerjaanPpatById(int id) =>
      (select(pekerjaanPpatLocals)
            ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
          .getSingleOrNull();

  Future<PekerjaanPpatLocal?> getPekerjaanPpatByUuid(String uuid) =>
      (select(pekerjaanPpatLocals)
            ..where((t) => t.uuid.equals(uuid) & t.deletedAt.isNull()))
          .getSingleOrNull();

  Future<int> insertPekerjaanPpat(PekerjaanPpatLocalsCompanion entry) =>
      into(pekerjaanPpatLocals).insert(entry);

  Future<bool> updatePekerjaanPpat(
    int id,
    PekerjaanPpatLocalsCompanion entry,
  ) =>
      (update(pekerjaanPpatLocals)..where((t) => t.id.equals(id)))
          .write(entry)
          .then((count) => count > 0);

  Future<bool> softDeletePekerjaanPpat(int id, DateTime now) =>
      (update(pekerjaanPpatLocals)..where((t) => t.id.equals(id)))
          .write(PekerjaanPpatLocalsCompanion(
            status: const Value(0),
            deletedAt: Value(now),
            updatedAt: Value(now),
            isSyncDirty: const Value(true),
          ))
          .then((count) => count > 0);

  Future<List<PekerjaanPpatHargaLocal>> getHargaPpat(int pekerjaanId) =>
      (select(pekerjaanPpatHargaLocals)
            ..where((t) =>
                t.pekerjaanPpatId.equals(pekerjaanId) &
                t.status.equals(1) &
                t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .get();

  Future<int> insertHargaPpat(PekerjaanPpatHargaLocalsCompanion entry) =>
      into(pekerjaanPpatHargaLocals).insert(entry);

  Future<bool> updateHargaPpat(
    int id,
    PekerjaanPpatHargaLocalsCompanion entry,
  ) =>
      (update(pekerjaanPpatHargaLocals)..where((t) => t.id.equals(id)))
          .write(entry)
          .then((count) => count > 0);

  Future<bool> softDeleteHargaPpat(int id, DateTime now) =>
      (update(pekerjaanPpatHargaLocals)..where((t) => t.id.equals(id)))
          .write(PekerjaanPpatHargaLocalsCompanion(
            status: const Value(0),
            deletedAt: Value(now),
            updatedAt: Value(now),
            isSyncDirty: const Value(true),
          ))
          .then((count) => count > 0);

  Future<List<PekerjaanPpatProsesLocal>> getProsesPpat(int pekerjaanId) =>
      (select(pekerjaanPpatProsesLocals)
            ..where((t) =>
                t.pekerjaanPpatId.equals(pekerjaanId) &
                t.status.equals(1) &
                t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .get();

  Future<int> insertProsesPpat(PekerjaanPpatProsesLocalsCompanion entry) =>
      into(pekerjaanPpatProsesLocals).insert(entry);

  Future<bool> updateProsesPpat(
    int id,
    PekerjaanPpatProsesLocalsCompanion entry,
  ) =>
      (update(pekerjaanPpatProsesLocals)..where((t) => t.id.equals(id)))
          .write(entry)
          .then((count) => count > 0);

  Future<bool> softDeleteProsesPpat(int id, DateTime now) =>
      (update(pekerjaanPpatProsesLocals)..where((t) => t.id.equals(id)))
          .write(PekerjaanPpatProsesLocalsCompanion(
            status: const Value(0),
            deletedAt: Value(now),
            updatedAt: Value(now),
            isSyncDirty: const Value(true),
          ))
          .then((count) => count > 0);

  Future<List<PekerjaanPpatAtributLocal>> getAtributPpat(int prosesId) =>
      (select(pekerjaanPpatAtributLocals)
            ..where((t) =>
                t.prosesPekerjaanPpatId.equals(prosesId) &
                t.status.equals(1) &
                t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .get();

  Future<int> insertAtributPpat(
    PekerjaanPpatAtributLocalsCompanion entry,
  ) =>
      into(pekerjaanPpatAtributLocals).insert(entry);

  Future<bool> updateAtributPpat(
    int id,
    PekerjaanPpatAtributLocalsCompanion entry,
  ) =>
      (update(pekerjaanPpatAtributLocals)..where((t) => t.id.equals(id)))
          .write(entry)
          .then((count) => count > 0);

  Future<bool> softDeleteAtributPpat(int id, DateTime now) =>
      (update(pekerjaanPpatAtributLocals)..where((t) => t.id.equals(id)))
          .write(PekerjaanPpatAtributLocalsCompanion(
            status: const Value(0),
            deletedAt: Value(now),
            updatedAt: Value(now),
            isSyncDirty: const Value(true),
          ))
          .then((count) => count > 0);
}
