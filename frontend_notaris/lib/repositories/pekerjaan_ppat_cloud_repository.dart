import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';

/// Explicit, controlled Ppat aggregate sync. Never registered with global sync.
class PekerjaanPpatCloudRepository {
  PekerjaanPpatCloudRepository(this.db, this.dio, {required this.scope});

  final AppDatabase db;
  final Dio dio;
  final String scope;
  static const _uuid = Uuid();

  Future<void> _bind() async {
    if (scope.trim().isEmpty) throw StateError('Cloud scope required');
    final known = await db
        .customSelect('SELECT scope FROM pekerjaan_ppat_sync_feed')
        .get();
    if (known.isNotEmpty && known.single.read<String>('scope') != scope) {
      throw StateError('Cloud scope mismatch');
    }
    await db.customStatement(
      'INSERT OR IGNORE INTO pekerjaan_ppat_sync_feed(scope,cursor) VALUES(?,0)',
      [scope],
    );
  }

  Future<Map<String, dynamic>> _snapshot(int localId, String mutationId) async {
    final parent =
        await (db.select(db.pekerjaanPpatLocals)..where(
              (t) =>
                  t.id.equals(localId) &
                  t.deletedAt.isNull() &
                  t.status.equals(1),
            ))
            .getSingleOrNull();
    if (parent == null) throw StateError('Pekerjaan Ppat lokal tidak aktif');
    final harga = await db.pekerjaanDao.getHargaPpat(localId);
    final proses = await db.pekerjaanDao.getProsesPpat(localId);
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
              for (final attr in await db.pekerjaanDao.getAtributPpat(row.id))
                {
                  'uuid': attr.uuid,
                  'atribut': _verifiedAttribute(attr.atribut),
                },
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

  String _verifiedAttribute(String? value) {
    if (value == null || value.trim().isEmpty) {
      throw StateError('Atribut lokal tidak lengkap untuk cloud');
    }
    return value;
  }

  /// A pending request is durable and reused byte-for-byte after failed HTTP.
  Future<Map<String, dynamic>> pushCreate(int localId) async {
    final payload = await db.transaction(() async {
      await _bind();
      final parent = await (db.select(
        db.pekerjaanPpatLocals,
      )..where((t) => t.id.equals(localId))).getSingle();
      final identity = await db
          .customSelect(
            'SELECT local_uuid FROM pekerjaan_ppat_sync_identity WHERE local_uuid=?',
            variables: [Variable.withString(parent.uuid)],
          )
          .get();
      if (identity.isNotEmpty) throw StateError('CREATE already acknowledged');
      final pending = await db
          .customSelect(
            'SELECT payload,state FROM pekerjaan_ppat_sync_pending WHERE local_uuid=?',
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
        'INSERT INTO pekerjaan_ppat_sync_pending(local_uuid,mutation_id,payload,state) VALUES(?,?,?,\'pending\')',
        [parent.uuid, mutationId, jsonEncode(body)],
      );
      return body;
    });
    final response = await dio.post<Map<String, dynamic>>(
      '/pekerjaan-ppat/sync/create',
      data: payload,
    );
    final ack = Map<String, dynamic>.from(
      response.data!['acknowledgement'] as Map,
    );
    if (ack['mutation_id'] != payload['mutation_id'] ||
        ack['uuid'] != payload['uuid'] ||
        ack['revision'] != 1) {
      throw const FormatException('Invalid Ppat cloud receipt');
    }
    await db.transaction(() async {
      await _bind();
      final pending = await db
          .customSelect(
            'SELECT payload,state FROM pekerjaan_ppat_sync_pending WHERE local_uuid=?',
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
        'INSERT INTO pekerjaan_ppat_sync_identity(local_uuid,cloud_uuid,scope,revision) VALUES(?,?,?,1)',
        [payload['uuid'], payload['uuid'], scope],
      );
      await db.customStatement(
        "UPDATE pekerjaan_ppat_sync_pending SET state='acked' WHERE local_uuid=?",
        [payload['uuid']],
      );
      if (unchanged) {
        await db.customStatement(
          'UPDATE pekerjaan_ppat SET is_sync_dirty=0,last_synced_at=? WHERE id=?',
          [DateTime.now().millisecondsSinceEpoch ~/ 1000, localId],
        );
        for (final table in [
          'pekerjaan_ppat_harga',
          'pekerjaan_ppat_proses',
          'pekerjaan_ppat_atributs',
        ]) {
          await db.customStatement(
            'UPDATE $table SET is_sync_dirty=0,last_synced_at=? WHERE pekerjaan_ppat_id=?',
            [DateTime.now().millisecondsSinceEpoch ~/ 1000, localId],
          );
        }
      }
      // Edits made during the HTTP request remain dirty for a later UPDATE slice.
    });
    return ack;
  }

  Future<Map<String, dynamic>> pushUpdate(int localId) =>
      _pushRevision(localId, delete: false);

  Future<Map<String, dynamic>> pushDelete(int localId) =>
      _pushRevision(localId, delete: true);

  Future<Map<String, dynamic>> _pushRevision(
    int localId, {
    required bool delete,
  }) async {
    final payload = await db.transaction(() async {
      await _bind();
      final parent = await (db.select(
        db.pekerjaanPpatLocals,
      )..where((t) => t.id.equals(localId))).getSingle();
      final identity = await db
          .customSelect(
            'SELECT scope,revision FROM pekerjaan_ppat_sync_identity WHERE local_uuid=?',
            variables: [Variable.withString(parent.uuid)],
          )
          .getSingleOrNull();
      if (identity == null || identity.read<String>('scope') != scope) {
        throw StateError('Verified cloud identity required');
      }
      final pending = await db
          .customSelect(
            'SELECT payload,state FROM pekerjaan_ppat_sync_pending WHERE local_uuid=?',
            variables: [Variable.withString(parent.uuid)],
          )
          .getSingleOrNull();
      if (pending != null && pending.read<String>('state') == 'pending') {
        final saved =
            jsonDecode(pending.read<String>('payload')) as Map<String, dynamic>;
        if ((saved['expected_revision'] as int?) == null ||
            (saved['delete'] == true) != delete) {
          throw StateError('Another mutation is pending');
        }
        return saved;
      }
      if (delete
          ? (parent.status != 0 || parent.deletedAt == null)
          : (parent.status != 1 || parent.deletedAt != null)) {
        throw StateError('Local aggregate state does not match operation');
      }
      if (!parent.isSyncDirty) throw StateError('No local change to send');
      final mutationId = _uuid.v4();
      final body = delete
          ? <String, dynamic>{
              'mutation_id': mutationId,
              'uuid': parent.uuid,
              'expected_revision': identity.read<int>('revision'),
              'delete': true,
            }
          : <String, dynamic>{
              ...await _snapshot(localId, mutationId),
              'expected_revision': identity.read<int>('revision'),
            };
      await db.customStatement(
        'INSERT INTO pekerjaan_ppat_sync_pending(local_uuid,mutation_id,payload,state) '
        "VALUES(?,?,?,'pending') ON CONFLICT(local_uuid) DO UPDATE SET mutation_id=excluded.mutation_id,payload=excluded.payload,state='pending'",
        [parent.uuid, mutationId, jsonEncode(body)],
      );
      return body;
    });
    final operation = delete ? 'delete' : 'update';
    // The local-only operation marker is never sent to the strict Go decoder.
    final request = Map<String, dynamic>.from(payload)..remove('delete');
    final response = await dio.post<Map<String, dynamic>>(
      '/pekerjaan-ppat/sync/$operation',
      data: request,
    );
    final ack = Map<String, dynamic>.from(
      response.data!['acknowledgement'] as Map,
    );
    if (ack['mutation_id'] != payload['mutation_id'] ||
        ack['uuid'] != payload['uuid'] ||
        ack['revision'] != (payload['expected_revision'] as int) + 1) {
      throw const FormatException('Invalid Ppat cloud receipt');
    }
    await db.transaction(() async {
      final pending = await db
          .customSelect(
            'SELECT payload,state FROM pekerjaan_ppat_sync_pending WHERE local_uuid=?',
            variables: [Variable.withString(payload['uuid'] as String)],
          )
          .getSingle();
      if (pending.read<String>('state') != 'pending' ||
          pending.read<String>('payload') != jsonEncode(payload)) {
        throw StateError('Local mutation changed during request');
      }
      final parent = await (db.select(
        db.pekerjaanPpatLocals,
      )..where((t) => t.id.equals(localId))).getSingle();
      var unchanged = delete && parent.status == 0 && parent.deletedAt != null;
      if (!delete) {
        try {
          final current = await _snapshot(
            localId,
            payload['mutation_id'] as String,
          );
          final sent = Map<String, dynamic>.from(payload)
            ..remove('expected_revision');
          unchanged = jsonEncode(current) == jsonEncode(sent);
        } on StateError {
          // An edit or delete during HTTP must stay dirty after the receipt.
          unchanged = false;
        }
      }
      final updated = await db.customUpdate(
        'UPDATE pekerjaan_ppat_sync_identity SET revision=? WHERE local_uuid=? AND scope=? AND revision=?',
        variables: [
          Variable.withInt(ack['revision'] as int),
          Variable.withString(payload['uuid'] as String),
          Variable.withString(scope),
          Variable.withInt(payload['expected_revision'] as int),
        ],
      );
      if (updated != 1) throw StateError('Cloud revision changed during push');
      await db.customStatement(
        "UPDATE pekerjaan_ppat_sync_pending SET state='acked' WHERE local_uuid=?",
        [payload['uuid']],
      );
      if (unchanged) {
        final stamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        await db.customStatement(
          'UPDATE pekerjaan_ppat SET is_sync_dirty=0,last_synced_at=? WHERE id=?',
          [stamp, localId],
        );
        for (final table in [
          'pekerjaan_ppat_harga',
          'pekerjaan_ppat_proses',
          'pekerjaan_ppat_atributs',
        ]) {
          await db.customStatement(
            'UPDATE $table SET is_sync_dirty=0,last_synced_at=? WHERE pekerjaan_ppat_id=?',
            [stamp, localId],
          );
        }
      }
    });
    return ack;
  }

  Future<int> pullPage({int limit = 100}) async {
    final cursor = await db.transaction(() async {
      await _bind();
      final row = await db
          .customSelect(
            'SELECT cursor FROM pekerjaan_ppat_sync_feed WHERE scope=?',
            variables: [Variable.withString(scope)],
          )
          .getSingle();
      return row.read<int>('cursor');
    });
    final response = await dio.get<Map<String, dynamic>>(
      '/pekerjaan-ppat/sync/pull',
      queryParameters: {'cursor': cursor, 'limit': limit},
    );
    final page = response.data!;
    final changes = (page['changes'] as List).cast<Map<String, dynamic>>();
    final next = page['next_cursor'] as int;
    await db.transaction(() async {
      await _bind();
      final stored = await db
          .customSelect(
            'SELECT cursor FROM pekerjaan_ppat_sync_feed WHERE scope=?',
            variables: [Variable.withString(scope)],
          )
          .getSingle();
      if (stored.read<int>('cursor') != cursor) {
        throw StateError('Cursor changed during pull');
      }
      var seen = cursor;
      for (final change in changes) {
        final sequence = change['sequence'] as int;
        if (sequence != seen + 1 || sequence > next) {
          throw const FormatException('Publication order invalid');
        }
        await _apply(
          change['aggregate'] as Map<String, dynamic>,
          change['revision'] as int,
          change['operation'] as String? ?? 'create',
        );
        seen = sequence;
      }
      if (seen != next) {
        throw const FormatException('Cursor does not match events');
      }
      await db.customStatement(
        'UPDATE pekerjaan_ppat_sync_feed SET cursor=? WHERE scope=?',
        [next, scope],
      );
    });
    return next;
  }

  Future<void> _apply(
    Map<String, dynamic> aggregate,
    int revision,
    String operation,
  ) async {
    if (!{'create', 'update', 'delete'}.contains(operation)) {
      throw const FormatException('Unknown Ppat publication operation');
    }
    final uuid = aggregate['uuid'] as String;
    final identity = await db
        .customSelect(
          'SELECT scope,revision FROM pekerjaan_ppat_sync_identity WHERE cloud_uuid=?',
          variables: [Variable.withString(uuid)],
        )
        .get();
    if (identity.isNotEmpty) {
      if (identity.single.read<String>('scope') != scope) {
        throw StateError('Cloud identity mismatch');
      }
      final prior = identity.single.read<int>('revision');
      if (revision <= prior) return;
      if (revision != prior + 1 || operation == 'create') {
        throw StateError('Cloud revision gap');
      }
      final parent = await (db.select(
        db.pekerjaanPpatLocals,
      )..where((t) => t.uuid.equals(uuid))).getSingle();
      final pending = await db
          .customSelect(
            "SELECT count(*) AS n FROM pekerjaan_ppat_sync_pending WHERE local_uuid=? AND state='pending'",
            variables: [Variable.withString(parent.uuid)],
          )
          .getSingle();
      if (parent.isSyncDirty ||
          pending.read<int>('n') != 0 ||
          await _hasDirtyChild(parent.id)) {
        throw StateError('Local dirty aggregate requires reconciliation');
      }
      if (operation == 'delete') {
        await db.customStatement(
          'UPDATE pekerjaan_ppat SET status=0,deleted_at=?,is_sync_dirty=0 WHERE id=?',
          [DateTime.now().millisecondsSinceEpoch ~/ 1000, parent.id],
        );
      } else {
        if (parent.status != 1) {
          throw StateError('Deleted aggregate cannot update');
        }
        await db.customStatement(
          'UPDATE pekerjaan_ppat SET nama=?,is_sync_dirty=0 WHERE id=?',
          [aggregate['nama'], parent.id],
        );
        await _replaceChildren(parent.id, aggregate);
      }
      await db.customStatement(
        'UPDATE pekerjaan_ppat_sync_identity SET revision=? WHERE cloud_uuid=? AND scope=?',
        [revision, uuid, scope],
      );
      return;
    }
    if (operation != 'create' || revision != 1) {
      throw StateError('Unknown cloud aggregate before revision');
    }
    final existing = await (db.select(
      db.pekerjaanPpatLocals,
    )..where((t) => t.uuid.equals(uuid))).getSingleOrNull();
    if (existing != null) throw StateError('Unreviewed local UUID collision');
    final parentId = await db
        .into(db.pekerjaanPpatLocals)
        .insert(
          PekerjaanPpatLocalsCompanion.insert(
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
          .into(db.pekerjaanPpatHargaLocals)
          .insert(
            PekerjaanPpatHargaLocalsCompanion.insert(
              uuid: row['uuid'] as String,
              pekerjaanPpatId: parentId,
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
          .into(db.pekerjaanPpatProsesLocals)
          .insert(
            PekerjaanPpatProsesLocalsCompanion.insert(
              uuid: row['uuid'] as String,
              pekerjaanPpatId: parentId,
              nama: row['nama'] as String,
              detail: row['detail'] as String,
              isSyncDirty: const Value(false),
            ),
          );
      for (final attrRaw in row['atribut'] as List) {
        final attr = attrRaw as Map<String, dynamic>;
        await db
            .into(db.pekerjaanPpatAtributLocals)
            .insert(
              PekerjaanPpatAtributLocalsCompanion.insert(
                uuid: attr['uuid'] as String,
                pekerjaanPpatId: parentId,
                prosesPekerjaanPpatId: processId,
                atribut: Value(attr['atribut'] as String),
                isSyncDirty: const Value(false),
              ),
            );
      }
    }
    await db.customStatement(
      'INSERT INTO pekerjaan_ppat_sync_identity(local_uuid,cloud_uuid,scope,revision) VALUES(?,?,?,?)',
      [uuid, uuid, scope, revision],
    );
  }

  Future<bool> _hasDirtyChild(int parentId) async {
    for (final table in [
      'pekerjaan_ppat_harga',
      'pekerjaan_ppat_proses',
      'pekerjaan_ppat_atributs',
    ]) {
      final row = await db
          .customSelect(
            'SELECT count(*) AS n FROM $table WHERE pekerjaan_ppat_id=? AND is_sync_dirty=1',
            variables: [Variable.withInt(parentId)],
          )
          .getSingle();
      if (row.read<int>('n') != 0) return true;
    }
    return false;
  }

  Future<void> _replaceChildren(
    int parentId,
    Map<String, dynamic> aggregate,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    for (final table in [
      'pekerjaan_ppat_harga',
      'pekerjaan_ppat_proses',
      'pekerjaan_ppat_atributs',
    ]) {
      await db.customStatement(
        'UPDATE $table SET status=0,deleted_at=?,is_sync_dirty=0 WHERE pekerjaan_ppat_id=?',
        [now, parentId],
      );
    }
    for (final raw in aggregate['harga'] as List) {
      final h = raw as Map<String, dynamic>;
      final category =
          await (db.select(db.pekerjaanKategoris)..where(
                (t) =>
                    t.uuid.equals(h['category_uuid'] as String) &
                    t.status.equals(1) &
                    t.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      if (category == null || category.isSyncDirty) {
        throw StateError('Category reference unresolved');
      }
      final existing = await db
          .customSelect(
            'SELECT id,pekerjaan_ppat_id FROM pekerjaan_ppat_harga WHERE uuid=?',
            variables: [Variable.withString(h['uuid'] as String)],
          )
          .getSingleOrNull();
      if (existing != null) {
        if (existing.read<int>('pekerjaan_ppat_id') != parentId) {
          throw StateError('Child UUID ownership mismatch');
        }
        await db.customStatement(
          'UPDATE pekerjaan_ppat_harga SET kategori_pekerjaan_id=?,harga=?,estimasi_waktu=?,status=1,deleted_at=NULL,is_sync_dirty=0 WHERE id=?',
          [
            category.id,
            h['harga'],
            h['estimasi_waktu'],
            existing.read<int>('id'),
          ],
        );
      } else {
        await db.customStatement(
          'INSERT INTO pekerjaan_ppat_harga(uuid,pekerjaan_ppat_id,kategori_pekerjaan_id,harga,estimasi_waktu,status,is_sync_dirty) VALUES(?,?,?,?,?,1,0)',
          [h['uuid'], parentId, category.id, h['harga'], h['estimasi_waktu']],
        );
      }
    }
    for (final raw in aggregate['proses'] as List) {
      final p = raw as Map<String, dynamic>;
      final existing = await db
          .customSelect(
            'SELECT id,pekerjaan_ppat_id FROM pekerjaan_ppat_proses WHERE uuid=?',
            variables: [Variable.withString(p['uuid'] as String)],
          )
          .getSingleOrNull();
      int processId;
      if (existing != null) {
        if (existing.read<int>('pekerjaan_ppat_id') != parentId) {
          throw StateError('Process UUID ownership mismatch');
        }
        processId = existing.read<int>('id');
        await db.customStatement(
          'UPDATE pekerjaan_ppat_proses SET nama=?,detail=?,status=1,deleted_at=NULL,is_sync_dirty=0 WHERE id=?',
          [p['nama'], p['detail'], processId],
        );
      } else {
        processId = await db
            .into(db.pekerjaanPpatProsesLocals)
            .insert(
              PekerjaanPpatProsesLocalsCompanion.insert(
                uuid: p['uuid'] as String,
                pekerjaanPpatId: parentId,
                nama: p['nama'] as String,
                detail: p['detail'] as String,
                isSyncDirty: const Value(false),
              ),
            );
      }
      for (final attrRaw in p['atribut'] as List) {
        final attr = attrRaw as Map<String, dynamic>;
        final old = await db
            .customSelect(
              'SELECT id,pekerjaan_ppat_id,proses_pekerjaan_ppat_id FROM pekerjaan_ppat_atributs WHERE uuid=?',
              variables: [Variable.withString(attr['uuid'] as String)],
            )
            .getSingleOrNull();
        if (old != null) {
          if (old.read<int>('pekerjaan_ppat_id') != parentId ||
              old.read<int>('proses_pekerjaan_ppat_id') != processId) {
            throw StateError('Attribute UUID ownership mismatch');
          }
          await db.customStatement(
            'UPDATE pekerjaan_ppat_atributs SET atribut=?,status=1,deleted_at=NULL,is_sync_dirty=0 WHERE id=?',
            [attr['atribut'], old.read<int>('id')],
          );
        } else {
          await db.customStatement(
            'INSERT INTO pekerjaan_ppat_atributs(uuid,pekerjaan_ppat_id,proses_pekerjaan_ppat_id,atribut,status,is_sync_dirty) VALUES(?,?,?,?,1,0)',
            [attr['uuid'], parentId, processId, attr['atribut']],
          );
        }
      }
    }
  }
}
