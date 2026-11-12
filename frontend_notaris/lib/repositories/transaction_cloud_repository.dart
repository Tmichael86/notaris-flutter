import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import 'transaction_cloud_references.dart';
import 'transaction_handover_repository.dart';

class TransactionPullBatch {
  const TransactionPullBatch(this.cursor, this.count, this.hasMore);
  final int cursor, count;
  final bool hasMore;
}

/// Explicit domain-checked transaction adapter. Never registered with SyncCoordinator.
class TransactionCloudRepository {
  TransactionCloudRepository(
    this.db,
    this.dio, {
    required this.scope,
    required this.petugasScope,
    required this.masterScope,
    this.domain = 'notaris',
    this.otherMasterScope,
  });
  final AppDatabase db;
  final Dio dio;
  final String scope, petugasScope, masterScope;
  final String domain;
  final String? otherMasterScope;
  String _masterScopeFor(String value) =>
      value == domain ? masterScope : (otherMasterScope ?? masterScope);
  String _domainOf(Map value) => (value['domain'] ?? 'notaris') as String;
  Future<void> _bind() async {
    if (!{'notaris', 'ppat'}.contains(domain)) {
      throw StateError('Invalid transaction domain');
    }
    if (scope.isEmpty) throw StateError('Transaction cloud scope required');
    final feeds = await db
        .customSelect('SELECT scope FROM transaction_cloud_feed')
        .get();
    if (feeds.any((f) => f.read<String>('scope') != scope)) {
      throw StateError('Transaction scope mismatch');
    }
    await db.customStatement(
      'INSERT OR IGNORE INTO transaction_cloud_feed(scope,cursor) VALUES(?,0)',
      [scope],
    );
  }

