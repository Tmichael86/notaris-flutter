import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';

class SyncLogRepository {
  SyncLogRepository(this.db, {this.changed});
  final AppDatabase db;
  final void Function()? changed;

  Future<List<Map<String, dynamic>>> list({
    String? module,
    String? status,
  }) async {
    final rows = await db
        .customSelect(
          'SELECT * FROM sync_logs WHERE (? IS NULL OR module=?) AND (? IS NULL OR status=?) ORDER BY id DESC LIMIT 500',
          variables: [
            Variable<String>(module),
            Variable<String>(module),
            Variable<String>(status),
            Variable<String>(status),
          ],
        )
        .get();
    return rows.map((r) => r.data).toList();
  }

  Future<void> track({
    required String module,
    required String direction,
    required String attemptId,
    required Future<int?> Function() action,
    required String Function(Object) errorCode,
  }) async {
    final inserted = await db.transaction(() async {
      final duplicate = await db
          .customSelect(
            'SELECT id FROM sync_logs WHERE attempt_id=? AND module=? AND direction=?',
            variables: [
              Variable(attemptId),
              Variable(module),
              Variable(direction),
            ],
          )
          .get();
      if (duplicate.isNotEmpty) return false;
      final prior = await db
          .customSelect(
            'SELECT operation_id,status FROM sync_logs WHERE module=? AND direction=? ORDER BY id DESC LIMIT 1',
            variables: [Variable(module), Variable(direction)],
          )
          .getSingleOrNull();
      final operation =
          prior != null && prior.read<String>('status') != 'success'
          ? prior.read<String>('operation_id')
          : const Uuid().v4();
      await db.customStatement(
        'INSERT INTO sync_logs(operation_id,attempt_id,module,direction,started_at,status,error_code,error_message) VALUES(?,?,?,?,?,\'pending\',\'in_progress\',\'Operasi belum terkonfirmasi selesai\')',
        [
          operation,
          attemptId,
          module,
          direction,
          DateTime.now().toUtc().toIso8601String(),
        ],
      );
      return true;
    });
    if (!inserted) return;
    changed?.call();
    int? count;
    try {
      count = await action();
    } catch (error) {
      final candidate = errorCode(error);
      final code =
          {
            'offline',
            'timeout',
            'unauthorized',
            'forbidden',
            'conflict',
            'validation',
            'server',
          }.contains(candidate)
          ? candidate
          : 'unknown';
      final pending = {'offline', 'timeout', 'server'}.contains(code);
      // Never persist error.toString(), Dio bodies, URLs, credentials or payloads.
      final message = switch (code) {
        'offline' => 'Koneksi tidak tersedia; menunggu percobaan berikutnya',
        'timeout' => 'Batas waktu terlampaui; hasil belum terkonfirmasi',
        'unauthorized' => 'Autentikasi diperlukan',
        'forbidden' => 'Akses ditolak',
        'conflict' => 'Konflik data memerlukan pemeriksaan',
        'validation' => 'Data atau referensi belum valid',
        'server' => 'Layanan gagal; menunggu percobaan berikutnya',
        _ => 'Operasi gagal; periksa konfigurasi dan koneksi',
      };
      await _finish(
        attemptId,
        module,
        direction,
        pending ? 'pending' : 'failed',
        null,
        code,
        message,
      );
      rethrow;
    }
    await _finish(attemptId, module, direction, 'success', count, null, null);
  }

  Future<void> _finish(
    String attempt,
    String module,
    String direction,
    String status,
    int? count,
    String? code,
    String? message,
  ) async {
    await db.customStatement(
      'UPDATE sync_logs SET status=?,finished_at=?,record_count=?,error_code=?,error_message=? WHERE attempt_id=? AND module=? AND direction=?',
      [
        status,
        DateTime.now().toUtc().toIso8601String(),
        count,
        code,
        message,
        attempt,
        module,
        direction,
      ],
    );
    changed?.call();
  }
}
