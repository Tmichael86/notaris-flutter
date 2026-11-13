import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../models/auth_session.dart';

enum RecycleModule {
  notaris('pekerjaan_notaris', 'Pekerjaan Notaris', 'notaris'),
  ppat('pekerjaan_ppat', 'Pekerjaan PPAT', 'ppat'),
  transactionNotaris('transaksi_notaris', 'Transaksi Notaris', 'notaris'),
  transactionPpat('transaksi_ppat', 'Transaksi PPAT', 'ppat');

  const RecycleModule(this.code, this.label, this.domain);
  final String code, label, domain;
  bool get isTransaction => code.startsWith('transaksi_');
  String get table => isTransaction ? 'transaksis' : 'pekerjaan_$domain';
  String get permission => isTransaction ? 'transaksi' : code;
}

class RestoreFailure implements Exception {
  const RestoreFailure(this.code);
  final String code;
  String get message => switch (code) {
    'permission' => 'Izin baca dan ubah modul diperlukan untuk memulihkan.',
    'cloud' => 'Restore cloud belum didukung. Identitas atau mutation cloud harus dipulihkan melalui kontrak RESTORE server.',
    'reference' => 'Referensi tidak aktif atau tidak valid. Pulihkan referensi terlebih dahulu.',
    'history' => 'Bukti status atau detail sebelum penghapusan tidak tersedia atau telah berubah. Pemulihan diblokir tanpa menebak data.',
    'stale' => 'Record telah berubah. Muat ulang daftar sebelum melanjutkan.',
    _ => 'Pemulihan gagal; perubahan data dibatalkan. Periksa histori lokal.',
  };
}

class RecycleRecord {
  const RecycleRecord(
    this.module,
    this.id,
    this.uuid,
    this.label,
    this.deletedAt,
    this.blocked,
  );
  final RecycleModule module;
  final int id;
  final String uuid, label;
  final DateTime deletedAt;
  final RestoreFailure? blocked;
}

/// Local recovery only. No HTTP client, coordinator, or cloud mutation capability.
class RecycleBinRepository {
  RecycleBinRepository(this.db, this.session);
  final AppDatabase db;
  final AuthSession? Function() session;

  bool canRead(RecycleModule module) => _allowed(module, 'read');
  bool _allowed(RecycleModule module, String action) {
    bool yes(dynamic v) => v == 1 || v == true || v == '1';
    return session()?.sidebars.any((a) {
          final sidebar = a['sidebar'];
          return sidebar is Map &&
              (sidebar['sidebar_kode'] == module.permission ||
                  (sidebar['sidebar_kode'] == null &&
                      sidebar['sidebar_nama'] ==
                          (module.isTransaction
                              ? 'Transaksi'
                              : module.label))) &&
              (sidebar['status'] == null || yes(sidebar['status'])) &&
              yes(a['read']) &&
              yes(a[action]);
        }) ??
        false;
  }

  Future<List<RecycleRecord>> list({RecycleModule? module}) async {
    final result = <RecycleRecord>[];
    for (final m in module == null ? RecycleModule.values : [module]) {
      if (!canRead(m)) continue;
      final rows = await db
          .customSelect(
            'SELECT * FROM ${m.table} WHERE deleted_at IS NOT NULL${m.isTransaction ? ' AND jenis_transaksi=?' : ''}',
            variables: [if (m.isTransaction) Variable(m.domain)],
          )
          .get();
      for (final r in rows) {
        final uuid = r.read<String>('uuid');
        RestoreFailure? blocked;
        try {
          await _validate(m, r.data);
        } on RestoreFailure catch (e) {
          blocked = e;
        }
        result.add(
          RecycleRecord(
            m,
            r.read<int>('id'),
            uuid,
            r.read<String>(m.isTransaction ? 'no_akta' : 'nama'),
            DateTime.fromMillisecondsSinceEpoch(
              r.read<int>('deleted_at') * 1000,
            ),
            blocked,
          ),
        );
      }
    }
    result.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
    return result;
  }

  Future<List<Map<String, dynamic>>> history() async {
    final rows = await db
        .customSelect(
          "SELECT * FROM recycle_bin_events WHERE action='restore' ORDER BY id DESC LIMIT 100",
        )
        .get();
    return rows
        .where(
          (r) => RecycleModule.values.any(
            (m) => m.code == r.read<String>('module') && canRead(m),
          ),
        )
        .map((r) => r.data)
        .toList();
  }

