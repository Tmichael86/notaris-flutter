import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/widgets/loading_overlay.dart';
import '../core/widgets/searchable_dropdown.dart';

class PemohonDesktopScreen extends StatefulWidget {
  const PemohonDesktopScreen({super.key});

  @override
  State<PemohonDesktopScreen> createState() => _PemohonDesktopScreenState();
}

class _PemohonDesktopScreenState extends State<PemohonDesktopScreen> {
  final _searchController = TextEditingController();
  final _horizontalScrollController = ScrollController();

  final List<PemohonData> _items = [
    PemohonData('3507010101900001', 'Budi Santoso', 'Laki-laki', '081234567890',
        'Jl. Merdeka No. 10, Blitar', DateTime(2026, 7, 1, 8, 30)),
    PemohonData('3507020202910002', 'Siti Rahma', 'Perempuan', '082233445566',
        'Jl. Diponegoro No. 12, Kediri', DateTime(2026, 7, 2, 9, 15)),
    PemohonData('3507030303920003', 'Andi Pratama', 'Laki-laki', '083344556677',
        'Jl. Soekarno Hatta No. 5, Malang', DateTime(2026, 7, 3, 10)),
    PemohonData('3507040404930004', 'Dewi Lestari', 'Perempuan', '084455667788',
        'Jl. Kenanga No. 8, Blitar', DateTime(2026, 7, 4, 11, 20)),
    PemohonData('3507050505940005', 'Rizky Maulana', 'Laki-laki', '085566778899',
        'Jl. Ahmad Yani No. 20, Tulungagung', DateTime(2026, 7, 5, 13, 45)),
    PemohonData('3507060606950006', 'Nadia Putri', 'Perempuan', '086677889900',
        'Jl. Raya Darmo No. 15, Surabaya', DateTime(2026, 7, 6, 14, 10)),
  ];

  bool _isLoading = false;
  int _currentPage = 1;
  static const _pageSize = 5;

  List<PemohonData> get _filteredItems {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items.where((x) =>
      x.nik.toLowerCase().contains(q) ||
      x.nama.toLowerCase().contains(q) ||
      x.jenisKelamin.toLowerCase().contains(q) ||
      x.noTelp.toLowerCase().contains(q)
    ).toList();
  }

  List<PemohonData> get _pageItems {
    final data = _filteredItems;
    final start = (_currentPage - 1) * _pageSize;
    if (start >= data.length) return [];
    final end = (start + _pageSize).clamp(0, data.length);
    return data.sublist(start, end);
  }

  int get _pageCount =>
      _filteredItems.isEmpty ? 1 : ((_filteredItems.length - 1) ~/ _pageSize) + 1;

