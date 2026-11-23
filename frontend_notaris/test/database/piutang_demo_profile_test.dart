import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:excel_plus/excel_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/piutang_demo_main.dart';
import 'package:frontend_notaris/repositories/piutang_repository.dart';
import 'package:frontend_notaris/services/piutang_excel_export.dart';
import 'package:path/path.dart' as p;

import '../support/piutang_fixture.dart';

void main() {
  final id = Platform.environment['NOTARIS_PIUTANG_PREPARE'];
  test('prepare one disposable Piutang SQLite; export under query_only and verify hash', () async {
    final root = piutangDemoRoot(id!);
    final file = await File(p.join(root.path, 'offline.sqlite'))
        .create(exclusive: true);
    final writer = AppDatabase.forTesting(
      NativeDatabase(
        file,
        setup: (sqlite) => sqlite.execute('PRAGMA foreign_keys=ON'),
      ),
    );
    try {
      await seedPiutang(writer);
    } finally {
      await writer.close();
    }
    final before = sha256.convert(await file.readAsBytes());
    final db = await openPiutangDemo(id);
    final folder = await Directory.systemTemp.createTemp('piutang-demo-proof-');
    try {
      final session = piutangReader();
      final repo = PiutangRepository(db, () => session);
      final report = await repo.read(allPiutang);
      expect(
        (report.rows.length, report.reviews.length, report.total),
        (13, 1, BigInt.from(1055000)),
      );
      expect(report.rows.singleWhere((row) => row.id == 3).remaining, 100000);
      expect(
        (await repo.read(piutangFilter(domain: 'ppat'))).total,
        BigInt.from(450000),
      );
      expect(
        (await repo.read(piutangFilter(domain: 'notaris'))).total,
        BigInt.from(605000),
      );
      final xlsx = File(p.join(folder.path, 'Piutang_Data.xlsx'));
      final exporter = PiutangExcelExport(
        chooseDestination: (_) async => xlsx.path,
      );
      expect(
        await exporter.run(
          repository: repo,
          currentSession: () => session,
          filter: allPiutang,
        ),
        13,
      );
      final sheet = Excel.decodeBytes(await xlsx.readAsBytes())['Piutang Data'];
      expect(
        sheet.cell(CellIndex.indexByString('I7')).value,
        IntCellValue(1055000),
      );
      expect(sheet.maxRows, 22);
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      expect(
        (await db.customSelect('PRAGMA integrity_check').getSingle())
            .read<String>('integrity_check'),
        'ok',
      );
    } finally {
      await db.close();
      await folder.delete(recursive: true);
    }
    expect(sha256.convert(await file.readAsBytes()), before);
  }, skip: id == null);
}
