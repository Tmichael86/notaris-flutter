import 'package:flutter/material.dart';

class PiutangDesktopScreen extends StatefulWidget {
  const PiutangDesktopScreen({super.key});

  @override
  State<PiutangDesktopScreen> createState() => _PiutangDesktopScreenState();
}

class _PiutangDesktopScreenState extends State<PiutangDesktopScreen> {
  final tableController = ScrollController();
  final searchController = TextEditingController();

  String selectedJenis = 'Semua Jenis Pekerjaan';
  String tanggalAwal = '11/09/2026';
  String tanggalAkhir = '11/09/2026';

  final rows = <_PiutangItem>[
    _PiutangItem('NTRX-2026-0001','3505010101000001','Budi Santoso','Notaris','Akta Jual Beli','Jual Beli','Rp 1.500.000','Rp 500.000','Rina Wulandari'),
    _PiutangItem('NTRX-2026-0002','3505010101000002','Siti Aminah','Notaris','Akta Kuasa','Kuasa','Rp 750.000','Rp 750.000','Dimas Saputra'),
    _PiutangItem('PTRX-2026-0001','3505010101000003','Andi Pratama','PPAT','Akta Jual Beli Tanah','Jual Beli','Rp 2.500.000','Rp 1.250.000','Sari Anggraini'),
    _PiutangItem('NTRX-2026-0003','3505010101000004','Dewi Lestari','Notaris','Akta Hibah','Hibah','Rp 1.250.000','Rp 300.000','Rina Wulandari'),
    _PiutangItem('PTRX-2026-0002','3505010101000005','Agus Setiawan','PPAT','Akta Hibah Tanah','Hibah','Rp 2.000.000','Rp 1.000.000','Dimas Saputra'),
    _PiutangItem('NTRX-2026-0004','3505010101000006','Fajar Nugroho','Notaris','Akta Waris','Waris','Rp 1.000.000','Rp 450.000','Sari Anggraini'),
    _PiutangItem('PTRX-2026-0003','3505010101000007','Maya Putri','PPAT','Akta Pembagian Hak Bersama','Pembagian Hak','Rp 2.250.000','Rp 900.000','Rina Wulandari'),
  ];

  List<_PiutangItem> get filtered {
    final q = searchController.text.toLowerCase().trim();
    return rows.where((e) {
      final jenis = selectedJenis == 'Semua Jenis Pekerjaan' ||
          e.jenis == selectedJenis;
      final search = q.isEmpty ||
          e.noAkta.toLowerCase().contains(q) ||
          e.nik.toLowerCase().contains(q) ||
          e.nama.toLowerCase().contains(q) ||
          e.pekerjaan.toLowerCase().contains(q) ||
          e.petugas.toLowerCase().contains(q);
      return jenis && search;
    }).toList();
  }

