import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/widgets/loading_overlay.dart';
import '../core/widgets/searchable_dropdown.dart';
import '../database/app_database.dart';
import '../providers/pekerjaan_provider.dart';
import '../repositories/pekerjaan_repository.dart';

class PekerjaanNotarisDesktopScreen extends ConsumerStatefulWidget {
  const PekerjaanNotarisDesktopScreen({super.key});

  @override
  ConsumerState<PekerjaanNotarisDesktopScreen> createState() => _PekerjaanNotarisDesktopScreenState();
}

class _PekerjaanNotarisDesktopScreenState extends ConsumerState<PekerjaanNotarisDesktopScreen> {
  final _search = TextEditingController();
  final _horizontalScroll = ScrollController();
  final _verticalScroll = ScrollController();
  bool _busy = false;
  String _query = '';
  int _page = 1;
  static const _limit = 10;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(pekerjaanNotarisProvider);
    final categories = ref.watch(pekerjaanKategoriProvider);

    return LoadingOverlay(
      isLoading: _busy,
      message: 'Memproses data...',
      child: LayoutBuilder(builder: (context, c) {
        final mobile = c.maxWidth < 700;
        return Padding(
          padding: EdgeInsets.fromLTRB(mobile ? 16 : 28, 20, mobile ? 16 : 28, 30),
          child: data.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Gagal memuat data: $e')),
            data: (items) => categories.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Gagal memuat kategori: $e')),
              data: (cats) => Column(
                children: [
                  _header(mobile),
                  const SizedBox(height: 18),
                  Expanded(child: _tablePanel(mobile, items, cats)),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _header(bool mobile) => Row(children: [
        Expanded(child: Row(children: [
          Text('Pekerjaan Notaris',
              style: TextStyle(fontSize: mobile ? 23 : 26, fontWeight: FontWeight.w500)),
          if (!mobile) ...[
            const SizedBox(width: 14),
            Text('Master  |  Pekerjaan Notaris',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          ],
        ])),
        ElevatedButton.icon(
          onPressed: _busy ? null : () => _form(),
          icon: const Icon(Icons.add, size: 18),
          label: Text(mobile ? 'Tambah' : 'Tambah Pekerjaan'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryConfirm,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ]);

  Widget _tablePanel(bool mobile, List<PekerjaanNotarisLocal> items,
      List<PekerjaanKategori> cats) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty ? items : items.where((e) => e.nama.toLowerCase().contains(q)).toList();
    final pages = filtered.isEmpty ? 1 : (filtered.length / _limit).ceil();
    if (_page > pages) _page = pages;
    final start = (_page - 1) * _limit;
    final rows = start >= filtered.length
        ? <PekerjaanNotarisLocal>[]
        : filtered.sublist(start, (start + _limit).clamp(0, filtered.length));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E5E5)),
        boxShadow: const [BoxShadow(blurRadius: 8, offset: Offset(0, 2), color: Color(0x10000000))],
      ),
      child: Column(children: [
        Row(children: [
          SizedBox(
            width: mobile ? double.infinity : 280,
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() { _query = v; _page = 1; }),
              decoration: InputDecoration(
                hintText: 'Cari data...',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(7)),
              ),
            ),
          ),
          if (!mobile) const Spacer(),
          if (!mobile) Text('${filtered.length} data'),
        ]),
        if (mobile) Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('${filtered.length} data'),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: rows.isEmpty
              ? const Center(child: Text('Belum ada data pekerjaan.'))
              : _table(rows, cats),
        ),
        const SizedBox(height: 14),
        _footer(mobile, filtered.length, pages),
      ]),
    );
  }

