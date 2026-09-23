import 'package:flutter/material.dart';

import '../core/widgets/loading_overlay.dart';
import '../core/widgets/searchable_dropdown.dart';
import '../core/theme/app_colors.dart';

class PekerjaanNotarisDesktopScreen extends StatefulWidget {
  const PekerjaanNotarisDesktopScreen({super.key});

  @override
  State<PekerjaanNotarisDesktopScreen> createState() =>
      _PekerjaanNotarisDesktopScreenState();
}

class _PekerjaanNotarisDesktopScreenState
    extends State<PekerjaanNotarisDesktopScreen> {
  final _searchController = TextEditingController();
  final _tableController = ScrollController();

  bool _isLoading = false;
  String _searchQuery = '';
  int _currentPage = 1;
  static const int _rowsPerPage = 10;

  final List<String> _kategoriOptions = const [
    'Akta Jual Beli',
    'Akta Hibah',
    'Akta Waris',
    'Akta Kuasa',
    'Perjanjian',
    'Lainnya',
  ];

  final List<_PekerjaanNotaris> _data = [
    _PekerjaanNotaris(
      id: '1',
      nama: 'Akta Jual Beli',
      harga: [
        _HargaNotaris('Akta Jual Beli', 2500000, '3 Hari'),
        _HargaNotaris('Perjanjian', 3000000, '5 Hari'),
      ],
      proses: [
        _ProsesNotaris('Pemeriksaan Dokumen', 'Pemeriksaan kelengkapan dokumen pemohon.', ['KTP', 'KK', 'Sertifikat']),
        _ProsesNotaris('Pembuatan Akta', 'Penyusunan dan pemeriksaan draft akta.', ['Draft Akta', 'Data Para Pihak']),
      ],
    ),
    _PekerjaanNotaris(
      id: '2',
      nama: 'Akta Hibah',
      harga: [_HargaNotaris('Akta Hibah', 2000000, '3 Hari')],
      proses: [_ProsesNotaris('Verifikasi Dokumen', 'Verifikasi identitas dan dokumen objek hibah.', ['KTP', 'KK', 'Sertifikat'])],
    ),
    _PekerjaanNotaris(
      id: '3',
      nama: 'Surat Kuasa',
      harga: [_HargaNotaris('Akta Kuasa', 750000, '1 Hari')],
      proses: [_ProsesNotaris('Pembuatan Surat Kuasa', 'Pembuatan dan pemeriksaan surat kuasa.', ['KTP Pemberi Kuasa', 'KTP Penerima Kuasa'])],
    ),
    _PekerjaanNotaris(
      id: '4',
      nama: 'Perjanjian Kerja Sama',
      harga: [_HargaNotaris('Perjanjian', 1500000, '2 Hari')],
      proses: [_ProsesNotaris('Penyusunan Perjanjian', 'Penyusunan draft berdasarkan kebutuhan para pihak.', ['Identitas Para Pihak', 'Draft Perjanjian'])],
    ),
    _PekerjaanNotaris(
      id: '5',
      nama: 'Akta Waris',
      harga: [_HargaNotaris('Akta Waris', 3500000, '7 Hari')],
      proses: [_ProsesNotaris('Pemeriksaan Ahli Waris', 'Pemeriksaan data dan dokumen ahli waris.', ['KTP', 'KK', 'Surat Keterangan Waris'])],
    ),
  ];

  List<_PekerjaanNotaris> get _filteredData {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return List.of(_data);
    return _data.where((e) =>
      e.nama.toLowerCase().contains(q) ||
      e.harga.any((h) => h.kategori.toLowerCase().contains(q)) ||
      e.proses.any((p) => p.nama.toLowerCase().contains(q))
    ).toList();
  }

  List<_PekerjaanNotaris> get _pageData {
    final data = _filteredData;
    final start = (_currentPage - 1) * _rowsPerPage;
    if (start >= data.length) return const [];
    final end = (start + _rowsPerPage).clamp(0, data.length);
    return data.sublist(start, end);
  }

  int get _totalPages => _filteredData.isEmpty ? 1 : (_filteredData.length / _rowsPerPage).ceil();

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      message: 'Memproses data...',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 700;
          return Padding(
            padding: EdgeInsets.fromLTRB(mobile ? 16 : 28, 20, mobile ? 16 : 28, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(mobile),
                const SizedBox(height: 18),
                _buildTablePanel(mobile),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(bool mobile) {
    final button = ElevatedButton.icon(
      onPressed: _isLoading ? null : () => _showForm(),
      icon: const Icon(Icons.add, size: 18),
      label: Text(mobile ? 'Tambah' : 'Tambah Pekerjaan'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryConfirm,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );

    if (mobile) {
      return Row(children: [
        const Expanded(child: Text('Pekerjaan Notaris', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w500))),
        button,
      ]);
    }

    return Row(children: [
      const Text('Pekerjaan Notaris', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w500)),
      const SizedBox(width: 14),
      Text('Master  |  Pekerjaan Notaris', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
      const Spacer(),
      button,
    ]);
  }

  Widget _buildTablePanel(bool mobile) {
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
        if (mobile)
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _buildSearchField(),
            const SizedBox(height: 12),
            Text('${_filteredData.length} data', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ])
        else
          Row(children: [
            _buildSearchField(),
            const Spacer(),
            Text('${_filteredData.length} data', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ]),
        const SizedBox(height: 16),
        _buildTable(),
        const SizedBox(height: 14),
        _buildFooter(mobile),
      ]),
    );
  }

  Widget _buildSearchField() {
    return SizedBox(
      width: 280,
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() { _searchQuery = value; _currentPage = 1; }),
        decoration: InputDecoration(
          hintText: 'Cari data...',
          prefixIcon: const Icon(Icons.search, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(7)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
      ),
    );
  }

  Widget _buildTable() {
    final rows = _pageData;
    return Scrollbar(
      controller: _tableController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _tableController,
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
          rows: List.generate(rows.length, (index) {
            final item = rows[index];
            return DataRow(cells: [
              DataCell(Text('${((_currentPage - 1) * _rowsPerPage) + index + 1}')),
              DataCell(SizedBox(width: 260, child: Text(item.nama, maxLines: 2, overflow: TextOverflow.ellipsis))),
              DataCell(SizedBox(width: 210, child: _multiText(item.harga.map((e) => _rupiah(e.harga)).toList()))),
              DataCell(SizedBox(width: 180, child: _multiText(item.harga.map((e) => e.estimasiWaktu).toList()))),
              DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(tooltip: 'Edit', onPressed: _isLoading ? null : () => _showForm(item: item), icon: const Icon(Icons.edit_outlined)),
                IconButton(tooltip: 'Hapus', onPressed: _isLoading ? null : () => _delete(item), icon: const Icon(Icons.delete_outline)),
              ])),
            ]);
          }),
        ),
      ),
    );
  }

  Widget _multiText(List<String> values) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: values.map((v) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(v))).toList(),
  );

  Widget _buildFooter(bool mobile) {
    final total = _filteredData.length;
    final start = total == 0 ? 0 : ((_currentPage - 1) * _rowsPerPage) + 1;
    final end = total == 0 ? 0 : (_currentPage * _rowsPerPage > total ? total : _currentPage * _rowsPerPage);
    final text = total == 0 ? 'Tidak ada data' : 'Menampilkan $start-$end dari $total data';
    final pagination = Wrap(spacing: 6, children: [
      OutlinedButton(onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null, child: const Text('Previous')),
      Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9), decoration: BoxDecoration(color: AppColors.primaryConfirm, borderRadius: BorderRadius.circular(6)), child: Text('$_currentPage', style: const TextStyle(color: Colors.white))),
      OutlinedButton(onPressed: _currentPage < _totalPages ? () => setState(() => _currentPage++) : null, child: const Text('Next')),
    ]);
    if (mobile) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(text, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)), const SizedBox(height: 10), pagination]);
    return Row(children: [Text(text, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)), const Spacer(), pagination]);
  }

  Future<void> _showForm({_PekerjaanNotaris? item}) async {
    final isEdit = item != null;
    final nama = TextEditingController(text: item?.nama ?? '');
    final hargaRows = (item?.harga ?? [_HargaNotaris(_kategoriOptions.first, 0, '')]).map((e) => _HargaNotaris(e.kategori, e.harga, e.estimasiWaktu)).toList();
    final prosesRows = (item?.proses ?? [_ProsesNotaris('', '', [''])]).map((e) => _ProsesNotaris(e.nama, e.detail, List<String>.from(e.atribut))).toList();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final mobile = MediaQuery.sizeOf(context).width < 700;
          return AlertDialog(
            title: Text(isEdit ? 'Edit Pekerjaan Notaris' : 'Tambah Pekerjaan Notaris'),
            content: SizedBox(
              width: mobile ? double.infinity : 900,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .72),
                child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Informasi Pekerjaan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  TextField(controller: nama, decoration: _decoration('Nama Pekerjaan')),
                  const SizedBox(height: 22),
                  const Text('Harga Pekerjaan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  ...List.generate(hargaRows.length, (i) => _hargaForm(hargaRows[i], hargaRows, i, mobile, () => setDialogState(() {}))),
                  OutlinedButton.icon(
                    onPressed: _availableCategories(hargaRows).isEmpty ? null : () => setDialogState(() => hargaRows.add(_HargaNotaris(_availableCategories(hargaRows).first, 0, ''))),
                    icon: const Icon(Icons.add, size: 18), label: const Text('Tambah Harga'),
                  ),
                  const SizedBox(height: 24),
                  const Text('Proses Pekerjaan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  ...List.generate(prosesRows.length, (i) => _prosesForm(prosesRows[i], prosesRows, i, mobile, () => setDialogState(() {}))),
                  OutlinedButton.icon(
                    onPressed: () => setDialogState(() => prosesRows.add(_ProsesNotaris('', '', ['']))),
                    icon: const Icon(Icons.add, size: 18), label: const Text('Tambah Proses'),
                  ),
                ])),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Batal')),
              ElevatedButton.icon(
              onPressed: () async {
                if (nama.text.trim().isEmpty) {
                  _validation(
                    dialogContext,
                    'Nama pekerjaan wajib diisi.',
                  );
                  return;
                }

                if (!_validateHarga(dialogContext, hargaRows)) {
                  return;
                }

                if (!_validateProses(dialogContext, prosesRows)) {
                  return;
                }

                Navigator.pop(dialogContext);

                await _processAction(
                  isEdit ? 'Mengubah data...' : 'Menyimpan data...',
                  () async {
                    await Future.delayed(
                      const Duration(milliseconds: 900),
                    );

                    final newItem = _PekerjaanNotaris(
                      id: item?.id ??
                          DateTime.now().millisecondsSinceEpoch.toString(),
                      nama: nama.text.trim(),
                      harga: hargaRows
                          .map(
                            (e) => _HargaNotaris(
                              e.kategori,
                              e.harga,
                              e.estimasiWaktu.trim(),
                            ),
                          )
                          .toList(),
                      proses: prosesRows
                          .map(
                            (e) => _ProsesNotaris(
                              e.nama.trim(),
                              e.detail.trim(),
                              e.atribut
                                  .where(
                                    (a) => a.trim().isNotEmpty,
                                  )
                                  .map((a) => a.trim())
                                  .toList(),
                            ),
                          )
                          .toList(),
                    );

                    if (isEdit) {
                      final i = _data.indexOf(item);

                      if (i != -1) {
                        _data[i] = newItem;
                      }
                    } else {
                      _data.insert(0, newItem);
                    }
                  },
                );
              },
                icon: const Icon(Icons.save_outlined, size: 18), label: Text(isEdit ? 'Simpan Perubahan' : 'Simpan'),
              ),
            ],
          );
        },
      ),
    );
    nama.dispose();
  }

  Widget _hargaForm(_HargaNotaris row, List<_HargaNotaris> all, int index, bool mobile, VoidCallback refresh) {
    final categories = _availableCategories(all, current: row.kategori);
    final price = TextEditingController(text: row.harga == 0 ? '' : row.harga.toString());
    final eta = TextEditingController(text: row.estimasiWaktu);
    final category = SearchableDropdown<String>(
      value: row.kategori,
      items: categories.isEmpty ? [row.kategori] : categories,
      label: 'Kategori Pekerjaan',
      onChanged: (v) { if (v != null) { row.kategori = v; refresh(); } },
    );
    final priceField = TextField(controller: price, keyboardType: TextInputType.number, decoration: _decoration('Harga'), onChanged: (v) => row.harga = int.tryParse(v.replaceAll('.', '').replaceAll(',', '')) ?? 0);
    final etaField = TextField(controller: eta, decoration: _decoration('Estimasi Waktu'), onChanged: (v) => row.estimasiWaktu = v);
    final remove = all.length == 1 ? null : () => refresh();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: mobile ? Column(children: [category, const SizedBox(height: 10), Row(children: [Expanded(child: priceField), const SizedBox(width: 10), Expanded(child: etaField), IconButton(onPressed: remove == null ? null : () { all.removeAt(index); refresh(); }, icon: const Icon(Icons.delete_outline))])]) : Row(children: [Expanded(flex: 3, child: category), const SizedBox(width: 10), Expanded(flex: 2, child: priceField), const SizedBox(width: 10), Expanded(flex: 2, child: etaField), IconButton(onPressed: remove == null ? null : () { all.removeAt(index); refresh(); }, icon: const Icon(Icons.delete_outline))]),
    );
  }

  Widget _prosesForm(_ProsesNotaris row, List<_ProsesNotaris> all, int index, bool mobile, VoidCallback refresh) {
    final name = TextEditingController(text: row.nama);
    final detail = TextEditingController(text: row.detail);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE5E5E5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text('Proses ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w600))), IconButton(onPressed: all.length == 1 ? null : () { all.removeAt(index); refresh(); }, icon: const Icon(Icons.delete_outline))]),
        TextField(controller: name, decoration: _decoration('Nama Proses'), onChanged: (v) => row.nama = v),
        const SizedBox(height: 10),
        TextField(controller: detail, maxLines: 3, decoration: _decoration('Detail Proses'), onChanged: (v) => row.detail = v),
        const SizedBox(height: 12),
        const Text('Atribut', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...List.generate(row.atribut.length, (a) {
          final attr = TextEditingController(text: row.atribut[a]);
          return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [Expanded(child: TextField(controller: attr, decoration: _decoration('Atribut ${a + 1}'), onChanged: (v) => row.atribut[a] = v)), IconButton(onPressed: row.atribut.length == 1 ? null : () { row.atribut.removeAt(a); refresh(); }, icon: const Icon(Icons.delete_outline))]));
        }),
        OutlinedButton.icon(onPressed: () { row.atribut.add(''); refresh(); }, icon: const Icon(Icons.add, size: 17), label: const Text('Tambah Atribut')),
      ]),
    );
  }

  List<String> _availableCategories(List<_HargaNotaris> rows, {String? current}) {
    final used = rows.where((r) => r.kategori != current).map((r) => r.kategori).toSet();
    return _kategoriOptions.where((e) => !used.contains(e)).toList();
  }

  bool _validateHarga(BuildContext ctx, List<_HargaNotaris> rows) {
    final used = <String>{};
    for (final row in rows) {
      if (!used.add(row.kategori)) return _validation(ctx, 'Kategori pekerjaan tidak boleh sama.');
      if (row.harga <= 0) return _validation(ctx, 'Harga harus lebih dari 0.');
      if (row.estimasiWaktu.trim().isEmpty) return _validation(ctx, 'Estimasi waktu wajib diisi.');
    }
    return true;
  }

  bool _validateProses(BuildContext ctx, List<_ProsesNotaris> rows) {
    for (final row in rows) {
      if (row.nama.trim().isEmpty) return _validation(ctx, 'Nama proses wajib diisi.');
      if (row.detail.trim().isEmpty) return _validation(ctx, 'Detail proses wajib diisi.');
    }
    return true;
  }

  bool _validation(BuildContext ctx, String message) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(message)));
    return false;
  }

  Future<void> _delete(_PekerjaanNotaris item) async {
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Peringatan!'),
      content: Text('Apakah Anda yakin ingin menghapus pekerjaan "${item.nama}"?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Tidak')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
      ],
    ));
    if (confirmed != true || !mounted) return;
    await _processAction('Menghapus data...', () async {
      await Future.delayed(const Duration(milliseconds: 900));
      _data.remove(item);
    });
  }

  Future<void> _processAction(String message, Future<void> Function() action) async {
    if (_isLoading || !mounted) return;
    setState(() => _isLoading = true);
    try { await action(); } finally { if (mounted) setState(() => _isLoading = false); }
  }

  String _rupiah(int value) {
    final s = value.toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) { b.write(s[i]); final left = s.length - i - 1; if (left > 0 && left % 3 == 0) b.write('.'); }
    return 'Rp $b';
  }

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(7)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
  );

  @override
  void dispose() { _searchController.dispose(); _tableController.dispose(); super.dispose(); }
}

class _PekerjaanNotaris {
  String id;
  String nama;
  List<_HargaNotaris> harga;
  List<_ProsesNotaris> proses;
  _PekerjaanNotaris({required this.id, required this.nama, required this.harga, required this.proses});
}

class _HargaNotaris {
  String kategori;
  int harga;
  String estimasiWaktu;
  _HargaNotaris(this.kategori, this.harga, this.estimasiWaktu);
}

class _ProsesNotaris {
  String nama;
  String detail;
  List<String> atribut;
  _ProsesNotaris(this.nama, this.detail, this.atribut);
}
