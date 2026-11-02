import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart' show mapEquals;

import '../database/app_database.dart';
import '../services/petugas_sync_api.dart';
import 'petugas_identity_map_repository.dart';

part 'petugas_conflict_resolution.dart';

/// All non-null references require explicit, verified resolution. Implementors
/// must never infer identity from names, seed UUIDs, or equal integer values.
abstract interface class PetugasSyncReferences {
  Future<int> genderToServer(int localId);
  Future<int> genderToLocal(int serverId);
  Future<int> verifiedServerUser(int storedId);
}

abstract interface class ScopedPetugasSyncReferences
    implements PetugasSyncReferences {
  String get scope;
}

class PetugasLocalSyncRepository {
  PetugasLocalSyncRepository(
    this.db,
    this.api,
    this.references, {
    required this.scope,
    this.preparePullIdentity,
    this.validatePullContext,
  });
  final AppDatabase db;
  final PetugasSyncApi api;
  final PetugasSyncReferences references;

  /// Stable server deployment + authenticated account identifier, not a token.
  final String scope;
  // Optional controlled-pull boundary. Both run in the page transaction, so
  // reconciliation, row changes and cursor advancement share the same commit.
  final Future<void> Function(Map<String, dynamic> event)? preparePullIdentity;
  final Future<void> Function()? validatePullContext;
  static final _running = Expando<bool>();
  Future<T> _exclusive<T>(Future<T> Function() action) async {
    if (_running[db] == true) {
      throw const PetugasSyncFailure(
        PetugasSyncFailureKind.blocked,
        'sync already running',
      );
    }
    _running[db] = true;
    try {
      return await action();
    } finally {
      _running[db] = false;
    }
  }

  Future<void> _bind() async {
    if (scope.isEmpty) {
      throw ArgumentError('scope required');
    }
    final resolver = references;
    if (resolver is ScopedPetugasSyncReferences && resolver.scope != scope) {
      throw const PetugasSyncFailure(
        PetugasSyncFailureKind.blockedReference,
        'reference scope mismatch',
      );
    }
    await db.customStatement(
      'INSERT OR IGNORE INTO petugas_sync_feed(id,scope) VALUES(1,?)',
      [scope],
    );
    final feed = await db
        .customSelect('SELECT * FROM petugas_sync_feed WHERE id=1')
        .getSingle();
    if (feed.read<String>('scope') != scope ||
        feed.readNullable<String>('blocked') != null) {
      throw const PetugasSyncFailure(
        PetugasSyncFailureKind.blocked,
        'scope mismatch or full resync required',
      );
    }
  }

