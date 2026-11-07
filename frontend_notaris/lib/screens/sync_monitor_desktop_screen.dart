import '../core/widgets/master_data_viewport.dart';
import '../core/widgets/sync_page_frame.dart' show SyncStatusBadge;
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
        builder: (c) => TransactionManualSyncControls(onClose: () => close(c)),
      );
    } finally {
      if (mounted) {
        setState(() => modalOpen = false);
        ref.invalidate(syncMonitorProvider);
      }
    }
  }

  final _vertical = ScrollController();
  @override
  void dispose() {
    _vertical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(syncMonitorProvider);
    final offline =
        ref.watch(authControllerProvider).session?.isOffline ?? true;
    return MasterDataViewport(
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: Scrollbar(
          controller: _vertical,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _vertical,
            padding: const EdgeInsets.only(right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, c) {
                    final heading = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Monitoring Sinkronisasi',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Status dan aktivitas data pada perangkat ini',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'System > Monitoring Sinkronisasi',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    );
                    final actions = Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const _SnapshotLabel(),
                        FilledButton.icon(
                          key: const Key('open-manual-sync'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryDark,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: modalOpen ? null : manual,
                          icon: const Icon(Icons.sync, size: 18),
                          label: const Text('Pusat Sinkronisasi'),
                        ),
                        IconButton(
                          key: const Key('refresh-monitor'),
                          tooltip: 'Refresh snapshot lokal',
                          onPressed: () => ref.invalidate(syncMonitorProvider),
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    );
                    if (c.maxWidth < 1050) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          heading,
                          const SizedBox(height: 12),
                          actions,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: heading),
                        const SizedBox(width: 20),
                        actions,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  offline
                      ? 'Offline / sesi online belum tersedia. Status server belum diperiksa.'
                      : 'Snapshot lokal, bukan pemeriksaan kesehatan server atau konfirmasi sinkronisasi global.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                data.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, s) => _Surface(
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error),
                        const SizedBox(height: 8),
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
                  data: (rows) {
                    final attention = rows
                        .where(
                          (r) => r['color'] == 'red' || r['color'] == 'yellow',
                        )
                        .length;
                    final unknown = rows
                        .where(
                          (r) =>
                              !{'red', 'yellow', 'green'}.contains(r['color']),
                        )
                        .length;
                    final activity =
                        rows
                            .expand(
                              (r) => [r['last_attempt'], r['last_success']],
                            )
                            .map((v) => DateTime.tryParse(v?.toString() ?? ''))
                            .whereType<DateTime>()
                            .toList()
                          ..sort();
                    final transaction = rows
                        .where((r) => '${r['module']}'.startsWith('transaksi'))
                        .toList();
                    final master = rows
                        .where((r) => !'${r['module']}'.startsWith('transaksi'))
                        .toList();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LayoutBuilder(
                          builder: (context, c) {
                            final width = c.maxWidth >= 760
                                ? (c.maxWidth - 24) / 3
                                : c.maxWidth;
                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                SizedBox(
                                  width: width,
                                  child: _SummaryCard(
                                    key: const Key('summary-attention'),
                                    title: 'Perlu perhatian',
                                    value: '$attention',
                                    note: 'Modul/feed dengan perhatian atau error',
                                    icon: Icons.report_outlined,
                                  ),
                                ),
                                SizedBox(
                                  width: width,
                                  child: _SummaryCard(
                                    key: const Key('summary-unknown'),
                                    title: 'Belum diketahui',
                                    value: '$unknown',
                                    note: 'Modul/feed tanpa status yang diketahui',
                                    icon: Icons.help_outline,
                                  ),
                                ),
                                SizedBox(
                                  width: width,
                                  child: _SummaryCard(
                                    key: const Key('summary-activity'),
                                    title: 'Aktivitas terakhir',
                                    value: activity.isEmpty
                                        ? 'Belum ada aktivitas'
                                        : syncLocalTime(
                                            activity.last.toIso8601String(),
                                          ),
                                    note: 'Attempt / keberhasilan terakhir yang tercatat',
                                    icon: Icons.history,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Jumlah ringkasan menghitung entri modul/feed, bukan penjumlahan record atau outbox server.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (rows.isEmpty)
                          const _Surface(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(
                                child: Text(
                                  'Belum ada modul untuk ditampilkan.',
                                ),
                              ),
                            ),
                          ),
                        if (transaction.isNotEmpty)
                          _ModuleGroup(title: 'Transaksi', rows: transaction),
                        if (transaction.isNotEmpty && master.isNotEmpty)
                          const SizedBox(height: 20),
                        if (master.isNotEmpty)
                          _ModuleGroup(title: 'Data Master', rows: master),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _gold = Color(0xFFE3D9C3);

class _SnapshotLabel extends StatelessWidget {
  const _SnapshotLabel();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      border: Border.all(color: _gold),
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.devices_outlined, size: 13, color: AppColors.textSecondary),
        SizedBox(width: 5),
        Text(
          'Snapshot lokal',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    ),
  );
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.card,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: child,
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.note,
    required this.icon,
  });
  final String title, value, note;
  final IconData icon;
  @override
  Widget build(BuildContext context) => _Surface(
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: AppColors.primaryDark),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: title == 'Aktivitas terakhir' ? 15 : 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            note,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    ),
  );
}

