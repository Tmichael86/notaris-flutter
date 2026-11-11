import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/repositories/transaction_cloud_repository.dart';
import 'package:frontend_notaris/repositories/transaction_repository.dart';
import 'package:frontend_notaris/repositories/transaction_upload_readiness.dart';

import 'recycle_bin_repository_test.dart' show rows, seedTransaction;

void main() {
  late Directory folder;
  late File file;
  late AppDatabase db;
  late int id;
  late TransaksiDetail detail;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('notaris-deed-');
    file = File('${folder.path}/fixture.sqlite');
    db = AppDatabase.forTesting(NativeDatabase(file));
    id = await seedTransaction(db, 'notaris');
    detail = await db.select(db.transaksiDetails).getSingle();
  });
  tearDown(() async {
    await db.close();
    await folder.delete(recursive: true);
  });

  Future<int> save(
    String status, {
    NotarisDeedInput? deed,
    bool invalidJob = false,
  }) => TransactionRepository(db).save(
    id: id,
    nomorTransaksi: '1000611260001',
    jenisTransaksi: 'notaris',
    pemohonId: 1,
    pemohonUuid: 'applicant',
    petugasId: 1,
    petugasUuid: 'officer',
    status: status,
    tanggalTransaksi: DateTime(2026, 11, 6),
    jobs: [
      TransactionJobInput(
        detailUuid: detail.uuid,
        jenisPekerjaan: 'notaris',
        namaPekerjaan: detail.namaPekerjaanSnapshot,
        pekerjaanNotarisId: detail.pekerjaanNotarisId,
        biayaLayanan: detail.biayaLayanan,
        unchangedDetail: invalidJob ? null : detail,
        prosesSnapshot: invalidJob ? 'invalid JSON' : null,
      ),
    ],
    deed: deed,
  );
  NotarisDeedInput deed() =>
      NotarisDeedInput(' Fidusia ', ' 0025211/A ', DateTime(2026, 11, 11, 23));

  test('requires each field only for a new completion', () async {
    await save('Baru');
    await save('Dalam Proses');
    for (final invalid in [
      null,
      NotarisDeedInput(' ', '25211', DateTime(2026, 11, 11)),
      NotarisDeedInput('Fidusia', '', DateTime(2026, 11, 11)),
      const NotarisDeedInput('Fidusia', '25211', null),
    ]) {
      await expectLater(save('Selesai', deed: invalid), throwsArgumentError);
    }
    final row = await db.select(db.transaksis).getSingle();
    expect(row.statusTransaksi, 'Dalam Proses');
    expect(row.judulAkta, isNull);
    await expectLater(save('Baru', deed: deed()), throwsArgumentError);
  });

  test(
    'completion survives restart and reopening without touching related rows',
    () async {
      await seedTransaction(db, 'ppat');
      final original = (await db.select(db.transaksis).get()).first;
      final other = (await db.select(db.transaksis).get()).last;
      final dependent = {
        for (final table in [
          'transaksi_details',
          'transaksi_proses',
          'transaksi_proses_riwayat',
          'transaksi_riwayat_pembayaran',
        ])
          table: await rows(db, table),
      };
      await save('Selesai', deed: deed());
      await db.close();
      db = AppDatabase.forTesting(NativeDatabase(file));
      final current = (await db.select(db.transaksis).get()).first;
      expect(current.uuid, original.uuid);
      expect(current.noAkta, original.noAkta);
      expect(current.statusTransaksi, 'Selesai');
      expect(current.judulAkta, 'Fidusia');
      expect(current.nomorAkta, '0025211/A');
      expect(current.tanggalAkta?.toUtc(), DateTime.utc(2026, 11, 11));
      await save('Dalam Proses');
      expect(
        (await db.select(db.transaksis).get()).first.nomorAkta,
        '0025211/A',
      );
      await save('Selesai');
      expect((await db.select(db.transaksis).get()).last, other);
      for (final entry in dependent.entries) {
        expect(await rows(db, entry.key), entry.value);
      }
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    },
  );

  test(
    'late detail failure rolls back completion and every child write',
    () async {
      final header = await db.select(db.transaksis).getSingle();
      final child = await db.select(db.transaksiProses).getSingle();
      await expectLater(
        save('Selesai', deed: deed(), invalidJob: true),
        throwsArgumentError,
      );
      expect(await db.select(db.transaksis).getSingle(), header);
      expect(await db.select(db.transaksiDetails).getSingle(), detail);
      expect(await db.select(db.transaksiProses).getSingle(), child);
    },
  );

  test(
    'historical Selesai remains nullable until deliberately completed again',
    () async {
      await db.customStatement(
        "UPDATE transaksis SET status_transaksi='Selesai'",
      );
      await save('Selesai');
      expect((await db.select(db.transaksis).getSingle()).tanggalAkta, isNull);
      await save('Dalam Proses');
      await expectLater(save('Selesai'), throwsArgumentError);
    },
  );

  test('pending payload blocks local completion and completed data blocks every push', () async {
    final uuid = (await db.select(db.transaksis).getSingle()).uuid;
    Future<void> stage() => db.customStatement(
      "INSERT INTO transaction_cloud_pending(local_uuid,mutation_id,payload,state) VALUES(?,'staged','{}','pending')",
      [uuid],
    );
    await stage();
    await expectLater(save('Selesai', deed: deed()), throwsStateError);
    expect(
      (await db.select(db.transaksis).getSingle()).statusTransaksi,
      'Dalam Proses',
    );
    await db.customStatement('DELETE FROM transaction_cloud_pending');
    await save('Selesai', deed: deed());
    expect(
      await TransactionUploadReadiness(db).check(
        id,
        domain: 'notaris',
        uuid: uuid,
        petugasScope: null,
        masterScope: null,
      ),
      contains('Data akta Notaris belum didukung oleh sinkronisasi Transaksi.'),
    );
    await stage();
    final dio = Dio();
    addTearDown(dio.close);
    final cloud = TransactionCloudRepository(
      db,
      dio,
      scope: 'fixture',
      petugasScope: 'fixture',
      masterScope: 'fixture',
    );
    for (final push in [cloud.pushCreate, cloud.pushUpdate, cloud.pushDelete]) {
      await expectLater(
        push(id),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Data akta Notaris'),
          ),
        ),
      );
    }
    expect(
      (await db
              .customSelect(
                'SELECT state,payload FROM transaction_cloud_pending',
              )
              .getSingle())
          .data,
      {'state': 'pending', 'payload': '{}'},
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
