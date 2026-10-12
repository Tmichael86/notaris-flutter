import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';

/// Process states owned by the local process-validation workflow.
abstract final class ProcessValidationStatus {
  static const belumDikerjakan = 'belum_dikerjakan';
  static const dalamPengerjaan = 'dalam_pengerjaan';
  static const menungguValidasi = 'menunggu_validasi';
  static const valid = 'valid';
  static const perluRevisi = 'perlu_revisi';

  static const all = <String>{
    belumDikerjakan,
    dalamPengerjaan,
    menungguValidasi,
    valid,
    perluRevisi,
  };

  static const transitions = <String, Set<String>>{
    belumDikerjakan: {dalamPengerjaan},
    dalamPengerjaan: {menungguValidasi},
    menungguValidasi: {valid, perluRevisi},
    perluRevisi: {dalamPengerjaan},
    valid: {},
  };
}

/// Persists process state transitions and their audit history atomically.
///
/// This is local workflow enforcement only. The Go API must repeat these
/// checks as the authoritative authorization boundary when synchronization
/// and multi-user validation are implemented.
class TransaksiProsesRepository {
  TransaksiProsesRepository(this.db);

  final AppDatabase db;
  static const _uuid = Uuid();

  /// Returns active process rows belonging to active transaction details.
  Future<List<TransaksiProse>> getByTransactionId(int transactionId) async {
    final rows = await (db.select(db.transaksiProses)
          ..where(
            (p) =>
                p.transaksiId.equals(transactionId) & p.deletedAt.isNull(),
          )
          ..orderBy([(p) => OrderingTerm.asc(p.id)]))
        .get();

    if (rows.isEmpty) return rows;

    final activeDetailUuids = (await (db.select(db.transaksiDetails)
              ..where(
                (d) =>
                    d.transaksiId.equals(transactionId) &
                    d.deletedAt.isNull() &
                    d.status.equals(1),
              ))
            .get())
        .map((detail) => detail.uuid)
        .toSet();

    return rows
        .where((process) => activeDetailUuids.contains(process.transaksiDetailUuid))
        .toList();
  }

  /// Explicitly initializes a migrated legacy process whose validation state
  /// is unknown. This records a new action now; it does not infer past history.
  Future<void> initializeLegacyProcess({
    required int processId,
    required int actorUserId,
    String? note,
  }) async {
    if (actorUserId <= 0) {
      throw ArgumentError.value(actorUserId, 'actorUserId', 'Harus positif.');
    }

    await db.transaction(() async {
      final process = await _getActiveProcess(processId);
      if (process.statusProses != null) {
        throw StateError('Proses sudah memiliki status validasi.');
      }

      await _writeTransition(
        process: process,
        nextStatus: ProcessValidationStatus.belumDikerjakan,
        actorUserId: actorUserId,
        note: note,
        now: DateTime.now(),
      );
    });
  }

  /// Applies one allowed state transition and appends its audit record.
  ///
  /// Moving to menunggu_validasi records the submitting actor/time.
  /// Approving or requesting revision is rejected when the actor is the same
  /// person who submitted that process for validation.
  Future<void> transition({
    required int processId,
    required String nextStatus,
    required int actorUserId,
    String? note,
  }) async {
    if (actorUserId <= 0) {
      throw ArgumentError.value(actorUserId, 'actorUserId', 'Harus positif.');
    }
    if (!ProcessValidationStatus.all.contains(nextStatus)) {
      throw ArgumentError.value(nextStatus, 'nextStatus', 'Status tidak dikenal.');
    }

    await db.transaction(() async {
      final process = await _getActiveProcess(processId);
      final currentStatus = process.statusProses;

      if (currentStatus == null) {
        throw StateError(
          'Status proses legacy belum diinisialisasi. '
          'Panggil initializeLegacyProcess terlebih dahulu.',
        );
      }

      final allowed = ProcessValidationStatus.transitions[currentStatus] ?? const <String>{};
      if (!allowed.contains(nextStatus)) {
        throw StateError('Transisi status tidak diizinkan: $currentStatus -> $nextStatus.');
      }

      if (currentStatus == ProcessValidationStatus.menungguValidasi &&
          (nextStatus == ProcessValidationStatus.valid ||
              nextStatus == ProcessValidationStatus.perluRevisi)) {
        if (process.submittedByUserId == null) {
          throw StateError(
            'Pengajuan validasi tidak memiliki identitas pengaju.',
          );
        }
        if (process.submittedByUserId == actorUserId) {
          throw StateError('Pengaju tidak boleh memvalidasi pekerjaannya sendiri.');
        }
        if (nextStatus == ProcessValidationStatus.perluRevisi &&
            (note?.trim().isEmpty ?? true)) {
          throw ArgumentError('Catatan revisi wajib diisi.');
        }
      }

      if (nextStatus == ProcessValidationStatus.menungguValidasi &&
          (note?.trim().isEmpty ?? true)) {
        throw ArgumentError('Catatan pengajuan validasi wajib diisi.');
      }

      await _writeTransition(
        process: process,
        nextStatus: nextStatus,
        actorUserId: actorUserId,
        note: note,
        now: DateTime.now(),
      );
    });
  }

