import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import 'package:frontend_notaris/core/widgets/searchable_dropdown.dart';
import '../core/utils/debouncer.dart';

enum MonitoringTransactionType { all, notaris, ppat }

class DummyMonitoringItem {
  final String date;
  final String transactionNumber;
  final String nik;
  final String applicant;
  final String job;
  final String category;
  final String officer;
  final String status;
  final String nominal;

  const DummyMonitoringItem({
    required this.date,
    required this.transactionNumber,
    required this.nik,
    required this.applicant,
    required this.job,
    required this.category,
    required this.officer,
    required this.status,
    required this.nominal,
  });
}

class MonitoringDesktopScreen extends StatefulWidget {
  const MonitoringDesktopScreen({super.key});

  @override
  State<MonitoringDesktopScreen> createState() =>
      _MonitoringDesktopScreenState();
}

class _MonitoringDesktopScreenState extends State<MonitoringDesktopScreen> {
  MonitoringTransactionType selectedType = MonitoringTransactionType.all;
  String selectedStatus = 'Semua Status';
  String selectedOfficer = 'Semua Petugas';
  String selectedCategory = 'Semua Kategori';
  String selectedJob = 'Semua Pekerjaan';

  final TextEditingController searchController = TextEditingController();
  final ScrollController tableHorizontalController = ScrollController();
  final _searchDebouncer = Debouncer();

  String _searchQuery = '';

  final List<DummyMonitoringItem> monitoringData = const [
    DummyMonitoringItem(
      date: '11/09/2026',
      transactionNumber: 'NTRX-2026-0001',
      nik: '3505010101000001',
      applicant: 'Budi Santoso',
      job: 'Akta Jual Beli',
      category: 'Jual Beli',
      officer: 'Rina Wulandari',
      status: 'Selesai',
      nominal: 'Rp 1.500.000',
    ),
    DummyMonitoringItem(
      date: '11/09/2026',
      transactionNumber: 'NTRX-2026-0002',
      nik: '3505010101000002',
      applicant: 'Siti Aminah',
      job: 'Akta Kuasa',
      category: 'Kuasa',
      officer: 'Dimas Saputra',
      status: 'Belum Selesai',
      nominal: 'Rp 750.000',
    ),
    DummyMonitoringItem(
      date: '10/09/2026',
      transactionNumber: 'PTRX-2026-0001',
      nik: '3505010101000003',
      applicant: 'Andi Pratama',
      job: 'Akta Jual Beli Tanah',
      category: 'Jual Beli',
      officer: 'Sari Anggraini',
      status: 'Belum Selesai',
      nominal: 'Rp 2.500.000',
    ),
    DummyMonitoringItem(
      date: '09/09/2026',
      transactionNumber: 'NTRX-2026-0003',
      nik: '3505010101000004',
      applicant: 'Dewi Lestari',
      job: 'Akta Hibah',
      category: 'Hibah',
      officer: 'Rina Wulandari',
      status: 'Selesai',
      nominal: 'Rp 1.250.000',
    ),
    DummyMonitoringItem(
      date: '08/09/2026',
      transactionNumber: 'PTRX-2026-0002',
      nik: '3505010101000005',
      applicant: 'Agus Setiawan',
      job: 'Akta Hibah Tanah',
      category: 'Hibah',
      officer: 'Dimas Saputra',
      status: 'Selesai',
      nominal: 'Rp 2.000.000',
    ),
    DummyMonitoringItem(
      date: '07/09/2026',
      transactionNumber: 'NTRX-2026-0004',
      nik: '3505010101000006',
      applicant: 'Fajar Nugroho',
      job: 'Akta Waris',
      category: 'Waris',
      officer: 'Sari Anggraini',
      status: 'Belum Selesai',
      nominal: 'Rp 1.000.000',
    ),
    DummyMonitoringItem(
      date: '06/09/2026',
      transactionNumber: 'PTRX-2026-0003',
      nik: '3505010101000007',
      applicant: 'Maya Putri',
      job: 'Akta Pembagian Hak Bersama',
      category: 'Pembagian Hak',
      officer: 'Rina Wulandari',
      status: 'Belum Selesai',
      nominal: 'Rp 2.250.000',
    ),
  ];

  List<DummyMonitoringItem> get filteredData {
    final query = _searchQuery.trim().toLowerCase();

    return monitoringData.where((item) {
      final matchesType = selectedType == MonitoringTransactionType.all ||
          (selectedType == MonitoringTransactionType.notaris &&
              item.transactionNumber.startsWith('NTRX')) ||
          (selectedType == MonitoringTransactionType.ppat &&
              item.transactionNumber.startsWith('PTRX'));

      final matchesStatus =
          selectedStatus == 'Semua Status' || item.status == selectedStatus;

      final matchesOfficer =
          selectedOfficer == 'Semua Petugas' || item.officer == selectedOfficer;

      final matchesCategory = selectedCategory == 'Semua Kategori' ||
          item.category == selectedCategory;

      final matchesJob =
          selectedJob == 'Semua Pekerjaan' || item.job == selectedJob;

      final matchesSearch = query.isEmpty ||
          item.transactionNumber.toLowerCase().contains(query) ||
          item.nik.toLowerCase().contains(query) ||
          item.applicant.toLowerCase().contains(query) ||
          item.job.toLowerCase().contains(query);

      return matchesType &&
          matchesStatus &&
          matchesOfficer &&
          matchesCategory &&
          matchesJob &&
          matchesSearch;
    }).toList();
  }

