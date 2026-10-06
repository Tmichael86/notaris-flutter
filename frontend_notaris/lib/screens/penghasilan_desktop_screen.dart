import 'package:flutter/material.dart';
import '../core/widgets/searchable_dropdown.dart';

class PenghasilanDesktopScreen extends StatefulWidget {
  const PenghasilanDesktopScreen({super.key});
  @override
  State<PenghasilanDesktopScreen> createState() => _PenghasilanDesktopScreenState();
}

class _PenghasilanDesktopScreenState extends State<PenghasilanDesktopScreen> {
  final tableController = ScrollController();
  final searchController = TextEditingController();

  String jenis = 'Semua Jenis Pekerjaan';
  String pekerjaan = 'Semua Pekerjaan';
  String kategori = 'Semua Kategori';
  String status = 'Semua Status';
  String petugas = 'Semua Petugas';
  String dari = '11/09/2026';
  String sampai = '11/09/2026';

  final data = <_Row>[
    _Row('11/09/2026','NTRX-2026-0001','3505010101000001','Budi Santoso','Notaris','Akta Jual Beli','Jual Beli','Rp 1.500.000','Rp 1.000.000','Rp 500.000','Rina Wulandari','Selesai'),
    _Row('11/09/2026','NTRX-2026-0002','3505010101000002','Siti Aminah','Notaris','Akta Kuasa','Kuasa','Rp 750.000','Rp 750.000','Rp 0','Dimas Saputra','Selesai'),
    _Row('10/09/2026','PTRX-2026-0001','3505010101000003','Andi Pratama','PPAT','Akta Jual Beli Tanah','Jual Beli','Rp 2.500.000','Rp 1.250.000','Rp 1.250.000','Sari Anggraini','Belum Selesai'),
    _Row('09/09/2026','NTRX-2026-0003','3505010101000004','Dewi Lestari','Notaris','Akta Hibah','Hibah','Rp 1.250.000','Rp 950.000','Rp 300.000','Rina Wulandari','Selesai'),
    _Row('08/09/2026','PTRX-2026-0002','3505010101000005','Agus Setiawan','PPAT','Akta Hibah Tanah','Hibah','Rp 2.000.000','Rp 1.000.000','Rp 1.000.000','Dimas Saputra','Selesai'),
    _Row('07/09/2026','NTRX-2026-0004','3505010101000006','Fajar Nugroho','Notaris','Akta Waris','Waris','Rp 1.000.000','Rp 550.000','Rp 450.000','Sari Anggraini','Selesai'),
    _Row('06/09/2026','PTRX-2026-0003','3505010101000007','Maya Putri','PPAT','Akta Pembagian Hak Bersama','Pembagian Hak','Rp 2.250.000','Rp 1.350.000','Rp 900.000','Rina Wulandari','Belum Selesai'),
  ];

