import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/pendapatan_repository.dart';
import 'auth_provider.dart';
import 'database_provider.dart';

final pendapatanAccessProvider = Provider.autoDispose<bool>((ref) {
  final session = ref.watch(authControllerProvider).session;
  if (session == null || !canReadPendapatan(session)) return false;
  final remaining = pendapatanSessionExpiry(session)!
      .difference(DateTime.now());
  final timer = Timer(remaining, ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return true;
});

final pendapatanRepositoryProvider = Provider.autoDispose<PendapatanRepository>(
  (ref) {
    return PendapatanRepository(
      ref.watch(appDatabaseProvider),
      () => ref.read(authControllerProvider).session,
    );
  },
);

final pendapatanReportProvider = StreamProvider.autoDispose
    .family<PendapatanReport, PendapatanPeriod>((ref, period) {
      if (!ref.watch(pendapatanAccessProvider)) {
        throw StateError(pendapatanDenied);
      }
      return ref.watch(pendapatanRepositoryProvider).watch(period);
    });
