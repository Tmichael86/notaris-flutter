import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../database/daos/pekerjaan_dao.dart';

class PekerjaanHargaInput {
  final int? id;
  final String harga;
  final int kategoriPekerjaanId;
  final String estimasiWaktu;

  const PekerjaanHargaInput({
    this.id,
    required this.harga,
    required this.kategoriPekerjaanId,
    required this.estimasiWaktu,
  });
}

class PekerjaanAtributInput {
  final int? id;
  final String? atribut;

  const PekerjaanAtributInput({
    this.id,
    this.atribut,
  });
}

class PekerjaanProsesInput {
  final int? id;
  final String nama;
  final String detail;
  final List<PekerjaanAtributInput> atribut;

  const PekerjaanProsesInput({
    this.id,
    required this.nama,
    required this.detail,
    this.atribut = const [],
  });
}

class PekerjaanAggregateInput {
  final String nama;
  final List<PekerjaanHargaInput> harga;
  final List<PekerjaanProsesInput> proses;

  const PekerjaanAggregateInput({
    required this.nama,
    this.harga = const [],
    this.proses = const [],
  });
}

class PekerjaanAggregateData {
  final int id;
  final String nama;
  final List<PekerjaanHargaData> harga;
  final List<PekerjaanProsesData> proses;

  const PekerjaanAggregateData({
    required this.id,
    required this.nama,
    required this.harga,
    required this.proses,
  });
}

class PekerjaanHargaData {
  final int id;
  final int kategoriPekerjaanId;
  final String harga;
  final String estimasiWaktu;

  const PekerjaanHargaData({
    required this.id,
    required this.kategoriPekerjaanId,
    required this.harga,
    required this.estimasiWaktu,
  });
}

class PekerjaanProsesData {
  final int id;
  final String nama;
  final String detail;
  final List<PekerjaanAtributData> atribut;

  const PekerjaanProsesData({
    required this.id,
    required this.nama,
    required this.detail,
    required this.atribut,
  });
}

class PekerjaanAtributData {
  final int id;
  final String? atribut;

  const PekerjaanAtributData({
    required this.id,
    required this.atribut,
  });
}

class PekerjaanNotarisRepository {
  static const _uuid = Uuid();

  final PekerjaanDao dao;

  PekerjaanNotarisRepository(this.dao);

  Stream<List<PekerjaanNotarisLocal>> watchAll() => dao.watchPekerjaanNotaris();

  Future<List<PekerjaanNotarisLocal>> getAll() => dao.getPekerjaanNotaris();

  Future<PekerjaanNotarisLocal?> getById(int id) =>
      dao.getPekerjaanNotarisById(id);

  Future<PekerjaanNotarisLocal?> getByUuid(String uuid) =>
      dao.getPekerjaanNotarisByUuid(uuid);

  Future<PekerjaanAggregateData?> getAggregate(int id) async {
    final parent = await dao.getPekerjaanNotarisById(id);
    if (parent == null || parent.status != 1) return null;

    final harga = await dao.getHargaNotaris(id);
    final proses = await dao.getProsesNotaris(id);

    return PekerjaanAggregateData(
      id: parent.id,
      nama: parent.nama,
      harga: [
        for (final item in harga)
          PekerjaanHargaData(
            id: item.id,
            kategoriPekerjaanId: item.kategoriPekerjaanId,
            harga: item.harga,
            estimasiWaktu: item.estimasiWaktu,
          ),
      ],
      proses: [
        for (final item in proses)
          PekerjaanProsesData(
            id: item.id,
            nama: item.nama,
            detail: item.detail,
            atribut: [
              for (final attribute in await dao.getAtributNotaris(item.id))
                PekerjaanAtributData(
                  id: attribute.id,
                  atribut: attribute.atribut,
                ),
            ],
          ),
      ],
    );
  }


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

