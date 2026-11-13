part of 'petugas_sync_repository.dart';

class PetugasConflict {
  PetugasConflict(
    this.mutationId,
    this.localUuid,
    this.state,
    this.mutation,
    this.localSnapshot,
    this.observedLocal,
    this.response,
    this.baseVersion,
    this.note,
  );
  final String mutationId, localUuid, state;
  final Map<String, dynamic> mutation, localSnapshot, observedLocal, response;
  final int? baseVersion;
  final String? note;
  Map<String, dynamic>? get serverRecord {
    final errors = response['errors'];
    return errors is Map && errors['current'] is Map
        ? syncMap(errors['current'])
        : null;
  }
}

extension PetugasConflictResolution on PetugasLocalSyncRepository {
  Future<void> _saveConflict(
    String localUuid,
    Map<String, dynamic> mutation,
    String snapshot,
    Object? details,
  ) => db.transaction(() async {
    final current = await _row(localUuid);
    await db.customStatement(
      "INSERT INTO petugas_sync_conflict(scope,mutation_id,local_uuid,mutation,local_snapshot,observed_local,response,base_version,state,updated_at) VALUES(?,?,?,?,?,?,?,?,'open',?) ON CONFLICT(scope,mutation_id) DO UPDATE SET observed_local=excluded.observed_local,response=excluded.response,updated_at=excluded.updated_at",
      [
        scope,
        mutation['mutation_id'],
        localUuid,
        jsonEncode(mutation),
        snapshot,
        jsonEncode(current.toJson()),
        jsonEncode(details is Map ? details : {'unrecognized_response': true}),
        mutation['expected_row_version'],
        DateTime.now().toIso8601String(),
      ],
    );
  });
  Future<void> _readScope() async {
    final feed = await db
        .customSelect('SELECT scope FROM petugas_sync_feed WHERE id=1')
        .getSingleOrNull();
    if (feed != null && feed.read<String>('scope') != scope) {
      throw const PetugasSyncFailure(
        PetugasSyncFailureKind.blocked,
        'scope mismatch',
      );
    }
  }

  /// Read-only access remains available while full resync is required.
  Future<List<PetugasConflict>> listConflicts() async {
    await _readScope();
    final rows = await db
        .customSelect(
          "SELECT * FROM petugas_sync_conflict WHERE scope=? AND state IN ('open','held') ORDER BY updated_at",
          variables: [Variable(scope)],
        )
        .get();
    return rows
        .map(
          (r) => PetugasConflict(
            r.read<String>('mutation_id'),
            r.read<String>('local_uuid'),
            r.read<String>('state'),
            syncMap(jsonDecode(r.read<String>('mutation'))),
            syncMap(jsonDecode(r.read<String>('local_snapshot'))),
            syncMap(jsonDecode(r.read<String>('observed_local'))),
            syncMap(jsonDecode(r.read<String>('response'))),
            r.readNullable<int>('base_version'),
            r.readNullable<String>('note'),
          ),
        )
        .toList();
  }

  Future<Map<String, dynamic>> currentLocalSnapshot(String localUuid) async {
    await _readScope();
    return (await _row(localUuid)).toJson();
  }

  Future<PetugasConflict> _conflict(String localUuid) async =>
      (await listConflicts()).singleWhere((c) => c.localUuid == localUuid);
  Future<void> holdConflict(String localUuid, String note) =>
      _exclusive(() async {
        await _readScope();
        if (note.trim().isEmpty) {
          throw ArgumentError('operator note required');
        }
        await db.customStatement(
          "UPDATE petugas_sync_conflict SET state='held',note=?,updated_at=? WHERE scope=? AND local_uuid=? AND state IN ('open','held')",
          [note, DateTime.now().toIso8601String(), scope, localUuid],
        );
      });
  Map<String, dynamic> _server(PetugasConflict conflict) {
    final errors = conflict.response['errors'];
    final record = conflict.serverRecord;
    if (errors is! Map ||
        errors['code'] != 'version_conflict' ||
        record == null ||
        record['uuid'] != conflict.mutation['petugas_uuid'] ||
        record['id'] is! int ||
        record['id'] < 1 ||
        record['row_version'] is! int ||
        record['row_version'] < 1 ||
        record['status'] is! int ||
        record['nama'] is! String ||
        record['email'] is! String) {
      throw const PetugasSyncFailure(
        PetugasSyncFailureKind.blocked,
        'canonical version conflict record required',
      );
    }
    return record;
  }

  Future<Map<String, dynamic>> _refreshConflict(
    PetugasConflict conflict,
  ) async {
    final old = _server(conflict);
    final base = conflict.baseVersion;
    // The original rejected request is guaranteed to remain stale under the
    // backend's monotonically increasing versions. This uses existing HTTP,
    // including tombstones not exposed by legacy GET. Never probe an unproven
    // mutation_reuse/constraint error or a version that might succeed.
    if (base != null && old['row_version'] <= base) {
      throw const PetugasSyncFailure(
        PetugasSyncFailureKind.blocked,
        'fresh canonical read protocol required for this conflict',
      );
    }
    try {
      await api.push(conflict.mutation);
    } on PetugasSyncFailure catch (e) {
      if (e.kind == PetugasSyncFailureKind.expired) {
        await db.customStatement(
          "UPDATE petugas_sync_feed SET blocked='full_resync_required' WHERE id=1",
        );
      }
      if (e.kind != PetugasSyncFailureKind.conflict) {
        rethrow;
      }
      await _saveConflict(
        conflict.localUuid,
        conflict.mutation,
        jsonEncode(conflict.localSnapshot),
        e.details,
      );
      final fresh = _server(await _conflict(conflict.localUuid));
      if (fresh['row_version'] != old['row_version'] ||
          !mapEquals(fresh, old)) {
        throw const PetugasSyncFailure(
          PetugasSyncFailureKind.conflict,
          'server changed; review refreshed snapshot',
        );
      }
      return fresh;
    }
    throw const PetugasSyncFailure(
      PetugasSyncFailureKind.blocked,
      'unexpected acknowledgement; operator recovery required',
    );
  }

