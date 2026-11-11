import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/repositories/transaction_cloud_repository.dart';
import 'package:frontend_notaris/repositories/transaction_repository.dart';

import '../support/transaction_ui_test_support.dart' show uiSession;
import 'recycle_bin_repository_test.dart' show rows, seedTransaction;

const first = '00000000-0000-4000-8000-000000000201';
const second = '00000000-0000-4000-8000-000000000202';
const third = '00000000-0000-4000-8000-000000000203';

void main() {
  late Directory temp;
  late File file;
  late AppDatabase db;
  late TransactionRepository repo;
  late int notaris;
  late int ppat;
  final actor = uiSession(groupType: 'superadmin', userId: 37);
  final date = DateTime(2026, 11, 11);

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('payment-audit-');
    file = File('${temp.path}/fixture.sqlite');
    db = AppDatabase.forTesting(NativeDatabase(file));
    repo = TransactionRepository(db);
    notaris = await seedTransaction(db, 'notaris');
    ppat = await seedTransaction(db, 'ppat');
  });
  tearDown(() async {
    await db.close();
    await temp.delete(recursive: true);
  });

  Future<int> add(int id, String uuid, int amount) => repo.addPayment(
    session: actor,
    transactionId: id,
    paymentUuid: uuid,
    paymentDate: date,
    amount: amount,
  );

  test(
    'acceptance amounts agree with the active ledger for both domains',
    () async {
      for (final (domain, templateId, paymentUuid) in [
        ('notaris', notaris, first),
        ('ppat', ppat, second),
      ]) {
        final template = (await repo.watchDetailsOnce(templateId)).single;
        final id = await repo.save(
          nomorTransaksi: domain == 'notaris'
              ? '1001111260001'
              : '2001111260001',
          jenisTransaksi: domain,
          pemohonId: 1,
          pemohonUuid: 'applicant',
          petugasId: 1,
          petugasUuid: 'officer',
          status: 'Dalam Proses',
          tanggalTransaksi: date,
          pembayaranSekarang: 500000,
          jobs: [
            TransactionJobInput(
              jenisPekerjaan: domain,
              namaPekerjaan: template.namaPekerjaanSnapshot,
              pekerjaanNotarisId: template.pekerjaanNotarisId,
              pekerjaanPpatId: template.pekerjaanPpatId,
              detailUuid: 'acceptance-$domain',
              biayaLayanan: 3000000,
            ),
          ],
        );
        Future<void> expectBalance(int paid, int remaining) async {
          final statement = await repo.watchPaymentStatement(id, actor).first;
          expect(
            (statement.billed, statement.paid, statement.remaining),
            (3000000, paid, remaining),
          );
          expect(statement.transaction.pembayaranSekarang, paid);
        }

        await expectBalance(500000, 2500000);
        await add(id, paymentUuid, 750000);
        await expectBalance(1250000, 1750000);
        Future<TransaksiRiwayatPembayaran> installment() async =>
            (await repo.getPaymentHistory(id))
                .singleWhere((row) => row.uuid == paymentUuid);
        await repo.editPayment(
          session: actor,
          transactionId: id,
          expected: await installment(),
          paymentDate: date,
          amount: 800000,
          method: 'Cash',
          reason: 'Bukti setor',
        );
        await expectBalance(1300000, 1700000);
        await repo.cancelPayment(
          session: actor,
          transactionId: id,
          expected: await installment(),
          reason: 'Salah transaksi',
        );
        await expectBalance(500000, 2500000);
      }
    },
  );

  test('integer balance, idempotent retry, corrected metadata and cancellation survive restart', () async {
    final original = await repo.watchPaymentStatement(notaris, actor).first;
    expect((original.billed, original.paid, original.remaining), (100, 20, 80));
    final unaffected = await repo.findById(ppat);
    final otherPayments = await repo.getPaymentHistory(ppat);
    final id = await add(notaris, first, 25);
    expect(await add(notaris, first, 25), id);
    await expectLater(add(notaris, first, 26), throwsStateError);
    await expectLater(add(ppat, first, 25), throwsStateError);
    await add(notaris, second, 5);
    final before = (await repo.getPaymentHistory(notaris))
        .singleWhere((p) => p.id == id);
    expect(
      await repo.editPayment(
        session: actor,
        transactionId: notaris,
        expected: before,
        paymentDate: DateTime(2026, 11, 12),
        amount: 40,
        method: 'Transfer',
        note: 'Bukti setor',
        reason: 'Nominal terkoreksi',
      ),
      isTrue,
    );
    final edited = (await repo.getPaymentHistory(notaris))
        .singleWhere((p) => p.id == id);
    expect(edited.nominalRupiah, 40);
    expect(edited.uuid, first);
    expect(edited.urutanPembayaran, 2);
    expect(edited.tanggalPembayaran, DateTime(2026, 11, 12));
    expect(edited.metodePembayaran, 'Transfer');
    expect(edited.keterangan, 'Bukti setor');
    expect((await repo.findById(notaris))?.pembayaranSekarang, 65);
    expect(await add(notaris, first, 25), id);
    await expectLater(
      repo.cancelPayment(
        session: actor,
        transactionId: ppat,
        expected: edited,
        reason: 'Salah transaksi',
      ),
      throwsStateError,
    );
    Future<bool> cancel() => repo.cancelPayment(
      session: actor,
      transactionId: notaris,
      expected: edited,
      reason: 'Pencatatan ganda',
    );
    expect(await cancel(), isTrue);
    expect(await cancel(), isFalse);
    expect((await repo.findById(notaris))?.pembayaranSekarang, 25);
    final next = await add(notaris, third, 5);
    await db.close();
    db = AppDatabase.forTesting(NativeDatabase(file));
    repo = TransactionRepository(db);
    final reopened = await repo.watchPaymentStatement(notaris, actor).first;
    expect((reopened.paid, reopened.remaining), (30, 70));
    expect(reopened.payments.map((p) => p.urutanPembayaran), [1, 2, 3, 4]);
    expect(reopened.payments.last.id, next);
    expect(reopened.payments[1].status, 0);
    expect(reopened.payments[1].deletedAt, isNotNull);
    expect(reopened.payments[1].nominalRupiah, 40);
    final audit = (await rows(
      db,
      'transaksi_pembayaran_audit',
    )).where((a) => a['payment_uuid'] == first);
    expect(audit.map((a) => a['action']), ['add', 'edit', 'cancel']);
    expect(audit.map((a) => a['actor_user_id']), everyElement(37));
    expect(audit.map((a) => a['reason']), [
      null,
      'Nominal terkoreksi',
      'Pencatatan ganda',
    ]);
    expect(
      jsonDecode(audit.elementAt(1)['before_state'] as String)['amount'],
      25,
    );
    expect(
      jsonDecode(audit.elementAt(1)['after_state'] as String)['amount'],
      40,
    );
    expect(jsonDecode(audit.last['after_state'] as String)['status'], 0);
    expect(await repo.findById(ppat), unaffected);
    expect(await repo.getPaymentHistory(ppat), otherPayments);
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });

  test('rejects invalid money, billing below paid, reused order, and historical fraction without rewriting', () async {
    for (final amount in [0, -1, 81]) {
      await expectLater(add(ppat, first, amount), throwsArgumentError);
    }
    final header = (await repo.findById(ppat))!;
    final job = (await repo.watchDetailsOnce(ppat)).single;
    await expectLater(
      repo.save(
        id: ppat,
        nomorTransaksi: header.noAkta,
        jenisTransaksi: 'ppat',
        pemohonId: 1,
        pemohonUuid: 'applicant',
        petugasId: 1,
        petugasUuid: 'officer',
        status: header.statusTransaksi,
        tanggalTransaksi: date,
        jobs: [
          TransactionJobInput(
            jenisPekerjaan: 'ppat',
            namaPekerjaan: job.namaPekerjaanSnapshot,
            pekerjaanPpatId: job.pekerjaanPpatId,
            detailUuid: job.uuid,
            biayaLayanan: 19,
          ),
        ],
      ),
      throwsArgumentError,
    );
    expect(await repo.findById(ppat), header);
    await expectLater(
      db.customStatement(
        "INSERT INTO transaksi_riwayat_pembayaran(uuid,transaksi_id,tanggal_pembayaran,nominal,nominal_rupiah,urutan_pembayaran) VALUES('bad-order',?,1,5,5,1)",
        [ppat],
      ),
      throwsA(anything),
    );
    await db.customStatement(
      'UPDATE transaksi_riwayat_pembayaran SET nominal=1.25, nominal_rupiah=NULL WHERE transaksi_id=?',
      [ppat],
    );
    final issue = await repo.watchPaymentStatement(ppat, actor).first;
    expect(issue.issue, isNotNull);
    expect(issue.paid, isNull);
    await expectLater(add(ppat, first, 10), throwsArgumentError);
    expect((await repo.getPaymentHistory(ppat)).single.nominal, 1.25);
    expect(await rows(db, 'transaksi_pembayaran_audit'), isEmpty);
    await db.customStatement(
      'UPDATE transaksi_riwayat_pembayaran SET status=0, deleted_at=2 WHERE transaksi_id=?',
      [ppat],
    );
    final dio = Dio();
    addTearDown(dio.close);
    final cloud = TransactionCloudRepository(
      db,
      dio,
      domain: 'ppat',
      scope: 'fixture',
      petugasScope: 'fixture',
      masterScope: 'fixture',
    );
    await expectLater(
      cloud.stageCreate(ppat),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('kontrak pembayaran cloud'),
        ),
      ),
    );
    expect(
      await db.customSelect('SELECT * FROM transaction_cloud_feed').get(),
      isEmpty,
    );
  });

  test(
    'permissions, failure rollback, and pending cloud journal are enforced',
    () async {
      final readOnly = uiSession(groupType: 'superadmin');
      readOnly.sidebars.single['update'] = 0;
      expect((await repo.watchPaymentStatement(ppat, readOnly).first).paid, 20);
      await expectLater(
        repo.watchPaymentStatement(ppat, null).first,
        throwsStateError,
      );
      await expectLater(
        repo.addPayment(
          session: readOnly,
          transactionId: ppat,
          paymentUuid: first,
          paymentDate: date,
          amount: 5,
        ),
        throwsStateError,
      );
      final payment = (await repo.getPaymentHistory(ppat)).single;
      await expectLater(
        repo.cancelPayment(
          session: uiSession(groupType: 'user'),
          transactionId: ppat,
          expected: payment,
          reason: 'Salah transaksi',
        ),
        throwsStateError,
      );
      await db.customStatement('''
      CREATE TRIGGER reject_audit BEFORE INSERT ON transaksi_pembayaran_audit
      BEGIN SELECT RAISE(ABORT, 'fixture audit failure'); END;
    ''');
      await expectLater(add(ppat, first, 10), throwsA(anything));
      expect(await repo.getPaymentHistory(ppat), [payment]);
      expect((await repo.findById(ppat))?.pembayaranSekarang, 20);
      await db.customStatement('DROP TRIGGER reject_audit');
      await add(ppat, first, 10);
      final header = (await repo.findById(ppat))!;
      await db.customStatement(
        "INSERT INTO transaction_cloud_pending(local_uuid,mutation_id,payload,state) VALUES(?,'staged','{}','pending')",
        [header.uuid],
      );
      await expectLater(add(ppat, second, 10), throwsStateError);
      final dio = Dio();
      addTearDown(dio.close);
      final cloud = TransactionCloudRepository(
        db,
        dio,
        domain: 'ppat',
        scope: 'fixture',
        petugasScope: 'fixture',
        masterScope: 'fixture',
      );
      for (final upload in [
        cloud.pushCreate,
        cloud.pushUpdate,
        cloud.pushDelete,
      ]) {
        await expectLater(
          upload(ppat),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('kontrak pembayaran cloud'),
            ),
          ),
        );
      }
      expect(
        (await db
                .customSelect(
                  'SELECT payload,state FROM transaction_cloud_pending',
                )
                .getSingle())
            .data,
        {'payload': '{}', 'state': 'pending'},
      );
      expect(
        await db.customSelect('SELECT * FROM transaction_cloud_feed').get(),
        isEmpty,
      );
    },
  );
}
