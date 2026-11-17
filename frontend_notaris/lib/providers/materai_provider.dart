import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/materai_repository.dart';
import 'auth_provider.dart';
import 'database_provider.dart';

final materaiReportProvider = FutureProvider.autoDispose<MateraiReport>((ref) {
  if (!canReadMaterai(ref.watch(authControllerProvider).session)) {
    throw StateError('Izin baca Laporan Materai diperlukan.');
  }
  return MateraiRepository(
    ref.watch(appDatabaseProvider),
    () => ref.read(authControllerProvider).session,
  ).read();
});
