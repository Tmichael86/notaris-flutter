import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/widgets/loading_overlay.dart';
import '../core/widgets/searchable_dropdown.dart';
import '../core/widgets/transaction_review_dialog.dart';
import '../database/app_database.dart';
import '../providers/auth_provider.dart';
import '../providers/pekerjaan_provider.dart';
import '../providers/pengeluaran_provider.dart';
import '../repositories/pengeluaran_repository.dart';
import '../services/pengeluaran_excel_export.dart';

class PengeluaranDesktopScreen extends ConsumerStatefulWidget {
  const PengeluaranDesktopScreen({
    super.key,
    this.exporter = const PengeluaranExcelExport(),
  });

  final PengeluaranExcelExport exporter;

  @override
  ConsumerState<PengeluaranDesktopScreen> createState() =>
      _PengeluaranDesktopScreenState();
}

class _PengeluaranDesktopScreenState
    extends ConsumerState<PengeluaranDesktopScreen> {
  final _tableController = ScrollController();
  final _search = TextEditingController();
  DateTime? _from, _through;
  int? _jenisId;
  int _page = 0;
  bool _deleting = false;
  bool _deleteOpen = false;
  bool _formOpen = false;
  bool _exporting = false;

  bool _allows(PengeluaranAction action) =>
      allowsPengeluaran(ref.read(authControllerProvider).session, action);

  PengeluaranFilter get _filter => (
    from: _from,
    through: _through,
    jenisId: _jenisId,
    search: _search.text,
    page: _page,
  );

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider).session;
    if (!allowsPengeluaran(session, PengeluaranAction.read)) {
      return const Padding(
        padding: EdgeInsets.all(28),
        child: Text('Anda tidak memiliki izin membaca Pengeluaran.'),
      );
    }
    final result = ref.watch(pengeluaranPageProvider(_filter));
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 700;
        return LoadingOverlay(
          isLoading: _deleting,
          message: 'Menghapus data...',
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 16 : 28,
              20,
              compact ? 16 : 28,
              30,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(stack: constraints.maxWidth < 555),
                const SizedBox(height: 18),
                _filters(),
                const SizedBox(height: 18),
                _panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (compact)
                        const _TableTitle()
                      else
                        Row(
                          children: [
                            const Expanded(child: _TableTitle()),
                            SizedBox(width: 260, child: _searchField()),
                          ],
                        ),
                      if (compact) ...[
                        const SizedBox(height: 12),
                        _searchField(),
                      ],
                      const SizedBox(height: 16),
                      result.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (_, _) =>
                            const Text('Daftar Pengeluaran gagal dimuat.'),
                        data: _table,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _header({required bool stack}) {
    const title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pengeluaran',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Tersimpan pada perangkat ini',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ],
    );
    final add = ElevatedButton.icon(
      onPressed: _allows(PengeluaranAction.create) ? () => _showForm() : null,
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Tambah Pengeluaran'),
      style: _primaryButton,
    );
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (Platform.isWindows)
          Tooltip(
            message: 'Ekspor seluruh hasil filter ke Excel',
            child: OutlinedButton.icon(
              onPressed: _exporting ? null : _export,
              icon: const Icon(Icons.table_view_outlined, size: 18),
              label: Text(_exporting ? 'Mengekspor…' : 'Excel'),
              style: _secondaryButton.copyWith(
                foregroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.disabled)
                      ? null
                      : Colors.green.shade800,
                ),
              ),
            ),
          ),
        add,
      ],
    );
    return stack
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 12), actions],
          )
        : Row(
            children: [
              Expanded(child: title),
              const SizedBox(width: 16),
              actions,
            ],
          );
  }

  Future<void> _export() async {
    if (_exporting || !_allows(PengeluaranAction.read)) return;
    final filter = _filter;
    String? jenisLabel;
    if (filter.jenisId != null) {
      for (final kind
          in ref.read(pengeluaranFilterJenisProvider).asData?.value ??
              <PengeluaranJenisData>[]) {
        if (kind.id == filter.jenisId) {
          jenisLabel = kind.nama;
          break;
        }
      }
    }
    setState(() => _exporting = true);
    try {
      final count = await widget.exporter.run(
        repository: ref.read(pengeluaranRepositoryProvider),
        currentSession: () =>
            mounted ? ref.read(authControllerProvider).session : null,
        filter: filter,
        jenisLabel: jenisLabel,
      );
      if (count != null && mounted) {
        _message('Excel tersimpan. $count pengeluaran diekspor.');
      }
    } on FileSystemException {
      if (mounted) {
        _message(
          'Excel gagal disimpan. Pilih nama baru dan folder yang dapat ditulis di luar penyimpanan dokumen transaksi.',
        );
      }
    } on PengeluaranFailure catch (error) {
      if (mounted) _message(error.message);
    } catch (_) {
      if (mounted) _message('Ekspor Excel gagal.');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Widget _filters() {
    final jenis = ref.watch(pengeluaranFilterJenisProvider);
    return _panel(
      LayoutBuilder(
        builder: (context, constraints) {
          const gap = 12.0;
          final available = constraints.maxWidth;
          final columns = available >= 680 ? 4 : (available >= 370 ? 2 : 1);
          final resetWidth = columns == 4 ? 104.0 : 0.0;
          final width =
              (available - (columns - 1) * gap - resetWidth) /
              (columns == 4 ? 3 : columns);
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              SizedBox(
                width: width,
                child: _dateField('Dari Tanggal', _from, (date) {
                  if (_through != null && date.isAfter(_through!)) {
                    _message(
                      'Dari Tanggal tidak boleh setelah Sampai Tanggal.',
                    );
                    return;
                  }
                  setState(() {
                    _from = date;
                    _page = 0;
                  });
                }),
              ),
              SizedBox(
                width: width,
                child: _dateField('Sampai Tanggal', _through, (date) {
                  if (_from != null && date.isBefore(_from!)) {
                    _message(
                      'Sampai Tanggal tidak boleh sebelum Dari Tanggal.',
                    );
                    return;
                  }
                  setState(() {
                    _through = date;
                    _page = 0;
                  });
                }),
              ),
              SizedBox(
                width: width,
                child: jenis.when(
                  loading: () => const Text('Memuat Jenis Pengeluaran…'),
                  error: (_, _) =>
                      const Text('Jenis Pengeluaran gagal dimuat.'),
                  data: (rows) {
                    final labels = <int, String>{
                      0: 'Semua jenis',
                      for (final row in rows)
                        row.id: row.status == 1 && row.deletedAt == null
                            ? row.nama
                            : '${row.nama} (nonaktif)',
                    };
                    if (_jenisId case final selected?) {
                      labels.putIfAbsent(
                        selected,
                        () => 'Jenis terpilih (nonaktif)',
                      );
                    }
                    return SearchableDropdown<int>(
                      value: _jenisId ?? 0,
                      items: labels.keys.toList(),
                      itemLabel: (id) => labels[id]!,
                      decoration: _dropdownDecoration,
                      onChanged: (id) => setState(() {
                        _jenisId = id == 0 ? null : id;
                        _page = 0;
                      }),
                    );
                  },
                ),
              ),
              SizedBox(
                width: columns == 4 ? resetWidth : width,
                child: OutlinedButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Reset'),
                  style: _secondaryButton,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _searchField() => TextField(
    controller: _search,
    onChanged: (_) => setState(() => _page = 0),
    decoration: _dec('Cari faktur atau keterangan')
        .copyWith(prefixIcon: const Icon(Icons.search)),
  );

  Widget _table(PengeluaranPage page) {
    const size = PengeluaranRepository.pageSize;
    final empty = page.count == 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (empty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              _from == null &&
                      _through == null &&
                      _jenisId == null &&
                      _search.text.trim().isEmpty
                  ? 'Belum ada pengeluaran.'
                  : 'Tidak ada pengeluaran yang cocok dengan filter.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) => ScrollConfiguration(
              behavior: ScrollConfiguration.of(context)
                  .copyWith(scrollbars: false),
              child: Scrollbar(
                controller: _tableController,
                thumbVisibility: true,
                notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
                child: SingleChildScrollView(
                  key: const Key('pengeluaran-table-scroll'),
                  controller: _tableController,
                  primary: false,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SizedBox(
                    width: constraints.maxWidth.clamp(900, double.infinity),
                    child: DataTable(
                      horizontalMargin: 10,
                      columnSpacing: 14,
                      headingRowHeight: 46,
                      headingRowColor: const WidgetStatePropertyAll(
                        AppColors.bgLight,
                      ),
                      headingTextStyle: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      dataRowMinHeight: 52,
                      dataRowMaxHeight: 56,
                      dividerThickness: 1,
                      border: const TableBorder(
                        horizontalInside: BorderSide(color: AppColors.divider),
                      ),
                      columns: [
                        _column('#', const FixedColumnWidth(48)),
                        _column('No. Faktur', const FixedColumnWidth(126)),
                        _column('Keterangan', const FlexColumnWidth(3)),
                        _column('Jenis Pengeluaran', const FlexColumnWidth(2)),
                        _column('Jumlah', const FixedColumnWidth(138)),
                        _column(
                          'Tanggal Pengeluaran',
                          const FixedColumnWidth(152),
                        ),
                        _column('Aksi', const FixedColumnWidth(114)),
                      ],
                      rows: [
                        for (final (index, row) in page.rows.indexed)
                          DataRow(
                            key: ValueKey(row.uuid),
                            cells: [
                              DataCell(
                                _cell('${page.page * size + index + 1}'),
                              ),
                              DataCell(
                                _cell(row.noFaktur ?? '—', tooltip: true),
                              ),
                              DataCell(_cell(row.keterangan, tooltip: true)),
                              DataCell(_cell(row.jenisNama, tooltip: true)),
                              DataCell(_cell(_rupiah(row.nominal.toString()))),
                              DataCell(
                                _cell(_displayDate(row.tanggal.toUtc())),
                              ),
                              DataCell(_actions(row)),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 14),
        _tableFooter(page),
      ],
    );
  }

  DataColumn _column(String label, TableColumnWidth width) => DataColumn(
    columnWidth: width,
    headingRowAlignment: MainAxisAlignment.center,
    label: Flexible(
      child: Text(
        label,
        textAlign: TextAlign.center,
        softWrap: true,
        maxLines: 2,
      ),
    ),
  );

  Widget _cell(String value, {bool tooltip = false}) {
    final text = Text(
      value,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );
    return Center(
      child: tooltip ? Tooltip(message: value, child: text) : text,
    );
  }

  Widget _actions(PengeluaranData row) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton(
        tooltip: 'Edit',
        iconSize: 19,
        onPressed: _allows(PengeluaranAction.update)
            ? () => _showForm(item: row)
            : null,
        icon: const Icon(Icons.edit_outlined),
      ),
      IconButton(
        tooltip: 'Hapus',
        iconSize: 19,
        color: AppColors.primaryDark,
        onPressed: _allows(PengeluaranAction.delete)
            ? () => _delete(row)
            : null,
        icon: const Icon(Icons.delete_outline),
      ),
    ],
  );

  Widget _tableFooter(PengeluaranPage page) {
    const size = PengeluaranRepository.pageSize;
    final pages = (page.count + size - 1) ~/ size;
    final summary = Wrap(
      spacing: 20,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '${page.count} data',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Total Pengeluaran',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            Text(
              _rupiah(page.total.toString()),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
    if (pages == 0) return summary;
    final navigation = Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton(
          style: _secondaryButton,
          onPressed: page.page > 0
              ? () => setState(() => _page = page.page - 1)
              : null,
          child: const Text('Previous'),
        ),
        Text('${page.page + 1} / $pages'),
        OutlinedButton(
          style: _secondaryButton,
          onPressed: page.page + 1 < pages
              ? () => setState(() => _page = page.page + 1)
              : null,
          child: const Text('Next'),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < 560
          ? Wrap(
              spacing: 24,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [summary, navigation],
            )
          : Row(
              children: [
                Expanded(child: summary),
                const SizedBox(width: 16),
                navigation,
              ],
            ),
    );
  }

  Widget _dateField(
    String label,
    DateTime? value,
    ValueChanged<DateTime> changed,
  ) => _DateField(label: label, value: value, onChanged: changed);

  void _reset() => setState(() {
    _from = null;
    _through = null;
    _jenisId = null;
    _page = 0;
    _search.clear();
  });

  Future<void> _showForm({PengeluaranData? item}) async {
    if (_formOpen ||
        !_allows(
          item == null ? PengeluaranAction.create : PengeluaranAction.update,
        )) {
      return;
    }
    _formOpen = true;
    try {
      final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _PengeluaranForm(item: item),
      );
      if (saved == true && mounted) {
        _message('Pengeluaran tersimpan di perangkat ini.');
      }
    } finally {
      _formOpen = false;
    }
  }

  Future<void> _delete(PengeluaranData row) async {
    if (_deleteOpen || !_allows(PengeluaranAction.delete)) return;
    _deleteOpen = true;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => TransactionReviewDialog(
          title: 'Hapus Pengeluaran?',
          width: 440,
          body: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Hapus pengeluaran ${row.noFaktur ?? row.keterangan}?'),
          ),
          footer: _dialogActions(
            OutlinedButton(
              style: _secondaryButton,
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: _primaryButton,
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Hapus'),
            ),
          ),
        ),
      );
      if (!mounted || confirmed != true) return;
      setState(() => _deleting = true);
      await ref.read(pengeluaranRepositoryProvider).delete(row.id);
      if (mounted) _message('Pengeluaran dihapus dari daftar aktif.');
    } on PengeluaranFailure catch (error) {
      if (mounted) _message(error.message);
    } catch (_) {
      if (mounted) _message('Pengeluaran gagal dihapus.');
    } finally {
      _deleteOpen = false;
      if (mounted && _deleting) setState(() => _deleting = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  void dispose() {
    _tableController.dispose();
    _search.dispose();
    super.dispose();
  }
}

class _TableTitle extends StatelessWidget {
  const _TableTitle();

  @override
  Widget build(BuildContext context) => const Text(
    'Data Pengeluaran',
    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
  );
}

class _PengeluaranForm extends ConsumerStatefulWidget {
  const _PengeluaranForm({this.item});

  final PengeluaranData? item;

  @override
  ConsumerState<_PengeluaranForm> createState() => _PengeluaranFormState();
}

class _PengeluaranFormState extends ConsumerState<_PengeluaranForm> {
  final _form = GlobalKey<FormState>();
  late final _faktur = TextEditingController(text: widget.item?.noFaktur);
  late final _nominal = TextEditingController(
    text: widget.item?.nominal.toString(),
  );
  late final _keterangan = TextEditingController(text: widget.item?.keterangan);
  late DateTime _date =
      widget.item?.tanggal.toUtc() ?? DateUtils.dateOnly(DateTime.now());
  late int? _jenisId = widget.item?.jenisId;
  bool _saving = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final session = ref.watch(authControllerProvider).session;
    final allowed = allowsPengeluaran(
      session,
      item == null ? PengeluaranAction.create : PengeluaranAction.update,
    );
    final jenis = allowed ? ref.watch(pengeluaranJenisProvider) : null;
    final active = {
      for (final row in jenis?.asData?.value ?? <PengeluaranJenisData>[])
        row.id: row.nama,
    };
    final labels = {
      if (item != null && !active.containsKey(item.jenisId))
        item.jenisId: '${item.jenisNama} (jenis tercatat)',
      ...active,
    };
    return PopScope(
      canPop: !_saving,
      child: TransactionReviewDialog(
        title: item == null ? 'Tambah Pengeluaran' : 'Edit Pengeluaran',
        width: 520,
        canClose: !_saving,
        bodyKey: const Key('pengeluaran-form-scroll'),
        body: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _faktur,
                  enabled: !_saving,
                  decoration: _dec('No. Faktur (opsional)'),
                ),
                const SizedBox(height: 12),
                if (jenis?.isLoading == true) const LinearProgressIndicator(),
                if (jenis?.hasError == true)
                  const Text('Jenis Pengeluaran gagal dimuat.'),
                if (jenis?.asData != null && labels.isEmpty)
                  const Text('Belum ada Jenis Pengeluaran aktif.'),
                FormField<int>(
                  initialValue: _jenisId,
                  validator: (value) =>
                      value == null || !labels.containsKey(value)
                      ? 'Pilih Jenis Pengeluaran.'
                      : null,
                  builder: (field) => SearchableDropdown<int>(
                    value: _jenisId,
                    items: labels.keys.toList(),
                    itemLabel: (id) => labels[id] ?? 'Pilih jenis',
                    decoration: _dropdownDecoration.copyWith(
                      errorText: field.errorText,
                    ),
                    enabled: allowed && !_saving && labels.isNotEmpty,
                    onChanged: (id) {
                      field.didChange(id);
                      setState(() => _jenisId = id);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nominal,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  decoration: _dec('Jumlah (Rp)'),
                  validator: (text) => _parseNominal(text) == null
                      ? 'Masukkan nominal Rupiah bulat positif.'
                      : null,
                ),
                const SizedBox(height: 12),
                _DateField(
                  label: 'Tanggal Pengeluaran',
                  value: _date,
                  onChanged: _saving
                      ? null
                      : (date) => setState(() => _date = date),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _keterangan,
                  enabled: !_saving,
                  minLines: 2,
                  maxLines: 3,
                  decoration: _dec('Keterangan')
                      .copyWith(alignLabelWithHint: true),
                  validator: (text) => (text ?? '').trim().isEmpty
                      ? 'Keterangan wajib diisi.'
                      : null,
                ),
                if (!allowed || _error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      allowed
                          ? _error!
                          : 'Anda tidak memiliki izin mengubah Pengeluaran.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        footer: _dialogActions(
          OutlinedButton(
            style: _secondaryButton,
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton.icon(
            style: _primaryButton,
            onPressed: !allowed || _saving || labels.isEmpty ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: const Text('Simpan'),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repository = ref.read(pengeluaranRepositoryProvider);
      final input = (
        noFaktur: _faktur.text,
        tanggal: _date,
        nominal: _parseNominal(_nominal.text)!,
        jenisId: _jenisId!,
        keterangan: _keterangan.text,
      );
      final item = widget.item;
      if (item == null) {
        await repository.create(input);
      } else {
        await repository.update(item.id, input);
      }
      if (mounted) Navigator.pop(context, true);
    } on PengeluaranFailure catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Pengeluaran gagal disimpan.';
        });
      }
    }
  }

  @override
  void dispose() {
    _faktur.dispose();
    _nominal.dispose();
    _keterangan.dispose();
    super.dispose();
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, this.onChanged});

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime>? onChanged;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onChanged == null
          ? null
          : () async {
              final date = await showDatePicker(
                context: context,
                initialDate: value ?? DateTime.now(),
                firstDate: DateTime(1),
                lastDate: DateTime(9999, 12, 31),
                builder: (context, child) => DatePickerTheme(
                  data: DatePickerTheme.of(context).copyWith(
                    backgroundColor: AppColors.card,
                    surfaceTintColor: Colors.transparent,
                  ),
                  child: child!,
                ),
              );
              if (context.mounted && date != null) onChanged!(date);
            },
      child: InputDecorator(
        decoration: _dec(label).copyWith(
          enabled: onChanged != null,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(value == null ? '—' : _displayDate(value!)),
      ),
    ),
  );
}

InputDecoration _dec(String label) => InputDecoration(
  labelText: label,
  isDense: true,
  filled: true,
  fillColor: AppColors.card,
  border: _fieldBorder,
  enabledBorder: _fieldBorder.copyWith(
    borderSide: const BorderSide(color: AppColors.border),
  ),
  focusedBorder: _fieldBorder.copyWith(
    borderSide: const BorderSide(color: AppColors.primaryConfirm, width: 1.5),
  ),
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
  suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 44),
);

const _fieldBorder = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(8)),
);

final _dropdownDecoration = _dec('Jenis Pengeluaran')
    .copyWith(suffixIcon: const Icon(Icons.expand_more, size: 20));

final _primaryButton = ElevatedButton.styleFrom(
  backgroundColor: AppColors.primaryConfirm,
  foregroundColor: AppColors.card,
  minimumSize: const Size(0, 44),
);

final _secondaryButton = OutlinedButton.styleFrom(
  foregroundColor: AppColors.textPrimary,
  minimumSize: const Size(0, 44),
);

Widget _dialogActions(Widget secondary, Widget primary) => Wrap(
  alignment: WrapAlignment.end,
  spacing: 8,
  runSpacing: 8,
  children: [secondary, primary],
);

Widget _panel(Widget child) => Container(
  width: double.infinity,
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: AppColors.card,
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: AppColors.divider),
    boxShadow: const [
      BoxShadow(blurRadius: 8, offset: Offset(0, 2), color: Color(0x10000000)),
    ],
  ),
  child: child,
);

String _displayDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

int? _parseNominal(String? text) {
  final value = text?.trim() ?? '';
  final amount = RegExp(r'^\d+$').hasMatch(value) ? int.tryParse(value) : null;
  return amount != null && amount > 0 ? amount : null;
}

String _rupiah(String value) =>
    'Rp ${value.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}';
