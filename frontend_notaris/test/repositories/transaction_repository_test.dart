import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/repositories/transaction_repository.dart';
import 'package:frontend_notaris/repositories/transaksi_proses_repository.dart';

void main() {
  late AppDatabase db;
  late TransactionRepository repository;
  late TransaksiProsesRepository processRepository;
  late int pekerjaanNotarisId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repository = TransactionRepository(db);
    processRepository = TransaksiProsesRepository(db);

    pekerjaanNotarisId = await db
        .into(db.pekerjaanNotarisLocals)
        .insert(
          PekerjaanNotarisLocalsCompanion.insert(
            uuid: 'job-uuid',
            nama: 'Akta Test',
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'saving a transaction persists its process snapshot as process rows',
    () async {
      final transactionId = await repository.save(
        nomorTransaksi: '1001210260001',
        jenisTransaksi: 'notaris',
        pemohonId: 1,
        pemohonUuid: 'applicant-uuid',
        petugasId: 1,
        petugasUuid: 'officer-uuid',
        status: 'Baru',
        tanggalTransaksi: DateTime(2026, 10, 12),
        jobs: [
          TransactionJobInput(
            jenisPekerjaan: 'notaris',
            namaPekerjaan: 'Akta Test',
            pekerjaanNotarisId: pekerjaanNotarisId,
            biayaLayanan: 100000,
            detailUuid: 'detail-uuid',
            prosesSnapshot:
                '[{"id":"process-1","name":"Pemeriksaan dokumen","status":"Belum Valid"},'
                '{"id":"process-2","name":"Penandatanganan","status":"Belum Valid"}]',
          ),
        ],
      );

      final processes = await processRepository.getByTransactionId(
        transactionId,
      );

      expect(processes, hasLength(2));
      expect(processes.map((process) => process.sourceProcessId).toList(), [
        'process-1',
        'process-2',
      ]);
      expect(processes.map((process) => process.namaProsesSnapshot).toList(), [
        'Pemeriksaan dokumen',
        'Penandatanganan',
      ]);
      expect(
        processes.every((process) => process.statusProses == null),
        isTrue,
      );
    },
  );

  test('editing a transaction preserves workflow state and soft-deletes removed processes', () async {
    final transactionId = await repository.save(
      nomorTransaksi: '1001210260002',
      jenisTransaksi: 'notaris',
      pemohonId: 1,
      pemohonUuid: 'applicant-uuid',
      petugasId: 1,
      petugasUuid: 'officer-uuid',
      status: 'Baru',
      tanggalTransaksi: DateTime(2026, 10, 12),
      jobs: [
        TransactionJobInput(
          jenisPekerjaan: 'notaris',
          namaPekerjaan: 'Akta Test',
          pekerjaanNotarisId: pekerjaanNotarisId,
          biayaLayanan: 100000,
          detailUuid: 'detail-uuid',
          prosesSnapshot:
              '[{"id":"process-1","name":"Pemeriksaan dokumen","status":"Belum Valid"},'
              '{"id":"process-2","name":"Penandatanganan","status":"Belum Valid"}]',
        ),
      ],
    );

    final initial = await processRepository.getByTransactionId(transactionId);
    final firstProcess = initial.firstWhere(
      (process) => process.sourceProcessId == 'process-1',
    );
    await processRepository.initializeLegacyProcess(
      processId: firstProcess.id,
      actorUserId: 10,
    );

    await repository.save(
      id: transactionId,
      nomorTransaksi: '1001210260002',
      jenisTransaksi: 'notaris',
      pemohonId: 1,
      pemohonUuid: 'applicant-uuid',
      petugasId: 1,
      petugasUuid: 'officer-uuid',
      status: 'Dalam Proses',
      tanggalTransaksi: DateTime(2026, 10, 12),
      jobs: [
        TransactionJobInput(
          jenisPekerjaan: 'notaris',
          namaPekerjaan: 'Akta Test',
          pekerjaanNotarisId: pekerjaanNotarisId,
          biayaLayanan: 100000,
          detailUuid: 'detail-uuid',
          prosesSnapshot:
              '[{"id":"process-1","name":"Pemeriksaan dokumen revisi","status":"Belum Valid"},'
              '{"id":"process-3","name":"Pengesahan","status":"Belum Valid"}]',
        ),
      ],
    );

    final active = await processRepository.getByTransactionId(transactionId);
    expect(active, hasLength(2));

    final retained = active.firstWhere(
      (process) => process.sourceProcessId == 'process-1',
    );
    expect(retained.id, firstProcess.id);
    expect(retained.namaProsesSnapshot, 'Pemeriksaan dokumen revisi');
    expect(retained.statusProses, 'belum_dikerjakan');
    expect((await processRepository.getHistory(firstProcess.id)), hasLength(1));

    final allRows = await (db.select(
      db.transaksiProses,
    )..where((process) => process.transaksiId.equals(transactionId))).get();
    final removed = allRows.firstWhere(
      (process) => process.sourceProcessId == 'process-2',
    );
    expect(removed.deletedAt, isNotNull);
  });

  test(
    'null process snapshot does not delete existing process state',
    () async {
      final transactionId = await repository.save(
        nomorTransaksi: '1001210260003',
        jenisTransaksi: 'notaris',
        pemohonId: 1,
        pemohonUuid: 'applicant-uuid',
        petugasId: 1,
        petugasUuid: 'officer-uuid',
        status: 'Baru',
        tanggalTransaksi: DateTime(2026, 10, 12),
        jobs: [
          TransactionJobInput(
            jenisPekerjaan: 'notaris',
            namaPekerjaan: 'Akta Test',
            pekerjaanNotarisId: pekerjaanNotarisId,
            biayaLayanan: 100000,
            detailUuid: 'detail-uuid',
            prosesSnapshot: '[{"id":"process-1","name":"Pemeriksaan dokumen"}]',
          ),
        ],
      );

      await repository.save(
        id: transactionId,
        nomorTransaksi: '1001210260003',
        jenisTransaksi: 'notaris',
        pemohonId: 1,
        pemohonUuid: 'applicant-uuid',
        petugasId: 1,
        petugasUuid: 'officer-uuid',
        status: 'Dalam Proses',
        tanggalTransaksi: DateTime(2026, 10, 12),
        jobs: [
          TransactionJobInput(
            jenisPekerjaan: 'notaris',
            namaPekerjaan: 'Akta Test',
            pekerjaanNotarisId: pekerjaanNotarisId,
            biayaLayanan: 100000,
            detailUuid: 'detail-uuid',
          ),
        ],
      );

      final processes = await processRepository.getByTransactionId(
        transactionId,
      );
      expect(processes, hasLength(1));
      expect(processes.single.sourceProcessId, 'process-1');
    },
  );

  test(
    'deletePayment rolls back the payment soft-delete when header update fails',
    () async {
      final transactionId = await repository.save(
        nomorTransaksi: '1001210260004',
        jenisTransaksi: 'notaris',
        pemohonId: 1,
        pemohonUuid: 'applicant-uuid',
        petugasId: 1,
        petugasUuid: 'officer-uuid',
        status: 'Baru',
        tanggalTransaksi: DateTime(2026, 10, 12),
        jobs: [
          TransactionJobInput(
            jenisPekerjaan: 'notaris',
            namaPekerjaan: 'Akta Test',
            pekerjaanNotarisId: pekerjaanNotarisId,
            biayaLayanan: 100000,
            detailUuid: 'detail-payment-atomicity',
          ),
        ],
      );

      final paymentId = await repository.addPayment(
        transactionId: transactionId,
        paymentDate: DateTime(2026, 10, 14),
        amount: 25000,
      );

      // Fail the second write after deletePayment has attempted to soft-delete
      // the payment row. The transaction should roll the first write back.
      await db.customStatement('''
        CREATE TRIGGER fail_payment_header_update
        BEFORE UPDATE OF pembayaran_sekarang ON transaksis
        BEGIN
          SELECT RAISE(ABORT, 'forced header update failure');
        END
      ''');

      await expectLater(
        repository.deletePayment(paymentId),
        throwsA(anything),
      );

      final history = await repository.getPaymentHistory(transactionId);
      expect(history, hasLength(1));
      expect(history.single.id, paymentId);
      expect(history.single.deletedAt, isNull);
      expect(history.single.status, 1);

      final transaction = await repository.findById(transactionId);
      expect(transaction, isNotNull);
      expect(transaction!.pembayaranSekarang, 25000);
    },
  );


  test(
    'generates the next four-digit sequence without reusing soft-deleted numbers',
    () async {
      await db.into(db.transaksis).insert(
        TransaksisCompanion.insert(
          uuid: 'uuid-soft-deleted-sequence',
          noAkta: '2001010260007',
          total: 0,
          deletedAt: Value(DateTime(2026, 10, 1)),
        ),
      );

      final nextNumber = await repository.generateNextTransactionNumber(
        jenisTransaksi: 'notaris',
        date: DateTime(2026, 10, 14),
      );

      expect(nextNumber, '1001410260008');
      expect(nextNumber, hasLength(13));
    },
  );

  test('rejects transaction number sequence overflow beyond 9999', () async {
    await db.into(db.transaksis).insert(
      TransaksisCompanion.insert(
        uuid: 'uuid-sequence-limit',
        noAkta: '1001410269999',
        total: 0,
      ),
    );

    await expectLater(
      repository.generateNextTransactionNumber(
        jenisTransaksi: 'notaris',
        date: DateTime(2026, 10, 14),
      ),
      throwsA(isA<StateError>()),
    );
  });

}
