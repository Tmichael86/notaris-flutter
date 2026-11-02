import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../repositories/petugas_baseline_pull.dart';
import '../repositories/petugas_reference_resolver.dart';
import 'auth_provider.dart';
import 'authenticated_api_provider.dart';

class PetugasBaselinePullConfiguration {
  const PetugasBaselinePullConfiguration({
    required this.database,
    required this.context,
    required this.plan,
    required this.references,
  });
  final AppDatabase database;
  final PetugasBaselineContext context;
  final PetugasBaselinePlan plan;
  final VerifiedPetugasReferences references;
}

// Intentionally OFF in every normal profile. No default DB is read/opened, and
// no auth/provider/watch/timer starts unless an approved caller supplies a target.
final petugasBaselinePullConfigurationProvider =
    Provider<PetugasBaselinePullConfiguration?>((ref) => null);

final petugasBaselinePullProvider = Provider<PetugasBaselinePull?>((ref) {
  final config = ref.watch(petugasBaselinePullConfigurationProvider);
  if (config == null) return null;
  return PetugasBaselinePull(
    db: config.database,
    dio: ref.watch(authenticatedDioProvider),
    context: config.context,
    plan: config.plan,
    references: config.references,
    session: () => ref.read(authControllerProvider).session,
  );
});
