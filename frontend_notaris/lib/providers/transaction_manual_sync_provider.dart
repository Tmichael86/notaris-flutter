import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/transaction_manual_sync_service.dart';
import 'auth_provider.dart';
import 'database_provider.dart';
import 'development_smoke_provider.dart';
import 'sync_log_provider.dart';
import 'sync_monitor_provider.dart';
import 'isolated_transaction_profile_provider.dart';

export 'isolated_transaction_profile_provider.dart';

final isolatedTransactionSyncServiceProvider =
    Provider<TransactionManualSyncService?>((ref) {
      final config = ref.watch(isolatedTransactionSyncConfigurationProvider);
      if (config == null) {
        return null; // Do not resolve/open a normal database here.
      }
      return TransactionManualSyncService(
        db: ref.watch(appDatabaseProvider),
        profile: config.profile,
        http: config.http,
        session: () => ref.read(authControllerProvider).session,
        uiSmoke: () => ref.read(developmentUiSmokeProvider),
        logs: ref.watch(syncLogRepositoryProvider),
      );
    });

typedef TransactionSyncChoice = ({
  String module,
  ManualSyncDirection direction,
});
final isolatedTransactionSyncEligibilityProvider = FutureProvider.autoDispose
    .family<void, TransactionSyncChoice>((ref, choice) async {
      ref.watch(authControllerProvider);
      ref.watch(developmentUiSmokeProvider);
      final service = ref.watch(isolatedTransactionSyncServiceProvider);
      if (service == null) throw const ManualTransactionFailure('scope');
      await service.validateUiContext(
        selectedModule: choice.module,
        direction: choice.direction,
      );
    });

class TransactionSyncRecord {
  const TransactionSyncRecord._(
    this.id,
    this.uuid,
    this.number,
    this.domain,
    this.dirty,
    this.childDirty,
    this.pending,
    this.deleted,
  );
  final int id, childDirty;
  final String uuid, number, domain;
  final bool dirty, deleted;
  final String? pending;
  String get summary =>
      '${domain == 'ppat' ? 'PPAT' : 'Notaris'} • $number • ${deleted
          ? 'tombstone'
          : dirty || childDirty > 0
          ? 'dirty'
          : 'clean'}${pending == null ? '' : ' • $pending'} • child dirty $childDirty';
}

final isolatedTransactionSyncRecordsProvider = FutureProvider.autoDispose
    .family<List<TransactionSyncRecord>, String>((ref, module) async {
      ref.watch(authControllerProvider);
      ref.watch(developmentUiSmokeProvider);
      final service = ref.watch(isolatedTransactionSyncServiceProvider);
      if (service == null) return [];
      await service.validateUiContext(
        selectedModule: module,
        direction: ManualSyncDirection.upload,
      );
      final domain = TransactionManualSyncService.uploadModules[module];
      final rows = await service.db
          .customSelect(
            "SELECT t.id,t.uuid,t.no_akta,t.jenis_transaksi,t.is_sync_dirty,t.deleted_at,p.state AS pending,(SELECT count(*) FROM transaksi_details d WHERE d.transaksi_id=t.id AND d.is_sync_dirty=1)+(SELECT count(*) FROM transaksi_proses d WHERE d.transaksi_id=t.id AND d.is_sync_dirty=1)+(SELECT count(*) FROM transaksi_riwayat_pembayaran d WHERE d.transaksi_id=t.id AND d.is_sync_dirty=1) AS child_dirty FROM transaksis t LEFT JOIN transaction_cloud_pending p ON p.local_uuid=t.uuid WHERE t.jenis_transaksi=? ORDER BY t.id DESC LIMIT 200",
            variables: [Variable(domain!)],
          )
          .get();
      return rows
          .map(
            (r) => TransactionSyncRecord._(
              r.read<int>('id'),
              r.read<String>('uuid'),
              r.read<String>('no_akta'),
              r.read<String>('jenis_transaksi'),
              r.read<int>('is_sync_dirty') == 1,
              r.read<int>('child_dirty'),
              r.readNullable<String>('pending'),
              r.data['deleted_at'] != null,
            ),
          )
          .toList();
    });

