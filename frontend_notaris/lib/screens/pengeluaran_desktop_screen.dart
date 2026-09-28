import 'package:flutter/material.dart';
import '../core/widgets/searchable_dropdown.dart';
import '../core/widgets/loading_overlay.dart';
import '../core/theme/app_colors.dart';


class PengeluaranDesktopScreen extends StatefulWidget {
  const PengeluaranDesktopScreen({super.key});

  @override
  State<PengeluaranDesktopScreen> createState() => _PengeluaranDesktopScreenState();
}

class _PengeluaranDesktopScreenState extends State<PengeluaranDesktopScreen> {
  final tableController = ScrollController();
  final searchController = TextEditingController();

  String selectedJenis = 'Semua Jenis Pengeluaran';
  String tanggalAwal = '11/09/2026';
  String tanggalAkhir = '11/09/2026';

  bool _isLoading = false;

  final data = <_PengeluaranItem>[
    _PengeluaranItem('01250920260001','ATK',350000,'11/09/2026','Pembelian alat tulis kantor'),
    _PengeluaranItem('01250920260002','Listrik',850000,'10/09/2026','Pembayaran listrik kantor'),
    _PengeluaranItem('01250920260003','Internet',450000,'08/09/2026','Pembayaran internet'),
    _PengeluaranItem('01250920260004','Transportasi',275000,'05/09/2026','Biaya perjalanan dinas'),
    _PengeluaranItem('01250920260005','ATK',180000,'03/09/2026','Pembelian kertas dan tinta'),
    _PengeluaranItem('01250920260006','Operasional',625000,'01/09/2026','Keperluan operasional kantor'),
    _PengeluaranItem('01250920260007','Kebersihan',220000,'30/08/2026','Perlengkapan kebersihan'),
  ];

  List<_PengeluaranItem> get filtered {
    final q = searchController.text.toLowerCase();
    return data.where((e) =>
      (selectedJenis == 'Semua Jenis Pengeluaran' || e.jenis == selectedJenis) &&
      (q.isEmpty || e.noFaktur.toLowerCase().contains(q) ||
       e.jenis.toLowerCase().contains(q) || e.keterangan.toLowerCase().contains(q))
    ).toList();
  }

