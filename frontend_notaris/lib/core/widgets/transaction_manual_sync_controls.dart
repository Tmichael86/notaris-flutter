import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/development_smoke_provider.dart';
import '../../providers/sync_monitor_provider.dart';
import '../../providers/transaction_manual_sync_provider.dart';
import '../../repositories/sync_monitor_repository.dart';
import '../../services/transaction_manual_sync_service.dart';

/// Same controls in the existing Monitoring card. Normal profiles have no
/// isolated configuration and never resolve an execution service/database.
class TransactionManualSyncControls extends ConsumerStatefulWidget {
  const TransactionManualSyncControls({super.key});
  @override
  ConsumerState<TransactionManualSyncControls> createState() =>
      _ControlsState();
}

class _ControlsState extends ConsumerState<TransactionManualSyncControls> {
  String module = 'kategori', direction = 'push';
  TransactionSyncRecord? selected;
  bool confirming = false;
  Future<void> execute(TransactionSyncRecord? record) async {
    if (confirming ||
        ref.read(isolatedTransactionSyncControllerProvider).busy) {
      return;
    }
    setState(() => confirming = true);
    try {
      if (direction == 'push') {
        if (record == null) return;
        final accepted = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'Konfirmasi upload ${record.domain == 'ppat' ? 'PPAT' : 'Notaris'}',
            ),
            content: Text(
              '${record.summary}\nUUID: ${record.uuid}\nLocal PK: ${record.id}\n\nHanya record ini yang dikirim. Identitas dan izin diperiksa ulang. ACK belum membuktikan publication.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              FilledButton(
                key: const Key('confirm-transaction-upload'),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Konfirmasi upload'),
              ),
            ],
          ),
        );
        if (accepted != true || !mounted) return;
      }
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
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
            DropdownButton<String>(
              key: const Key('manual-sync-direction'),
              value: direction,
              items: [
                if (!download)
                  const DropdownMenuItem(value: 'push', child: Text('Upload')),
                if (!upload)
                  const DropdownMenuItem(
                    value: 'pull',
                    child: Text('Download'),
                  ),
              ],
              onChanged: locked
                  ? null
                  : (value) => setState(() => direction = value!),
            ),
            FilledButton(
              key: const Key('manual-sync-execute'),
              onPressed: !locked && ready && !smoke && config != null
                  ? () => execute(current)
                  : null,
              child: Text(outcome.busy ? 'Sinkronisasi…' : 'Jalankan seleksi'),
            ),
            IconButton(
              tooltip: 'Refresh snapshot lokal',
              onPressed: locked
                  ? null
                  : () {
                      ref.invalidate(isolatedTransactionSyncRecordsProvider);
                      ref.invalidate(
                        isolatedTransactionSyncEligibilityProvider,
                      );
                      ref.invalidate(syncMonitorProvider);
                    },
              icon: const Icon(Icons.refresh),
            ),
          ],
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
              ? 'Profil normal: eksekusi manual tetap dinonaktifkan. ${selectiveSyncReason(module, direction)}'
              : selectiveSyncReason(module, direction),
        ),
        if (download)
          const Text(
            'Download menerima Transaksi Notaris dan PPAT dari feed yang sama; satu cursor bersama.',
          ),
        if (eligibility?.isLoading == true)
          const Text('Memverifikasi profil, scope dan permission…'),
        if (rejection != null)
          Text(rejection, key: const Key('manual-sync-guard-reason')),
        if (outcome.message.isNotEmpty)
          Semantics(
            liveRegion: true,
            child: Text(
              '${outcome.operationLabel}: ${outcome.message}',
              key: const Key('manual-sync-feedback'),
            ),
          ),
      ],
    );
  }
}