  /// Returns audit entries in chronological order for one process.
  Future<List<TransaksiProsesRiwayatData>> getHistory(int processId) async {
    final process = await _getActiveProcess(processId);
    return (db.select(db.transaksiProsesRiwayat)
          ..where((h) => h.transaksiProsesId.equals(process.id))
          ..orderBy([
            (h) => OrderingTerm.asc(h.createdAt),
            (h) => OrderingTerm.asc(h.id),
          ]))
        .get();
  }

  Future<TransaksiProse> _getActiveProcess(int processId) async {
    final process = await (db.select(db.transaksiProses)
          ..where(
            (p) => p.id.equals(processId) & p.deletedAt.isNull(),
          ))
        .getSingleOrNull();
    if (process == null) {
      throw StateError('Proses tidak ditemukan atau sudah dihapus.');
    }

    final detail = await (db.select(db.transaksiDetails)
          ..where(
            (d) =>
                d.uuid.equals(process.transaksiDetailUuid) &
                d.transaksiId.equals(process.transaksiId) &
                d.deletedAt.isNull() &
                d.status.equals(1),
          ))
        .getSingleOrNull();
    if (detail == null) {
      throw StateError('Detail pekerjaan tidak aktif atau sudah dihapus.');
    }

    final transaction = await (db.select(db.transaksis)
          ..where(
            (t) =>
                t.id.equals(process.transaksiId) & t.deletedAt.isNull(),
          ))
        .getSingleOrNull();
    if (transaction == null) {
      throw StateError('Transaksi tidak ditemukan atau sudah dihapus.');
    }

    return process;
  }

  Future<void> _writeTransition({
    required TransaksiProse process,
    required String nextStatus,
    required int actorUserId,
    required String? note,
    required DateTime now,
  }) async {
    final normalizedNote = _nullableText(note);
    final isSubmission = nextStatus == ProcessValidationStatus.menungguValidasi;
    final isDecision = nextStatus == ProcessValidationStatus.valid ||
        nextStatus == ProcessValidationStatus.perluRevisi;

    await (db.update(db.transaksiProses)
          ..where(
            (p) => p.id.equals(process.id) & p.deletedAt.isNull(),
          ))
        .write(
      TransaksiProsesCompanion(
        statusProses: Value(nextStatus),
        catatan: Value(normalizedNote),
        submittedByUserId: isSubmission
            ? Value(actorUserId)
            : (nextStatus == ProcessValidationStatus.dalamPengerjaan
                ? const Value(null)
                : const Value.absent()),
        submittedAt: isSubmission
            ? Value(now)
            : (nextStatus == ProcessValidationStatus.dalamPengerjaan
                ? const Value(null)
                : const Value.absent()),
        validatedByUserId: isDecision
            ? Value(actorUserId)
            : (nextStatus == ProcessValidationStatus.dalamPengerjaan
                ? const Value(null)
                : const Value.absent()),
        validatedAt: isDecision
            ? Value(now)
            : (nextStatus == ProcessValidationStatus.dalamPengerjaan
                ? const Value(null)
                : const Value.absent()),
        updatedAt: Value(now),
        isSyncDirty: const Value(true),
      ),
    );

    await db.into(db.transaksiProsesRiwayat).insert(
      TransaksiProsesRiwayatCompanion.insert(
        uuid: _uuid.v4(),
        transaksiProsesId: process.id,
        statusSebelumnya: Value(process.statusProses),
        statusBaru: nextStatus,
        actorUserId: Value(actorUserId),
        createdAt: now,
        catatan: Value(normalizedNote),
        isSyncDirty: const Value(true),
      ),
    );
  }

  static String? _nullableText(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}
