import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import 'isolated_transaction_profile_provider.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final isolated = ref.watch(isolatedTransactionSyncConfigurationProvider);
  final database = isolated?.database ?? AppDatabase();

  ref.onDispose(database.close);

  return database;
});
