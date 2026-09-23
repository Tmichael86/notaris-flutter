import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/widgets/loading_overlay.dart';
import '../core/widgets/searchable_dropdown.dart';

class PetugasDesktopScreen extends StatefulWidget {
  const PetugasDesktopScreen({super.key});

  @override
  State<PetugasDesktopScreen> createState() => _PetugasDesktopScreenState();
}

class _PetugasDesktopScreenState extends State<PetugasDesktopScreen> {
  final _searchController = TextEditingController();

  final List<PetugasData> _items = [
    PetugasData('3507010101900001', 'Budi Santoso', 'Laki-laki', 'Blitar',
        DateTime(1990, 1, 1), '081234567890', 'budi@blitaris.test', 'Admin Utama',
        'Jl. Merdeka No. 10, Blitar', DateTime(2026, 7, 1, 8, 30)),
    PetugasData('3507020202910002', 'Siti Rahma', 'Perempuan', 'Kediri',
        DateTime(1991, 2, 2), '082233445566', 'siti@blitaris.test', 'Siti Rahma',
        'Jl. Diponegoro No. 12, Kediri', DateTime(2026, 7, 2, 9, 15)),
    PetugasData('3507030303920003', 'Andi Pratama', 'Laki-laki', 'Malang',
        DateTime(1992, 3, 3), '083344556677', 'andi@blitaris.test', 'Andi Pratama',
        'Jl. Soekarno Hatta No. 5, Malang', DateTime(2026, 7, 3, 10)),
    PetugasData('3507040404930004', 'Dewi Lestari', 'Perempuan', 'Blitar',
        DateTime(1993, 4, 4), '084455667788', 'dewi@blitaris.test', 'Dewi Lestari',
        'Jl. Kenanga No. 8, Blitar', DateTime(2026, 7, 4, 11, 20)),
    PetugasData('3507050505940005', 'Rizky Maulana', 'Laki-laki', 'Tulungagung',
        DateTime(1994, 5, 5), '085566778899', 'rizky@blitaris.test', 'Rizky Maulana',
        'Jl. Ahmad Yani No. 20, Tulungagung', DateTime(2026, 7, 5, 13, 45)),
    PetugasData('3507060606950006', 'Nadia Putri', 'Perempuan', 'Surabaya',
        DateTime(1995, 6, 6), '086677889900', 'nadia@blitaris.test', 'Nadia Putri',
        'Jl. Raya Darmo No. 15, Surabaya', DateTime(2026, 7, 6, 14, 10)),
  ];

  bool _isLoading = false;
  int _currentPage = 1;
  static const _pageSize = 5;

  List<PetugasData> get _filteredItems {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items.where((x) =>
      x.nik.toLowerCase().contains(q) ||
      x.nama.toLowerCase().contains(q) ||
      x.jenisKelamin.toLowerCase().contains(q) ||
      x.email.toLowerCase().contains(q) ||
      x.noTelp.toLowerCase().contains(q)
    ).toList();
  }

  List<PetugasData> get _pageItems {
    final data = _filteredItems;
    final start = (_currentPage - 1) * _pageSize;
    if (start >= data.length) return [];
    final end = (start + _pageSize).clamp(0, data.length);
    return data.sublist(start, end);
  }

  int get _pageCount =>
      _filteredItems.isEmpty ? 1 : ((_filteredItems.length - 1) ~/ _pageSize) + 1;

