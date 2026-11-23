import 'dart:io';

import 'package:excel_plus/excel_plus.dart';
import 'package:path/path.dart' as p;

import '../database/app_database.dart';
import '../models/auth_session.dart';
import '../repositories/pengeluaran_repository.dart';
import 'xlsx_export_file.dart';

class PengeluaranExcelExport {
  const PengeluaranExcelExport({
    this.chooseDestination = chooseXlsxDestination,
  });

  final Future<String?> Function(String suggestedName) chooseDestination;

  /// Returns the number of saved rows, or null when Save As is cancelled.
  Future<int?> run({
    required PengeluaranRepository repository,
    required AuthSession? Function() currentSession,
    required PengeluaranFilter filter,
    String? jenisLabel,
  }) async {
    final session = currentSession();
    void checkSession() {
      if (!identical(currentSession(), session) ||
          !allowsPengeluaran(session, PengeluaranAction.read)) {
        throw const PengeluaranFailure('Izin baca Pengeluaran diperlukan.');
      }
    }

    checkSession();
    final now = DateTime.now();
    final destination = await chooseDestination(
      'Pengeluaran_Data_${now.year}${_two(now.month)}${_two(now.day)}_'
      '${_two(now.hour)}${_two(now.minute)}.xlsx',
    );
    if (destination == null) return null;
    checkSession();
    final rows = await repository.readExport(filter);
    final bytes = await _workbook(rows, filter, jenisLabel, now).encodeAsync();
    if (bytes == null || bytes.isEmpty) {
      throw const PengeluaranFailure('Workbook Excel tidak dapat dibuat.');
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
            'Pilih folder di luar penyimpanan dokumen transaksi.',
            parent,
          );
        }
      },
    );
    return rows.length;
  }
}

Excel _workbook(
  List<PengeluaranData> rows,
  PengeluaranFilter filter,
  String? jenisLabel,
  DateTime now,
) {
  const headerRow = 7;
  if (rows.length > 1048576 - headerRow - 1) {
    throw const PengeluaranFailure(
      'Hasil melebihi kapasitas lembar Excel. Persempit filter.',
    );
  }
  // Every amount is positive. Capping the exact total also bounds every row.
  final total = rows.fold(
    BigInt.zero,
    (sum, row) => sum + BigInt.from(row.nominal),
  );
  if (total > BigInt.from(999999999999999)) {
    throw const PengeluaranFailure(
      'Total melebihi 15 digit presisi Excel. Persempit filter.',
    );
  }
  const title = 'Pengeluaran Data';
  final excel = Excel.createExcel();
  excel.rename('Sheet1', title);
  final sheet = excel[title];
  final header = CellStyle(
    bold: true,
    backgroundColorHex: ExcelColor.fromHexString('#6E2331'),
    fontColorHex: ExcelColor.white,
    horizontalAlign: HorizontalAlign.Center,
  );
  final date = CellStyle(
    numberFormat: NumFormat.custom(formatCode: 'dd/mm/yyyy'),
    horizontalAlign: HorizontalAlign.Center,
  );
  final amount = CellStyle(
    numberFormat: NumFormat.custom(formatCode: '"Rp" #,##0'),
    horizontalAlign: HorizontalAlign.Right,
  );
  final identifier = CellStyle(numberFormat: NumFormat.standard_49);
  final note = CellStyle(textWrapping: TextWrapping.WrapText);

  void cell(int row, int column, CellValue value, [CellStyle? style]) =>
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
        value,
        cellStyle: style,
      );

  void merge(int row, int from, int through) => sheet.merge(
    CellIndex.indexByColumnRow(columnIndex: from, rowIndex: row),
    CellIndex.indexByColumnRow(columnIndex: through, rowIndex: row),
  );

  TextCellValue text(String? value) {
    if ((value?.length ?? 0) > 32767) {
      throw const PengeluaranFailure(
        'Ada teks yang melebihi kapasitas satu sel Excel.',
      );
    }
    return xlsxText(value);
  }

  merge(0, 0, 5);
  cell(0, 0, text(title), CellStyle(bold: true, fontSize: 16));
  for (final (row, label, value) in <(int, String, CellValue)>[
    (1, 'Waktu ekspor', DateTimeCellValue.fromDateTime(now)),
    (
      2,
      'Tanggal',
      text('${_dateLabel(filter.from)} – ${_dateLabel(filter.through)}'),
    ),
    (
      3,
      'Jenis Pengeluaran',
      text(
        filter.jenisId == null ? 'Semua' : jenisLabel ?? 'ID ${filter.jenisId}',
      ),
    ),
    (
      4,
      'Pencarian',
      text(filter.search.trim().isEmpty ? 'Semua' : filter.search.trim()),
    ),
  ]) {
    merge(row, 0, 1);
    merge(row, 2, 5);
    cell(row, 0, text(label));
    cell(
      row,
      2,
      value,
      row == 1
          ? CellStyle(
              numberFormat: NumFormat.custom(formatCode: 'dd/mm/yyyy hh:mm:ss'),
            )
          : note,
    );
  }
  merge(5, 0, 1);
  cell(5, 0, text('Jumlah data'));
  cell(5, 2, IntCellValue(rows.length));
  cell(5, 3, text('Total Pengeluaran'));
  merge(5, 4, 5);
  cell(5, 4, IntCellValue(total.toInt()), amount.copyWith(boldVal: true));

  const columns = [
    ('No', 7.0),
    ('No Faktur', 24.0),
    ('Keterangan', 48.0),
    ('Jenis Pengeluaran', 26.0),
    ('Jumlah', 23.0),
    ('Tanggal Pengeluaran', 24.0),
  ];
  for (final (column, (label, width)) in columns.indexed) {
    sheet.setColumnWidth(column, width);
    cell(headerRow, column, text(label), header);
  }
  if (rows.isEmpty) {
    merge(headerRow + 1, 0, 5);
    cell(
      headerRow + 1,
      0,
      text('Tidak ada pengeluaran yang cocok dengan filter.'),
    );
  }
  for (final (index, item) in rows.indexed) {
    final row = headerRow + index + 1;
    final calendar = item.tanggal.toUtc();
    cell(row, 0, IntCellValue(index + 1));
    cell(row, 1, text(item.noFaktur), identifier);
    cell(row, 2, text(item.keterangan), note);
    cell(row, 3, text(item.jenisNama), note);
    cell(row, 4, IntCellValue(item.nominal), amount);
    if (calendar.year >= 1900) {
      cell(row, 5, DateCellValue.fromDateTime(calendar), date);
    } else {
      cell(row, 5, text(_dateLabel(calendar)));
    }
  }
  return excel;
}

String _two(int number) => number.toString().padLeft(2, '0');

String _dateLabel(DateTime? value) => value == null
    ? '—'
    : '${_two(value.day)}/${_two(value.month)}/${value.year.toString().padLeft(4, '0')}';
