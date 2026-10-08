import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';

class PengeluaranJenisRepository {
  static const _uuid = Uuid();

  final AppDatabase database;

  PengeluaranJenisRepository(this.database);

  Stream<List<PengeluaranJenisData>> watchAll() {
    return (database.select(database.pengeluaranJenis)
          ..where((t) => t.status.equals(1) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.nama)]))
        .watch();
  }

  Future<int> create({
    required String nama,
    int? createdBy,
  }) {
    final now = DateTime.now();

    return database.into(database.pengeluaranJenis).insert(
          PengeluaranJenisCompanion.insert(
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

    final count = await (database.update(database.pengeluaranJenis)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .write(
      PengeluaranJenisCompanion(
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

    final count = await (database.update(database.pengeluaranJenis)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .write(
      PengeluaranJenisCompanion(
        status: const Value(0),
        deletedAt: Value(now),
        updatedAt: Value(now),
        isSyncDirty: const Value(true),
      ),
    );

    return count > 0;
  }
}
