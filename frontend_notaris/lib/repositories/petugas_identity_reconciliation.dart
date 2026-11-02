import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../services/petugas_sync_api.dart';
import 'petugas_identity_map_repository.dart';

/// Explicit selection from an authenticated server Petugas response. Audit/user
/// confirmation supplies the evidence, not a heuristic on mutable personal data.
class PetugasServerIdentity {
  PetugasServerIdentity.fromRecord(
    Map<String, dynamic> record, {
    required this.scope,
  }) : cloudUuid = record['uuid'] as String,
       serverId = record['id'] as int,
       rowVersion = record['row_version'] as int {
    if (scope.isEmpty ||
        serverId < 1 ||
        rowVersion < 1 ||
        !RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(cloudUuid)) {
      throw const FormatException('invalid server Petugas identity');
    }
  }
  final String scope, cloudUuid;
  final int serverId, rowVersion;
}

class PetugasIdentityReconciliation {
  PetugasIdentityReconciliation(this.db, {required this.scope});
  final AppDatabase db;
  final String scope;
  Never _blocked(String reason) =>
      throw PetugasSyncFailure(PetugasSyncFailureKind.blocked, reason);
  Future<void> _guard(String uuid, String evidence) async {
    if (scope.isEmpty || evidence.trim().isEmpty) {
      _blocked('scope and operator evidence required');
    }
    await (db.select(
      db.petugasLocals,
    )..where((r) => r.uuid.equals(uuid))).getSingle();
    await db.customStatement(
      'INSERT OR IGNORE INTO petugas_sync_feed(id,scope) VALUES(1,?)',
      [scope],
    );
    final feed = await db
        .customSelect('SELECT scope,blocked FROM petugas_sync_feed WHERE id=1')
        .getSingle();
    if (feed.read<String>('scope') != scope ||
        feed.readNullable<String>('blocked') != null) {
      _blocked('identity belongs to another scope');
    }
    final journal = await db
        .customSelect(
          'SELECT pending FROM petugas_sync_journal WHERE local_uuid=?',
          variables: [Variable(uuid)],
        )
        .getSingleOrNull();
    if (journal?.readNullable<String>('pending') != null) {
      _blocked('pending mutation must be resolved first');
    }
  }

  Future<PetugasIdentityMap> confirmVerified({
    required String localUuid,
    required PetugasServerIdentity server,
    required String evidence,
  }) => _confirm(localUuid, server, evidence, false);

  /// Select an existing clean local row for an authenticated baseline event.
  /// Unlike push reconciliation, do not acknowledge a server version until the
  /// corresponding payload has actually been applied by the pull transaction.
  Future<PetugasIdentityMap> confirmForPull({
    required String localUuid,
    required PetugasServerIdentity server,
    required String evidence,
  }) => db.transaction(() async {
    await _guard(localUuid, evidence);
    if (server.scope != scope) _blocked('server identity scope mismatch');
    final row = await (db.select(
      db.petugasLocals,
    )..where((r) => r.uuid.equals(localUuid))).getSingle();
    if (row.isSyncDirty || row.deletedAt != null || row.status != 1) {
      _blocked('local edits/deletion must be reviewed before baseline pull');
    }
    final mappings = PetugasIdentityMapRepository(db);
    final old = await mappings.findByLocalUuid(localUuid);
    if (old?.state == 'development' ||
        (old?.cloudUuid != null &&
            (old!.cloudUuid != server.cloudUuid ||
                old.serverId != server.serverId))) {
      _blocked('existing identity cannot be silently reassigned');
    }
    final journal = await db
        .customSelect(
          'SELECT row_version FROM petugas_sync_journal WHERE local_uuid=?',
          variables: [Variable(localUuid)],
        )
        .getSingleOrNull();
    if (old?.cloudUuid == null &&
        journal?.readNullable<int>('row_version') != null) {
      _blocked('unmapped local row already has a server version');
    }
    return mappings.linkVerified(
      localUuid: localUuid,
      cloudUuid: server.cloudUuid,
      serverId: server.serverId,
      evidence: evidence,
    );
  });
  Future<PetugasIdentityMap> confirmServerOnly({
    required String localUuid,
    required PetugasServerIdentity server,
    required String evidence,
  }) => _confirm(localUuid, server, evidence, true);
  Future<PetugasIdentityMap> _confirm(
    String uuid,
    PetugasServerIdentity server,
    String evidence,
    bool serverOnly,
  ) => db.transaction(() async {
    await _guard(uuid, evidence);
    if (server.scope != scope) {
      _blocked('server identity scope mismatch');
    }
    final mappings = PetugasIdentityMapRepository(db);
    final old = await mappings.findByLocalUuid(uuid);
    if (old?.cloudUuid != null &&
        (old!.cloudUuid != server.cloudUuid ||
            old.serverId != server.serverId)) {
      _blocked('active identity cannot be reassigned');
    }
    final journal = await db
        .customSelect(
          'SELECT row_version FROM petugas_sync_journal WHERE local_uuid=?',
          variables: [Variable(uuid)],
        )
        .getSingleOrNull();
    final version = journal?.readNullable<int>('row_version');
    if (version != null && version != server.rowVersion) {
      _blocked('established version must be reconciled through sync');
    }
    final row = await (db.select(
      db.petugasLocals,
    )..where((r) => r.uuid.equals(uuid))).getSingle();
    if (serverOnly && row.isSyncDirty) {
      _blocked('server-only materialization must be clean');
    }
    final mapped = serverOnly
        ? await mappings.linkServerOnly(
            localUuid: uuid,
            cloudUuid: server.cloudUuid,
            serverId: server.serverId,
            evidence: evidence,
          )
        : await mappings.linkVerified(
            localUuid: uuid,
            cloudUuid: server.cloudUuid,
            serverId: server.serverId,
            evidence: evidence,
          );
    await db.customStatement(
      'INSERT INTO petugas_sync_journal(local_uuid,row_version) VALUES(?,?) ON CONFLICT(local_uuid) DO UPDATE SET row_version=excluded.row_version',
      [uuid, server.rowVersion],
    );
    return mapped;
  });
  Future<PetugasIdentityMap> _classify(
    String uuid,
    String evidence,
    String state,
  ) => db.transaction(() async {
    await _guard(uuid, evidence);
    final mappings = PetugasIdentityMapRepository(db);
    if ((await mappings.findByLocalUuid(uuid))?.cloudUuid != null) {
      _blocked(
        'linked identity requires conflict resolution before reclassification',
      );
    }
    return switch (state) {
      'ambiguous' => mappings.markAmbiguous(
        localUuid: uuid,
        evidence: evidence,
      ),
      'development' => mappings.markDevelopment(
        localUuid: uuid,
        evidence: evidence,
      ),
      _ => mappings.registerLocalOnly(localUuid: uuid, evidence: evidence),
    };
  });
  Future<PetugasIdentityMap> markAmbiguous(String uuid, String evidence) =>
      _classify(uuid, evidence, 'ambiguous');
  Future<PetugasIdentityMap> confirmLocalOnly(String uuid, String evidence) =>
      _classify(uuid, evidence, 'local_only');
  Future<PetugasIdentityMap> markDevelopment(String uuid, String evidence) =>
      _classify(uuid, evidence, 'development');
}
