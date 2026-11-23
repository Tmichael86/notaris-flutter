import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/petugas_sync_api.dart';

const petugasManualBuildEnabled =
    kDebugMode && bool.fromEnvironment('PETUGAS_MANUAL_SYNC');
final petugasManualEnabledProvider = Provider<bool>(
  (ref) => petugasManualBuildEnabled,
);
final petugasManualReadyProvider = StateProvider<bool>((ref) => false);
final petugasManualActionProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    throw const PetugasSyncFailure(
      PetugasSyncFailureKind.blocked,
      'isolated harness not configured',
    );
  },
);
final petugasManualPrepareProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    throw const PetugasSyncFailure(
      PetugasSyncFailureKind.blocked,
      'isolated harness not configured',
    );
  },
);

enum PetugasManualStatus { idle, syncing, success, pending, blocked, failed }

class PetugasManualState {
  const PetugasManualState(this.status, this.message);
  final PetugasManualStatus status;
  final String message;
}

final petugasManualControllerProvider =
    StateNotifierProvider<PetugasManualController, PetugasManualState>(
      (ref) => PetugasManualController(ref),
    );

class PetugasManualController extends StateNotifier<PetugasManualState> {
  PetugasManualController(this.ref)
    : super(const PetugasManualState(PetugasManualStatus.idle, 'idle'));
  final Ref ref;
  Future<void> run({bool prepare = false}) async {
    if (state.status == PetugasManualStatus.syncing) {
      return;
    }
    if (!ref.read(petugasManualEnabledProvider) ||
        (!prepare && !ref.read(petugasManualReadyProvider))) {
      state = const PetugasManualState(
        PetugasManualStatus.blocked,
        'Testing backend / mapping belum dikonfirmasi',
      );
      return;
    }
    state = const PetugasManualState(PetugasManualStatus.syncing, 'syncing');
    try {
      await ref.read(
        prepare ? petugasManualPrepareProvider : petugasManualActionProvider,
      )();
      if (prepare) {
        ref.read(petugasManualReadyProvider.notifier).state = true;
      }
      state = PetugasManualState(
        PetugasManualStatus.success,
        prepare ? 'Fixture & mapping dikonfirmasi' : 'success',
      );
    } on PetugasSyncFailure catch (e) {
      final pending = {
        PetugasSyncFailureKind.timeout,
        PetugasSyncFailureKind.network,
      }.contains(e.kind);
      final message = switch (e.kind) {
        PetugasSyncFailureKind.blockedReference =>
          'blocked_reference: verifikasi referensi server',
        PetugasSyncFailureKind.conflict =>
          '409 conflict: keputusan operator diperlukan',
        PetugasSyncFailureKind.expired =>
          '410 full_resync_required: data lokal dipertahankan',
        PetugasSyncFailureKind.blocked => 'blocked: identity ambiguous/development, pending conflict, atau recovery diperlukan',
        PetugasSyncFailureKind.timeout =>
          'pending: timeout; data lokal dipertahankan',
        PetugasSyncFailureKind.network =>
          'pending: offline; retry mempertahankan mutation',
        PetugasSyncFailureKind.unauthorized =>
          'blocked: sesi testing kedaluwarsa',
        PetugasSyncFailureKind.forbidden =>
          'blocked: permission Petugas ditolak',
        _ => 'failed: backend testing menolak request',
      };
      state = PetugasManualState(
        pending
            ? PetugasManualStatus.pending
            : ({
                    PetugasSyncFailureKind.server,
                    PetugasSyncFailureKind.invalid,
                  }.contains(e.kind)
                  ? PetugasManualStatus.failed
                  : PetugasManualStatus.blocked),
        message,
      );
    } catch (_) {
      state = const PetugasManualState(
        PetugasManualStatus.failed,
        'failed: periksa konfigurasi testing',
      );
    }
  }
}
