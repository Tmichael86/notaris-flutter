import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class DashboardDesktopScreen extends StatefulWidget {
  const DashboardDesktopScreen({super.key});

  @override
  State<DashboardDesktopScreen> createState() => _DashboardDesktopScreenState();
}

class _DashboardDesktopScreenState
    extends State<DashboardDesktopScreen>
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

  Widget _buildDashboard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < desktopBreakpoint;
        final padding = mobile ? 16.0 : 28.0;

        return Padding(
          padding: EdgeInsets.fromLTRB(padding, 22, padding, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDashboardHeading(mobile),
              const SizedBox(height: 20),
              _buildStats(mobile),
              const SizedBox(height: 24),
              if (mobile) ...[
                _buildTransactionChartCard(),
                const SizedBox(height: 16),
                _buildTasksCard(),
                const SizedBox(height: 16),
                _buildRecentTransactionsCard(),
                const SizedBox(height: 16),
                _buildApplicantCard(),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _buildTransactionChartCard()),
                    const SizedBox(width: 20),
                    Expanded(child: _buildApplicantCard()),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _buildTasksCard()),
                    const SizedBox(width: 20),
                    Expanded(child: _buildRecentTransactionsCard()),
                  ],
                ),
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
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
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
        children: [
          heading,
          const SizedBox(height: 14),
          yearPicker,
        ],
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

  Widget _buildStats(bool mobile) {
    const stats = [
      _DashboardMetric(
        title: 'Total Transaksi',
        value: '128',
        subtitle: 'Tahun berjalan',
        icon: Icons.receipt_long_outlined,
      ),
      _DashboardMetric(
        title: 'Transaksi Berjalan',
        value: '36',
        subtitle: 'Masih diproses',
        icon: Icons.pending_actions_outlined,
      ),
      _DashboardMetric(
        title: 'Jatuh Tempo',
        value: '12',
        subtitle: 'Perlu perhatian',
        icon: Icons.event_available_outlined,
      ),
      _DashboardMetric(
        title: 'Pendapatan',
        value: 'Rp 48,5 jt',
        subtitle: 'Tahun berjalan',
        icon: Icons.account_balance_wallet_outlined,
      ),
    ];

    if (mobile) {
      return GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.35,
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
        final progress = Curves.easeOutCubic.transform(_dashboardController.value);
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
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .035),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.selectedMenuBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(metric.icon, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    metric.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    metric.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    metric.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(18)}) {
    return Container(
      height: 310,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
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

  Widget _sectionTitle(String title, {String? action}) {
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
        if (action != null)
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: EdgeInsets.zero,
            ),
            child: Text(action),
          ),
      ],
    );
  }

  Widget _buildTransactionChartCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Aktivitas Transaksi', action: 'Tahun $_selectedYear'),
          const SizedBox(height: 8),
          const Text(
            'Pergerakan transaksi kantor sepanjang tahun',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: CustomPaint(
              painter: _TransactionChartPainter(),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _ChartLabel('Jan'),
              _ChartLabel('Mar'),
              _ChartLabel('Mei'),
              _ChartLabel('Jul'),
              _ChartLabel('Sep'),
              _ChartLabel('Nov'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildApplicantCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Pemohon & Transaksi'),
          const SizedBox(height: 4),
          const Text(
            'Ringkasan komposisi data dashboard',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          Expanded(
            child: Row(
              children: [
                const SizedBox(
                  width: 160,
                  height: 160,
                  child: CustomPaint(painter: _DonutPainter()),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      _LegendItem('Transaksi selesai', '55%'),
                      SizedBox(height: 12),
                      _LegendItem('Transaksi berjalan', '25%'),
                      SizedBox(height: 12),
                      _LegendItem('Belum diproses', '20%'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksCard() {
    const tasks = [
      ('AJB - 0012', 'Pemeriksaan dokumen', 'Hari ini'),
      ('SHM - 0081', 'Menunggu pembayaran', 'Hari ini'),
      ('CV - 0045', 'Proses akta', 'Besok'),
      ('PPAT - 0120', 'Validasi berkas', '25 Sep'),
      ('PT - 0021', 'Penandatanganan', '26 Sep'),
    ];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Tugas & Aktivitas', action: 'Lihat semua'),
          const SizedBox(height: 6),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 2),
          Expanded(
            child: ListView.separated(
              physics: const ClampingScrollPhysics(),
              itemCount: tasks.length,
              separatorBuilder: (_, __) => const Divider(
                height: 1,
                color: AppColors.divider,
              ),
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
                    task.$1,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    task.$2,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: Text(
                    task.$3,
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

  Widget _buildRecentTransactionsCard() {
    const rows = [
      ('TRX-2026-0128', 'Notaris', 'Rp 4.500.000'),
      ('TRX-2026-0127', 'PPAT', 'Rp 8.250.000'),
      ('TRX-2026-0126', 'Notaris', 'Rp 3.750.000'),
      ('TRX-2026-0125', 'PPAT', 'Rp 6.100.000'),
      ('TRX-2026-0124', 'Notaris', 'Rp 2.900.000'),
    ];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Transaksi Terbaru', action: 'Lihat semua'),
          const SizedBox(height: 6),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.separated(
              physics: const ClampingScrollPhysics(),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const Divider(
                height: 1,
                color: AppColors.divider,
              ),
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
                              row.$1,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              row.$2,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        row.$3,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
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

  const _LegendItem(this.title, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
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

class _TransactionChartPainter extends CustomPainter {
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

    const values = [
      .25,
      .32,
      .28,
      .45,
      .40,
      .55,
      .49,
      .64,
      .58,
      .72,
      .66,
      .82,
    ];

    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - (size.height * values[i]);
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 8;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..strokeCap = StrokeCap.butt;

    const segments = [0.55, 0.25, 0.20];
    final colors = [
      AppColors.primary,
      AppColors.primaryDark,
      AppColors.border,
    ];

    double startAngle = -1.5708;
    for (int i = 0; i < segments.length; i++) {
      paint.color = colors[i];
      final sweep = segments[i] * 6.28318;
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
      text: const TextSpan(
        text: '128',
        style: TextStyle(
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
