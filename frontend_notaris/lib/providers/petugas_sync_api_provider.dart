import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/petugas_sync_api.dart';
import 'authenticated_api_provider.dart';

// Lazy adapter only; no synchronization or timer is started by this provider.
final petugasSyncApiProvider = Provider<PetugasSyncApi>(
  (ref) => PetugasSyncApi(ref.watch(authenticatedDioProvider)),
);
