import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/penghasilan_demo_main.dart';
import 'package:frontend_notaris/repositories/penghasilan_repository.dart';
import 'package:path/path.dart' as p;

import '../support/penghasilan_fixture.dart';

void main() {
  final id = Platform.environment['NOTARIS_PENGHASILAN_PREPARE'];
  test('one disposable profile preserves all SQLite bytes through query_only reporting', () async {
    final root = penghasilanDemoRoot(id!);
    final file = await File(p.join(root.path, 'offline.sqlite'))
        .create(exclusive: true);
    final writer = AppDatabase.forTesting(
      NativeDatabase(
        file,
        setup: (sqlite) => sqlite.execute('PRAGMA foreign_keys=ON'),
      ),
    );
    try {
      await seedPenghasilan(writer);
    } finally {
      await writer.close();
    }
    final before = sha256.convert(await file.readAsBytes());
    final db = await openPenghasilanDemo(id);
    try {
      final repo = PenghasilanRepository(db, penghasilanReader);
      final report = await repo.read();
      expect(
        (report.rows.length, report.reviews.length, report.total),
        (13, 1, BigInt.from(480000)),
      );
      expect(
        report.filtered(receiptFilter(domain: 'ppat')).total,
        BigInt.from(185000),
      );
      expect(
        report.filtered(receiptFilter(search: 'PEN-01')).total,
        BigInt.from(170000),
      );
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      expect(
        (await db.customSelect('PRAGMA integrity_check').getSingle())
            .read<String>('integrity_check'),
        'ok',
      );
    } finally {
      await db.close();
    }
    expect(sha256.convert(await file.readAsBytes()), before);
  }, skip: id == null);
}