  Future<Map<String, dynamic>> _snapshot(int id, String mutation) async {
    final header = await (db.select(
      db.transaksis,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingle();
    await _guardLocalCompletion(header);
    await _guardLocalHandover(id);
    await _guardLocalPayments(id);
    await _guardProcessAudit(id);
    final refs = await TransactionCloudReferences(
      db,
      petugasScope: petugasScope,
      masterScope: masterScope,
    ).prepare(id);
    if (refs['domain'] != domain) {
      throw StateError('Transaction push domain mismatch');
    }
    final details =
        await (db.select(db.transaksiDetails)
              ..where(
                (t) =>
                    t.transaksiId.equals(id) &
                    t.deletedAt.isNull() &
                    t.status.equals(1),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.uuid)]))
            .get();
    final payments =
        await (db.select(db.transaksiRiwayatPembayarans)
              ..where(
                (t) =>
                    t.transaksiId.equals(id) &
                    t.deletedAt.isNull() &
                    t.status.equals(1),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.uuid)]))
            .get();
    final jobs = <Map<String, dynamic>>[];
    for (final d in details) {
      final ref = (refs['jobs'] as List)
          .cast<Map<String, dynamic>>()
          .singleWhere((r) => r['detail_uuid'] == d.uuid);
      final processes =
          await (db.select(db.transaksiProses)
                ..where(
                  (t) =>
                      t.transaksiDetailUuid.equals(d.uuid) &
                      t.deletedAt.isNull(),
                )
                ..orderBy([(t) => OrderingTerm.asc(t.uuid)]))
              .get();
      jobs.add({
        'uuid': d.uuid,
        'job_uuid': ref['job_uuid'],
        'price_uuid': ref['price_uuid'],
        'category_uuid': ref['category_uuid'],
        'name': d.namaPekerjaanSnapshot,
        'category': d.kategoriSnapshot ?? '',
        'estimate': d.estimasiWaktuSnapshot ?? '',
        'service_cost': d.biayaLayanan,
        'other_cost': d.biayaLainnya,
        'total': d.totalSnapshot,
        'process_snapshot': d.prosesSnapshot == null
            ? null
            : jsonDecode(d.prosesSnapshot!),
        'processes': [
          for (final p in processes)
            {
              'uuid': p.uuid,
              'source_id': p.sourceProcessId,
              'name': p.namaProsesSnapshot,
              'status': p.statusProses,
              'legacy_status': p.legacyStatus,
              'legacy_data': p.legacyData,
              'note': p.catatan,
            },
        ],
      });
    }
    return {
      'domain': domain,
      'mutation_id': mutation,
      'uuid': header.uuid,
      'expected_revision': 0,
      'pemohon_uuid': refs['pemohon_uuid'],
      'petugas_uuid': refs['petugas_uuid'],
      'header': {
        'date': header.tanggalTransaksi!.toUtc().toIso8601String(),
        'due': header.tanggalJatuhTempo?.toUtc().toIso8601String(),
        'status': header.statusTransaksi,
        'total': header.total,
        'discount': header.diskon,
        'initial_payment': header.pembayaranSekarang,
        'method': header.metodePembayaran,
        'materai': header.jumlahMaterai,
        'note': header.catatan,
      },
      'details': jobs,
      'payments': [
        for (final p in payments)
          {
            'uuid': p.uuid,
            'date': p.tanggalPembayaran.toUtc().toIso8601String(),
            'amount': p.nominal,
            'method': p.metodePembayaran,
            'description': p.keterangan,
            'order': p.urutanPembayaran,
          },
      ],
    };
  }

  /// Freeze the existing CREATE journal without contacting the server.
  Future<String> stageCreate(int id) => db.transaction(() async {
    await _bind();
    final h = await (db.select(
      db.transaksis,
    )..where((t) => t.id.equals(id))).getSingle();
    if (h.jenisTransaksi != domain) {
      throw StateError('Transaction domain mismatch');
    }
    await _guardLocalHandover(id);
    await _guardLocalCompletion(h);
    await _guardLocalPayments(id);
    final identity = await db
        .customSelect(
          'SELECT local_uuid FROM transaction_cloud_identity WHERE local_uuid=?',
          variables: [Variable(h.uuid)],
        )
        .get();
    if (identity.isNotEmpty) {
      throw StateError('Transaction CREATE already acknowledged');
    }
    final pending = await db
        .customSelect(
          'SELECT payload FROM transaction_cloud_pending WHERE local_uuid=?',
          variables: [Variable(h.uuid)],
        )
        .getSingleOrNull();
    if (pending != null) return pending.read<String>('payload');
    final snapshot = await _snapshot(id, const Uuid().v4());
    final body = jsonEncode(snapshot);
    await db.customStatement(
      "INSERT INTO transaction_cloud_pending(local_uuid,mutation_id,payload,state) VALUES(?,?,?,'pending')",
      [h.uuid, snapshot['mutation_id'], body],
    );
    return body;
  });

  Future<String> currentCreatePayload(int id, String mutationId) async =>
      jsonEncode(await _snapshot(id, mutationId));

  Future<Map<String, dynamic>> pushCreate(int id) async {
    final payload = await stageCreate(id);
    final response = await dio.post<Map<String, dynamic>>(
      '/transaksi-$domain/sync/create',
      data: jsonDecode(payload),
    );
    final ack = Map<String, dynamic>.from(
      response.data!['acknowledgement'] as Map,
    );
    final sent = jsonDecode(payload) as Map<String, dynamic>;
    if (ack['uuid'] != sent['uuid'] ||
        ack['mutation_id'] != sent['mutation_id'] ||
        ack['revision'] != 1 ||
        !RegExp(domain == 'ppat' ? r'^200\d{10}$' : r'^100\d{10}$')
            .hasMatch(ack['final_number'] as String)) {
      throw StateError('Invalid transaction acknowledgement');
    }
    await db.transaction(() async {
      final already = await db
          .customSelect(
            'SELECT scope,final_number FROM transaction_cloud_identity WHERE local_uuid=?',
            variables: [Variable(sent['uuid'] as String)],
          )
          .getSingleOrNull();
      if (already != null) {
        if (already.read<String>('scope') != scope ||
            already.read<String>('final_number') != ack['final_number']) {
          throw StateError('Concurrent acknowledgement mismatch');
        }
        return;
      }
      var unchanged = false;
      try {
        unchanged =
            jsonEncode(await _snapshot(id, sent['mutation_id'] as String)) ==
            payload;
      } on StateError {
        unchanged = false;
      }
      final aggregate = {...sent, 'final_number': ack['final_number']};
      await db.customStatement(
        'INSERT INTO transaction_cloud_identity(local_uuid,cloud_uuid,scope,revision,final_number,snapshot) VALUES(?,?,?,1,?,?)',
        [
          sent['uuid'],
          sent['uuid'],
          scope,
          ack['final_number'],
          jsonEncode(aggregate),
        ],
      );
      await db.customStatement(
        'UPDATE transaksis SET no_akta=?,is_sync_dirty=? WHERE id=?',
        [ack['final_number'], unchanged ? 0 : 1, id],
      );
      if (unchanged) {
        await _cleanChildren(id);
      }
      await db.customStatement(
        "UPDATE transaction_cloud_pending SET state='acked' WHERE local_uuid=? AND payload=?",
        [sent['uuid'], payload],
      );
    });
    return ack;
  }

  Future<void> _cleanChildren(int id) async {
    for (final table in [
      'transaksi_details',
      'transaksi_proses',
      'transaksi_riwayat_pembayaran',
    ]) {
      await db.customStatement(
        'UPDATE $table SET is_sync_dirty=0 WHERE transaksi_id=? AND deleted_at IS NULL${table == 'transaksi_proses' ? '' : ' AND status=1'}',
        [id],
      );
    }
  }

  Future<Map<String, dynamic>> pushUpdate(int id) =>
      _pushMutation(id, 'update');
  Future<Map<String, dynamic>> pushDelete(int id) =>
      _pushMutation(id, 'delete');
  Future<List<Map<String, dynamic>>> _payments(int id) async {
    final rows =
        await (db.select(db.transaksiRiwayatPembayarans)
              ..where(
                (t) =>
                    t.transaksiId.equals(id) &
                    t.deletedAt.isNull() &
                    t.status.equals(1),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.uuid)]))
            .get();
    return [
      for (final p in rows)
        {
          'uuid': p.uuid,
          'date': p.tanggalPembayaran.toUtc().toIso8601String(),
          'amount': p.nominal,
          'method': p.metodePembayaran,
          'description': p.keterangan,
          'order': p.urutanPembayaran,
        },
    ];
  }

  static Future<String?> localCompletionBlockReason(
    AppDatabase db,
    Transaksi row,
  ) async {
    if (row.jenisTransaksi == 'notaris' &&
        (row.judulAkta != null ||
            row.nomorAkta != null ||
            row.tanggalAkta != null)) {
      return 'Data akta Notaris belum didukung oleh sinkronisasi Transaksi.';
    }
    if (row.jenisTransaksi != 'ppat') return null;
    final completion =
        await (db.select(db.transaksiDetails)
              ..where(
                (detail) =>
                    detail.transaksiId.equals(row.id) &
                    (detail.statusPekerjaanPpat.isNotNull() |
                        detail.judulAktaPpat.isNotNull() |
                        detail.nomorAktaPpat.isNotNull() |
                        detail.tanggalAktaPpat.isNotNull()),
              )
              ..limit(1))
            .getSingleOrNull();
    return completion == null
        ? null
        : 'Status pekerjaan dan data akta PPAT belum didukung oleh sinkronisasi Transaksi.';
  }

  Future<void> _guardLocalCompletion(Transaksi row) async {
    if (await localCompletionBlockReason(db, row) case final reason?) {
      throw StateError(reason);
    }
  }

  Future<void> _guardLocalHandover(int id) async {
    if (await TransactionHandoverRepository.cloudBlockReason(db, id)
        case final reason?) {
      throw StateError(reason);
    }
  }

  static Future<String?> localPaymentBlockReason(AppDatabase db, int id) async {
    final localAudit = await db
        .customSelect(
          '''SELECT 1 FROM transaksi_riwayat_pembayaran p
             WHERE p.transaksi_id=? AND (
               p.status <> 1 OR p.deleted_at IS NOT NULL OR EXISTS (
                 SELECT 1 FROM transaksi_pembayaran_audit a WHERE a.payment_uuid=p.uuid
               )
             ) LIMIT 1''',
          variables: [Variable(id)],
        )
        .getSingleOrNull();
    return localAudit == null
        ? null
        : 'Cicilan, koreksi, dan pembatalan lokal memerlukan kontrak pembayaran cloud.';
  }

  Future<void> _guardLocalPayments(int id) async {
    if (await localPaymentBlockReason(db, id) case final reason?) {
      throw StateError(reason);
    }
  }

  Future<void> _guardProcessAudit(int id) async {
    final audit = await db
        .customSelect(
          'SELECT p.id FROM transaksi_proses p WHERE p.transaksi_id=? AND (p.submitted_by_user_id IS NOT NULL OR p.validated_by_user_id IS NOT NULL OR p.submitted_at IS NOT NULL OR p.validated_at IS NOT NULL OR EXISTS(SELECT 1 FROM transaksi_proses_riwayat h WHERE h.transaksi_proses_id=p.id))',
          variables: [Variable(id)],
        )
        .get();
    if (audit.isNotEmpty) {
      throw StateError(
        'Process transition audit requires verified cloud actor provenance',
      );
    }
  }

  Future<Map<String, dynamic>> _pushMutation(int id, String operation) async {
    final payload = await db.transaction(() async {
      await _bind();
      final h = await (db.select(
        db.transaksis,
      )..where((t) => t.id.equals(id))).getSingle();
      if (h.jenisTransaksi != domain) {
        throw StateError('Transaction domain mismatch');
      }
      await _guardLocalCompletion(h);
      await _guardLocalHandover(id);
      await _guardLocalPayments(id);
      final identity = await db
          .customSelect(
            'SELECT * FROM transaction_cloud_identity WHERE local_uuid=?',
            variables: [Variable(h.uuid)],
          )
          .getSingle();
      if (identity.read<String>('scope') != scope) {
        throw StateError('Transaction identity scope mismatch');
      }
      final pending = await db
          .customSelect(
            "SELECT payload,operation FROM transaction_cloud_pending WHERE local_uuid=? AND state='pending'",
            variables: [Variable(h.uuid)],
          )
          .getSingleOrNull();
      if (pending != null) {
        if (pending.read<String>('operation') != operation) {
          throw StateError('Unresolved mutation must not be replaced');
        }
        return pending.read<String>('payload');
      }
      final accepted =
          jsonDecode(identity.read<String>('snapshot')) as Map<String, dynamic>;
      if (accepted['deleted_at'] != null) {
        throw StateError('Transaction already deleted in cloud');
      }
      if (!_same(await _payments(id), accepted['payments'])) {
        throw StateError(
          'Committed payments need an explicit payment contract',
        );
      }
      final Map<String, dynamic> request;
      if (operation == 'delete') {
        await _guardProcessAudit(id);
        if (h.deletedAt == null) {
          throw StateError('Local soft deletion required before cloud delete');
        }
        request = {
          'domain': domain,
          'mutation_id': const Uuid().v4(),
          'uuid': h.uuid,
          'expected_revision': identity.read<int>('revision'),
        };
      } else {
        request = await _snapshot(id, const Uuid().v4());
        request['expected_revision'] = identity.read<int>('revision');
      }
      final body = jsonEncode(request);
      await db.customStatement(
        "INSERT INTO transaction_cloud_pending(local_uuid,mutation_id,payload,state,operation) VALUES(?,?,?,'pending',?) ON CONFLICT(local_uuid) DO UPDATE SET mutation_id=excluded.mutation_id,payload=excluded.payload,state='pending',operation=excluded.operation WHERE transaction_cloud_pending.state='acked'",
        [h.uuid, request['mutation_id'], body, operation],
      );
      return body;
    });
    final sent = jsonDecode(payload) as Map<String, dynamic>;
    // 409 leaves the immutable request and all dirty state intact.
    final response = await dio.post<Map<String, dynamic>>(
      '/transaksi-$domain/sync/$operation',
      data: sent,
    );
    final ack = Map<String, dynamic>.from(
      response.data!['acknowledgement'] as Map,
    );
    if (ack['uuid'] != sent['uuid'] ||
        ack['mutation_id'] != sent['mutation_id'] ||
        ack['revision'] != (sent['expected_revision'] as int) + 1) {
      throw StateError('Invalid transaction acknowledgement');
    }
    await db.transaction(() async {
      final identity = await db
          .customSelect(
            'SELECT * FROM transaction_cloud_identity WHERE local_uuid=?',
            variables: [Variable(sent['uuid'] as String)],
          )
          .getSingle();
      if (identity.read<String>('scope') != scope ||
          identity.read<String>('final_number') != ack['final_number']) {
        throw StateError('Immutable transaction identity mismatch');
      }
      if (identity.read<int>('revision') == ack['revision']) return;
      if (identity.read<int>('revision') != sent['expected_revision']) {
        throw StateError('Concurrent acknowledgement revision mismatch');
      }
      final prior =
          jsonDecode(identity.read<String>('snapshot')) as Map<String, dynamic>;
      Map<String, dynamic> aggregate;
      var unchanged = false;
      if (operation == 'delete') {
        if (ack['deleted_at'] == null) {
          throw StateError('Missing tombstone receipt');
        }
        aggregate = {...prior, ...sent, 'deleted_at': ack['deleted_at']};
        final h = await (db.select(
          db.transaksis,
        )..where((t) => t.id.equals(id))).getSingle();
        unchanged =
            h.deletedAt != null &&
            _same(await _payments(id), prior['payments']);
      } else {
        aggregate = {...sent, 'final_number': ack['final_number']};
        try {
          final current = await _snapshot(id, sent['mutation_id'] as String);
          current['expected_revision'] = sent['expected_revision'];
          unchanged = _same(current, sent);
        } on StateError {
          unchanged = false;
        }
      }
      await db.customStatement(
        'UPDATE transaction_cloud_identity SET revision=?,snapshot=? WHERE local_uuid=?',
        [ack['revision'], jsonEncode(aggregate), sent['uuid']],
      );
      await db.customStatement(
        'UPDATE transaksis SET no_akta=?,is_sync_dirty=? WHERE id=?',
        [ack['final_number'], unchanged ? 0 : 1, id],
      );
      if (unchanged && operation == 'update') await _cleanChildren(id);
      await db.customStatement(
        "UPDATE transaction_cloud_pending SET state='acked' WHERE local_uuid=? AND payload=?",
        [sent['uuid'], payload],
      );
    });
    return ack;
  }

  Future<int> pullPage({int limit = 100}) async {
    return (await pullBatch(limit: limit)).cursor;
  }

  /// A selective caller must stop before applying an unselected domain. The
  /// shared feed cannot be filtered or its cursor advanced past skipped events.
  Future<TransactionPullBatch> pullBatch({
    int limit = 100,
    Set<String>? allowedDomains,
    bool confirmAcknowledgements = false,
  }) async {
    await db.transaction(_bind);
    final before =
        (await db
                .customSelect(
                  'SELECT cursor FROM transaction_cloud_feed WHERE scope=?',
                  variables: [Variable(scope)],
                )
                .getSingle())
            .read<int>('cursor');
    final response = await dio.get<Map<String, dynamic>>(
      '/transaksi-$domain/sync/pull',
      queryParameters: {'cursor': before, 'limit': limit},
    );
    final page = response.data!;
    if (page['has_more'] is! bool ||
        (allowedDomains != null &&
            (page['changes'] as List).any(
              (event) => !allowedDomains.contains(
                (event['aggregate'] as Map)['domain'],
              ),
            ))) {
      throw StateError('Unselected transaction domain or invalid page');
    }
    return db.transaction(() async {
      final current =
          (await db
                  .customSelect(
                    'SELECT cursor FROM transaction_cloud_feed WHERE scope=?',
                    variables: [Variable(scope)],
                  )
                  .getSingle())
              .read<int>('cursor');
      if (current != before) throw StateError('Concurrent transaction pull');
      var next = before;
      for (final raw in page['changes'] as List) {
        final event = Map<String, dynamic>.from(raw as Map);
        if (event['sequence'] != next + 1 ||
            event['revision'] is! int ||
            !{'create', 'update', 'delete'}.contains(event['operation'])) {
          throw StateError('Transaction publication gap');
        }
        if (allowedDomains != null) _validatePublished(event);
        await _apply(
          Map<String, dynamic>.from(event['aggregate'] as Map),
          event['revision'] as int,
          event['operation'] as String,
        );
        if (confirmAcknowledgements) {
          // Retire only an ACKED request whose exact immutable mutation is now
          // observed in publication. Pending/409/timeout requests never qualify.
          // This proof and the cursor commit share the same SQLite transaction.
          final aggregate = event['aggregate'] as Map;
          await db.customStatement(
            "DELETE FROM transaction_cloud_pending WHERE state='acked' AND local_uuid=? AND json_extract(payload,'\$.mutation_id')=? AND json_extract(payload,'\$.expected_revision')=?",
            [
              aggregate['uuid'],
              aggregate['mutation_id'],
              (event['revision'] as int) - 1,
            ],
          );
        }
        next++;
      }
      if (page['next_cursor'] != next) {
        throw StateError('Transaction cursor mismatch');
      }
      await db.customStatement(
        'UPDATE transaction_cloud_feed SET cursor=? WHERE scope=?',
        [next, scope],
      );
      return TransactionPullBatch(
        next,
        (page['changes'] as List).length,
        page['has_more'] as bool,
      );
    });
  }

  /// Validate wire identities even on replay, before a page can commit. Domain
  /// tables may share a master UUID; transaction UUIDs are deployment-global.
  void _validatePublished(Map<String, dynamic> event) {
    final a = event['aggregate'] as Map;
    final uuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    void identity(dynamic value) {
      if (value is! String || !uuid.hasMatch(value)) {
        throw StateError('Invalid published UUID');
      }
    }

    for (final key in ['uuid', 'mutation_id', 'pemohon_uuid', 'petugas_uuid']) {
      identity(a[key]);
    }
    final revision = event['revision'] as int;
    if (revision < 1 ||
        a['expected_revision'] != revision - 1 ||
        (event['operation'] == 'create' && revision != 1) ||
        (event['operation'] != 'create' && revision < 2) ||
        ((event['operation'] == 'delete') != (a['deleted_at'] != null)) ||
        !RegExp(a['domain'] == 'ppat' ? r'^200\d{10}$' : r'^100\d{10}$')
            .hasMatch(a['final_number'] as String)) {
      throw StateError('Invalid published revision/number/tombstone');
    }
    final details = <String>{}, processes = <String>{}, payments = <String>{};
    if ((a['details'] as List).isEmpty) {
      throw StateError('Missing published detail');
    }
    for (final d in a['details'] as List) {
      for (final key in ['uuid', 'job_uuid', 'price_uuid', 'category_uuid']) {
        identity(d[key]);
      }
      if (!details.add(d['uuid'] as String)) {
        throw StateError('Duplicate detail UUID');
      }
      for (final process in d['processes'] as List) {
        identity(process['uuid']);
        if (!processes.add(process['uuid'] as String)) {
          throw StateError('Duplicate process UUID');
        }
      }
    }
    for (final payment in a['payments'] as List) {
      identity(payment['uuid']);
      if (!payments.add(payment['uuid'] as String)) {
        throw StateError('Duplicate payment UUID');
      }
    }
  }

  int _date(dynamic value) =>
      DateTime.parse(value as String).millisecondsSinceEpoch ~/ 1000;
  Future<void> _apply(
    Map<String, dynamic> aggregate,
    int revision,
    String operation,
  ) async {
    final eventDomain = _domainOf(aggregate);
    if (!{'notaris', 'ppat'}.contains(eventDomain)) {
      throw StateError('Invalid published domain');
    }
    final uuid = aggregate['uuid'] as String;
    final identity = await db
        .customSelect(
          'SELECT scope,snapshot,revision,final_number FROM transaction_cloud_identity WHERE cloud_uuid=?',
          variables: [Variable(uuid)],
        )
        .getSingleOrNull();
    if (identity != null) {
      if (_domainOf(jsonDecode(identity.read<String>('snapshot')) as Map) !=
              eventDomain ||
          identity.read<String>('scope') != scope ||
          identity.read<String>('final_number') != aggregate['final_number']) {
        throw StateError('Transaction replay disagrees');
      }
      final prior = identity.read<int>('revision');
      if (revision <= prior) {
        if (revision == prior &&
            !_same(jsonDecode(identity.read<String>('snapshot')), aggregate)) {
          throw StateError('Transaction replay disagrees');
        }
        return;
      }
      if (revision != prior + 1 || operation == 'create') {
        throw StateError('Transaction revision gap');
      }
    } else if (revision != 1 || operation != 'create') {
      throw StateError('Transaction CREATE baseline missing');
    }
    final existing = await (db.select(
      db.transaksis,
    )..where((t) => t.uuid.equals(uuid))).get();
    if (existing.any((row) => row.jenisTransaksi != eventDomain) ||
        existing.length > 1 ||
        (identity == null && existing.isNotEmpty) ||
        (identity != null && existing.length != 1)) {
      throw StateError(
        'Existing local transaction requires explicit reconciliation',
      );
    }
    final updating = identity != null;
    if (updating) {
      await _guardLocalCompletion(existing.single);
      final id = existing.single.id;
      await _guardLocalHandover(id);
      await _guardLocalPayments(id);
      final pending = await db
          .customSelect(
            "SELECT local_uuid FROM transaction_cloud_pending WHERE local_uuid=? AND state='pending'",
            variables: [Variable(uuid)],
          )
          .get();
      if (existing.single.isSyncDirty ||
          existing.single.deletedAt != null ||
          pending.isNotEmpty) {
        throw StateError('Dirty transaction protected');
      }
      for (final table in [
        'transaksi_details',
        'transaksi_proses',
        'transaksi_riwayat_pembayaran',
      ]) {
        final dirty = await db
            .customSelect(
              'SELECT id FROM $table WHERE transaksi_id=? AND is_sync_dirty=1',
              variables: [Variable(id)],
            )
            .get();
        if (dirty.isNotEmpty) {
          throw StateError('Dirty transaction child protected');
        }
      }
      await _guardProcessAudit(id);
      if (!_same(await _payments(id), aggregate['payments'])) {
        throw StateError('Committed payment history mismatch');
      }
      if (operation == 'delete') {
        final prior = jsonDecode(identity.read<String>('snapshot')) as Map;
        for (final key in [
          'pemohon_uuid',
          'petugas_uuid',
          'header',
          'details',
        ]) {
          if (!_same(prior[key], aggregate[key])) {
            throw StateError('Tombstone historical snapshot mismatch');
          }
        }
        final deleted = aggregate['deleted_at'];
        if (deleted == null) throw StateError('Tombstone missing');
        await db.customStatement(
          "UPDATE transaksis SET deleted_at=?,status_transaksi='Dihapus',is_sync_dirty=0 WHERE id=?",
          [_date(deleted), id],
        );
        await db.customStatement(
          'UPDATE transaksi_details SET deleted_at=COALESCE(deleted_at,?),status=0,is_sync_dirty=0 WHERE transaksi_id=?',
          [_date(deleted), id],
        );
        await db.customStatement(
          'UPDATE transaksi_proses SET deleted_at=COALESCE(deleted_at,?),is_sync_dirty=0 WHERE transaksi_id=?',
          [_date(deleted), id],
        );
        await db.customStatement(
          'UPDATE transaction_cloud_identity SET revision=?,snapshot=? WHERE local_uuid=?',
          [revision, jsonEncode(aggregate), uuid],
        );
        return;
      }
      if (aggregate['deleted_at'] != null) {
        throw StateError('Unexpected tombstone');
      }
    }
    final applicants =
        await (db.select(db.pemohons)..where(
              (t) =>
                  t.uuid.equals(aggregate['pemohon_uuid'] as String) &
                  t.status.equals(1) &
                  t.deletedAt.isNull() &
                  t.lastSyncedAt.isNotNull() &
                  t.isSyncDirty.equals(false),
            ))
            .get();
    final officer = await db
        .customSelect(
          "SELECT p.id,p.uuid FROM petugas p JOIN petugas_identity_map m ON m.local_uuid=p.uuid JOIN petugas_sync_journal j ON j.local_uuid=p.uuid JOIN petugas_sync_feed f ON f.id=1 WHERE m.cloud_uuid=? AND m.state IN ('verified','server_only') AND m.server_id>0 AND NULLIF(trim(m.evidence),'') IS NOT NULL AND p.status=1 AND p.deleted_at IS NULL AND p.is_sync_dirty=0 AND j.pending IS NULL AND j.row_version>0 AND f.scope=? AND f.blocked IS NULL",
          variables: [
            Variable(aggregate['petugas_uuid'] as String),
            Variable(petugasScope),
          ],
        )
        .get();
    if (applicants.length != 1 || officer.length != 1) {
      throw StateError('Transaction pull dependencies unresolved');
    }
    final h = Map<String, dynamic>.from(aggregate['header'] as Map);
    if (!updating) {
      await db.customStatement(
        'INSERT INTO transaksis(uuid,no_akta,total,pemohon_id,pemohon_uuid,petugas_id,petugas_uuid,jenis_transaksi,status_transaksi,tanggal_transaksi,tanggal_jatuh_tempo,diskon,pembayaran_sekarang,metode_pembayaran,jumlah_materai,catatan,is_sync_dirty) VALUES(?,?,?,?,?,?,?,\'$eventDomain\',?,?,?,?,?,?,?,?,0)',
        [
          uuid,
          aggregate['final_number'],
          h['total'],
          applicants.single.id,
          applicants.single.uuid,
          officer.single.read<int>('id'),
          officer.single.read<String>('uuid'),
          h['status'],
          _date(h['date']),
          h['due'] == null ? null : _date(h['due']),
          h['discount'],
          h['initial_payment'],
          h['method'],
          h['materai'],
          h['note'],
        ],
      );
    }
    final id = (await (db.select(
      db.transaksis,
    )..where((t) => t.uuid.equals(uuid))).getSingle()).id;
    if (updating) {
      await db.customStatement(
        'UPDATE transaksis SET total=?,pemohon_id=?,pemohon_uuid=?,petugas_id=?,petugas_uuid=?,status_transaksi=?,tanggal_transaksi=?,tanggal_jatuh_tempo=?,diskon=?,pembayaran_sekarang=?,metode_pembayaran=?,jumlah_materai=?,catatan=?,is_sync_dirty=0 WHERE id=?',
        [
          h['total'],
          applicants.single.id,
          applicants.single.uuid,
          officer.single.read<int>('id'),
          officer.single.read<String>('uuid'),
          h['status'],
          _date(h['date']),
          h['due'] == null ? null : _date(h['due']),
          h['discount'],
          h['initial_payment'],
          h['method'],
          h['materai'],
          h['note'],
          id,
        ],
      );
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await db.customStatement(
        'UPDATE transaksi_details SET status=0,deleted_at=? WHERE transaksi_id=? AND deleted_at IS NULL',
        [now, id],
      );
      await db.customStatement(
        'UPDATE transaksi_proses SET deleted_at=? WHERE transaksi_id=? AND deleted_at IS NULL',
        [now, id],
      );
    }
    for (final raw in aggregate['details'] as List) {
      final d = Map<String, dynamic>.from(raw as Map);
      final owned = await db
          .customSelect(
            'SELECT transaksi_id FROM transaksi_details WHERE uuid=?',
            variables: [Variable(d['uuid'] as String)],
          )
          .getSingleOrNull();
      if (owned != null && owned.read<int>('transaksi_id') != id) {
        throw StateError('Detail UUID belongs to another transaction');
      }
      // A clean tombstone with a scoped, advanced Master feed and no local
      // mutation journal is the state produced by Master pull. Push ACKs keep
      // their journal, so a locally deleted or ACK-only Master is insufficient.
      // Keep the retained price/category UUID link; the Transaction event owns
      // its historical values. This lookup never changes the Master.
      final jobs = await db
          .customSelect(
            '''SELECT p.id FROM pekerjaan_$eventDomain p
            JOIN pekerjaan_${eventDomain}_sync_identity i ON i.local_uuid=p.uuid
            JOIN pekerjaan_${eventDomain}_harga h ON h.pekerjaan_${eventDomain}_id=p.id
            JOIN pekerjaan_kategori c ON c.id=h.kategori_pekerjaan_id
            WHERE i.cloud_uuid=? AND i.scope=? AND i.revision>0 AND p.is_sync_dirty=0
              AND h.uuid=? AND h.status=1 AND h.deleted_at IS NULL AND h.is_sync_dirty=0
              AND c.uuid=? AND c.status=1 AND c.deleted_at IS NULL AND c.is_sync_dirty=0
              AND NOT EXISTS(SELECT 1 FROM pekerjaan_${eventDomain}_sync_pending m
                WHERE m.local_uuid=p.uuid AND m.state='pending')
              AND ((p.status=1 AND p.deleted_at IS NULL)
                OR (p.status=0 AND p.deleted_at IS NOT NULL AND i.revision>1 AND i.local_uuid=i.cloud_uuid
                  AND EXISTS(SELECT 1 FROM pekerjaan_${eventDomain}_sync_feed f WHERE f.scope=i.scope AND f.cursor>=i.revision)
                  AND NOT EXISTS(SELECT 1 FROM pekerjaan_${eventDomain}_sync_pending m WHERE m.local_uuid=p.uuid)))''',
            variables: [
              Variable(d['job_uuid'] as String),
              Variable(_masterScopeFor(eventDomain)),
              Variable(d['price_uuid'] as String),
              Variable(d['category_uuid'] as String),
            ],
          )
          .get();
      if (jobs.length != 1) {
        throw StateError('Transaction job reference unresolved');
      }
      await db.customStatement(
        "INSERT INTO transaksi_details(uuid,transaksi_id,jenis_pekerjaan,pekerjaan_${eventDomain}_id,nama_pekerjaan_snapshot,kategori_snapshot,estimasi_waktu_snapshot,proses_snapshot,biaya_layanan,biaya_lainnya,total_snapshot,harga_uuid,kategori_uuid,is_sync_dirty) VALUES(?,?,'$eventDomain',?,?,?,?,?,?,?,?,?,?,0) ON CONFLICT(uuid) DO UPDATE SET pekerjaan_${eventDomain}_id=excluded.pekerjaan_${eventDomain}_id,nama_pekerjaan_snapshot=excluded.nama_pekerjaan_snapshot,kategori_snapshot=excluded.kategori_snapshot,estimasi_waktu_snapshot=excluded.estimasi_waktu_snapshot,proses_snapshot=excluded.proses_snapshot,biaya_layanan=excluded.biaya_layanan,biaya_lainnya=excluded.biaya_lainnya,total_snapshot=excluded.total_snapshot,harga_uuid=excluded.harga_uuid,kategori_uuid=excluded.kategori_uuid,status=1,deleted_at=NULL,is_sync_dirty=0",
        [
          d['uuid'],
          id,
          jobs.single.read<int>('id'),
          d['name'],
          d['category'],
          d['estimate'],
          d['process_snapshot'] == null
              ? null
              : jsonEncode(d['process_snapshot']),
          d['service_cost'],
          d['other_cost'],
          d['total'],
          d['price_uuid'],
          d['category_uuid'],
        ],
      );
      for (final rawProcess in d['processes'] as List) {
        final p = rawProcess as Map;
        final owned = await db
            .customSelect(
              'SELECT transaksi_detail_uuid FROM transaksi_proses WHERE uuid=?',
              variables: [Variable(p['uuid'] as String)],
            )
            .getSingleOrNull();
        if (owned != null &&
            owned.read<String>('transaksi_detail_uuid') != d['uuid']) {
          throw StateError('Process UUID belongs to another detail');
        }
        await db.customStatement(
          'INSERT INTO transaksi_proses(uuid,transaksi_id,transaksi_detail_uuid,source_process_id,nama_proses_snapshot,status_proses,legacy_status,legacy_data,catatan,is_sync_dirty) VALUES(?,?,?,?,?,?,?,?,?,0) ON CONFLICT(uuid) DO UPDATE SET source_process_id=excluded.source_process_id,nama_proses_snapshot=excluded.nama_proses_snapshot,status_proses=excluded.status_proses,legacy_status=excluded.legacy_status,legacy_data=excluded.legacy_data,catatan=excluded.catatan,deleted_at=NULL,is_sync_dirty=0',
          [
            p['uuid'],
            id,
            d['uuid'],
            p['source_id'],
            p['name'],
            p['status'],
            p['legacy_status'],
            p['legacy_data'],
            p['note'],
          ],
        );
      }
    }
    for (final raw in updating ? const [] : aggregate['payments'] as List) {
      final p = raw as Map;
      await db.customStatement(
        'INSERT INTO transaksi_riwayat_pembayaran(uuid,transaksi_id,tanggal_pembayaran,nominal,metode_pembayaran,keterangan,urutan_pembayaran,is_sync_dirty) VALUES(?,?,?,?,?,?,?,0)',
        [
          p['uuid'],
          id,
          _date(p['date']),
          p['amount'],
          p['method'],
          p['description'],
          p['order'],
        ],
      );
    }
    await db.customStatement(
      'INSERT INTO transaction_cloud_identity(local_uuid,cloud_uuid,scope,revision,final_number,snapshot) VALUES(?,?,?,?,?,?) ON CONFLICT(local_uuid) DO UPDATE SET revision=excluded.revision,snapshot=excluded.snapshot',
      [
        uuid,
        uuid,
        scope,
        revision,
        aggregate['final_number'],
        jsonEncode(aggregate),
      ],
    );
  }

  bool _same(dynamic a, dynamic b) {
    if (a is Map && b is Map) {
      if (a.containsKey('expected_revision') && a.containsKey('header')) {
        a = {'domain': 'notaris', ...a};
      }
      if (b.containsKey('expected_revision') && b.containsKey('header')) {
        b = {'domain': 'notaris', ...b};
      }
      return a.length == b.length &&
          a.keys.every(
            (k) =>
                b.containsKey(k) &&
                ((k == 'date' || k == 'due') && a[k] is String && b[k] is String
                    ? DateTime.parse(a[k] as String)
                          .isAtSameMomentAs(DateTime.parse(b[k] as String))
                    : _same(a[k], b[k])),
          );
    }
    if (a is List && b is List) {
      return a.length == b.length &&
          List.generate(a.length, (i) => i).every((i) => _same(a[i], b[i]));
    }
    return a == b;
  }
}