  int get total => filtered.fold(0, (s, e) => s + e.jumlah);

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      message: 'Memproses data...',
      child: LayoutBuilder(builder: (context, c) {
        final mobile = c.maxWidth < 700;
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
              _header(mobile),
              const SizedBox(height: 18),
              _filters(mobile),
              const SizedBox(height: 18),
              _table(mobile),
            ],
          ),
        );
      }),
    );
  }

  Widget _header(bool mobile) {
    final button = ElevatedButton.icon(
      onPressed: _isLoading ? null : _showForm,
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Tambah Pengeluaran'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryConfirm,
        foregroundColor: Colors.white,
      ),
    );
    if (mobile) {
      return Row(children: [
        const Expanded(child: Text('Pengeluaran', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w500))),
        button,
      ]);
    }
    return Row(children: [
      const Text('Pengeluaran', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w500)),
      const SizedBox(width: 14),
      Text('Pengeluaran  |  Page', style: TextStyle(color: AppColors.primaryConfirm, fontSize: 13)),
      const Spacer(),
      button,
    ]);
  }

  Widget _filters(bool mobile) {
    return _panel(child: LayoutBuilder(builder: (context, c) {
      const gap = 12.0;
      final w = mobile ? c.maxWidth : (c.maxWidth - 3 * gap) / 4;
      return Wrap(spacing: gap, runSpacing: 12, children: [
        SizedBox(width: w, child: _date('Dari Tanggal', tanggalAwal, (v) => setState(() => tanggalAwal = v))),
        SizedBox(width: w, child: _date('Sampai Tanggal', tanggalAkhir, (v) => setState(() => tanggalAkhir = v))),
        SizedBox(width: w, child: 
        SearchableDropdown<String>(
          value: selectedJenis,
          items: const [
            'ATK',
            'Listrik',
            'Internet',
            'Transportasi',
            'Operasional',
            'Kebersihan',
          ],
          label: 'Jenis Pengeluaran',
          onChanged: (v) {
            if (v != null) {
              setState(() => selectedJenis = v);
            }
          },
        )
        ),
        SizedBox(width: mobile ? w : 110, child: OutlinedButton.icon(
          onPressed: _reset, icon: const Icon(Icons.refresh, size: 18), label: const Text('Reset'),
        )),
      ]);
    }));
  }

  Widget _table(bool mobile) {
    final rows = filtered;
    return _panel(padding: const EdgeInsets.all(16), child: Column(children: [
      if (mobile) ...[
        Row(children: [
          const Expanded(child: Text('Data Pengeluaran', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
          Text('${rows.length} data', style: TextStyle(color: Colors.grey.shade500)),
        ]),
        const SizedBox(height: 12),
        _search(true),
      ] else Row(children: [
        const Text('Data Pengeluaran', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(width: 10),
        Text('${rows.length} data', style: TextStyle(color: Colors.grey.shade500)),
        const Spacer(),
        _search(false),
      ]),
      const SizedBox(height: 16),
      Scrollbar(
        controller: tableController,
        thumbVisibility: true,
        notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
        child: SingleChildScrollView(
          controller: tableController,
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 8),
          child: DataTable(
            columnSpacing: mobile ? 28 : 26,
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF5F5F5)),
            columns: const [
              DataColumn(label: Text('#')), DataColumn(label: Text('No. Faktur')),
              DataColumn(label: Text('Keterangan')), DataColumn(label: Text('Jenis Pengeluaran')),
              DataColumn(label: Text('Jumlah')), DataColumn(label: Text('Tanggal Pengeluaran')),
              DataColumn(label: Text('Aksi')),
            ],
            rows: List.generate(rows.length, (i) {
              final e = rows[i];
              return DataRow(cells: [
                DataCell(Text('${i + 1}')),
                DataCell(Text(e.noFaktur, style: const TextStyle(fontWeight: FontWeight.w600))),
                DataCell(SizedBox(width: 230, child: Text(e.keterangan, overflow: TextOverflow.ellipsis))),
                DataCell(Text(e.jenis)),
                DataCell(Text(_rupiah(e.jumlah), style: const TextStyle(fontWeight: FontWeight.w600))),
                DataCell(Text(e.tanggal)),
                DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(tooltip: 'Edit', onPressed: _isLoading ? null : () => _showForm(item: e), icon: const Icon(Icons.edit_outlined)),
                  IconButton(tooltip: 'Hapus', onPressed: _isLoading ? null : () => _delete(e), icon: const Icon(Icons.delete_outline)),
                ])),
              ]);
            }),
          ),
        ),
      ),
      const SizedBox(height: 14),
      if (mobile) Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Menampilkan ${rows.length} data', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        const SizedBox(height: 10),
        Text('Total Pengeluaran: ${_rupiah(total)}', style: TextStyle(color: const Color(0xFFBC7D7D), fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        _pagination(),
      ]) else Row(children: [
        Text('Menampilkan ${rows.length} data', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        const SizedBox(width: 30),
        Text('Total Pengeluaran: ${_rupiah(total)}', style: TextStyle(color: const Color(0xFFBC7D7D), fontWeight: FontWeight.w700)),
        const Spacer(),
        _pagination(),
      ]),
    ]));
  }

  Widget _search(bool mobile) => SizedBox(
    width: mobile ? double.infinity : 260,
    child: TextField(
      controller: searchController,
      onChanged: (_) => setState(() {}),
      decoration: _dec('Cari data...').copyWith(prefixIcon: const Icon(Icons.search)),
    ),
  );

  Widget _pagination() => Wrap(spacing: 6, children: [
    OutlinedButton(onPressed: () {}, child: const Text('Previous')),
    Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(color: const Color(0xFFBC7D7D), borderRadius: BorderRadius.circular(6)),
      child: const Text('1', style: TextStyle(color: Colors.white))),
    OutlinedButton(onPressed: () {}, child: const Text('Next')),
  ]);

  Widget _date(String label, String value, ValueChanged<String> onChanged) => TextField(
    readOnly: true,
    controller: TextEditingController(text: value),
    decoration: _dec(label).copyWith(suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18)),
    onTap: () async {
      final d = await showDatePicker(context: context, initialDate: DateTime(2026,9,11), firstDate: DateTime(2020), lastDate: DateTime(2100));
      if (d != null) onChanged('${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}');
    },
  );

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(7)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
  );

  Widget _panel({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(16)}) =>
    Container(width: double.infinity, padding: padding, decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE5E5E5)),
      boxShadow: const [BoxShadow(blurRadius: 8, offset: Offset(0,2), color: Color(0x10000000))],
    ), child: child);

  void _reset() => setState(() {
    selectedJenis = 'Semua Jenis Pengeluaran';
    tanggalAwal = '11/09/2026';
    tanggalAkhir = '11/09/2026';
    searchController.clear();
  });

  void _showForm({_PengeluaranItem? item}) {
    final no = TextEditingController(text: item?.noFaktur ?? '01250920260008');
    final jumlah = TextEditingController(text: item == null ? '' : _rupiah(item.jumlah));
    final tanggal = TextEditingController(text: item?.tanggal ?? '11/09/2026');
    final ket = TextEditingController(text: item?.keterangan ?? '');
    String jenis = item?.jenis ?? 'ATK';

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setModal) {
      final mobile = MediaQuery.sizeOf(ctx).width < 600;
      return AlertDialog(
        title: Text(item == null ? 'Tambah Pengeluaran' : 'Edit Pengeluaran'),
        content: SizedBox(width: mobile ? double.infinity : 520, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: no, readOnly: true, decoration: _dec('No. Faktur')),
          const SizedBox(height: 12),
          SearchableDropdown<String>(
            value: jenis,
            items: const [
              'ATK',
              'Listrik',
              'Internet',
              'Transportasi',
              'Operasional',
              'Kebersihan',
            ],
            label: 'Jenis Pengeluaran',
            onChanged: (v) {
              if (v != null) {
                setModal(() => jenis = v);
              }
            },
          ),
          const SizedBox(height: 12),
          TextField(controller: jumlah, keyboardType: TextInputType.number, decoration: _dec('Jumlah')),
          const SizedBox(height: 12),
          TextField(controller: tanggal, readOnly: true, decoration: _dec('Tanggal Pengeluaran').copyWith(suffixIcon: const Icon(Icons.calendar_today_outlined)), onTap: () async {
            final d = await showDatePicker(context: ctx, initialDate: DateTime(2026,9,11), firstDate: DateTime(2020), lastDate: DateTime(2100));
            if (d != null) tanggal.text = '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
          }),
          const SizedBox(height: 12),
          TextField(controller: ket, maxLines: 3, decoration: _dec('Keterangan')),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);

              await _processAction(
                item == null ? 'Menyimpan data...' : 'Mengubah data...',
                () async {
                  // Simulasi request ke backend.
                  await Future.delayed(const Duration(seconds: 1));
                },
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      item == null
                          ? 'Pengeluaran disimpan (dummy).'
                          : 'Pengeluaran diubah (dummy).',
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('Simpan'),
          ),
        ],
      );
    }));
  }

  void _delete(_PengeluaranItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Peringatan!'),
        content: Text(
          'Apakah Anda yakin ingin menghapus pengeluaran ${item.noFaktur}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tidak'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);

              await _processAction(
                'Menghapus data...',
                () async {
                  // Simulasi request ke backend.
                  await Future.delayed(const Duration(seconds: 1));
                },
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Data dihapus (dummy).'),
                  ),
                );
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  Future<void> _processAction(
    String message,
    Future<void> Function() action,
  ) async {
    if (_isLoading || !mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await action();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _rupiah(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (int i=0; i<s.length; i++) {
      b.write(s[i]);
      final left = s.length - i - 1;
      if (left > 0 && left % 3 == 0) b.write('.');
    }
    return 'Rp ${b.toString()}';
  }

  @override
  void dispose() {
    tableController.dispose();
    searchController.dispose();
    super.dispose();
  }
}

class _PengeluaranItem {
  final String noFaktur, jenis, tanggal, keterangan;
  final int jumlah;
  const _PengeluaranItem(this.noFaktur, this.jenis, this.jumlah, this.tanggal, this.keterangan);
}
