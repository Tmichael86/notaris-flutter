import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../services/kategori_pekerjaan_api_service.dart';

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

  /// Merges active cloud categories into the local cache by stable UUID.
  /// Local dirty rows are intentionally preserved until their changes are synced.
  Future<void> syncFromCloud(
    List<KategoriPekerjaanApiModel> remoteCategories,
  ) async {
    final now = DateTime.now();

    await database.transaction(() async {
      for (final remote in remoteCategories) {
        if (remote.uuid.isEmpty) {
          throw const FormatException(
            'UUID kategori pekerjaan dari server tidak tersedia.',
          );
        }

        final existing = await (database.select(
          database.pekerjaanKategoris,
        )..where((t) => t.uuid.equals(remote.uuid))).getSingleOrNull();

        if (existing != null && existing.isSyncDirty) {
          continue;
        }

        final createdAt = remote.createdAt ?? now;
        final updatedAt = remote.updatedAt ?? createdAt;
        final companion = PekerjaanKategorisCompanion(
          uuid: Value(remote.uuid),
          nama: Value(remote.nama),
          createdAt: Value(createdAt),
          updatedAt: Value(updatedAt),
          status: Value(remote.status),
          isSyncDirty: const Value(false),
          lastSyncedAt: Value(now),
          deletedAt: const Value(null),
        );

        if (existing == null) {
          await database
              .into(database.pekerjaanKategoris)
              .insert(
                PekerjaanKategorisCompanion.insert(
                  uuid: remote.uuid,
                  nama: remote.nama,
                  createdAt: Value(createdAt),
                  updatedAt: Value(updatedAt),
                  status: Value(remote.status),
                  isSyncDirty: const Value(false),
                  lastSyncedAt: Value(now),
                ),
              );
        } else {
          await (database.update(
            database.pekerjaanKategoris,
          )..where((t) => t.uuid.equals(remote.uuid))).write(companion);
        }
      }
    });
  }

  /// Pushes dirty local categories in deterministic order. A row is marked clean
  /// only after the API confirms its upsert/deactivation.
  Future<int> syncToCloud(KategoriPekerjaanApiService api) async {
    final dirtyRows = await (database.select(
      database.pekerjaanKategoris,
    )..where((t) => t.isSyncDirty.equals(true))).get();
    var synced = 0;

    for (final row in dirtyRows) {
      if (row.uuid.trim().isEmpty) {
        throw StateError('Kategori lokal ${row.id} tidak memiliki UUID.');
      }

      if (row.status == 0 || row.deletedAt != null) {
        await api.syncDeactivate(uuid: row.uuid);
      } else {
        await api.syncUpsert(uuid: row.uuid, nama: row.nama);
      }

      final now = DateTime.now();
      await (database.update(
            database.pekerjaanKategoris,
          )..where((t) => t.uuid.equals(row.uuid) & t.isSyncDirty.equals(true)))
          .write(
            PekerjaanKategorisCompanion(
              isSyncDirty: const Value(false),
              lastSyncedAt: Value(now),
            ),
          );
      synced++;
    }

    return synced;
  }

  Future<int> create({required String nama, int? createdBy}) async {
    final normalizedNama = _normalizeNama(nama);
    await _validateNama(normalizedNama);

    final now = DateTime.now();

    return database
        .into(database.pekerjaanKategoris)
        .insert(
          PekerjaanKategorisCompanion.insert(
            uuid: _uuid.v4(),
            nama: normalizedNama,
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
    final normalizedNama = _normalizeNama(nama);
    await _validateNama(normalizedNama, excludeId: id);

    final now = DateTime.now();

    final count =
        await (database.update(database.pekerjaanKategoris)..where(
              (t) =>
                  t.id.equals(id) & t.status.equals(1) & t.deletedAt.isNull(),
            ))
            .write(
              PekerjaanKategorisCompanion(
                nama: Value(normalizedNama),
                updatedBy: Value(updatedBy),
                updatedAt: Value(now),
                isSyncDirty: const Value(true),
              ),
            );

    return count > 0;
  }

  Future<bool> delete(int id) async {
    final now = DateTime.now();

    final count =
        await (database.update(database.pekerjaanKategoris)..where(
              (t) =>
                  t.id.equals(id) & t.status.equals(1) & t.deletedAt.isNull(),
            ))
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

  String _normalizeNama(String nama) {
    final normalized = nama.trim();

    if (normalized.isEmpty) {
      throw ArgumentError('Nama kategori pekerjaan wajib diisi.');
    }

    return normalized;
  }

  Future<void> _validateNama(String normalizedNama, {int? excludeId}) async {
    final categories = await (database.select(
      database.pekerjaanKategoris,
    )..where((t) => t.status.equals(1) & t.deletedAt.isNull())).get();

    final duplicate = categories.any((category) {
      if (excludeId != null && category.id == excludeId) {
        return false;
      }

      return category.nama.trim().toLowerCase() == normalizedNama.toLowerCase();
    });

    if (duplicate) {
      throw ArgumentError(
        'Kategori pekerjaan "$normalizedNama" sudah tersedia.',
      );
    }
  }
}
