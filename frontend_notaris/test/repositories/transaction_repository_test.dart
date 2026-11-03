import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
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
    await db.customStatement(
      "INSERT INTO pemohons(id,uuid,nama) VALUES(1,'applicant-uuid','Fixture')",
    );
    await db.customStatement(
      "INSERT INTO petugas(id,uuid,nama,email) VALUES(1,'officer-uuid','Fixture','fixture@example.invalid')",
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

      await expectLater(repository.deletePayment(paymentId), throwsA(anything));

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

  test('generates the next four-digit sequence without reusing soft-deleted numbers', () async {
    await db
        .into(db.transaksis)
        .insert(
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
  });

  test('duplicate numbers from separately opened forms are rejected without partial saves', () async {
    // Two forms can ask for a number before either one is saved.
    final firstCandidate = await repository.generateNextTransactionNumber(
      jenisTransaksi: 'notaris',
      date: DateTime(2026, 10, 14),
    );
    final secondCandidate = await repository.generateNextTransactionNumber(
      jenisTransaksi: 'notaris',
      date: DateTime(2026, 10, 14),
    );
    expect(secondCandidate, firstCandidate);

    Future<int> saveWithNumber(String number, String detailUuid) {
      return repository.save(
        nomorTransaksi: number,
        jenisTransaksi: 'notaris',
        pemohonId: 1,
        pemohonUuid: 'applicant-uuid',
        petugasId: 1,
        petugasUuid: 'officer-uuid',
        status: 'Baru',
        tanggalTransaksi: DateTime(2026, 10, 14),
        jobs: [
          TransactionJobInput(
            jenisPekerjaan: 'notaris',
            namaPekerjaan: 'Akta Test',
            pekerjaanNotarisId: pekerjaanNotarisId,
            biayaLayanan: 100000,
            detailUuid: detailUuid,
          ),
        ],
      );
    }

    await saveWithNumber(firstCandidate, 'detail-first-candidate');
    await expectLater(
      saveWithNumber(secondCandidate, 'detail-second-candidate'),
      throwsA(isA<StateError>()),
    );

    final rows = await db.select(db.transaksis).get();
    expect(rows, hasLength(1));
    expect(rows.single.noAkta, firstCandidate);
    final details = await db.select(db.transaksiDetails).get();
    expect(details, hasLength(1));
  });

  test('rejects transaction number sequence overflow beyond 9999', () async {
    await db
        .into(db.transaksis)
        .insert(
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

  test(
    'Notaris and PPAT keep references, snapshots and payments isolated',
    () async {
      await db.customStatement(
        "INSERT INTO pekerjaan_ppat(id,uuid,nama) VALUES(1,'ppat-job','PPAT Fixture')",
      );
      Future<int> save(String type, String number, String detail) =>
          repository.save(
            nomorTransaksi: number,
            jenisTransaksi: type,
            pemohonId: 1,
            pemohonUuid: 'applicant-uuid',
            petugasId: 1,
            petugasUuid: 'officer-uuid',
            status: 'Baru',
            tanggalTransaksi: DateTime(2026, 11, 3),
            pembayaranSekarang: 100,
            jobs: [
              TransactionJobInput(
                detailUuid: detail,
                jenisPekerjaan: type,
                namaPekerjaan: 'Snapshot $type',
                pekerjaanNotarisId: type == 'notaris'
                    ? pekerjaanNotarisId
                    : null,
                pekerjaanPpatId: type == 'ppat' ? 1 : null,
                kategoriSnapshot: 'Synthetic Category',
                estimasiWaktuSnapshot: '2 hari',
                prosesSnapshot:
                    '[{"id":"p1","name":"Pemeriksaan","attributes":["KTP"]}]',
                biayaLayanan: 1000,
              ),
            ],
          );
      final notarisId = await save('notaris', '1000311260001', 'n-detail');
      final ppatId = await save('ppat', '2000311260002', 'p-detail');
      expect(await repository.getPaymentHistory(notarisId), hasLength(1));
      expect(await repository.getPaymentHistory(ppatId), hasLength(1));
      await db.customStatement(
        "UPDATE pekerjaan_notaris SET nama='Master changed' WHERE id=?",
        [pekerjaanNotarisId],
      );
      final before = (await repository.watchDetailsOnce(notarisId)).single;
      expect(before.namaPekerjaanSnapshot, 'Snapshot notaris');
      expect(before.prosesSnapshot, contains('KTP'));
      await repository.save(
        id: notarisId,
        nomorTransaksi: '1000311260001',
        jenisTransaksi: 'notaris',
        pemohonId: 1,
        pemohonUuid: 'applicant-uuid',
        petugasId: 1,
        petugasUuid: 'officer-uuid',
        status: 'Baru',
        tanggalTransaksi: DateTime(2026, 11, 3),
        jobs: [
          TransactionJobInput(
            detailUuid: before.uuid,
            jenisPekerjaan: 'notaris',
            namaPekerjaan: before.namaPekerjaanSnapshot,
            pekerjaanNotarisId: pekerjaanNotarisId,
            kategoriSnapshot: before.kategoriSnapshot,
            estimasiWaktuSnapshot: before.estimasiWaktuSnapshot,
            prosesSnapshot: before.prosesSnapshot,
            biayaLayanan: before.biayaLayanan,
          ),
        ],
      );
      final after = (await repository.watchDetailsOnce(notarisId)).single;
      expect(after.id, before.id);
      expect(after.uuid, before.uuid);
      expect(after.namaPekerjaanSnapshot, before.namaPekerjaanSnapshot);
      expect(await repository.getPaymentHistory(notarisId), hasLength(1));
      expect(await repository.getPaymentHistory(ppatId), hasLength(1));
      expect(
        (await repository.watchDetailsOnce(ppatId)).single.pekerjaanPpatId,
        1,
      );
      final integrity = await db.customSelect('PRAGMA integrity_check').get();
      expect(integrity.single.read<String>('integrity_check'), 'ok');
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    },
  );

  test(
    'invalid local references and crossed job types leave no rows',
    () async {
      await expectLater(
        repository.save(
          nomorTransaksi: '1000311260003',
          jenisTransaksi: 'notaris',
          pemohonId: 1,
          pemohonUuid: 'wrong',
          petugasId: 1,
          petugasUuid: 'officer-uuid',
          status: 'Baru',
          tanggalTransaksi: DateTime(2026, 11, 3),
          jobs: [
            TransactionJobInput(
              detailUuid: 'bad',
              jenisPekerjaan: 'notaris',
              namaPekerjaan: 'Bad',
              pekerjaanNotarisId: pekerjaanNotarisId,
              biayaLayanan: 100,
            ),
          ],
        ),
        throwsArgumentError,
      );
      await expectLater(
        repository.save(
          nomorTransaksi: '1000311260004',
          jenisTransaksi: 'notaris',
          pemohonId: 1,
          pemohonUuid: 'applicant-uuid',
          petugasId: 1,
          petugasUuid: 'officer-uuid',
          status: 'Baru',
          tanggalTransaksi: DateTime(2026, 11, 3),
          jobs: [
            TransactionJobInput(
              detailUuid: 'cross',
              jenisPekerjaan: 'notaris',
              namaPekerjaan: 'Bad',
              pekerjaanNotarisId: pekerjaanNotarisId,
              pekerjaanPpatId: 1,
              biayaLayanan: 100,
            ),
          ],
        ),
        throwsArgumentError,
      );
      expect(await db.select(db.transaksis).get(), isEmpty);
      expect(await db.select(db.transaksiDetails).get(), isEmpty);
    },
  );

  test('PPAT transaction and initial payment survive SQLite reopen', () async {
    final folder = await Directory.systemTemp.createTemp(
      'notaris-transaction-',
    );
    addTearDown(() => folder.delete(recursive: true));
    final file = File('${folder.path}/offline.sqlite');
    var persistent = AppDatabase.forTesting(NativeDatabase(file));
    await persistent.customStatement(
      "INSERT INTO pemohons(id,uuid,nama) VALUES(1,'p','Fixture')",
    );
    await persistent.customStatement(
      "INSERT INTO petugas(id,uuid,nama,email) VALUES(1,'o','Fixture','f@example.invalid')",
    );
    await persistent.customStatement(
      "INSERT INTO pekerjaan_ppat(id,uuid,nama) VALUES(1,'j','Fixture')",
    );
    final id = await TransactionRepository(persistent).save(
      nomorTransaksi: '2000311260001',
      jenisTransaksi: 'ppat',
      pemohonId: 1,
      pemohonUuid: 'p',
      petugasId: 1,
      petugasUuid: 'o',
      status: 'Baru',
      tanggalTransaksi: DateTime(2026, 11, 3),
      pembayaranSekarang: 100,
      jobs: const [
        TransactionJobInput(
          detailUuid: 'stable-detail',
          jenisPekerjaan: 'ppat',
          namaPekerjaan: 'PPAT snapshot',
          pekerjaanPpatId: 1,
          prosesSnapshot: '[{"name":"Check","attributes":["KTP"]}]',
          biayaLayanan: 1000,
        ),
      ],
    );
    await persistent.close();
    persistent = AppDatabase.forTesting(NativeDatabase(file));
    final reopened = TransactionRepository(persistent);
    expect((await reopened.findById(id))!.jenisTransaksi, 'ppat');
    expect((await reopened.watchDetailsOnce(id)).single.uuid, 'stable-detail');
    expect(
      (await reopened.watchDetailsOnce(id)).single.prosesSnapshot,
      contains('KTP'),
    );
    expect(await reopened.getPaymentHistory(id), hasLength(1));
    expect(
      await persistent.customSelect('PRAGMA foreign_key_check').get(),
      isEmpty,
    );
    await persistent.close();
  });
}
