import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show mapEquals;
import 'package:path/path.dart' as p;

import '../database/app_database.dart';
import '../models/auth_session.dart';
import '../services/petugas_sync_api.dart';
import 'petugas_identity_map_repository.dart';
import 'petugas_identity_reconciliation.dart';
import 'petugas_reference_resolver.dart';
import 'petugas_sync_repository.dart';

Never _blocked(String reason) =>
    throw PetugasSyncFailure(PetugasSyncFailureKind.blocked, reason);

/// The physical SQLite file, deployment generation, account and device all
/// participate in the persisted scope. One file cannot silently change owners.
class PetugasBaselineContext {
  PetugasBaselineContext({
    required this.generation,
    required this.accountId,
    required this.deviceId,
    required String databasePath,
  }) : databasePath = AppDatabase.petugasBaselineFilePath(File(databasePath)) {
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(generation) ||
        accountId < 1 ||
        !RegExp(r'^[a-zA-Z0-9_-]{1,100}$').hasMatch(deviceId) ||
        !p.isAbsolute(databasePath) ||
        p.basename(databasePath) != 'offline.sqlite' ||
        p.basename(p.dirname(databasePath)) != generation ||
        p.basename(p.dirname(p.dirname(databasePath))) != 'notarisdev') {
      throw ArgumentError('Explicit isolated notarisdev profile required');
    }
  }
  static final apiBase = Uri.parse('http://127.0.0.1:8081/api/v1');
  final String generation, deviceId, databasePath;
  final int accountId;
  String get scope => jsonEncode([
    apiBase.toString(),
    'notarisdev',
    generation,
    accountId,
    deviceId,
    databasePath,
  ]);
}

/// An explicit operator decision, selected from authenticated feed identities.
/// New means reviewed server-only; it never means "no numeric ID match found".
class PetugasBaselineSelection {
  const PetugasBaselineSelection.existing({
    required PetugasServerIdentity server,
    required int sequence,
    required String localUuid,
    required String evidence,
  }) : this._(server, sequence, evidence, localUuid);
  const PetugasBaselineSelection.serverOnly({
    required PetugasServerIdentity server,
    required int sequence,
    required String evidence,
  }) : this._(server, sequence, evidence, null);
  const PetugasBaselineSelection._(
    this.server,
    this.sequence,
    this.evidence,
    this.localUuid,
  );
  final PetugasServerIdentity server;
  final int sequence;
  final String? localUuid;
  final String evidence;
}

class PetugasBaselinePlan {
  PetugasBaselinePlan({
    required this.scope,
    required Iterable<String> reviewedLocalUuids,
    required Iterable<PetugasBaselineSelection> selections,
  }) : reviewedLocalUuids = Set.unmodifiable(reviewedLocalUuids),
       selections = List.unmodifiable(selections) {
    if (scope.isEmpty ||
        this.selections.length != 4 ||
        this.selections.map((s) => s.sequence).toSet().difference({
          1,
          2,
          3,
          4,
        }).isNotEmpty ||
        this.selections.map((s) => s.sequence).toSet().length != 4 ||
        this.selections.map((s) => s.server.cloudUuid).toSet().length != 4 ||
        this.selections.map((s) => s.server.serverId).toSet().length != 4) {
      throw ArgumentError(
        'Four distinct reviewed baseline identities required',
      );
    }
    final locals = this.selections
        .map((s) => s.localUuid)
        .whereType<String>()
        .toList();
    if (locals.toSet().length != locals.length ||
        locals.any((uuid) => !this.reviewedLocalUuids.contains(uuid))) {
      throw ArgumentError(
        'Existing targets must be unique reviewed local UUIDs',
      );
    }
    for (final selection in this.selections) {
      if (selection.server.scope != scope ||
          selection.server.rowVersion != 1 ||
          selection.evidence.trim().isEmpty) {
        throw ArgumentError(
          'Scoped baseline version and operator evidence required',
        );
      }
    }
  }
  final String scope;
  final Set<String> reviewedLocalUuids;
  final List<PetugasBaselineSelection> selections;
}

/// Explicit, pull-only application service. Normal startup/coordinator never
/// instantiates it. Caller must supply an isolated DB and reviewed identity plan.
class PetugasBaselinePull {
  PetugasBaselinePull({
    required this.db,
    required this.dio,
    required this.context,
    required this.plan,
    required this.references,
    required this.session,
  }) {
    if (plan.scope != context.scope ||
        references.scope != context.scope ||
        !identical(references.db, db)) {
      throw ArgumentError('Baseline/reference/profile scope mismatch');
    }
    if (db.petugasBaselinePath == null ||
        !p.equals(db.petugasBaselinePath!, context.databasePath)) {
      throw ArgumentError('Use the explicit isolated Petugas database factory');
    }
  }
  final AppDatabase db;
  final Dio dio;
  final PetugasBaselineContext context;
  final PetugasBaselinePlan plan;
  final VerifiedPetugasReferences references;
  final AuthSession? Function() session;

  String _token() {
    final current = session();
    if (current == null ||
        current.userId != context.accountId ||
        current.token.isEmpty ||
        current.isOffline) {
      throw const PetugasSyncFailure(
        PetugasSyncFailureKind.unauthorized,
        'online baseline account required',
      );
    }
    if (Uri.parse(dio.options.baseUrl) != PetugasBaselineContext.apiBase) {
      _blocked('API origin does not match the reviewed development deployment');
    }
    return current.token;
  }

