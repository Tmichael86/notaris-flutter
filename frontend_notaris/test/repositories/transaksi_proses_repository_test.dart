import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/repositories/transaksi_proses_repository.dart';
import 'package:frontend_notaris/repositories/transaction_cloud_repository.dart';

import '../support/transaction_ui_test_support.dart';

void main() {
  late AppDatabase db;
  late TransaksiProsesRepository repository;
  late int processId;
  late Directory directory;
  late File databaseFile;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('process-validation-');
    databaseFile = File('${directory.path}/fixture.sqlite');
    db = AppDatabase(NativeDatabase(databaseFile));
    repository = TransaksiProsesRepository(db);

    final transactionId = await db
        .into(db.transaksis)
        .insert(
          TransaksisCompanion.insert(
            uuid: 'transaction-uuid',
            noAkta: '1000000000001',
            total: 100000,
          ),
        );

    await db
        .into(db.transaksiDetails)
        .insert(
          TransaksiDetailsCompanion.insert(
            uuid: 'detail-uuid',
            transaksiId: transactionId,
            jenisPekerjaan: 'notaris',
            namaPekerjaanSnapshot: 'Akta Test',
          ),
        );

    processId = await db
        .into(db.transaksiProses)
        .insert(
          TransaksiProsesCompanion.insert(
            uuid: 'process-uuid',
            transaksiId: transactionId,
            transaksiDetailUuid: 'detail-uuid',
            namaProsesSnapshot: 'Pemeriksaan dokumen',
            statusProses: const Value(null),
          ),
        );
  });

  tearDown(() async {
    await db.close();
    await directory.delete(recursive: true);
  });

  test(
    'direct validation persists note, actor and audit through restart',
    () async {
      final session = uiSession();
      final legacy = (await repository.getByTransactionId(1)).single;
      await expectLater(
        repository.saveDirectValidation(
          session: session,
          expected: legacy,
          valid: true,
        ),
        throwsStateError,
      );
      final initialized = await repository.saveDirectValidation(
        session: session,
        expected: legacy,
        valid: null,
      );
      final validated = await repository.saveDirectValidation(
        session: session,
        expected: initialized,
        valid: true,
        note: '  Lengkap  ',
      );
      expect(validated.submittedByUserId, isNull);
      expect(validated.validatedByUserId, session.userId);
      expect(validated.validatedAt, isNotNull);
      await repository.saveDirectValidation(
        session: session,
        expected: validated,
        valid: true,
        note: 'Lengkap',
      );
      expect(await repository.getHistory(processId), hasLength(2));

      await db.close();
      db = AppDatabase(NativeDatabase(databaseFile));
      repository = TransaksiProsesRepository(db);
      final reopened = (await repository.getByTransactionId(1)).single;
      expect(reopened.statusProses, 'valid');
      expect(reopened.catatan, 'Lengkap');
      expect(reopened.validatedByUserId, session.userId);
      final amended = await repository.saveDirectValidation(
        session: session,
        expected: reopened,
        valid: true,
        note: 'Catatan tambahan',
      );
      expect(amended.validatedAt, reopened.validatedAt);
      await repository.saveDirectValidation(
        session: session,
        expected: amended,
        valid: false,
      );
      final history = await repository.getHistory(processId);
      expect(
        history.map((row) => row.actorUserId),
        everyElement(session.userId),
      );
      expect(history.map((row) => row.statusSebelumnya), [
        null,
        'belum_valid',
        'valid',
        'valid',
      ]);
      expect(history.map((row) => row.statusBaru), [
        'belum_valid',
        'valid',
        'valid',
        'belum_valid',
      ]);
      expect(history.map((row) => row.catatan), [
        null,
        'Lengkap',
        'Catatan tambahan',
        null,
      ]);
      final process = (await repository.getByTransactionId(1)).single;
      expect(process.validatedByUserId, isNull);
      expect(process.validatedAt, isNull);
      expect(process.isSyncDirty, isTrue);
      expect((await db.select(db.transaksis).getSingle()).isSyncDirty, isTrue);
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    },
  );

  test('rejects unauthorized, stale and pending-sync saves', () async {
    final process = (await repository.getByTransactionId(1)).single;
    await expectLater(
      repository.saveDirectValidation(
        session: uiSession(permission: false),
        expected: process,
        valid: null,
      ),
      throwsStateError,
    );
    await db.customStatement(
      "INSERT INTO transaction_cloud_pending(local_uuid,mutation_id,payload,state) VALUES('transaction-uuid','staged','{}','pending')",
    );
    await expectLater(
      repository.saveDirectValidation(
        session: uiSession(),
        expected: process,
        valid: null,
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('mutasi sinkronisasi tertunda'),
        ),
      ),
    );
    expect((await repository.getByTransactionId(1)).single, process);
    expect(await repository.getHistory(processId), isEmpty);
    expect(
      (await db
              .customSelect('SELECT payload FROM transaction_cloud_pending')
              .getSingle())
          .read<String>('payload'),
      '{}',
    );
    await db.customStatement(
      "UPDATE transaction_cloud_pending SET state='acked'",
    );
    final initialized = await repository.saveDirectValidation(
      session: uiSession(),
      expected: process,
      valid: null,
    );
    await expectLater(
      repository.saveDirectValidation(
        session: uiSession(),
        expected: process,
        valid: null,
      ),
      throwsStateError,
    );
    expect((await repository.getByTransactionId(1)).single, initialized);
    expect(await repository.getHistory(processId), hasLength(1));
  });

  test('a history write failure rolls back the process change', () async {
    final process = (await repository.getByTransactionId(1)).single;
    await db.customStatement('''
      CREATE TRIGGER fail_validation_history BEFORE INSERT ON transaksi_proses_riwayat
      BEGIN SELECT RAISE(ABORT, 'fixture failure'); END;
    ''');
    await expectLater(
      repository.saveDirectValidation(
        session: uiSession(),
        expected: process,
        valid: null,
      ),
      throwsA(isA<Exception>()),
    );
    expect((await repository.getByTransactionId(1)).single, process);
    expect(await repository.getHistory(processId), isEmpty);
  });

  test(
    'cloud CREATE fails closed even after an audited process is removed',
    () async {
      final process = (await repository.getByTransactionId(1)).single;
      await repository.saveDirectValidation(
        session: uiSession(),
        expected: process,
        valid: null,
      );
      await (db.update(db.transaksiProses)
            ..where((row) => row.id.equals(process.id)))
          .write(TransaksiProsesCompanion(deletedAt: Value(DateTime.now())));
      final dio = Dio();
      addTearDown(dio.close);
      final cloud = TransactionCloudRepository(
        db,
        dio,
        scope: 'fixture',
        petugasScope: 'fixture',
        masterScope: 'fixture',
      );
      await expectLater(
        cloud.stageCreate(process.transaksiId),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('cloud actor provenance'),
          ),
        ),
      );
      expect(
        await db.customSelect('SELECT * FROM transaction_cloud_pending').get(),
        isEmpty,
      );
      expect(
        await db.customSelect('SELECT * FROM transaction_cloud_feed').get(),
        isEmpty,
      );
    },
  );

  test(
    'legacy process must be initialized before normal transitions',
    () async {
      await expectLater(
        repository.transition(
          processId: processId,
          nextStatus: ProcessValidationStatus.dalamPengerjaan,
          actorUserId: 10,
        ),
        throwsA(isA<StateError>()),
      );

      await repository.initializeLegacyProcess(
        processId: processId,
        actorUserId: 10,
        note: 'Mulai menggunakan alur validasi baru',
      );

      final rows = await repository.getByTransactionId(1);
      expect(rows.single.statusProses, ProcessValidationStatus.belumDikerjakan);
      expect(
        (await repository.getHistory(processId)).single.statusBaru,
        ProcessValidationStatus.belumDikerjakan,
      );
    },
  );

  test('rejects an illegal transition', () async {
    await repository.initializeLegacyProcess(
      processId: processId,
      actorUserId: 10,
    );

    await expectLater(
      repository.transition(
        processId: processId,
        nextStatus: ProcessValidationStatus.valid,
        actorUserId: 20,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('submitter cannot validate own work and history is atomic', () async {
    await repository.initializeLegacyProcess(
      processId: processId,
      actorUserId: 10,
    );
    await repository.transition(
      processId: processId,
      nextStatus: ProcessValidationStatus.dalamPengerjaan,
      actorUserId: 10,
    );
    await repository.transition(
      processId: processId,
      nextStatus: ProcessValidationStatus.menungguValidasi,
      actorUserId: 10,
      note: 'Dokumen siap diperiksa',
    );

    await expectLater(
      repository.transition(
        processId: processId,
        nextStatus: ProcessValidationStatus.valid,
        actorUserId: 10,
      ),
      throwsA(isA<StateError>()),
    );

    await repository.transition(
      processId: processId,
      nextStatus: ProcessValidationStatus.valid,
      actorUserId: 20,
      note: 'Dokumen telah diperiksa',
    );

    final process = await (db.select(
      db.transaksiProses,
    )..where((row) => row.id.equals(processId))).getSingle();
    final history = await repository.getHistory(processId);

    expect(process.statusProses, ProcessValidationStatus.valid);
    expect(process.submittedByUserId, 10);
    expect(process.validatedByUserId, 20);
    expect(history.map((row) => row.statusBaru).toList(), [
      ProcessValidationStatus.belumDikerjakan,
      ProcessValidationStatus.dalamPengerjaan,
      ProcessValidationStatus.menungguValidasi,
      ProcessValidationStatus.valid,
    ]);
  });

  test(
    'revision requires a note and can be resubmitted by the worker',
    () async {
      await repository.initializeLegacyProcess(
        processId: processId,
        actorUserId: 10,
      );
      await repository.transition(
        processId: processId,
        nextStatus: ProcessValidationStatus.dalamPengerjaan,
        actorUserId: 10,
      );
      await repository.transition(
        processId: processId,
        nextStatus: ProcessValidationStatus.menungguValidasi,
        actorUserId: 10,
        note: 'Mohon diperiksa',
      );

      await expectLater(
        repository.transition(
          processId: processId,
          nextStatus: ProcessValidationStatus.perluRevisi,
          actorUserId: 20,
        ),
        throwsA(isA<ArgumentError>()),
      );

      await repository.transition(
        processId: processId,
        nextStatus: ProcessValidationStatus.perluRevisi,
        actorUserId: 20,
        note: 'Lampiran belum lengkap',
      );
      await repository.transition(
        processId: processId,
        nextStatus: ProcessValidationStatus.dalamPengerjaan,
        actorUserId: 10,
      );
      await repository.transition(
        processId: processId,
        nextStatus: ProcessValidationStatus.menungguValidasi,
        actorUserId: 10,
        note: 'Lampiran sudah dilengkapi',
      );

      final process = await (db.select(
        db.transaksiProses,
      )..where((row) => row.id.equals(processId))).getSingle();
      expect(process.statusProses, ProcessValidationStatus.menungguValidasi);
      expect(process.submittedByUserId, 10);
      expect(process.validatedByUserId, equals(null));
      expect((await repository.getHistory(processId)).length, 6);
    },
  );
}
