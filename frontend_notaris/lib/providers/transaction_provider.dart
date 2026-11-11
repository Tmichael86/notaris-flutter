import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../models/dashboard_transactions.dart';
import '../models/transaction_monitoring.dart';
import '../models/transaction_payments.dart';
import '../repositories/transaction_repository.dart';
import 'database_provider.dart';
import 'auth_provider.dart';
import '../models/auth_session.dart';

bool canSaveNotarisTransaction(
  AuthSession? session, {
  required bool editing,
  required bool completing,
}) {
  return session?.hasTransactionAccess(
        create: !editing,
        update: editing || completing,
      ) ??
      false;
}

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(appDatabaseProvider));
});

final transactionsProvider = StreamProvider.autoDispose<List<Transaksi>>((ref) {
  return ref.watch(transactionRepositoryProvider).watchAll();
});

final transactionPaymentStatementProvider = StreamProvider.autoDispose
    .family<TransactionPaymentStatement, int>(
      (ref, id) => ref
          .watch(transactionRepositoryProvider)
          .watchPaymentStatement(id, ref.watch(authControllerProvider).session),
    );

final monitoringPageProvider = StreamProvider.autoDispose
    .family<MonitoringPage, MonitoringFilter>(
      (ref, filter) =>
          ref.watch(transactionRepositoryProvider).watchMonitoringPage(filter),
    );
final monitoringOptionsProvider = StreamProvider.autoDispose
    .family<MonitoringOptions, String>(
      (ref, domain) => ref
          .watch(transactionRepositoryProvider)
          .watchMonitoringOptions(domain),
    );
final monitoringTransactionProvider = StreamProvider.autoDispose
    .family<MonitoringRow?, int>(
      (ref, id) => ref
          .watch(transactionRepositoryProvider)
          .watchMonitoringTransaction(id),
    );
final monitoringDetailsProvider = StreamProvider.autoDispose
    .family<List<TransaksiDetail>, int>(
      (ref, id) =>
          ref.watch(transactionRepositoryProvider).watchMonitoringDetails(id),
    );

final dashboardTransactionPageProvider = StreamProvider.autoDispose
    .family<
      DashboardTransactionPage,
      ({DashboardTransactionList list, int year, int index})
    >(
      (ref, request) => ref
          .watch(transactionRepositoryProvider)
          .watchDashboardPage(
            list: request.list,
            year: request.year,
            pageIndex: request.index,
          ),
    );

final receivedPaymentsProvider = StreamProvider.autoDispose.family<double, int>(
  (ref, year) =>
      ref.watch(transactionRepositoryProvider).watchReceivedPayments(year),
);

final transactionControllerProvider =
    AsyncNotifierProvider<TransactionController, void>(
      TransactionController.new,
    );

class TransactionController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  TransactionRepository get _repository =>
      ref.read(transactionRepositoryProvider);

  Future<int> save({
    int? id,
    required String nomorTransaksi,
    required String jenisTransaksi,
    required int pemohonId,
    required String pemohonUuid,
    required int petugasId,
    required String petugasUuid,
    required String status,
    required DateTime tanggalTransaksi,
    DateTime? tanggalJatuhTempo,
    required List<TransactionJobInput> jobs,
    double diskon = 0,
    double pembayaranSekarang = 0,
    String metodePembayaran = 'Cash',
    int jumlahMaterai = 0,
    String? catatan,
    NotarisDeedInput? deed,
  }) async {
    if (jenisTransaksi == 'notaris' &&
        !canSaveNotarisTransaction(
          ref.read(authControllerProvider).session,
          editing: id != null,
          completing: status.trim().toLowerCase() == 'selesai',
        )) {
      throw StateError('Izin simpan Transaksi Notaris tidak tersedia.');
    }
    if (jenisTransaksi == 'ppat' &&
        id != null &&
        ref
                .read(authControllerProvider)
                .session
                ?.hasTransactionAccess(update: true) !=
            true) {
      throw StateError('Izin ubah Transaksi PPAT tidak tersedia.');
    }
    state = const AsyncLoading();
    try {
      final result = await _repository.save(
        id: id,
        nomorTransaksi: nomorTransaksi,
        jenisTransaksi: jenisTransaksi,
        pemohonId: pemohonId,
        pemohonUuid: pemohonUuid,
        petugasId: petugasId,
        petugasUuid: petugasUuid,
        status: status,
        tanggalTransaksi: tanggalTransaksi,
        tanggalJatuhTempo: tanggalJatuhTempo,
        jobs: jobs,
        diskon: diskon,
        pembayaranSekarang: pembayaranSekarang,
        metodePembayaran: metodePembayaran,
        jumlahMaterai: jumlahMaterai,
        catatan: catatan,
        deed: deed,
      );
      state = const AsyncData(null);
      return result;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<bool> delete(int id) async {
    state = const AsyncLoading();
    try {
      final result = await _repository.delete(id);
      state = const AsyncData(null);
      return result;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}
