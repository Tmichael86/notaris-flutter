import 'package:flutter/material.dart';

import '../core/widgets/loading_overlay.dart';
import '../core/theme/app_colors.dart';

class KategoriPekerjaanDesktopScreen extends StatefulWidget {
  const KategoriPekerjaanDesktopScreen({super.key});

  @override
  State<KategoriPekerjaanDesktopScreen> createState() =>
      _KategoriPekerjaanDesktopScreenState();
}

class _KategoriPekerjaanDesktopScreenState
    extends State<KategoriPekerjaanDesktopScreen> {
  final _searchController = TextEditingController();
  final _tableController = ScrollController();

  bool _isLoading = false;
  String _searchQuery = '';
  int _currentPage = 1;
  static const int _rowsPerPage = 10;

  final List<_KategoriPekerjaan> _data = [
    _KategoriPekerjaan('1', 'Perorangan', '18/09/2026 08:30'),
    _KategoriPekerjaan('2', 'Badan Hukum', '18/09/2026 08:25'),
    _KategoriPekerjaan('3', 'Instansi', '17/09/2026 15:10'),
    _KategoriPekerjaan('4', 'Bank', '17/09/2026 13:45'),
    _KategoriPekerjaan('5', 'Developer', '16/09/2026 10:20'),
    _KategoriPekerjaan('6', 'Lainnya', '15/09/2026 09:15'),
  ];

  List<_KategoriPekerjaan> get _filteredData {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return List.of(_data);

    return _data
        .where((e) =>
            e.nama.toLowerCase().contains(q) ||
            e.createdAt.toLowerCase().contains(q))
        .toList();
  }

  List<_KategoriPekerjaan> get _pageData {
    final data = _filteredData;
    final start = (_currentPage - 1) * _rowsPerPage;
    if (start >= data.length) return const [];

    final end = (start + _rowsPerPage).clamp(0, data.length);
    return data.sublist(start, end);
  }

  int get _totalPages =>
      _filteredData.isEmpty ? 1 : (_filteredData.length / _rowsPerPage).ceil();

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      message: 'Memproses data...',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 700;

          return Padding(
            padding: EdgeInsets.fromLTRB(
              mobile ? 16 : 28,
              20,
              mobile ? 16 : 28,
              30,
            ),
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
      label: Text(mobile ? 'Tambah' : 'Tambah'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryConfirm,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );

    if (mobile) {
      return Row(
        children: [
          const Expanded(
            child: Text(
              'Kategori Pekerjaan',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w500),
            ),
          ),
          button,
        ],
      );
    }

    return Row(
      children: [
        const Text(
          'Kategori Pekerjaan',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 14),
        Text(
          'Master  |  Kategori Pekerjaan',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        ),
        const Spacer(),
        button,
      ],
    );
  }

  Widget _buildTablePanel(bool mobile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E5E5)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 8,
            offset: Offset(0, 2),
            color: Color(0x10000000),
          ),
        ],
      ),
      child: Column(
        children: [
          if (mobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSearchField(),
                const SizedBox(height: 12),
                _dataCount(),
              ],
            )
          else
            Row(
              children: [
                _buildSearchField(),
                const Spacer(),
                _dataCount(),
              ],
            ),
          const SizedBox(height: 16),
          _buildTable(),
          const SizedBox(height: 14),
          _buildFooter(mobile),
        ],
      ),
    );
  }

  Widget _dataCount() => Text(
        '${_filteredData.length} data',
        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
      );

  Widget _buildSearchField() {
    return SizedBox(
      width: 280,
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
            _currentPage = 1;
          });
        },
        decoration: InputDecoration(
          hintText: 'Cari data...',
          prefixIcon: const Icon(Icons.search, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(7)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
          dataRowMaxHeight: 76,
          columns: const [
            DataColumn(label: Text('No')),
            DataColumn(label: Text('Nama')),
            DataColumn(label: Text('Created At')),
            DataColumn(label: Text('Aksi')),
          ],
          rows: List.generate(rows.length, (index) {
            final item = rows[index];

            return DataRow(
              cells: [
                DataCell(Text(
                  '${((_currentPage - 1) * _rowsPerPage) + index + 1}',
                )),
                DataCell(SizedBox(
                  width: 300,
                  child: Text(
                    item.nama,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                )),
                DataCell(SizedBox(
                  width: 220,
                  child: Text(item.createdAt),
                )),
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Edit',
                      onPressed:
                          _isLoading ? null : () => _showForm(item: item),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Hapus',
                      onPressed: _isLoading ? null : () => _delete(item),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                )),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildFooter(bool mobile) {
    final total = _filteredData.length;
    final start = total == 0 ? 0 : ((_currentPage - 1) * _rowsPerPage) + 1;
    final end = total == 0
        ? 0
        : (_currentPage * _rowsPerPage > total
            ? total
            : _currentPage * _rowsPerPage);

    final text = total == 0
        ? 'Tidak ada data'
        : 'Menampilkan $start-$end dari $total data';

    final pagination = Wrap(
      spacing: 6,
      children: [
        OutlinedButton(
          onPressed:
              _currentPage > 1 ? () => setState(() => _currentPage--) : null,
          child: const Text('Previous'),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.primaryConfirm,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$_currentPage',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        OutlinedButton(
          onPressed: _currentPage < _totalPages
              ? () => setState(() => _currentPage++)
              : null,
          child: const Text('Next'),
        ),
      ],
    );

    if (mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 10),
          pagination,
        ],
      );
    }

    return Row(
      children: [
        Text(text,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        const Spacer(),
        pagination,
      ],
    );
  }

  Future<void> _showForm({_KategoriPekerjaan? item}) async {
    final isEdit = item != null;
    final nama = TextEditingController(text: item?.nama ?? '');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isEdit ? 'Edit Kategori Pekerjaan' : 'Tambah Kategori'),
        content: SizedBox(
          width: 480,
          child: TextField(
            controller: nama,
            autofocus: true,
            decoration: _decoration('Nama'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Tutup'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (nama.text.trim().isEmpty) {
                _validation(dialogContext, 'Nama wajib diisi.');
                return;
              }

              Navigator.pop(dialogContext);

              await _processAction(() async {
                await Future.delayed(const Duration(milliseconds: 900));

                if (isEdit) {
                  item.nama = nama.text.trim();
                } else {
                  _data.insert(
                    0,
                    _KategoriPekerjaan(
                      DateTime.now().millisecondsSinceEpoch.toString(),
                      nama.text.trim(),
                      _formatNow(),
                    ),
                  );
                }
              });
            },
            icon: const Icon(Icons.save_outlined, size: 18),
            label: Text(isEdit ? 'Simpan Perubahan' : 'Simpan'),
          ),
        ],
      ),
    );

    nama.dispose();
  }

  Future<void> _delete(_KategoriPekerjaan item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Peringatan!'),
        content: Text(
          'Apakah Anda yakin ingin menghapus kategori "${item.nama}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tidak'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await _processAction(() async {
      await Future.delayed(const Duration(milliseconds: 900));
      _data.remove(item);

      if (_currentPage > _totalPages) {
        _currentPage = _totalPages;
      }
    });
  }

  Future<void> _processAction(Future<void> Function() action) async {
    if (_isLoading || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _validation(BuildContext ctx, String message) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(content: Text(message)),
    );
    return false;
  }

  String _formatNow() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');

    return '${two(now.day)}/${two(now.month)}/${now.year} '
        '${two(now.hour)}:${two(now.minute)}';
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(7)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      );

  @override
  void dispose() {
    _searchController.dispose();
    _tableController.dispose();
    super.dispose();
  }
}

class _KategoriPekerjaan {
  String id;
  String nama;
  String createdAt;

  _KategoriPekerjaan(this.id, this.nama, this.createdAt);
}
