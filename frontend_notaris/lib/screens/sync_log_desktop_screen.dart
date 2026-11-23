import '../core/widgets/sync_presentation.dart';
import '../repositories/sync_monitor_repository.dart' show syncModules;
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
  int page = 0, density = 20;
  Map<String, dynamic>? selected;
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
              onChanged: (v) => setState(() {
                module = v == '' ? null : v;
                page = 0;
                selected = null;
              }),
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
              onChanged: (v) => setState(() {
                status = v == '' ? null : v;
                page = 0;
                selected = null;
              }),
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
                : logBody(rows),
          ),
        ),
      ],
    );
  }

  Widget logBody(List<Map<String, dynamic>> rows) => LayoutBuilder(
    builder: (context, c) {
      final start = (page * density).clamp(
        0,
        ((rows.length - 1) ~/ density) * density,
      );
      final visible = rows.skip(start).take(density).toList();
      final active = selected == null
          ? null
          : rows.where((r) => r['id'] == selected!['id']).firstOrNull;
      final table = Column(
        children: [
          Expanded(
            child: MasterDataTableViewport(
              horizontalController: _horizontal,
              verticalController: _vertical,
              child: DataTable(
                showCheckboxColumn: false,
                columnSpacing: 24,
                dataRowMinHeight: 52,
                dataRowMaxHeight: 64,
                columns: [
                  for (final h in [
                    'Waktu lokal',
                    'Modul',
                    'Aktivitas',
                    'Status',
                    'Record',
                  ])
                    DataColumn(label: Text(h)),
                ],
                rows: [
                  for (final r in visible)
                    DataRow(
                      key: ValueKey('sync-log-${r['id'] ?? r['attempt_id']}'),
                      selected: active != null && active['id'] == r['id'],
                      onSelectChanged: (_) => setState(() => selected = r),
                      cells: [
                        DataCell(Text(syncLocalTime(r['started_at']))),
                        DataCell(
                          SizedBox(
                            width: 180,
                            child: Text(
                              syncModules[r['module']] ?? '${r['module']}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            r['direction'] == 'push' ? 'Upload' : 'Download',
                          ),
                        ),
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
                      ],
                    ),
                ],
              ),
            ),
          ),
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${start + 1}–${(start + density).clamp(0, rows.length)} dari ${rows.length}',
              ),
              DropdownButton<int>(
                value: density,
                items: [
                  for (final n in [20, 50])
                    DropdownMenuItem(value: n, child: Text('$n / halaman')),
                ],
                onChanged: (v) => setState(() {
                  density = v!;
                  page = 0;
                }),
              ),
              IconButton(
                tooltip: 'Halaman sebelumnya',
                onPressed: start > 0
                    ? () => setState(() => page = start ~/ density - 1)
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                tooltip: 'Halaman berikutnya',
                onPressed: start + density < rows.length
                    ? () => setState(() => page = start ~/ density + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      );
      if (active == null) return table;
      final panel = Container(
        key: const Key('sync-log-details'),
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: AppColors.border)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Detail aktivitas',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Tutup detail',
                  onPressed: () => setState(() => selected = null),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SyncDetailField(
                      'Modul',
                      syncModules[active['module']] ?? '${active['module']}',
                    ),
                    SyncDetailField(
                      'Aktivitas',
                      active['direction'] == 'push' ? 'Upload' : 'Download',
                    ),
                    SyncDetailField('Status', label('${active['status']}')),
                    SyncDetailField(
                      'Mulai',
                      syncLocalTime(active['started_at'], precise: true),
                    ),
                    SyncDetailField(
                      'Selesai',
                      syncLocalTime(active['finished_at'], precise: true),
                    ),
                    SyncDetailField(
                      'Jumlah record',
                      '${active['record_count'] ?? '—'}',
                    ),
                    SyncDetailField(
                      'Operation ID',
                      '${active['operation_id'] ?? '—'}',
                      copy: true,
                    ),
                    SyncDetailField(
                      'Attempt ID',
                      '${active['attempt_id'] ?? '—'}',
                      copy: true,
                    ),
                    SyncDetailField(
                      'Error code',
                      '${active['error_code'] ?? '—'}',
                    ),
                    SyncDetailField(
                      'Reason',
                      '${active['error_message'] ?? '—'}',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
      return c.maxWidth < 1000
          ? panel
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: table),
                SizedBox(width: 340, child: panel),
              ],
            );
    },
  );

  String label(String value) => switch (value) {
    'success' => 'Berhasil',
    'failed' => 'Gagal',
    'pending' => 'Tertunda',
    _ => value,
  };
}
