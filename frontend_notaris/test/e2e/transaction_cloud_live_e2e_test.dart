import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/repositories/transaction_repository.dart';
import 'package:frontend_notaris/repositories/transaction_cloud_repository.dart';
import 'package:frontend_notaris/services/transaction_manual_sync_service.dart';
import 'package:frontend_notaris/models/auth_session.dart';
import 'package:frontend_notaris/repositories/sync_log_repository.dart';
import 'package:frontend_notaris/repositories/sync_monitor_repository.dart';

void main() {
  final domain = Platform.environment['TRANSACTION_DOMAIN'] ?? 'notaris';
  final bridge = Platform.environment['TRANSACTION_MANUAL_BRIDGE'] == '1';
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
      bridge ? 'transaction_manual_e2e_' : 'transaction_cloud_e2e_',
    );
    addTearDown(() => folder.delete(recursive: true));
    final aFile = File('${folder.path}/a.sqlite'),
        bFile = File('${folder.path}/b.sqlite');
    final a = AppDatabase.forTesting(NativeDatabase(aFile)),
        b = AppDatabase.forTesting(NativeDatabase(bFile));
    addTearDown(a.close);
    addTearDown(b.close);
    final profiles = <AppDatabase, TransactionManualProfile>{};
    TransactionManualProfile makeProfile(File file) => TransactionManualProfile(
      sqlitePath: file.path,
      baseUrl: url,
      databaseTarget: Platform.environment['TRANSACTION_DISPOSABLE_TARGET']!,
      deployment: Platform.environment['TRANSACTION_DISPOSABLE_DEPLOYMENT']!,
      device: file.path,
      generation: 'manual-bridge-v1',
      accountId: 1,
      groupId: 1,
    );
    if (bridge) {
      profiles[a] = makeProfile(aFile);
      profiles[b] = makeProfile(bFile);
    }
    String officerScope(AppDatabase db) =>
        bridge ? profiles[db]!.petugasScope : 'officer-scope';
    String masterScope(AppDatabase db) =>
        bridge ? profiles[db]!.masterScope : 'master-scope';
    String transactionScope(AppDatabase db) => bridge
        ? profiles[db]!.transactionScope
        : 'disposable-deployment-account-device-profile';
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
        "INSERT INTO petugas_sync_feed(id,scope,cursor) VALUES(1,?,4)",
        [officerScope(db)],
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
          "INSERT INTO pekerjaan_${jobDomain}_sync_identity(local_uuid,cloud_uuid,scope,revision) VALUES(?,?,?,1)",
          [job, job, masterScope(db)],
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
          scope: transactionScope(db),
          domain: domain,
          petugasScope: officerScope(db),
          masterScope: masterScope(db),
        );
    final sender = cloud(a), receiver = cloud(b);
    AuthSession? session;
    if (bridge) {
      final auth =
          (await dio.get<Map<String, dynamic>>('/auth/me/sidebar-access'))
                  .data!['data']
              as Map;
      session = AuthSession(
        token: token,
        userId: auth['user']['id'] as int,
        groupId: auth['user']['group_id'] as int,
        userName: 'Disposable',
        groupName: 'Disposable',
        user: Map<String, dynamic>.from(auth['user'] as Map),
        sidebars: (auth['sidebars'] as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList(),
        verifiedAt: DateTime.now(),
      );
    }
    TransactionManualSyncService manual(AppDatabase db) =>
        TransactionManualSyncService(
          db: db,
          profile: profiles[db]!,
          http: dio,
          session: () => session,
          uiSmoke: () => false,
        );
    Future<Map<String, dynamic>> upload(AppDatabase db, int id) async {
      final header = await (db.select(
        db.transaksis,
      )..where((t) => t.id.equals(id))).getSingle();
      return (await manual(db).run(
        selectedModule: 'transaksi_${header.jenisTransaksi}',
        direction: ManualSyncDirection.upload,
        transactionId: id,
      )).receipt!;
    }

    Future<int> pull(AppDatabase db, {int limit = 100}) async => bridge
        ? (await manual(db).run(
            selectedModule: 'transaksi',
            direction: ManualSyncDirection.download,
            pageSize: limit,
          )).cursor!
        : cloud(db).pullPage(limit: limit);
    Future<Map<String, dynamic>> monitor(AppDatabase db) async =>
        (await SyncMonitorRepository(
          db,
        ).read()).singleWhere((r) => r['module'] == 'transaksi_$domain');
    if (bridge) expect((await monitor(b))['color'], 'neutral');

    if (Platform.environment['TRANSACTION_MIXED_FEED'] == '1') {
      if (!bridge) throw StateError('Mixed feed requires application service');
      var ppatNumber = '', notarisNumber = '';
      Future<int> save(String kind, {int? id}) => TransactionRepository(a).save(
        id: id,
        nomorTransaksi: id == null
            ? 'OFFLINE-$kind'
            : kind == 'ppat'
            ? ppatNumber
            : notarisNumber,
        jenisTransaksi: kind,
        pemohonId: 10,
        pemohonUuid: applicant,
        petugasId: 20,
        petugasUuid: officer,
        status: 'Baru',
        tanggalTransaksi: DateTime.utc(2020),
        pembayaranSekarang: id == null ? 25 : 0,
        jobs: [
          TransactionJobInput(
            jenisPekerjaan: kind,
            namaPekerjaan: '$kind snapshot ${id == null ? 1 : 2}',
            pekerjaanNotarisId: kind == 'notaris' ? 40 : null,
            pekerjaanPpatId: kind == 'ppat' ? 50 : null,
            detailUuid: kind == 'notaris'
                ? detail
                : '00000000-0000-4000-8000-000000000017',
            hargaUuid: price,
            kategoriUuid: category,
            biayaLayanan: id == null ? 100 : 150,
            kategoriSnapshot: 'Historical category',
            estimasiWaktuSnapshot: '2 hari',
            prosesSnapshot: jsonEncode([
              {
                'id': 'synthetic-$kind',
                'name': 'Periksa',
                'attributes': ['KTP', id == null ? 'Initial' : 'Updated'],
              },
            ]),
          ),
        ],
      );
      final ids = <String, int>{}, uuids = <String, String>{};
      final numbers = <String, String>{};
      var seq = 0;
      Future<void> publish(String kind, String operation, int revision) async {
        final result = (await dio.post<Map<String, dynamic>>(
          '/transaksi-notaris/testing/publish',
          data: {
            'domain': kind,
            'uuid': uuids[kind],
            'operation': operation,
            'revision': revision,
            'expected_last_seq': seq,
          },
        )).data!;
        expect(result['published'], 1);
        expect(result['last_seq'], ++seq);
      }

      Future<TransactionManualResult> download(
        AppDatabase db, {
        int size = 100,
        int pages = 1,
      }) => manual(db).run(
        selectedModule: 'transaksi',
        direction: ManualSyncDirection.download,
        pageSize: size,
        maxPages: pages,
      );
      for (final kind in ['ppat', 'notaris']) {
        ids[kind] = await save(kind);
        uuids[kind] = (await TransactionRepository(a).findById(ids[kind]!))!
            .uuid;
      }
      final first = await upload(a, ids['ppat']!);
      numbers['ppat'] = first['final_number'] as String;
      ppatNumber = numbers['ppat']!;
      expect(ppatNumber, matches(r'^200\d{6}0001$'));
      expect(
        (await TransactionRepository(a).findById(ids['notaris']!))!.isSyncDirty,
        true,
      );
      expect(
        await a
            .customSelect(
              "SELECT * FROM transaction_cloud_identity WHERE local_uuid='${uuids['notaris']}'",
            )
            .get(),
        isEmpty,
      );
      await publish('ppat', 'create', 1);
      final second = await upload(a, ids['notaris']!);
      numbers['notaris'] = second['final_number'] as String;
      notarisNumber = numbers['notaris']!;
      expect(notarisNumber, matches(r'^100\d{6}0001$'));
      expect(
        (await TransactionRepository(a).findById(ids['ppat']!))!.isSyncDirty,
        false,
      );
      await publish('notaris', 'create', 1);
      for (final kind in ['ppat', 'notaris']) {
        await save(kind, id: ids[kind]);
        final ack = await upload(a, ids[kind]!);
        expect(ack['revision'], 2);
        expect(ack['final_number'], numbers[kind]);
        await publish(kind, 'update', 2);
      }
      final page = (await dio.get<Map<String, dynamic>>(
        '/transaksi-notaris/sync/pull',
        queryParameters: {'cursor': 0, 'limit': 4},
      )).data!;
      expect((page['changes'] as List).map((e) => e['aggregate']['domain']), [
        'ppat',
        'notaris',
        'ppat',
        'notaris',
      ]);
      // First event is valid PPAT; second needs an intentionally blocked Notaris
      // reference. Every local write from that first event must roll back.
      await b.customStatement('UPDATE pekerjaan_notaris SET is_sync_dirty=1');
      await expectLater(
        download(b, size: 4),
        throwsA(
          isA<ManualTransactionFailure>().having(
            (e) => e.code,
            'code',
            'validation',
          ),
        ),
      );
      expect(await b.select(b.transaksis).get(), isEmpty);
      expect(await b.select(b.transaksiDetails).get(), isEmpty);
      expect(await b.select(b.transaksiRiwayatPembayarans).get(), isEmpty);
      expect(
        await b.customSelect('SELECT * FROM transaction_cloud_identity').get(),
        isEmpty,
      );
      expect(
        (await b
                .customSelect('SELECT cursor FROM transaction_cloud_feed')
                .getSingle())
            .read<int>('cursor'),
        0,
      );
      expect((await SyncLogRepository(b).list(status: 'failed')).length, 1);
      await b.customStatement('UPDATE pekerjaan_notaris SET is_sync_dirty=0');
      final applied = await download(b, size: 4);
      expect(applied.count, 4);
      expect(applied.cursor, 4);
      expect(applied.more, false);
      final processes = <String, String>{}, payments = <String, String>{};
      final received = await b.select(b.transaksis).get();
      expect(received.length, 2);
      for (final kind in ['ppat', 'notaris']) {
        final h = received.singleWhere((t) => t.jenisTransaksi == kind);
        expect(h.uuid, uuids[kind]);
        expect(h.noAkta, numbers[kind]);
        expect(h.total, 150);
        final d = (await b.select(b.transaksiDetails).get()).singleWhere(
          (d) => d.transaksiId == h.id,
        );
        expect(d.hargaUuid, price);
        expect(d.kategoriUuid, category);
        expect(
          kind == 'ppat' ? d.pekerjaanPpatId : d.pekerjaanNotarisId,
          kind == 'ppat' ? 150 : 140,
        );
        expect((jsonDecode(d.prosesSnapshot!) as List).single['attributes'], [
          'KTP',
          'Updated',
        ]);
        final proc = (await b.select(b.transaksiProses).get()).singleWhere(
          (p) => p.transaksiId == h.id,
        );
        final source = (await a.select(a.transaksiProses).get()).singleWhere(
          (p) => p.transaksiId == ids[kind],
        );
        expect(proc.uuid, source.uuid);
        processes[kind] = proc.uuid;
        final payment = (await TransactionRepository(b).getPaymentHistory(h.id))
            .single;
        final sourcePayment = (await TransactionRepository(
          a,
        ).getPaymentHistory(ids[kind]!)).single;
        expect(payment.uuid, sourcePayment.uuid);
        expect(payment.nominal, 25);
        payments[kind] = payment.uuid;
      }
      expect(
        (await SyncMonitorRepository(
          b,
        ).read()).singleWhere((r) => r['module'] == 'transaksi')['color'],
        'green',
      );
      for (final kind in ['ppat', 'notaris']) {
        await TransactionRepository(a).delete(ids[kind]!);
        final ack = await upload(a, ids[kind]!);
        expect(ack['revision'], 3);
        expect(ack['final_number'], numbers[kind]);
        await publish(kind, 'delete', 3);
      }
      final dirty = received.singleWhere((t) => t.jenisTransaksi == 'notaris');
      await b.customStatement(
        "UPDATE transaksis SET catatan='local dirty test',is_sync_dirty=1 WHERE id=?",
        [dirty.id],
      );
      await expectLater(
        download(b, size: 2),
        throwsA(
          isA<ManualTransactionFailure>().having(
            (e) => e.code,
            'code',
            'conflict',
          ),
        ),
      );
      expect(
        (await b
                .customSelect('SELECT cursor FROM transaction_cloud_feed')
                .getSingle())
            .read<int>('cursor'),
        4,
      );
      expect(
        (await b.select(b.transaksis).get()).every((t) => t.deletedAt == null),
        true,
      );
      await expectLater(
        upload(b, dirty.id),
        throwsA(
          isA<ManualTransactionFailure>().having(
            (e) => e.code,
            'code',
            'conflict',
          ),
        ),
      );
      expect(
        (await b
                .customSelect(
                  "SELECT * FROM transaction_cloud_pending WHERE state='pending'",
                )
                .get())
            .length,
        1,
      );
      expect(
        (await TransactionRepository(b).findById(dirty.id))!.catatan,
        'local dirty test',
      );
      // Explicit fixture-only resolution. The application never clears a 409.
      await b.customStatement(
        'DELETE FROM transaction_cloud_pending WHERE local_uuid=?',
        [dirty.uuid],
      );
      await b.customStatement(
        'UPDATE transaksis SET catatan=NULL,is_sync_dirty=0 WHERE id=?',
        [dirty.id],
      );
      expect((await download(b, size: 2)).cursor, 6);
      expect((await download(a)).cursor, 6);
      expect(
        (await b.select(b.transaksis).get()).every((t) => t.deletedAt != null),
        true,
      );
      final noOp = await manual(b).run(
        selectedModule: 'transaksi_notaris',
        direction: ManualSyncDirection.upload,
        transactionId: dirty.id,
      );
      expect(noOp.count, 0);
      expect((await SyncLogRepository(b).list(status: 'failed')).length, 3);
      await b.customStatement('UPDATE transaction_cloud_feed SET cursor=0');
      final replay = await download(b, size: 2, pages: 3);
      expect(replay.count, 6);
      expect(replay.cursor, 6);
      for (final device in [a, b]) {
        expect((await device.select(device.transaksis).get()).length, 2);
        expect(
          (await device.select(device.transaksiRiwayatPembayarans).get())
              .length,
          2,
        );
        expect(
          await device.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        expect(
          (await device.customSelect('PRAGMA integrity_check').getSingle())
              .read<String>('integrity_check'),
          'ok',
        );
      }
      await a.close();
      await b.close();
      for (final file in [aFile, bFile]) {
        final restarted = AppDatabase.forTesting(NativeDatabase(file));
        profiles[restarted] = makeProfile(file);
        expect((await download(restarted)).cursor, 6);
        expect(
          (await restarted.select(restarted.transaksiRiwayatPembayarans).get())
              .map((p) => p.uuid)
              .toSet(),
          payments.values.toSet(),
        );
        expect(
          (await restarted.select(restarted.transaksiProses).get())
              .map((p) => p.uuid)
              .toSet(),
          processes.values.toSet(),
        );
        expect((await SyncLogRepository(restarted).list()).isNotEmpty, true);
        await restarted.close();
      }
      return;
    }

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
    final ack = bridge ? await upload(a, id) : await sender.pushCreate(id);
    if (bridge) {
      expect((await monitor(a))['color'], 'yellow');
      final noOp = await manual(a).run(
        selectedModule: 'transaksi_$domain',
        direction: ManualSyncDirection.upload,
        transactionId: id,
      );
      expect(noOp.count, 0);
    }
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
        data: {
          'domain': domain,
          'uuid': before.uuid,
          'operation': 'create',
          'revision': 1,
          'expected_last_seq': 0,
        },
      )).data!['published'],
      1,
    );
    expect(
      (await dio.post<Map<String, dynamic>>(
        '/transaksi-$domain/testing/publish',
        data: {
          'domain': domain,
          'uuid': before.uuid,
          'operation': 'create',
          'revision': 1,
          'expected_last_seq': 0,
        },
      )).data!['published'],
      0,
    );
    // Failure after parent insertion must roll back the complete local page.
    await b.customStatement('UPDATE pekerjaan_kategori SET is_sync_dirty=1');
    await expectLater(
      pull(b, limit: 1),
      bridge ? throwsA(isA<ManualTransactionFailure>()) : throwsStateError,
    );
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
    await expectLater(
      pull(b, limit: 1),
      bridge ? throwsA(isA<ManualTransactionFailure>()) : throwsStateError,
    );
    expect((await b.select(b.transaksis).getSingle()).noAkta, 'LOCAL-DIRTY');
    await b.customStatement(
      'DELETE FROM transaksis',
    ); // explicit removal of test-only conflicting draft
    expect(await pull(b, limit: 1), 1);
    expect(await pull(a, limit: 1), 1);
    if (bridge) expect((await monitor(b))['color'], 'green');
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
    expect(await pull(b), 1);
    expect(await pull(b), 1);
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
      final updated = bridge
          ? await upload(a, id)
          : await sender.pushUpdate(id);
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
        bridge ? upload(b, received.id) : receiver.pushUpdate(received.id),
        throwsA(
          bridge
              ? isA<ManualTransactionFailure>().having(
                  (e) => e.code,
                  'code',
                  'conflict',
                )
              : isA<DioException>().having(
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
      if (bridge) {
        expect((await monitor(b))['color'], 'red');
        expect(
          (await SyncLogRepository(b).list(status: 'failed')).isNotEmpty,
          true,
        );
      }
      expect((await b.select(b.transaksis).getSingle()).isSyncDirty, true);
      expect(
        (await dio.post<Map<String, dynamic>>(
          '/transaksi-$domain/testing/publish',
          data: {
            'domain': domain,
            'uuid': before.uuid,
            'operation': 'update',
            'revision': 2,
            'expected_last_seq': 1,
          },
        )).data!['published'],
        1,
      );
      await expectLater(
        pull(b, limit: 1),
        bridge ? throwsA(isA<ManualTransactionFailure>()) : throwsStateError,
      );
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
      await expectLater(
        pull(b, limit: 1),
        bridge ? throwsA(isA<ManualTransactionFailure>()) : throwsStateError,
      );
      expect((await b.select(b.transaksis).getSingle()).total, 100);
      await b.customStatement('UPDATE pekerjaan_kategori SET is_sync_dirty=0');
      expect(await pull(b, limit: 1), 2);
      expect(await pull(a, limit: 1), 2);
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
      final deleted = bridge
          ? await upload(a, id)
          : await sender.pushDelete(id);
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
          data: {
            'domain': domain,
            'uuid': before.uuid,
            'operation': 'delete',
            'revision': 3,
            'expected_last_seq': 2,
          },
        )).data!['published'],
        1,
      );
      await b.customStatement('UPDATE transaksis SET is_sync_dirty=1');
      await expectLater(
        pull(b),
        bridge ? throwsA(isA<ManualTransactionFailure>()) : throwsStateError,
      );
      await b.customStatement('UPDATE transaksis SET is_sync_dirty=0');
      expect(await pull(b, limit: 1), 3);
      expect(await pull(a, limit: 1), 3);
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
      expect(await pull(b, limit: 1), 1);
      expect(await pull(b, limit: 1), 2);
      expect(await pull(b, limit: 1), 3);
      expect(await pull(b, limit: 1), 3);
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
      bridge ? 0 : 1,
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
        scope: transactionScope(a),
        petugasScope: officerScope(a),
        masterScope: masterScope(a),
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
          data: {
            'domain': 'notaris',
            'uuid': otherAck['uuid'],
            'operation': 'create',
            'revision': 1,
            'expected_last_seq': 3,
          },
        )).data!['published'],
        1,
      );
      expect(await pull(b, limit: 1), 4);
      expect(await pull(a, limit: 1), 4);
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
      if (bridge) profiles[reopened] = makeProfile(file);
      expect(await pull(reopened), expectedCursor);
      if (bridge) expect(await SyncLogRepository(reopened).list(), isNotEmpty);
      expect(
        await reopened.select(reopened.transaksiRiwayatPembayarans).get(),
        hasLength(expectedPayments),
      );
      await reopened.close();
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
