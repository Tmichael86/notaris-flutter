import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/penghasilan_repository.dart';
import 'auth_provider.dart';
import 'database_provider.dart';

final penghasilanRepositoryProvider = Provider<PenghasilanRepository>(
  (ref) => PenghasilanRepository(
    ref.watch(appDatabaseProvider),
    () => ref.read(authControllerProvider).session,
  ),
);

final penghasilanReportProvider = StreamProvider.autoDispose<PenghasilanReport>(
  (ref) {
    if (!canReadPenghasilan(ref.watch(authControllerProvider).session)) {
      throw StateError('Izin baca Penghasilan diperlukan.');
    }
    return ref.watch(penghasilanRepositoryProvider).watch();
  },
);
