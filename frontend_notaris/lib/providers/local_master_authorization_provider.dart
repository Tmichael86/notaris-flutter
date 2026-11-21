import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/local_master_authorization.dart';
import 'auth_provider.dart';
import 'database_provider.dart';
export '../services/local_master_authorization.dart';

// Only a verified disposable bootstrap supplies its signed demo profile ID.
final localMasterProfileIdProvider = Provider<String?>((ref) => null);
final localMasterAuthorizationProvider = Provider<LocalMasterAuthorization>((
  ref,
) {
  final db = ref.watch(appDatabaseProvider);
  final profile = ref.watch(localMasterProfileIdProvider);
  return LocalMasterAuthorization(
    database: db,
    currentDatabase: () => ref.read(appDatabaseProvider),
    session: () => ref.read(authControllerProvider).session,
    profileId: profile,
  );
});
