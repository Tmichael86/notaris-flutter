import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../services/user_api_service.dart';
import '../services/petugas_sync_api.dart';
import 'petugas_sync_repository.dart';

/// Scope must be the same stable deployment/account identity as local sync.
/// Gender evidence is supplied by a trusted operator, never derived from labels.
class VerifiedPetugasReferences implements ScopedPetugasSyncReferences {
  VerifiedPetugasReferences(this.db, {required this.scope});
  final AppDatabase db;
  @override
  final String scope;
  Never _blocked(String reason) =>
      throw PetugasSyncFailure(PetugasSyncFailureKind.blockedReference, reason);
  void _evidence(String evidence) {
    if (scope.isEmpty || evidence.trim().isEmpty) {
      _blocked('scope and verification evidence required');
    }
  }

  Future<void> confirmGender({
    required String localUuid,
    required int serverId,
    required String evidence,
  }) async {
    _evidence(evidence);
    if (serverId < 1) {
      _blocked('invalid server gender ID');
    }
    await db.transaction(() async {
      final local = await (db.select(
        db.jenisKelamins,
      )..where((r) => r.uuid.equals(localUuid))).getSingleOrNull();
      if (local == null) {
        _blocked('local gender missing');
      }
      final existing = await db
          .customSelect(
            'SELECT * FROM petugas_gender_reference WHERE scope=? AND local_uuid=?',
            variables: [Variable(scope), Variable(localUuid)],
          )
          .getSingleOrNull();
      if (existing?.readNullable<int>('server_id') != null &&
          existing!.read<int>('server_id') != serverId) {
        _blocked('existing verified reference cannot be silently reassigned');
      }
      final duplicate = await db
          .customSelect(
            "SELECT local_uuid FROM petugas_gender_reference WHERE scope=? AND server_id=? AND local_uuid<>? AND state='verified'",
            variables: [
              Variable(scope),
              Variable(serverId),
              Variable(localUuid),
            ],
          )
          .get();
      if (duplicate.isNotEmpty) {
        _blocked('server gender already mapped');
      }
      await db.customStatement(
        "INSERT INTO petugas_gender_reference(scope,local_uuid,server_id,state,evidence) VALUES(?,?,?,'verified',?) ON CONFLICT(scope,local_uuid) DO UPDATE SET server_id=excluded.server_id,state=excluded.state,evidence=excluded.evidence",
        [scope, localUuid, serverId, evidence.trim()],
      );
    });
  }

  Future<void> markGenderAmbiguous(String localUuid, String evidence) async {
    _evidence(evidence);
    await db.customStatement(
      "INSERT INTO petugas_gender_reference(scope,local_uuid,state,evidence) VALUES(?,?,'ambiguous',?) ON CONFLICT(scope,local_uuid) DO UPDATE SET server_id=NULL,state='ambiguous',evidence=excluded.evidence",
      [scope, localUuid, evidence],
    );
  }

  @override
  Future<int> genderToServer(int localId) async {
    final local = await (db.select(
      db.jenisKelamins,
    )..where((r) => r.id.equals(localId))).getSingleOrNull();
    if (local == null || local.status != 1 || local.deletedAt != null) {
      _blocked('local gender missing or inactive');
    }
    final row = await db
        .customSelect(
          "SELECT server_id FROM petugas_gender_reference WHERE scope=? AND local_uuid=? AND state='verified'",
          variables: [Variable(scope), Variable(local.uuid)],
        )
        .getSingleOrNull();
    if (row == null) {
      _blocked('gender mapping missing or ambiguous');
    }
    return row.read<int>('server_id');
  }

  @override
  Future<int> genderToLocal(int serverId) async {
    final row = await db
        .customSelect(
          "SELECT local_uuid FROM petugas_gender_reference WHERE scope=? AND server_id=? AND state='verified'",
          variables: [Variable(scope), Variable(serverId)],
        )
        .getSingleOrNull();
    if (row == null) {
      _blocked('server gender mapping missing');
    }
    final local =
        await (db.select(db.jenisKelamins)
              ..where((r) => r.uuid.equals(row.read<String>('local_uuid'))))
            .getSingleOrNull();
    if (local == null || local.status != 1 || local.deletedAt != null) {
      _blocked('mapped local gender inactive');
    }
    return local.id;
  }

  /// Only authenticated /users response is used. No local/user-name matching.
  /// Failure or revocation invalidates previously cached provenance first.
  Future<void> verifyUserFromServer(UserApiService users, int serverId) async {
    if (serverId < 1 || scope.isEmpty) {
      _blocked('invalid user provenance');
    }
    await db.customStatement(
      'DELETE FROM petugas_user_reference WHERE scope=? AND server_id=?',
      [scope, serverId],
    );
    try {
      final rows = await users.getAll();
      if (rows.where((u) => u.id == serverId && u.status == 1).length != 1) {
        _blocked('server user unavailable or ambiguous');
      }
      await db.customStatement(
        'INSERT INTO petugas_user_reference(scope,server_id,evidence) VALUES(?,?,?)',
        [scope, serverId, 'authenticated GET /users selection'],
      );
    } on PetugasSyncFailure {
      rethrow;
    } catch (_) {
      _blocked('unable to verify user on authenticated server');
    }
  }

  @override
  Future<int> verifiedServerUser(int storedId) async {
    final row = await db
        .customSelect(
          'SELECT server_id FROM petugas_user_reference WHERE scope=? AND server_id=?',
          variables: [Variable(scope), Variable(storedId)],
        )
        .getSingleOrNull();
    if (row == null) {
      _blocked('user ID has no server-scoped provenance');
    }
    return storedId;
  }
}
