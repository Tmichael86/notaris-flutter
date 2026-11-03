import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';

/// Explicit, controlled CREATE slice. Never registered with global sync.
class PekerjaanNotarisCloudRepository {
  PekerjaanNotarisCloudRepository(this.db, this.dio, {required this.scope});

  final AppDatabase db;
  final Dio dio;
  final String scope;
  static const _uuid = Uuid();

  Future<void> _bind() async {
    if (scope.trim().isEmpty) throw StateError('Cloud scope required');
    final known = await db
        .customSelect('SELECT scope FROM pekerjaan_notaris_sync_feed')
        .get();
    if (known.isNotEmpty && known.single.read<String>('scope') != scope) {
      throw StateError('Cloud scope mismatch');
    }
    await db.customStatement(
      'INSERT OR IGNORE INTO pekerjaan_notaris_sync_feed(scope,cursor) VALUES(?,0)',
      [scope],
    );
  }

  Future<Map<String, dynamic>> _snapshot(int localId, String mutationId) async {
    final parent =
        await (db.select(db.pekerjaanNotarisLocals)..where(
              (t) =>
                  t.id.equals(localId) &
                  t.deletedAt.isNull() &
                  t.status.equals(1),
            ))
            .getSingleOrNull();
    if (parent == null) throw StateError('Pekerjaan Notaris lokal tidak aktif');
    final harga = await db.pekerjaanDao.getHargaNotaris(localId);
    final proses = await db.pekerjaanDao.getProsesNotaris(localId);
    if (harga.isEmpty || proses.isEmpty) {
      throw StateError('Aggregate belum lengkap');
    }
    return {
      'mutation_id': mutationId,
      'uuid': parent.uuid,
      'nama': parent.nama,
      'harga': [
        for (final row in harga)
          {
            'uuid': row.uuid,
            'category_uuid': await _verifiedCategory(row.kategoriPekerjaanId),
            'harga': row.harga,
            'estimasi_waktu': row.estimasiWaktu,
          },
      ],
      'proses': [
        for (final row in proses)
          {
            'uuid': row.uuid,
            'nama': row.nama,
            'detail': row.detail,
            'atribut': [
              for (final attr in await db.pekerjaanDao.getAtributNotaris(
                row.id,
              ))
                {'uuid': attr.uuid, 'atribut': attr.atribut},
            ],
          },
      ],
    };
  }

