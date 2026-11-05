import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import 'transaction_cloud_references.dart';

/// Explicit CREATE-only adapter. Never registered with SyncCoordinator.
class TransactionCloudRepository {
  TransactionCloudRepository(
    this.db,
    this.dio, {
    required this.scope,
    required this.petugasScope,
    required this.masterScope,
  });
  final AppDatabase db;
  final Dio dio;
  final String scope, petugasScope, masterScope;
  Future<void> _bind() async {
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
    final refs = await TransactionCloudReferences(
      db,
      petugasScope: petugasScope,
      masterScope: masterScope,
    ).prepare(id);
    if (refs['domain'] != 'notaris') {
      throw StateError('Only Notaris CREATE supported');
    }
    final header = await (db.select(
      db.transaksis,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingle();
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
      for (final p in processes) {
        final audit = await (db.select(
          db.transaksiProsesRiwayat,
        )..where((t) => t.transaksiProsesId.equals(p.id))).get();
        if (audit.isNotEmpty ||
            p.submittedByUserId != null ||
            p.validatedByUserId != null ||
            p.submittedAt != null ||
            p.validatedAt != null) {
          throw StateError(
            'Process transition audit requires a cloud actor contract',
          );
        }
      }
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

  Future<Map<String, dynamic>> pushCreate(int id) async {
    final payload = await db.transaction(() async {
      await _bind();
      final h = await (db.select(
        db.transaksis,
      )..where((t) => t.id.equals(id))).getSingle();
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
    final response = await dio.post<Map<String, dynamic>>(
      '/transaksi-notaris/sync/create',
      data: jsonDecode(payload),
    );
    final ack = Map<String, dynamic>.from(
      response.data!['acknowledgement'] as Map,
    );
    final sent = jsonDecode(payload) as Map<String, dynamic>;
    if (ack['uuid'] != sent['uuid'] ||
        ack['mutation_id'] != sent['mutation_id'] ||
        ack['revision'] != 1 ||
        !RegExp(r'^100\d{10}$').hasMatch(ack['final_number'] as String)) {
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

  Future<int> pullPage({int limit = 100}) async {
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
      '/transaksi-notaris/sync/pull',
      queryParameters: {'cursor': before, 'limit': limit},
    );
    final page = response.data!;
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
            event['revision'] != 1 ||
            event['operation'] != 'create') {
          throw StateError('Transaction publication gap');
        }
        await _apply(Map<String, dynamic>.from(event['aggregate'] as Map));
        next++;
      }
      if (page['next_cursor'] != next) {
        throw StateError('Transaction cursor mismatch');
      }
      await db.customStatement(
        'UPDATE transaction_cloud_feed SET cursor=? WHERE scope=?',
        [next, scope],
      );
      return next;
    });
  }

  int _date(dynamic value) =>
      DateTime.parse(value as String).millisecondsSinceEpoch ~/ 1000;
  Future<void> _apply(Map<String, dynamic> aggregate) async {
    final uuid = aggregate['uuid'] as String;
    final identity = await db
        .customSelect(
          'SELECT scope,snapshot FROM transaction_cloud_identity WHERE cloud_uuid=?',
          variables: [Variable(uuid)],
        )
        .getSingleOrNull();
    if (identity != null) {
      if (identity.read<String>('scope') != scope ||
          !_same(jsonDecode(identity.read<String>('snapshot')), aggregate)) {
        throw StateError('Transaction replay disagrees');
      }
      return;
    }
    final existing = await (db.select(
      db.transaksis,
    )..where((t) => t.uuid.equals(uuid))).get();
    if (existing.isNotEmpty) {
      throw StateError(
        'Existing local transaction requires explicit reconciliation',
      );
    }
    final applicants =
        await (db.select(db.pemohons)..where(
              (t) =>
                  t.uuid.equals(aggregate['pemohon_uuid'] as String) &
                  t.status.equals(1) &
                  t.deletedAt.isNull() &
                  t.isSyncDirty.equals(false),
            ))
            .get();
    final officer = await db
        .customSelect(
          "SELECT p.id,p.uuid FROM petugas p JOIN petugas_identity_map m ON m.local_uuid=p.uuid JOIN petugas_sync_journal j ON j.local_uuid=p.uuid JOIN petugas_sync_feed f ON f.id=1 WHERE m.cloud_uuid=? AND m.state IN ('verified','server_only') AND p.status=1 AND p.deleted_at IS NULL AND p.is_sync_dirty=0 AND j.pending IS NULL AND j.row_version>0 AND f.scope=? AND f.blocked IS NULL",
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
    await db.customStatement(
      'INSERT INTO transaksis(uuid,no_akta,total,pemohon_id,pemohon_uuid,petugas_id,petugas_uuid,jenis_transaksi,status_transaksi,tanggal_transaksi,tanggal_jatuh_tempo,diskon,pembayaran_sekarang,metode_pembayaran,jumlah_materai,catatan,is_sync_dirty) VALUES(?,?,?,?,?,?,?,\'notaris\',?,?,?,?,?,?,?,?,0)',
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
    final id = (await (db.select(
      db.transaksis,
    )..where((t) => t.uuid.equals(uuid))).getSingle()).id;
    for (final raw in aggregate['details'] as List) {
      final d = Map<String, dynamic>.from(raw as Map);
      final jobs = await db
          .customSelect(
            "SELECT p.id FROM pekerjaan_notaris p JOIN pekerjaan_notaris_sync_identity i ON i.local_uuid=p.uuid JOIN pekerjaan_notaris_harga h ON h.pekerjaan_notaris_id=p.id JOIN pekerjaan_kategori c ON c.id=h.kategori_pekerjaan_id WHERE i.cloud_uuid=? AND i.scope=? AND i.revision>0 AND p.status=1 AND p.deleted_at IS NULL AND p.is_sync_dirty=0 AND h.uuid=? AND h.status=1 AND h.deleted_at IS NULL AND h.is_sync_dirty=0 AND c.uuid=? AND c.status=1 AND c.deleted_at IS NULL AND c.is_sync_dirty=0 AND NOT EXISTS(SELECT 1 FROM pekerjaan_notaris_sync_pending m WHERE m.local_uuid=p.uuid AND m.state='pending')",
            variables: [
              Variable(d['job_uuid'] as String),
              Variable(masterScope),
              Variable(d['price_uuid'] as String),
              Variable(d['category_uuid'] as String),
            ],
          )
          .get();
      if (jobs.length != 1) {
        throw StateError('Transaction job reference unresolved');
      }
      await db.customStatement(
        "INSERT INTO transaksi_details(uuid,transaksi_id,jenis_pekerjaan,pekerjaan_notaris_id,nama_pekerjaan_snapshot,kategori_snapshot,estimasi_waktu_snapshot,proses_snapshot,biaya_layanan,biaya_lainnya,total_snapshot,harga_uuid,kategori_uuid,is_sync_dirty) VALUES(?,?,'notaris',?,?,?,?,?,?,?,?,?,?,0)",
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
        await db.customStatement(
          'INSERT INTO transaksi_proses(uuid,transaksi_id,transaksi_detail_uuid,source_process_id,nama_proses_snapshot,status_proses,legacy_status,legacy_data,catatan,is_sync_dirty) VALUES(?,?,?,?,?,?,?,?,?,0)',
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
    for (final raw in aggregate['payments'] as List) {
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
      'INSERT INTO transaction_cloud_identity(local_uuid,cloud_uuid,scope,revision,final_number,snapshot) VALUES(?,?,?,1,?,?)',
      [uuid, uuid, scope, aggregate['final_number'], jsonEncode(aggregate)],
    );
  }

  bool _same(dynamic a, dynamic b) {
    if (a is Map && b is Map) {
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
