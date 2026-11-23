import '../support/transaction_test_authority.dart';

import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:excel_plus/excel_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/models/auth_session.dart';
import 'package:frontend_notaris/repositories/piutang_repository.dart';
import 'package:frontend_notaris/services/piutang_excel_export.dart';
import 'package:path/path.dart' as p;

import '../support/piutang_fixture.dart';
import '../support/transaction_ui_test_support.dart' show uiSession;

void main() {
  late AppDatabase db;
  late AuthSession session;
  late PiutangRepository repo;
  setUp(() async {
    db = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (sqlite) => sqlite.execute('PRAGMA foreign_keys=ON'),
      ),
    );
    session = piutangReader();
    repo = PiutangRepository(db, () => session);
    await seedPiutang(db);
  });
  tearDown(() => db.close());

  test('authoritative totals read once per transaction, independent of jobs and payment counts', () async {
    // A change to current Master does not change a previously saved price.
    await db.customStatement('UPDATE pekerjaan_notaris SET nama=?', [
      'Nama baru',
    ]);
    await db.customStatement('PRAGMA query_only=ON');
    final before = await db.customSelect('SELECT total_changes()').getSingle();
    final report = await repo.read(allPiutang);
    expect(report.rows.map((row) => row.id), [for (var i = 13; i > 0; i--) i]);
    expect(report.total, BigInt.from(1055000));
    final multiple = report.rows.last;
    expect(
      (multiple.billed, multiple.paid, multiple.remaining),
      (180000, 50000, 130000),
    );
    expect(multiple.jobs, '=Akta Fidusia\n+Salinan Akta');
    expect(multiple.categories, 'Kenotariatan\n—');
    expect(report.rows.singleWhere((row) => row.id == 3).remaining, 100000);
    expect(report.reviews.single.reason, contains('ledger aktif'));
    expect(report.reviews.single.id, 15);
    expect(
      (await db.customSelect('SELECT total_changes()').getSingle()).data,
      before.data,
    );
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });

  test('watch reacts to existing payment correction and cancellation without new ledger', () async {
    final stream = StreamIterator(repo.watch(piutangFilter(search: 'Salinan')));
    addTearDown(stream.cancel);
    expect(await stream.moveNext(), isTrue);
    expect(stream.current.total, BigInt.from(130000));
    final actor = uiSession(groupType: 'superadmin');
    final transactions = testTransactionRepository(db, session: () => actor);
    final original = (await transactions.getPaymentHistory(1)).last;
    await transactions.editPayment(
      session: actor,
      transactionId: 1,
      expected: original,
      paymentDate: original.tanggalPembayaran,
      amount: 25000,
      method: 'Cash',
      reason: 'Koreksi fixture',
    );
    expect(await stream.moveNext(), isTrue);
    expect(stream.current.total, BigInt.from(125000));
    final edited = (await transactions.getPaymentHistory(1)).last;
    await transactions.cancelPayment(
      session: actor,
      transactionId: 1,
      expected: edited,
      reason: 'Batal fixture',
    );
    expect(await stream.moveNext(), isTrue);
    expect(stream.current.total, BigInt.from(150000));
  });

  test('mismatched relationships, duplicate numbers, fractions and overspend remain review cases', () async {
    await db.customStatement('DROP INDEX idx_transaksis_no_akta_unique');
    await db.customStatement(
      "UPDATE transaksis SET no_akta=' DUP ' WHERE id=4",
    );
    await db.customStatement("UPDATE transaksis SET no_akta='DUP' WHERE id=5");
    await db.customStatement(
      "UPDATE transaksis SET pemohon_uuid='bad' WHERE id=7",
    );
    await db.customStatement(
      'UPDATE transaksis SET petugas_id=NULL,petugas_uuid=NULL WHERE id=8',
    );
    await db.customStatement('UPDATE transaksis SET total=3.5 WHERE id=9');
    await db.customStatement('UPDATE transaksis SET total=4000 WHERE id=10');
    await db.customStatement(
      'UPDATE transaksi_riwayat_pembayaran SET nominal=150000,nominal_rupiah=150000 WHERE transaksi_id=11',
    );
    await db.customStatement(
      'UPDATE transaksi_riwayat_pembayaran SET nominal=22.5,nominal_rupiah=NULL WHERE transaksi_id=12',
    );
    final report = await repo.read(allPiutang);
    final issues = {for (final row in report.reviews) row.id: row.reason};
    expect(issues.keys, unorderedEquals([4, 5, 7, 8, 9, 10, 11, 12, 15]));
    expect(issues[4], contains('ambigu'));
    expect(issues[7], contains('Relasi'));
    expect(issues[9], contains('Rupiah bulat'));
    expect(issues[10], contains('Snapshot'));
    expect(issues[11], contains('melebihi'));
    expect(issues[12], contains('Rupiah bulat'));
    expect(report.total, BigInt.from(455000));
    expect(
      (await repo.read(piutangFilter(domain: 'ppat', search: 'DUP')))
          .reviews
          .single
          .id,
      4,
    );
  });

  test('shared filters include end of day, exclude null only with dates and search verified references', () async {
    final ppat = await repo.read(piutangFilter(domain: 'ppat'));
    expect(ppat.total, BigInt.from(450000));
    final day = DateTime(2026, 11, 10);
    final matching = await repo.read(
      piutangFilter(
        domain: 'notaris',
        from: day,
        through: day,
        search: 'pradépta',
      ),
    );
    expect(matching.rows.map((row) => row.id), [5, 3, 1]);
    expect(matching.total, BigInt.from(305000));
    expect(
      (await repo.read(piutangFilter(search: 'PIU-13'))).rows.single.id,
      13,
    );
    expect(
      (await repo.read(piutangFilter(search: 'PIU-13', from: day))).rows,
      isEmpty,
    );
    for (final search in [piutangNik, 'Dimas', 'Salinan', 'Kenotariatan']) {
      expect(
        (await repo.read(piutangFilter(search: search))).rows
            .any((row) => row.id == 1),
        isTrue,
      );
    }
  });

  test('repository and exporter independently deny missing/inactive grants and handle cancellation', () async {
    var chooseCalls = 0;
    final exporter = PiutangExcelExport(
      chooseDestination: (_) async {
        chooseCalls++;
        return null;
      },
    );
    for (final denied in [
      piutangReader(allowed: false),
      piutangReader(status: 0),
      uiSession(groupType: 'superadmin'),
    ]) {
      session = denied;
      await expectLater(repo.read(allPiutang), throwsStateError);
      await expectLater(
        exporter.run(
          repository: repo,
          currentSession: () => session,
          filter: allPiutang,
        ),
        throwsStateError,
      );
    }
    expect(chooseCalls, 0);
    session = piutangReader();
    expect(
      await exporter.run(
        repository: repo,
        currentSession: () => session,
        filter: allPiutang,
      ),
      isNull,
    );
    expect(chooseCalls, 1);
    final switched = PiutangExcelExport(
      chooseDestination: (_) async {
        session = piutangReader();
        return 'unused.xlsx';
      },
    );
    await expectLater(
      switched.run(
        repository: repo,
        currentSession: () => session,
        filter: allPiutang,
      ),
      throwsStateError,
    );
  });

  test('Excel reopens ten legacy columns, all matches, exact currency and safe text', () async {
    final dir = await Directory.systemTemp.createTemp('piutang-xlsx-test-');
    addTearDown(() => dir.delete(recursive: true));
    await db.customStatement('PRAGMA query_only=ON');
    Future<Sheet> export(PiutangFilter filter, String name, int count) async {
      final target = p.join(dir.path, '$name.xlsx');
      final exporter = PiutangExcelExport(
        chooseDestination: (_) async => target,
      );
      expect(
        await exporter.run(
          repository: repo,
          currentSession: () => session,
          filter: filter,
        ),
        count,
      );
      final book = Excel.decodeBytes(await File(target).readAsBytes());
      expect(book.tables.keys, ['Piutang Data']);
      final sheet = book['Piutang Data'];
      expect(
        sheet.rows
            .expand((cells) => cells)
            .any((cell) => cell?.value is FormulaCellValue),
        isFalse,
      );
      return sheet;
    }

    CellValue? value(Sheet sheet, String address) =>
        sheet.cell(CellIndex.indexByString(address)).value;
    final all = await export(allPiutang, 'all', 13);
    expect(all.rows[8].map((cell) => cell?.value.toString()), [
      'No',
      'No Akta',
      'NIK Pemohon',
      'Nama Pemohon',
      'Jenis Pekerjaan',
      'Nama Pekerjaan',
      'Kategori',
      'Total',
      'Total Piutang',
      'Nama Petugas',
    ]);
    expect(value(all, 'I7'), IntCellValue(1055000));
    expect(value(all, 'E7'), IntCellValue(1));
    expect(value(all, 'B22').toString(), piutangNumber);
    expect(value(all, 'C22').toString(), piutangNik);
    expect(value(all, 'B22'), isA<TextCellValue>());
    expect(value(all, 'F22').toString(), '=Akta Fidusia\n+Salinan Akta');
    expect(value(all, 'D22').toString(), 'Laras Pradépta');
    expect(value(all, 'C21').toString(), '—');
    expect(value(all, 'H22'), IntCellValue(180000));
    expect(value(all, 'I22'), IntCellValue(130000));
    final searched = await export(
      piutangFilter(search: 'Salinan'),
      'filtered',
      1,
    );
    expect(value(searched, 'I7'), IntCellValue(130000));
    final empty = await export(piutangFilter(search: 'absent'), 'empty', 0);
    expect(value(empty, 'A10').toString(), contains('Tidak ada piutang'));
    for (final target in [
      p.join(dir.path, 'all.xlsx'),
      p.join(dir.path, 'absent', 'file.xlsx'),
    ]) {
      final exporter = PiutangExcelExport(
        chooseDestination: (_) async => target,
      );
      await expectLater(
        exporter.run(
          repository: repo,
          currentSession: () => session,
          filter: allPiutang,
        ),
        throwsA(isA<FileSystemException>()),
      );
    }
    expect(await dir.list().length, 3);
  }, skip: !Platform.isWindows);

  test('Excel rejects unrepresentable precision before publishing', () async {
    await db.customStatement(
      'UPDATE transaksis SET total=1000000000000001 WHERE id=2',
    );
    await db.customStatement(
      'UPDATE transaksi_details SET biaya_layanan=1000000000000001,total_snapshot=1000000000000001 WHERE transaksi_id=2',
    );
    final dir = await Directory.systemTemp.createTemp(
      'piutang-precision-test-',
    );
    addTearDown(() => dir.delete(recursive: true));
    final exporter = PiutangExcelExport(
      chooseDestination: (_) async => p.join(dir.path, 'fail.xlsx'),
    );
    await expectLater(
      exporter.run(
        repository: repo,
        currentSession: () => session,
        filter: allPiutang,
      ),
      throwsStateError,
    );
    expect(await dir.list().isEmpty, isTrue);
  });
}