  void _showForm({PetugasData? item}) {
    final isEdit = item != null;
    final nik = TextEditingController(text: item?.nik ?? '');
    final nama = TextEditingController(text: item?.nama ?? '');
    final tempat = TextEditingController(text: item?.tempatLahir ?? '');
    final tanggal = TextEditingController(
      text: item == null ? '' : _formatDate(item.tanggalLahir),
    );
    final telp = TextEditingController(text: item?.noTelp ?? '');
    final email = TextEditingController(text: item?.email ?? '');
    final alamat = TextEditingController(text: item?.alamat ?? '');
    String? gender = item?.jenisKelamin;
    String? user = item?.user;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Petugas' : 'Tambah Petugas'),
          content: SizedBox(
            width: 720,
            child: SingleChildScrollView(
              child: Column(children: [
                _row(context, _field('NIK', nik, type: TextInputType.number),
                    _userDropdown(user, (v) => setDialogState(() => user = v))),
                const SizedBox(height: 12),
                _row(context, _field('Nama', nama),
                    _genderDropdown(gender, (v) => setDialogState(() => gender = v))),
                const SizedBox(height: 12),
                _row(context, _field('Tempat Lahir', tempat),
                    _field('Tanggal Lahir (dd/mm/yyyy)', tanggal)),
                const SizedBox(height: 12),
                _row(context, _field('Telp', telp, type: TextInputType.phone),
                    _field('Email', email, type: TextInputType.emailAddress)),
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
                if (nik.text.trim().isEmpty || nama.text.trim().isEmpty ||
                    tempat.text.trim().isEmpty || tanggal.text.trim().isEmpty ||
                    gender == null || user == null || email.text.trim().isEmpty) {
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
                      item.tempatLahir = tempat.text.trim();
                      item.tanggalLahir = _parseDate(tanggal.text);
                      item.jenisKelamin = gender!;
                      item.noTelp = telp.text.trim();
                      item.email = email.text.trim();
                      item.user = user!;
                      item.alamat = alamat.text.trim();
                    } else {
                      _items.insert(0, PetugasData(
                        nik.text.trim(), nama.text.trim(), gender!, tempat.text.trim(),
                        _parseDate(tanggal.text), telp.text.trim(), email.text.trim(),
                        user!, alamat.text.trim(), DateTime.now(),
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
      for (final c in [nik, nama, tempat, tanggal, telp, email, alamat]) {
        c.dispose();
      }
    });
  }

  Widget _row(BuildContext context, Widget a, Widget b) => LayoutBuilder(
    builder: (context, c) => c.maxWidth < 560
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

  Widget _userDropdown(String? value, ValueChanged<String?> onChanged) =>
      SearchableDropdown<String>(
        label: 'User',
        hint: 'Pilih user',
        value: value,
        items: const [
          'Admin Utama', 'Budi Santoso', 'Siti Rahma', 'Andi Pratama',
          'Dewi Lestari', 'Rizky Maulana', 'Nadia Putri'
        ],
        itemLabel: (x) => x,
        onChanged: onChanged,
      );

  void _delete(PetugasData item) {
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
      const Text('Petugas', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text('Master > Petugas', style: TextStyle(color: AppColors.textSecondary)),
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
                hintText: 'Cari NIK, nama, email, atau no telp...',
                border: OutlineInputBorder(),
              ),
            )),
            const SizedBox(width: 14),
            Text('${_filteredItems.length} data'),
          ]),
          const SizedBox(height: 16),
          Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 28,
                columns: const [
                  DataColumn(label: Text('No')),
                  DataColumn(label: Text('NIK')),
                  DataColumn(label: Text('Nama')),
                  DataColumn(label: Text('Jenis Kelamin')),
                  DataColumn(label: Text('Email')),
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
                      DataCell(Text(data[i].email)),
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

  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String _formatDateTime(DateTime d) =>
      '${_formatDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static DateTime _parseDate(String value) {
    final p = value.split('/');
    if (p.length == 3) {
      final day = int.tryParse(p[0]);
      final month = int.tryParse(p[1]);
      final year = int.tryParse(p[2]);
      if (day != null && month != null && year != null) return DateTime(year, month, day);
    }
    return DateTime.now();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class PetugasData {
  PetugasData(
    this.nik, this.nama, this.jenisKelamin, this.tempatLahir, this.tanggalLahir,
    this.noTelp, this.email, this.user, this.alamat, this.createdAt,
  );

  String nik;
  String nama;
  String jenisKelamin;
  String tempatLahir;
  DateTime tanggalLahir;
  String noTelp;
  String email;
  String user;
  String alamat;
  DateTime createdAt;
}