  void _showForm({PemohonData? item}) {
    final isEdit = item != null;
    final nik = TextEditingController(text: item?.nik ?? '');
    final nama = TextEditingController(text: item?.nama ?? '');
    final telp = TextEditingController(text: item?.noTelp ?? '');
    final alamat = TextEditingController(text: item?.alamat ?? '');
    String? gender = item?.jenisKelamin;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Pemohon' : 'Tambah Pemohon'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(children: [
                _row(context, _field('NIK', nik, type: TextInputType.number),
                    _field('Nama', nama)),
                const SizedBox(height: 12),
                _row(context,
                    _genderDropdown(gender, (v) => setDialogState(() => gender = v)),
                    _field('Telp', telp, type: TextInputType.phone)),
                const SizedBox(height: 12),
                _field('Alamat', alamat, maxLines: 4),
              ]),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (nik.text.trim().isEmpty || nama.text.trim().isEmpty || gender == null) {
                  _message('Lengkapi data wajib terlebih dahulu.');
                  return;
                }

                setState(() => _isLoading = true);
                Navigator.pop(dialogContext);

                Future.delayed(const Duration(milliseconds: 700), () {
                  if (!mounted) return;
                  setState(() {
                    if (isEdit) {
                      item.nik = nik.text.trim();
                      item.nama = nama.text.trim();
                      item.jenisKelamin = gender!;
                      item.noTelp = telp.text.trim();
                      item.alamat = alamat.text.trim();
                    } else {
                      _items.insert(0, PemohonData(
                        nik.text.trim(), nama.text.trim(), gender!,
                        telp.text.trim(), alamat.text.trim(), DateTime.now(),
                      ));
                    }
                    _isLoading = false;
                    _currentPage = 1;
                  });
                });
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Simpan'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      for (final c in [nik, nama, telp, alamat]) {
        c.dispose();
      }
    });
  }

  Widget _row(BuildContext context, Widget a, Widget b) => LayoutBuilder(
    builder: (context, c) => c.maxWidth < 500
        ? Column(children: [a, const SizedBox(height: 12), b])
        : Row(children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)]),
  );

  Widget _field(String label, TextEditingController c,
      {TextInputType? type, int maxLines = 1}) =>
      TextField(
        controller: c,
        keyboardType: type,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      );

  Widget _genderDropdown(String? value, ValueChanged<String?> onChanged) =>
      SearchableDropdown<String>(
        label: 'Jenis Kelamin',
        hint: 'Pilih jenis kelamin',
        value: value,
        items: const ['Laki-laki', 'Perempuan'],
        itemLabel: (x) => x,
        onChanged: onChanged,
      );

  void _delete(PemohonData item) {
    setState(() => _isLoading = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        _items.remove(item);
        _isLoading = false;
        if (_currentPage > _pageCount) _currentPage = _pageCount;
      });
    });
  }

  void _message(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => LoadingOverlay(
    isLoading: _isLoading,
    message: 'Memproses data...',
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _header(),
        const SizedBox(height: 20),
        _table(),
      ]),
    ),
  );

  Widget _header() => Row(children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Pemohon', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text('Master > Pemohon', style: TextStyle(color: AppColors.textSecondary)),
    ])),
    OutlinedButton.icon(
      onPressed: () => _message('Export Excel dummy.'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
      ),
      icon: const Icon(Icons.file_download_outlined),
      label: const Text('Excel'),
    ),
    const SizedBox(width: 10),
    FilledButton.icon(
      onPressed: () => _showForm(),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      icon: const Icon(Icons.add),
      label: const Text('Tambah'),
    ),
  ]);

  Widget _table() {
    final data = _pageItems;
    return Card(
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(children: [
          Row(children: [
            Expanded(child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() => _currentPage = 1),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Cari NIK, nama, atau no telp...',
                border: OutlineInputBorder(),
              ),
            )),
            const SizedBox(width: 14),
            Text('${_filteredItems.length} data'),
          ]),
          const SizedBox(height: 16),
          Scrollbar(
            controller: _horizontalScrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _horizontalScrollController,
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 30,
                columns: const [
                  DataColumn(label: Text('No')),
                  DataColumn(label: Text('NIK')),
                  DataColumn(label: Text('Nama')),
                  DataColumn(label: Text('Jenis Kelamin')),
                  DataColumn(label: Text('No Telp')),
                  DataColumn(label: Text('Created At')),
                  DataColumn(label: Text('Aksi')),
                ],
                rows: [
                  for (var i = 0; i < data.length; i++)
                    DataRow(cells: [
                      DataCell(Text('${((_currentPage - 1) * _pageSize) + i + 1}')),
                      DataCell(Text(data[i].nik)),
                      DataCell(Text(data[i].nama)),
                      DataCell(Text(data[i].jenisKelamin)),
                      DataCell(Text(data[i].noTelp)),
                      DataCell(Text(_formatDateTime(data[i].createdAt))),
                      DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          tooltip: 'Edit',
                          onPressed: () => _showForm(item: data[i]),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Hapus',
                          onPressed: () => _delete(data[i]),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ])),
                    ]),
                ],
              ),
            ),
          ),
          if (data.isEmpty) const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Tidak ada data.'),
          ),
          const SizedBox(height: 12),
          _pagination(),
        ]),
      ),
    );
  }

  Widget _pagination() => Row(mainAxisAlignment: MainAxisAlignment.end, children: [
    IconButton(
      onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
      icon: const Icon(Icons.chevron_left),
    ),
    Text('Halaman $_currentPage / $_pageCount'),
    IconButton(
      onPressed: _currentPage < _pageCount ? () => setState(() => _currentPage++) : null,
      icon: const Icon(Icons.chevron_right),
    ),
  ]);

  static String _formatDateTime(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _searchController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }
}

class PemohonData {
  PemohonData(this.nik, this.nama, this.jenisKelamin, this.noTelp, this.alamat, this.createdAt);

  String nik;
  String nama;
  String jenisKelamin;
  String noTelp;
  String alamat;
  DateTime createdAt;
}
