import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/sync_log_repository.dart';
import 'database_provider.dart';
import 'sync_monitor_provider.dart';

final syncLogsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, ({String? module, String? status})>(
      (ref, filter) => ref
          .watch(syncLogRepositoryProvider)
          .list(module: filter.module, status: filter.status),
    );
final Provider<SyncLogRepository> syncLogRepositoryProvider =
    Provider<SyncLogRepository>(
      (ref) => SyncLogRepository(
        ref.watch(appDatabaseProvider),
        changed: () {
          ref.invalidate(syncLogsProvider);
          ref.invalidate(syncMonitorProvider);
        },
      ),
    );
