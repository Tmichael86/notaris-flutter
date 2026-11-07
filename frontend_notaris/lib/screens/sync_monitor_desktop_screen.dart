import 'package:flutter/services.dart';

import '../core/widgets/master_data_viewport.dart';
import '../core/widgets/sync_page_frame.dart';
import '../core/widgets/transaction_manual_sync_controls.dart';
import '../core/theme/app_colors.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sync_monitor_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/transaction_manual_sync_provider.dart';
import '../core/widgets/sync_presentation.dart';

class SyncMonitorDesktopScreen extends ConsumerStatefulWidget {
  const SyncMonitorDesktopScreen({super.key});
  @override
  ConsumerState<SyncMonitorDesktopScreen> createState() => _MonitorState();
}

class _MonitorState extends ConsumerState<SyncMonitorDesktopScreen> {
  bool modalOpen = false;
  Future<void> manual() async {
    if (modalOpen || ref.read(isolatedTransactionSyncControllerProvider).busy) {
      return;
    }
    setState(() => modalOpen = true);
    bool closing = false;
    void close(BuildContext c) {
      if (closing ||
          ref.read(isolatedTransactionSyncControllerProvider).busy ||
          ModalRoute.of(c)?.isCurrent != true) {
        return;
      }
      closing = true;
      Navigator.pop(c);
    }

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (c) => Consumer(
          builder: (context, ref, _) => PopScope(
            canPop: !ref.watch(isolatedTransactionSyncControllerProvider).busy,
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape): () {
                  if (!ref
                      .read(isolatedTransactionSyncControllerProvider)
                      .busy) {
                    close(c);
                  }
                },
              },
              child: Actions(
                actions: {
                  DismissIntent: CallbackAction<DismissIntent>(
                    onInvoke: (_) {
                      if (!ref
                          .read(isolatedTransactionSyncControllerProvider)
                          .busy) {
                        close(c);
                      }
                      return null;
                    },
                  ),
                },
                child: Focus(
                  autofocus: true,
                  child: AlertDialog(
                    title: const Text('Sinkronisasi Manual'),
                    content: SizedBox(
                      width: 740,
                      child: SingleChildScrollView(
                        child: const TransactionManualSyncControls(),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed:
                            ref
                                .watch(
                                  isolatedTransactionSyncControllerProvider,
                                )
                                .busy
                            ? null
                            : () => close(c),
                        child: const Text('Tutup'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => modalOpen = false);
        ref.invalidate(syncMonitorProvider);
      }
    }
  }

  final _horizontal = ScrollController();
  final _vertical = ScrollController();
  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(syncMonitorProvider);
    final offline =
        ref.watch(authControllerProvider).session?.isOffline ?? true;
    return SyncPageFrame(
      title: 'Monitoring Sinkronisasi',
      children: [
        const Text(
          'Snapshot lokal, bukan pemeriksaan kesehatan server. Hijau hanya untuk kondisi relevan yang diketahui.',
        ),
        if (offline)
          const Text(
            'Offline / sesi online belum tersedia. Status server belum diperiksa.',
          ),
        Wrap(
          spacing: 12,
          children: [
            FilledButton.icon(
              key: const Key('open-manual-sync'),
              onPressed: modalOpen ? null : manual,
              icon: const Icon(Icons.sync),
              label: const Text('Sinkronisasi Manual'),
            ),
            IconButton(
              tooltip: 'Refresh snapshot lokal',
              onPressed: () => ref.invalidate(syncMonitorProvider),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: data.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Snapshot tidak dapat dimuat. Tidak ada sinkronisasi dijalankan.',
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(syncMonitorProvider),
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
            ),
            data: (rows) => rows.isEmpty
                ? const Center(
                    child: Text('Belum ada modul untuk ditampilkan.'),
                  )
                : MasterDataTableViewport(
                    horizontalController: _horizontal,
                    verticalController: _vertical,
                    child: DataTable(
                      columnSpacing: 28,
                      dataRowMinHeight: 56,
                      dataRowMaxHeight: double.infinity,
                      columns: [
                        for (final title in [
                          'Modul',
                          'Status',
                          'Pending',
                          'Terakhir Aktivitas',
                          'Detail',
                        ])
                          DataColumn(label: Text(title)),
                      ],
                      rows: rows
                          .map(
                            (r) => DataRow(
                              cells: [
                                DataCell(Text('${r['label']}')),
                                DataCell(
                                  SyncStatusBadge(
                                    label: switch (r['color']) {
                                      'green' => 'Berhasil (diketahui)',
                                      'yellow' => 'Perhatian',
                                      'red' => 'Perlu penanganan',
                                      _ => 'Belum diketahui',
                                    },
                                    color: switch (r['color']) {
                                      'green' => AppColors.success,
                                      'yellow' => AppColors.warning,
                                      'red' => AppColors.error,
                                      _ => AppColors.textSecondary,
                                    },
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    '${r['pending_records']} record / ${r['pending_operations']} operasi',
                                  ),
                                ),
                                DataCell(
                                  Text(syncLocalTime(r['last_attempt'])),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 300,
                                    child: ExpansionTile(
                                      key: ValueKey(
                                        'monitor-detail-${r['module']}',
                                      ),
                                      tilePadding: EdgeInsets.zero,
                                      title: const Text('Lihat detail'),
                                      children: [
                                        Text(
                                          '${r['progress']}\nError diketahui: ${r['errors']}\nTerakhir berhasil: ${syncLocalTime(r['last_success'])}\n${reason(r)}',
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  String reason(Map<String, dynamic> row) => switch (row['module']) {
    'transaksi_notaris' || 'transaksi_ppat' => 'Upload satu record melalui Sinkronisasi Manual; profil dan izin tetap diverifikasi.',
    'transaksi' => 'Download feed gabungan Notaris + PPAT melalui Sinkronisasi Manual, dengan satu cursor.',
    _ => '${row['reason'] ?? '—'}',
  };
}
