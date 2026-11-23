import 'dart:ffi';
import 'dart:io';

import 'package:excel_plus/excel_plus.dart';
import 'package:ffi/ffi.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;

Future<String?> chooseXlsxDestination(String suggestedName) async =>
    (await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Excel', extensions: ['xlsx']),
      ],
    ))?.path;

/// Publishes a complete workbook without replacing a destination, even if
/// Windows Save As offered to replace it or another process created it later.
Future<void> writeNewXlsx(
  String destination,
  List<int> bytes, {
  required void Function() beforePublish,
  void Function(String parent)? validateDestination,
}) async {
  final file = File(
    destination.toLowerCase().endsWith('.xlsx')
        ? destination
        : '$destination.xlsx',
  );
  final parent = await file.parent.resolveSymbolicLinks();
  validateDestination?.call(parent);
  final target = p.join(parent, p.basename(file.path));
  final staging = await Directory(parent).createTemp('.xlsx-export-');
  final staged = File(p.join(staging.path, 'export.xlsx'));
  try {
    await staged.writeAsBytes(bytes, flush: true);
    beforePublish();
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
}

// Typed text cells preserve identifiers and never emit spreadsheet formulas.
TextCellValue xlsxText(String? value) => TextCellValue(
  value == null || value.trim().isEmpty
      ? '—'
      : value.replaceAll(
          RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\ufffe\uffff]'),
          '\uFFFD',
        ),
);
