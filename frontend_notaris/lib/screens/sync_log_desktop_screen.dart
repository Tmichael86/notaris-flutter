import '../core/widgets/master_data_viewport.dart';
import '../core/widgets/sync_page_frame.dart';
import '../core/theme/app_colors.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sync_log_provider.dart';

class SyncLogDesktopScreen extends ConsumerStatefulWidget {
  const SyncLogDesktopScreen({super.key});
  @override
  ConsumerState<SyncLogDesktopScreen> createState() => _SyncLogState();
}

class _SyncLogState extends ConsumerState<SyncLogDesktopScreen> {
  String? module, status;
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
    final filter = (module: module, status: status);
    final logs = ref.watch(syncLogsProvider(filter));
    return SyncPageFrame(
      title: 'Log Sinkronisasi',
      children: [
        const Text(
          'Histori lokal • terbaru dahulu • maksimal 500 entri sesuai filter',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DropdownButton<String>(
              value: module ?? '',
              items: [
                for (final v in [
                  '',
                  'kategori',
                  'pengeluaran',
                  'pemohon',
                  'transaksi_notaris',
                  'transaksi_ppat',
                  'transaksi',
                ])
                  DropdownMenuItem(
                    value: v,
                    child: Text(v.isEmpty ? 'Semua modul' : v),
                  ),
              ],
              onChanged: (v) => setState(() => module = v == '' ? null : v),
            ),
            DropdownButton<String>(
              value: status ?? '',
              items: [
                for (final v in ['', 'success', 'failed', 'pending'])
                  DropdownMenuItem(
                    value: v,
                    child: Text(v.isEmpty ? 'Semua status' : label(v)),
                  ),
              ],
              onChanged: (v) => setState(() => status = v == '' ? null : v),
            ),
            IconButton(
              tooltip: 'Muat ulang histori lokal',
              onPressed: () => ref.invalidate(syncLogsProvider(filter)),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: logs.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Histori tidak dapat dimuat. Data tidak dihapus.'),
                  TextButton(
                    onPressed: () => ref.invalidate(syncLogsProvider(filter)),
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
            ),
            data: (rows) => rows.isEmpty
                ? const Center(
                    child: Text(
                      'Belum ada aktivitas sinkronisasi untuk filter ini.',
                    ),
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
                          'Waktu (lokal)',
                          'Modul',
                          'Arah',
                          'Status',
                          'Record',
                          'Kode / Alasan',
                          'Operasi / Attempt',
                        ])
                          DataColumn(label: Text(title)),
                      ],
                      rows: rows
                          .map(
                            (r) => DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    DateTime.parse(r['started_at'] as String)
                                        .toLocal()
                                        .toString(),
                                  ),
                                ),
                                DataCell(Text('${r['module']}')),
                                DataCell(Text('${r['direction']}')),
                                DataCell(
                                  SyncStatusBadge(
                                    label: label('${r['status']}'),
                                    color: switch (r['status']) {
                                      'success' => AppColors.success,
                                      'failed' => AppColors.error,
                                      _ => AppColors.warning,
                                    },
                                  ),
                                ),
                                DataCell(Text('${r['record_count'] ?? '—'}')),
                                DataCell(
                                  Text(
                                    '${r['error_code'] ?? '—'}\n${r['error_message'] ?? ''}',
                                  ),
                                ),
                                DataCell(
                                  SelectionArea(
                                    child: Text(
                                      '${r['operation_id']}\n${r['attempt_id']}',
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

  String label(String value) => switch (value) {
    'success' => 'Berhasil',
    'failed' => 'Gagal',
    'pending' => 'Tertunda',
    _ => value,
  };
}