  /// Creates a complete Notaris aggregate atomically:
  /// pekerjaan -> harga + proses -> atribut.
  Future<int> createAggregate({
    required PekerjaanAggregateInput input,
    int? createdBy,
  }) async {
    final now = DateTime.now();

    return dao.attachedDatabase.transaction(() async {
      final pekerjaanId = await dao.insertPekerjaanNotaris(
        PekerjaanNotarisLocalsCompanion.insert(
          uuid: _uuid.v4(),
          nama: input.nama,
          createdBy: Value(createdBy),
          createdAt: Value(now),
          updatedAt: Value(now),
          isSyncDirty: const Value(true),
        ),
      );

      for (final harga in input.harga) {
        await dao.insertHargaNotaris(
          PekerjaanNotarisHargaLocalsCompanion.insert(
            uuid: _uuid.v4(),
            pekerjaanNotarisId: pekerjaanId,
            harga: harga.harga,
            kategoriPekerjaanId: harga.kategoriPekerjaanId,
            estimasiWaktu: harga.estimasiWaktu,
            createdBy: Value(createdBy),
            createdAt: Value(now),
            updatedAt: Value(now),
            isSyncDirty: const Value(true),
          ),
        );
      }

      for (final proses in input.proses) {
        final prosesId = await dao.insertProsesNotaris(
          PekerjaanNotarisProsesLocalsCompanion.insert(
            uuid: _uuid.v4(),
            pekerjaanNotarisId: pekerjaanId,
            nama: proses.nama,
            detail: proses.detail,
            createdBy: Value(createdBy),
            createdAt: Value(now),
            updatedAt: Value(now),
            isSyncDirty: const Value(true),
          ),
        );

        for (final atribut in proses.atribut) {
          await dao.insertAtributNotaris(
            PekerjaanNotarisAtributLocalsCompanion.insert(
              uuid: _uuid.v4(),
              pekerjaanNotarisId: pekerjaanId,
              prosesPekerjaanNotarisId: prosesId,
              atribut: Value(atribut.atribut),
              createdBy: Value(createdBy),
              createdAt: Value(now),
              updatedAt: Value(now),
              isSyncDirty: const Value(true),
            ),
          );
        }
      }

      return pekerjaanId;
    });
  }

