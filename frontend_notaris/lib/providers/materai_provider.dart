import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/materai_repository.dart';
import '../repositories/materai_stock_repository.dart';
import 'auth_provider.dart';
import 'database_provider.dart';

final materaiStockBindingProvider = Provider<MateraiStockBinding?>(
  (ref) => null,
);

final materaiStockRepositoryProvider =
    Provider.autoDispose<MateraiStockRepository?>((ref) {
      final binding = ref.watch(materaiStockBindingProvider);
      if (binding == null ||
          !identical(binding.database, ref.watch(appDatabaseProvider))) {
        return null;
      }
      return MateraiStockRepository(
        binding,
        () => ref.read(authControllerProvider).session,
      );
    });

final materaiStockContextProvider =
    FutureProvider.autoDispose<MateraiStockContext?>((ref) {
      if (!canCreateMaterai(ref.watch(authControllerProvider).session)) {
        return null;
      }
      return ref.watch(materaiStockRepositoryProvider)?.context();
    });

final materaiTransactionStockContextProvider =
    FutureProvider.autoDispose<MateraiStockContext?>((ref) {
      ref.watch(authControllerProvider);
      return ref
          .watch(materaiStockRepositoryProvider)
          ?.context(transactionUsage: true);
    });

final materaiCorrectionPreviewProvider = FutureProvider.autoDispose
    .family<MateraiCorrectionPreview?, int>((ref, id) {
      ref.watch(authControllerProvider);
      if (ref
              .watch(materaiStockBindingProvider)
              ?.transactionCorrectionsEnabled !=
          true) {
        return null;
      }
      return ref.watch(materaiStockRepositoryProvider)?.correctionPreview(id);
    });

final materaiReportProvider = FutureProvider.autoDispose<MateraiReport>((ref) {
  if (!canReadMaterai(ref.watch(authControllerProvider).session)) {
    throw StateError('Izin baca Laporan Materai diperlukan.');
  }
  return MateraiRepository(
    ref.watch(appDatabaseProvider),
    () => ref.read(authControllerProvider).session,
  ).read();
});
