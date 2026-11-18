import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/pendapatan_demo_main.dart';
import 'package:frontend_notaris/repositories/pendapatan_repository.dart';
import 'package:frontend_notaris/services/pendapatan_excel_export.dart';
import 'package:path/path.dart' as p;

import '../support/materai_stock_fixture.dart';
import '../support/pendapatan_fixture.dart';

void main() {
  final prepare = Platform.environment['NOTARIS_PENDAPATAN_PREPARE'] ?? '';
  final verify = Platform.environment['NOTARIS_PENDAPATAN_VERIFY'] ?? '';
  final id = prepare.isEmpty ? verify : prepare;
  test(
    'one fresh profile reopens read-only with exact verified totals',
    () async {
      expect(prepare.isEmpty || verify.isEmpty, isTrue);
      final root = pendapatanDemoRoot(id);
      final file = File(p.join(root.path, 'offline.sqlite'));
      if (prepare.isNotEmpty) {
        await _prepare(file, id);
      }
      final before = sha256.convert(await file.readAsBytes());
      final reader = openPendapatanDemo(id);
      try {
        final actor = pendapatanActor();
        final report = await PendapatanRepository(
          reader,
          () => actor,
        ).read(pendapatanNovember);
        expect(report.days.length, 13);
        expect(report.total.receipts, BigInt.from(78000));
        expect(report.total.expenses, BigInt.from(93000));
        expect(report.total.difference, BigInt.from(-15000));
        expect(report.reviews.length, 1);
        expect(
          (await reader.customSelect('PRAGMA query_only').getSingle())
              .data
              .values
              .single,
          1,
        );
        expect(
          (await reader.customSelect('PRAGMA integrity_check').getSingle())
              .data
              .values
              .single,
          'ok',
        );
        expect(
          await reader.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        final workbook =
            Platform.environment['NOTARIS_PENDAPATAN_VALIDATE_XLSX'];
        if (workbook != null) {
          final result =
              await PendapatanExcelExport(
                chooseDestination: (_) async => workbook,
              ).run(
                repository: PendapatanRepository(reader, () => actor),
                currentSession: () => actor,
                period: pendapatanNovember,
              );
          expect(result, (rows: 13, excluded: 1));
        }
        await expectLater(
          reader.customStatement('UPDATE pengeluaran SET nominal=1'),
          throwsA(anything),
        );
      } finally {
        await reader.close();
      }
      expect(sha256.convert(await file.readAsBytes()), before);
    },
    skip: id.isEmpty,
  );
}

Future<void> _prepare(File file, String id) async {
  await file.create(exclusive: true);
  final writer = MateraiProfileDatabase(
    NativeDatabase(file, setup: (raw) => raw.execute('PRAGMA foreign_keys=ON')),
  );
  try {
    await seedPendapatan(writer);
    await seedMateraiOpening(writer, id: id);
    await writer.customStatement(
      "INSERT INTO transaction_cloud_feed(scope,cursor) VALUES('pendapatan-demo',3)",
    );
    await writer.customStatement(
      "INSERT INTO transaction_cloud_identity(local_uuid,cloud_uuid,scope,revision,final_number,snapshot) "
      "SELECT uuid,uuid,'pendapatan-demo',1,no_akta,'{}' FROM transaksis WHERE id=2",
    );
    await writer.customStatement(
      "INSERT INTO transaction_cloud_pending(local_uuid,mutation_id,payload,state) "
      "SELECT uuid,'pendapatan-demo-ack','{}','acked' FROM transaksis WHERE id=2",
    );
  } finally {
    await writer.close();
  }
}