class _ModuleGroup extends StatelessWidget {
  const _ModuleGroup({required this.title, required this.rows});
  final String title;
  final List<Map<String, dynamic>> rows;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 1, color: _gold)),
        ],
      ),
      const SizedBox(height: 10),
      Material(
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              _ModuleRow(row: rows[i]),
            ],
          ],
        ),
      ),
    ],
  );
}

class _ModuleRow extends StatelessWidget {
  const _ModuleRow({required this.row});
  final Map<String, dynamic> row;
  @override
  Widget build(BuildContext context) {
    final color = switch (row['color']) {
      'green' => AppColors.success,
      'yellow' => AppColors.warning,
      'red' => AppColors.error,
      _ => AppColors.textSecondary,
    };
    final label = switch (row['color']) {
      'green' => 'Berhasil (diketahui)',
      'yellow' => 'Perhatian',
      'red' => 'Perlu penanganan',
      _ => 'Belum diketahui',
    };
    final reason = switch (row['module']) {
      'transaksi_notaris' || 'transaksi_ppat' => 'Upload satu record melalui Pusat Sinkronisasi; profil dan izin tetap diverifikasi.',
      'transaksi' => 'Download feed gabungan Notaris + PPAT melalui Pusat Sinkronisasi, dengan satu cursor.',
      _ => '${row['reason'] ?? '—'}',
    };
    final badge = SyncStatusBadge(label: label, color: color);
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${row['label'] ?? row['module']}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          '${row['pending_records'] ?? '—'} record pending · ${row['pending_operations'] ?? '—'} operasi tertunda',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
    return ExpansionTile(
      key: ValueKey('monitor-detail-${row['module']}'),
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      title: LayoutBuilder(
        builder: (context, c) => c.maxWidth < 550
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [identity, const SizedBox(height: 8), badge],
              )
            : Row(
                children: [
                  Expanded(child: identity),
                  const SizedBox(width: 16),
                  badge,
                ],
              ),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final field in {
                'Terakhir mencoba': syncLocalTime(row['last_attempt']),
                'Terakhir berhasil': syncLocalTime(row['last_success']),
                'Progress tercatat': row['progress'] ?? '—',
                'Error diketahui': row['errors'] ?? '—',
                'Ketersediaan operasi': reason,
                'Modul / feed': row['module'] ?? '—',
                'Waktu snapshot': syncLocalTime(
                  row['snapshot_at'],
                  precise: true,
                ),
                for (final entry in row.entries)
                  if (!{
                    'module',
                    'label',
                    'color',
                    'last_attempt',
                    'last_success',
                    'pending_records',
                    'pending_operations',
                    'errors',
                    'progress',
                    'reason',
                    'snapshot_at',
                  }.contains(entry.key))
                    entry.key: entry.value ?? '—',
              }.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${field.key}: ${field.value}',
                    style: const TextStyle(fontSize: 12, height: 1.5),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