  Future<PetugasLocal> _row(String uuid) => (db.select(
    db.petugasLocals,
  )..where((r) => r.uuid.equals(uuid))).getSingle();
  Future<Map<String, dynamic>> _payload(PetugasLocal row) async => {
    'nama': row.nama,
    'email': row.email,
    'nik': row.nik,
    'alamat': row.alamat,
    'tempat_lahir': row.tempatLahir,
    'tanggal_lahir': row.tanggalLahir?.toIso8601String().substring(0, 10),
    'no_telp': row.noTelp,
    'jenis_kelamin_id': row.jenisKelamin == null
        ? null
        : await references.genderToServer(row.jenisKelamin!),
    'user_id': row.userId == null
        ? null
        : await references.verifiedServerUser(row.userId!),
  };
  Future<void> push(String localUuid) => _exclusive(() async {
    late Map<String, dynamic> mutation;
    late String snapshot;
    await db.transaction(() async {
      await _bind();
      final conflicts = await db
          .customSelect(
            "SELECT mutation_id FROM petugas_sync_conflict WHERE scope=? AND local_uuid=? AND state IN ('open','held')",
            variables: [Variable(scope), Variable(localUuid)],
          )
          .get();
      if (conflicts.isNotEmpty) {
        throw const PetugasSyncFailure(
          PetugasSyncFailureKind.blocked,
          'unresolved conflict',
        );
      }
      final mapping = await PetugasIdentityMapRepository(db)
          .findByLocalUuid(localUuid);
      if (mapping == null ||
          !{'local_only', 'verified', 'server_only'}.contains(mapping.state)) {
        throw const PetugasSyncFailure(
          PetugasSyncFailureKind.blocked,
          'explicit identity reconciliation required',
        );
      }
      final row = await _row(localUuid);
      await db.customStatement(
        'INSERT OR IGNORE INTO petugas_sync_journal(local_uuid) VALUES(?)',
        [localUuid],
      );
      final journal = await db
          .customSelect(
            'SELECT * FROM petugas_sync_journal WHERE local_uuid=?',
            variables: [Variable(localUuid)],
          )
          .getSingle();
      final pending = journal.readNullable<String>('pending');
      if (pending != null) {
        mutation = syncMap(jsonDecode(pending));
        final payload = mutation['payload'];
        if (payload != null) {
          final p = syncMap(payload);
          if (p['jenis_kelamin_id'] != null) {
            await references.genderToLocal(p['jenis_kelamin_id'] as int);
          }
          if (p['user_id'] != null) {
            await references.verifiedServerUser(p['user_id'] as int);
          }
        }
        snapshot = journal.read<String>('snapshot');
        return;
      }
      if (!row.isSyncDirty) {
        throw const PetugasSyncFailure(
          PetugasSyncFailureKind.blocked,
          'record is clean',
        );
      }
      final version = journal.readNullable<int>('row_version');
      if (mapping.cloudUuid != null && version == null) {
        throw const PetugasSyncFailure(
          PetugasSyncFailureKind.blocked,
          'server version not established',
        );
      }
      final deleted = row.deletedAt != null || row.status != 1;
      if (deleted && mapping.cloudUuid == null) {
        throw const PetugasSyncFailure(
          PetugasSyncFailureKind.blocked,
          'unpublished local deletion',
        );
      }
      mutation = {
        'mutation_id': const Uuid().v4(),
        'petugas_uuid': mapping.cloudUuid ?? const Uuid().v4(),
        'operation': deleted ? 'delete' : 'upsert',
        'expected_row_version': version,
        if (!deleted) 'payload': await _payload(row),
      };
      snapshot = jsonEncode(row.toJson());
      await db.customStatement(
        'UPDATE petugas_sync_journal SET pending=?,snapshot=? WHERE local_uuid=?',
        [jsonEncode(mutation), snapshot, localUuid],
      );
    });
    late Map<String, dynamic> response;
    try {
      response = await api.push(mutation);
    } on PetugasSyncFailure catch (e) {
      if (e.kind == PetugasSyncFailureKind.conflict) {
        await _saveConflict(localUuid, mutation, snapshot, e.details);
      }
      if (e.kind == PetugasSyncFailureKind.expired) {
        await db.customStatement(
          "UPDATE petugas_sync_feed SET blocked='full_resync_required' WHERE id=1",
        );
      }
      rethrow;
    }
    final ack = syncMap(response['acknowledgement']);
    final canonical = syncMap(response['record']);
    if (ack['mutation_id'] != mutation['mutation_id'] ||
        ack['petugas_uuid'] != mutation['petugas_uuid'] ||
        ack['server_id'] is! int ||
        ack['server_id'] < 1 ||
        ack['row_version'] is! int ||
        ack['row_version'] < 1 ||
        canonical['uuid'] != ack['petugas_uuid'] ||
        canonical['id'] != ack['server_id'] ||
        ack['tombstone'] != (mutation['operation'] == 'delete') ||
        canonical['row_version'] != ack['row_version']) {
      throw const FormatException('Invalid acknowledgment');
    }
    await db.transaction(() async {
      final row = await _row(localUuid);
      await PetugasIdentityMapRepository(db).linkVerified(
        localUuid: localUuid,
        cloudUuid: ack['petugas_uuid'],
        serverId: ack['server_id'],
        evidence: 'acknowledged mutation ${ack['mutation_id']}',
      );
      await db.customStatement(
        'UPDATE petugas_sync_journal SET row_version=?,pending=NULL,snapshot=NULL WHERE local_uuid=?',
        [ack['row_version'], localUuid],
      );
      // Compare every persisted field, including updatedAt. Never clean an edit
      // made while the HTTP request was in flight; do not overwrite local data.
      if (jsonEncode(row.toJson()) == snapshot) {
        await (db.update(
          db.petugasLocals,
        )..where((r) => r.uuid.equals(localUuid))).write(
          PetugasLocalsCompanion(
            isSyncDirty: const Value(false),
            lastSyncedAt: Value(DateTime.now()),
          ),
        );
      }
    });
  });

