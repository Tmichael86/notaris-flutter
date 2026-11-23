import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/pendapatan_provider.dart';
import '../repositories/pendapatan_repository.dart';
import '../services/pendapatan_excel_export.dart';

class LaporanPendapatanDesktopScreen extends ConsumerStatefulWidget {
  const LaporanPendapatanDesktopScreen({
    super.key,
    this.exporter = const PendapatanExcelExport(),
    this.now = DateTime.now,
  });

  final PendapatanExcelExport exporter;
  final DateTime Function() now;

  @override
  ConsumerState<LaporanPendapatanDesktopScreen> createState() =>
      _LaporanPendapatanDesktopScreenState();
}

class _LaporanPendapatanDesktopScreenState
    extends ConsumerState<LaporanPendapatanDesktopScreen> {
  final _tableScroll = ScrollController();
  late var _period = pendapatanMonth(widget.now());
  int _page = 0;
  bool _exporting = false;

  @override
  void dispose() {
    _tableScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allowed = ref.watch(pendapatanAccessProvider);
    final report = allowed
        ? ref.watch(pendapatanReportProvider(_period))
        : null;
    return LayoutBuilder(
      builder: (context, bounds) {
        final compact = bounds.maxWidth < 700;
        return Padding(
          padding: EdgeInsets.all(compact ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 16,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Laporan Pendapatan',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Ringkasan penerimaan dan pengeluaran tercatat pada profil lokal.',
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        report?.hasValue == true &&
                            report?.isLoading == false &&
                            report?.hasError == false &&
                            !_exporting
                        ? _export
                        : null,
                    icon: _exporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.file_download_outlined),
                    label: Text(_exporting ? 'Mengekspor…' : 'Excel'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (!allowed)
                _panel(const Text(pendapatanDenied))
              else ...[
                _panel(
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _dateButton(true),
                      _dateButton(false),
                      OutlinedButton.icon(
                        onPressed: _exporting
                            ? null
                            : () => _select(pendapatanMonth(widget.now())),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                report!.when(
                  skipLoadingOnRefresh: false,
                  loading: () =>
                      _panel(const Center(child: CircularProgressIndicator())),
                  error: (_, _) =>
                      _panel(const Text('Laporan Pendapatan gagal dimuat.')),
                  data: (value) => _report(value),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Laporan berdasarkan pembayaran dan pengeluaran tercatat pada profil lokal. '
                  'Tidak termasuk perhitungan pajak PPAT, valuasi meterai, atau saldo kas historis. '
                  'Koreksi data dapat mengubah angka periode sebelumnya.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _panel(Widget child) => Material(
    color: AppColors.card,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: AppColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );

  Widget _dateButton(bool start) => OutlinedButton.icon(
    onPressed: _exporting ? null : () => _pickDate(start),
    icon: const Icon(Icons.calendar_today_outlined, size: 17),
    label: Text(
      '${start ? 'Tanggal Awal' : 'Tanggal Akhir'} · ${_date(start ? _period.from : _period.through)}',
    ),
  );

  Future<void> _pickDate(bool start) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _period.from : _period.through,
      firstDate: DateTime(1900),
      lastDate: DateTime(9999, 12, 31),
    );
    if (!mounted || picked == null || _exporting) return;
    final day = DateTime.utc(picked.year, picked.month, picked.day);
    if ((start && day.isAfter(_period.through)) ||
        (!start && day.isBefore(_period.from))) {
      _message('Tanggal awal harus sebelum atau sama dengan tanggal akhir.');
      return;
    }
    _select((
      from: start ? day : _period.from,
      through: start ? _period.through : day,
    ));
  }

  void _select(PendapatanPeriod period) => setState(() {
    _period = period;
    _page = 0;
  });

  Widget _report(PendapatanReport report) {
    final total = report.total;
    final page = _page.clamp(
      0,
      report.pageCount == 0 ? 0 : report.pageCount - 1,
    );
    final amounts = [
      ('Total Penerimaan Tercatat', total.receipts),
      ('Total Pengeluaran Tercatat', total.expenses),
      ('Selisih Penerimaan–Pengeluaran', total.difference),
    ];
    Widget card((String, BigInt) item) => _panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.$1, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Text(
            report.days.isEmpty ? '—' : formatPendapatanRupiah(item.$2),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: item.$2.isNegative
                  ? AppColors.primaryDark
                  : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (_, bounds) {
            if (bounds.maxWidth < 690) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final item in amounts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: card(item),
                    ),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < amounts.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(child: card(amounts[i])),
                ],
              ],
            );
          },
        ),
        if (report.reviews.isNotEmpty) ...[
          const SizedBox(height: 12),
          _reviewPanel(report),
        ],
        const SizedBox(height: 12),
        _panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                children: [
                  Text(
                    'Rekap Harian',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text('${report.days.length} hari'),
                ],
              ),
              const SizedBox(height: 10),
              if (report.days.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'Tidak ada catatan terverifikasi pada periode ini.',
                  ),
                )
              else ...[
                _table(report.page(page), page),
                if (report.pageCount > 1)
                  Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('Halaman ${page + 1} dari ${report.pageCount}'),
                      IconButton(
                        tooltip: 'Halaman sebelumnya',
                        onPressed: page > 0
                            ? () => setState(() => _page = page - 1)
                            : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      IconButton(
                        tooltip: 'Halaman berikutnya',
                        onPressed: page + 1 < report.pageCount
                            ? () => setState(() => _page = page + 1)
                            : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _reviewPanel(PendapatanReport report) {
    final counts = <String, int>{};
    for (final review in report.reviews) {
      final source = review.payment ? 'Pembayaran' : 'Pengeluaran';
      final label = '$source · ${review.reason}';
      counts.update(label, (count) => count + 1, ifAbsent: () => 1);
    }
    return _panel(
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        leading: const Icon(Icons.info_outline, color: AppColors.warning),
        title: const Text('Perlu Ditinjau'),
        subtitle: Text(
          '${report.reviews.length - report.unknownDates} dalam periode · '
          '${report.unknownDates} tanpa tanggal terverifikasi. '
          'Total hanya mencakup catatan terverifikasi.',
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in counts.entries)
            ListTile(
              dense: true,
              title: Text(entry.key),
              trailing: Text('${entry.value}'),
            ),
        ],
      ),
    );
  }

  Widget _table(List<PendapatanDay> rows, int page) => LayoutBuilder(
    builder: (_, bounds) {
      return Scrollbar(
        controller: _tableScroll,
        child: SingleChildScrollView(
          controller: _tableScroll,
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: bounds.maxWidth),
            child: DataTable(
              columnSpacing: 24,
              headingRowColor: const WidgetStatePropertyAll(
                AppColors.background,
              ),
              columns: const [
                DataColumn(label: Text('No')),
                DataColumn(label: Text('Tanggal')),
                DataColumn(label: Text('Penerimaan Tercatat'), numeric: true),
                DataColumn(label: Text('Pengeluaran Tercatat'), numeric: true),
                DataColumn(label: Text('Selisih'), numeric: true),
              ],
              rows: [
                for (var i = 0; i < rows.length; i++)
                  DataRow(
                    cells: [
                      DataCell(
                        Text('${page * PendapatanReport.pageSize + i + 1}'),
                      ),
                      DataCell(Text(_date(rows[i].date))),
                      for (final amount in [
                        rows[i].amount.receipts,
                        rows[i].amount.expenses,
                        rows[i].amount.difference,
                      ])
                        DataCell(Text(formatPendapatanRupiah(amount))),
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );

  String _date(DateTime day) =>
      '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}/${day.year}';

  Future<void> _export() async {
    if (_exporting) return;
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() => _exporting = true);
    try {
      final result = await widget.exporter.run(
        repository: ref.read(pendapatanRepositoryProvider),
        currentSession: () => container.read(authControllerProvider).session,
        period: _period,
      );
      if (result != null && mounted) {
        final excluded = result.excluded > 0
            ? ' ${result.excluded} catatan perlu ditinjau dan dikecualikan.'
            : '';
        _message('Excel tersimpan. ${result.rows} hari diekspor.$excluded');
      }
    } on StateError catch (error) {
      if (mounted) _message(error.message);
    } catch (_) {
      if (mounted) {
        _message('Excel gagal disimpan. Pilih nama dan lokasi file baru.');
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