  Future<void> restore(RecycleRecord record) async {
    final attempt = const Uuid().v4();
    try {
      await db.transaction(() async {
        final m = record.module;
        final r = await db
            .customSelect(
              'SELECT * FROM ${m.table} WHERE id=? AND uuid=?',
              variables: [Variable(record.id), Variable(record.uuid)],
            )
            .getSingleOrNull();
        if (r == null ||
            r.data['deleted_at'] !=
                record.deletedAt.millisecondsSinceEpoch ~/ 1000 ||
            (m.isTransaction &&
                r.read<String>('jenis_transaksi') != m.domain)) {
          throw const RestoreFailure('stale');
        }
        await _validate(
          m,
          r.data,
        ); // Revalidate permission/references after confirmation.
        if (!m.isTransaction) {
          final children = await _masterChildren(m, r.data);
          for (final c in children) {
            await db.customUpdate(
              'UPDATE ${c['table']} SET deleted_at=NULL,status=?,is_sync_dirty=1 WHERE id=? AND uuid=?',
              variables: [
                Variable(c['status'] as int),
                Variable(c['id'] as int),
                Variable(c['uuid'] as String),
              ],
              updates: {
                db.pekerjaanNotarisHargaLocals,
                db.pekerjaanNotarisProsesLocals,
                db.pekerjaanNotarisAtributLocals,
                db.pekerjaanPpatHargaLocals,
                db.pekerjaanPpatProsesLocals,
                db.pekerjaanPpatAtributLocals,
              },
            );
          }
        }
        String? originalStatus;
        if (m.isTransaction) {
          final before = await _transactionBefore(r.data, m);
          originalStatus = before['status'] as String;
          for (final detail in (before['details'] as List).cast<Map>()) {
            await db.customUpdate(
              'UPDATE transaksi_details SET deleted_at=NULL,status=?,updated_at=?,is_sync_dirty=1 WHERE transaksi_id=? AND uuid=? AND deleted_at=?',
              variables: [
                Variable(detail['status'] as int),
                Variable(_now()),
                Variable(record.id),
                Variable(detail['uuid'] as String),
                Variable(r.read<int>('deleted_at')),
              ],
              updates: {db.transaksiDetails},
            );
          }
        }
        await db.customUpdate(
          'UPDATE ${m.table} SET deleted_at=NULL,${m.isTransaction ? 'status_transaksi=?' : 'status=1'},updated_at=?,is_sync_dirty=1 WHERE id=?',
          variables: [
            if (m.isTransaction) Variable(originalStatus!),
            Variable(_now()),
            Variable(record.id),
          ],
          updates: {
            if (m.isTransaction)
              db.transaksis
            else if (m == RecycleModule.notaris)
              db.pekerjaanNotarisLocals
            else
              db.pekerjaanPpatLocals,
          },
        );
        await _log(record, attempt, 'success', null);
      });
    } catch (e) {
      // Rolled-back data writes and success audit cannot survive a failure.
      final failure = e is RestoreFailure ? e : const RestoreFailure('storage');
      await _log(record, attempt, 'failed', failure.code);
      throw failure;
    }
  }

  int _now() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  Future<void> _log(
    RecycleRecord r,
    String attempt,
    String outcome,
    String? code,
  ) => db.customStatement(
    "INSERT INTO recycle_bin_events(attempt_id,module,local_uuid,action,outcome,actor_id,occurred_at,error_code) VALUES(?,?,?,'restore',?,?,?,?)",
    [
      attempt,
      r.module.code,
      r.uuid,
      outcome,
      session()?.userId,
      DateTime.now().toUtc().toIso8601String(),
      code,
    ],
  );

  Future<bool> _exists(String sql, List<Variable> vars) async =>
      (await db.customSelect(sql, variables: vars).get()).isNotEmpty;

