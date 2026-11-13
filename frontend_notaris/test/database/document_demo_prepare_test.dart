import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/document_demo_main.dart';
import 'package:path/path.dart' as p;

import '../repositories/recycle_bin_repository_test.dart' show seedTransaction;
import '../services/transaction_document_preview_test.dart'
    show sampleJpeg, samplePdf;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final id = Platform.environment['NOTARIS_DOCUMENT_PREPARE'];
  test('prepare fresh document demo', () async {
    final root = documentDemoRoot(id!);
    final file = File(p.join(root.path, 'offline.sqlite'));
    expect(root.listSync().map((entry) => p.basename(entry.path)), ['owner']);
    final db = DocumentProfileDatabase(NativeDatabase(file));
    try {
      for (final domain in ['notaris', 'ppat']) {
        final transactionId = await seedTransaction(db, domain);
        final prefix = domain == 'notaris' ? '1' : '2';
        await db.customStatement('UPDATE transaksis SET no_akta=? WHERE id=?', [
          '${prefix}001111260001',
          transactionId,
        ]);
        await db.customStatement(
          'UPDATE transaksi_details SET nama_pekerjaan_snapshot=? WHERE transaksi_id=?',
          [
            domain == 'notaris'
                ? 'Pembuatan Akta Fidusia'
                : 'Pembuatan Akta Jual Beli',
            transactionId,
          ],
        );
      }
      await db.customStatement("UPDATE pemohons SET nama='Bagas Pradipta'");
      await db.customStatement("UPDATE petugas SET nama='Dimas Prasetyo'");
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    } finally {
      await db.close();
    }
    final (runtime, _) = await openDocumentDemo(id);
    try {
      expect(runtime.schemaVersion, 25);
      expect(
        await runtime.customSelect('SELECT * FROM transaction_documents').get(),
        isEmpty,
      );
    } finally {
      await runtime.close();
    }
    await File(p.join(root.path, 'Salinan Fidusia.pdf'))
        .writeAsBytes(await samplePdf(595, 842));
    await File(p.join(root.path, 'Foto AJB.jpg')).writeAsBytes(sampleJpeg());
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(const ui.Color(0xff333333), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(8, 8);
    picture.dispose();
    try {
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
          .buffer
          .asUint8List();
      await File(p.join(root.path, 'Peta AJB.png')).writeAsBytes(bytes);
    } finally {
      image.dispose();
    }
  }, skip: id == null);
}
