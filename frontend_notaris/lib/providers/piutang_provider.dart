import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/piutang_repository.dart';
import 'auth_provider.dart';
import 'database_provider.dart';

final piutangRepositoryProvider = Provider<PiutangRepository>(
  (ref) => PiutangRepository(
    ref.watch(appDatabaseProvider),
    () => ref.read(authControllerProvider).session,
  ),
);

final piutangReportProvider = StreamProvider.autoDispose
    .family<PiutangReport, PiutangFilter>((ref, filter) {
      if (!canReadPiutang(ref.watch(authControllerProvider).session)) {
        throw StateError('Izin baca Piutang diperlukan.');
      }
      return ref.watch(piutangRepositoryProvider).watch(filter);
    });
