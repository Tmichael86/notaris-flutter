import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../../providers/development_smoke_provider.dart';
import '../../providers/transaction_manual_sync_provider.dart';
import '../../services/transaction_manual_sync_service.dart';

/// Presentation-only exclusions; the existing service remains authoritative.
String? manualUploadDisabledReason(TransactionSyncRecord record) {
  if (record.pending == 'acked') {
    return 'ACK tersimpan; tunggu verifikasi publication melalui Download.';
  }
  if (record.deleted) {
    return 'Record terhapus tidak dapat dipilih melalui modal ini.';
  }
  if (!record.dirty && record.childDirty == 0 && record.pending == null) {
    return 'Data bersih; tidak ada perubahan lokal untuk diupload.';
  }
  return null;
}

class TransactionManualSyncControls extends ConsumerStatefulWidget {
  const TransactionManualSyncControls({super.key, this.onClose});
  final VoidCallback? onClose;
  @override
  ConsumerState<TransactionManualSyncControls> createState() =>
      _ControlsState();
}

class _ControlsState extends ConsumerState<TransactionManualSyncControls> {
  String module = 'transaksi_notaris', direction = 'push', query = '';
  TransactionSyncRecord? selected, confirmation;
  bool confirming = false, closing = false;
  final _dialogFocus = FocusNode();
  @override
  void dispose() {
    _dialogFocus.dispose();
    super.dispose();
  }

  void dismiss() {
    if (ref.read(isolatedTransactionSyncControllerProvider).busy) return;
    if (confirming) {
      setState(() => confirming = false);
    } else {
      close();
    }
  }