  /// Updates the complete aggregate atomically.
  ///
  /// Existing child rows keep their local IDs. Rows removed from the input
  /// are soft-deleted so future sync can still see the deletion.
  Future<bool> updateAggregate({
    required int id,
    required PekerjaanAggregateInput input,
    int? updatedBy,
  }) async {
    final now = DateTime.now();

    return dao.attachedDatabase.transaction(() async {
      final parent = await dao.getPekerjaanNotarisById(id);
      if (parent == null) return false;

      final updated = await dao.updatePekerjaanNotaris(
        id,
        PekerjaanNotarisLocalsCompanion(
          nama: Value(input.nama),
          updatedBy: Value(updatedBy),
          updatedAt: Value(now),
          isSyncDirty: const Value(true),
        ),
      );
      if (!updated) return false;

      final existingHarga = await dao.getHargaNotaris(id);
      final incomingHargaIds = input.harga
          .where((item) => item.id != null)
          .map((item) => item.id!)
          .toSet();

      for (final existing in existingHarga) {
        if (!incomingHargaIds.contains(existing.id)) {
          await dao.softDeleteHargaNotaris(existing.id, now);
        }
      }

      for (final harga in input.harga) {
        if (harga.id == null) {
          await dao.insertHargaNotaris(
            PekerjaanNotarisHargaLocalsCompanion.insert(
              uuid: _uuid.v4(),
              pekerjaanNotarisId: id,
              harga: harga.harga,
              kategoriPekerjaanId: harga.kategoriPekerjaanId,
              estimasiWaktu: harga.estimasiWaktu,
              createdBy: Value(updatedBy),
              createdAt: Value(now),
              updatedAt: Value(now),
              isSyncDirty: const Value(true),
            ),
          );
        } else {
          await dao.updateHargaNotaris(
            harga.id!,
            PekerjaanNotarisHargaLocalsCompanion(
              harga: Value(harga.harga),
              kategoriPekerjaanId: Value(harga.kategoriPekerjaanId),
              estimasiWaktu: Value(harga.estimasiWaktu),
              updatedBy: Value(updatedBy),
              updatedAt: Value(now),
              isSyncDirty: const Value(true),
            ),
          );
        }
      }

      final existingProses = await dao.getProsesNotaris(id);
      final incomingProsesIds = input.proses
          .where((item) => item.id != null)
          .map((item) => item.id!)
          .toSet();

      for (final existing in existingProses) {
        if (!incomingProsesIds.contains(existing.id)) {
          await _softDeleteNotarisProsesTree(existing.id, now);
        }
      }

      for (final proses in input.proses) {
        final prosesId = proses.id ??
            await dao.insertProsesNotaris(
              PekerjaanNotarisProsesLocalsCompanion.insert(
                uuid: _uuid.v4(),
                pekerjaanNotarisId: id,
                nama: proses.nama,
                detail: proses.detail,
                createdBy: Value(updatedBy),
                createdAt: Value(now),
                updatedAt: Value(now),
                isSyncDirty: const Value(true),
              ),
            );

        if (proses.id != null) {
          await dao.updateProsesNotaris(
            prosesId,
            PekerjaanNotarisProsesLocalsCompanion(
              nama: Value(proses.nama),
              detail: Value(proses.detail),
              updatedBy: Value(updatedBy),
              updatedAt: Value(now),
              isSyncDirty: const Value(true),
            ),
          );
        }

        final existingAtribut = await dao.getAtributNotaris(prosesId);
        final incomingAtributIds = proses.atribut
            .where((item) => item.id != null)
            .map((item) => item.id!)
            .toSet();

        for (final existing in existingAtribut) {
          if (!incomingAtributIds.contains(existing.id)) {
            await dao.softDeleteAtributNotaris(existing.id, now);
          }
        }

        for (final atribut in proses.atribut) {
          if (atribut.id == null) {
            await dao.insertAtributNotaris(
              PekerjaanNotarisAtributLocalsCompanion.insert(
                uuid: _uuid.v4(),
                pekerjaanNotarisId: id,
                prosesPekerjaanNotarisId: prosesId,
                atribut: Value(atribut.atribut),
                createdBy: Value(updatedBy),
                createdAt: Value(now),
                updatedAt: Value(now),
                isSyncDirty: const Value(true),
              ),
            );
          } else {
            await dao.updateAtributNotaris(
              atribut.id!,
              PekerjaanNotarisAtributLocalsCompanion(
                atribut: Value(atribut.atribut),
                updatedBy: Value(updatedBy),
                updatedAt: Value(now),
                isSyncDirty: const Value(true),
              ),
            );
          }
        }
      }

      return true;
    });
  }

  Future<void> _softDeleteNotarisProsesTree(int prosesId, DateTime now) async {
    final atribut = await dao.getAtributNotaris(prosesId);

    for (final item in atribut) {
      await dao.softDeleteAtributNotaris(item.id, now);
    }

    await dao.softDeleteProsesNotaris(prosesId, now);
  }

  Future<bool> deleteAggregate(int id) async {
    final now = DateTime.now();

    return dao.attachedDatabase.transaction(() async {
      final parent = await dao.getPekerjaanNotarisById(id);
      if (parent == null) return false;

      for (final harga in await dao.getHargaNotaris(id)) {
        await dao.softDeleteHargaNotaris(harga.id, now);
      }

      for (final proses in await dao.getProsesNotaris(id)) {
        await _softDeleteNotarisProsesTree(proses.id, now);
      }

      return dao.softDeletePekerjaanNotaris(id, now);
    });
  }
}

class PekerjaanPpatRepository {
  static const _uuid = Uuid();

  final PekerjaanDao dao;

  PekerjaanPpatRepository(this.dao);

  Stream<List<PekerjaanPpatLocal>> watchAll() => dao.watchPekerjaanPpat();

  Future<List<PekerjaanPpatLocal>> getAll() => dao.getPekerjaanPpat();

  Future<PekerjaanPpatLocal?> getById(int id) => dao.getPekerjaanPpatById(id);

  Future<PekerjaanPpatLocal?> getByUuid(String uuid) =>
      dao.getPekerjaanPpatByUuid(uuid);

