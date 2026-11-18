import 'dart:io';

import 'package:excel_plus/excel_plus.dart';
import 'package:path/path.dart' as p;

import '../models/auth_session.dart';
import '../repositories/pendapatan_repository.dart';
import 'xlsx_export_file.dart';

const pendapatanExportFilename = 'Pendapatan_Data.xlsx';
const pendapatanSheetTitle = 'Pendapatan Data';
const pendapatanHeaders = [
  'No',
  'Tanggal',
  'Penerimaan Tercatat',
  'Pengeluaran Tercatat',
  'Selisih Penerimaan–Pengeluaran',
];

class PendapatanExcelExport {
  const PendapatanExcelExport({this.chooseDestination = chooseXlsxDestination});

  final Future<String?> Function(String suggestedName) chooseDestination;

  Future<({int rows, int excluded})?> run({
    required PendapatanRepository repository,
    required AuthSession? Function() currentSession,
    required PendapatanPeriod period,
  }) async {
    final session = currentSession();
    void checkSession() {
      if (!identical(currentSession(), session) ||
          !canReadPendapatan(session)) {
        throw StateError(pendapatanDenied);
      }
      repository.requireRead(expectedSession: session);
    }

    checkSession();
    final destination = await chooseDestination(pendapatanExportFilename);
    if (destination == null) return null;
    checkSession();
    final report = await repository.read(period);
    final bytes = await _workbook(report).encodeAsync();
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Workbook Excel tidak dapat dibuat.');
    }
    checkSession();
    await writeNewXlsx(
      destination,
      bytes,
      beforePublish: checkSession,
      validateDestination: (parent) {
        if (p
            .split(parent)
            .any((part) => part.toLowerCase() == 'transaction-documents')) {
          throw FileSystemException(
            'Pilih lokasi di luar penyimpanan dokumen transaksi.',
            parent,
          );
        }
      },
    );
    return (rows: report.days.length, excluded: report.reviews.length);
  }
}

Excel _workbook(PendapatanReport report) {
  if (report.days.length > 1048575) {
    throw StateError(
      'Hasil melebihi kapasitas lembar Excel. Persempit periode.',
    );
  }
  final maxExact = BigInt.from(999999999999999);
  for (final amounts in [
    report.total,
    ...report.days.map((row) => row.amount),
  ]) {
    if ([
      amounts.receipts,
      amounts.expenses,
      amounts.difference,
    ].any((amount) => amount.abs() > maxExact)) {
      throw StateError(
        'Angka melampaui 15 digit presisi Excel. Persempit periode.',
      );
    }
  }

  final workbook = Excel.createExcel();
  workbook.rename('Sheet1', pendapatanSheetTitle);
  final sheet = workbook[pendapatanSheetTitle];
  final header = CellStyle(
    bold: true,
    backgroundColorHex: ExcelColor.fromHexString('#F1F2F4'),
    fontColorHex: ExcelColor.fromHexString('#26313B'),
  );
  final dateStyle = CellStyle(
    numberFormat: NumFormat.custom(formatCode: 'dd/mm/yyyy'),
  );
  final money = CellStyle(
    horizontalAlign: HorizontalAlign.Right,
    numberFormat: NumFormat.custom(formatCode: '"Rp" #,##0;-"Rp" #,##0'),
  );
  void cell(int row, int column, CellValue value, [CellStyle? style]) =>
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
        value,
        cellStyle: style,
      );
  const widths = [8.0, 16.0, 25.0, 26.0, 36.0];
  for (var column = 0; column < pendapatanHeaders.length; column++) {
    sheet.setColumnWidth(column, widths[column]);
    cell(0, column, xlsxText(pendapatanHeaders[column]), header);
  }
  for (var i = 0; i < report.days.length; i++) {
    final row = report.days[i];
    final index = i + 1;
    cell(index, 0, IntCellValue(index));
    cell(index, 1, DateCellValue.fromDateTime(row.date), dateStyle);
    cell(index, 2, IntCellValue(row.amount.receipts.toInt()), money);
    cell(index, 3, IntCellValue(row.amount.expenses.toInt()), money);
    cell(index, 4, IntCellValue(row.amount.difference.toInt()), money);
  }
  return workbook;
}