  Future<void> pull({
    int limit = 100,
    int? throughCursor,
  }) => _exclusive(() async {
    if (limit < 1 || limit > 500) {
      throw ArgumentError.value(limit, 'limit', 'Expected 1..500');
    }
    await validatePullContext?.call();
    await db.transaction(_bind);
    final pending = await db
        .customSelect(
          'SELECT local_uuid FROM petugas_sync_journal WHERE pending IS NOT NULL LIMIT 1',
        )
        .get();
    if (pending.isNotEmpty) {
      throw const PetugasSyncFailure(
        PetugasSyncFailureKind.blocked,
        'resolve/replay pending mutation before pull',
      );
    }
    while (true) {
      final feed = await db
          .customSelect('SELECT cursor FROM petugas_sync_feed WHERE id=1')
          .getSingle();
      final cursor = feed.read<int>('cursor');
      if (throughCursor != null && cursor > throughCursor) {
        throw const PetugasSyncFailure(
          PetugasSyncFailureKind.blocked,
          'cursor exceeds the reviewed baseline boundary',
        );
      }
      final remaining = throughCursor == null ? limit : throughCursor - cursor;
      final pageLimit = remaining > 0 && remaining < limit ? remaining : limit;
      late Map<String, dynamic> page;
      try {
        page = await api.pull(cursor, limit: pageLimit);
      } on PetugasSyncFailure catch (e) {
        if (e.kind == PetugasSyncFailureKind.expired) {
          await db.customStatement(
            "UPDATE petugas_sync_feed SET blocked='full_resync_required' WHERE id=1",
          );
        }
        rethrow;
      }
      final changes = page['changes'];
      final next = page['next_cursor'];
      final more = page['has_more'];
      if (changes is! List ||
          next is! int ||
          more is! bool ||
          next < cursor ||
          (throughCursor != null && next > throughCursor) ||
          changes.length > pageLimit ||
          (more && next == cursor)) {
        throw const FormatException('Invalid pull page');
      }
      await db.transaction(() async {
        await validatePullContext?.call();
        await _bind();
        final current = await db
            .customSelect('SELECT cursor FROM petugas_sync_feed WHERE id=1')
            .getSingle();
        if (current.read<int>('cursor') != cursor) {
          throw const PetugasSyncFailure(
            PetugasSyncFailureKind.blocked,
            'cursor changed while awaiting HTTP; retry from persisted state',
          );
        }
        var last = cursor;
        for (final value in changes) {
          final event = syncMap(value);
          final seq = event['publication_sequence'];
          if (seq is! int || seq != last + 1 || seq > next) {
            throw const FormatException('Invalid event sequence');
          }
          last = seq;
          await preparePullIdentity?.call(event);
          await _apply(event);
        }
        if (last != next) {
          throw const FormatException('Cursor did not match events');
        }
        await validatePullContext?.call();
        await db.customStatement(
          'UPDATE petugas_sync_feed SET cursor=? WHERE id=1',
          [next],
        );
      });
      if (!more || next == throughCursor) {
        break;
      }
    }
  });
  Future<void> _apply(
    Map<String, dynamic> event, {
    bool resolving = false,
  }) async {
    final cloud = event['petugas_uuid'];
    final id = event['server_id'];
    final version = event['row_version'];
    final tomb = event['tombstone'];
    if (cloud is! String ||
        !RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(cloud) ||
        id is! int ||
        id < 1 ||
        version is! int ||
        version < 1 ||
        tomb is! bool) {
      throw const FormatException('Invalid event identity');
    }
    final map = await (db.select(
      db.petugasIdentityMaps,
    )..where((m) => m.cloudUuid.equals(cloud))).getSingleOrNull();
    final uuid = map?.localUuid ?? const Uuid().v4();
    if (map != null) {
      if (map.serverId != id ||
          !{'verified', 'server_only'}.contains(map.state)) {
        throw const PetugasSyncFailure(
          PetugasSyncFailureKind.blocked,
          'identity mismatch',
        );
      }
      final row = await _row(uuid);
      if (row.isSyncDirty && !resolving) {
        throw const PetugasSyncFailure(
          PetugasSyncFailureKind.blocked,
          'dirty local record requires conflict resolution',
        );
      }
      final journal = await db
          .customSelect(
            'SELECT row_version FROM petugas_sync_journal WHERE local_uuid=?',
            variables: [Variable(uuid)],
          )
          .getSingleOrNull();
      if (!resolving &&
          (journal?.readNullable<int>('row_version') ?? 0) >= version) {
        return;
      }
    }
    final p = tomb ? <String, dynamic>{} : syncMap(event['payload']);
    if (!tomb) {
      for (final key in ['nama', 'email']) {
        if (p[key] is! String || (p[key] as String).trim().isEmpty) {
          throw const FormatException('Missing required Petugas payload');
        }
      }
      for (final key in ['nik', 'alamat', 'tempat_lahir', 'no_telp']) {
        if (p[key] != null && p[key] is! String) {
          throw const FormatException('Invalid Petugas text field');
        }
      }
      for (final key in ['jenis_kelamin_id', 'user_id']) {
        if (p[key] != null && (p[key] is! int || (p[key] as int) < 1)) {
          throw const FormatException('Invalid Petugas reference');
        }
      }
      final date = p['tanggal_lahir'];
      if (date != null &&
          (date is! String ||
              !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
              DateTime.tryParse(date)?.toIso8601String().substring(0, 10) !=
                  date)) {
        throw const FormatException('Invalid Petugas birth date');
      }
    }
    final gender = p['jenis_kelamin_id'];
    final user = p['user_id'];
    final localGender = gender == null
        ? null
        : await references.genderToLocal(gender as int);
    final serverUser = user == null
        ? null
        : await references.verifiedServerUser(user as int);
    final date = p['tanggal_lahir'];
    final values = PetugasLocalsCompanion(
      nama: Value(p['nama'] as String? ?? ''),
      email: Value(p['email'] as String? ?? ''),
      nik: Value(p['nik'] as String?),
      alamat: Value(p['alamat'] as String?),
      tempatLahir: Value(p['tempat_lahir'] as String?),
      tanggalLahir: Value(date == null ? null : DateTime.parse(date as String)),
      jenisKelamin: Value(localGender),
      userId: Value(serverUser),
      noTelp: Value(p['no_telp'] as String?),
      status: Value(tomb ? 0 : 1),
      deletedAt: Value(tomb ? DateTime.now() : null),
      isSyncDirty: const Value(false),
      lastSyncedAt: Value(DateTime.now()),
    );
    if (map == null) {
      await db
          .into(db.petugasLocals)
          .insert(values.copyWith(uuid: Value(uuid)));
      await PetugasIdentityMapRepository(db).linkServerOnly(
        localUuid: uuid,
        cloudUuid: cloud,
        serverId: id,
        evidence: 'explicit cloud feed identity',
      );
    } else if (tomb) {
      await (db.update(
        db.petugasLocals,
      )..where((r) => r.uuid.equals(uuid))).write(
        PetugasLocalsCompanion(
          status: const Value(0),
          deletedAt: Value(DateTime.now()),
          isSyncDirty: const Value(false),
        ),
      );
    } else {
      await (db.update(
        db.petugasLocals,
      )..where((r) => r.uuid.equals(uuid))).write(values);
    }
    await db.customStatement(
      'INSERT INTO petugas_sync_journal(local_uuid,row_version) VALUES(?,?) ON CONFLICT(local_uuid) DO UPDATE SET row_version=excluded.row_version',
      [uuid, version],
    );
  }
}