  Future<String> _verifiedCategory(int id) async {
    final category =
        await (db.select(db.pekerjaanKategoris)..where(
              (t) =>
                  t.id.equals(id) & t.status.equals(1) & t.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (category == null ||
        category.isSyncDirty ||
        category.uuid.trim().isEmpty) {
      throw StateError('Kategori belum terverifikasi di cloud');
    }
    return category.uuid;
  }

  /// A pending request is durable and reused byte-for-byte after failed HTTP.
  Future<Map<String, dynamic>> pushCreate(int localId) async {
    final payload = await db.transaction(() async {
      await _bind();
      final parent = await (db.select(
        db.pekerjaanNotarisLocals,
      )..where((t) => t.id.equals(localId))).getSingle();
      final identity = await db
          .customSelect(
            'SELECT local_uuid FROM pekerjaan_notaris_sync_identity WHERE local_uuid=?',
            variables: [Variable.withString(parent.uuid)],
          )
          .get();
      if (identity.isNotEmpty) throw StateError('CREATE already acknowledged');
      final pending = await db
          .customSelect(
            'SELECT payload,state FROM pekerjaan_notaris_sync_pending WHERE local_uuid=?',
            variables: [Variable.withString(parent.uuid)],
          )
          .get();
      if (pending.isNotEmpty) {
        if (pending.single.read<String>('state') != 'pending') {
          throw StateError('CREATE already acknowledged');
        }
        return jsonDecode(pending.single.read<String>('payload'))
            as Map<String, dynamic>;
      }
      final mutationId = _uuid.v4();
      final body = await _snapshot(localId, mutationId);
      await db.customStatement(
        'INSERT INTO pekerjaan_notaris_sync_pending(local_uuid,mutation_id,payload,state) VALUES(?,?,?,\'pending\')',
        [parent.uuid, mutationId, jsonEncode(body)],
      );
      return body;
    });
    final response = await dio.post<Map<String, dynamic>>(
      '/pekerjaan-notaris/sync/create',
      data: payload,
    );
    final ack = Map<String, dynamic>.from(
      response.data!['acknowledgement'] as Map,
    );
    if (ack['mutation_id'] != payload['mutation_id'] ||
        ack['uuid'] != payload['uuid'] ||
        ack['revision'] != 1) {
      throw const FormatException('Invalid Notaris cloud receipt');
    }
    await db.transaction(() async {
      await _bind();
      final pending = await db
          .customSelect(
            'SELECT payload,state FROM pekerjaan_notaris_sync_pending WHERE local_uuid=?',
            variables: [Variable.withString(payload['uuid'] as String)],
          )
          .getSingle();
      if (pending.read<String>('payload') != jsonEncode(payload) ||
          pending.read<String>('state') != 'pending') {
        throw StateError('Local mutation changed during request');
      }
      final unchanged =
          jsonEncode(
            await _snapshot(localId, payload['mutation_id'] as String),
          ) ==
          jsonEncode(payload);
      await db.customStatement(
        'INSERT INTO pekerjaan_notaris_sync_identity(local_uuid,cloud_uuid,scope,revision) VALUES(?,?,?,1)',
        [payload['uuid'], payload['uuid'], scope],
      );
      await db.customStatement(
        "UPDATE pekerjaan_notaris_sync_pending SET state='acked' WHERE local_uuid=?",
        [payload['uuid']],
      );
      if (unchanged) {
        await db.customStatement(
          'UPDATE pekerjaan_notaris SET is_sync_dirty=0,last_synced_at=? WHERE id=?',
          [DateTime.now().millisecondsSinceEpoch ~/ 1000, localId],
        );
        for (final table in [
          'pekerjaan_notaris_harga',
          'pekerjaan_notaris_proses',
          'pekerjaan_notaris_atributs',
        ]) {
          await db.customStatement(
            'UPDATE $table SET is_sync_dirty=0,last_synced_at=? WHERE pekerjaan_notaris_id=?',
            [DateTime.now().millisecondsSinceEpoch ~/ 1000, localId],
          );
        }
      }
      // Edits made during the HTTP request remain dirty for a later UPDATE slice.
    });
    return ack;
  }

  Future<int> pullPage({int limit = 100}) async {
    final cursor = await db.transaction(() async {
      await _bind();
      final row = await db
          .customSelect(
            'SELECT cursor FROM pekerjaan_notaris_sync_feed WHERE scope=?',
            variables: [Variable.withString(scope)],
          )
          .getSingle();
      return row.read<int>('cursor');
    });
    final response = await dio.get<Map<String, dynamic>>(
      '/pekerjaan-notaris/sync/pull',
      queryParameters: {'cursor': cursor, 'limit': limit},
    );
    final page = response.data!;
    final changes = (page['changes'] as List).cast<Map<String, dynamic>>();
    final next = page['next_cursor'] as int;
    await db.transaction(() async {
      await _bind();
      final stored = await db
          .customSelect(
            'SELECT cursor FROM pekerjaan_notaris_sync_feed WHERE scope=?',
            variables: [Variable.withString(scope)],
          )
          .getSingle();
      if (stored.read<int>('cursor') != cursor) {
        throw StateError('Cursor changed during pull');
      }
      var seen = cursor;
      for (final change in changes) {
        final sequence = change['sequence'] as int;
        if (sequence <= seen || sequence > next) {
          throw const FormatException('Publication order invalid');
        }
        await _apply(
          change['aggregate'] as Map<String, dynamic>,
          change['revision'] as int,
        );
        seen = sequence;
      }
      if (seen != next) {
        throw const FormatException('Cursor does not match events');
      }
      await db.customStatement(
        'UPDATE pekerjaan_notaris_sync_feed SET cursor=? WHERE scope=?',
        [next, scope],
      );
    });
    return next;
  }

  Future<void> _apply(Map<String, dynamic> aggregate, int revision) async {
    if (revision != 1) throw StateError('Only CREATE publication supported');
    final uuid = aggregate['uuid'] as String;
    final identity = await db
        .customSelect(
          'SELECT scope,revision FROM pekerjaan_notaris_sync_identity WHERE cloud_uuid=?',
          variables: [Variable.withString(uuid)],
        )
        .get();
    if (identity.isNotEmpty) {
      if (identity.single.read<String>('scope') != scope ||
          identity.single.read<int>('revision') != revision) {
        throw StateError('Cloud identity mismatch');
      }
      return;
    }
    final existing = await (db.select(
      db.pekerjaanNotarisLocals,
    )..where((t) => t.uuid.equals(uuid))).getSingleOrNull();
    if (existing != null) throw StateError('Unreviewed local UUID collision');
    final parentId = await db
        .into(db.pekerjaanNotarisLocals)
        .insert(
          PekerjaanNotarisLocalsCompanion.insert(
            uuid: uuid,
            nama: aggregate['nama'] as String,
            isSyncDirty: const Value(false),
          ),
        );
    for (final raw in aggregate['harga'] as List) {
      final row = raw as Map<String, dynamic>;
      final category =
          await (db.select(db.pekerjaanKategoris)..where(
                (t) =>
                    t.uuid.equals(row['category_uuid'] as String) &
                    t.status.equals(1) &
                    t.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      if (category == null || category.isSyncDirty) {
        throw StateError('Category reference unresolved');
      }
      await db
          .into(db.pekerjaanNotarisHargaLocals)
          .insert(
            PekerjaanNotarisHargaLocalsCompanion.insert(
              uuid: row['uuid'] as String,
              pekerjaanNotarisId: parentId,
              kategoriPekerjaanId: category.id,
              harga: row['harga'] as String,
              estimasiWaktu: row['estimasi_waktu'] as String,
              isSyncDirty: const Value(false),
            ),
          );
    }
    for (final raw in aggregate['proses'] as List) {
      final row = raw as Map<String, dynamic>;
      final processId = await db
          .into(db.pekerjaanNotarisProsesLocals)
          .insert(
            PekerjaanNotarisProsesLocalsCompanion.insert(
              uuid: row['uuid'] as String,
              pekerjaanNotarisId: parentId,
              nama: row['nama'] as String,
              detail: row['detail'] as String,
              isSyncDirty: const Value(false),
            ),
          );
      for (final attrRaw in row['atribut'] as List) {
        final attr = attrRaw as Map<String, dynamic>;
        await db
            .into(db.pekerjaanNotarisAtributLocals)
            .insert(
              PekerjaanNotarisAtributLocalsCompanion.insert(
                uuid: attr['uuid'] as String,
                pekerjaanNotarisId: parentId,
                prosesPekerjaanNotarisId: processId,
                atribut: Value(attr['atribut'] as String),
                isSyncDirty: const Value(false),
              ),
            );
      }
    }
    await db.customStatement(
      'INSERT INTO pekerjaan_notaris_sync_identity(local_uuid,cloud_uuid,scope,revision) VALUES(?,?,?,?)',
      [uuid, uuid, scope, revision],
    );
  }
}
