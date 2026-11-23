import 'dart:io';

import 'package:excel_plus/excel_plus.dart';
import 'package:path/path.dart' as p;

import '../models/auth_session.dart';
import '../models/transaction_payments.dart';
import '../repositories/piutang_repository.dart';
import 'xlsx_export_file.dart';

const piutangScope =
    'Piutang layanan lokal. Kewajiban pajak PPAT di luar perhitungan ini.';

class PiutangExcelExport {
  const PiutangExcelExport({this.chooseDestination = chooseXlsxDestination});

  final Future<String?> Function(String) chooseDestination;

  Future<int?> run({
    required PiutangRepository repository,
    required AuthSession? Function() currentSession,
    required PiutangFilter filter,
  }) async {
    final session = currentSession();
    void requireRead() {
      if (!identical(session, currentSession()) || !canReadPiutang(session)) {
        throw StateError('Izin baca Piutang diperlukan.');
      }
    }

    requireRead();
    final now = DateTime.now();
    final stamp = now
        .toIso8601String()
        .substring(0, 16)
        .replaceAll(RegExp('[-:]'), '')
        .replaceFirst('T', '_');
    final destination = await chooseDestination('Piutang_Data_$stamp.xlsx');
    if (destination == null) return null;
    requireRead();
    final report = await repository.read(filter);
    final bytes = await _workbook(report, filter, now).encodeAsync();
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Workbook Excel tidak dapat dibuat.');
    }
    requireRead();
    await writeNewXlsx(
      destination,
      bytes,
      beforePublish: requireRead,
      validateDestination: (parent) {
        if (p
            .split(parent)
            .any((part) => part.toLowerCase() == 'transaction-documents')) {
          throw FileSystemException(
            'Pilih folder di luar penyimpanan dokumen transaksi.',
            parent,
          );
        }
      },
    );
    return report.rows.length;
  }
}

Excel _workbook(PiutangReport report, PiutangFilter filter, DateTime now) {
  const headerRow = 8;
  const maxExactExcel = 999999999999999;
  if (report.total > BigInt.from(maxExactExcel) ||
      report.rows.any((row) => row.billed > maxExactExcel)) {
    throw StateError(
      'Nominal hasil melebihi 15 digit presisi Excel. Persempit filter.',
    );
  }
  if (report.rows.length > 1048576 - headerRow - 1) {
    throw StateError(
      'Hasil melebihi kapasitas lembar Excel. Persempit filter.',
    );
  }

  final excel = Excel.createExcel();
  excel.rename('Sheet1', 'Piutang Data');
  final sheet = excel['Piutang Data'];
  final header = CellStyle(
    bold: true,
    backgroundColorHex: ExcelColor.fromHexString('#6E2331'),
    fontColorHex: ExcelColor.white,
    horizontalAlign: HorizontalAlign.Center,
  );
  final identifier = CellStyle(numberFormat: NumFormat.standard_49);
  final money = CellStyle(
    numberFormat: NumFormat.custom(formatCode: '"Rp" #,##0'),
    horizontalAlign: HorizontalAlign.Right,
  );
  final wrap = CellStyle(textWrapping: TextWrapping.WrapText);
  TextCellValue text(String? value) {
    if ((value?.length ?? 0) > 32767) {
      throw StateError('Ada teks yang melebihi kapasitas satu sel Excel.');
    }
    return xlsxText(value);
  }

  CellIndex at(int row, int col) =>
      CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row);
  void cell(int row, int col, CellValue value, [CellStyle? style]) =>
      sheet.updateCell(at(row, col), value, cellStyle: style);
  void merge(int row, int from, int through) =>
      sheet.merge(at(row, from), at(row, through));
  String date(DateTime? value) =>
      value == null ? '—' : formatPaymentDate(value);

  merge(0, 0, 9);
  cell(
    0,
    0,
    text('Piutang Layanan Lokal'),
    CellStyle(bold: true, fontSize: 16),
  );
  merge(1, 0, 9);
  cell(1, 0, text(piutangScope));
  for (final (row, label, value) in <(int, String, CellValue)>[
    (2, 'Waktu ekspor', DateTimeCellValue.fromDateTime(now)),
    (3, 'Jatuh tempo', text('${date(filter.from)} – ${date(filter.through)}')),
    (
      4,
      'Jenis pekerjaan',
      text(filter.domain.isEmpty ? 'Semua' : piutangDomain(filter.domain)),
    ),
    (
      5,
      'Pencarian',
      text(filter.search.trim().isEmpty ? 'Semua' : filter.search.trim()),
    ),
  ]) {
    merge(row, 0, 1);
    merge(row, 2, 9);
    cell(row, 0, text(label));
    cell(
      row,
      2,
      value,
      row == 2
          ? CellStyle(
              numberFormat: NumFormat.custom(formatCode: 'dd/mm/yyyy hh:mm:ss'),
            )
          : wrap,
    );
  }
  merge(6, 0, 1);
  cell(6, 0, text('Data terverifikasi'));
  cell(6, 2, IntCellValue(report.rows.length));
  cell(6, 3, text('Perlu Ditinjau'));
  cell(6, 4, IntCellValue(report.reviews.length));
  merge(6, 5, 7);
  cell(6, 5, text('Total Piutang Layanan Terverifikasi'));
  merge(6, 8, 9);
  cell(6, 8, IntCellValue(report.total.toInt()), money.copyWith(boldVal: true));

  const columns = [
    ('No', 7.0),
    ('No Akta', 23.0),
    ('NIK Pemohon', 24.0),
    ('Nama Pemohon', 29.0),
    ('Jenis Pekerjaan', 20.0),
    ('Nama Pekerjaan', 44.0),
    ('Kategori', 32.0),
    ('Total', 23.0),
    ('Total Piutang', 23.0),
    ('Nama Petugas', 27.0),
  ];
  for (final (index, (label, width)) in columns.indexed) {
    sheet.setColumnWidth(index, width);
    cell(headerRow, index, text(label), header);
  }
  if (report.rows.isEmpty) {
    merge(headerRow + 1, 0, 9);
    cell(
      headerRow + 1,
      0,
      text('Tidak ada piutang layanan terverifikasi yang cocok dengan filter.'),
    );
  }
  for (final (index, row) in report.rows.indexed) {
    final pos = headerRow + index + 1;
    cell(pos, 0, IntCellValue(index + 1));
    cell(pos, 1, text(row.number), identifier);
    cell(pos, 2, text(row.nik), identifier);
    cell(pos, 3, text(row.applicant));
    cell(pos, 4, text(piutangDomain(row.domain)));
    cell(pos, 5, text(row.jobs), wrap);
    cell(pos, 6, text(row.categories), wrap);
    cell(pos, 7, IntCellValue(row.billed), money);
    cell(pos, 8, IntCellValue(row.remaining), money);
    cell(pos, 9, text(row.officer));
  }
  return excel;
}

String piutangDomain(String value) => value == 'ppat' ? 'PPAT' : 'Notaris';