  List<String> get jobOptions {
    if (selectedType == MonitoringTransactionType.notaris) {
      return [
        'Semua Pekerjaan',
        'Akta Jual Beli',
        'Akta Kuasa',
        'Akta Hibah',
        'Akta Waris',
      ];
    }

    if (selectedType == MonitoringTransactionType.ppat) {
      return [
        'Semua Pekerjaan',
        'Akta Jual Beli Tanah',
        'Akta Hibah Tanah',
        'Akta Pembagian Hak Bersama',
      ];
    }

    return [
      'Semua Pekerjaan',
      'Akta Jual Beli',
      'Akta Kuasa',
      'Akta Hibah',
      'Akta Waris',
      'Akta Jual Beli Tanah',
      'Akta Hibah Tanah',
      'Akta Pembagian Hak Bersama',
    ];
  }

  void _changeType(MonitoringTransactionType type) {
    setState(() {
      selectedType = type;
      selectedJob = 'Semua Pekerjaan';
    });
  }

  void _resetFilter() {
    _searchDebouncer.cancel();

    setState(() {
      selectedType = MonitoringTransactionType.all;
      selectedStatus = 'Semua Status';
      selectedOfficer = 'Semua Petugas';
      selectedCategory = 'Semua Kategori';
      selectedJob = 'Semua Pekerjaan';
      _searchQuery = '';
      searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = filteredData;

    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 700;
        final padding = mobile ? 16.0 : 28.0;

        return Padding(
          padding: EdgeInsets.fromLTRB(padding, 20, padding, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPageHeader(mobile: mobile),
              const SizedBox(height: 18),
              _buildFilters(mobile: mobile),
              const SizedBox(height: 18),
              _buildTable(data, mobile: mobile),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPageHeader({required bool mobile}) {
    final excelButton = ElevatedButton.icon(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Export Excel masih berupa dummy.'),
          ),
        );
      },
      icon: const Icon(Icons.table_view_outlined, size: 18),
      label: const Text('Excel'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      ),
    );

    if (mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Monitoring',
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.w500),
                ),
              ),
              excelButton,
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'Monitoring  |  Page',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        const Text(
          'Monitoring',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 14),
        Text(
          'Monitoring  |  Page',
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 13,
          ),
        ),
        const Spacer(),
        excelButton,
      ],
    );
  }

  Widget _buildFilters({required bool mobile}) {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _typeFilterButton('Semua', MonitoringTransactionType.all),
                    _typeFilterButton(
                      'Notaris',
                      MonitoringTransactionType.notaris,
                    ),
                    _typeFilterButton(
                      'PPAT',
                      MonitoringTransactionType.ppat,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: _resetFilter,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Reset'),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                _typeFilterButton('Semua', MonitoringTransactionType.all),
                const SizedBox(width: 8),
                _typeFilterButton(
                  'Notaris',
                  MonitoringTransactionType.notaris,
                ),
                const SizedBox(width: 8),
                _typeFilterButton('PPAT', MonitoringTransactionType.ppat),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _resetFilter,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Reset'),
                ),
              ],
            ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 10.0;
              final fieldWidth = mobile
                  ? constraints.maxWidth
                  : (constraints.maxWidth - (gap * 5)) / 6;

              return Wrap(
                spacing: gap,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: fieldWidth,
                    child: _dateField('Dari Tanggal'),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _dateField('Sampai Tanggal'),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: SearchableDropdown<String>(
                      value: selectedJob,
                      items: jobOptions,
                      label: 'Pekerjaan',
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedJob = value);
                        }
                      },
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: SearchableDropdown<String>(
                      value: selectedCategory,
                      items: const [
                        'Semua Kategori',
                        'Jual Beli',
                        'Kuasa',
                        'Hibah',
                        'Waris',
                        'Pembagian Hak',
                      ],
                      label: 'Kategori',
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedCategory = value);
                        }
                      },
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: SearchableDropdown<String>(
                      value: selectedStatus,
                      items: const [
                        'Semua Status',
                        'Selesai',
                        'Belum Selesai',
                      ],
                      label: 'Status',
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedStatus = value);
                        }
                      },
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: SearchableDropdown<String>(
                      value: selectedOfficer,
                      items: const [
                        'Semua Petugas',
                        'Rina Wulandari',
                        'Dimas Saputra',
                        'Sari Anggraini',
                      ],
                      label: 'Petugas',
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedOfficer = value);
                        }
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _typeFilterButton(
    String label,
    MonitoringTransactionType type,
  ) {
    final selected = selectedType == type;

    return OutlinedButton(
      onPressed: () => _changeType(type),
      style: OutlinedButton.styleFrom(
        backgroundColor:
            selected ? AppColors.primaryConfirm : Colors.white,
        foregroundColor:
            selected ? Colors.white : AppColors.primaryConfirm,
        side: BorderSide(color: AppColors.primaryConfirm),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      ),
      child: Text(label),
    );
  }

  Widget _dateField(String label) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
        ),
        suffixIcon: const Icon(
          Icons.calendar_today_outlined,
          size: 18,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      child: const Text('11/09/2026'),
    );
  }

  Widget _buildTable(
    List<DummyMonitoringItem> data, {
    required bool mobile,
  }) {
    final searchField = SizedBox(
      width: mobile ? double.infinity : 260,
      child: TextField(
        controller: searchController,
        onChanged: (value) {
          _searchDebouncer.run(() {
            if (mounted) {
              setState(() => _searchQuery = value);
            }
          });
        },
        decoration: InputDecoration(
          hintText: 'Cari data...',
          prefixIcon: const Icon(Icons.search, size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
        ),
      ),
    );

    return _panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (mobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Data Monitoring',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${data.length} data',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                searchField,
              ],
            )
          else
            Row(
              children: [
                const Text(
                  'Data Monitoring',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 10),
                Text(
                  '${data.length} data',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                searchField,
              ],
            ),
          const SizedBox(height: 16),
          Scrollbar(
            controller: tableHorizontalController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: tableHorizontalController,
              physics: const ClampingScrollPhysics(),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(bottom: 8),
              child: DataTable(
                headingRowColor:
                    WidgetStateProperty.all(const Color(0xFFF5F5F5)),
                columnSpacing: mobile ? 28 : 24,
                horizontalMargin: 12,
                columns: const [
                  DataColumn(label: Text('#')),
                  DataColumn(label: Text('Tanggal')),
                  DataColumn(label: Text('No. Transaksi')),
                  DataColumn(label: Text('NIK')),
                  DataColumn(label: Text('Pemohon')),
                  DataColumn(label: Text('Pekerjaan')),
                  DataColumn(label: Text('Kategori')),
                  DataColumn(label: Text('Petugas')),
                  DataColumn(label: Text('Nominal')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Aksi')),
                ],
                rows: List.generate(
                  data.length,
                  (index) {
                    final item = data[index];
                    final isDone = item.status == 'Selesai';

                    return DataRow(
                      cells: [
                        DataCell(Text('${index + 1}')),
                        DataCell(Text(item.date)),
                        DataCell(
                          Text(
                            item.transactionNumber,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        DataCell(Text(item.nik)),
                        DataCell(Text(item.applicant)),
                        DataCell(
                          SizedBox(
                            width: 170,
                            child: Text(
                              item.job,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(Text(item.category)),
                        DataCell(Text(item.officer)),
                        DataCell(Text(item.nominal)),
                        DataCell(_statusBadge(item.status, isDone)),
                        DataCell(
                          IconButton(
                            tooltip: 'Detail',
                            onPressed: () => _showDetail(item),
                            icon: Icon(
                              Icons.visibility_outlined,
                              color: AppColors.primaryConfirm,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (mobile)
            Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Menampilkan ${data.length} data',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    OutlinedButton(
                      onPressed: () {},
                      child: const Text('Previous'),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryConfirm,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '1',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () {},
                      child: const Text('Next'),
                    ),
                  ],
                ),
              ],
            )
          else
            Row(
              children: [
                Text(
                  'Menampilkan ${data.length} data',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: () {},
                  child: const Text('Previous'),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryConfirm,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '1',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 6),
                OutlinedButton(
                  onPressed: () {},
                  child: const Text('Next'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status, bool isDone) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: isDone
            ? Colors.green.withValues(alpha: 0.10)
            : Colors.orange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: isDone ? Colors.green.shade700 : Colors.orange.shade700,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _showDetail(DummyMonitoringItem item) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Detail Monitoring'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow('No. Transaksi', item.transactionNumber),
                _detailRow('Tanggal', item.date),
                _detailRow('NIK', item.nik),
                _detailRow('Pemohon', item.applicant),
                _detailRow('Pekerjaan', item.job),
                _detailRow('Kategori', item.category),
                _detailRow('Petugas', item.officer),
                _detailRow('Nominal', item.nominal),
                _detailRow('Status', item.status),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          const Text(':  '),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE7E7E7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  void dispose() {
    _searchDebouncer.dispose();
    searchController.dispose();
    tableHorizontalController.dispose();
    super.dispose();
  }
}