  int _number(String value) =>
      int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  int get totalPiutang =>
      filtered.fold(0, (sum, e) => sum + _number(e.totalPiutang));

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final mobile = c.maxWidth < 700;
      return Padding(
        padding: EdgeInsets.fromLTRB(mobile ? 16 : 28, 20, mobile ? 16 : 28, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(mobile),
            const SizedBox(height: 18),
            _filters(mobile),
            const SizedBox(height: 18),
            _dataPanel(mobile),
          ],
        ),
      );
    });
  }

  Widget _header(bool mobile) {
    final excel = ElevatedButton.icon(
      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export Excel masih berupa dummy.')),
      ),
      icon: const Icon(Icons.table_view_outlined, size: 18),
      label: const Text('Excel'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
      ),
    );

    if (mobile) {
      return Row(children: [
        const Expanded(
          child: Text('Piutang', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w500)),
        ),
        excel,
      ]);
    }

    return Row(children: [
      const Text('Piutang', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w500)),
      const SizedBox(width: 14),
      Text('Piutang  |  Page', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
      const Spacer(),
      excel,
    ]);
  }

  Widget _filters(bool mobile) {
    return _panel(
      child: LayoutBuilder(builder: (context, c) {
        const gap = 12.0;
        final w = mobile ? c.maxWidth : (c.maxWidth - 3 * gap) / 4;

        return Wrap(
          spacing: gap,
          runSpacing: 12,
          children: [
            SizedBox(width: w, child: _date('Dari Tanggal', tanggalAwal, (v) => setState(() => tanggalAwal = v))),
            SizedBox(width: w, child: _date('Sampai Tanggal', tanggalAkhir, (v) => setState(() => tanggalAkhir = v))),
            SizedBox(
              width: w,
              child: DropdownButtonFormField<String>(
                value: selectedJenis,
                isExpanded: true,
                decoration: _dec('Jenis Pekerjaan'),
                items: const [
                  'Semua Jenis Pekerjaan',
                  'Notaris',
                  'PPAT',
                ].map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(e, overflow: TextOverflow.ellipsis),
                )).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => selectedJenis = v);
                },
              ),
            ),
            SizedBox(
              width: mobile ? w : 110,
              child: OutlinedButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reset'),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _dataPanel(bool mobile) {
    final data = filtered;

    return _panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (mobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Expanded(
                    child: Text('Data Piutang', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  ),
                  Text('${data.length} data', style: TextStyle(color: Colors.grey.shade500)),
                ]),
                const SizedBox(height: 12),
                _search(true),
              ],
            )
          else
            Row(children: [
              const Text('Data Piutang', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(width: 10),
              Text('${data.length} data', style: TextStyle(color: Colors.grey.shade500)),
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
                  DataColumn(label: Text('#')),
                  DataColumn(label: Text('No. Akta')),
                  DataColumn(label: Text('NIK')),
                  DataColumn(label: Text('Nama')),
                  DataColumn(label: Text('Jenis Pekerjaan')),
                  DataColumn(label: Text('Pekerjaan')),
                  DataColumn(label: Text('Kategori')),
                  DataColumn(label: Text('Total Tagihan')),
                  DataColumn(label: Text('Total Piutang')),
                  DataColumn(label: Text('Petugas')),
                ],
                rows: List.generate(data.length, (i) {
                  final e = data[i];
                  return DataRow(cells: [
                    DataCell(Text('${i + 1}')),
                    DataCell(Text(e.noAkta, style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text(e.nik)),
                    DataCell(Text(e.nama)),
                    DataCell(Text(e.jenis)),
                    DataCell(SizedBox(width: 190, child: Text(e.pekerjaan, overflow: TextOverflow.ellipsis))),
                    DataCell(Text(e.kategori)),
                    DataCell(Text(e.totalTagihan)),
                    DataCell(Text(
                      e.totalPiutang,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    )),
                    DataCell(Text(e.petugas)),
                  ]);
                }),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (mobile)
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Menampilkan ${data.length} data', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              const SizedBox(height: 8),
              Text(
                'Total Piutang: ${_rupiah(totalPiutang)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              _pagination(),
            ])
          else
            Row(children: [
              Text('Menampilkan ${data.length} data', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              const SizedBox(width: 30),
              Text(
                'Total Piutang: ${_rupiah(totalPiutang)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              _pagination(),
            ]),
        ],
      ),
    );
  }

  Widget _search(bool mobile) => SizedBox(
    width: mobile ? double.infinity : 260,
    child: TextField(
      controller: searchController,
      onChanged: (_) => setState(() {}),
      decoration: _dec('Cari data...').copyWith(
        prefixIcon: const Icon(Icons.search),
      ),
    ),
  );

  Widget _pagination() => Wrap(
    spacing: 6,
    children: [
      OutlinedButton(onPressed: () {}, child: const Text('Previous')),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFBC7D7D),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text('1', style: TextStyle(color: Colors.white)),
      ),
      OutlinedButton(onPressed: () {}, child: const Text('Next')),
    ],
  );

  Widget _date(String label, String value, ValueChanged<String> onChanged) {
    return TextField(
      readOnly: true,
      controller: TextEditingController(text: value),
      decoration: _dec(label).copyWith(
        suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
      ),
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: DateTime(2026, 9, 11),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (d != null) {
          onChanged(
            '${d.day.toString().padLeft(2, '0')}/'
            '${d.month.toString().padLeft(2, '0')}/${d.year}',
          );
        }
      },
    );
  }

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(7)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
  );

  Widget _panel({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) =>
      Container(
        width: double.infinity,
        padding: padding,
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
        child: child,
      );

  void _reset() => setState(() {
    selectedJenis = 'Semua Jenis Pekerjaan';
    tanggalAwal = '11/09/2026';
    tanggalAkhir = '11/09/2026';
    searchController.clear();
  });

  String _rupiah(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
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

class _PiutangItem {
  final String noAkta;
  final String nik;
  final String nama;
  final String jenis;
  final String pekerjaan;
  final String kategori;
  final String totalTagihan;
  final String totalPiutang;
  final String petugas;

  const _PiutangItem(
    this.noAkta,
    this.nik,
    this.nama,
    this.jenis,
    this.pekerjaan,
    this.kategori,
    this.totalTagihan,
    this.totalPiutang,
    this.petugas,
  );
}
