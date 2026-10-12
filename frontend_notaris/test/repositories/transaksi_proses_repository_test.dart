import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/repositories/transaksi_proses_repository.dart';

void main() {
  late AppDatabase db;
  late TransaksiProsesRepository repository;
  late int processId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repository = TransaksiProsesRepository(db);

    final transactionId = await db.into(db.transaksis).insert(
          TransaksisCompanion.insert(
            uuid: 'transaction-uuid',
            noAkta: '1000000000001',
            total: 100000,
          ),
        );

    await db.into(db.transaksiDetails).insert(
          TransaksiDetailsCompanion.insert(
            uuid: 'detail-uuid',
            transaksiId: transactionId,
            jenisPekerjaan: 'notaris',
            namaPekerjaanSnapshot: 'Akta Test',
          ),
        );

    processId = await db.into(db.transaksiProses).insert(
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
  });

  test('legacy process must be initialized before normal transitions', () async {
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
    expect((await repository.getHistory(processId)).single.statusBaru,
        ProcessValidationStatus.belumDikerjakan);
  });

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

    final process = await (db.select(db.transaksiProses)
          ..where((row) => row.id.equals(processId)))
        .getSingle();
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

  test('revision requires a note and can be resubmitted by the worker', () async {
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

    final process = await (db.select(db.transaksiProses)
          ..where((row) => row.id.equals(processId)))
        .getSingle();
    expect(process.statusProses, ProcessValidationStatus.menungguValidasi);
    expect(process.submittedByUserId, 10);
    expect(process.validatedByUserId, isNull);
    expect((await repository.getHistory(processId)).length, 6);
  });
}
