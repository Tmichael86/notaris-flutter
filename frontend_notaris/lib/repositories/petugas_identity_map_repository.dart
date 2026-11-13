import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/petugas_sync_contract.dart';

/// Stores explicit reconciliation decisions. It deliberately does not infer
/// matches from mutable fields such as name or email.
class PetugasIdentityMapRepository {
  PetugasIdentityMapRepository(this.db);

  final AppDatabase db;

  Future<PetugasIdentityMap?> findByLocalUuid(String localUuid) {
    return (db.select(
      db.petugasIdentityMaps,
    )..where((map) => map.localUuid.equals(localUuid))).getSingleOrNull();
  }

  Future<PetugasIdentityMap> registerLocalOnly({
    required String localUuid,
    String? evidence,
  }) {
    return _write(
      localUuid: localUuid,
      state: PetugasIdentityState.localOnly,
      evidence: evidence,
    );
  }

  Future<PetugasIdentityMap> markAmbiguous({
    required String localUuid,
    required String evidence,
  }) {
    if (evidence.trim().isEmpty) {
      throw ArgumentError.value(evidence, 'evidence', 'Wajib diisi.');
    }
    return _write(
      localUuid: localUuid,
      state: PetugasIdentityState.ambiguous,
      evidence: evidence,
    );
  }

  Future<PetugasIdentityMap> linkVerified({
    required String localUuid,
    required String cloudUuid,
    required int serverId,
    required String evidence,
  }) {
    return _link(
      localUuid: localUuid,
      cloudUuid: cloudUuid,
      serverId: serverId,
      state: PetugasIdentityState.verified,
      evidence: evidence,
    );
  }

  Future<PetugasIdentityMap> linkServerOnly({
    required String localUuid,
    required String cloudUuid,
    required int serverId,
    required String evidence,
  }) {
    return _link(
      localUuid: localUuid,
      cloudUuid: cloudUuid,
      serverId: serverId,
      state: PetugasIdentityState.serverOnly,
      evidence: evidence,
    );
  }

  Future<PetugasIdentityMap> markDevelopment({
    required String localUuid,
    required String evidence,
  }) {
    return _write(
      localUuid: localUuid,
      state: PetugasIdentityState.development,
      evidence: evidence,
    );
  }

  Future<PetugasIdentityMap> _link({
    required String localUuid,
    required String cloudUuid,
    required int serverId,
    required PetugasIdentityState state,
    required String evidence,
  }) async {
    final normalizedLocalUuid = localUuid.trim();
    final normalizedCloudUuid = cloudUuid.trim();
    if (normalizedLocalUuid.isEmpty ||
        normalizedCloudUuid.isEmpty ||
        serverId <= 0 ||
        evidence.trim().isEmpty) {
      throw ArgumentError('Cloud UUID, server ID, dan evidence wajib valid.');
    }

    return db.transaction(() async {
      final conflict =
          await (db.select(db.petugasIdentityMaps)..where(
                (map) =>
                    (map.cloudUuid.equals(normalizedCloudUuid) |
                        map.serverId.equals(serverId)) &
                    map.localUuid.equals(normalizedLocalUuid).not() &
                    map.state.isIn(const ['verified', 'server_only']),
              ))
              .getSingleOrNull();
      if (conflict != null) {
        throw StateError(
          'Cloud UUID sudah memiliki mapping aktif ke ${conflict.localUuid}.',
        );
      }

      return _write(
        localUuid: normalizedLocalUuid,
        cloudUuid: normalizedCloudUuid,
        serverId: serverId,
        state: state,
        evidence: evidence,
      );
    });
  }

  Future<PetugasIdentityMap> _write({
    required String localUuid,
    required PetugasIdentityState state,
    String? cloudUuid,
    int? serverId,
    String? evidence,
  }) async {
    final normalizedLocalUuid = localUuid.trim();
    if (normalizedLocalUuid.isEmpty) {
      throw ArgumentError.value(localUuid, 'localUuid', 'Wajib diisi.');
    }

    final now = DateTime.now();
    final existing = await findByLocalUuid(normalizedLocalUuid);
    final values = PetugasIdentityMapsCompanion(
      cloudUuid: Value(cloudUuid),
      serverId: Value(serverId),
      state: Value(state.databaseValue),
      evidence: Value(_optionalText(evidence)),
      updatedAt: Value(now),
    );

    if (existing == null) {
      await db
          .into(db.petugasIdentityMaps)
          .insert(
            values.copyWith(
              localUuid: Value(normalizedLocalUuid),
              createdAt: Value(now),
            ),
          );
    } else {
      await (db.update(db.petugasIdentityMaps)
            ..where((map) => map.localUuid.equals(normalizedLocalUuid)))
          .write(values);
    }

    return (await findByLocalUuid(normalizedLocalUuid))!;
  }

  String? _optionalText(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}
