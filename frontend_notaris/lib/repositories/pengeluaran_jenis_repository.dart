import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../services/jenis_pengeluaran_api_service.dart';

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

  /// Merge cloud rows by stable UUID without overwriting unsynced local edits.
  Future<void> syncFromCloud(
    List<JenisPengeluaranApiModel> remoteItems,
  ) async {
    final now = DateTime.now();

    await database.transaction(() async {
      for (final remote in remoteItems) {
        if (remote.uuid.trim().isEmpty) {
          throw const FormatException(
            'UUID jenis pengeluaran dari server tidak tersedia.',
          );
        }

        final existing = await (database.select(
          database.pengeluaranJenis,
        )..where((t) => t.uuid.equals(remote.uuid))).getSingleOrNull();

        if (existing != null && existing.isSyncDirty) continue;

        final createdAt = remote.createdAt ?? now;
        final updatedAt = remote.updatedAt ?? createdAt;
        final companion = PengeluaranJenisCompanion(
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
          await database.into(database.pengeluaranJenis).insert(
                PengeluaranJenisCompanion.insert(
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
          await (database.update(database.pengeluaranJenis)
                ..where((t) => t.uuid.equals(remote.uuid)))
              .write(companion);
        }
      }
    });
  }

  /// Push dirty rows and clear dirty state only if the row has not changed
  /// while the network request was in flight.
  Future<int> syncToCloud(JenisPengeluaranApiService api) async {
    final dirtyRows = await (database.select(database.pengeluaranJenis)
          ..where((t) => t.isSyncDirty.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
    var synced = 0;

    for (final row in dirtyRows) {
      if (row.uuid.trim().isEmpty) {
        throw StateError('Jenis pengeluaran lokal ${row.id} tidak memiliki UUID.');
      }

      if (row.status == 0 || row.deletedAt != null) {
        await api.syncDeactivate(uuid: row.uuid);
      } else {
        await api.syncUpsert(uuid: row.uuid, nama: row.nama);
      }

      final now = DateTime.now();
      await (database.update(database.pengeluaranJenis)
            ..where(
              (t) =>
                  t.uuid.equals(row.uuid) &
                  t.isSyncDirty.equals(true) &
                  t.updatedAt.equalsNullable(row.updatedAt) &
                  t.status.equals(row.status),
            ))
          .write(
        PengeluaranJenisCompanion(
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
        .into(database.pengeluaranJenis)
        .insert(
          PengeluaranJenisCompanion.insert(
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
        await (database.update(database.pengeluaranJenis)..where(
              (t) =>
                  t.id.equals(id) & t.status.equals(1) & t.deletedAt.isNull(),
            ))
            .write(
              PengeluaranJenisCompanion(
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
        await (database.update(database.pengeluaranJenis)..where(
              (t) =>
                  t.id.equals(id) & t.status.equals(1) & t.deletedAt.isNull(),
            ))
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

  String _normalizeNama(String nama) {
    final normalized = nama.trim();

    if (normalized.isEmpty) {
      throw ArgumentError('Nama jenis pengeluaran wajib diisi.');
    }

    return normalized;
  }

  Future<void> _validateNama(String normalizedNama, {int? excludeId}) async {
    final items = await (database.select(
      database.pengeluaranJenis,
    )..where((t) => t.status.equals(1) & t.deletedAt.isNull())).get();

    final duplicate = items.any((item) {
      if (excludeId != null && item.id == excludeId) {
        return false;
      }

      return item.nama.trim().toLowerCase() == normalizedNama.toLowerCase();
    });

    if (duplicate) {
      throw ArgumentError(
        'Jenis pengeluaran "$normalizedNama" sudah tersedia.',
      );
    }
  }
}
