import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/models/auth_session.dart';
import 'package:frontend_notaris/repositories/penghasilan_repository.dart';
import 'package:frontend_notaris/repositories/transaction_repository.dart';

import '../support/penghasilan_fixture.dart';
import '../support/transaction_ui_test_support.dart' show uiSession;

void main() {
  late AppDatabase db;
  late AuthSession session;
  late PenghasilanRepository repo;
  setUp(() async {
    db = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (sqlite) => sqlite.execute('PRAGMA foreign_keys=ON'),
      ),
    );
    await seedPenghasilan(db);
    session = penghasilanReader();
    repo = PenghasilanRepository(db, () => session);
  });
  tearDown(() => db.close());

  test('ledger is read-only, each installment is counted once and ties preserve both IDs', () async {
    await db.customStatement('PRAGMA query_only=ON');
    final before = await db.customSelect('SELECT total_changes()').getSingle();
    final data = await repo.read();
    expect(data.rows, hasLength(13));
    expect(data.total, BigInt.from(480000));
    expect(data.rows.map((row) => row.id).toSet(), hasLength(13));
    expect(data.rows.any((row) => row.context.parentId >= 13), isFalse);
    final multi = data.rows.where((row) => row.context.parentId == 1).toList();
    expect(multi.map((row) => row.amount), [120000, 50000]);
    expect(multi.first.context.jobs.map((job) => job.name), [
      'Akta Fidusia',
      'Salinan Berkas',
    ]);
    final sameTime = data.rows
        .where((row) => row.date == DateTime(2026, 11, 10, 23, 59, 59))
        .toList();
    expect(sameTime.map((row) => row.amount), [50000, 60000]);
    expect(sameTime.first.id, greaterThan(sameTime.last.id));
    expect(data.reviews.single.reason, contains('Rupiah bulat'));
    expect(
      (await db.customSelect('SELECT total_changes()').getSingle()).data,
      before.data,
    );
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });

  test('two active installments plus initial payment stay separate for one dirty transaction', () async {
    final tx = TransactionRepository(db);
    const uuid = '00000000-0000-4000-8000-333333333333';
    await tx.addPayment(
      session: uiSession(groupType: 'superadmin'),
      transactionId: 1,
      paymentUuid: uuid,
      paymentDate: DateTime(2026, 11, 10, 23, 59, 59),
      amount: 10000,
    );
    final report = (await repo.read()).filtered(
      receiptFilter(search: 'PEN-01'),
    );
    expect(report.rows.map((row) => row.amount), [120000, 10000, 50000]);
    expect(report.rows[1].uuid, uuid);
    expect(report.rows.map((row) => row.id).toSet(), hasLength(3));
    expect(report.total, BigInt.from(180000));
    expect(
      (await db
              .customSelect('SELECT is_sync_dirty FROM transaksis WHERE id=1')
              .getSingle())
          .read<int>('is_sync_dirty'),
      1,
    );
  });

  test('correction moves receipt across local calendar days and refreshes exact value', () async {
    final stream = StreamIterator(repo.watch());
    addTearDown(stream.cancel);
    expect(await stream.moveNext(), isTrue);
    final tx = TransactionRepository(db);
    final old = (await tx.getPaymentHistory(1))
        .singleWhere((row) => row.nominalRupiah == 120000);
    final moved = DateTime(2026, 11, 12, 0, 1);
    await tx.editPayment(
      session: uiSession(groupType: 'superadmin'),
      transactionId: 1,
      expected: old,
      paymentDate: moved,
      amount: 125000,
      method: 'Cash',
      reason: 'Koreksi tanggal',
    );
    expect(await stream.moveNext(), isTrue);
    final report = stream.current;
    expect(report.total, BigInt.from(485000));
    expect(report.rows.first.uuid, old.uuid);
    expect(
      report
          .filtered(receiptFilter(from: moved, through: moved))
          .rows
          .single
          .amount,
      125000,
    );
    final previous = DateTime(2026, 11, 11);
    expect(
      report.filtered(receiptFilter(from: previous, through: previous)).rows,
      isEmpty,
    );
  });

  test('all criteria share payment totals; work and category match the same detail', () async {
    final report = await repo.read();
    final tenth = DateTime(2026, 11, 10);
    final tenthReport = report.filtered(
      receiptFilter(from: tenth, through: tenth),
    );
    expect(tenthReport.total, BigInt.from(110000));
    expect(tenthReport.rows, hasLength(2));
    final combined = report.filtered(
      receiptFilter(
        domain: 'notaris',
        from: tenth,
        through: tenth,
        job: 'Salinan Berkas',
        category: 'Administrasi',
        officer: 1,
        status: 'Dalam Proses',
        search: 'PRADÉPTA',
      ),
    );
    expect(combined.rows.single.amount, 50000);
    expect(
      report
          .filtered(
            receiptFilter(job: 'Salinan Berkas', category: 'Kenotariatan'),
          )
          .total,
      BigInt.zero,
    );
    expect(
      report.filtered(receiptFilter(domain: 'ppat')).total,
      BigInt.from(185000),
    );
    expect(
      report.filtered(receiptFilter(officer: 2)).total,
      BigInt.from(60000),
    );
    for (final search in ['0000000000000001', 'PEN-01', 'Dimas', 'Fidusia']) {
      expect(
        report
            .filtered(receiptFilter(search: search))
            .rows
            .any((row) => row.context.parentId == 1),
        isTrue,
      );
    }
  });

  test('bad date, missing references, header-only and duplicate UUID become reviews', () async {
    await db.customStatement(
      "UPDATE transaksi_riwayat_pembayaran SET tanggal_pembayaran='invalid' WHERE transaksi_id=2",
    );
    await db.customStatement(
      "UPDATE transaksis SET pemohon_uuid='mismatch' WHERE id=3",
    );
    await db.customStatement(
      'UPDATE transaksis SET petugas_id=NULL,petugas_uuid=NULL WHERE id=4',
    );
    await db.customStatement(
      'UPDATE transaksis SET pembayaran_sekarang=1500 WHERE id=13',
    );
    await db.customStatement(
      "UPDATE transaksi_riwayat_pembayaran SET uuid='duplicate' WHERE transaksi_id=5",
    );
    await db.customStatement(
      "UPDATE transaksi_riwayat_pembayaran SET uuid=' DUPLICATE ' WHERE transaksi_id=6",
    );
    final report = await repo.read();
    final review = {
      for (final row in report.reviews) row.context.parentId: row,
    };
    expect(review.keys, unorderedEquals([2, 3, 4, 5, 6, 13, 16]));
    expect(review[2]!.date, isNull);
    expect(review[2]!.reason, contains('Tanggal'));
    expect(review[3]!.reason, contains('Relasi'));
    expect(review[4]!.reason, contains('Relasi'));
    expect(review[13]!.reason, contains('tanpa ledger'));
    expect(review[5]!.reason, contains('ganda'));
    expect(report.total, BigInt.from(320000));
    expect(
      report
          .filtered(receiptFilter(from: DateTime(2026, 11, 11)))
          .reviews
          .map((row) => row.context.parentId),
      unorderedEquals([2, 13]),
    );
  });

  test(
    'inconsistent mirrors and totals hold the unverified ledger out of revenue',
    () async {
      await db.customStatement(
        'DROP TRIGGER transaksi_pembayaran_rupiah_update',
      );
      await db.customStatement(
        'UPDATE transaksi_riwayat_pembayaran SET nominal_rupiah=10000 WHERE transaksi_id=1 AND nominal=50000',
      );
      await db.customStatement('UPDATE transaksis SET total=59999 WHERE id=2');
      await db.customStatement(
        'UPDATE transaksis SET pembayaran_sekarang=24999 WHERE id=3',
      );
      final report = await repo.read();
      expect(
        report.rows.map((row) => row.context.parentId),
        everyElement(greaterThan(3)),
      );
      expect(
        report.reviews.map((row) => row.reason),
        containsAll([
          'Nominal pembayaran tidak cocok dengan nilai ledger.',
          'Ledger aktif transaksi belum dapat direkonsiliasi.',
          'Pembayaran aktif melebihi tagihan tersimpan.',
          'Ringkasan pembayaran berbeda dari ledger aktif.',
        ]),
      );
      expect(report.total, BigInt.from(225000));
    },
  );

  test(
    'active Penghasilan read is enforced without a superadmin bypass',
    () async {
      for (final denied in [
        penghasilanReader(allowed: false),
        penghasilanReader(status: 0),
        uiSession(groupType: 'superadmin'),
      ]) {
        session = denied;
        await expectLater(repo.read(), throwsStateError);
        expect(repo.watch, throwsStateError);
      }
    },
  );
}
