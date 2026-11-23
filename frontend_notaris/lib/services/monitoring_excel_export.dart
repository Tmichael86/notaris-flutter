import 'package:excel_plus/excel_plus.dart';

import '../models/auth_session.dart';
import '../models/transaction_monitoring.dart';
import '../repositories/transaction_repository.dart';
import 'xlsx_export_file.dart';

class MonitoringExcelExport {
  const MonitoringExcelExport({this.chooseDestination = chooseXlsxDestination});

  final Future<String?> Function(String suggestedName) chooseDestination;

  /// Returns null when the user cancels Save As.
  Future<int?> run({
    required TransactionRepository repository,
    required AuthSession? Function() currentSession,
    required MonitoringFilter filter,
    String? officerLabel,
  }) async {
    final session = currentSession();
    void checkSession() {
      if (session?.canExportMonitoring != true ||
          !identical(currentSession(), session)) {
        throw StateError('Izin baca Monitoring dan Transaksi diperlukan.');
      }
    }

    checkSession();
    final now = DateTime.now();
    final destination = await chooseDestination(
      'Monitoring_Transaksi_${now.year}${_two(now.month)}${_two(now.day)}_'
      '${_two(now.hour)}${_two(now.minute)}.xlsx',
    );
    if (destination == null) return null;
    checkSession();
    final rows = await repository.readMonitoringExport(filter, session);
    final bytes = await _workbook(
      rows,
      filter,
      officerLabel,
      now,
    ).encodeAsync();
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Workbook Excel tidak dapat dibuat.');
    }
    checkSession();

    await writeNewXlsx(destination, bytes, beforePublish: checkSession);
    return rows.length;
  }
}

Excel _workbook(
  List<MonitoringExportRow> rows,
  MonitoringFilter filter,
  String? officerLabel,
  DateTime now,
) {
  final excel = Excel.createExcel();
  excel.rename('Sheet1', 'Monitoring Transaksi');
  final sheet = excel['Monitoring Transaksi'];
  const columns = [
    ('No', 7.0),
    ('Tanggal Daftar', 18.0),
    ('Tanggal Selesai', 19.0),
    ('No. Transaksi', 23.0),
    ('NIK Pemohon', 24.0),
    ('Nama Pemohon', 28.0),
    ('Jenis Pekerjaan', 19.0),
    ('Nama Pekerjaan', 40.0),
    ('Kategori', 28.0),
    ('Estimasi Waktu', 20.0),
    ('Proses', 42.0),
    ('Total Tagihan', 20.0),
    ('Sisa Tagihan', 20.0),
    ('Nama Petugas', 27.0),
    ('Status', 20.0),
  ];
  final header = CellStyle(
    bold: true,
    backgroundColorHex: ExcelColor.fromHexString('#6E2331'),
    fontColorHex: ExcelColor.white,
  );
  final dateStyle = CellStyle(
    numberFormat: NumFormat.custom(formatCode: 'dd/mm/yyyy'),
  );
  final money = CellStyle(
    numberFormat: NumFormat.custom(formatCode: '"Rp" #,##0'),
  );
  final fractionalMoney = CellStyle(
    numberFormat: NumFormat.custom(formatCode: '"Rp" #,##0.00'),
  );
  final identifier = CellStyle(
    numberFormat: NumFormat.standard_49,
    horizontalAlign: HorizontalAlign.Left,
  );
  void cell(int row, int col, CellValue? value, [CellStyle? style]) {
    if (value != null) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
        value,
        cellStyle: style,
      );
    }
  }

  sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('K1'));
  cell(
    0,
    0,
    TextCellValue('Monitoring Transaksi'),
    CellStyle(bold: true, fontSize: 16),
  );
  sheet.merge(CellIndex.indexByString('A2'), CellIndex.indexByString('B2'));
  sheet.merge(CellIndex.indexByString('C2'), CellIndex.indexByString('E2'));
  cell(1, 0, TextCellValue('Waktu ekspor'));
  cell(
    1,
    2,
    DateTimeCellValue.fromDateTime(now),
    CellStyle(
      numberFormat: NumFormat.custom(formatCode: 'dd/mm/yyyy hh:mm:ss'),
    ),
  );
  final context = [
    ('Jenis', filter.domain.isEmpty ? 'Semua' : _domain(filter.domain)),
    (
      'Tanggal',
      filter.from == null && filter.until == null
          ? 'Semua tanggal'
          : '${_dateLabel(filter.from)} – ${_dateLabel(filter.until)}',
    ),
    ('Pekerjaan', _filterLabel(filter.job)),
    ('Kategori', _filterLabel(filter.category)),
    ('Status', _filterLabel(filter.status)),
    (
      'Petugas',
      filter.officerId == 0
          ? 'Semua'
          : officerLabel ?? 'ID ${filter.officerId}',
    ),
    ('Pencarian', _filterLabel(filter.search)),
  ];
  for (final (index, (label, value)) in context.indexed) {
    final row = index + 2;
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row),
    );
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row),
    );
    cell(row, 0, xlsxText(label));
    cell(row, 2, xlsxText(value));
  }
  // Only business dates available in SQLite are written as date cells.
  sheet.merge(CellIndex.indexByString('A10'), CellIndex.indexByString('K10'));
  cell(
    9,
    0,
    xlsxText(
      'Tanggal selesai belum tercatat sebagai tanggal penyelesaian transaksi.',
    ),
  );
  cell(10, 0, xlsxText('Jumlah'));
  cell(10, 1, IntCellValue(rows.length));
  for (final (index, (label, width)) in columns.indexed) {
    sheet.setColumnWidth(index, width);
    cell(12, index, xlsxText(label), header);
  }
  for (final (index, item) in rows.indexed) {
    final row = index + 13;
    final tx = item.row.transaction;
    final date = tx.tanggalTransaksi?.toLocal();
    cell(row, 0, IntCellValue(index + 1));
    if (date != null) {
      cell(row, 1, DateCellValue.fromDateTime(date), dateStyle);
    }
    cell(row, 3, xlsxText(tx.noAkta), identifier);
    cell(row, 4, xlsxText(item.row.nik), identifier);
    cell(row, 5, xlsxText(item.row.applicant));
    cell(row, 6, xlsxText(_domain(tx.jenisTransaksi)));
    cell(row, 7, xlsxText(item.row.jobs));
    cell(row, 8, xlsxText(item.row.categories));
    cell(row, 9, xlsxText(item.estimates));
    cell(row, 10, xlsxText(item.processes));
    if (tx.total.isFinite) {
      cell(
        row,
        11,
        DoubleCellValue(tx.total),
        tx.total == tx.total.truncateToDouble() ? money : fractionalMoney,
      );
    }
    final remaining = item.remaining;
    if (remaining != null) {
      cell(row, 12, IntCellValue(remaining), money);
    }
    cell(row, 13, xlsxText(item.row.officer));
    cell(row, 14, xlsxText(tx.statusTransaksi));
  }
  return excel;
}

String _domain(String value) => switch (value) {
  'notaris' => 'Notaris',
  'ppat' => 'PPAT',
  _ => value,
};
String _filterLabel(String value) =>
    value.trim().isEmpty ? 'Semua' : value.trim();
String _two(int n) => n.toString().padLeft(2, '0');
String _dateLabel(DateTime? value) => value == null
    ? '—'
    : '${_two(value.day)}/${_two(value.month)}/${value.year}';
