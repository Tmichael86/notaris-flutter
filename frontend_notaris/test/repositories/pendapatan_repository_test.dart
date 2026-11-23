import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:excel_plus/excel_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/models/auth_session.dart';
import 'package:frontend_notaris/repositories/pendapatan_repository.dart';
import 'package:frontend_notaris/repositories/pengeluaran_repository.dart';
import 'package:frontend_notaris/services/pendapatan_excel_export.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../support/pendapatan_fixture.dart';

void main() {
  late AppDatabase db;
  late AuthSession? actor;
  late PendapatanRepository reportRepo;
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('pendapatan-test-');
    db = AppDatabase.forTesting(NativeDatabase.memory());
    actor = pendapatanActor();
    reportRepo = PendapatanRepository(db, () => actor);
    await seedPendapatan(db);
  });
  tearDown(() async {
    await db.close();
    await temp.delete(recursive: true);
  });

  test('one receipt per UUID, grouped by WIB, with full-period totals and stable paging', () async {
    final report = await reportRepo.read(pendapatanNovember);
    expect(report.days.map((row) => row.date.day), [
      for (var i = 13; i >= 1; i--) i,
    ]);
    expect(report.page(0).length, 10);
    expect(report.page(1).map((row) => row.date.day), [3, 2, 1]);
    expect(
      report.page(1).map((row) => row.amount.receipts),
      [8000, 20000, 20000].map(BigInt.from),
    );
    expect(report.days.first.amount.receipts, BigInt.from(30000));
    expect(report.days.first.amount.expenses, BigInt.from(15000));
    expect(report.days[1].amount.difference, BigInt.from(-12000));
    expect(report.total.receipts, BigInt.from(78000));
    expect(report.total.expenses, BigInt.from(93000));
    expect(report.total.difference, BigInt.from(-15000));
    expect(report.reviews.single.date, DateTime.utc(2026, 11, 4));
    expect(report.unknownDates, 0);
    expect(report.reviews.single.reason, contains('Rupiah bulat'));

    final sliced = await reportRepo.read((
      from: DateTime.utc(2026, 11, 11),
      through: DateTime.utc(2026, 11, 13),
    ));
    expect(sliced.days.length, 3);
    expect(sliced.total.receipts, BigInt.from(30000));
    expect(sliced.total.expenses, BigInt.from(38000));
    expect(sliced.reviews, isEmpty);
    expect(
      pendapatanMonth(DateTime.utc(2026, 10, 31, 16, 59)).from,
      DateTime.utc(2026, 10),
    );
    expect(
      pendapatanMonth(DateTime.utc(2026, 10, 31, 17)).from,
      pendapatanNovember.from,
    );
    expect(
      pendapatanMonth(DateTime.utc(2026, 10, 31, 17)).through,
      pendapatanNovember.through,
    );
  });

  test('changes to expenses refresh the report, retain receipt-only dates and omit tombstones', () async {
    final stream = StreamIterator(reportRepo.watch(pendapatanNovember));
    addTearDown(stream.cancel);
    expect(await stream.moveNext(), isTrue);
    final expenses = PengeluaranRepository(db, () => actor);
    await expenses.update(1, pendapatanExpense(13, 6000));
    expect(await stream.moveNext(), isTrue);
    expect(stream.current.days.last.amount.expenses, BigInt.zero);
    expect(stream.current.days.last.amount.receipts, BigInt.from(20000));
    expect(stream.current.days.first.amount.expenses, BigInt.from(21000));
    await expenses.delete(1);
    expect(await stream.moveNext(), isTrue);
    expect(stream.current.total.expenses, BigInt.from(92000));
    await db.customStatement(
      "UPDATE transaksis SET status_transaksi='Batal' WHERE id=1",
    );
    await db.customStatement("UPDATE transaksis SET deleted_at=1 WHERE id=2");
    final changed = await reportRepo.read(pendapatanNovember);
    expect(changed.total.receipts, BigInt.zero);
    expect(changed.total.expenses, BigInt.from(92000));
  });

  test(
    'malformed status, date, identity and amounts stay visible as reviews',
    () async {
      await db.customStatement(
        "UPDATE transaksi_riwayat_pembayaran SET tanggal_pembayaran='unknown',status=7 WHERE transaksi_id=3",
      );
      await db.customStatement(
        "UPDATE transaksis SET status_transaksi='unknown' WHERE id=2",
      );
      await db.customStatement(
        "UPDATE pengeluaran SET tanggal='unknown' WHERE id=4",
      );
      await db.customStatement("UPDATE pengeluaran SET uuid='' WHERE id=5");
      await db.customStatement('PRAGMA ignore_check_constraints=ON');
      await db.customStatement('UPDATE pengeluaran SET nominal=6.5 WHERE id=6');
      await db.customStatement('PRAGMA ignore_check_constraints=OFF');
      final report = await reportRepo.read(pendapatanNovember);
      expect(report.total.receipts, BigInt.from(48000));
      expect(report.total.expenses, BigInt.from(78000));
      expect(
        report.unknownDates,
        3,
      ); // malformed payment + unsupported header-only summary + expense date
      expect(
        report.reviews.map((row) => row.reason),
        containsAll([
          'Status transaksi induk tidak terverifikasi.',
          'Status pembayaran tidak terverifikasi.',
          'Tanggal kalender pengeluaran tidak valid.',
          'Identitas pengeluaran kosong atau ganda.',
          'Nominal pengeluaran harus berupa Rupiah bulat positif.',
        ]),
      );
    },
  );

  test('duplicate normalized UUIDs cannot enter trusted totals', () async {
    await db.customStatement(
      "UPDATE pengeluaran SET uuid='cash-test' WHERE id=1",
    );
    await db.customStatement(
      "UPDATE pengeluaran SET uuid=' CASH-TEST ' WHERE id=2",
    );
    await db.customStatement(
      "UPDATE transaksi_riwayat_pembayaran SET uuid=' duplicate ' WHERE id=1",
    );
    await db.customStatement(
      "UPDATE transaksi_riwayat_pembayaran SET uuid='DUPLICATE' WHERE id=2",
    );
    final report = await reportRepo.read(pendapatanNovember);
    expect(report.total.receipts, BigInt.zero);
    expect(report.total.expenses, BigInt.from(90000));
    expect(
      report.reviews.where((row) => row.reason.contains('ganda')).length,
      4,
    );
  });

  test('all three grants, identity and expiry are required at repository and exporter', () async {
    for (final code in [pendapatanPermission, 'penghasilan', 'pengeluaran']) {
      actor = pendapatanActor(without: code);
      await expectLater(reportRepo.read(pendapatanNovember), throwsStateError);
    }
    actor = pendapatanActor(
      expiry: DateTime.now().subtract(const Duration(seconds: 1)),
    );
    expect(() => reportRepo.watch(pendapatanNovember), throwsStateError);
    actor = null;
    final exporter = PendapatanExcelExport(
      chooseDestination: (_) async {
        fail('The picker must not open without permission');
      },
    );
    await expectLater(
      exporter.run(
        repository: reportRepo,
        currentSession: () => actor,
        period: pendapatanNovember,
      ),
      throwsStateError,
    );
  });

  test('backend token issuer, session identity and expiry must match', () {
    final model = pendapatanActor();
    final now = DateTime.now();
    AuthSession session({
      required int user,
      required DateTime expires,
      bool offline = false,
    }) {
      final claims = base64Url.encode(
        utf8.encode(
          jsonEncode({
            'iss': 'backend-notaris-go',
            'uid': user,
            'gid': model.groupId,
            'exp': expires.millisecondsSinceEpoch ~/ 1000,
          }),
        ),
      );
      return AuthSession(
        token: 'header.$claims.signature',
        userId: model.userId,
        groupId: model.groupId,
        userName: model.userName,
        groupName: model.groupName,
        user: model.user,
        sidebars: model.sidebars,
        isOffline: offline,
        verifiedAt: now.subtract(Duration(days: offline ? 8 : 0)),
      );
    }

    final future = now.add(const Duration(hours: 1));
    expect(
      canReadPendapatan(session(user: model.userId, expires: future)),
      isTrue,
    );
    expect(
      canReadPendapatan(session(user: model.userId + 1, expires: future)),
      isFalse,
    );
    expect(
      canReadPendapatan(
        session(
          user: model.userId,
          expires: now.subtract(const Duration(seconds: 1)),
        ),
      ),
      isFalse,
    );
    expect(
      canReadPendapatan(
        session(user: model.userId, expires: future, offline: true),
      ),
      isFalse,
    );
  });

  test('export aborts at staged-file publication and refuses a different repository session', () async {
    final target = p.join(temp.path, 'publication.xlsx');
    final exporter = PendapatanExcelExport(
      chooseDestination: (_) async => target,
    );
    bool staged = false;
    await expectLater(
      exporter.run(
        repository: reportRepo,
        period: pendapatanNovember,
        currentSession: () {
          if (temp.listSync().whereType<Directory>().any(
            (folder) => File(p.join(folder.path, 'export.xlsx')).existsSync(),
          )) {
            staged = true;
            return null;
          }
          return actor;
        },
      ),
      throwsStateError,
    );
    expect(staged, isTrue);
    expect(temp.listSync(), isEmpty);
    final otherSession = pendapatanActor();
    await expectLater(
      exporter.run(
        repository: PendapatanRepository(db, () => otherSession),
        currentSession: () => actor,
        period: pendapatanNovember,
      ),
      throwsStateError,
    );
    expect(File(target).existsSync(), isFalse);
  });

  test('XLSX reopens with exact headers, dates and numeric totals under query_only', () async {
    const filename = pendapatanExportFilename;
    final destination = p.join(temp.path, filename);
    await db.customStatement('PRAGMA query_only=ON');
    final report = await reportRepo.read(pendapatanNovember);
    expect(report.page(1).length, 3);
    final result =
        await PendapatanExcelExport(
          chooseDestination: (suggested) async {
            expect(suggested, filename);
            return destination;
          },
        ).run(
          repository: reportRepo,
          currentSession: () => actor,
          period: pendapatanNovember,
        );
    expect(result, (rows: 13, excluded: 1));
    final workbook = Excel.decodeBytes(await File(destination).readAsBytes());
    expect(workbook.tables.keys, [pendapatanSheetTitle]);
    final sheet = workbook[pendapatanSheetTitle];
    expect(sheet.maxColumns, 5);
    expect(sheet.maxRows, 14);
    expect(
      sheet.rows.first.map(
        (cell) => (cell!.value as TextCellValue).value.toString(),
      ),
      pendapatanHeaders,
    );
    final totals = [BigInt.zero, BigInt.zero, BigInt.zero];
    for (var i = 0; i < report.days.length; i++) {
      final row = sheet.rows[i + 1];
      expect((row[0]!.value as IntCellValue).value, i + 1);
      expect(row[1]!.value, DateCellValue.fromDateTime(report.days[i].date));
      for (var col = 0; col < 3; col++) {
        totals[col] += BigInt.from((row[col + 2]!.value as IntCellValue).value);
      }
    }
    expect(totals, [78000, 93000, -15000].map(BigInt.from));
    expect((sheet.rows[2][4]!.value as IntCellValue).value, -12000);
    expect(
      sheet.rows
          .expand((row) => row)
          .any((cell) => cell?.value is FormulaCellValue),
      isFalse,
    );
    expect(
      (await db.customSelect('PRAGMA query_only').getSingle())
          .data
          .values
          .single,
      1,
    );
  });

  test('empty export, cancel, revocation, existing file and Excel numeric precision', () async {
    final destination = p.join(temp.path, pendapatanExportFilename);
    final exporter = PendapatanExcelExport(
      chooseDestination: (_) async => destination,
    );
    final empty = (from: DateTime.utc(2026), through: DateTime.utc(2026));
    final result = await exporter.run(
      repository: reportRepo,
      currentSession: () => actor,
      period: empty,
    );
    expect(result?.rows, 0);
    final original = await File(destination).readAsBytes();
    expect(Excel.decodeBytes(original)[pendapatanSheetTitle].maxRows, 1);
    await expectLater(
      exporter.run(
        repository: reportRepo,
        currentSession: () => actor,
        period: pendapatanNovember,
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(await File(destination).readAsBytes(), original);
    final cancel = PendapatanExcelExport(chooseDestination: (_) async => null);
    expect(
      await cancel.run(
        repository: reportRepo,
        currentSession: () => actor,
        period: pendapatanNovember,
      ),
      isNull,
    );
    final other = p.join(temp.path, 'blocked.xlsx');
    final duringPicker = PendapatanExcelExport(
      chooseDestination: (_) async {
        actor = pendapatanActor(without: 'penghasilan');
        return other;
      },
    );
    await expectLater(
      duringPicker.run(
        repository: reportRepo,
        currentSession: () => actor,
        period: pendapatanNovember,
      ),
      throwsStateError,
    );
    expect(File(other).existsSync(), isFalse);
    actor = pendapatanActor();
    await db.customStatement(
      'UPDATE pengeluaran SET nominal=9000000000000000000 WHERE id IN (2,3)',
    );
    final totals = await reportRepo.read(pendapatanNovember);
    expect(totals.total.expenses, BigInt.parse('18000000000000088000'));
    final overflow = PendapatanExcelExport(
      chooseDestination: (_) async => other,
    );
    await expectLater(
      overflow.run(
        repository: reportRepo,
        currentSession: () => actor,
        period: pendapatanNovember,
      ),
      throwsStateError,
    );
    expect(File(other).existsSync(), isFalse);
  });

  test('one SQLite statement retains a snapshot through concurrent committed writes', () async {
    final file = File(p.join(temp.path, 'concurrent.sqlite'));
    final writer = sqlite3.open(file.path)..execute('PRAGMA journal_mode=WAL');
    addTearDown(writer.close);
    final seed = AppDatabase.forTesting(NativeDatabase(file));
    await seedPendapatan(seed);
    await seed.close();
    var injected = false;
    final reader = AppDatabase.forTesting(
      NativeDatabase(
        file,
        setup: (raw) {
          raw.execute('PRAGMA query_only=ON');
          raw.createFunction(
            functionName: 'lower',
            argumentCount: const AllowedArgumentCount(1),
            function: (args) {
              final input = args.single;
              if (!injected) {
                injected = true;
                writer.execute('BEGIN IMMEDIATE');
                writer.execute(
                  'UPDATE transaksi_riwayat_pembayaran SET nominal=21000,nominal_rupiah=21000 WHERE id=1',
                );
                writer.execute(
                  'UPDATE transaksis SET pembayaran_sekarang=49000 WHERE id=1',
                );
                writer.execute(
                  'UPDATE pengeluaran SET nominal=2000 WHERE id=1',
                );
                writer.execute('COMMIT');
              }
              return input is String ? input.toLowerCase() : input;
            },
          );
        },
      ),
    );
    addTearDown(reader.close);
    final scoped = PendapatanRepository(reader, () => actor);
    final before = await scoped.read(pendapatanNovember);
    expect(injected, isTrue);
    expect(before.total.receipts, BigInt.from(78000));
    expect(before.total.expenses, BigInt.from(93000));
    final after = await scoped.read(pendapatanNovember);
    expect(after.total.receipts, BigInt.from(79000));
    expect(after.total.expenses, BigInt.from(94000));
  });
}
