import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/recycle_bin_repository.dart';
import 'auth_provider.dart';
import 'database_provider.dart';

final recycleBinRepositoryProvider = Provider<RecycleBinRepository>(
  (ref) => RecycleBinRepository(
    ref.watch(appDatabaseProvider),
    () => ref.read(authControllerProvider).session,
  ),
);

final recycleBinRecordsProvider = FutureProvider.autoDispose
    .family<List<RecycleRecord>, RecycleModule?>((ref, module) {
      ref.watch(authControllerProvider);
      return ref.watch(recycleBinRepositoryProvider).list(module: module);
    });
