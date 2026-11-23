import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../models/transaction_payments.dart';
import '../providers/auth_provider.dart';
import '../providers/piutang_provider.dart';
import '../repositories/piutang_repository.dart';
import '../services/piutang_excel_export.dart';

class PiutangDesktopScreen extends ConsumerStatefulWidget {
  const PiutangDesktopScreen({
    super.key,
    this.exporter = const PiutangExcelExport(),
  });

  final PiutangExcelExport exporter;

  @override
  ConsumerState<PiutangDesktopScreen> createState() =>
      _PiutangDesktopScreenState();
}

class _PiutangDesktopScreenState extends ConsumerState<PiutangDesktopScreen> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  String _domain = '';
  DateTime? _from, _through;
  int _page = 0;
  bool _exporting = false;

  PiutangFilter get _filter =>
      (domain: _domain, from: _from, through: _through, search: _search.text);

  @override
  Widget build(BuildContext context) {
    if (!canReadPiutang(ref.watch(authControllerProvider).session)) {
      return const Padding(
        padding: EdgeInsets.all(28),
        child: Text('Anda tidak memiliki izin membaca Piutang.'),
      );
    }
    final filter = _filter;
    final report = ref.watch(piutangReportProvider(filter));
    return LayoutBuilder(
      builder: (context, bounds) {
        final compact = bounds.maxWidth < 700;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 16 : 28,
            20,
            compact ? 16 : 28,
            30,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Piutang',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          piutangScope,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (Platform.isWindows) ...[
                    const SizedBox(width: 12),
                    Tooltip(
                      message: 'Ekspor seluruh piutang terverifikasi yang cocok dengan filter',
                      child: OutlinedButton.icon(
                        onPressed: _exporting || !report.hasValue
                            ? null
                            : () => _export(filter),
                        icon: const Icon(Icons.table_view_outlined, size: 18),
                        label: Text(_exporting ? 'Mengekspor…' : 'Excel'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green.shade800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              _panel(_filters()),
              const SizedBox(height: 18),
              _panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Data Piutang',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _search,
                      onChanged: (_) => setState(() => _page = 0),
                      decoration:
                          _dec('Cari nomor, pemohon, pekerjaan atau petugas')
                              .copyWith(
                                prefixIcon: const Icon(Icons.search, size: 20),
                              ),
                    ),
                    const SizedBox(height: 16),
                    report.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, _) =>
                          const Text('Daftar Piutang gagal dimuat.'),
                      data: _results,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _filters() => LayoutBuilder(
    builder: (context, bounds) {
      final columns = bounds.maxWidth >= 670
          ? 4
          : (bounds.maxWidth >= 370 ? 2 : 1);
      final width = (bounds.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: width,
            child: _dateField('Jatuh tempo dari', _from, from: true),
          ),
          SizedBox(
            width: width,
            child: _dateField('Jatuh tempo sampai', _through, from: false),
          ),
          SizedBox(
            width: width,
            child: DropdownButtonFormField<String>(
              // Reset must also reset the field's internal value.
              key: ValueKey(_domain),
              initialValue: _domain,
              isExpanded: true,
              decoration: _dec('Jenis Pekerjaan'),
              items: const [
                DropdownMenuItem(value: '', child: Text('Semua')),
                DropdownMenuItem(value: 'notaris', child: Text('Notaris')),
                DropdownMenuItem(value: 'ppat', child: Text('PPAT')),
              ],
              onChanged: (value) => setState(() {
                _domain = value ?? '';
                _page = 0;
              }),
            ),
          ),
          SizedBox(
            width: width,
            child: OutlinedButton.icon(
              onPressed: () => setState(() {
                _from = _through = null;
                _domain = '';
                _search.clear();
                _page = 0;
              }),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reset'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
            ),
          ),
        ],
      );
    },
  );

  Widget _dateField(String label, DateTime? value, {required bool from}) =>
      InkWell(
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: value ?? DateTime.now(),
            firstDate: DateTime(1900),
            lastDate: DateTime(9999, 12, 31),
            builder: (context, child) => DatePickerTheme(
              data: DatePickerTheme.of(context).copyWith(
                backgroundColor: AppColors.card,
                surfaceTintColor: Colors.transparent,
              ),
              child: child!,
            ),
          );
          if (!mounted || date == null) return;
          if ((from && _through != null && date.isAfter(_through!)) ||
              (!from && _from != null && date.isBefore(_from!))) {
            _message('Rentang jatuh tempo tidak valid.');
            return;
          }
          setState(() {
            if (from) {
              _from = date;
            } else {
              _through = date;
            }
            _page = 0;
          });
        },
        child: InputDecorator(
          decoration: _dec(label).copyWith(
            suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
          ),
          child: Text(value == null ? '—' : formatPaymentDate(value)),
        ),
      );

  Widget _results(PiutangReport report) {
    const size = PiutangReport.pageSize;
    final count = report.rows.length;
    final pages = (count + size - 1) ~/ size;
    final page = _page.clamp(0, pages == 0 ? 0 : pages - 1);
    final rows = report.rows.skip(page * size).take(size);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (count == 0)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Tidak ada piutang layanan terverifikasi yang cocok dengan filter.',
              textAlign: TextAlign.center,
            ),
          )
        else
          LayoutBuilder(
            builder: (context, bounds) => ScrollConfiguration(
              behavior: ScrollConfiguration.of(context)
                  .copyWith(scrollbars: false),
              child: Scrollbar(
                controller: _scroll,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scroll,
                  primary: false,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SizedBox(
                    width: bounds.maxWidth.clamp(1300, double.infinity),
                    child: _table(rows, page * size),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 20,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('$count data terverifikasi'),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Piutang Layanan Terverifikasi',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Rp ${report.total.toString().replaceAllMapped(RegExp(r"\B(?=(\d{3})+(?!\d))"), (_) => ".")}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (pages > 0)
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: page > 0
                        ? () => setState(() => _page = page - 1)
                        : null,
                    child: const Text('Previous'),
                  ),
                  Text('${page + 1} / $pages'),
                  OutlinedButton(
                    onPressed: page + 1 < pages
                        ? () => setState(() => _page = page + 1)
                        : null,
                    child: const Text('Next'),
                  ),
                ],
              ),
          ],
        ),
        if (report.reviews.isNotEmpty) ...[
          const SizedBox(height: 12),
          ExpansionTile(
            key: const Key('piutang-review'),
            tilePadding: EdgeInsets.zero,
            title: Text('Perlu Ditinjau (${report.reviews.length})'),
            subtitle: const Text(
              'Data ini dikecualikan dari total dan ekspor terverifikasi.',
            ),
            children: [
              for (final item in report.reviews)
                ListTile(
                  dense: true,
                  title: Text(
                    '${item.number.trim().isEmpty ? "Nomor kosong" : item.number} · ${piutangDomain(item.domain)} · ID ${item.id}',
                  ),
                  subtitle: Text(item.reason),
                ),
            ],
          ),
        ],
      ],
    );
  }

  DataTable _table(Iterable<PiutangRow> rows, int offset) => DataTable(
    horizontalMargin: 10,
    columnSpacing: 12,
    headingRowColor: const WidgetStatePropertyAll(AppColors.bgLight),
    headingTextStyle: const TextStyle(
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    dataRowMinHeight: 52,
    dataRowMaxHeight: 60,
    border: const TableBorder(
      horizontalInside: BorderSide(color: AppColors.divider),
    ),
    columns: [
      for (final (label, width) in <(String, TableColumnWidth)>[
        ('No', const FixedColumnWidth(50)),
        ('No Akta', const FixedColumnWidth(136)),
        ('NIK Pemohon', const FixedColumnWidth(158)),
        ('Nama Pemohon', const FlexColumnWidth(2)),
        ('Jenis Pekerjaan', const FixedColumnWidth(105)),
        ('Nama Pekerjaan', const FlexColumnWidth(3)),
        ('Kategori', const FlexColumnWidth(2)),
        ('Total Layanan', const FixedColumnWidth(150)),
        ('Total Piutang Layanan', const FixedColumnWidth(150)),
        ('Nama Petugas', const FlexColumnWidth(2)),
      ])
        DataColumn(
          columnWidth: width,
          headingRowAlignment: MainAxisAlignment.center,
          label: Flexible(
            child: Text(label, textAlign: TextAlign.center, softWrap: true),
          ),
        ),
    ],
    rows: [
      for (final (index, row) in rows.indexed)
        DataRow(
          key: ValueKey(row.id),
          cells: [
            _cell('${offset + index + 1}'),
            _cell(row.number),
            _cell(row.nik),
            _cell(row.applicant),
            _cell(piutangDomain(row.domain)),
            _cell(row.jobs),
            _cell(row.categories),
            _cell(formatPaymentRupiah(row.billed)),
            _cell(formatPaymentRupiah(row.remaining)),
            _cell(row.officer),
          ],
        ),
    ],
  );

  DataCell _cell(String? value) {
    final label = value == null || value.trim().isEmpty ? '—' : value;
    return DataCell(
      Center(
        child: Tooltip(
          message: label,
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Future<void> _export(PiutangFilter filter) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final count = await widget.exporter.run(
        repository: ref.read(piutangRepositoryProvider),
        currentSession: () =>
            mounted ? ref.read(authControllerProvider).session : null,
        filter: filter,
      );
      if (mounted && count != null) {
        _message('Excel tersimpan. $count piutang layanan diekspor.');
      }
    } on FileSystemException {
      if (mounted) {
        _message('Excel gagal disimpan. Pilih nama dan lokasi file baru.');
      }
    } on StateError catch (error) {
      if (mounted) _message(error.message);
    } catch (_) {
      if (mounted) _message('Ekspor Excel gagal.');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _message(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }
}

InputDecoration _dec(String label) => InputDecoration(
  labelText: label,
  isDense: true,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
);

Widget _panel(Widget child) => Material(
  color: AppColors.card,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(10),
    side: const BorderSide(color: AppColors.divider),
  ),
  child: Padding(padding: const EdgeInsets.all(16), child: child),
);
