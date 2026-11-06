import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/widgets/master_data_viewport.dart';
import '../core/widgets/sync_page_frame.dart';
import '../providers/recycle_bin_provider.dart';
import '../providers/sync_monitor_provider.dart';
import '../repositories/recycle_bin_repository.dart';

class RecycleBinDesktopScreen extends ConsumerStatefulWidget {
  const RecycleBinDesktopScreen({super.key});
  @override
  ConsumerState<RecycleBinDesktopScreen> createState() => _RecycleBinState();
}

class _RecycleBinState extends ConsumerState<RecycleBinDesktopScreen> {
  RecycleModule? module;
  bool busy = false;
  bool restoring = false;
  final horizontal = ScrollController(), vertical = ScrollController();
  @override
  void dispose() {
    horizontal.dispose();
    vertical.dispose();
    super.dispose();
  }

  Future<void> restore(RecycleRecord record) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Pulihkan data lokal?'),
          content: Text(
            '${record.module.label}: ${record.label}\nUUID: ${record.uuid}\nIdentitas dan histori dipertahankan. Operasi ini tidak mengirim data ke server.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Pulihkan'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      setState(() => restoring = true);
      await ref.read(recycleBinRepositoryProvider).restore(record);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data berhasil dipulihkan secara lokal.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (e is RestoreFailure ? e : const RestoreFailure('storage'))
                  .message,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        ref.invalidate(recycleBinRecordsProvider);
        ref.invalidate(syncMonitorProvider);
        setState(() {
          busy = false;
          restoring = false;
        });
      }
    }
  }

  Future<void> history() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Histori pemulihan lokal'),
        content: SizedBox(
          width: 640,
          height: 320,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: ref.read(recycleBinRepositoryProvider).history(),
            builder: (context, state) {
              if (state.hasError) {
                return const Text('Histori tidak dapat dimuat.');
              }
              if (!state.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.data!.isEmpty) {
                return const Text('Belum ada percobaan pemulihan.');
              }
              return ListView(
                children: [
                  for (final event in state.data!)
                    ListTile(
                      title: Text(
                        '${event['module']} • ${event['outcome'] == 'success' ? 'Berhasil' : 'Gagal'}',
                      ),
                      subtitle: Text(
                        '${event['local_uuid']}\n${event['occurred_at']}${event['error_code'] == null ? '' : '\n${RestoreFailure(event['error_code'] as String).message}'}',
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(recycleBinRepositoryProvider);
    final rows = ref.watch(recycleBinRecordsProvider(module));
    return SyncPageFrame(
      title: 'Recycle Bin',
      children: [
        const Text(
          'Pemulihan lokal • tanpa hapus permanen • restore cloud belum tersedia',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DropdownButton<RecycleModule?>(
              value: module,
              hint: const Text('Semua modul'),
              items: [
                const DropdownMenuItem<RecycleModule?>(
                  value: null,
                  child: Text('Semua modul'),
                ),
                // Keep a selected label valid if its permission is revoked.
                // Discovery and restore still recheck permissions independently.
                for (final m in RecycleModule.values.where(
                  (m) => repo.canRead(m) || m == module,
                ))
                  DropdownMenuItem(
                    value: m,
                    enabled: repo.canRead(m),
                    child: Text(m.label),
                  ),
              ],
              onChanged: busy ? null : (v) => setState(() => module = v),
            ),
            IconButton(
              tooltip: 'Muat ulang Recycle Bin',
              onPressed: busy
                  ? null
                  : () => ref.invalidate(recycleBinRecordsProvider),
              icon: const Icon(Icons.refresh),
            ),
            TextButton.icon(
              onPressed: busy ? null : history,
              icon: const Icon(Icons.history),
              label: const Text('Histori pemulihan'),
            ),
            if (restoring)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: rows.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Recycle Bin tidak dapat dimuat. Data tidak diubah.',
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(recycleBinRecordsProvider),
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
            ),
            data: (records) => records.isEmpty
                ? const Center(
                    child: Text(
                      'Tidak ada data terhapus untuk modul yang dapat Anda akses.',
                    ),
                  )
                : MasterDataTableViewport(
                    horizontalController: horizontal,
                    verticalController: vertical,
                    child: DataTable(
                      dataRowMinHeight: 64,
                      dataRowMaxHeight: double.infinity,
                      columns: [
                        for (final title in [
                          'Modul',
                          'Nama / Nomor',
                          'Identitas',
                          'Dihapus',
                          'Pemulihan',
                        ])
                          DataColumn(label: Text(title)),
                      ],
                      rows: [
                        for (final r in records)
                          DataRow(
                            cells: [
                              DataCell(Text(r.module.label)),
                              DataCell(
                                SizedBox(width: 200, child: Text(r.label)),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 240,
                                  child: Text('PK ${r.id}\n${r.uuid}'),
                                ),
                              ),
                              DataCell(Text(r.deletedAt.toLocal().toString())),
                              DataCell(
                                SizedBox(
                                  width: 280,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      TextButton.icon(
                                        onPressed: busy || r.blocked != null
                                            ? null
                                            : () => restore(r),
                                        icon: const Icon(Icons.restore),
                                        label: const Text('Restore'),
                                      ),
                                      if (r.blocked != null)
                                        Text(r.blocked!.message),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
