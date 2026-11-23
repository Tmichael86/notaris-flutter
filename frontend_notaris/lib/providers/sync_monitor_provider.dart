import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/sync_monitor_repository.dart';
import 'database_provider.dart';

final syncMonitorProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
      (ref) => SyncMonitorRepository(ref.watch(appDatabaseProvider)).read(),
    );
