import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_session.dart';
import '../models/transaction_monitoring.dart';
import '../providers/auth_provider.dart';
import '../providers/transaction_provider.dart';
import '../widgets/transaksi_proses_list.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/transaction_review_dialog.dart';

import 'package:frontend_notaris/core/widgets/searchable_dropdown.dart';

import '../core/utils/debouncer.dart';

enum MonitoringTransactionType { all, notaris, ppat }

bool _canReadTransactions(AuthSession? session) {
  bool yes(dynamic value) => value == true || value == 1 || value == '1';
  return session?.sidebars.any((entry) {
        final sidebar = entry['sidebar'];
        return sidebar is Map &&
            sidebar['sidebar_kode'] == 'transaksi' &&
            (sidebar['status'] == null || yes(sidebar['status'])) &&
            yes(entry['read']);
      }) ??
      false;
}

String _present(String? value) =>
    value == null || value.trim().isEmpty ? '—' : value;
String _monitoringDate(DateTime? value) {
  if (value == null) return '—';
  final date = value.toLocal();
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _monitoringMoney(double amount) =>
    'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}';

class MonitoringDesktopScreen extends ConsumerStatefulWidget {
  const MonitoringDesktopScreen({super.key});

  @override
  ConsumerState<MonitoringDesktopScreen> createState() =>
      _MonitoringDesktopScreenState();
}

class _MonitoringDetailDialog extends ConsumerWidget {
  const _MonitoringDetailDialog(this.transactionId);
  final int transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canRead = _canReadTransactions(
      ref.watch(authControllerProvider.select((state) => state.session)),
    );
    final result = canRead
        ? ref.watch(monitoringTransactionProvider(transactionId))
        : null;
    final row = result?.asData?.value;
    return TransactionReviewDialog(
      width: 860,
      title: 'Detail Monitoring',
      subtitle: row?.transaction.noAkta,
      status: row == null
          ? null
          : TransactionReviewBadge.transaction(row.transaction.statusTransaksi),
      body:
          result?.when(
            loading: () => const TransactionReviewMessage(
              'Memuat detail transaksi…',
              loading: true,
            ),
            error: (_, _) => const TransactionReviewMessage(
              'Detail transaksi gagal dimuat.',
              icon: Icons.error_outline,
            ),
            data: (row) => row == null
                ? const TransactionReviewMessage(
                    'Transaksi sudah tidak tersedia.',
                  )
                : _buildDetail(context, ref, row),
          ) ??
          const TransactionReviewMessage(
            'Izin baca Transaksi diperlukan.',
            icon: Icons.lock_outline,
          ),
    );
  }

  Widget _buildDetail(BuildContext context, WidgetRef ref, MonitoringRow row) {
    final transaction = row.transaction;
    final kind = switch (transaction.jenisTransaksi) {
      'notaris' => 'Notaris',
      'ppat' => 'PPAT',
      _ => _present(transaction.jenisTransaksi),
    };
    final details = ref.watch(monitoringDetailsProvider(transactionId));
    final fields = [
      ('No. Transaksi', _present(transaction.noAkta)),
      ('Jenis', kind),
      ('Tanggal', _monitoringDate(transaction.tanggalTransaksi)),
      ('Jatuh Tempo', _monitoringDate(transaction.tanggalJatuhTempo)),
      ('Pemohon', _present(row.applicant)),
      ('NIK', _present(row.nik)),
      ('Petugas', _present(row.officer)),
      ('Nominal', _monitoringMoney(transaction.total)),
      ('Status', _present(transaction.statusTransaksi)),
    ];
    final titleStyle = Theme.of(context).textTheme.titleMedium
        ?.copyWith(fontWeight: FontWeight.w700);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        Text('Ringkasan Transaksi', style: titleStyle),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final fieldWidth = width < 560 ? width : (width - 16) / 2;
            return Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                for (final (label, value) in fields)
                  SizedBox(
                    width: fieldWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          value,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        const Divider(color: AppColors.divider),
        Text('Detail Pekerjaan', style: titleStyle),
        details.when(
          loading: () => const TransactionReviewMessage(
            'Memuat pekerjaan…',
            loading: true,
          ),
          error: (_, _) => const TransactionReviewMessage(
            'Pekerjaan gagal dimuat.',
            icon: Icons.error_outline,
          ),
          data: (jobs) => jobs.isEmpty
              ? const TransactionReviewMessage(
                  'Belum ada detail pekerjaan aktif.',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final job in jobs)
                      Container(
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _present(job.namaPekerjaanSnapshot),
                              style: titleStyle,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Kategori: ${_present(job.kategoriSnapshot)}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const Divider(color: AppColors.divider),
                            TransaksiProsesList(
                              key: ValueKey(job.uuid),
                              transactionId: transactionId,
                              detailUuid: job.uuid,
                              fallbackProcesses: const [],
                              embedded: true,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}

class _MonitoringDesktopScreenState
    extends ConsumerState<MonitoringDesktopScreen> {
  MonitoringTransactionType selectedType = MonitoringTransactionType.all;
  String selectedStatus = '', selectedCategory = '', selectedJob = '';
  int selectedOfficer = 0, _pageIndex = 0;
  DateTime? _from, _until;

  String get _domain =>
      selectedType == MonitoringTransactionType.all ? '' : selectedType.name;

  final TextEditingController searchController = TextEditingController();
  final ScrollController tableHorizontalController = ScrollController();
  final _searchDebouncer = Debouncer();

  String _searchQuery = '';

  void _changeType(MonitoringTransactionType type) {
    setState(() {
      selectedType = type;
      selectedJob = selectedCategory = '';
      selectedOfficer = _pageIndex = 0;
    });
  }

  void _resetFilter() {
    _searchDebouncer.cancel();
    setState(() {
      selectedType = MonitoringTransactionType.all;
      selectedStatus = selectedCategory = selectedJob = _searchQuery = '';
      selectedOfficer = _pageIndex = 0;
      _from = _until = null;
      searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_canReadTransactions(
      ref.watch(authControllerProvider.select((state) => state.session)),
    )) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text('Izin baca Transaksi diperlukan untuk membuka Monitoring.'),
      );
    }
    final filter = (
      domain: _domain,
      status: selectedStatus,
      search: _searchQuery,
      job: selectedJob,
      category: selectedCategory,
      officerId: selectedOfficer,
      from: _from,
      until: _until,
      index: _pageIndex,
    );
    final data = ref.watch(monitoringPageProvider(filter));
    final options = ref.watch(monitoringOptionsProvider(_domain));

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
              _buildFilters(options, mobile: mobile),
              const SizedBox(height: 18),
              _buildTable(data, mobile: mobile),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPageHeader({required bool mobile}) {
    final excelButton = Tooltip(
      message: 'Export Excel belum tersedia.',
      child: ElevatedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.table_view_outlined, size: 18),
        label: const Text('Excel'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade600,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        ),
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
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
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
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        ),
        const Spacer(),
        excelButton,
      ],
    );
  }

  Widget _buildFilters(
    AsyncValue<MonitoringOptions> options, {
    required bool mobile,
  }) {
    final choices = options.asData?.value;
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
                    _typeFilterButton('PPAT', MonitoringTransactionType.ppat),
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
                _typeFilterButton('Notaris', MonitoringTransactionType.notaris),
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
          if (options.isLoading) const Text('Memuat pilihan filter…'),
          if (options.hasError)
            const Text(
              'Pilihan filter pekerjaan, kategori, dan petugas gagal dimuat.',
            ),
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
                    child: _dateField('Dari Tanggal', from: true),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _dateField('Sampai Tanggal', from: false),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _filterDropdown(
                      'Pekerjaan',
                      selectedJob,
                      choices?.jobs,
                      (value) => selectedJob = value,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _filterDropdown(
                      'Kategori',
                      selectedCategory,
                      choices?.categories,
                      (value) => selectedCategory = value,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _filterDropdown('Status', selectedStatus, const [
                      'Baru',
                      'Dalam Proses',
                      'Selesai',
                    ], (value) => selectedStatus = value),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: SearchableDropdown<int>(
                      value: selectedOfficer,
                      items: {
                        0,
                        ...?choices?.officers.keys,
                        selectedOfficer,
                      }.toList(),
                      label: 'Petugas',
                      enabled: choices != null,
                      itemLabel: (id) => id == 0
                          ? 'Semua Petugas'
                          : choices?.officers[id] ?? 'Petugas tidak tersedia',
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedOfficer = value;
                            _pageIndex = 0;
                          });
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

  Widget _typeFilterButton(String label, MonitoringTransactionType type) {
    final selected = selectedType == type;

    return OutlinedButton(
      onPressed: () => _changeType(type),
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? AppColors.primaryConfirm : Colors.white,
        foregroundColor: selected ? Colors.white : AppColors.primaryConfirm,
        side: BorderSide(color: AppColors.primaryConfirm),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      ),
      child: Text(label),
    );
  }

  Widget _filterDropdown(
    String label,
    String selected,
    List<String>? values,
    ValueChanged<String> apply,
  ) {
    return SearchableDropdown<String>(
      value: selected,
      items: {'', ...?values, selected}.toList(),
      label: label,
      enabled: values != null,
      itemLabel: (value) => value.isEmpty ? 'Semua $label' : value,
      onChanged: (value) {
        if (value != null) {
          setState(() {
            apply(value);
            _pageIndex = 0;
          });
        }
      },
    );
  }

  Widget _dateField(String label, {required bool from}) {
    return InkWell(
      onTap: () async {
        final first = from ? DateTime(1900) : _from ?? DateTime(1900);
        final last = from
            ? _until ?? DateTime(9999, 12, 31)
            : DateTime(9999, 12, 31);
        final initial =
            (from ? _from : _until) ?? DateUtils.dateOnly(DateTime.now());
        final picked = await showDatePicker(
          context: context,
          initialDate: initial.isBefore(first)
              ? first
              : initial.isAfter(last)
              ? last
              : initial,
          firstDate: first,
          lastDate: last,
        );
        if (picked != null && mounted) {
          setState(() {
            if (from) {
              _from = picked;
            } else {
              _until = picked;
            }
            _pageIndex = 0;
          });
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(7)),
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
        child: Text(_monitoringDate(from ? _from : _until)),
      ),
    );
  }

  Widget _buildTable(
    AsyncValue<MonitoringPage> result, {
    required bool mobile,
  }) {
    final page = result.asData?.value;
    final data = page?.rows ?? [];
    final pageCount = page == null
        ? 0
        : (page.total + monitoringPageSize - 1) ~/ monitoringPageSize;
    final searchField = SizedBox(
      width: mobile ? double.infinity : 260,
      child: TextField(
        controller: searchController,
        onChanged: (value) {
          _searchDebouncer.run(() {
            if (mounted) {
              setState(() {
                _searchQuery = value;
                _pageIndex = 0;
              });
            }
          });
        },
        decoration: InputDecoration(
          hintText: 'Cari data...',
          prefixIcon: const Icon(Icons.search, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(7)),
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
                      page == null ? '—' : '${page.total} data',
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
                  page == null ? '—' : '${page.total} data',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
                const Spacer(),
                searchField,
              ],
            ),
          const SizedBox(height: 16),
          if (page == null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                result.hasError
                    ? 'Data Monitoring gagal dimuat.'
                    : 'Memuat data Monitoring…',
              ),
            )
          else if (data.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Tidak ada transaksi yang sesuai.'),
            )
          else
            Scrollbar(
              controller: tableHorizontalController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: tableHorizontalController,
                physics: const ClampingScrollPhysics(),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 8),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    const Color(0xFFF5F5F5),
                  ),
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
                  rows: List.generate(data.length, (index) {
                    final item = data[index];
                    final transaction = item.transaction;
                    final status = transaction.statusTransaksi;
                    final isDone = status.trim().toLowerCase() == 'selesai';

                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            '${page.index * monitoringPageSize + index + 1}',
                          ),
                        ),
                        DataCell(
                          Text(_monitoringDate(transaction.tanggalTransaksi)),
                        ),
                        DataCell(
                          Text(
                            transaction.noAkta,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        DataCell(Text(_present(item.nik))),
                        DataCell(Text(_present(item.applicant))),
                        DataCell(
                          SizedBox(
                            width: 170,
                            child: Text(
                              _present(item.jobs),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(Text(_present(item.categories))),
                        DataCell(Text(_present(item.officer))),
                        DataCell(Text(_monitoringMoney(transaction.total))),
                        DataCell(_statusBadge(_present(status), isDone)),
                        DataCell(
                          IconButton(
                            tooltip: 'Detail',
                            onPressed: () => _showDetail(transaction.id),
                            icon: Icon(
                              Icons.visibility_outlined,
                              color: AppColors.primaryConfirm,
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          if (page != null) ...[
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text('Menampilkan ${data.length} dari ${page.total} transaksi'),
                OutlinedButton(
                  onPressed: page.index > 0
                      ? () => setState(() => _pageIndex = page.index - 1)
                      : null,
                  child: const Text('Previous'),
                ),
                Text(
                  'Halaman ${pageCount == 0 ? 0 : page.index + 1} / $pageCount',
                ),
                OutlinedButton(
                  onPressed: page.index + 1 < pageCount
                      ? () => setState(() => _pageIndex = page.index + 1)
                      : null,
                  child: const Text('Next'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusBadge(String status, bool isDone) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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

  Future<void> _showDetail(int transactionId) async {
    if (!_canReadTransactions(ref.read(authControllerProvider).session)) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _MonitoringDetailDialog(transactionId),
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