String transactionSyncUiMessage(String code) => switch (code) {
  'scope' => 'Profil/target tidak cocok. Gunakan konfigurasi SQLite dan backend disposable yang telah diverifikasi.',
  'forbidden' => 'Izin transaksi atau UI Smoke memblokir sinkronisasi.',
  'unauthorized' => 'Sesi online yang valid diperlukan.',
  'offline' => 'Offline: operasi ditunda; data lokal dipertahankan.',
  'busy' => 'Sinkronisasi profil ini sedang berjalan.',
  'conflict' => '409 / dirty conflict: data lokal dan mutation dipertahankan untuk pemeriksaan.',
  'feed_expired' => '410: feed kedaluwarsa. Recovery eksplisit diperlukan; cursor tidak direset.',
  'validation' => 'Record, referensi atau pilihan operasi belum valid; tidak ada overwrite otomatis.',
  'timeout' => 'Timeout: hasil belum terkonfirmasi. Jangan menganggap upload telah selesai.',
  'server' => 'Layanan gagal; periksa Log sebelum mencoba lagi.',
  _ => 'Operasi ditolak atau gagal; periksa Log Sinkronisasi.',
};

class TransactionSyncUiState {
  const TransactionSyncUiState({
    this.busy = false,
    this.message = '',
    this.errorCode,
    this.operationLabel = '',
  });
  final bool busy;
  final String message;
  final String? errorCode;
  final String operationLabel;
}

final isolatedTransactionSyncControllerProvider =
    StateNotifierProvider<TransactionSyncUiController, TransactionSyncUiState>(
      (ref) => TransactionSyncUiController(ref),
    );

class TransactionSyncUiController
    extends StateNotifier<TransactionSyncUiState> {
  TransactionSyncUiController(this.ref) : super(const TransactionSyncUiState());
  final Ref ref;
  Future<void> execute({
    required String module,
    required ManualSyncDirection direction,
    TransactionSyncRecord? record,
  }) async {
    if (state.busy) return;
    final label = direction == ManualSyncDirection.download
        ? 'Download feed Transaksi gabungan'
        : 'Upload ${record?.domain == 'ppat' ? 'PPAT' : 'Notaris'} ${record?.number ?? ''}';
    state = TransactionSyncUiState(
      operationLabel: label,
      busy: true,
      message: 'Sinkronisasi sedang berjalan…',
    );
    try {
      final service = ref.read(isolatedTransactionSyncServiceProvider);
      if (service == null) throw const ManualTransactionFailure('scope');
      if (direction == ManualSyncDirection.upload &&
          (record == null ||
              TransactionManualSyncService.uploadModules[module] !=
                  record.domain)) {
        throw const ManualTransactionFailure('validation');
      }
      // The service re-reads id/domain/UUID and all permissions after confirmation.
      final result = await service.run(
        selectedModule: module,
        direction: direction,
        transactionId: record?.id,
        expectedLocalUuid: record?.uuid,
      );
      if (mounted) {
        state = TransactionSyncUiState(
          operationLabel: label,
          message: direction == ManualSyncDirection.upload
              ? result.count == 0
                    ? 'Tidak ada mutation baru; record sudah diakui.'
                    : 'Upload terkonfirmasi: ${result.count} record. Publication menunggu konfirmasi download.'
              : '${result.more ? 'Download tertunda pada batas halaman' : 'Download selesai'}: ${result.count} event, cursor ${result.cursor}.',
        );
      }
    } catch (e) {
      final code = e is ManualTransactionFailure ? e.code : 'unknown';
      if (mounted) {
        state = TransactionSyncUiState(
          operationLabel: label,
          errorCode: code,
          message: transactionSyncUiMessage(code),
        );
      }
    } finally {
      if (mounted) {
        ref.invalidate(syncMonitorProvider);
        ref.invalidate(syncLogsProvider);
        ref.invalidate(isolatedTransactionSyncRecordsProvider);
        ref.invalidate(isolatedTransactionSyncEligibilityProvider);
      }
    }
  }
}
