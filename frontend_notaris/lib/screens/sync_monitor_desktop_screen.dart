import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sync_monitor_provider.dart';
import '../providers/development_smoke_provider.dart';
import '../providers/auth_provider.dart';
import '../repositories/sync_monitor_repository.dart';

class SyncMonitorDesktopScreen extends ConsumerStatefulWidget {
  const SyncMonitorDesktopScreen({super.key});
  @override
  ConsumerState<SyncMonitorDesktopScreen> createState() => _MonitorState();
}

class _MonitorState extends ConsumerState<SyncMonitorDesktopScreen> {
  String module = 'kategori', direction = 'push';
  @override
  Widget build(BuildContext context) {
    final data = ref.watch(syncMonitorProvider);
    final smoke = ref.watch(developmentUiSmokeProvider);
    final offline =
        ref.watch(authControllerProvider).session?.isOffline ?? true;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monitoring Sinkronisasi',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const Text(
            'Snapshot lokal, bukan pemeriksaan kesehatan server. Hijau hanya untuk kondisi relevan yang diketahui.',
          ),
          if (offline)
            const Text(
              'Offline / sesi online belum tersedia. Status server belum diperiksa.',
            ),
          Wrap(
            spacing: 16,
            children: [
              DropdownButton<String>(
                value: module,
                items: [
                  for (final e in syncModules.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setState(() => module = v!),
              ),
              DropdownButton<String>(
                value: direction,
                items: const [
                  DropdownMenuItem(value: 'push', child: Text('Upload')),
                  DropdownMenuItem(value: 'pull', child: Text('Download')),
                ],
                onChanged: (v) => setState(() => direction = v!),
              ),
              const FilledButton(
                onPressed: null,
                child: Text('Jalankan seleksi'),
              ),
              IconButton(
                tooltip: 'Refresh snapshot lokal',
                onPressed: () => ref.invalidate(syncMonitorProvider),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          Text(
            smoke
                ? 'UI Smoke: seluruh sinkronisasi manual dinonaktifkan.'
                : selectiveSyncReason(module),
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
                  : SingleChildScrollView(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
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
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.circle,
                                            size: 12,
                                            color: switch (r['color']) {
                                              'green' => Colors.green,
                                              'yellow' => Colors.amber,
                                              'red' => Colors.red,
                                              _ => Colors.grey,
                                            },
                                          ),
                                          const SizedBox(width: 6),
                                          Text(switch (r['color']) {
                                            'green' => 'Berhasil (diketahui)',
                                            'yellow' => 'Perhatian',
                                            'red' => 'Perlu penanganan',
                                            _ => 'Belum diketahui',
                                          }),
                                        ],
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
                                    DataCell(Text('${r['progress']}')),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String time(Object? value) => value == null
      ? '—'
      : DateTime.parse(value as String).toLocal().toString();
}
