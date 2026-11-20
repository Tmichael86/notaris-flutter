import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/profile_api_service.dart';
import 'auth_provider.dart';
import 'authenticated_api_provider.dart';
import 'development_smoke_provider.dart';

final profileApiProvider = Provider<ProfileApiService>(
  (ref) => ProfileApiService(
    ref.watch(authenticatedDioProvider),
    session: () => ref.read(authControllerProvider).session,
  ),
);
// Only the runtime-attested dedicated acceptance entry overrides this provider.
// Normal UiSmoke retains both this UI block and its direct HTTP mutation block.
final profileEditingEnabledProvider = Provider<bool>(
  (ref) => !ref.watch(developmentUiSmokeProvider),
);
final ownProfileProvider = FutureProvider.autoDispose<OwnProfile>((ref) {
  if (!allowsOwnProfile(ref.watch(authControllerProvider).session)) {
    throw StateError('Sesi P0 online diperlukan.');
  }
  return ref.watch(profileApiProvider).read();
});

final profileEditingExplanationProvider = Provider<String>(
  (ref) => 'UI Smoke: perubahan akun melalui HTTP diblokir.',
);
