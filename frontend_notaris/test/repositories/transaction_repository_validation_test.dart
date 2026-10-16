import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/repositories/transaction_repository.dart';

void main() {
  late AppDatabase database;
  late TransactionRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = TransactionRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<int> saveTransaction({double discount = 0, double payment = 0}) {
    return repository.save(
      nomorTransaksi: '1000110260001',
      jenisTransaksi: 'notaris',
      pemohonId: 1,
      pemohonUuid: 'pemohon-test',
      petugasId: 1,
      petugasUuid: 'petugas-test',
      status: 'Baru',
      tanggalTransaksi: DateTime(2026, 10, 15),
      jobs: const [
        TransactionJobInput(
          detailUuid: 'detail-validation-test',
          jenisPekerjaan: 'notaris',
          namaPekerjaan: 'Akta test',
          pekerjaanNotarisId: 1,
          biayaLayanan: 100,
        ),
      ],
      diskon: discount,
      pembayaranSekarang: payment,
    );
  }

  test(
    'rejects an initial payment greater than the net transaction total',
    () async {
      await expectLater(saveTransaction(payment: 101), throwsArgumentError);
    },
  );

  test('rejects a discount greater than the job total', () async {
    await expectLater(saveTransaction(discount: 101), throwsArgumentError);
  });

  test('rejects a negative initial payment', () async {
    await expectLater(saveTransaction(payment: -1), throwsArgumentError);
  });

  test('rejects negative job costs', () async {
    await expectLater(
      repository.save(
        nomorTransaksi: '1000110260001',
        jenisTransaksi: 'notaris',
        pemohonId: 1,
        pemohonUuid: 'pemohon-test',
        petugasId: 1,
        petugasUuid: 'petugas-test',
        status: 'Baru',
        tanggalTransaksi: DateTime(2026, 10, 15),
        jobs: const [
          TransactionJobInput(
            detailUuid: 'detail-negative-cost-test',
            jenisPekerjaan: 'notaris',
            namaPekerjaan: 'Akta test',
            pekerjaanNotarisId: 1,
            biayaLayanan: 100,
            biayaLainnya: -1,
          ),
        ],
      ),
      throwsArgumentError,
    );
  });
}