  Future<void> chooseServer(
    String localUuid, {
    required int reviewedServerVersion,
    required Map<String, dynamic> reviewedLocalSnapshot,
    required bool confirmed,
  }) => _resolve(
    localUuid,
    reviewedServerVersion,
    reviewedLocalSnapshot,
    confirmed,
    true,
  );
  Future<void> chooseLocal(
    String localUuid, {
    required int reviewedServerVersion,
    required Map<String, dynamic> reviewedLocalSnapshot,
    required bool confirmed,
  }) => _resolve(
    localUuid,
    reviewedServerVersion,
    reviewedLocalSnapshot,
    confirmed,
    false,
  );
  Future<void> _resolve(
    String uuid,
    int reviewedVersion,
    Map<String, dynamic> reviewedLocal,
    bool confirmed,
    bool useServer,
  ) => _exclusive(() async {
    if (!confirmed) {
      throw ArgumentError('explicit operator confirmation required');
    }
    await _bind();
    final conflict = await _conflict(uuid);
    if (_server(conflict)['row_version'] != reviewedVersion) {
      throw const PetugasSyncFailure(
        PetugasSyncFailureKind.conflict,
        'reviewed version changed',
      );
    }
    final server = await _refreshConflict(conflict);
    await db.transaction(() async {
      final local = await _row(uuid);
      if (!mapEquals(local.toJson(), reviewedLocal)) {
        throw const PetugasSyncFailure(
          PetugasSyncFailureKind.conflict,
          'local changed; review latest edit',
        );
      }
      final journal = await db
          .customSelect(
            'SELECT pending FROM petugas_sync_journal WHERE local_uuid=?',
            variables: [Variable(uuid)],
          )
          .getSingle();
      if (journal.readNullable<String>('pending') !=
          jsonEncode(conflict.mutation)) {
        throw const PetugasSyncFailure(
          PetugasSyncFailureKind.blocked,
          'pending identity changed',
        );
      }
      final mapping = await PetugasIdentityMapRepository(db)
          .findByLocalUuid(uuid);
      if (mapping == null ||
          !{'local_only', 'verified', 'server_only'}.contains(mapping.state) ||
          mapping.cloudUuid != null &&
              (mapping.cloudUuid != server['uuid'] ||
                  mapping.serverId != server['id'])) {
        throw const PetugasSyncFailure(
          PetugasSyncFailureKind.blocked,
          'identity reconciliation required',
        );
      }
      final tomb = server['status'] != 1 || server['deleted_at'] != null;
      if (!useServer && tomb && local.status == 1 && local.deletedAt == null) {
        throw const PetugasSyncFailure(
          PetugasSyncFailureKind.blocked,
          'server tombstone cannot be resurrected',
        );
      }
      await PetugasIdentityMapRepository(db).linkVerified(
        localUuid: uuid,
        cloudUuid: server['uuid'],
        serverId: server['id'],
        evidence: 'explicit conflict resolution ${conflict.mutationId}',
      );
      if (useServer) {
        await _apply({
          'petugas_uuid': server['uuid'],
          'server_id': server['id'],
          'row_version': server['row_version'],
          'tombstone': tomb,
          'payload': server,
        }, resolving: true);
        await db.customStatement(
          'UPDATE petugas_sync_journal SET pending=NULL,snapshot=NULL,row_version=? WHERE local_uuid=?',
          [server['row_version'], uuid],
        );
      } else {
        final deleted = local.status != 1 || local.deletedAt != null;
        final mutation = {
          'mutation_id': const Uuid().v4(),
          'petugas_uuid': server['uuid'],
          'expected_row_version': server['row_version'],
          'operation': deleted ? 'delete' : 'upsert',
          if (!deleted) 'payload': await _payload(local),
        };
        await db.customStatement(
          'UPDATE petugas_sync_journal SET pending=?,snapshot=?,row_version=? WHERE local_uuid=?',
          [
            jsonEncode(mutation),
            jsonEncode(local.toJson()),
            server['row_version'],
            uuid,
          ],
        );
        await (db.update(db.petugasLocals)..where((r) => r.uuid.equals(uuid)))
            .write(const PetugasLocalsCompanion(isSyncDirty: Value(true)));
      }
      await db.customStatement(
        'UPDATE petugas_sync_conflict SET state=?,updated_at=? WHERE scope=? AND mutation_id=?',
        [
          useServer ? 'resolved_server' : 'resolved_local',
          DateTime.now().toIso8601String(),
          scope,
          conflict.mutationId,
        ],
      );
    });
  });
  Future<String?> recoveryStatus() async {
    await _readScope();
    return (await db
            .customSelect('SELECT blocked FROM petugas_sync_feed WHERE id=1')
            .getSingleOrNull())
        ?.readNullable<String>('blocked');
  }
}
