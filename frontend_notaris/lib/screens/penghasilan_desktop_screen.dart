import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../models/transaction_payments.dart';
import '../providers/auth_provider.dart';
import '../providers/penghasilan_provider.dart';
import '../repositories/penghasilan_repository.dart';

class PenghasilanDesktopScreen extends ConsumerStatefulWidget {
  const PenghasilanDesktopScreen({super.key});

  @override
  ConsumerState<PenghasilanDesktopScreen> createState() =>
      _PenghasilanDesktopScreenState();
}

class _PenghasilanDesktopScreenState
    extends ConsumerState<PenghasilanDesktopScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  DateTime? _from, _through;
  String _domain = '', _job = '', _category = '', _status = '';
  int? _officer;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    if (!canReadPenghasilan(ref.watch(authControllerProvider).session)) {
      return const Padding(
        padding: EdgeInsets.all(28),
        child: Text('Anda tidak memiliki izin membaca Penghasilan.'),
      );
    }
    final state = ref.watch(penghasilanReportProvider);
    return LayoutBuilder(
      builder: (context, bounds) => Padding(
        padding: EdgeInsets.fromLTRB(
          bounds.maxWidth < 700 ? 16 : 28,
          20,
          bounds.maxWidth < 700 ? 16 : 28,
          30,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Penghasilan',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Penerimaan pembayaran berdasarkan tanggal bayar',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            state.when(
              loading: () =>
                  _card(const Center(child: CircularProgressIndicator())),
              error: (_, _) =>
                  _card(const Text('Daftar Penghasilan gagal dimuat.')),
              data: (source) {
                final report = source.filtered((
                  from: _from,
                  through: _through,
                  domain: _domain,
                  job: _job,
                  category: _category,
                  status: _status,
                  officer: _officer,
                  search: _search.text,
                ));
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _card(_filters(source.contexts)),
                    const SizedBox(height: 18),
                    _card(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Data Penghasilan',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _search,
                            onChanged: (_) => _change(() {}),
                            decoration:
                                _decoration(
                                  'Cari nomor, NIK, pemohon, pekerjaan atau petugas',
                                ).copyWith(
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    size: 20,
                                  ),
                                ),
                          ),
                          const SizedBox(height: 16),
                          _results(report),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _filters(Iterable<ReceiptContext> contexts) {
    final domainContexts = contexts.where(
      (row) => _domain.isEmpty || row.domain == _domain,
    );
    final jobs = domainContexts.expand((row) => row.jobs);
    Map<String, String> options(Iterable<String> values) => {
      for (final value
          in (values.where((value) => value.isNotEmpty).toSet().toList()
            ..sort()))
        value: value,
    };
    final officers = {
      for (final row in domainContexts)
        if (row.officerId != null && (row.officer?.trim().isNotEmpty ?? false))
          row.officerId!: row.officer!,
    };
    return LayoutBuilder(
      builder: (context, bounds) {
        final columns = bounds.maxWidth >= 780
            ? 4
            : (bounds.maxWidth >= 390 ? 2 : 1);
        final width = (bounds.maxWidth - 12 * (columns - 1)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final control in [
              _dateField('Dari tanggal pembayaran', _from, from: true),
              _dateField('Sampai tanggal pembayaran', _through, from: false),
              _select(
                'Jenis Pekerjaan',
                _domain,
                const {'': 'Semua', 'notaris': 'Notaris', 'ppat': 'PPAT'},
                (value) => _change(() {
                  _domain = value;
                  _job = _category = '';
                  _officer = null;
                }),
              ),
              _select('Pekerjaan', _job, {
                '': 'Semua',
                ...options(jobs.map((job) => job.name)),
              }, (value) => _change(() => _job = value)),
              _select('Kategori', _category, {
                '': 'Semua',
                ...options(jobs.map((job) => job.category)),
              }, (value) => _change(() => _category = value)),
              _select('Status Transaksi', _status, {
                '': 'Semua',
                ...options(contexts.map((row) => row.status)),
              }, (value) => _change(() => _status = value)),
              _select(
                'Petugas',
                _officer ?? 0,
                {0: 'Semua', ...officers},
                (value) => _change(() => _officer = value == 0 ? null : value),
              ),
              OutlinedButton.icon(
                onPressed: () => _change(() {
                  _from = _through = null;
                  _domain = _job = _category = _status = '';
                  _officer = null;
                  _search.clear();
                }),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reset'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              ),
            ])
              SizedBox(width: width, child: control),
          ],
        );
      },
    );
  }

  Widget _select<T>(
    String label,
    T value,
    Map<T, String> options,
    ValueChanged<T> changed,
  ) {
    final labels = {...options};
    labels.putIfAbsent(value, () => 'Pilihan sebelumnya');
    return DropdownButtonFormField<T>(
      key: ValueKey((label, value)),
      initialValue: value,
      isExpanded: true,
      decoration: _decoration(label),
      items: [
        for (final item in labels.entries)
          DropdownMenuItem(
            value: item.key,
            child: Text(
              item.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (next) {
        if (next != null) changed(next);
      },
    );
  }

  Widget _dateField(String label, DateTime? value, {required bool from}) =>
      InkWell(
        onTap: () async {
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
          if ((from && _through != null && picked.isAfter(_through!)) ||
              (!from && _from != null && picked.isBefore(_from!))) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Rentang tanggal pembayaran tidak valid.'),
              ),
            );
            return;
          }
          _change(() {
            if (from) {
              _from = picked;
            } else {
              _through = picked;
            }
          });
        },
        child: InputDecorator(
          decoration: _decoration(label).copyWith(
            suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
          ),
          child: Text(value == null ? '—' : formatPaymentDate(value)),
        ),
      );

  Widget _results(PenghasilanReport report) {
    const size = PenghasilanReport.pageSize;
    final count = report.rows.length;
    final pages = (count + size - 1) ~/ size;
    final page = _page.clamp(0, pages == 0 ? 0 : pages - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (count == 0)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Tidak ada pembayaran terverifikasi yang cocok dengan filter.',
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
                    width: bounds.maxWidth.clamp(1280, double.infinity),
                    child: _table(
                      report.rows.skip(page * size).take(size),
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
          spacing: 20,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('$count pembayaran terverifikasi'),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Dibayar',
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
        if (report.reviews.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('Perlu Ditinjau (${report.reviews.length})'),
            subtitle: const Text(
              'Dikecualikan dari total. Data tanpa tanggal ditampilkan tanpa periode.',
            ),
            children: [
              for (final row in report.reviews)
                ListTile(
                  dense: true,
                  title: Text(
                    '${_present(row.context.number)} · ${row.id == null ? "Transaksi #${row.context.parentId}" : "Pembayaran #${row.id}"}',
                  ),
                  subtitle: Text(row.reason),
                ),
            ],
          ),
      ],
    );
  }

  DataTable _table(Iterable<ReceiptRow> rows, int offset) => DataTable(
    headingRowColor: const WidgetStatePropertyAll(AppColors.bgLight),
    headingTextStyle: const TextStyle(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w600,
    ),
    horizontalMargin: 10,
    columnSpacing: 12,
    dataRowMinHeight: 52,
    dataRowMaxHeight: 60,
    border: const TableBorder(
      horizontalInside: BorderSide(color: AppColors.divider),
    ),
    columns: [
      for (final (label, width) in <(String, TableColumnWidth)>[
        ('No', const FixedColumnWidth(48)),
        ('Tanggal Pembayaran', const FixedColumnWidth(132)),
        ('No. Transaksi', const FixedColumnWidth(140)),
        ('Nama Pemohon', const FlexColumnWidth(2)),
        ('Jenis Pekerjaan', const FixedColumnWidth(108)),
        ('Nama Pekerjaan', const FlexColumnWidth(3)),
        ('Kategori', const FlexColumnWidth(2)),
        ('Jumlah Dibayar', const FixedColumnWidth(145)),
        ('Nama Petugas', const FlexColumnWidth(2)),
        ('Status Transaksi', const FixedColumnWidth(130)),
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
            _cell(formatPaymentDate(row.date)),
            _cell(row.context.number),
            _cell(row.context.applicant),
            _cell(row.context.domain == 'ppat' ? 'PPAT' : 'Notaris'),
            _cell(row.context.jobs.map((job) => _present(job.name)).join('\n')),
            _cell(
              row.context.jobs.map((job) => _present(job.category)).join('\n'),
            ),
            _cell(formatPaymentRupiah(row.amount)),
            _cell(row.context.officer),
            _cell(row.context.status),
          ],
        ),
    ],
  );

  DataCell _cell(String? value) {
    final text = _present(value);
    return DataCell(
      Center(
        child: Tooltip(
          message: text,
          child: Text(
            text,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  void _change(VoidCallback change) => setState(() {
    change();
    _page = 0;
  });

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }
}

String _present(String? value) =>
    value == null || value.trim().isEmpty ? '—' : value;

InputDecoration _decoration(String label) => InputDecoration(
  labelText: label,
  isDense: true,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
);

Widget _card(Widget child) => Material(
  color: AppColors.card,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(10),
    side: const BorderSide(color: AppColors.divider),
  ),
  child: Padding(padding: const EdgeInsets.all(16), child: child),
);
