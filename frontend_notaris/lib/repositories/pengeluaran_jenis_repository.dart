import '../services/local_master_authorization.dart';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../services/jenis_pengeluaran_api_service.dart';

class PengeluaranJenisRepository {
  static const _uuid = Uuid();

  final AppDatabase database;

  PengeluaranJenisRepository(this.database, {this.authorization});
  final LocalMasterAuthorization? authorization;

  Stream<List<PengeluaranJenisData>> watchAll() {
    return (database.select(database.pengeluaranJenis)
          ..where((t) => t.status.equals(1) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.nama)]))
        .watch();
  }

  /// Merge cloud rows by stable UUID without overwriting unsynced local edits.
  Future<void> syncFromCloud(List<JenisPengeluaranApiModel> remoteItems) async {
    final authority = authorization;
    if (authority == null) throw const LocalMasterDenied();
    return authority.write(
      database,
      MasterModule.expenseType,
      MasterAction.read,
      (actor) async {
        final now = DateTime.now();
        final actions = <MasterAction>{};

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

            final action = existing == null
                ? MasterAction.create
                : (remote.status == 1
                      ? MasterAction.update
                      : MasterAction.delete);
            if (remote.status != 1) {
              actions.add(MasterAction.delete);
              authority.require(
                MasterModule.expenseType,
                MasterAction.delete,
                expected: actor,
              );
            }
            actions.add(action);
            authority.require(
              MasterModule.expenseType,
              action,
              expected: actor,
            );
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
              await database
                  .into(database.pengeluaranJenis)
                  .insert(
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
              await (database.update(
                database.pengeluaranJenis,
              )..where((t) => t.uuid.equals(remote.uuid))).write(companion);
            }
          }
        });
        for (final action in actions) {
          authority.require(MasterModule.expenseType, action, expected: actor);
        }
      },
    );
  }

  /// Push dirty rows and clear dirty state only if the row has not changed
  /// while the network request was in flight.
  Future<int> syncToCloud(JenisPengeluaranApiService api) async {
    final authority = authorization;
    if (authority == null) throw const LocalMasterDenied();
    final actor = authority.require(
      MasterModule.expenseType,
      MasterAction.read,
    );

    final dirtyRows =
        await (database.select(database.pengeluaranJenis)
              ..where((t) => t.isSyncDirty.equals(true))
              ..orderBy([(t) => OrderingTerm.asc(t.id)]))
            .get();
    var synced = 0;

    for (final row in dirtyRows) {
      final action = row.status != 1 || row.deletedAt != null
          ? MasterAction.delete
          : (row.lastSyncedAt == null
                ? MasterAction.create
                : MasterAction.update);
      authority.require(MasterModule.expenseType, action, expected: actor);

      if (row.uuid.trim().isEmpty) {
        throw StateError(
          'Jenis pengeluaran lokal ${row.id} tidak memiliki UUID.',
        );
      }

      if (row.status == 0 || row.deletedAt != null) {
        await api.syncDeactivate(uuid: row.uuid);
        authority.require(MasterModule.expenseType, action, expected: actor);
      } else {
        await api.syncUpsert(uuid: row.uuid, nama: row.nama);
        authority.require(MasterModule.expenseType, action, expected: actor);
      }

      await authority.write(database, MasterModule.expenseType, action, (
        _,
      ) async {
        authority.require(MasterModule.expenseType, action, expected: actor);
        final now = DateTime.now();
        await (database.update(database.pengeluaranJenis)..where(
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
      });
      synced++;
    }

    return synced;
  }

  Future<int> create({required String nama, int? createdBy}) async {
    final authority = authorization;
    if (authority == null) throw const LocalMasterDenied();
    return authority.write(
      database,
      MasterModule.expenseType,
      MasterAction.create,
      (actor) async {
        createdBy = actor.userId;

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
      },
      claimedActor: createdBy,
    );
  }

  Future<bool> update({
    required int id,
    required String nama,
    int? updatedBy,
  }) async {
    final authority = authorization;
    if (authority == null) throw const LocalMasterDenied();
    return authority.write(
      database,
      MasterModule.expenseType,
      MasterAction.update,
      (actor) async {
        updatedBy = actor.userId;

        final normalizedNama = _normalizeNama(nama);
        await _validateNama(normalizedNama, excludeId: id);

        final now = DateTime.now();

        final count =
            await (database.update(database.pengeluaranJenis)..where(
                  (t) =>
                      t.id.equals(id) &
                      t.status.equals(1) &
                      t.deletedAt.isNull(),
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
      },
      claimedActor: updatedBy,
    );
  }

  Future<bool> delete(int id) async {
    final authority = authorization;
    if (authority == null) throw const LocalMasterDenied();
    return authority.write(
      database,
      MasterModule.expenseType,
      MasterAction.delete,
      (actor) async {
        final now = DateTime.now();

        final count =
            await (database.update(database.pengeluaranJenis)..where(
                  (t) =>
                      t.id.equals(id) &
                      t.status.equals(1) &
                      t.deletedAt.isNull(),
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
      },
    );
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
