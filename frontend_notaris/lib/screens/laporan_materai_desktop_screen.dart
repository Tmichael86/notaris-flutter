import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/materai_provider.dart';
import '../repositories/materai_repository.dart';
import '../repositories/materai_stock_repository.dart';
import '../widgets/materai_stock_dialog.dart';

class LaporanMateraiDesktopScreen extends ConsumerStatefulWidget {
  const LaporanMateraiDesktopScreen({super.key});

  @override
  ConsumerState<LaporanMateraiDesktopScreen> createState() =>
      _LaporanMateraiDesktopScreenState();
}

class _LaporanMateraiDesktopScreenState
    extends ConsumerState<LaporanMateraiDesktopScreen> {
  final _search = TextEditingController();
  final _horizontal = ScrollController();
  DateTime? _from, _through;
  String? _officer;
  bool _review = false;
  bool _openingDialog = false;
  int _page = 0;

  @override
  void dispose() {
    _search.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  void _change(VoidCallback update) => setState(() {
    update();
    _page = 0;
  });

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider).session;
    if (!canReadMaterai(session)) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('Anda tidak memiliki izin membaca Laporan Materai.'),
      );
    }
    final state = ref.watch(materaiReportProvider);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Laporan Mutasi Materai',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          const Text(
            'Riwayat mutasi dan stok tercatat dalam lembar.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          if (canCreateMaterai(session)) _stockAction(),
          state.when(
            loading: () =>
                _card(const Center(child: CircularProgressIndicator())),
            error: (_, _) => _card(const Text('Laporan Materai gagal dimuat.')),
            data: (source) {
              if (!source.imported) {
                return _card(
                  const Text(
                    'Belum ada snapshot ledger Materai terverifikasi yang diimpor pada profil ini.',
                  ),
                );
              }
              final report = source.filtered((
                from: _from == null ? null : materaiCalendarDate(_from!),
                through: _through == null
                    ? null
                    : materaiCalendarDate(_through!),
                officer: _officer,
                search: _search.text,
              ));
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _card(_filters(source.officers)),
                  const SizedBox(height: 16),
                  _card(_results(report)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _stockAction() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: ref
        .watch(materaiStockContextProvider)
        .when(
          loading: () => const Text('Memeriksa kesiapan penerimaan stok…'),
          error: (error, _) => Text(
            error is MateraiStockException
                ? error.message
                : 'Kesiapan penerimaan stok tidak dapat diperiksa.',
          ),
          data: (baseline) => baseline == null
              ? const Text('Profil ini hanya membuka laporan baca saja.')
              : Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                    ),
                    onPressed: _openingDialog
                        ? null
                        : () => _openStock(baseline),
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah Stok Materai'),
                  ),
                ),
        ),
  );

  Future<void> _openStock(MateraiStockContext baseline) async {
    final repository = ref.read(materaiStockRepositoryProvider);
    if (_openingDialog || repository == null) return;
    setState(() => _openingDialog = true);
    try {
      if (await showMateraiStockDialog(context, repository, baseline) == true &&
          mounted) {
        _change(() => _review = false);
        ref.invalidate(materaiReportProvider);
      }
    } catch (error) {
      if (mounted) {
        final message = error is MateraiStockException
            ? error.message
            : 'Draf penerimaan tidak dapat dibuka.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) {
        ref.invalidate(materaiStockContextProvider);
        setState(() => _openingDialog = false);
      }
    }
  }

  Widget _filters(Map<String, String> officers) => LayoutBuilder(
    builder: (context, bounds) {
      final columns = bounds.maxWidth >= 900
          ? 4
          : bounds.maxWidth >= 390
          ? 2
          : 1;
      final width = (bounds.maxWidth - 12 * (columns - 1)) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: width,
            child: _dateField('Tanggal Awal', _from, true),
          ),
          SizedBox(
            width: width,
            child: _dateField('Tanggal Akhir', _through, false),
          ),
          SizedBox(
            width: width,
            child: DropdownButtonFormField<String>(
              key: ValueKey(_officer),
              initialValue: _officer ?? '',
              isExpanded: true,
              decoration: _decoration('Petugas'),
              items: [
                const DropdownMenuItem(value: '', child: Text('Semua Petugas')),
                for (final entry in officers.entries)
                  DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) =>
                  _change(() => _officer = value == '' ? null : value),
            ),
          ),
          SizedBox(
            width: width,
            child: TextField(
              controller: _search,
              onChanged: (_) => _change(() {}),
              decoration: _decoration('Cari keterangan')
                  .copyWith(prefixIcon: const Icon(Icons.search)),
            ),
          ),
          OutlinedButton(
            onPressed: () => _change(() {
              _from = _through = null;
              _officer = null;
              _review = false;
              _search.clear();
            }),
            child: const Text('Reset'),
          ),
        ],
      );
    },
  );

  Widget _dateField(
    String label,
    DateTime? value,
    bool start,
  ) => OutlinedButton.icon(
    icon: const Icon(Icons.calendar_today_outlined, size: 18),
    label: Text(
      '$label · ${value == null ? 'Semua' : _displayDate(materaiCalendarDate(value))}',
    ),
    onPressed: () async {
      final picked = await showDatePicker(
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
      if (!mounted || picked == null) return;
      if ((start && _through != null && picked.isAfter(_through!)) ||
          (!start && _from != null && picked.isBefore(_from!))) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rentang tanggal tidak valid.')),
        );
        return;
      }
      _change(() {
        if (start) {
          _from = picked;
        } else {
          _through = picked;
        }
      });
    },
  );

  Widget _results(MateraiReport report) {
    final verified = report.verified.toList();
    final review = report.review.toList();
    final rows = _review ? review : verified;
    const size = MateraiReport.pageSize;
    final pages = (rows.length + size - 1) ~/ size;
    final page = _page.clamp(0, pages == 0 ? 0 : pages - 1);
    final stockIn = verified.fold(
      BigInt.zero,
      (sum, movement) => sum + BigInt.from(movement.stockIn!),
    );
    final stockOut = verified.fold(
      BigInt.zero,
      (sum, movement) => sum + BigInt.from(movement.stockOut!),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: Text('Terverifikasi (${verified.length})'),
              selected: !_review,
              onSelected: (_) => _change(() => _review = false),
            ),
            ChoiceChip(
              label: Text('Perlu Ditinjau (${review.length})'),
              selected: _review,
              onSelected: (_) => _change(() => _review = true),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_review)
          const Text(
            'Data belum terverifikasi. Mutasi tanpa tanggal ditampilkan di luar filter periode.',
          )
        else if (verified.isNotEmpty)
          Text(
            'Masuk $stockIn lembar   ·   Keluar $stockOut lembar',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              _review
                  ? 'Tidak ada mutasi yang perlu ditinjau.'
                  : 'Tidak ada mutasi terverifikasi yang cocok.',
              textAlign: TextAlign.center,
            ),
          )
        else
          LayoutBuilder(
            builder: (context, bounds) => ScrollConfiguration(
              behavior: ScrollConfiguration.of(context)
                  .copyWith(scrollbars: false),
              child: Scrollbar(
                controller: _horizontal,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _horizontal,
                  primary: false,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SizedBox(
                    width: bounds.maxWidth.clamp(
                      _review ? 1060.0 : 860.0,
                      double.infinity,
                    ),
                    child: _table(
                      rows.skip(page * size).take(size),
                      page * size,
                    ),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('${rows.length} mutasi'),
            if (pages > 0)
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: page > 0
                        ? () => setState(() => _page = page - 1)
                        : null,
                    child: const Text('Sebelumnya'),
                  ),
                  Text('${page + 1} / $pages'),
                  OutlinedButton(
                    onPressed: page + 1 < pages
                        ? () => setState(() => _page = page + 1)
                        : null,
                    child: const Text('Berikutnya'),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  DataTable _table(Iterable<MateraiMovement> rows, int offset) => DataTable(
    headingRowColor: const WidgetStatePropertyAll(AppColors.bgLight),
    headingTextStyle: const TextStyle(
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    horizontalMargin: 10,
    columnSpacing: 10,
    dataRowMinHeight: 48,
    dataRowMaxHeight: 58,
    border: const TableBorder(
      horizontalInside: BorderSide(color: AppColors.divider),
    ),
    columns: [
      for (final (label, width) in <(String, TableColumnWidth)>[
        ('No.', const FixedColumnWidth(44)),
        ('Tanggal', const FixedColumnWidth(100)),
        ('Keterangan', const FlexColumnWidth(2)),
        ('Masuk', const FixedColumnWidth(70)),
        ('Keluar', const FixedColumnWidth(70)),
        ('Stok tercatat', const FixedColumnWidth(100)),
        ('Petugas', const FlexColumnWidth(1.5)),
        if (_review) ('Alasan peninjauan', const FlexColumnWidth(2)),
      ])
        DataColumn(
          headingRowAlignment: MainAxisAlignment.center,
          columnWidth: width,
          label: Flexible(child: Text(label, textAlign: TextAlign.center)),
        ),
    ],
    rows: [
      for (final (index, row) in rows.indexed)
        DataRow(
          key: ValueKey(row.id),
          cells: [
            _cell('${offset + index + 1}'),
            _cell(_displayDate(row.businessDate)),
            _cell(row.description),
            _cell(row.stockIn?.toString()),
            _cell(row.stockOut?.toString()),
            _cell(row.recordedStock?.toString()),
            _cell(row.officer),
            if (_review) _cell(row.review),
          ],
        ),
    ],
  );
}

String _displayDate(String? date) => date?.split('-').reversed.join('/') ?? '—';

DataCell _cell(String? value) {
  final text = value == null || value.isEmpty ? '—' : value;
  return DataCell(
    Center(
      child: Tooltip(
        message: text,
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}

InputDecoration _decoration(String label) => InputDecoration(
  labelText: label,
  isDense: true,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
);

Widget _card(Widget child) => Material(
  color: AppColors.card,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(10),
    side: const BorderSide(color: AppColors.divider),
  ),
  child: Padding(padding: const EdgeInsets.all(16), child: child),
);