  void close() {
    if (closing ||
        ref.read(isolatedTransactionSyncControllerProvider).busy ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    closing = true;
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> execute(TransactionSyncRecord? record) async {
    if (ref.read(isolatedTransactionSyncControllerProvider).busy) return;
    try {
      await ref
          .read(isolatedTransactionSyncControllerProvider.notifier)
          .execute(
            module: module,
            direction: direction == 'push'
                ? ManualSyncDirection.upload
                : ManualSyncDirection.download,
            record: record,
          );
    } finally {
      if (mounted) setState(() => confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(isolatedTransactionSyncConfigurationProvider);
    final smoke = ref.watch(developmentUiSmokeProvider);
    final outcome = ref.watch(isolatedTransactionSyncControllerProvider);
    final upload = direction == 'push';
    final choice = (
      module: module,
      direction: upload
          ? ManualSyncDirection.upload
          : ManualSyncDirection.download,
    );
    final eligibility = config != null && !smoke
        ? ref.watch(isolatedTransactionSyncEligibilityProvider(choice))
        : null;
    final records = config != null && !smoke && upload
        ? ref.watch(isolatedTransactionSyncRecordsProvider(module))
        : null;
    final rows = records?.asData?.value ?? <TransactionSyncRecord>[];
    final current = rows
        .where((r) => r.id == selected?.id && r.uuid == selected?.uuid)
        .firstOrNull;
    final locked = confirming || outcome.busy;
    final confirmingAtBuild = confirming;
    final ready =
        eligibility?.asData != null &&
        (!upload ||
            current != null && manualUploadDisabledReason(current) == null);
    final rejection = eligibility?.hasError == true
        ? transactionSyncUiMessage(
            eligibility!.error is ManualTransactionFailure
                ? (eligibility.error as ManualTransactionFailure).code
                : 'unknown',
          )
        : null;
    final visible = rows
        .where(
          (r) => '${r.number} ${r.uuid} ${r.summary}'.toLowerCase().contains(
            query.toLowerCase().trim(),
          ),
        )
        .toList();
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme
            .copyWith(primary: AppColors.primaryDark),
      ),
      child: PopScope(
        canPop: !outcome.busy,
        child: CallbackShortcuts(
          bindings: {const SingleActivator(LogicalKeyboardKey.escape): dismiss},
          child: Focus(
            focusNode: _dialogFocus,
            autofocus: true,
            child: Dialog(
              key: const Key('manual-sync-dialog'),
              insetPadding: const EdgeInsets.all(24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: AppColors.card,
              child: SizedBox(
                key: const Key('manual-sync-surface'),
                width: 500,
                height: math.min(760, MediaQuery.sizeOf(context).height - 48),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primaryDark.withValues(
                                alpha: .08,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.sync,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sinkronisasi Data',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Pilih arah dan data yang ingin disinkronkan',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            key: const Key('close-manual-sync'),
                            tooltip: 'Tutup',
                            onPressed: outcome.busy ? null : close,
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (outcome.message.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    '${outcome.operationLabel}: ${outcome.message}',
                                    key: const Key('manual-sync-feedback'),
                                    style: TextStyle(
                                      color: outcome.errorCode == null
                                          ? AppColors.textPrimary
                                          : AppColors.error,
                                    ),
                                  ),
                                ),
                              ),
                            Visibility(
                              visible: !confirming,
                              maintainState: true,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SegmentedButton<String>(
                                    key: const Key('manual-sync-direction'),
                                    showSelectedIcon: false,
                                    expandedInsets: EdgeInsets.zero,
                                    style: const ButtonStyle(
                                      minimumSize: WidgetStatePropertyAll(
                                        Size(0, 48),
                                      ),
                                    ),
                                    segments: const [
                                      ButtonSegment(
                                        value: 'push',
                                        label: Text('Upload'),
                                        icon: Icon(Icons.cloud_upload_outlined),
                                      ),
                                      ButtonSegment(
                                        value: 'pull',
                                        label: Text('Download'),
                                        icon: Icon(
                                          Icons.cloud_download_outlined,
                                        ),
                                      ),
                                    ],
                                    selected: {direction},
                                    onSelectionChanged: locked
                                        ? null
                                        : (v) => setState(() {
                                            direction = v.single;
                                            module = direction == 'pull'
                                                ? 'transaksi'
                                                : 'transaksi_notaris';
                                            selected = null;
                                            query = '';
                                          }),
                                  ),
                                  const SizedBox(height: 20),
                                  if (upload) ...[
                                    const Text(
                                      'Jenis transaksi',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SegmentedButton<String>(
                                      key: const Key('manual-sync-module'),
                                      segments: const [
                                        ButtonSegment(
                                          value: 'transaksi_notaris',
                                          label: Text('Notaris'),
                                        ),
                                        ButtonSegment(
                                          value: 'transaksi_ppat',
                                          label: Text('PPAT'),
                                        ),
                                      ],
                                      selected: {module},
                                      onSelectionChanged: locked
                                          ? null
                                          : (v) => setState(() {
                                              module = v.single;
                                              selected = null;
                                              query = '';
                                            }),
                                    ),
                                    const SizedBox(height: 16),
                                    TextField(
                                      key: ValueKey(
                                        'manual-sync-search-$module',
                                      ),
                                      enabled: !locked,
                                      onChanged: (v) =>
                                          setState(() => query = v),
                                      decoration: const InputDecoration(
                                        hintText: 'Cari nomor atau identitas transaksi',
                                        prefixIcon: Icon(Icons.search),
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    if (config == null || smoke)
                                      const Text(
                                        'Pemilihan record dinonaktifkan pada profil ini.',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                        ),
                                      )
                                    else
                                      records!.when(
                                        loading: () => const Center(
                                          child: Padding(
                                            padding: EdgeInsets.all(20),
                                            child: CircularProgressIndicator(),
                                          ),
                                        ),
                                        error: (e, _) => Text(
                                          transactionSyncUiMessage(
                                            e is ManualTransactionFailure
                                                ? e.code
                                                : 'unknown',
                                          ),
                                        ),
                                        data: (data) {
                                          if (data.isEmpty) {
                                            return const Text(
                                              'Belum ada transaksi lokal untuk jenis ini. Tidak ada upload yang dijalankan.',
                                            );
                                          }
                                          if (visible.isEmpty) {
                                            return const Text(
                                              'Tidak ada transaksi sesuai pencarian.',
                                            );
                                          }
                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              Text(
                                                '${visible.length} dari ${data.length} record dimuat',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              RadioGroup<int>(
                                                groupValue: current?.id,
                                                onChanged: (id) {
                                                  if (locked ||
                                                      eligibility?.asData ==
                                                          null) {
                                                    return;
                                                  }
                                                  final r = rows.singleWhere(
                                                    (r) => r.id == id,
                                                  );
                                                  if (manualUploadDisabledReason(
                                                        r,
                                                      ) ==
                                                      null) {
                                                    setState(
                                                      () => selected = r,
                                                    );
                                                  }
                                                },
                                                child: Column(
                                                  key: ValueKey(
                                                    'manual-sync-record-$module',
                                                  ),
                                                  children: [
                                                    for (final r in visible)
                                                      Container(
                                                        margin:
                                                            const EdgeInsets.only(
                                                              bottom: 8,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          border: Border.all(
                                                            color:
                                                                current?.id ==
                                                                    r.id
                                                                ? AppColors
                                                                      .primary
                                                                : AppColors
                                                                      .border,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                        ),
                                                        child: RadioListTile<int>(
                                                          key: ValueKey(
                                                            'manual-sync-choice-${r.id}',
                                                          ),
                                                          value: r.id,
                                                          enabled:
                                                              !locked &&
                                                              eligibility
                                                                      ?.asData !=
                                                                  null &&
                                                              manualUploadDisabledReason(
                                                                    r,
                                                                  ) ==
                                                                  null,
                                                          contentPadding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 4,
                                                              ),
                                                          title: Text(
                                                            r.number,
                                                            maxLines: 2,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style:
                                                                const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                          ),
                                                          subtitle: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                r.summary,
                                                                style:
                                                                    const TextStyle(
                                                                      fontSize:
                                                                          11,
                                                                    ),
                                                              ),
                                                              if (manualUploadDisabledReason(
                                                                    r,
                                                                  ) !=
                                                                  null)
                                                                Text(
                                                                  manualUploadDisabledReason(
                                                                    r,
                                                                  )!,
                                                                  style: const TextStyle(
                                                                    fontSize:
                                                                        11,
                                                                    color: AppColors
                                                                        .warning,
                                                                  ),
                                                                ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                  ] else
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: AppColors.background,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.cloud_download_outlined,
                                            color: AppColors.primaryDark,
                                          ),
                                          SizedBox(height: 12),
                                          Text(
                                            'Feed gabungan Notaris + PPAT',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'Download menerima Transaksi Notaris dan PPAT dari feed yang sama; satu cursor bersama. Tidak ada upload record lokal atau pemilihan per domain.',
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (current != null && !confirming)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: SelectableText(
                                  'UUID: ${current.uuid} • Local PK: ${current.id}',
                                  key: const Key('manual-sync-record-identity'),
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            const SizedBox(height: 16),
                            Text(
                              smoke
                                  ? 'UI Smoke: seluruh sinkronisasi manual dinonaktifkan.'
                                  : config == null
                                  ? 'Profil normal: eksekusi manual tetap dinonaktifkan.'
                                  : upload
                                  ? 'Referensi, identitas dan izin diperiksa ulang saat eksekusi. ACK belum membuktikan publication.'
                                  : 'Halaman feed dan cursor diterapkan atomik oleh service existing.',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (eligibility?.isLoading == true)
                              const Text(
                                'Memverifikasi profil, scope dan permission…',
                              ),
                            if (rejection != null)
                              Text(
                                rejection,
                                key: const Key('manual-sync-guard-reason'),
                                style: const TextStyle(color: AppColors.error),
                              ),
                            if (confirming && confirmation != null)
                              Container(
                                margin: const EdgeInsets.only(top: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryDark.withValues(
                                    alpha: .05,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Konfirmasi upload ${confirmation!.domain == 'ppat' ? 'PPAT' : 'Notaris'}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(confirmation!.summary),
                                    SelectableText(
                                      'UUID: ${confirmation!.uuid} • Local PK: ${confirmation!.id}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Hanya record ini yang dikirim. ACK belum membuktikan publication.',
                                    ),
                                    TextButton(
                                      onPressed: outcome.busy
                                          ? null
                                          : () => setState(
                                              () => confirming = false,
                                            ),
                                      child: const Text('Batal'),
                                    ),
                                  ],
                                ),
                              ),
                            if (outcome.busy)
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          key: const Key('manual-sync-execute'),
                          onPressed:
                              outcome.busy ||
                                  smoke ||
                                  config == null ||
                                  (!confirming && !ready)
                              ? null
                              : () {
                                  if (ref
                                      .read(
                                        isolatedTransactionSyncControllerProvider,
                                      )
                                      .busy) {
                                    return;
                                  }
                                  if (confirming != confirmingAtBuild) return;
                                  if (confirming) {
                                    execute(confirmation);
                                  } else if (upload) {
                                    setState(() {
                                      confirmation = current;
                                      confirming = true;
                                    });
                                    _dialogFocus.requestFocus();
                                  } else {
                                    execute(null);
                                  }
                                },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: outcome.busy
                                ? const Text('Menyinkronkan…')
                                : confirming
                                ? const Text(
                                    'Konfirmasi upload',
                                    key: Key('confirm-transaction-upload'),
                                  )
                                : Text(
                                    upload ? 'Mulai Upload' : 'Mulai Download',
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
