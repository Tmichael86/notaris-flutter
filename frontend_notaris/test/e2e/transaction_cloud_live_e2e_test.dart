import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/repositories/transaction_repository.dart';
import 'package:frontend_notaris/repositories/transaction_cloud_repository.dart';

void main() {
  final domain = Platform.environment['TRANSACTION_DOMAIN'] ?? 'notaris';
  if (!{'notaris', 'ppat'}.contains(domain)) {
    throw StateError('Invalid fixture domain');
  }
  final url = Platform.environment['TRANSACTION_E2E_URL'];
  final token = Platform.environment['TRANSACTION_E2E_TOKEN'];
  if (url == null || token == null) {
    test(
      'transaction cloud requires disposable HTTP opt-in',
      () {},
      skip: true,
    );
    return;
  }
  if (!url.startsWith('http://127.0.0.1:') || url.contains(':8081/')) {
    throw StateError('Disposable HTTP target required');
  }
  test('$domain CRUD SQLite A → real HTTP/PostgreSQL → SQLite B', () async {
    final folder = await Directory.systemTemp.createTemp(
      'transaction_cloud_e2e_',
    );
    addTearDown(() => folder.delete(recursive: true));
    final aFile = File('${folder.path}/a.sqlite'),
        bFile = File('${folder.path}/b.sqlite');
    final a = AppDatabase.forTesting(NativeDatabase(aFile)),
        b = AppDatabase.forTesting(NativeDatabase(bFile));
    addTearDown(a.close);
    addTearDown(b.close);
    const applicant = '00000000-0000-4000-8000-000000000001',
        officer = '00000000-0000-4000-8000-000000000002',
        cloudOfficer = '00000000-0000-4000-8000-000000000003',
        job = '00000000-0000-4000-8000-000000000004',
        price = '00000000-0000-4000-8000-000000000005',
        category = '00000000-0000-4000-8000-000000000006',
        detail = '00000000-0000-4000-8000-000000000007';
    Future<void> seed(AppDatabase db, int offset) async {
      await db.customStatement(
        "INSERT INTO pemohons(id,uuid,nama,is_sync_dirty,last_synced_at) VALUES(?,?,'Applicant',0,1)",
        [offset + 10, applicant],
      );
      await db.customStatement(
        "INSERT INTO petugas(id,uuid,nama,email,is_sync_dirty) VALUES(?,?,'Officer','e2e@example.invalid',0)",
        [offset + 20, officer],
      );
      await db.customStatement(
        "INSERT INTO petugas_identity_map(local_uuid,cloud_uuid,server_id,state,evidence,created_at,updated_at) VALUES(?,?,104,'server_only','authenticated fixture',1,1)",
        [officer, cloudOfficer],
      );
      await db.customStatement(
        "INSERT INTO petugas_sync_feed(id,scope,cursor) VALUES(1,'officer-scope',4)",
      );
      await db.customStatement(
        'INSERT INTO petugas_sync_journal(local_uuid,row_version) VALUES(?,1)',
        [officer],
      );
      await db.customStatement(
        "INSERT INTO pekerjaan_kategori(id,uuid,nama,is_sync_dirty) VALUES(?,?,'Category',0)",
        [offset + 30, category],
      );
      for (final jobDomain in ['notaris', 'ppat']) {
        final jobId = offset + (jobDomain == domain ? 40 : 50);
        await db.customStatement(
          "INSERT INTO pekerjaan_$jobDomain(id,uuid,nama,is_sync_dirty) VALUES(?,?,'Job $jobDomain',0)",
          [jobId, job],
        );
        await db.customStatement(
          "INSERT INTO pekerjaan_${jobDomain}_sync_identity(local_uuid,cloud_uuid,scope,revision) VALUES(?,?,'master-scope',1)",
          [job, job],
        );
        await db.customStatement(
          "INSERT INTO pekerjaan_${jobDomain}_harga(uuid,pekerjaan_${jobDomain}_id,kategori_pekerjaan_id,harga,estimasi_waktu,is_sync_dirty) VALUES(?,?,?,'100','2 hari',0)",
          [price, jobId, offset + 30],
        );
      }
    }

    await seed(a, 0);
    await seed(b, 100);
    final dio = Dio(
      BaseOptions(baseUrl: url, headers: {'Authorization': 'Bearer $token'}),
    );
    TransactionCloudRepository cloud(AppDatabase db) =>
        TransactionCloudRepository(
          db,
          dio,
          scope: 'disposable-deployment-account-device-profile',
          domain: domain,
          petugasScope: 'officer-scope',
          masterScope: 'master-scope',
        );
    final sender = cloud(a), receiver = cloud(b);
    final id = await TransactionRepository(a).save(
      nomorTransaksi: 'OFFLINE-TEMP',
      jenisTransaksi: domain,
      pemohonId: 10,
      pemohonUuid: applicant,
      petugasId: 20,
      petugasUuid: officer,
      status: 'Baru',
      tanggalTransaksi: DateTime.utc(2020, 1, 1),
      jobs: [
        TransactionJobInput(
          jenisPekerjaan: domain,
          namaPekerjaan: 'Historical job',
          pekerjaanNotarisId: domain == 'notaris' ? 40 : null,
          pekerjaanPpatId: domain == 'ppat' ? 40 : null,
          hargaUuid: price,
          kategoriUuid: category,
          detailUuid: detail,
          biayaLayanan: 100,
          kategoriSnapshot: 'Historical category',
          estimasiWaktuSnapshot: '2 hari',
          prosesSnapshot: '[{"id":"manual-process","name":"Periksa","attributes":["KTP","Akta"]}]',
        ),
      ],
      pembayaranSekarang: 25,
    );
    final before = (await TransactionRepository(a).findById(id))!;
    final ack = await sender.pushCreate(id);
    expect(ack['uuid'], before.uuid);
    expect(ack['revision'], 1);
    expect(
      ack['final_number'],
      matches(domain == 'ppat' ? r'^200\d{6}0001$' : r'^100\d{6}0001$'),
    );
    final accepted = (await TransactionRepository(a).findById(id))!;
    expect(accepted.uuid, before.uuid);
    expect(accepted.id, id);
    expect(accepted.noAkta, ack['final_number']);
    expect(accepted.isSyncDirty, false);
    final pending =
        (await a
                .customSelect('SELECT payload FROM transaction_cloud_pending')
                .getSingle())
            .read<String>('payload');
    final replay = await dio.post<Map<String, dynamic>>(
      '/transaksi-$domain/sync/create',
      data: jsonDecode(pending),
    );
    expect(replay.data!['acknowledgement'], ack);
    final altered = jsonDecode(pending) as Map<String, dynamic>;
    (altered['header'] as Map)['note'] = 'changed';
    await expectLater(
      dio.post('/transaksi-$domain/sync/create', data: altered),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          409,
        ),
      ),
    );
    expect(
      (await dio.post<Map<String, dynamic>>(
        '/transaksi-$domain/testing/publish',
      )).data!['published'],
      1,
    );
    expect(
      (await dio.post<Map<String, dynamic>>(
        '/transaksi-$domain/testing/publish',
      )).data!['published'],
      0,
    );
    // Failure after parent insertion must roll back the complete local page.
    await b.customStatement('UPDATE pekerjaan_kategori SET is_sync_dirty=1');
    await expectLater(receiver.pullPage(limit: 1), throwsStateError);
    expect(await b.select(b.transaksis).get(), isEmpty);
    expect(
      (await b
              .customSelect('SELECT cursor FROM transaction_cloud_feed')
              .getSingle())
          .read<int>('cursor'),
      0,
    );
    await b.customStatement('UPDATE pekerjaan_kategori SET is_sync_dirty=0');
    await b.customStatement(
      "INSERT INTO transaksis(uuid,no_akta,total,is_sync_dirty,jenis_transaksi) VALUES(?,'LOCAL-DIRTY',100,1,'$domain')",
      [before.uuid],
    );
    await expectLater(receiver.pullPage(limit: 1), throwsStateError);
    expect((await b.select(b.transaksis).getSingle()).noAkta, 'LOCAL-DIRTY');
    await b.customStatement(
      'DELETE FROM transaksis',
    ); // explicit removal of test-only conflicting draft
    expect(await receiver.pullPage(limit: 1), 1);
    expect(await sender.pullPage(limit: 1), 1);
    final received = await b.select(b.transaksis).getSingle();
    expect(received.uuid, before.uuid);
    expect(received.noAkta, ack['final_number']);
    expect(received.pemohonId, 110);
    expect(received.petugasId, 120);
    expect(received.petugasUuid, officer);
    expect(received.total, 100);
    final receivedDetail = await b.select(b.transaksiDetails).getSingle();
    expect(receivedDetail.uuid, detail);
    expect(receivedDetail.hargaUuid, price);
    expect(receivedDetail.kategoriUuid, category);
    expect(
      domain == 'ppat'
          ? receivedDetail.pekerjaanPpatId
          : receivedDetail.pekerjaanNotarisId,
      140,
    );
    expect(
      domain == 'ppat'
          ? receivedDetail.pekerjaanNotarisId
          : receivedDetail.pekerjaanPpatId,
      isNull,
    );
    expect(receivedDetail.namaPekerjaanSnapshot, 'Historical job');
    expect(
      (jsonDecode(receivedDetail.prosesSnapshot!) as List).single['attributes'],
      ['KTP', 'Akta'],
    );
    final sourceProcess = await a.select(a.transaksiProses).getSingle(),
        targetProcess = await b.select(b.transaksiProses).getSingle();
    expect(targetProcess.uuid, sourceProcess.uuid);
    expect(targetProcess.transaksiDetailUuid, detail);
    final sourcePayment = await a
            .select(a.transaksiRiwayatPembayarans)
            .getSingle(),
        targetPayment = await b
            .select(b.transaksiRiwayatPembayarans)
            .getSingle();
    expect(targetPayment.uuid, sourcePayment.uuid);
    expect(targetPayment.nominal, 25);
    await b.customStatement(
      "UPDATE pekerjaan_$domain SET nama='Master changed'",
    );
    expect(
      (await b.select(b.transaksiDetails).getSingle()).namaPekerjaanSnapshot,
      'Historical job',
    );
    await b.customStatement('UPDATE transaction_cloud_feed SET cursor=0');
    expect(await receiver.pullPage(), 1);
    expect(await receiver.pullPage(), 1);
    expect(await b.select(b.transaksiRiwayatPembayarans).get(), hasLength(1));
    var expectedCursor = 1;
    if (Platform.environment['TRANSACTION_MUTATIONS'] == '1') {
      await TransactionRepository(a).save(
        id: id,
        nomorTransaksi: ack['final_number'] as String,
        jenisTransaksi: domain,
        pemohonId: 10,
        pemohonUuid: applicant,
        petugasId: 20,
        petugasUuid: officer,
        status: 'Baru',
        tanggalTransaksi: DateTime.utc(2020, 1, 1),
        jobs: [
          TransactionJobInput(
            jenisPekerjaan: domain,
            namaPekerjaan: 'Updated historical job',
            pekerjaanNotarisId: domain == 'notaris' ? 40 : null,
            pekerjaanPpatId: domain == 'ppat' ? 40 : null,
            hargaUuid: price,
            kategoriUuid: category,
            detailUuid: detail,
            biayaLayanan: 150,
            kategoriSnapshot: 'Historical category',
            estimasiWaktuSnapshot: '2 hari',
            prosesSnapshot: '[{"id":"manual-process","name":"Periksa updated","attributes":["KTP","Akta","Updated"]}]',
          ),
        ],
      );
      final updated = await sender.pushUpdate(id);
      expect(updated['revision'], 2);
      expect(updated['final_number'], ack['final_number']);
      final updatePayload =
          (await a
                  .customSelect(
                    "SELECT payload FROM transaction_cloud_pending WHERE operation='update'",
                  )
                  .getSingle())
              .read<String>('payload');
      final retry = await dio.post<Map<String, dynamic>>(
        '/transaksi-$domain/sync/update',
        data: jsonDecode(updatePayload),
      );
      expect(retry.data!['acknowledgement'], updated);
      final changed = jsonDecode(updatePayload) as Map<String, dynamic>;
      (changed['header'] as Map)['note'] = 'mutation reuse';
      await expectLater(
        dio.post('/transaksi-$domain/sync/update', data: changed),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            409,
          ),
        ),
      );
      await b.customStatement(
        "UPDATE transaksis SET catatan='Device B dirty',is_sync_dirty=1",
      );
      await expectLater(
        receiver.pushUpdate(received.id),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            409,
          ),
        ),
      );
      final conflict = (await b
          .customSelect(
            "SELECT payload,state FROM transaction_cloud_pending WHERE operation='update'",
          )
          .getSingle());
      expect(conflict.read<String>('state'), 'pending');
      expect((await b.select(b.transaksis).getSingle()).isSyncDirty, true);
      expect(
        (await dio.post<Map<String, dynamic>>(
          '/transaksi-$domain/testing/publish',
        )).data!['published'],
        1,
      );
      await expectLater(receiver.pullPage(limit: 1), throwsStateError);
      expect(
        (await b
                .customSelect('SELECT cursor FROM transaction_cloud_feed')
                .getSingle())
            .read<int>('cursor'),
        1,
      );
      expect(
        (await b
                .customSelect(
                  "SELECT payload FROM transaction_cloud_pending WHERE state='pending'",
                )
                .getSingle())
            .read<String>('payload'),
        conflict.read<String>('payload'),
      );
      // Explicit fixture-only conflict resolution; no automatic rebase or overwrite.
      await b.customStatement('DELETE FROM transaction_cloud_pending');
      await b.customStatement(
        'UPDATE transaksis SET catatan=NULL,is_sync_dirty=0',
      );
      await b.customStatement('UPDATE pekerjaan_kategori SET is_sync_dirty=1');
      await expectLater(receiver.pullPage(limit: 1), throwsStateError);
      expect((await b.select(b.transaksis).getSingle()).total, 100);
      await b.customStatement('UPDATE pekerjaan_kategori SET is_sync_dirty=0');
      expect(await receiver.pullPage(limit: 1), 2);
      expect(await sender.pullPage(limit: 1), 2);
      final updatedHeader = await b.select(b.transaksis).getSingle(),
          updatedDetail = await b.select(b.transaksiDetails).getSingle(),
          updatedProcess = await b.select(b.transaksiProses).getSingle();
      expect(updatedHeader.id, received.id);
      expect(updatedHeader.uuid, before.uuid);
      expect(updatedHeader.noAkta, ack['final_number']);
      expect(updatedHeader.total, 150);
      expect(updatedDetail.id, receivedDetail.id);
      expect(updatedDetail.uuid, detail);
      expect(updatedDetail.namaPekerjaanSnapshot, 'Updated historical job');
      expect(updatedProcess.uuid, sourceProcess.uuid);
      expect(updatedProcess.id, targetProcess.id);
      expect(updatedProcess.namaProsesSnapshot, 'Periksa updated');
      expect(
        (await b.select(b.transaksiRiwayatPembayarans).getSingle()).toJson(),
        targetPayment.toJson(),
      );
      // A local payment edit needs its own contract; aggregate UPDATE cannot erase it.
      await a.customStatement(
        "UPDATE transaksi_riwayat_pembayaran SET keterangan='Unresolved correction',is_sync_dirty=1",
      );
      await expectLater(sender.pushUpdate(id), throwsStateError);
      expect(
        (await a.select(a.transaksiRiwayatPembayarans).getSingle()).isSyncDirty,
        true,
      );
      await a.customStatement(
        'UPDATE transaksi_riwayat_pembayaran SET keterangan=?,is_sync_dirty=0',
        [sourcePayment.keterangan],
      );
      await a.customStatement(
        'UPDATE transaksi_proses SET submitted_by_user_id=777,is_sync_dirty=1',
      );
      await a.customStatement(
        'UPDATE transaksis SET is_sync_dirty=1 WHERE id=?',
        [id],
      );
      await expectLater(sender.pushUpdate(id), throwsStateError);
      expect((await a.select(a.transaksiProses).getSingle()).isSyncDirty, true);
      expect(
        await a
            .customSelect(
              "SELECT * FROM transaction_cloud_pending WHERE state='pending'",
            )
            .get(),
        isEmpty,
      );
      await a.customStatement(
        'UPDATE transaksi_proses SET submitted_by_user_id=NULL,is_sync_dirty=0',
      );
      await a.customStatement(
        'UPDATE transaksis SET is_sync_dirty=0 WHERE id=?',
        [id],
      );
      expect(await TransactionRepository(a).delete(id), true);
      final deleted = await sender.pushDelete(id);
      expect(deleted['revision'], 3);
      expect(deleted['final_number'], ack['final_number']);
      expect(deleted['deleted_at'], isNotNull);
      final deletePayload =
          (await a
                  .customSelect(
                    "SELECT payload FROM transaction_cloud_pending WHERE operation='delete'",
                  )
                  .getSingle())
              .read<String>('payload');
      final deleteRetry = await dio.post<Map<String, dynamic>>(
        '/transaksi-$domain/sync/delete',
        data: jsonDecode(deletePayload),
      );
      expect(deleteRetry.data!['acknowledgement'], deleted);
      expect(
        (await dio.post<Map<String, dynamic>>(
          '/transaksi-$domain/testing/publish',
        )).data!['published'],
        1,
      );
      await b.customStatement('UPDATE transaksis SET is_sync_dirty=1');
      await expectLater(receiver.pullPage(), throwsStateError);
      await b.customStatement('UPDATE transaksis SET is_sync_dirty=0');
      expect(await receiver.pullPage(limit: 1), 3);
      expect(await sender.pullPage(limit: 1), 3);
      expect((await b.select(b.transaksis).getSingle()).deletedAt, isNotNull);
      expect(
        (await b.select(b.transaksis).getSingle()).noAkta,
        ack['final_number'],
      );
      expect((await b.select(b.transaksiDetails).getSingle()).status, 0);
      expect(
        (await b.select(b.transaksiRiwayatPembayarans).getSingle()).toJson(),
        targetPayment.toJson(),
      );
      await b.customStatement('UPDATE transaction_cloud_feed SET cursor=0');
      expect(await receiver.pullPage(limit: 1), 1);
      expect(await receiver.pullPage(limit: 1), 2);
      expect(await receiver.pullPage(limit: 1), 3);
      expect(await receiver.pullPage(limit: 1), 3);
      expectedCursor = 3;
    }
    // Legacy unresolved detail cannot create a new pending request or HTTP mutation.
    final legacyId = await TransactionRepository(a).save(
      nomorTransaksi: 'LEGACY-LOCAL',
      jenisTransaksi: domain,
      pemohonId: 10,
      pemohonUuid: applicant,
      petugasId: 20,
      petugasUuid: officer,
      status: 'Baru',
      tanggalTransaksi: DateTime.utc(2020),
      jobs: [
        TransactionJobInput(
          jenisPekerjaan: domain,
          namaPekerjaan: 'Unresolved',
          pekerjaanNotarisId: domain == 'notaris' ? 40 : null,
          pekerjaanPpatId: domain == 'ppat' ? 40 : null,
          biayaLayanan: 100,
          detailUuid: '00000000-0000-4000-8000-000000000017',
        ),
      ],
    );
    await expectLater(sender.pushCreate(legacyId), throwsStateError);
    expect(
      (await a
              .customSelect(
                'SELECT count(*) AS n FROM transaction_cloud_pending',
              )
              .getSingle())
          .read<int>('n'),
      1,
    );
    var expectedPayments = 1;
    if (domain == 'ppat' &&
        Platform.environment['TRANSACTION_MUTATIONS'] == '1') {
      final collision = Map<String, dynamic>.from(jsonDecode(pending) as Map)
        ..['domain'] = 'notaris'
        ..['mutation_id'] = '00000000-0000-4000-8000-000000009909';
      await expectLater(
        dio.post('/transaksi-notaris/sync/create', data: collision),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            409,
          ),
        ),
      );
      final otherCloud = TransactionCloudRepository(
        a,
        dio,
        domain: 'notaris',
        scope: 'disposable-deployment-account-device-profile',
        petugasScope: 'officer-scope',
        masterScope: 'master-scope',
      );
      final otherId = await TransactionRepository(a).save(
        nomorTransaksi: 'OTHER-DOMAIN-OFFLINE',
        jenisTransaksi: 'notaris',
        pemohonId: 10,
        pemohonUuid: applicant,
        petugasId: 20,
        petugasUuid: officer,
        status: 'Baru',
        tanggalTransaksi: DateTime.utc(2020),
        jobs: [
          const TransactionJobInput(
            jenisPekerjaan: 'notaris',
            namaPekerjaan: 'Notaris isolated',
            pekerjaanNotarisId: 50,
            hargaUuid: price,
            kategoriUuid: category,
            detailUuid: '00000000-0000-4000-8000-000000000027',
            biayaLayanan: 100,
            kategoriSnapshot: 'Historical category',
            prosesSnapshot: '[]',
          ),
        ],
        pembayaranSekarang: 25,
      );
      final otherAck = await otherCloud.pushCreate(otherId);
      expect(otherAck['final_number'], matches(r'^100\d{6}0001$'));
      await expectLater(sender.pushUpdate(otherId), throwsStateError);
      expect(
        (await dio.post<Map<String, dynamic>>(
          '/transaksi-$domain/testing/publish',
        )).data!['published'],
        1,
      );
      expect(await receiver.pullPage(limit: 1), 4);
      expect(await sender.pullPage(limit: 1), 4);
      final combined = await b.select(b.transaksis).get();
      expect(combined, hasLength(2));
      expect(
        combined.singleWhere((t) => t.jenisTransaksi == 'ppat').uuid,
        before.uuid,
      );
      final other = combined.singleWhere((t) => t.jenisTransaksi == 'notaris');
      expect(other.uuid, otherAck['uuid']);
      expect(other.deletedAt, isNull);
      final combinedDetails = await b.select(b.transaksiDetails).get();
      final notarisDetail = combinedDetails.singleWhere(
        (d) => d.jenisPekerjaan == 'notaris',
      );
      expect(notarisDetail.pekerjaanNotarisId, 150);
      expect(notarisDetail.pekerjaanPpatId, isNull);
      final ppatDetail = combinedDetails.singleWhere(
        (d) => d.jenisPekerjaan == 'ppat',
      );
      expect(ppatDetail.pekerjaanPpatId, 140);
      expect(ppatDetail.pekerjaanNotarisId, isNull);
      expectedCursor = 4;
      expectedPayments = 2;
    }
    for (final db in [a, b]) {
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      expect(
        (await db.customSelect('PRAGMA integrity_check').getSingle())
            .read<String>('integrity_check'),
        'ok',
      );
    }
    await a.close();
    await b.close();
    for (final file in [aFile, bFile]) {
      final reopened = AppDatabase.forTesting(NativeDatabase(file));
      expect(await cloud(reopened).pullPage(), expectedCursor);
      expect(
        await reopened.select(reopened.transaksiRiwayatPembayarans).get(),
        hasLength(expectedPayments),
      );
      await reopened.close();
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
