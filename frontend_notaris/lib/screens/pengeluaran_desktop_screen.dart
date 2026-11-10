import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/widgets/loading_overlay.dart';
import '../core/widgets/searchable_dropdown.dart';
import '../database/app_database.dart';
import '../providers/auth_provider.dart';
import '../providers/pekerjaan_provider.dart';
import '../providers/pengeluaran_provider.dart';
import '../repositories/pengeluaran_repository.dart';

class PengeluaranDesktopScreen extends ConsumerStatefulWidget {
  const PengeluaranDesktopScreen({super.key});

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

  bool _allows(PengeluaranAction action) =>
      allowsPengeluaran(ref.read(authControllerProvider).session, action);

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider).session;
    if (!allowsPengeluaran(session, PengeluaranAction.read)) {
      return const Padding(
        padding: EdgeInsets.all(28),
        child: Text('Anda tidak memiliki izin membaca Pengeluaran.'),
      );
    }
    final result = ref.watch(
      pengeluaranPageProvider((
        from: _from,
        through: _through,
        jenisId: _jenisId,
        search: _search.text,
        page: _page,
      )),
    );
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
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pengeluaran',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text('Tersimpan pada perangkat ini'),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: _allows(PengeluaranAction.create)
                          ? () => _showForm()
                          : null,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Tambah Pengeluaran'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryConfirm,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _filters(compact),
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
                        data: (page) => _table(compact, page),
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

  Widget _filters(bool compact) {
    final jenis = ref.watch(pengeluaranFilterJenisProvider);
    return _panel(
      LayoutBuilder(
        builder: (context, constraints) {
          const gap = 12.0;
          final width = compact
              ? constraints.maxWidth
              : (constraints.maxWidth - 3 * gap) / 4;
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
                      label: 'Jenis Pengeluaran',
                      onChanged: (id) => setState(() {
                        _jenisId = id == 0 ? null : id;
                        _page = 0;
                      }),
                    );
                  },
                ),
              ),
              OutlinedButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reset'),
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

  Widget _table(bool compact, PengeluaranPage page) {
    if (page.count == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            _from == null &&
                    _through == null &&
                    _jenisId == null &&
                    _search.text.trim().isEmpty
                ? 'Belum ada pengeluaran.'
                : 'Tidak ada pengeluaran yang cocok dengan filter.',
          ),
        ),
      );
    }
    final canUpdate = _allows(PengeluaranAction.update);
    final canDelete = _allows(PengeluaranAction.delete);
    const size = PengeluaranRepository.pageSize;
    final pages = (page.count + size - 1) ~/ size;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Scrollbar(
          controller: _tableController,
          thumbVisibility: true,
          notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
          child: SingleChildScrollView(
            controller: _tableController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 8),
            child: DataTable(
              columnSpacing: compact ? 28 : 26,
              headingRowColor: const WidgetStatePropertyAll(Color(0xFFF5F5F5)),
              columns: const [
                DataColumn(label: Text('#')),
                DataColumn(label: Text('No. Faktur')),
                DataColumn(label: Text('Keterangan')),
                DataColumn(label: Text('Jenis Pengeluaran')),
                DataColumn(label: Text('Jumlah')),
                DataColumn(label: Text('Tanggal Pengeluaran')),
                DataColumn(label: Text('Aksi')),
              ],
              rows: [
                for (final (index, row) in page.rows.indexed)
                  DataRow(
                    key: ValueKey(row.uuid),
                    cells: [
                      DataCell(Text('${page.page * size + index + 1}')),
                      DataCell(Text(row.noFaktur ?? '—')),
                      DataCell(
                        SizedBox(
                          width: 230,
                          child: Text(
                            row.keterangan,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text(row.jenisNama)),
                      DataCell(Text(_rupiah(row.nominal.toString()))),
                      DataCell(Text(_displayDate(row.tanggal.toUtc()))),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit',
                              onPressed: canUpdate
                                  ? () => _showForm(item: row)
                                  : null,
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Hapus',
                              onPressed: canDelete ? () => _delete(row) : null,
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 20,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('${page.count} data'),
            Text(
              'Total Pengeluaran: ${_rupiah(page.total.toString())}',
              style: const TextStyle(
                color: Color(0xFFBC7D7D),
                fontWeight: FontWeight.w700,
              ),
            ),
            Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: page.page > 0
                      ? () => setState(() => _page = page.page - 1)
                      : null,
                  child: const Text('Previous'),
                ),
                Text('${page.page + 1} / $pages'),
                OutlinedButton(
                  onPressed: page.page + 1 < pages
                      ? () => setState(() => _page = page.page + 1)
                      : null,
                  child: const Text('Next'),
                ),
              ],
            ),
          ],
        ),
      ],
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
        builder: (ctx) => AlertDialog(
          title: const Text('Hapus Pengeluaran?'),
          content: Text('Hapus pengeluaran ${row.noFaktur ?? row.keterangan}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Hapus'),
            ),
          ],
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
      child: AlertDialog(
        title: Text(item == null ? 'Tambah Pengeluaran' : 'Edit Pengeluaran'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
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
                    builder: (field) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SearchableDropdown<int>(
                          value: _jenisId,
                          items: labels.keys.toList(),
                          itemLabel: (id) => labels[id] ?? 'Pilih jenis',
                          label: 'Jenis Pengeluaran',
                          enabled: allowed && !_saving && labels.isNotEmpty,
                          onChanged: (id) {
                            field.didChange(id);
                            setState(() => _jenisId = id);
                          },
                        ),
                        if (field.errorText != null)
                          Text(
                            field.errorText!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                      ],
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
                    maxLines: 3,
                    decoration: _dec('Keterangan'),
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
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton.icon(
            onPressed: !allowed || _saving || labels.isEmpty ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: const Text('Simpan'),
          ),
        ],
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
  Widget build(BuildContext context) => InkWell(
    onTap: onChanged == null
        ? null
        : () async {
            final date = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(1),
              lastDate: DateTime(9999, 12, 31),
            );
            if (context.mounted && date != null) onChanged!(date);
          },
    child: InputDecorator(
      decoration: _dec(label).copyWith(
        suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
      ),
      child: Text(value == null ? '—' : _displayDate(value!)),
    ),
  );
}

InputDecoration _dec(String label) => InputDecoration(
  labelText: label,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(7)),
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
);

Widget _panel(Widget child) => Container(
  width: double.infinity,
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: const Color(0xFFE5E5E5)),
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
