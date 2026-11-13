import 'dart:ffi';
import 'dart:io';

import 'package:excel_plus/excel_plus.dart';
import 'package:ffi/ffi.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;

import '../models/auth_session.dart';
import '../models/transaction_monitoring.dart';
import '../repositories/transaction_repository.dart';

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

    final file = File(
      destination.toLowerCase().endsWith('.xlsx')
          ? destination
          : '$destination.xlsx',
    );
    final parent = await file.parent.resolveSymbolicLinks();
    final target = p.join(parent, p.basename(file.path));
    final staging = await Directory(parent).createTemp('.monitoring-export-');
    final staged = File(p.join(staging.path, 'export.xlsx'));
    try {
      await staged.writeAsBytes(bytes, flush: true);
      checkSession();
      // Windows MoveFileW publishes the completed file without replacement.
      // It also refuses a destination created while the export was running.
      using((arena) {
        final move = DynamicLibrary.open('kernel32.dll')
            .lookupFunction<
              Int32 Function(Pointer<Utf16>, Pointer<Utf16>),
              int Function(Pointer<Utf16>, Pointer<Utf16>)
            >('MoveFileW');
        if (move(
              staged.path.toNativeUtf16(allocator: arena),
              target.toNativeUtf16(allocator: arena),
            ) ==
            0) {
          throw FileSystemException('Excel gagal disimpan.', target);
        }
      });
    } finally {
      try {
        if (await staged.exists()) await staged.delete();
        await staging.delete();
      } on FileSystemException {
        // Cleanup is limited to the staging directory created for this export.
      }
    }
    return rows.length;
  }
}

Future<String?> chooseXlsxDestination(String suggestedName) async =>
    (await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Excel', extensions: ['xlsx']),
      ],
    ))?.path;

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
    cell(row, 0, _text(label));
    cell(row, 2, _text(value));
  }
  // Only business dates available in SQLite are written as date cells.
  sheet.merge(CellIndex.indexByString('A10'), CellIndex.indexByString('K10'));
  cell(
    9,
    0,
    _text(
      'Tanggal selesai belum tercatat sebagai tanggal penyelesaian transaksi.',
    ),
  );
  cell(10, 0, _text('Jumlah'));
  cell(10, 1, IntCellValue(rows.length));
  for (final (index, (label, width)) in columns.indexed) {
    sheet.setColumnWidth(index, width);
    cell(12, index, _text(label), header);
  }
  for (final (index, item) in rows.indexed) {
    final row = index + 13;
    final tx = item.row.transaction;
    final date = tx.tanggalTransaksi?.toLocal();
    cell(row, 0, IntCellValue(index + 1));
    if (date != null) {
      cell(row, 1, DateCellValue.fromDateTime(date), dateStyle);
    }
    cell(row, 3, _text(tx.noAkta), identifier);
    cell(row, 4, _text(item.row.nik), identifier);
    cell(row, 5, _text(item.row.applicant));
    cell(row, 6, _text(_domain(tx.jenisTransaksi)));
    cell(row, 7, _text(item.row.jobs));
    cell(row, 8, _text(item.row.categories));
    cell(row, 9, _text(item.estimates));
    cell(row, 10, _text(item.processes));
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
    cell(row, 13, _text(item.row.officer));
    cell(row, 14, _text(tx.statusTransaksi));
  }
  return excel;
}

// Typed text cells preserve identifiers and never emit spreadsheet formulas.
TextCellValue _text(String? value) => TextCellValue(
  value == null || value.trim().isEmpty
      ? '—'
      : value.replaceAll(
          RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\ufffe\uffff]'),
          '\uFFFD',
        ),
);

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