  Widget _table(List<PekerjaanNotarisLocal> rows, List<PekerjaanKategori> cats) =>
      Scrollbar(
        controller: _verticalScroll,
        thumbVisibility: true,
        notificationPredicate: (notification) =>
            notification.metrics.axis == Axis.vertical,
        child: SingleChildScrollView(
          controller: _verticalScroll,
          child: Scrollbar(
            controller: _horizontalScroll,
            thumbVisibility: true,
            notificationPredicate: (notification) =>
                notification.metrics.axis == Axis.horizontal,
            child: SingleChildScrollView(
              controller: _horizontalScroll,
              scrollDirection: Axis.horizontal,
              child: DataTable(
            columnSpacing: 28,
            headingRowHeight: 48,
            dataRowMinHeight: 58,
            dataRowMaxHeight: 110,
            columns: const [
              DataColumn(label: Text('No')),
              DataColumn(label: Text('Pekerjaan')),
              DataColumn(label: Text('Harga')),
              DataColumn(label: Text('Estimasi Waktu')),
              DataColumn(label: Text('Aksi')),
            ],
            rows: List.generate(rows.length, (i) {
              final item = rows[i];
              return DataRow(cells: [
                DataCell(Text(((_page - 1) * _limit + i + 1).toString())),
                DataCell(SizedBox(width: 260, child: Text(item.nama))),
                DataCell(SizedBox(width: 210, child: _aggregate(item.id, false))),
                DataCell(SizedBox(width: 180, child: _aggregate(item.id, true))),
                DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    tooltip: 'Edit',
                    onPressed: _busy ? null : () => _form(item: item),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Hapus',
                    onPressed: _busy ? null : () => _delete(item),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ])),
              ]);
            }),
              ),
            ),
          ),
        ),
      );

  Widget _aggregate(int id, bool eta) {
    final state = ref.watch(pekerjaanNotarisAggregateProvider(id));
    return state.when(
      loading: () => const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, _) => const Text('Gagal'),
      data: (data) {
        if (data == null || data.harga.isEmpty) return const Text('-');
        final values = data.harga.map((e) => eta ? e.estimasiWaktu : _rupiah(int.tryParse(e.harga) ?? 0)).toList();
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: values.map((v) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(v),
          )).toList(),
        );
      },
    );
  }

  Widget _footer(bool mobile, int total, int pages) {
    final start = total == 0 ? 0 : ((_page - 1) * _limit) + 1;
    final end = total == 0 ? 0 : (_page * _limit > total ? total : _page * _limit);
    final text = total == 0 ? 'Tidak ada data' : 'Menampilkan $start-$end dari $total data';
    final buttons = Wrap(spacing: 6, children: [
      OutlinedButton(onPressed: _page > 1 ? () => setState(() => _page--) : null, child: const Text('Previous')),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(color: AppColors.primaryConfirm, borderRadius: BorderRadius.circular(6)),
        child: Text('$_page', style: const TextStyle(color: Colors.white)),
      ),
      OutlinedButton(onPressed: _page < pages ? () => setState(() => _page++) : null, child: const Text('Next')),
    ]);
    return mobile
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(text), const SizedBox(height: 10), buttons])
        : Row(children: [Text(text), const Spacer(), buttons]);
  }

  Future<void> _form({PekerjaanNotarisLocal? item}) async {
    final cats = await ref.read(pekerjaanKategoriProvider.future);
    if (!mounted) return;
    if (cats.isEmpty) {
      _message('Belum ada kategori pekerjaan aktif. Tambahkan kategori terlebih dahulu.');
      return;
    }

    PekerjaanAggregateData? existing;
    if (item != null) {
      existing = await ref.read(pekerjaanNotarisAggregateProvider(item.id).future);
      if (!mounted || existing == null) return;
    }

    final name = TextEditingController(text: existing?.nama ?? '');
    final prices = existing == null
        ? [_HargaRow(null, cats.first.id, cats.first.nama, 0, '')]
        : existing.harga.map((e) => _HargaRow(
            e.id, e.kategoriPekerjaanId, _categoryName(cats, e.kategoriPekerjaanId),
            int.tryParse(e.harga) ?? 0, e.estimasiWaktu)).toList();
    final processes = existing == null
        ? [_ProcessRow(null, '', '', [_AttributeRow(null, '')])]
        : existing.proses.map((e) => _ProcessRow(
            e.id, e.nama, e.detail,
            e.atribut.map((a) => _AttributeRow(a.id, a.atribut ?? '')).toList())).toList();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, refresh) {
        final mobile = MediaQuery.sizeOf(context).width < 700;
        return AlertDialog(
          title: Text(existing == null ? 'Tambah Pekerjaan Notaris' : 'Edit Pekerjaan Notaris'),
          content: SizedBox(
            width: mobile ? double.infinity : 900,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .72),
              child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(controller: name, decoration: _decoration('Nama Pekerjaan')),
                const SizedBox(height: 22),
                const Text('Harga Pekerjaan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                ...List.generate(prices.length, (i) => _priceForm(prices[i], prices, i, cats, mobile, refresh)),
                OutlinedButton.icon(
                  onPressed: _available(prices, cats).isEmpty ? null : () {
                    final c = _available(prices, cats).first;
                    refresh(() => prices.add(_HargaRow(null, c.id, c.nama, 0, '')));
                  },
                  icon: const Icon(Icons.add, size: 18), label: const Text('Tambah Harga'),
                ),
                const SizedBox(height: 24),
                const Text('Proses Pekerjaan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                ...List.generate(processes.length, (i) => _processForm(processes[i], processes, i, mobile, refresh)),
                OutlinedButton.icon(
                  onPressed: () => refresh(() => processes.add(_ProcessRow(null, '', '', [_AttributeRow(null, '')]))),
                  icon: const Icon(Icons.add, size: 18), label: const Text('Tambah Proses'),
                ),
              ])),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Batal')),
            ElevatedButton.icon(
              onPressed: () async {
                if (name.text.trim().isEmpty || !_validatePrices(dialogContext, prices) || !_validateProcesses(dialogContext, processes)) return;
                Navigator.pop(dialogContext);
                await _process(existing == null ? 'Menyimpan data...' : 'Mengubah data...', () async {
                  final input = PekerjaanAggregateInput(
                    nama: name.text.trim(),
                    harga: prices.map((e) => PekerjaanHargaInput(
                      id: e.id, harga: e.harga.toString(), kategoriPekerjaanId: e.kategoriId, estimasiWaktu: e.eta.trim(),
                    )).toList(),
                    proses: processes.map((e) => PekerjaanProsesInput(
                      id: e.id, nama: e.nama.trim(), detail: e.detail.trim(),
                      atribut: e.attributes.where((a) => a.value.trim().isNotEmpty).map((a) =>
                        PekerjaanAtributInput(id: a.id, atribut: a.value.trim())).toList(),
                    )).toList(),
                  );
                  final controller = ref.read(pekerjaanNotarisControllerProvider.notifier);
                  if (existing == null) {
                    await controller.create(input: input);
                  } else {
                    await controller.updateAggregate(id: existing.id, input: input);
                  }
                });
              },
              icon: const Icon(Icons.save_outlined, size: 18),
              label: Text(existing == null ? 'Simpan' : 'Simpan Perubahan'),
            ),
          ],
        );
      }),
    );
    name.dispose();
  }

  Widget _priceForm(_HargaRow row, List<_HargaRow> all, int index,
      List<PekerjaanKategori> cats, bool mobile, StateSetter refresh) {
    final items = cats.where((c) => c.id == row.kategoriId || !all.any((r) => r.kategoriId == c.id)).toList();
    final dropdown = SearchableDropdown<PekerjaanKategori>(
      value: items.where((c) => c.id == row.kategoriId).firstOrNull,
      items: items,
      label: 'Kategori Pekerjaan',
      itemLabel: (c) => c.nama,
      onChanged: (c) {
        if (c == null) return;
        refresh(() { row.kategoriId = c.id; row.kategori = c.nama; });
      },
    );
    final price = TextFormField(
      initialValue: row.harga == 0 ? '' : row.harga.toString(),
      keyboardType: TextInputType.number,
      decoration: _decoration('Harga'),
      onChanged: (v) => row.harga = int.tryParse(v.replaceAll('.', '').replaceAll(',', '')) ?? 0,
    );
    final eta = TextFormField(initialValue: row.eta, decoration: _decoration('Estimasi Waktu'), onChanged: (v) => row.eta = v);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: mobile
          ? Column(children: [
              dropdown, const SizedBox(height: 10),
              Row(children: [
                Expanded(child: price), const SizedBox(width: 10), Expanded(child: eta),
                IconButton(onPressed: all.length == 1 ? null : () => refresh(() => all.removeAt(index)), icon: const Icon(Icons.delete_outline)),
              ]),
            ])
          : Row(children: [
              Expanded(flex: 3, child: dropdown), const SizedBox(width: 10),
              Expanded(flex: 2, child: price), const SizedBox(width: 10),
              Expanded(flex: 2, child: eta),
              IconButton(onPressed: all.length == 1 ? null : () => refresh(() => all.removeAt(index)), icon: const Icon(Icons.delete_outline)),
            ]),
    );
  }

  Widget _processForm(_ProcessRow row, List<_ProcessRow> all, int index,
      bool mobile, StateSetter refresh) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE5E5E5))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('Proses ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w600))),
        IconButton(onPressed: all.length == 1 ? null : () => refresh(() => all.removeAt(index)), icon: const Icon(Icons.delete_outline)),
      ]),
      TextFormField(initialValue: row.nama, decoration: _decoration('Nama Proses'), onChanged: (v) => row.nama = v),
      const SizedBox(height: 10),
      TextFormField(initialValue: row.detail, maxLines: 3, decoration: _decoration('Detail Proses'), onChanged: (v) => row.detail = v),
      const SizedBox(height: 12),
      const Text('Atribut', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      ...List.generate(row.attributes.length, (a) {
        final attribute = row.attributes[a];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Expanded(child: TextFormField(
              initialValue: attribute.value,
              decoration: _decoration('Atribut ${a + 1}'),
              onChanged: (v) => attribute.value = v,
            )),
            IconButton(onPressed: row.attributes.length == 1 ? null : () => refresh(() => row.attributes.removeAt(a)), icon: const Icon(Icons.delete_outline)),
          ]),
        );
      }),
      OutlinedButton.icon(
        onPressed: () => refresh(() => row.attributes.add(_AttributeRow(null, ''))),
        icon: const Icon(Icons.add, size: 17), label: const Text('Tambah Atribut'),
      ),
    ]),
  );

  List<PekerjaanKategori> _available(List<_HargaRow> rows, List<PekerjaanKategori> cats) {
    final used = rows.map((r) => r.kategoriId).toSet();
    return cats.where((c) => !used.contains(c.id)).toList();
  }

  String _categoryName(List<PekerjaanKategori> cats, int id) =>
      cats.where((c) => c.id == id).map((c) => c.nama).firstOrNull ?? 'Kategori #$id';

  bool _validatePrices(BuildContext ctx, List<_HargaRow> rows) {
    if (rows.isEmpty) { _validation(ctx, 'Minimal satu harga harus diisi.'); return false; }
    final used = <int>{};
    for (final row in rows) {
      if (!used.add(row.kategoriId)) { _validation(ctx, 'Kategori pekerjaan tidak boleh sama.'); return false; }
      if (row.harga <= 0) { _validation(ctx, 'Harga harus lebih dari 0.'); return false; }
      if (row.eta.trim().isEmpty) { _validation(ctx, 'Estimasi waktu wajib diisi.'); return false; }
    }
    return true;
  }

  bool _validateProcesses(BuildContext ctx, List<_ProcessRow> rows) {
    if (rows.isEmpty) { _validation(ctx, 'Minimal satu proses harus diisi.'); return false; }
    for (final row in rows) {
      if (row.nama.trim().isEmpty) { _validation(ctx, 'Nama proses wajib diisi.'); return false; }
      if (row.detail.trim().isEmpty) { _validation(ctx, 'Detail proses wajib diisi.'); return false; }
    }
    return true;
  }

  void _validation(BuildContext ctx, String message) =>
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _delete(PekerjaanNotarisLocal item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Peringatan!'),
        content: Text('Apakah Anda yakin ingin menghapus pekerjaan "${item.nama}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Tidak')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _process('Menghapus data...', () async {
      final deleted = await ref.read(pekerjaanNotarisControllerProvider.notifier).delete(item.id);
      if (!deleted) throw StateError('Data pekerjaan tidak ditemukan.');
    });
  }

  Future<void> _process(String message, Future<void> Function() action) async {
    if (_busy || !mounted) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message.replaceFirst('...', ' berhasil.'))));
    } catch (e) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Gagal: $e'), backgroundColor: Colors.red.shade700));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  String _rupiah(int value) {
    final s = value.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      b.write(s[i]);
      final left = s.length - i - 1;
      if (left > 0 && left % 3 == 0) b.write('.');
    }
    return 'Rp $b';
  }

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(7)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
  );

  @override
  void dispose() {
    _search.dispose();
    _horizontalScroll.dispose();
    _verticalScroll.dispose();
    super.dispose();
  }
}

class _HargaRow {
  int? id;
  int kategoriId;
  String kategori;
  int harga;
  String eta;
  _HargaRow(this.id, this.kategoriId, this.kategori, this.harga, this.eta);
}

class _AttributeRow {
  int? id;
  String value;
  _AttributeRow(this.id, this.value);
}

class _ProcessRow {
  int? id;
  String nama;
  String detail;
  List<_AttributeRow> attributes;
  _ProcessRow(this.id, this.nama, this.detail, this.attributes);
}
