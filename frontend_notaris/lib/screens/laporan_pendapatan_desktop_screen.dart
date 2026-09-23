import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/searchable_dropdown.dart';

class LaporanPendapatanDesktopScreen extends StatefulWidget {
  const LaporanPendapatanDesktopScreen({super.key});

  @override
  State<LaporanPendapatanDesktopScreen> createState() =>
      _LaporanPendapatanDesktopScreenState();
}

class _LaporanPendapatanDesktopScreenState
    extends State<LaporanPendapatanDesktopScreen> {
  DateTime _tanggalAwal = DateTime(2026, 9, 1);
  DateTime _tanggalAkhir = DateTime(2026, 9, 20);
  String? _selectedJenisPembayaran = 'Semua Jenis Pembayaran';

  final List<String> _jenisPembayaran = const [
    'Semua Jenis Pembayaran',
    'Tunai',
    'Transfer',
    'Non Tunai',
    'Pelunasan',
    'DP',
    'Lainnya',
  ];

  final List<PendapatanDummy> _data = [
    PendapatanDummy(DateTime(2026, 9, 20), 5000000, 1000000, 4000000, 4000000),
    PendapatanDummy(DateTime(2026, 9, 19), 3500000, 500000, 3000000, 7000000),
    PendapatanDummy(DateTime(2026, 9, 18), 2500000, 750000, 1750000, 8750000),
    PendapatanDummy(DateTime(2026, 9, 17), 4000000, 1000000, 3000000, 11750000),
    PendapatanDummy(DateTime(2026, 9, 16), 3000000, 500000, 2500000, 14250000),
    PendapatanDummy(DateTime(2026, 9, 15), 2000000, 250000, 1750000, 16000000),
  ];

  List<PendapatanDummy> get _filteredData {
    return _data.where((item) {
      final date = DateTime(item.tanggal.year, item.tanggal.month, item.tanggal.day);
      final start = DateTime(_tanggalAwal.year, _tanggalAwal.month, _tanggalAwal.day);
      final end = DateTime(_tanggalAkhir.year, _tanggalAkhir.month, _tanggalAkhir.day);
      return !date.isBefore(start) && !date.isAfter(end);
    }).toList();
  }

  int get _totalPenghasilan =>
      _filteredData.fold(0, (sum, item) => sum + item.penghasilan);

  int get _totalPengeluaran =>
      _filteredData.fold(0, (sum, item) => sum + item.pengeluaran);

  int get _totalPendapatan =>
      _filteredData.fold(0, (sum, item) => sum + item.pendapatan);

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

  void _reset() {
    setState(() {
      _tanggalAwal = DateTime(2026, 9, 1);
      _tanggalAkhir = DateTime(2026, 9, 20);
      _selectedJenisPembayaran = 'Semua Jenis Pembayaran';
    });
  }

  void _exportExcel() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export Excel masih berupa prototype.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 700;

        return Padding(
          padding: EdgeInsets.all(mobile ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(mobile),
              const SizedBox(height: 18),
              _filterCard(mobile),
              const SizedBox(height: 16),
              _tableCard(),
            ],
          ),
        );
      },
    );
  }

  Widget _header(bool mobile) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Laporan Pendapatan',
                style: TextStyle(
                  fontSize: mobile ? 22 : 25,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Laporan > Pendapatan',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: _exportExcel,
          icon: const Icon(Icons.file_download_outlined, size: 18),
          label: const Text('Excel'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _filterCard(bool mobile) {
    final children = [
      _dateField(
        'Tanggal Awal',
        _tanggalAwal,
        () => _pickDate(true),
      ),
      _dateField(
        'Tanggal Akhir',
        _tanggalAkhir,
        () => _pickDate(false),
      ),
      SearchableDropdown<String>(
        value: _selectedJenisPembayaran,
        items: _jenisPembayaran,
        label: 'Jenis Pembayaran',
        itemLabel: (item) => item,
        onChanged: (value) {
          setState(() => _selectedJenisPembayaran = value);
        },
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
                  Align(
                    alignment: Alignment.centerRight,
                    child: children[3],
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(child: children[0]),
                  const SizedBox(width: 12),
                  Expanded(child: children[1]),
                  const SizedBox(width: 12),
                  SizedBox(width: 250, child: children[2]),
                  const SizedBox(width: 12),
                  children[3],
                ],
              ),
      ),
    );
  }

  Widget _dateField(
    String label,
    DateTime date,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: AppColors.card,
          suffixIcon: const Icon(
            Icons.calendar_today_outlined,
            size: 18,
          ),
        ),
        child: Text(_formatDate(date)),
      ),
    );
  }

  Widget _tableCard() {
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
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Data Pendapatan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${rows.length} tanggal',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
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
                    DataColumn(label: Text('Penghasilan')),
                    DataColumn(label: Text('Pengeluaran')),
                    DataColumn(label: Text('Pendapatan')),
                    DataColumn(label: Text('Saldo')),
                  ],
                  rows: List.generate(rows.length, (index) {
                    final item = rows[index];

                    return DataRow(
                      cells: [
                        DataCell(Text('${index + 1}')),
                        DataCell(Text(_formatDate(item.tanggal))),
                        DataCell(Text(_rupiah(item.penghasilan))),
                        DataCell(Text(_rupiah(item.pengeluaran))),
                        DataCell(
                          Text(
                            _rupiah(item.pendapatan),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        DataCell(Text(_rupiah(item.saldo))),
                      ],
                    );
                  }),
                ),
              ),
            ),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text('Tidak ada data pendapatan.'),
                ),
              ),
            const Divider(height: 28),
            _totalRow('Total Penghasilan', _totalPenghasilan),
            _totalRow('Total Pengeluaran', _totalPengeluaran),
            _totalRow('Total Pendapatan', _totalPendapatan),
          ],
        ),
      ),
    );
  }

  Widget _totalRow(String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            _rupiah(value),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  static String _rupiah(int value) {
    final text = value.toString();
    final buffer = StringBuffer();

    for (var i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(text[i]);
    }

    return 'Rp. ${buffer.toString()}';
  }

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class PendapatanDummy {
  final DateTime tanggal;
  final int penghasilan;
  final int pengeluaran;
  final int pendapatan;
  final int saldo;

  const PendapatanDummy(
    this.tanggal,
    this.penghasilan,
    this.pengeluaran,
    this.pendapatan,
    this.saldo,
  );
}