  List<_Row> get filtered {
    final q = searchController.text.toLowerCase().trim();
    return data.where((e) =>
      (jenis == 'Semua Jenis Pekerjaan' || e.jenis == jenis) &&
      (pekerjaan == 'Semua Pekerjaan' || e.pekerjaan == pekerjaan) &&
      (kategori == 'Semua Kategori' || e.kategori == kategori) &&
      (status == 'Semua Status' || e.status == status) &&
      (petugas == 'Semua Petugas' || e.petugas == petugas) &&
      (q.isEmpty || e.noTransaksi.toLowerCase().contains(q) || e.nik.contains(q) || e.nama.toLowerCase().contains(q) || e.pekerjaan.toLowerCase().contains(q) || e.petugas.toLowerCase().contains(q))
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final mobile = c.maxWidth < 700;
      return Padding(
        padding: EdgeInsets.fromLTRB(mobile ? 16 : 28, 20, mobile ? 16 : 28, 30),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _header(mobile),
          const SizedBox(height: 18),
          _filters(mobile),
          const SizedBox(height: 18),
          _table(mobile),
        ]),
      );
    });
  }

  Widget _header(bool mobile) {
    final excel = ElevatedButton.icon(
      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export Excel masih berupa dummy.'))),
      icon: const Icon(Icons.table_view_outlined, size: 18),
      label: const Text('Excel'),
      style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white),
    );
    return mobile
      ? Row(children: [const Expanded(child: Text('Penghasilan', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w500))), excel])
      : Row(children: [
          const Text('Penghasilan', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w500)),
          const SizedBox(width: 14),
          Text('Penghasilan  |  Page', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          const Spacer(), excel
        ]);
  }

  Widget _filters(bool mobile) {
    return _panel(child: LayoutBuilder(builder: (context, c) {
      const gap = 12.0;
      final w = mobile ? c.maxWidth : (c.maxWidth - gap * 3) / 4;
      return Wrap(spacing: gap, runSpacing: 12, children: [
        SizedBox(width: w, child: _date('Dari Tanggal', dari, (v) => setState(() => dari = v))),
        SizedBox(width: w, child: _date('Sampai Tanggal', sampai, (v) => setState(() => sampai = v))),
        SizedBox(width: w, child: _drop('Jenis Pekerjaan', jenis, const ['Semua Jenis Pekerjaan','Notaris','PPAT'], (v) => setState(() { jenis = v!; pekerjaan = 'Semua Pekerjaan'; }))),
        SizedBox(width: w, child: _drop('Pekerjaan', pekerjaan, const ['Semua Pekerjaan','Akta Jual Beli','Akta Kuasa','Akta Hibah','Akta Waris','Akta Jual Beli Tanah','Akta Hibah Tanah','Akta Pembagian Hak Bersama'], (v) => setState(() => pekerjaan = v!))),
        SizedBox(width: w, child: _drop('Kategori', kategori, const ['Semua Kategori','Jual Beli','Kuasa','Hibah','Waris','Pembagian Hak'], (v) => setState(() => kategori = v!))),
        SizedBox(width: w, child: _drop('Status', status, const ['Semua Status','Selesai','Belum Selesai'], (v) => setState(() => status = v!))),
        SizedBox(width: w, child: _drop('Petugas', petugas, const ['Semua Petugas','Rina Wulandari','Dimas Saputra','Sari Anggraini'], (v) => setState(() => petugas = v!))),
        SizedBox(width: mobile ? w : 110, child: OutlinedButton.icon(onPressed: _reset, icon: const Icon(Icons.refresh, size: 18), label: const Text('Reset'))),
      ]);
    }));
  }

  Widget _table(bool mobile) {
    final list = filtered;
    return _panel(padding: const EdgeInsets.all(16), child: Column(children: [
      mobile
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Expanded(child: Text('Data Penghasilan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))), Text('${list.length} data', style: TextStyle(color: Colors.grey.shade500))]),
            const SizedBox(height: 12), _search(true)
          ])
        : Row(children: [
            const Text('Data Penghasilan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(width: 10), Text('${list.length} data', style: TextStyle(color: Colors.grey.shade500)),
            const Spacer(), _search(false)
          ]),
      const SizedBox(height: 16),
      Scrollbar(
        controller: tableController, thumbVisibility: true,
        notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
        child: SingleChildScrollView(
          controller: tableController, scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: DataTable(
            columnSpacing: mobile ? 28 : 26,
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF5F5F5)),
            columns: const [
              DataColumn(label: Text('#')), DataColumn(label: Text('Tanggal Pembayaran')),
              DataColumn(label: Text('No. Transaksi')), DataColumn(label: Text('NIK')),
              DataColumn(label: Text('Nama')), DataColumn(label: Text('Jenis Pekerjaan')),
              DataColumn(label: Text('Pekerjaan')), DataColumn(label: Text('Kategori')),
              DataColumn(label: Text('Jumlah Tagihan')), DataColumn(label: Text('Jumlah Dibayar')),
              DataColumn(label: Text('Sisa Tagihan')), DataColumn(label: Text('Petugas')),
              DataColumn(label: Text('Status')),
            ],
            rows: List.generate(list.length, (i) {
              final e = list[i];
              return DataRow(cells: [
                DataCell(Text('${i + 1}')), DataCell(Text(e.tanggal)), DataCell(Text(e.noTransaksi, style: const TextStyle(fontWeight: FontWeight.w600))),
                DataCell(Text(e.nik)), DataCell(Text(e.nama)), DataCell(Text(e.jenis)),
                DataCell(SizedBox(width: 190, child: Text(e.pekerjaan, overflow: TextOverflow.ellipsis))),
                DataCell(Text(e.kategori)), DataCell(Text(e.tagihan)), DataCell(Text(e.dibayar)),
                DataCell(Text(e.sisa, style: const TextStyle(fontWeight: FontWeight.w700))),
                DataCell(Text(e.petugas)), DataCell(_badge(e.status)),
              ]);
            }),
          ),
        ),
      ),
      const SizedBox(height: 14),
      mobile
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Menampilkan ${list.length} data', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 8), Text('Total Penghasilan: ${_total(list)}', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10), _pagination()
          ])
        : Row(children: [
            Text('Menampilkan ${list.length} data', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(width: 30), Text('Total Penghasilan: ${_total(list)}', style: const TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(), _pagination()
          ]),
    ]));
  }

  Widget _search(bool mobile) => SizedBox(width: mobile ? double.infinity : 260, child: TextField(
    controller: searchController, onChanged: (_) => setState(() {}),
    decoration: _dec('Cari data...').copyWith(prefixIcon: const Icon(Icons.search)),
  ));

  Widget _drop(String label, String value, List<String> items, ValueChanged<String?> onChanged) => SearchableDropdown<String>(
    value: value,
    items: items,
    label: label,
    onChanged: onChanged,
  );

  Widget _date(String label, String value, ValueChanged<String> onChanged) => TextField(
    readOnly: true, controller: TextEditingController(text: value),
    decoration: _dec(label).copyWith(suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18)),
    onTap: () async {
      final d = await showDatePicker(context: context, initialDate: DateTime(2026,9,11), firstDate: DateTime(2020), lastDate: DateTime(2100));
      if (d != null) onChanged('${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}');
    },
  );

  Widget _badge(String value) {
    final done = value == 'Selesai';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: done ? Colors.green.shade50 : Colors.orange.shade50, borderRadius: BorderRadius.circular(20)),
      child: Text(value, style: TextStyle(color: done ? Colors.green.shade700 : Colors.orange.shade700, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }

  Widget _pagination() => Wrap(spacing: 6, children: [
    OutlinedButton(onPressed: () {}, child: const Text('Previous')),
    Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9), decoration: BoxDecoration(color: const Color(0xFFBC7D7D), borderRadius: BorderRadius.circular(6)), child: const Text('1', style: TextStyle(color: Colors.white))),
    OutlinedButton(onPressed: () {}, child: const Text('Next')),
  ]);

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(7)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
  );

  Widget _panel({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(16)}) => Container(
    width: double.infinity, padding: padding,
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE5E5E5)),
      boxShadow: const [BoxShadow(blurRadius: 8, offset: Offset(0,2), color: Color(0x10000000))]),
    child: child,
  );

  String _total(List<_Row> list) {
    var total = 0;
    for (final e in list) {
      total += int.tryParse(e.dibayar.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }
    final s = total.toString();
    final b = StringBuffer();
    for (var i=0; i<s.length; i++) {
      b.write(s[i]); final left = s.length-i-1;
      if (left > 0 && left % 3 == 0) b.write('.');
    }
    return 'Rp $b';
  }

  void _reset() => setState(() {
    jenis='Semua Jenis Pekerjaan'; pekerjaan='Semua Pekerjaan'; kategori='Semua Kategori';
    status='Semua Status'; petugas='Semua Petugas'; dari='11/09/2026'; sampai='11/09/2026';
    searchController.clear();
  });

  @override
  void dispose() { tableController.dispose(); searchController.dispose(); super.dispose(); }
}

class _Row {
  final String tanggal,noTransaksi,nik,nama,jenis,pekerjaan,kategori,tagihan,dibayar,sisa,petugas,status;
  const _Row(this.tanggal,this.noTransaksi,this.nik,this.nama,this.jenis,this.pekerjaan,this.kategori,this.tagihan,this.dibayar,this.sisa,this.petugas,this.status);
}