  Future<void> _validate() async {
    _token();
    final databases = await db.customSelect('PRAGMA database_list').get();
    final main = databases.singleWhere((r) => r.read<String>('name') == 'main');
    final actual = main.read<String>('file');
    if (actual.isEmpty ||
        !p.equals(
          await File(actual).resolveSymbolicLinks(),
          await File(context.databasePath).resolveSymbolicLinks(),
        )) {
      _blocked('SQLite does not match the isolated reviewed profile');
    }
    // Every pre-existing local identity must have been included in the review.
    // New rows are allowed only if this plan already materialized them earlier.
    final rows = await db.select(db.petugasLocals).get();
    if (!rows.map((r) => r.uuid).toSet().containsAll(plan.reviewedLocalUuids)) {
      _blocked('reviewed local inventory changed');
    }
    for (final row in rows) {
      if (plan.reviewedLocalUuids.contains(row.uuid)) continue;
      final map = await PetugasIdentityMapRepository(db)
          .findByLocalUuid(row.uuid);
      if (map == null ||
          map.state != 'server_only' ||
          !plan.selections.any(
            (s) =>
                s.localUuid == null &&
                s.server.cloudUuid == map.cloudUuid &&
                s.server.serverId == map.serverId,
          )) {
        _blocked('unreviewed local rows require identity reconciliation');
      }
    }
    _token();
  }

  Future<void> _prepare(Map<String, dynamic> event) async {
    final candidates = plan.selections.where(
      (s) =>
          s.server.cloudUuid == event['petugas_uuid'] &&
          s.server.serverId == event['server_id'] &&
          s.server.rowVersion == event['row_version'] &&
          s.sequence == event['publication_sequence'],
    );
    if (candidates.length != 1 || event['tombstone'] != false) {
      _blocked('event is outside the reviewed baseline');
    }
    final selected = candidates.single;
    final mapped =
        await (db.select(db.petugasIdentityMaps)
              ..where((m) => m.cloudUuid.equals(selected.server.cloudUuid)))
            .getSingleOrNull();
    if (mapped != null) {
      if (mapped.serverId != selected.server.serverId ||
          (selected.localUuid != null &&
              mapped.localUuid != selected.localUuid) ||
          (selected.localUuid == null && mapped.state != 'server_only')) {
        _blocked('reviewed identity conflicts with an existing mapping');
      }
      final journal = await db
          .customSelect(
            'SELECT row_version FROM petugas_sync_journal WHERE local_uuid=?',
            variables: [Variable(mapped.localUuid)],
          )
          .getSingleOrNull();
      if (journal?.readNullable<int>('row_version') != null) {
        final row = await (db.select(
          db.petugasLocals,
        )..where((r) => r.uuid.equals(mapped.localUuid))).getSingle();
        final payload = syncMap(event['payload']);
        final gender = payload['jenis_kelamin_id'];
        final user = payload['user_id'];
        final expected = {
          'nama': row.nama,
          'email': row.email,
          'nik': row.nik,
          'alamat': row.alamat,
          'tempat_lahir': row.tempatLahir,
          'tanggal_lahir': row.tanggalLahir?.toIso8601String().substring(0, 10),
          'jenis_kelamin': row.jenisKelamin,
          'user_id': row.userId,
          'no_telp': row.noTelp,
        };
        final incoming = {
          for (final key in [
            'nama',
            'email',
            'nik',
            'alamat',
            'tempat_lahir',
            'tanggal_lahir',
            'no_telp',
          ])
            key: payload[key],
          'jenis_kelamin': gender == null
              ? null
              : await references.genderToLocal(gender as int),
          'user_id': user == null
              ? null
              : await references.verifiedServerUser(user as int),
        };
        // Old push reconciliation may acknowledge a version without applying
        // its payload. Such a stale local row must not be silently skipped.
        if (journal!.read<int>('row_version') != 1 ||
            row.isSyncDirty ||
            row.status != 1 ||
            row.deletedAt != null ||
            !mapEquals(expected, incoming)) {
          _blocked(
            'established baseline version disagrees with local payload; review required',
          );
        }
      }
      return;
    }
    if (selected.localUuid != null) {
      await PetugasIdentityReconciliation(
        db,
        scope: context.scope,
      ).confirmForPull(
        localUuid: selected.localUuid!,
        server: selected.server,
        evidence: selected.evidence,
      );
    } else {
      final collision =
          await (db.select(db.petugasLocals)
                ..where((r) => r.uuid.equals(selected.server.cloudUuid)))
              .getSingleOrNull();
      if (collision != null) {
        _blocked('an existing UUID requires an explicit local selection');
      }
      // The existing repository now materializes and links this reviewed
      // server-only event, inside the same page/cursor transaction.
    }
  }

  Future<void> pull({int limit = 2}) async {
    final api = AuthenticatedPetugasPullApi(dio, verifiedToken: _token);
    await PetugasLocalSyncRepository(
      db,
      api,
      references,
      scope: context.scope,
      validatePullContext: _validate,
      preparePullIdentity: _prepare,
    ).pull(limit: limit, throughCursor: 4);
    await _validate();
    final feed = await db
        .customSelect('SELECT cursor FROM petugas_sync_feed WHERE id=1')
        .getSingle();
    if (feed.read<int>('cursor') != 4) {
      _blocked(
        'baseline incomplete; preserve the persisted checkpoint and retry pull',
      );
    }
    for (final selected in plan.selections) {
      final mapping =
          await (db.select(db.petugasIdentityMaps)
                ..where((m) => m.cloudUuid.equals(selected.server.cloudUuid)))
              .getSingleOrNull();
      if (mapping == null ||
          mapping.serverId != selected.server.serverId ||
          (selected.localUuid != null &&
              mapping.localUuid != selected.localUuid)) {
        _blocked('baseline identity is incomplete');
      }
    }
  }
}
