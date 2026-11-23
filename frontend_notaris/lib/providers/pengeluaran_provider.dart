import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../repositories/pengeluaran_repository.dart';
import 'auth_provider.dart';
import 'database_provider.dart';

final pengeluaranRepositoryProvider = Provider<PengeluaranRepository>((ref) {
  return PengeluaranRepository(
    ref.watch(appDatabaseProvider),
    () => ref.read(authControllerProvider).session,
  );
});

final pengeluaranPageProvider = StreamProvider.autoDispose
    .family<PengeluaranPage, PengeluaranFilter>((ref, filter) {
      final session = ref.watch(authControllerProvider).session;
      if (!allowsPengeluaran(session, PengeluaranAction.read)) {
        throw const PengeluaranFailure('Anda tidak memiliki izin Pengeluaran.');
      }
      return ref.watch(pengeluaranRepositoryProvider).watchPage(filter);
    });

final pengeluaranFilterJenisProvider =
    StreamProvider.autoDispose<List<PengeluaranJenisData>>((ref) {
      final session = ref.watch(authControllerProvider).session;
      if (!allowsPengeluaran(session, PengeluaranAction.read)) {
        throw const PengeluaranFailure('Anda tidak memiliki izin Pengeluaran.');
      }
      return ref.watch(pengeluaranRepositoryProvider).watchFilterJenis();
    });
