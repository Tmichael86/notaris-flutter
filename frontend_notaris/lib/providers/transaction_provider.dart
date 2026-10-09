import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../repositories/transaction_repository.dart';
import 'database_provider.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(appDatabaseProvider));
});

final transactionsProvider = StreamProvider.autoDispose<List<Transaksi>>((ref) {
  return ref.watch(transactionRepositoryProvider).watchAll();
});

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
  }) async {
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
