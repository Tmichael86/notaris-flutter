import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/development_smoke_provider.dart';
import '../../providers/sync_monitor_provider.dart';
import '../../providers/transaction_manual_sync_provider.dart';
import '../../repositories/sync_monitor_repository.dart';
import '../../services/transaction_manual_sync_service.dart';

/// Manual controls hosted only inside the Monitoring desktop modal. Normal profiles have no
/// isolated configuration and never resolve an execution service/database.
class TransactionManualSyncControls extends ConsumerStatefulWidget {
  const TransactionManualSyncControls({super.key});
  @override
  ConsumerState<TransactionManualSyncControls> createState() =>
      _ControlsState();
}

class _ControlsState extends ConsumerState<TransactionManualSyncControls> {
  String module = 'transaksi_notaris', direction = 'push';
  TransactionSyncRecord? selected;
  bool confirming = false;
  TransactionSyncRecord? confirmation;
  Future<void> execute(TransactionSyncRecord? record) async {
    if (ref.read(isolatedTransactionSyncControllerProvider).busy) {
      return;
    }
    // Confirmation is rendered inside the same desktop modal.

    try {
      if (!mounted) return;
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
    final upload = TransactionManualSyncService.uploadModules.containsKey(
      module,
    );
    final download = module == TransactionManualSyncService.feedModule;
    final supported =
        (upload && direction == 'push') || (download && direction == 'pull');
    final locked = confirming || outcome.busy;
    final choice = (
      module: module,
      direction: direction == 'push'
          ? ManualSyncDirection.upload
          : ManualSyncDirection.download,
    );
    final eligibility = config != null && !smoke && supported
        ? ref.watch(isolatedTransactionSyncEligibilityProvider(choice))
        : null;
    final records = config != null && !smoke && upload
        ? ref.watch(isolatedTransactionSyncRecordsProvider(module))
        : null;
    final rows = records?.asData?.value ?? <TransactionSyncRecord>[];
    final matches = rows
        .where((r) => r.id == selected?.id && r.uuid == selected?.uuid)
        .toList();
    final current = matches.isEmpty ? null : matches.single;
    final ready = eligibility?.asData != null && (!upload || current != null);
    String? rejection;
    if (eligibility?.hasError == true) {
      final e = eligibility!.error;
      rejection = transactionSyncUiMessage(
        e is ManualTransactionFailure ? e.code : 'unknown',
      );
    }
    return PopScope(
      canPop: !outcome.busy,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (outcome.busy) return;
            if (confirming) {
              setState(() => confirming = false);
            } else {
              if (ModalRoute.of(context)?.isCurrent == true) {
                Navigator.pop(context);
              }
            }
          },
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (current != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(current.summary),
              ),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<String>(
                  key: const Key('manual-sync-module'),
                  value: module,
                  items: [
                    for (final e in syncModules.entries)
                      DropdownMenuItem(
                        value: e.key,
                        enabled: direction == 'push'
                            ? TransactionManualSyncService.uploadModules
                                  .containsKey(e.key)
                            : e.key == 'transaksi',
                        child: Text(e.value),
                      ),
                  ],
                  onChanged: locked
                      ? null
                      : (value) => setState(() {
                          module = value!;
                          selected = null;
                          direction = module == 'transaksi'
                              ? 'pull'
                              : TransactionManualSyncService.uploadModules
                                    .containsKey(module)
                              ? 'push'
                              : direction;
                        }),
                ),
                SegmentedButton<String>(
                  key: const Key('manual-sync-direction'),
                  segments: const [
                    ButtonSegment(
                      value: 'push',
                      label: Text('Upload'),
                      icon: Icon(Icons.upload),
                    ),
                    ButtonSegment(
                      value: 'pull',
                      label: Text('Download'),
                      icon: Icon(Icons.download),
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
                        }),
                ),
                FilledButton(
                  key: const Key('manual-sync-execute'),
                  onPressed: !locked && ready && !smoke && config != null
                      ? () {
                          if (upload) {
                            setState(() {
                              confirming = true;
                              confirmation = current;
                            });
                          } else {
                            execute(null);
                          }
                        }
                      : null,
                  child: Text(
                    outcome.busy ? 'Sinkronisasi…' : 'Jalankan seleksi',
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh snapshot lokal',
                  onPressed: locked
                      ? null
                      : () {
                          ref.invalidate(
                            isolatedTransactionSyncRecordsProvider,
                          );
                          ref.invalidate(
                            isolatedTransactionSyncEligibilityProvider,
                          );
                          ref.invalidate(syncMonitorProvider);
                        },
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (upload && (config == null || smoke))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: DropdownButtonFormField<int>(
                  key: Key('manual-sync-record-disabled'),
                  items: [],
                  onChanged: null,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Transaksi lokal terpilih',
                    border: OutlineInputBorder(),
                  ),
                  hint: Text('Pemilihan record dinonaktifkan pada profil ini'),
                ),
              ),
            if (upload && config != null && !smoke)
              records!.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(8),
                  child: LinearProgressIndicator(),
                ),
                error: (e, _) => Text(
                  transactionSyncUiMessage(
                    e is ManualTransactionFailure ? e.code : 'unknown',
                  ),
                ),
                data: (data) => data.isEmpty
                    ? const Text(
                        'Belum ada transaksi lokal untuk jenis ini. Tidak ada upload yang dijalankan.',
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: DropdownButtonFormField<int>(
                          key: ValueKey('manual-sync-record-$module'),
                          initialValue: current?.id,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Transaksi lokal terpilih',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            for (final r in data)
                              DropdownMenuItem(
                                value: r.id,
                                child: Text(
                                  r.summary,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: locked
                              ? null
                              : (id) => setState(
                                  () => selected = data.singleWhere(
                                    (r) => r.id == id,
                                  ),
                                ),
                        ),
                      ),
              ),
            if (current != null)
              SelectableText(
                'UUID: ${current.uuid} • Local PK: ${current.id}',
                key: const Key('manual-sync-record-identity'),
              ),
            Text(
              smoke
                  ? 'UI Smoke: seluruh sinkronisasi manual dinonaktifkan.'
                  : config == null
                  ? 'Profil normal: eksekusi manual tetap dinonaktifkan.'
                  : upload
                  ? 'Upload satu record terpilih. ACK belum membuktikan publication.'
                  : 'Download feed gabungan, tanpa upload record lokal.',
            ),
            if (download)
              const Text(
                'Download menerima Transaksi Notaris dan PPAT dari feed yang sama; satu cursor bersama.',
              ),
            if (eligibility?.isLoading == true)
              const Text('Memverifikasi profil, scope dan permission…'),
            if (rejection != null)
              Text(rejection, key: const Key('manual-sync-guard-reason')),
            if (confirming && confirmation != null) ...[
              const Divider(),
              Text(
                'Konfirmasi upload ${confirmation!.domain == 'ppat' ? 'PPAT' : 'Notaris'}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                '${confirmation!.summary}\nHanya record ini yang dikirim. Identitas dan izin diperiksa ulang. ACK belum membuktikan publication.',
              ),
              Wrap(
                spacing: 12,
                children: [
                  TextButton(
                    onPressed: outcome.busy
                        ? null
                        : () => setState(() => confirming = false),
                    child: const Text('Batal'),
                  ),
                  FilledButton(
                    key: const Key('confirm-transaction-upload'),
                    onPressed: outcome.busy
                        ? null
                        : () => execute(confirmation),
                    child: const Text('Konfirmasi upload'),
                  ),
                ],
              ),
            ],
            if (outcome.busy) const LinearProgressIndicator(),
            if (outcome.message.isNotEmpty)
              Semantics(
                liveRegion: true,
                child: Text(
                  '${outcome.operationLabel}: ${outcome.message}',
                  key: const Key('manual-sync-feedback'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
