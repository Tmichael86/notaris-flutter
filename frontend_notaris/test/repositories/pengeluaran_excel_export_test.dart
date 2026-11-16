import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:excel_plus/excel_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/models/auth_session.dart';
import 'package:frontend_notaris/pengeluaran_demo_main.dart';
import 'package:frontend_notaris/repositories/pengeluaran_repository.dart';
import 'package:frontend_notaris/services/pengeluaran_excel_export.dart';
import 'package:path/path.dart' as p;

import 'pengeluaran_repository_test.dart' show expenseSession;
import 'recycle_bin_repository_test.dart' show seedTransaction;

PengeluaranFilter filter({
  DateTime? from,
  DateTime? through,
  int? kind,
  String search = '',
  int page = 1,
}) => (from: from, through: through, jenisId: kind, search: search, page: page);

CellValue? value(Sheet sheet, String cell) =>
    sheet.cell(CellIndex.indexByString(cell)).value;

Future<Sheet> reopen(File file) async {
  final workbook = Excel.decodeBytes(await file.readAsBytes());
  expect(workbook.tables.keys, ['Pengeluaran Data']);
  final sheet = workbook['Pengeluaran Data'];
  expect(
    sheet.rows
        .expand((row) => row)
        .map((cell) => cell?.value)
        .whereType<FormulaCellValue>(),
    isEmpty,
  );
  return sheet;
}

