import '../core/widgets/master_data_viewport.dart';
import '../core/widgets/sync_page_frame.dart';
import '../core/widgets/transaction_manual_sync_controls.dart';
import '../core/theme/app_colors.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sync_monitor_provider.dart';
import '../providers/auth_provider.dart';

class SyncMonitorDesktopScreen extends ConsumerStatefulWidget {
  const SyncMonitorDesktopScreen({super.key});
  @override
  ConsumerState<SyncMonitorDesktopScreen> createState() => _MonitorState();
}

class _MonitorState extends ConsumerState<SyncMonitorDesktopScreen> {
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
        const TransactionManualSyncControls(),
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
                          'Last attempt',
                          'Last success',
                          'Pending record / operasi',
                          'Error diketahui',
                          'Progress tercatat',
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
                                DataCell(Text(time(r['last_attempt']))),
                                DataCell(Text(time(r['last_success']))),
                                DataCell(
                                  Text(
                                    '${r['pending_records']} / ${r['pending_operations']}',
                                  ),
                                ),
                                DataCell(Text('${r['errors']}')),
                                DataCell(
                                  SizedBox(
                                    width: 300,
                                    child: Text(
                                      '${r['progress']}',
                                      softWrap: true,
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

  String time(Object? value) => value == null
      ? '—'
      : DateTime.parse(value as String).toLocal().toString();
}
