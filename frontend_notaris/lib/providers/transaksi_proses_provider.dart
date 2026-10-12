import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../repositories/transaksi_proses_repository.dart';
import 'database_provider.dart';

final transaksiProsesRepositoryProvider = Provider<TransaksiProsesRepository>((
  ref,
) {
  return TransaksiProsesRepository(ref.watch(appDatabaseProvider));
});

/// Streams active process rows for a transaction and follows both process and
/// detail changes so soft-deleted transaction details disappear immediately.
final transaksiProsesByTransactionProvider = StreamProvider.autoDispose
    .family<List<TransaksiProse>, int>((ref, transactionId) {
      final database = ref.watch(appDatabaseProvider);
      final query =
          database.select(database.transaksiProses).join([
              innerJoin(
                database.transaksiDetails,
                database.transaksiDetails.uuid.equalsExp(
                  database.transaksiProses.transaksiDetailUuid,
                ),
              ),
              innerJoin(
                database.transaksis,
                database.transaksis.id.equalsExp(
                  database.transaksiProses.transaksiId,
                ),
              ),
            ])
            ..where(
              database.transaksiProses.transaksiId.equals(transactionId) &
                  database.transaksiProses.deletedAt.isNull() &
                  database.transaksiDetails.deletedAt.isNull() &
                  database.transaksiDetails.status.equals(1) &
                  database.transaksis.deletedAt.isNull(),
            )
            ..orderBy([OrderingTerm.asc(database.transaksiProses.id)]);

      return query.watch().map(
        (rows) =>
            rows.map((row) => row.readTable(database.transaksiProses)).toList(),
      );
    });

/// Streams the audit trail in stable chronological order.
final transaksiProsesHistoryProvider = StreamProvider.autoDispose
    .family<List<TransaksiProsesRiwayatData>, int>((ref, processId) {
      final database = ref.watch(appDatabaseProvider);
      return (database.select(database.transaksiProsesRiwayat)
            ..where((row) => row.transaksiProsesId.equals(processId))
            ..orderBy([
              (row) => OrderingTerm.asc(row.createdAt),
              (row) => OrderingTerm.asc(row.id),
            ]))
          .watch();
    });

final transaksiProsesControllerProvider =
    AsyncNotifierProvider<TransaksiProsesController, void>(
      TransaksiProsesController.new,
    );

/// Coordinates local process transitions and refreshes affected Riverpod
/// families. The supplied actor ID is local context, not server authorization.
class TransaksiProsesController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  TransaksiProsesRepository get _repository =>
      ref.read(transaksiProsesRepositoryProvider);

  Future<void> initializeLegacyProcess({
    required int transactionId,
    required int processId,
    required int actorUserId,
    String? note,
  }) async {
    await _runMutation(() async {
      await _repository.initializeLegacyProcess(
        processId: processId,
        actorUserId: actorUserId,
        note: note,
      );
      _invalidateAffected(transactionId, processId);
    });
  }

  Future<void> transition({
    required int transactionId,
    required int processId,
    required String nextStatus,
    required int actorUserId,
    String? note,
  }) async {
    await _runMutation(() async {
      await _repository.transition(
        processId: processId,
        nextStatus: nextStatus,
        actorUserId: actorUserId,
        note: note,
      );
      _invalidateAffected(transactionId, processId);
    });
  }

  Future<void> _runMutation(Future<void> Function() mutation) async {
    state = const AsyncLoading();
    try {
      await mutation();
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  void _invalidateAffected(int transactionId, int processId) {
    ref.invalidate(transaksiProsesByTransactionProvider(transactionId));
    ref.invalidate(transaksiProsesHistoryProvider(processId));
  }
}
