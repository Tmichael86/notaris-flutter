import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/widgets/searchable_dropdown.dart';
import '../core/widgets/transaction_review_dialog.dart';
import '../models/dashboard_transactions.dart';
import '../providers/transaction_provider.dart';

class DashboardDesktopScreen extends ConsumerStatefulWidget {
  const DashboardDesktopScreen({super.key, required this.canReadTransactions});

  final bool canReadTransactions;

  @override
  ConsumerState<DashboardDesktopScreen> createState() =>
      _DashboardDesktopScreenState();
}

class _DashboardDesktopScreenState extends ConsumerState<DashboardDesktopScreen>
    with SingleTickerProviderStateMixin {
  static const double desktopBreakpoint = 1000;

  String _selectedYear = DateTime.now().year.toString();
  late final AnimationController _dashboardController;

  List<String> get _availableYears {
    final currentYear = DateTime.now().year;
    return List.generate(5, (index) => '${currentYear - index}');
  }

  @override
  void initState() {
    super.initState();
    _dashboardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
  }

  @override
  void dispose() {
    _dashboardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allowed = widget.canReadTransactions;
    final year = int.parse(_selectedYear);
    final transactions = allowed ? ref.watch(transactionsProvider) : null;
    final data = transactions?.asData?.value;
    final summary = data == null
        ? null
        : DashboardTransactions(data, year, DateTime.now());
    final revenue = allowed ? ref.watch(receivedPaymentsProvider(year)) : null;
    final unavailable = transactions?.hasError == true
        ? 'Data transaksi lokal gagal dimuat.'
        : 'Memuat transaksi lokal…';
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < desktopBreakpoint;
        final padding = mobile ? 16.0 : 28.0;

        return Padding(
          padding: EdgeInsets.fromLTRB(padding, 24, padding, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDashboardHeading(mobile),
              const SizedBox(height: 20),
              if (!allowed)
                _card(
                  child: _message(
                    'Izin baca Transaksi diperlukan untuk melihat data Dashboard.',
                  ),
                )
              else ...[
                _buildStats(mobile, summary, revenue!),
                const SizedBox(height: 24),
                if (mobile) ...[
                  _buildTransactionChartCard(summary, unavailable),
                  const SizedBox(height: 16),
                  _buildTasksCard(summary, unavailable),
                  const SizedBox(height: 16),
                  _buildRecentTransactionsCard(summary, unavailable),
                  const SizedBox(height: 16),
                  _buildApplicantCard(summary, unavailable),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildTransactionChartCard(summary, unavailable),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _buildApplicantCard(summary, unavailable),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildTasksCard(summary, unavailable),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _buildRecentTransactionsCard(
                          summary,
                          unavailable,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDashboardHeading(bool mobile) {
    const heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dashboard',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 5),
        Text(
          'Ringkasan aktivitas kantor Notaris & PPAT',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );

    final yearPicker = SizedBox(
      width: mobile ? double.infinity : 140,
      height: 40,
      child: SearchableDropdown<String>(
        value: _selectedYear,
        items: _availableYears,
        label: 'Tahun',
        hint: 'Pilih tahun',
        itemLabel: (year) => year,
        onChanged: (value) {
          if (value != null) setState(() => _selectedYear = value);
        },
      ),
    );

    if (mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [heading, const SizedBox(height: 14), yearPicker],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(child: heading),
        yearPicker,
      ],
    );
  }

  Widget _buildStats(
    bool mobile,
    DashboardTransactions? summary,
    AsyncValue<double> revenue,
  ) {
    final received = revenue.asData?.value;
    final stats = [
      _DashboardMetric(
        title: 'Total Transaksi',
        value: summary?.total.toString() ?? '—',
        subtitle: 'Tahun $_selectedYear',
        icon: Icons.receipt_long_outlined,
      ),
      _DashboardMetric(
        title: 'Transaksi Berjalan',
        value: summary?.running.toString() ?? '—',
        subtitle: 'Masih diproses',
        icon: Icons.pending_actions_outlined,
      ),
      _DashboardMetric(
        title: 'Jatuh Tempo',
        value: summary?.due.toString() ?? '—',
        subtitle: 'Hingga hari ini',
        icon: Icons.event_available_outlined,
      ),
      _DashboardMetric(
        title: 'Pendapatan',
        value: received == null ? '—' : _rupiah(received),
        subtitle: revenue.hasError
            ? 'Pembayaran gagal dimuat'
            : received == null
            ? 'Memuat pembayaran…'
            : 'Pembayaran masuk $_selectedYear',
        icon: Icons.account_balance_wallet_outlined,
      ),
    ];

    if (mobile) {
      return GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 156,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [for (final item in stats) _buildMetricCard(item)],
      );
    }

    return Row(
      children: [
        for (int i = 0; i < stats.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          Expanded(child: _buildMetricCard(stats[i])),
        ],
      ],
    );
  }

  Widget _buildMetricCard(_DashboardMetric metric) {
    return AnimatedBuilder(
      animation: _dashboardController,
      builder: (context, child) {
        final progress = Curves.easeOutCubic.transform(
          _dashboardController.value,
        );
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - progress)),
            child: child,
          ),
        );
      },
      child: Container(
        height: 142,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .035),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 200;
            final icon = Container(
              width: compact ? 34.0 : 42.0,
              height: compact ? 34.0 : 42.0,
              decoration: BoxDecoration(
                color: AppColors.selectedMenuBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                metric.icon,
                color: AppColors.primary,
                size: compact ? 19 : 22,
              ),
            );
            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  metric.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 10 : 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: compact ? 3 : 6),
                Tooltip(
                  message: metric.value,
                  child: Text(
                    metric.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 19 : 23,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Tooltip(
                  message: metric.subtitle,
                  child: Text(
                    metric.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 9 : 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [icon, const SizedBox(height: 8), details],
              );
            }

            return Row(
              children: [
                icon,
                const SizedBox(width: 12),
                Expanded(child: details),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _card({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
  }) {
    return Container(
      height: 320,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionTitle(
    String title, {
    String? trailing,
    VoidCallback? onPressed,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (trailing != null && onPressed == null)
          Text(
            trailing,
            style: const TextStyle(fontSize: 12, color: AppColors.primary),
          ),
        if (trailing != null && onPressed != null)
          TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: EdgeInsets.zero,
            ),
            child: Text(trailing),
          ),
      ],
    );
  }

  Widget _message(String text) => Center(
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
    ),
  );

  Widget _buildTransactionChartCard(
    DashboardTransactions? summary,
    String unavailable,
  ) {
    final counts = summary?.monthlyCounts;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Aktivitas Transaksi',
            trailing: 'Tahun $_selectedYear',
          ),
          const SizedBox(height: 8),
          const Text(
            'Pergerakan transaksi kantor sepanjang tahun',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: counts == null
                ? _message(unavailable)
                : summary!.total == 0
                ? _message(
                    'Belum ada transaksi bertanggal pada tahun $_selectedYear.',
                  )
                : Semantics(
                    label:
                        'Jumlah transaksi Januari sampai Desember: ${counts.join(', ')}',
                    child: CustomPaint(
                      painter: _TransactionChartPainter(counts),
                      child: const SizedBox.expand(),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 14,
            child: Stack(
              children: [
                for (final (index, label) in const [
                  (0, 'Jan'),
                  (2, 'Mar'),
                  (4, 'Mei'),
                  (6, 'Jul'),
                  (8, 'Sep'),
                  (11, 'Des'),
                ])
                  Align(
                    alignment: Alignment(index * 2 / 11 - 1, 0),
                    child: _ChartLabel(label),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicantCard(
    DashboardTransactions? summary,
    String unavailable,
  ) {
    final counts = summary?.statusCounts ?? const [0, 0, 0];
    final known = counts.reduce((a, b) => a + b);
    final percent = [
      for (final count in counts)
        if (known > 0) '${(count * 100 / known).round()}%',
    ];
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Pemohon & Transaksi'),
          const SizedBox(height: 4),
          const Text(
            'Komposisi status transaksi yang dikenal',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          Expanded(
            child: summary == null
                ? _message(unavailable)
                : known == 0
                ? _message('Belum ada transaksi dengan status yang dikenal.')
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final donutSize = (constraints.maxWidth * 0.42)
                          .clamp(104.0, 140.0)
                          .toDouble();
                      return Row(
                        children: [
                          SizedBox(
                            width: donutSize,
                            height: donutSize,
                            child: CustomPaint(
                              painter: _DonutPainter(counts, known),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _LegendItem(
                                  'Transaksi selesai',
                                  percent[0],
                                  _statusColors[0],
                                ),
                                const SizedBox(height: 10),
                                _LegendItem(
                                  'Transaksi berjalan',
                                  percent[1],
                                  _statusColors[1],
                                ),
                                const SizedBox(height: 10),
                                _LegendItem(
                                  'Belum diproses',
                                  percent[2],
                                  _statusColors[2],
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksCard(DashboardTransactions? summary, String unavailable) {
    final tasks = summary?.upcoming;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            DashboardTransactionList.deadlines.title,
            trailing: 'Lihat semua',
            onPressed: () =>
                _openTransactionList(DashboardTransactionList.deadlines),
          ),
          const Text(
            'Tenggat transaksi yang masih terbuka',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 2),
          Expanded(
            child: tasks == null
                ? _message(unavailable)
                : tasks.isEmpty
                ? _message(
                    'Belum ada tenggat transaksi terbuka pada tahun $_selectedYear.',
                  )
                : ListView.separated(
                    physics: const ClampingScrollPhysics(),
                    itemCount: tasks.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.divider),
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.selectedMenuBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.assignment_outlined,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ),
                        title: Text(
                          task.noAkta,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          task.statusTransaksi,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        trailing: Text(
                          _formatDate(task.tanggalJatuhTempo!),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textMuted,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactionsCard(
    DashboardTransactions? summary,
    String unavailable,
  ) {
    final rows = summary?.recent;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            DashboardTransactionList.recent.title,
            trailing: 'Lihat semua',
            onPressed: () =>
                _openTransactionList(DashboardTransactionList.recent),
          ),
          const SizedBox(height: 6),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 4),
          Expanded(
            child: rows == null
                ? _message(unavailable)
                : rows.isEmpty
                ? _message('Belum ada transaksi pada tahun $_selectedYear.')
                : ListView.separated(
                    physics: const ClampingScrollPhysics(),
                    itemCount: rows.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.divider),
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: AppColors.selectedMenuBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.description_outlined,
                                size: 18,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    row.noAkta,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    row.jenisTransaksi == 'notaris'
                                        ? 'Notaris'
                                        : row.jenisTransaksi.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _rupiah(row.total),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _openTransactionList(DashboardTransactionList list) {
    if (!widget.canReadTransactions) return;
    showDialog<void>(
      context: context,
      builder: (_) => _DashboardTransactionDialog(
        list: list,
        year: int.parse(_selectedYear),
      ),
    );
  }
}

class _DashboardTransactionDialog extends ConsumerStatefulWidget {
  const _DashboardTransactionDialog({required this.list, required this.year});

  final DashboardTransactionList list;
  final int year;

  @override
  ConsumerState<_DashboardTransactionDialog> createState() =>
      _DashboardTransactionDialogState();
}

class _DashboardTransactionDialogState
    extends ConsumerState<_DashboardTransactionDialog> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(
      dashboardTransactionPageProvider((
        list: widget.list,
        year: widget.year,
        index: _index,
      )),
    );
    final page = result.asData?.value;
    final pageCount = page == null
        ? 0
        : (page.total + dashboardTransactionPageSize - 1) ~/
              dashboardTransactionPageSize;
    final deadlines = widget.list == DashboardTransactionList.deadlines;
    return TransactionReviewDialog(
      title: widget.list.title,
      subtitle: 'Tahun ${widget.year}',
      bodyKey: ValueKey(page?.index),
      body: result.when(
        loading: () => const TransactionReviewMessage(
          'Memuat transaksi lokal…',
          loading: true,
        ),
        error: (_, _) => const TransactionReviewMessage(
          'Data transaksi lokal gagal dimuat.',
          icon: Icons.error_outline,
        ),
        data: (page) => page.rows.isEmpty
            ? TransactionReviewMessage(
                deadlines
                    ? 'Belum ada tenggat transaksi terbuka.'
                    : 'Belum ada transaksi pada tahun ini.',
              )
            : Column(
                children: [
                  for (final (index, row) in page.rows.indexed) ...[
                    if (index > 0)
                      const Divider(height: 1, color: AppColors.divider),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            deadlines
                                ? Icons.event_outlined
                                : Icons.receipt_long_outlined,
                            color: AppColors.primaryDark,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  row.noAkta,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    if (deadlines) ...[
                                      Text(
                                        'Tenggat ${_formatDate(row.tanggalJatuhTempo!)}',
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      TransactionReviewBadge.transaction(
                                        row.statusTransaksi,
                                      ),
                                    ] else ...[
                                      Text(
                                        '${row.jenisTransaksi.toUpperCase()} · ${_formatDate(row.tanggalTransaksi!)}',
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      Text(
                                        _rupiah(row.total),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
      ),
      footer: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          if (page != null)
            Text(
              '${page.total} transaksi · Halaman ${pageCount == 0 ? 0 : page.index + 1} / $pageCount',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          Wrap(
            children: [
              TextButton(
                onPressed: page != null && page.index > 0
                    ? () => setState(() => _index = page.index - 1)
                    : null,
                child: const Text('Sebelumnya'),
              ),
              TextButton(
                onPressed: page != null && page.index + 1 < pageCount
                    ? () => setState(() => _index = page.index + 1)
                    : null,
                child: const Text('Berikutnya'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardMetric {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  const _DashboardMetric({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });
}

class _ChartLabel extends StatelessWidget {
  final String text;

  const _ChartLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _LegendItem(this.title, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

String _rupiah(double amount) =>
    'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}';

String _formatDate(DateTime value) {
  final date = value.toLocal();
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _TransactionChartPainter extends CustomPainter {
  const _TransactionChartPainter(this.counts);
  final List<int> counts;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;

    final line = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = AppColors.primary.withValues(alpha: .08)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 4; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final maxCount = counts.reduce(math.max);
    final points = <Offset>[];
    for (int i = 0; i < counts.length; i++) {
      final x = 3 + (size.width - 6) * i / (counts.length - 1);
      final y = size.height - 3 - (size.height - 6) * counts[i] / maxCount;
      points.add(Offset(x, y));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(fillPath, fill);
    canvas.drawPath(path, line);

    final dotPaint = Paint()..color = AppColors.primary;
    for (final point in points) {
      canvas.drawCircle(point, 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TransactionChartPainter oldDelegate) =>
      !listEquals(counts, oldDelegate.counts);
}

const _statusColors = [
  AppColors.primary,
  AppColors.primaryDark,
  AppColors.border,
];

class _DonutPainter extends CustomPainter {
  const _DonutPainter(this.counts, this.total);
  final List<int> counts;
  final int total;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 8;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..strokeCap = StrokeCap.butt;

    double startAngle = -math.pi / 2;
    for (int i = 0; i < counts.length; i++) {
      paint.color = _statusColors[i];
      final sweep = counts[i] * 2 * math.pi / total;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        paint,
      );
      startAngle += sweep;
    }

    final centerPaint = Paint()
      ..color = AppColors.card
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 14, centerPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: '$total',
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      !listEquals(counts, oldDelegate.counts);
}