void main() {
  group('Pengeluaran XLSX', () {
    late Directory folder;
    late AppDatabase db;
    late PengeluaranRepository repo;
    late AuthSession? session;

    setUp(() async {
      folder = await Directory.systemTemp.createTemp('pengeluaran-xlsx-');
      db = AppDatabase.forTesting(NativeDatabase.memory());
      session = expenseSession(write: false);
      repo = PengeluaranRepository(db, () => session);
      final writer = PengeluaranRepository(db, expenseSession);
      await seedTransaction(db, 'notaris');
      await db.customStatement(
        "INSERT INTO transaction_cloud_feed(scope,cursor) VALUES('expense',9)",
      );
      await db.customStatement("""
        INSERT INTO transaction_cloud_pending(local_uuid,mutation_id,payload,state)
        SELECT uuid,'expense-ack','{}','acked' FROM transaksis
        """);
      for (final name in ['ATK', 'Transport']) {
        await db
            .into(db.pengeluaranJenis)
            .insert(PengeluaranJenisCompanion.insert(uuid: name, nama: name));
      }
      for (var i = 1; i <= 14; i++) {
        final day = i == 13 ? 12 : i;
        final pk = await writer.create((
          noFaktur: switch (i) {
            13 => '000013',
            12 => '=1+1',
            _ => 'INV-$i',
          },
          tanggal: DateTime(2026, 11, day),
          nominal: i * 100,
          jenisId: i.isEven ? 1 : 2,
          keterangan: i == 12 ? '@Papér – dibeli' : 'Berkas kantor $i',
        ));
        if (i == 14) await writer.delete(pk);
      }
      await db.customStatement(
        "UPDATE pengeluaran_jenis SET nama='ATK baru' WHERE id=1",
      );
      await db.customStatement('PRAGMA query_only = ON');
    });

    tearDown(() async {
      await db.close();
      await folder.delete(recursive: true);
    });

    Future<Sheet> export(
      String name,
      PengeluaranFilter query,
      int count, {
      String? kind,
    }) async {
      final path = p.join(folder.path, name);
      final exporter = PengeluaranExcelExport(
        chooseDestination: (suggestion) async {
          expect(suggestion, matches(r'^Pengeluaran_Data_\d{8}_\d{4}\.xlsx$'));
          return path;
        },
      );
      expect(
        await exporter.run(
          repository: repo,
          currentSession: () => session,
          filter: query,
          jenisLabel: kind,
        ),
        count,
      );
      final sheet = await reopen(File('$path.xlsx'));
      expect(value(sheet, 'C6'), IntCellValue(count));
      return sheet;
    }

    Future<Map<String, List<Map<String, Object?>>>> snapshot() async => {
      for (final query in [
        'SELECT total_changes() AS n',
        'SELECT * FROM pengeluaran ORDER BY id',
        'SELECT * FROM transaksis ORDER BY id',
        'SELECT * FROM transaksi_riwayat_pembayaran ORDER BY id',
        'SELECT * FROM transaction_cloud_feed ORDER BY scope',
        'SELECT * FROM transaction_cloud_pending ORDER BY local_uuid',
      ])
        query: [for (final row in await db.customSelect(query).get()) row.data],
    };

    test(
      'page 2 exports all active rows in table order with exact typed values',
      () async {
        final before = await snapshot();
        final page = await repo.watchPage(filter()).first;
        expect((page.page, page.rows.length), (1, 3));
        final sheet = await export('semua', filter(), 13);
        expect(sheet.rows[7].map((cell) => cell?.value.toString()), [
          'No',
          'No Faktur',
          'Keterangan',
          'Jenis Pengeluaran',
          'Jumlah',
          'Tanggal Pengeluaran',
        ]);
        expect(value(sheet, 'B9').toString(), '000013');
        expect(value(sheet, 'B9'), isA<TextCellValue>());
        expect(value(sheet, 'B10').toString(), '=1+1');
        expect(value(sheet, 'B10'), isA<TextCellValue>());
        expect(value(sheet, 'C10').toString(), '@Papér – dibeli');
        expect(value(sheet, 'D10').toString(), 'ATK');
        expect(value(sheet, 'E10'), IntCellValue(1200));
        expect(
          sheet
              .cell(CellIndex.indexByString('E10'))
              .cellStyle
              ?.numberFormat
              .formatCode,
          '"Rp" #,##0',
        );
        expect(value(sheet, 'E6'), IntCellValue(page.total.toInt()));
        expect(
          value(sheet, 'F9'),
          DateCellValue(year: 2026, month: 11, day: 12),
        );
        expect(value(sheet, 'C2'), isA<DateTimeCellValue>());
        expect(
          sheet
              .cell(CellIndex.indexByString('F9'))
              .cellStyle
              ?.numberFormat
              .formatCode,
          'dd/mm/yyyy',
        );
        expect(value(sheet, 'B21').toString(), 'INV-1');
        expect(sheet.maxRows, 21);
        expect(await snapshot(), before);
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        expect(
          (await db.customSelect('PRAGMA integrity_check').getSingle())
              .read<String>('integrity_check'),
          'ok',
        );
      },
      skip: !Platform.isWindows,
    );

    test(
      'date boundaries, type and search use the same predicate as the table',
      () async {
        final dates = await export(
          'tanggal',
          filter(from: DateTime(2026, 11, 11), through: DateTime(2026, 11, 12)),
          3,
        );
        expect(
          value(dates, 'F11'),
          DateCellValue(year: 2026, month: 11, day: 11),
        );
        expect(value(dates, 'E6'), IntCellValue(3600));
        final type = await export(
          'jenis',
          filter(kind: 1),
          6,
          kind: 'ATK baru',
        );
        expect(value(type, 'C4').toString(), 'ATK baru');
        expect(value(type, 'D9').toString(), 'ATK');
        await export('faktur', filter(search: '  inv-2  '), 1);
        await export('uraian', filter(search: 'papér'), 1);
        final combined = await export(
          'gabungan',
          filter(
            from: DateTime(2026, 11, 12),
            through: DateTime(2026, 11, 12),
            kind: 1,
            search: '=1+1',
          ),
          1,
        );
        expect(value(combined, 'E6'), IntCellValue(1200));
        expect(value(combined, 'C5'), isA<TextCellValue>());
        final empty = await export('kosong', filter(search: '_'), 0);
        expect(value(empty, 'E6'), IntCellValue(0));
        expect(
          value(empty, 'A9').toString(),
          'Tidak ada pengeluaran yang cocok dengan filter.',
        );
      },
      skip: !Platform.isWindows,
    );

    test(
      'denial, cancellation and account switching do not publish a file',
      () async {
        final authorized = session;
        var opened = false;
        final exporter = PengeluaranExcelExport(
          chooseDestination: (_) async {
            opened = true;
            return null;
          },
        );
        session = expenseSession(read: false);
        final denied = throwsA(isA<PengeluaranFailure>());
        await expectLater(repo.readExport(filter()), denied);
        await expectLater(
          exporter.run(
            repository: repo,
            currentSession: () => session,
            filter: filter(),
          ),
          denied,
        );
        expect(opened, isFalse);
        session = authorized;
        expect(
          await exporter.run(
            repository: repo,
            currentSession: () => session,
            filter: filter(),
          ),
          isNull,
        );
        expect(opened, isTrue);
        final switched = PengeluaranExcelExport(
          chooseDestination: (_) async {
            session = expenseSession(write: false);
            return p.join(folder.path, 'blocked.xlsx');
          },
        );
        await expectLater(
          switched.run(
            repository: repo,
            currentSession: () => session,
            filter: filter(),
          ),
          denied,
        );
        expect(await folder.list().toList(), isEmpty);
      },
    );

    test('save errors preserve existing files and refuse the managed document directory', () async {
      final existing = File(p.join(folder.path, 'existing.xlsx'));
      await existing.writeAsString('preserve');
      final managed = await Directory(
        p.join(folder.path, 'Transaction-Documents', 'profile'),
      ).create(recursive: true);
      for (final destination in [
        existing.path,
        p.join(folder.path, 'missing', 'file.xlsx'),
        p.join(managed.path, 'file.xlsx'),
      ]) {
        final exporter = PengeluaranExcelExport(
          chooseDestination: (_) async => destination,
        );
        await expectLater(
          exporter.run(
            repository: repo,
            currentSession: () => session,
            filter: filter(),
          ),
          throwsA(isA<FileSystemException>()),
        );
      }
      expect(await existing.readAsString(), 'preserve');
      expect(await managed.list().toList(), isEmpty);
      expect((await folder.list().toList()).length, 2);
    }, skip: !Platform.isWindows);

    test(
      'totals outside exact Excel precision fail before publishing',
      () async {
        await db.customStatement('PRAGMA query_only = OFF');
        await db.customStatement(
          'UPDATE pengeluaran SET nominal=999999999999999 WHERE id=1',
        );
        await db.customStatement('PRAGMA query_only = ON');
        final exporter = PengeluaranExcelExport(
          chooseDestination: (_) async => p.join(folder.path, 'oversized.xlsx'),
        );
        await expectLater(
          exporter.run(
            repository: repo,
            currentSession: () => session,
            filter: filter(),
          ),
          throwsA(
            isA<PengeluaranFailure>().having(
              (error) => error.message,
              'message',
              contains('15 digit'),
            ),
          ),
        );
        expect(await folder.list().toList(), isEmpty);
        final single = await export(
          'exact',
          filter(search: 'INV-1', through: DateTime(2026, 11, 1)),
          1,
        );
        expect(value(single, 'E9'), IntCellValue(999999999999999));
      },
      skip: !Platform.isWindows,
    );
  });

  final id = Platform.environment['NOTARIS_PENGELUARAN_EXPORT_REVIEW'];
  test('disposable Windows profile exports under query_only and preserves SQLite SHA-256', () async {
    final root = pengeluaranDemoRoot(id!);
    final file = File(p.join(root.path, 'offline.sqlite'));
    final before = sha256.convert(await file.readAsBytes());
    final folder = await Directory.systemTemp.createTemp(
      'pengeluaran-export-proof-',
    );
    final db = AppDatabase.forTesting(
      NativeDatabase(
        file,
        enableMigrations: false,
        setup: (sqlite) {
          sqlite.execute('PRAGMA foreign_keys = ON');
          sqlite.execute('PRAGMA query_only = ON');
        },
      ),
    );
    try {
      final session = expenseSession(write: false);
      final path = p.join(folder.path, 'Pengeluaran_Data.xlsx');
      final exporter = PengeluaranExcelExport(
        chooseDestination: (_) async => path,
      );
      final repo = PengeluaranRepository(db, () => session);
      expect(
        await exporter.run(
          repository: repo,
          currentSession: () => session,
          filter: filter(),
        ),
        12,
      );
      final sheet = await reopen(File(path));
      expect(value(sheet, 'E6'), IntCellValue(120000));
      expect(value(sheet, 'B9').toString(), 'DEMO-12');
      expect(value(sheet, 'B20').toString(), 'DEMO-01');
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
  }, skip: id == null || !Platform.isWindows);
}
