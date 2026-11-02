import 'package:drift/drift.dart';

import '../database/app_database.dart';

const syncModules = <String, String>{
  'kategori': 'Kategori Pekerjaan',
  'pengeluaran': 'Jenis Pengeluaran',
  'pemohon': 'Pemohon',
  'petugas': 'Petugas',
  'pekerjaan_notaris': 'Pekerjaan Notaris',
  'pekerjaan_ppat': 'Pekerjaan PPAT',
  'transaksi': 'Transaksi',
};
const syncTables = <String, String>{
  'kategori': 'pekerjaan_kategori',
  'pengeluaran': 'pengeluaran_jenis',
  'pemohon': 'pemohons',
  'petugas': 'petugas',
  'pekerjaan_notaris': 'pekerjaan_notaris',
  'pekerjaan_ppat': 'pekerjaan_ppat',
  'transaksi': 'transaksis',
};

String selectiveSyncReason(String module) =>
    {'kategori', 'pengeluaran', 'pemohon'}.contains(module)
    ? 'Repository tersedia; coordinator hanya mendukung batch global. Seleksi arah belum memiliki single-flight dan guard izin bersama.'
    : module == 'petugas'
    ? 'Hanya baseline terkontrol; push/coordinator normal belum diaktifkan.'
    : 'Kontrak sinkronisasi aman modul ini belum tersedia.';

// No dispatch to global sync: unsupported selection fails closed in every mode.
Future<void> executeSelectedSync(String module, String direction) async {
  throw UnsupportedError(selectiveSyncReason(module));
}

class SyncMonitorRepository {
  SyncMonitorRepository(this.db);
  final AppDatabase db;
  Future<List<Map<String, dynamic>>> read() => db.transaction(() async {
    final result = <Map<String, dynamic>>[];
    for (final module in syncModules.keys) {
      final dirty =
          (await db
                  .customSelect(
                    'SELECT count(*) AS n FROM ${syncTables[module]} WHERE is_sync_dirty=1',
                  )
                  .getSingle())
              .read<int>('n');
      final latest = await db
          .customSelect(
            'SELECT * FROM sync_logs l WHERE module=? AND NOT EXISTS(SELECT 1 FROM sync_logs n WHERE n.module=l.module AND n.direction=l.direction AND n.id>l.id) ORDER BY id DESC',
            variables: [Variable(module)],
          )
          .get();
      final success = await db
          .customSelect(
            "SELECT started_at FROM sync_logs WHERE module=? AND status='success' ORDER BY id DESC LIMIT 1",
            variables: [Variable(module)],
          )
          .getSingleOrNull();
      var pending = dirty, conflicts = 0;
      var blocked = false;
      if (module == 'petugas') {
        pending =
            (await db
                    .customSelect(
                      'SELECT count(*) AS n FROM (SELECT uuid FROM petugas WHERE is_sync_dirty=1 UNION SELECT local_uuid FROM petugas_sync_journal WHERE pending IS NOT NULL)',
                    )
                    .getSingle())
                .read<int>('n');
        conflicts =
            (await db
                    .customSelect(
                      "SELECT count(*) AS n FROM petugas_sync_conflict WHERE state IN ('open','held')",
                    )
                    .getSingle())
                .read<int>('n');
        blocked =
            (await db
                    .customSelect(
                      'SELECT 1 FROM petugas_sync_feed WHERE blocked IS NOT NULL',
                    )
                    .get())
                .isNotEmpty;
      }
      final failed = latest
          .where((r) => r.read<String>('status') == 'failed')
          .length;
      final deferred = latest
          .where((r) => r.read<String>('status') == 'pending')
          .length;
      final running = latest
          .where((r) => r.readNullable<String>('finished_at') == null)
          .length;
      final color = blocked || conflicts > 0 || failed > 0
          ? 'red'
          : pending > 0 || deferred > 0
          ? 'yellow'
          : latest.isEmpty
          ? 'neutral'
          : latest.every((r) => r.read<String>('status') == 'success')
          ? 'green'
          : 'neutral';
      result.add({
        'module': module,
        'label': syncModules[module],
        'color': color,
        'last_attempt': latest.isEmpty
            ? null
            : latest.first.read<String>('started_at'),
        'last_success': success?.read<String>('started_at'),
        'pending_records': pending,
        'pending_operations': deferred,
        'errors': failed + conflicts + (blocked ? 1 : 0),
        'progress': running > 0
            ? '$running operasi belum terkonfirmasi selesai'
            : 'Tidak ada operasi berjalan yang tercatat',
        'reason': selectiveSyncReason(module),
        'snapshot_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
    return result;
  });
}
