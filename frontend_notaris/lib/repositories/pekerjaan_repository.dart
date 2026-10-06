import 'package:drift/drift.dart';

import '../database/app_database.dart';

class PekerjaanNotarisRepository {
  final PekerjaanDao dao;

  PekerjaanNotarisRepository(this.dao);

  Stream<List<PekerjaanNotarisLocal>> watchAll() => dao.watchPekerjaanNotaris();
  Future<List<PekerjaanNotarisLocal>> getAll() => dao.getPekerjaanNotaris();
  Future<PekerjaanNotarisLocal?> getById(int id) =>
      dao.getPekerjaanNotarisById(id);
  Future<PekerjaanNotarisLocal?> getByUuid(String uuid) =>
      dao.getPekerjaanNotarisByUuid(uuid);

  Future<int> create({
    required String uuid,
    required String nama,
    int? createdBy,
  }) {
    final now = DateTime.now();
    return dao.insertPekerjaanNotaris(
      PekerjaanNotarisLocalsCompanion.insert(
        uuid: uuid,
        nama: nama,
        createdBy: Value(createdBy),
        createdAt: Value(now),
        updatedAt: Value(now),
        isSyncDirty: const Value(true),
      ),
    );
  }

  Future<bool> updateNama({
    required int id,
    required String nama,
    int? updatedBy,
  }) {
    final now = DateTime.now();
    return dao.updatePekerjaanNotaris(
      id,
      PekerjaanNotarisLocalsCompanion(
        nama: Value(nama),
        updatedBy: Value(updatedBy),
        updatedAt: Value(now),
        isSyncDirty: const Value(true),
      ),
    );
  }

  Future<bool> delete(int id) => dao.softDeletePekerjaanNotaris(id, DateTime.now());
}

class PekerjaanPpatRepository {
  final PekerjaanDao dao;

  PekerjaanPpatRepository(this.dao);

  Stream<List<PekerjaanPpatLocal>> watchAll() => dao.watchPekerjaanPpat();
  Future<List<PekerjaanPpatLocal>> getAll() => dao.getPekerjaanPpat();
  Future<PekerjaanPpatLocal?> getById(int id) => dao.getPekerjaanPpatById(id);
  Future<PekerjaanPpatLocal?> getByUuid(String uuid) =>
      dao.getPekerjaanPpatByUuid(uuid);

  Future<int> create({
    required String uuid,
    required String nama,
    int? createdBy,
  }) {
    final now = DateTime.now();
    return dao.insertPekerjaanPpat(
      PekerjaanPpatLocalsCompanion.insert(
        uuid: uuid,
        nama: nama,
        createdBy: Value(createdBy),
        createdAt: Value(now),
        updatedAt: Value(now),
        isSyncDirty: const Value(true),
      ),
    );
  }

  Future<bool> updateNama({
    required int id,
    required String nama,
    int? updatedBy,
  }) {
    final now = DateTime.now();
    return dao.updatePekerjaanPpat(
      id,
      PekerjaanPpatLocalsCompanion(
        nama: Value(nama),
        updatedBy: Value(updatedBy),
        updatedAt: Value(now),
        isSyncDirty: const Value(true),
      ),
    );
  }

  Future<bool> delete(int id) => dao.softDeletePekerjaanPpat(id, DateTime.now());
}