  Future<PekerjaanAggregateData?> getAggregate(int id) async {
    final parent = await dao.getPekerjaanPpatById(id);
    if (parent == null || parent.status != 1) return null;

    final harga = await dao.getHargaPpat(id);
    final proses = await dao.getProsesPpat(id);

    return PekerjaanAggregateData(
      id: parent.id,
      nama: parent.nama,
      harga: [
        for (final item in harga)
          PekerjaanHargaData(
            id: item.id,
            kategoriPekerjaanId: item.kategoriPekerjaanId,
            harga: item.harga,
            estimasiWaktu: item.estimasiWaktu,
          ),
      ],
      proses: [
        for (final item in proses)
          PekerjaanProsesData(
            id: item.id,
            nama: item.nama,
            detail: item.detail,
            atribut: [
              for (final attribute in await dao.getAtributPpat(item.id))
                PekerjaanAtributData(
                  id: attribute.id,
                  atribut: attribute.atribut,
                ),
            ],
          ),
      ],
    );
  }

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

  Future<int> createAggregate({
    required PekerjaanAggregateInput input,
    int? createdBy,
  }) async {
    final now = DateTime.now();

    return dao.attachedDatabase.transaction(() async {
      final pekerjaanId = await dao.insertPekerjaanPpat(
        PekerjaanPpatLocalsCompanion.insert(
          uuid: _uuid.v4(),
          nama: input.nama,
          createdBy: Value(createdBy),
          createdAt: Value(now),
          updatedAt: Value(now),
          isSyncDirty: const Value(true),
        ),
      );

      for (final harga in input.harga) {
        await dao.insertHargaPpat(
          PekerjaanPpatHargaLocalsCompanion.insert(
            uuid: _uuid.v4(),
            pekerjaanPpatId: pekerjaanId,
            harga: harga.harga,
            kategoriPekerjaanId: harga.kategoriPekerjaanId,
            estimasiWaktu: harga.estimasiWaktu,
            createdBy: Value(createdBy),
            createdAt: Value(now),
            updatedAt: Value(now),
            isSyncDirty: const Value(true),
          ),
        );
      }

      for (final proses in input.proses) {
        final prosesId = await dao.insertProsesPpat(
          PekerjaanPpatProsesLocalsCompanion.insert(
            uuid: _uuid.v4(),
            pekerjaanPpatId: pekerjaanId,
            nama: proses.nama,
            detail: proses.detail,
            createdBy: Value(createdBy),
            createdAt: Value(now),
            updatedAt: Value(now),
            isSyncDirty: const Value(true),
          ),
        );

        for (final atribut in proses.atribut) {
          await dao.insertAtributPpat(
            PekerjaanPpatAtributLocalsCompanion.insert(
              uuid: _uuid.v4(),
              pekerjaanPpatId: pekerjaanId,
              prosesPekerjaanPpatId: prosesId,
              atribut: Value(atribut.atribut),
              createdBy: Value(createdBy),
              createdAt: Value(now),
              updatedAt: Value(now),
              isSyncDirty: const Value(true),
            ),
          );
        }
      }

      return pekerjaanId;
    });
  }

