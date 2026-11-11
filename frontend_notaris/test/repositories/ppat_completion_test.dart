import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/repositories/transaction_cloud_repository.dart';
import 'package:frontend_notaris/repositories/transaction_repository.dart';
import 'package:frontend_notaris/repositories/transaction_upload_readiness.dart';

import '../support/transaction_ui_test_support.dart' show uiSession;
import 'recycle_bin_repository_test.dart' show rows, seedTransaction;

void main() {
  late Directory folder;
  late File file;
  late AppDatabase db;
  late TransactionRepository repo;
  late int id;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('ppat-completion-');
    file = File('${folder.path}/fixture.sqlite');
    db = AppDatabase.forTesting(NativeDatabase(file));
    repo = TransactionRepository(db);
    id = await seedTransaction(db, 'ppat');
    final first = (await repo.watchDetailsOnce(id)).single;
    await db
        .into(db.transaksiDetails)
        .insert(
          TransaksiDetailsCompanion.insert(
            uuid: 'same-master-second-detail',
            transaksiId: id,
            jenisPekerjaan: 'ppat',
            pekerjaanPpatId: Value(first.pekerjaanPpatId),
            namaPekerjaanSnapshot: first.namaPekerjaanSnapshot,
          ),
        );
  });
  tearDown(() async {
    await db.close();
    await folder.delete(recursive: true);
  });

  Future<TransaksiDetail> read([String uuid = 'detail-ppat']) => repo
      .readPpatJob(session: uiSession(), transactionId: id, detailUuid: uuid);

  test('separate detail with same Master is isolated through completion and restart', () async {
    final initial = await read();
    expect(initial.statusPekerjaanPpat, isNull);
    expect(initial.judulAktaPpat, isNull);
    final other = await read('same-master-second-detail');
    expect(other.pekerjaanPpatId, initial.pekerjaanPpatId);
    await repo.savePpatJobStatus(
      session: uiSession(),
      expected: other,
      status: PpatJobStatus.dalamProses,
    );
    final untouched = await read('same-master-second-detail');
    final protected = {
      for (final table in [
        'transaksis',
        'transaksi_proses',
        'transaksi_proses_riwayat',
        'transaksi_riwayat_pembayaran',
      ])
        table: await rows(db, table),
    };
    await repo.savePpatJobStatus(
      session: uiSession(),
      expected: initial,
      status: PpatJobStatus.selesai,
      title: ' Akta Jual Beli ',
      number: '0025211/A',
      date: DateTime(2026, 11, 11, 19),
    );
    await db.close();
    db = AppDatabase.forTesting(NativeDatabase(file));
    repo = TransactionRepository(db);
    final completed = await read();
    expect(completed.uuid, initial.uuid);
    expect(completed.id, initial.id);
    expect(completed.statusPekerjaanPpat, 'selesai');
    expect(completed.judulAktaPpat, 'Akta Jual Beli');
    expect(completed.nomorAktaPpat, '0025211/A');
    expect(completed.tanggalAktaPpat?.toUtc(), DateTime.utc(2026, 11, 11));
    await repo.savePpatJobStatus(
      session: uiSession(),
      expected: completed,
      status: PpatJobStatus.dalamProses,
    );
    final reopened = await read();
    expect(reopened.statusPekerjaanPpat, 'dalamProses');
    expect(reopened.judulAktaPpat, completed.judulAktaPpat);
    expect(reopened.nomorAktaPpat, completed.nomorAktaPpat);
    expect(reopened.tanggalAktaPpat, completed.tanggalAktaPpat);
    expect(await read('same-master-second-detail'), untouched);
    for (final entry in protected.entries) {
      expect(await rows(db, entry.key), entry.value);
    }
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });

  test(
    'permits nullable completion and rejects deed edits outside Selesai',
    () async {
      final detail = await read();
      await expectLater(
        repo.savePpatJobStatus(
          session: uiSession(),
          expected: detail,
          status: PpatJobStatus.dalamProses,
          number: '25',
        ),
        throwsArgumentError,
      );
      expect(await read(), detail);
      await repo.savePpatJobStatus(
        session: uiSession(),
        expected: detail,
        status: PpatJobStatus.selesai,
      );
      final completed = await read();
      expect(completed.statusPekerjaanPpat, 'selesai');
      expect(
        [
          completed.judulAktaPpat,
          completed.nomorAktaPpat,
          completed.tanggalAktaPpat,
        ],
        [null, null, null],
      );
    },
  );

  test(
    'enforces read and update access and rolls back a failed write',
    () async {
      final detail = await read();
      final readOnly = uiSession();
      readOnly.sidebars.single['update'] = 0;
      expect(
        await repo.readPpatJob(
          session: readOnly,
          transactionId: id,
          detailUuid: detail.uuid,
        ),
        detail,
      );
      await expectLater(
        repo.readPpatJob(
          session: uiSession(permission: false),
          transactionId: id,
          detailUuid: detail.uuid,
        ),
        throwsStateError,
      );
      await expectLater(
        repo.savePpatJobStatus(
          session: readOnly,
          expected: detail,
          status: PpatJobStatus.selesai,
        ),
        throwsStateError,
      );
      await db.customStatement('''
      CREATE TRIGGER reject_ppat_completion AFTER UPDATE ON transaksi_details
      BEGIN SELECT RAISE(ABORT, 'fixture failure'); END;
    ''');
      await expectLater(
        repo.savePpatJobStatus(
          session: uiSession(),
          expected: detail,
          status: PpatJobStatus.selesai,
          title: 'Jual Beli',
          number: '25',
          date: DateTime(2026, 11, 11),
        ),
        throwsA(isA<Exception>()),
      );
      expect(await read(), detail);
    },
  );

  test('protects pending journal and blocks unsafe upload even before pending replay', () async {
    final detail = await read();
    final uuid = (await db.select(db.transaksis).getSingle()).uuid;
    Future<void> stage() => db.customStatement(
      "INSERT INTO transaction_cloud_pending(local_uuid,mutation_id,payload,state) VALUES(?,'staged','{}','pending')",
      [uuid],
    );
    await stage();
    await expectLater(
      repo.savePpatJobStatus(
        session: uiSession(),
        expected: detail,
        status: PpatJobStatus.selesai,
      ),
      throwsStateError,
    );
    expect(await read(), detail);
    await db.customStatement('DELETE FROM transaction_cloud_pending');
    await repo.savePpatJobStatus(
      session: uiSession(),
      expected: detail,
      status: PpatJobStatus.selesai,
    );
    await stage();
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
    const reason =
        'Status pekerjaan dan data akta PPAT belum didukung oleh sinkronisasi Transaksi.';
    expect(
      await TransactionUploadReadiness(db).check(
        id,
        domain: 'ppat',
        uuid: uuid,
        petugasScope: null,
        masterScope: null,
      ),
      contains(reason),
    );
    for (final push in [cloud.pushCreate, cloud.pushUpdate, cloud.pushDelete]) {
      await expectLater(
        push(id),
        throwsA(
          isA<StateError>().having((error) => error.message, 'message', reason),
        ),
      );
    }
    expect(
      (await db
              .customSelect('SELECT payload FROM transaction_cloud_pending')
              .getSingle())
          .data,
      {'payload': '{}'},
    );
    expect(
      await db.customSelect('SELECT * FROM transaction_cloud_feed').get(),
      isEmpty,
    );
    expect(
      await db.customSelect('SELECT * FROM transaction_cloud_identity').get(),
      isEmpty,
    );
  });
}