  Future<void> _validate(RecycleModule m, Map<String, dynamic> r) async {
    if (!_allowed(m, 'update')) throw const RestoreFailure('permission');
    final uuid = r['uuid'] as String;
    final prefix = m.isTransaction
        ? 'transaction_cloud'
        : 'pekerjaan_${m.domain}_sync';
    if (r['last_synced_at'] != null ||
        r['is_sync_dirty'] != 1 ||
        await _exists(
          'SELECT 1 FROM ${prefix}_identity WHERE local_uuid=? UNION ALL SELECT 1 FROM ${prefix}_pending WHERE local_uuid=?',
          [Variable(uuid), Variable(uuid)],
        )) {
      throw const RestoreFailure('cloud');
    }
    final id = r['id'] as int;
    if (m.isTransaction) {
      for (final table in [
        'transaksi_details',
        'transaksi_proses',
        'transaksi_riwayat_pembayaran',
      ]) {
        if (await _exists(
          'SELECT 1 FROM $table WHERE transaksi_id=? AND (last_synced_at IS NOT NULL OR is_sync_dirty=0)',
          [Variable(id)],
        )) {
          throw const RestoreFailure('cloud');
        }
      }
      final before = await _transactionBefore(r, m);
      for (final person in [('pemohons', 'pemohon'), ('petugas', 'petugas')]) {
        if (!await _exists(
          'SELECT 1 FROM ${person.$1} WHERE id=? AND uuid=? AND status=1 AND deleted_at IS NULL',
          [
            Variable(r['${person.$2}_id'] as int?),
            Variable(r['${person.$2}_uuid'] as String?),
          ],
        )) {
          throw const RestoreFailure('reference');
        }
      }
      for (final detail in (before['details'] as List).cast<Map>()) {
        final detailUuid = detail['uuid'] as String;
        final d = await db
            .customSelect(
              'SELECT * FROM transaksi_details WHERE transaksi_id=? AND uuid=?',
              variables: [Variable(id), Variable(detailUuid)],
            )
            .getSingleOrNull();
        if (d == null ||
            d.data['deleted_at'] != r['deleted_at'] ||
            d.read<int>('status') != 0) {
          throw const RestoreFailure('history');
        }
        final job = d.data['pekerjaan_${m.domain}_id'] as int?;
        final other = m.domain == 'ppat' ? 'notaris' : 'ppat';
        if (d.read<String>('jenis_pekerjaan') != m.domain ||
            d.data['pekerjaan_${other}_id'] != null ||
            job == null ||
            !await _exists(
              'SELECT 1 FROM pekerjaan_${m.domain} WHERE id=? AND status=1 AND deleted_at IS NULL',
              [Variable(job)],
            )) {
          throw const RestoreFailure('reference');
        }
        if (d.data['harga_uuid'] != null &&
            !await _exists(
              'SELECT 1 FROM pekerjaan_${m.domain}_harga h JOIN pekerjaan_kategori c ON c.id=h.kategori_pekerjaan_id WHERE h.uuid=? AND h.pekerjaan_${m.domain}_id=? AND c.uuid=? AND h.status=1 AND h.deleted_at IS NULL AND c.status=1 AND c.deleted_at IS NULL',
              [
                Variable(d.data['harga_uuid'] as String),
                Variable(job),
                Variable(d.data['kategori_uuid'] as String?),
              ],
            )) {
          throw const RestoreFailure('reference');
        }
      }
    } else {
      await _masterChildren(m, r);
      final domain = m.domain;
      for (final suffix in ['harga', 'proses', 'atributs']) {
        if (await _exists(
          'SELECT 1 FROM pekerjaan_${domain}_$suffix WHERE pekerjaan_${domain}_id=? AND (last_synced_at IS NOT NULL OR is_sync_dirty=0)',
          [Variable(id)],
        )) {
          throw const RestoreFailure('cloud');
        }
      }
      if (await _exists(
            'SELECT 1 FROM pekerjaan_${domain}_harga h LEFT JOIN pekerjaan_kategori c ON c.id=h.kategori_pekerjaan_id WHERE h.pekerjaan_${domain}_id=? AND h.deleted_at IS NULL AND h.status=1 AND (c.id IS NULL OR c.status<>1 OR c.deleted_at IS NOT NULL)',
            [Variable(id)],
          ) ||
          await _exists(
            'SELECT 1 FROM pekerjaan_${domain}_atributs a LEFT JOIN pekerjaan_${domain}_proses p ON p.id=a.proses_pekerjaan_${domain}_id WHERE a.pekerjaan_${domain}_id=? AND a.deleted_at IS NULL AND a.status=1 AND (p.id IS NULL OR p.pekerjaan_${domain}_id<>a.pekerjaan_${domain}_id OR p.deleted_at IS NOT NULL OR p.status<>1)',
            [Variable(id)],
          )) {
        throw const RestoreFailure('reference');
      }
    }
  }

