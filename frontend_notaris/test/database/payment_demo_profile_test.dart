import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/notaris_completion_demo_main.dart';
import 'package:frontend_notaris/payment_demo_main.dart';
import 'package:frontend_notaris/repositories/transaction_repository.dart';
import 'package:frontend_notaris/services/auth_service.dart';
import 'package:path/path.dart' as p;

import '../support/transaction_ui_test_support.dart' show uiSession;

void main() {
  final id = Platform.environment['NOTARIS_PAYMENT_PREPARE'];
  test(
    'prepare owned payment fixture with initial cash and protected references',
    () async {
      final file = File(p.join(paymentDemoRoot(id!).path, 'offline.sqlite'));
      if (FileSystemEntity.typeSync(file.path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw StateError('Fixture harus baru.');
      }
      final db = AppDatabase.forTesting(NativeDatabase(file));
      try {
        final repo = TransactionRepository(db);
        await db.transaction(() async {
          for (final sql in [
            "INSERT INTO pemohons(id,uuid,nama) VALUES(1,'44eb657b-2f98-4c92-b346-d695d5ac0001','Bagas Pradipta'),(2,'44eb657b-2f98-4c92-b346-d695d5ac0002','Laras Mahendra')",
            "INSERT INTO petugas(id,uuid,nama,email) VALUES(1,'44eb657b-2f98-4c92-b346-d695d5ac0003','Dimas Prasetyo','dimas@example.invalid')",
            "INSERT INTO pekerjaan_kategori(id,uuid,nama) VALUES(1,'44eb657b-2f98-4c92-b346-d695d5ac0004','Perjanjian dan Jaminan'),(2,'44eb657b-2f98-4c92-b346-d695d5ac0005','Peralihan Hak')",
            "INSERT INTO pekerjaan_notaris(id,uuid,nama) VALUES(1,'44eb657b-2f98-4c92-b346-d695d5ac0006','Pembuatan Akta Fidusia')",
            "INSERT INTO pekerjaan_ppat(id,uuid,nama) VALUES(1,'44eb657b-2f98-4c92-b346-d695d5ac0007','Akta Jual Beli')",
            "INSERT INTO pekerjaan_notaris_harga(uuid,pekerjaan_notaris_id,kategori_pekerjaan_id,harga,estimasi_waktu) VALUES('44eb657b-2f98-4c92-b346-d695d5ac0008',1,1,'3000000','3 hari')",
            "INSERT INTO pekerjaan_ppat_harga(uuid,pekerjaan_ppat_id,kategori_pekerjaan_id,harga,estimasi_waktu) VALUES('44eb657b-2f98-4c92-b346-d695d5ac0009',1,2,'3000000','5 hari')",
          ]) {
            await db.customStatement(sql);
          }
          for (final notaris in [true, false]) {
            final domain = notaris ? 'notaris' : 'ppat';
            await repo.save(
              nomorTransaksi: notaris ? paymentDemoNotaris : paymentDemoPpat,
              jenisTransaksi: domain,
              pemohonId: notaris ? 1 : 2,
              pemohonUuid: notaris
                  ? '44eb657b-2f98-4c92-b346-d695d5ac0001'
                  : '44eb657b-2f98-4c92-b346-d695d5ac0002',
              petugasId: 1,
              petugasUuid: '44eb657b-2f98-4c92-b346-d695d5ac0003',
              status: 'Dalam Proses',
              tanggalTransaksi: DateTime(2026, 11, 10),
              tanggalJatuhTempo: DateTime(2026, 11, 18),
              pembayaranSekarang: 500000,
              jobs: [
                TransactionJobInput(
                  jenisPekerjaan: domain,
                  namaPekerjaan: notaris
                      ? 'Pembuatan Akta Fidusia'
                      : 'Akta Jual Beli',
                  pekerjaanNotarisId: notaris ? 1 : null,
                  pekerjaanPpatId: notaris ? null : 1,
                  detailUuid: notaris
                      ? '44eb657b-2f98-4c92-b346-d695d5ac0010'
                      : '44eb657b-2f98-4c92-b346-d695d5ac0011',
                  hargaUuid: notaris
                      ? '44eb657b-2f98-4c92-b346-d695d5ac0008'
                      : '44eb657b-2f98-4c92-b346-d695d5ac0009',
                  kategoriUuid: notaris
                      ? '44eb657b-2f98-4c92-b346-d695d5ac0004'
                      : '44eb657b-2f98-4c92-b346-d695d5ac0005',
                  biayaLayanan: 3000000,
                  kategoriSnapshot: notaris
                      ? 'Perjanjian dan Jaminan'
                      : 'Peralihan Hak',
                  prosesSnapshot: jsonEncode([
                    {
                      'id': '1',
                      'name': 'Pemeriksaan kelengkapan berkas',
                      'status': 'Belum Valid',
                      'attributes': <String>[],
                    },
                  ]),
                ),
              ],
            );
          }
        });
      } finally {
        await db.close();
      }
      final reopened = await openPaymentDemo(id);
      try {
        expect(
          await reopened.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        final payments = await reopened
            .select(reopened.transaksiRiwayatPembayarans)
            .get();
        expect(payments.map((row) => row.nominalRupiah), [500000, 500000]);
      } finally {
        await reopened.close();
      }
      final dio = Dio();
      addTearDown(dio.close);
      final helper = File(p.join(paymentDemoRoot(id).path, 'session.exe'));
      final auth = PaymentDemoAuth(
        dio,
        id,
        sha256.convert(helper.readAsBytesSync()).toString(),
      );
      await auth.verifyProfile();
      for (final name in PaymentDemoAuth.usernames) {
        await expectLater(
          auth.login(username: name, password: 'invalid', rememberMe: true),
          throwsA(isA<AuthException>()),
        );
        expect(await auth.restoreSession(), isNull);
      }
    },
    skip: id == null,
  );

  final rehearsalId = Platform.environment['NOTARIS_PAYMENT_REHEARSAL'] ?? id;
  test(
    'postchecks validate each payment stage on a copy of the initial profile',
    () async {
      final original = File(
        p.join(paymentDemoRoot(rehearsalId!).path, 'offline.sqlite'),
      );
      await rehearsePaymentCheckpoints(original);
    },
    skip: rehearsalId == null,
  );

  test('offline entry refuses to restore or construct a free-form privileged session', () async {
    final dio = Dio();
    addTearDown(dio.close);
    final auth = PaymentDemoAuth(dio, 'invalid', 'invalid');
    expect(await auth.restoreSession(), isNull);
    for (final name in ['102', 'admin.demo']) {
      await expectLater(
        auth.login(username: name, password: 'fake', rememberMe: true),
        throwsA(isA<AuthException>()),
      );
    }
    expect(
      () => CompletionDemoNoHttp().createHttpClient(null),
      throwsStateError,
    );
    final privileged = uiSession(groupType: 'superadmin');
    final expired = ExpiringPaymentDemoSession(
      privileged,
      DateTime.now().subtract(const Duration(seconds: 1)),
    );
    expect(expired.hasTransactionAccess(update: true), isFalse);
    expect(expired.canCorrectTransactionPayment, isFalse);
  });
}

Future<void> rehearsePaymentCheckpoints(File original) async {
  final temp = await Directory.systemTemp.createTemp('payment-checkpoints-');
  try {
    final file = await original.copy(p.join(temp.path, 'offline.sqlite'));
    final checker = p.absolute('..', 'scripts', 'payment-demo-acceptance.py');
    Future<Map<String, dynamic>> snapshot() async {
      final result = await Process.run('python.exe', [
        '-c',
        'import json,runpy,sys; from pathlib import Path; '
            'print(json.dumps(runpy.run_path(sys.argv[1])["snapshot"](Path(sys.argv[2]).resolve())))',
        checker,
        temp.path,
      ]);
      expect(result.exitCode, 0, reason: result.stderr.toString());
      return jsonDecode(result.stdout as String) as Map<String, dynamic>;
    }

    final baseline = await snapshot();
    const payment = '537a6e3d-7e8b-48ba-8d89-3c80c4eb0001';
    final date = DateTime(2026, 11, 11);
    final officer = uiSession(userId: 101);
    final admin = uiSession(groupType: 'superadmin', userId: 102);
    for (final (phase, expectedPaid) in [
      ('add', 1250000),
      ('edit', 1300000),
      ('cancel', 500000),
    ]) {
      final db = AppDatabase.forTesting(NativeDatabase(file));
      try {
        final repo = TransactionRepository(db);
        final records = await db.select(db.transaksis).get();
        final id = records
            .singleWhere((row) => row.noAkta == paymentDemoNotaris)
            .id;
        if (phase == 'add') {
          await repo.addPayment(
            session: officer,
            transactionId: id,
            paymentUuid: payment,
            paymentDate: date,
            amount: 750000,
          );
        } else {
          final installment = (await repo.getPaymentHistory(id))
              .singleWhere((row) => row.uuid == payment);
          if (phase == 'edit') {
            await repo.editPayment(
              session: admin,
              transactionId: id,
              expected: installment,
              paymentDate: date,
              amount: 800000,
              method: 'Cash',
              reason: 'Bukti setor',
            );
          } else {
            await repo.cancelPayment(
              session: admin,
              transactionId: id,
              expected: installment,
              reason: 'Salah transaksi',
            );
          }
        }
      } finally {
        await db.close();
      }
      final evidence = await snapshot();
      expect(evidence['phase'], phase);
      expect(evidence['paid'], expectedPaid);
      expect(evidence['protected_sha256'], baseline['protected_sha256']);
    }
    final reopened = AppDatabase.forTesting(NativeDatabase(file));
    try {
      final rows = await reopened
          .select(reopened.transaksiRiwayatPembayarans)
          .get();
      expect(rows.singleWhere((row) => row.uuid == payment).status, 0);
    } finally {
      await reopened.close();
    }
    expect((await snapshot())['phase'], 'cancel');
  } finally {
    await temp.delete(recursive: true);
  }
}
