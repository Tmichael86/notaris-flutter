import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/loading_overlay.dart';
import '../../core/widgets/searchable_dropdown.dart';

class LaporanMateraiDesktopScreen extends StatefulWidget {
  const LaporanMateraiDesktopScreen({super.key});

  @override
  State<LaporanMateraiDesktopScreen> createState() =>
      _LaporanMateraiDesktopScreenState();
}

class _LaporanMateraiDesktopScreenState
    extends State<LaporanMateraiDesktopScreen> {
  DateTime _tanggalAwal = DateTime(2026, 9, 1);
  DateTime _tanggalAkhir = DateTime(2026, 9, 20);
  String? _selectedPetugas = 'Semua Petugas';
  bool _isLoading = false;

  final List<String> _petugas = const [
    'Semua Petugas',
    'Tegar',
    'Budi Santoso',
    'Siti Aminah',
    'Rina Wulandari',
    'Andi Pratama',
  ];

  final List<MateraiDummy> _data = [
    MateraiDummy(DateTime(2026, 9, 20), 'Penambahan stok materai', 100, 0, 100, 'Tegar'),
    MateraiDummy(DateTime(2026, 9, 19), 'Materai transaksi', 0, 3, 100, 'Budi Santoso'),
    MateraiDummy(DateTime(2026, 9, 18), 'Penambahan stok materai', 50, 0, 103, 'Siti Aminah'),
    MateraiDummy(DateTime(2026, 9, 17), 'Materai transaksi', 0, 5, 53, 'Tegar'),
    MateraiDummy(DateTime(2026, 9, 16), 'Penambahan stok materai', 100, 0, 58, 'Rina Wulandari'),
    MateraiDummy(DateTime(2026, 9, 15), 'Materai transaksi', 0, 2, 58, 'Andi Pratama'),
    MateraiDummy(DateTime(2026, 9, 14), 'Penambahan stok materai', 25, 0, 60, 'Budi Santoso'),
  ];

  List<MateraiDummy> get _filteredData => _data.where((item) {
        final d = DateTime(item.date.year, item.date.month, item.date.day);
        final start = DateTime(_tanggalAwal.year, _tanggalAwal.month, _tanggalAwal.day);
        final end = DateTime(_tanggalAkhir.year, _tanggalAkhir.month, _tanggalAkhir.day);
        final dateOk = !d.isBefore(start) && !d.isAfter(end);
        final petugasOk = _selectedPetugas == 'Semua Petugas' ||
            item.petugas == _selectedPetugas;
        return dateOk && petugasOk;
      }).toList();

  Future<void> _pickDate(bool start) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _tanggalAwal : _tanggalAkhir,
      firstDate: DateTime(2025),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _tanggalAwal = picked;
        if (_tanggalAkhir.isBefore(picked)) _tanggalAkhir = picked;
      } else {
        _tanggalAkhir = picked;
        if (_tanggalAwal.isAfter(picked)) _tanggalAwal = picked;
      }
    });
  }

  Future<void> _addMaterai() async {
    final jumlah = TextEditingController();
    final keterangan = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Materai'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: _formatDate(_tanggalAkhir),
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Tanggal',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: jumlah,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Jumlah Materai',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                readOnly: true,
                initialValue: 'Tegar',
                decoration: InputDecoration(
                  labelText: 'Petugas',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: keterangan,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Keterangan',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Tutup'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final value = int.tryParse(jumlah.text);
              if (value == null || value <= 0) return;

              Navigator.pop(dialogContext);
              setState(() => _isLoading = true);
              await Future.delayed(const Duration(milliseconds: 700));

              final stock = _data.isEmpty ? 0 : _data.first.stok;
              setState(() {
                _data.insert(
                  0,
                  MateraiDummy(
                    _tanggalAkhir,
                    keterangan.text.trim().isEmpty
                        ? 'Penambahan stok materai'
                        : keterangan.text.trim(),
                    value,
                    0,
                    stock + value,
                    'Tegar',
                  ),
                );
                _isLoading = false;
              });
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    jumlah.dispose();
    keterangan.dispose();
  }

  void _reset() {
    setState(() {
      _tanggalAwal = DateTime(2026, 9, 1);
      _tanggalAkhir = DateTime(2026, 9, 20);
      _selectedPetugas = 'Semua Petugas';
    });
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      message: 'Menyimpan data materai...',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 700;
          return Padding(
            padding: EdgeInsets.all(mobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(mobile),
                const SizedBox(height: 18),
                _filters(mobile),
                const SizedBox(height: 16),
                _table(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _header(bool mobile) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Materai',
                    style: TextStyle(
                      fontSize: mobile ? 22 : 25,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    )),
                const SizedBox(height: 5),
                const Text('Laporan > Materai',
                    style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: _addMaterai,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Tambah'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          ),
        ],
      );

  Widget _filters(bool mobile) {
    final children = [
      _dateField('Tanggal Awal', _tanggalAwal, () => _pickDate(true)),
      _dateField('Tanggal Akhir', _tanggalAkhir, () => _pickDate(false)),
      SearchableDropdown<String>(
        value: _selectedPetugas,
        items: _petugas,
        label: 'Petugas',
        itemLabel: (item) => item,
        onChanged: (value) => setState(() => _selectedPetugas = value),
      ),
      OutlinedButton.icon(
        onPressed: _reset,
        icon: const Icon(Icons.refresh, size: 17),
        label: const Text('Reset'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
        ),
      ),
    ];

    return Card(
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: mobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  children[0],
                  const SizedBox(height: 12),
                  children[1],
                  const SizedBox(height: 12),
                  children[2],
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerRight, child: children[3]),
                ],
              )
            : Row(
                children: [
                  Expanded(child: children[0]),
                  const SizedBox(width: 12),
                  Expanded(child: children[1]),
                  const SizedBox(width: 12),
                  SizedBox(width: 230, child: children[2]),
                  const SizedBox(width: 12),
                  children[3],
                ],
              ),
      ),
    );
  }

  Widget _dateField(String label, DateTime date, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: AppColors.card,
            suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
          ),
          child: Text(_formatDate(date)),
        ),
      );

  Widget _table() {
    final rows = _filteredData;
    return Card(
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Data Materai',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      )),
                ),
                Text('${rows.length} data',
                    style: const TextStyle(color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 14),
            Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor:
                      const WidgetStatePropertyAll(AppColors.card),
                  columnSpacing: 42,
                  dividerThickness: 1,
                  headingTextStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                  dataTextStyle: const TextStyle(
                    color: AppColors.textPrimary,
                  ),
                  columns: const [
                    DataColumn(label: Text('#')),
                    DataColumn(label: Text('Tanggal')),
                    DataColumn(label: Text('Keterangan')),
                    DataColumn(label: Text('Materai Masuk')),
                    DataColumn(label: Text('Materai Keluar')),
                    DataColumn(label: Text('Stok Materai')),
                    DataColumn(label: Text('Petugas')),
                  ],
                  rows: List.generate(rows.length, (index) {
                    final item = rows[index];
                    return DataRow(cells: [
                      DataCell(Text('${index + 1}')),
                      DataCell(Text(_formatDate(item.date))),
                      DataCell(Text(item.keterangan)),
                      DataCell(Text('${item.masuk}')),
                      DataCell(Text('${item.keluar}')),
                      DataCell(Text('${item.stok}',
                          style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(Text(item.petugas)),
                    ]);
                  }),
                ),
              ),
            ),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('Tidak ada data materai.')),
              ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class MateraiDummy {
  final DateTime date;
  final String keterangan;
  final int masuk;
  final int keluar;
  final int stok;
  final String petugas;

  const MateraiDummy(
      this.date, this.keterangan, this.masuk, this.keluar, this.stok, this.petugas);
}