  Future<List<Map<String, dynamic>>> _masterChildren(
    RecycleModule m,
    Map<String, dynamic> r,
  ) async {
    final event = await db
        .customSelect(
          "SELECT before_state FROM recycle_bin_events WHERE module=? AND local_uuid=? AND action='delete' ORDER BY id DESC LIMIT 1",
          variables: [Variable(m.code), Variable(r['uuid'] as String)],
        )
        .getSingleOrNull();
    if (event == null) {
      for (final suffix in ['harga', 'proses', 'atributs']) {
        if (await _exists(
          'SELECT 1 FROM pekerjaan_${m.domain}_$suffix WHERE pekerjaan_${m.domain}_id=? AND deleted_at IS NOT NULL',
          [Variable(r['id'] as int)],
        )) {
          throw const RestoreFailure('history');
        }
      }
      return [];
    }
    final before = jsonDecode(event.read<String>('before_state')) as Map;
    if (before['deletedAt'] != r['deleted_at']) {
      throw const RestoreFailure('history');
    }
    final children = (before['children'] as List)
        .cast<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final allowed = [
      'harga',
      'proses',
      'atributs',
    ].map((s) => 'pekerjaan_${m.domain}_$s').toSet();
    for (final c in children) {
      if (!allowed.contains(c['table'])) throw const RestoreFailure('history');
      final row = await db
          .customSelect(
            'SELECT * FROM ${c['table']} WHERE id=? AND uuid=? AND pekerjaan_${m.domain}_id=?',
            variables: [
              Variable(c['id'] as int),
              Variable(c['uuid'] as String),
              Variable(r['id'] as int),
            ],
          )
          .getSingleOrNull();
      if (row == null ||
          row.data['deleted_at'] != r['deleted_at'] ||
          row.data['status'] != 0) {
        throw const RestoreFailure('history');
      }
      if ((c['table'] as String).endsWith('_harga') &&
          !await _exists(
            'SELECT 1 FROM pekerjaan_kategori WHERE id=? AND status=1 AND deleted_at IS NULL',
            [Variable(row.read<int>('kategori_pekerjaan_id'))],
          )) {
        throw const RestoreFailure('reference');
      }
      if ((c['table'] as String).endsWith('_atributs') &&
          !children.any(
            (p) =>
                p['table'] == 'pekerjaan_${m.domain}_proses' &&
                p['id'] == row.data['proses_pekerjaan_${m.domain}_id'],
          )) {
        throw const RestoreFailure('reference');
      }
    }
    return children;
  }

  Future<Map<String, dynamic>> _transactionBefore(
    Map<String, dynamic> r,
    RecycleModule m,
  ) async {
    final event = await db
        .customSelect(
          "SELECT before_state FROM recycle_bin_events WHERE module=? AND local_uuid=? AND action='delete' AND outcome='success' ORDER BY id DESC LIMIT 1",
          variables: [Variable(m.code), Variable(r['uuid'] as String)],
        )
        .getSingleOrNull();
    try {
      final before = jsonDecode(
        event?.read<String>('before_state') ?? '',
      ) as Map<String, dynamic>;
      if (before['deletedAt'] != r['deleted_at'] ||
          before['status'] is! String ||
          before['status'] == 'Dihapus' ||
          (before['status'] as String).isEmpty ||
          before['details'] is! List ||
          (before['details'] as List).isEmpty ||
          !(before['details'] as List).every(
            (v) => v is Map && v['uuid'] is String && v['status'] is int,
          ) ||
          (before['details'] as List)
                  .map((v) => (v as Map)['uuid'])
                  .toSet()
                  .length !=
              (before['details'] as List).length) {
        throw const FormatException();
      }
      return before;
    } catch (_) {
      throw const RestoreFailure('history');
    }
  }
}
