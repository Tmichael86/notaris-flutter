import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';

class PekerjaanKategoriRepository {
  static const _uuid = Uuid();

  final AppDatabase database;

  PekerjaanKategoriRepository(this.database);

  Stream<List<PekerjaanKategori>> watchAll() {
    return (database.select(database.pekerjaanKategoris)
          ..where((t) => t.status.equals(1) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.nama)]))
        .watch();
  }

  Future<int> create({
    required String nama,
    int? createdBy,
  }) {
    final now = DateTime.now();

    return database.into(database.pekerjaanKategoris).insert(
          PekerjaanKategorisCompanion.insert(
            uuid: _uuid.v4(),
            nama: nama,
            createdBy: Value(createdBy),
            createdAt: Value(now),
            updatedAt: Value(now),
            isSyncDirty: const Value(true),
          ),
        );
  }

  Future<bool> update({
    required int id,
    required String nama,
    int? updatedBy,
  }) async {
    final now = DateTime.now();

    final count = await (database.update(database.pekerjaanKategoris)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .write(
      PekerjaanKategorisCompanion(
        nama: Value(nama),
        updatedBy: Value(updatedBy),
        updatedAt: Value(now),
        isSyncDirty: const Value(true),
      ),
    );

    return count > 0;
  }

  Future<bool> delete(int id) async {
    final now = DateTime.now();

    final count = await (database.update(database.pekerjaanKategoris)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .write(
      PekerjaanKategorisCompanion(
        status: const Value(0),
        deletedAt: Value(now),
        updatedAt: Value(now),
        isSyncDirty: const Value(true),
      ),
    );

    return count > 0;
  }
}