  Future<bool> updateAggregate({
    required int id,
    required PekerjaanAggregateInput input,
    int? updatedBy,
  }) async {
    final now = DateTime.now();

    return dao.attachedDatabase.transaction(() async {
      final parent = await dao.getPekerjaanPpatById(id);
      if (parent == null) return false;

      final updated = await dao.updatePekerjaanPpat(
        id,
        PekerjaanPpatLocalsCompanion(
          nama: Value(input.nama),
          updatedBy: Value(updatedBy),
          updatedAt: Value(now),
          isSyncDirty: const Value(true),
        ),
      );
      if (!updated) return false;

      final existingHarga = await dao.getHargaPpat(id);
      final incomingHargaIds = input.harga
          .where((item) => item.id != null)
          .map((item) => item.id!)
          .toSet();

      for (final existing in existingHarga) {
        if (!incomingHargaIds.contains(existing.id)) {
          await dao.softDeleteHargaPpat(existing.id, now);
        }
      }

      for (final harga in input.harga) {
        if (harga.id == null) {
          await dao.insertHargaPpat(
            PekerjaanPpatHargaLocalsCompanion.insert(
              uuid: _uuid.v4(),
              pekerjaanPpatId: id,
              harga: harga.harga,
              kategoriPekerjaanId: harga.kategoriPekerjaanId,
              estimasiWaktu: harga.estimasiWaktu,
              createdBy: Value(updatedBy),
              createdAt: Value(now),
              updatedAt: Value(now),
              isSyncDirty: const Value(true),
            ),
          );
        } else {
          await dao.updateHargaPpat(
            harga.id!,
            PekerjaanPpatHargaLocalsCompanion(
              harga: Value(harga.harga),
              kategoriPekerjaanId: Value(harga.kategoriPekerjaanId),
              estimasiWaktu: Value(harga.estimasiWaktu),
              updatedBy: Value(updatedBy),
              updatedAt: Value(now),
              isSyncDirty: const Value(true),
            ),
          );
        }
      }

      final existingProses = await dao.getProsesPpat(id);
      final incomingProsesIds = input.proses
          .where((item) => item.id != null)
          .map((item) => item.id!)
          .toSet();

      for (final existing in existingProses) {
        if (!incomingProsesIds.contains(existing.id)) {
          await _softDeletePpatProsesTree(existing.id, now);
        }
      }

      for (final proses in input.proses) {
        final prosesId = proses.id ??
            await dao.insertProsesPpat(
              PekerjaanPpatProsesLocalsCompanion.insert(
                uuid: _uuid.v4(),
                pekerjaanPpatId: id,
                nama: proses.nama,
                detail: proses.detail,
                createdBy: Value(updatedBy),
                createdAt: Value(now),
                updatedAt: Value(now),
                isSyncDirty: const Value(true),
              ),
            );

        if (proses.id != null) {
          await dao.updateProsesPpat(
            prosesId,
            PekerjaanPpatProsesLocalsCompanion(
              nama: Value(proses.nama),
              detail: Value(proses.detail),
              updatedBy: Value(updatedBy),
              updatedAt: Value(now),
              isSyncDirty: const Value(true),
            ),
          );
        }

        final existingAtribut = await dao.getAtributPpat(prosesId);
        final incomingAtributIds = proses.atribut
            .where((item) => item.id != null)
            .map((item) => item.id!)
            .toSet();

        for (final existing in existingAtribut) {
          if (!incomingAtributIds.contains(existing.id)) {
            await dao.softDeleteAtributPpat(existing.id, now);
          }
        }

        for (final atribut in proses.atribut) {
          if (atribut.id == null) {
            await dao.insertAtributPpat(
              PekerjaanPpatAtributLocalsCompanion.insert(
                uuid: _uuid.v4(),
                pekerjaanPpatId: id,
                prosesPekerjaanPpatId: prosesId,
                atribut: Value(atribut.atribut),
                createdBy: Value(updatedBy),
                createdAt: Value(now),
                updatedAt: Value(now),
                isSyncDirty: const Value(true),
              ),
            );
          } else {
            await dao.updateAtributPpat(
              atribut.id!,
              PekerjaanPpatAtributLocalsCompanion(
                atribut: Value(atribut.atribut),
                updatedBy: Value(updatedBy),
                updatedAt: Value(now),
                isSyncDirty: const Value(true),
              ),
            );
          }
        }
      }

      return true;
    });
  }

  Future<void> _softDeletePpatProsesTree(int prosesId, DateTime now) async {
    final atribut = await dao.getAtributPpat(prosesId);

    for (final item in atribut) {
      await dao.softDeleteAtributPpat(item.id, now);
    }

    await dao.softDeleteProsesPpat(prosesId, now);
  }

  Future<bool> deleteAggregate(int id) async {
    final now = DateTime.now();

    return dao.attachedDatabase.transaction(() async {
      final parent = await dao.getPekerjaanPpatById(id);
      if (parent == null) return false;

      for (final harga in await dao.getHargaPpat(id)) {
        await dao.softDeleteHargaPpat(harga.id, now);
      }

      for (final proses in await dao.getProsesPpat(id)) {
        await _softDeletePpatProsesTree(proses.id, now);
      }

      return dao.softDeletePekerjaanPpat(id, now);
    });
  }
}
