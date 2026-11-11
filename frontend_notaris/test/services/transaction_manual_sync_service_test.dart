import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/models/auth_session.dart';
import 'package:frontend_notaris/services/transaction_manual_sync_service.dart';
import 'package:frontend_notaris/repositories/transaction_repository.dart';
import 'package:frontend_notaris/repositories/transaction_cloud_repository.dart';
import 'package:frontend_notaris/repositories/sync_log_repository.dart';
import 'package:frontend_notaris/repositories/sync_monitor_repository.dart';

class Transport implements HttpClientAdapter {
  int calls = 0;
  Future<ResponseBody> Function(RequestOptions)? respond;
  Map<String, dynamic>? aggregate;
  static ResponseBody json(Object body, int status) => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    calls++;
    if (respond != null) return respond!(o);
    if (o.method == 'GET') {
      return json({'changes': [], 'next_cursor': 0, 'has_more': false}, 200);
    }
    final body = Map<String, dynamic>.from(o.data as Map);
    final number = body['domain'] == 'ppat' ? '2000611260001' : '1000611260001';
    aggregate = {...body, 'final_number': number};
    return json({
      'acknowledgement': {
        'uuid': body['uuid'],
        'mutation_id': body['mutation_id'],
        'revision': (body['expected_revision'] as int) + 1,
        'final_number': number,
      },
    }, 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Directory folder;
  late AppDatabase db;
  late TransactionManualProfile profile;
  late Transport transport;
  late Dio http;
  late AuthSession? session;
  late bool smoke;
  late int id;
  const applicant = '00000000-0000-4000-8000-000000000001',
      officer = '00000000-0000-4000-8000-000000000002',
      cloudOfficer = '00000000-0000-4000-8000-000000000003',
      job = '00000000-0000-4000-8000-000000000004',
      price = '00000000-0000-4000-8000-000000000005',
      category = '00000000-0000-4000-8000-000000000006';
  AuthSession auth({bool permission = true, int user = 1}) => AuthSession(
    token: 'test-secret-JWT',
    userId: user,
    groupId: 1,
    userName: 'Test',
    groupName: 'Test',
    user: const {},
    sidebars: [
      {
        'sidebar': {'sidebar_kode': 'transaksi', 'status': 1},
        'read': permission ? 1 : 0,
        'create': permission ? 1 : 0,
        'update': permission ? 1 : 0,
        'delete': permission ? 1 : 0,
      },
    ],
    verifiedAt: DateTime.now(),
  );
  TransactionManualSyncService service({TransactionManualProfile? target}) =>
      TransactionManualSyncService(
        db: db,
        profile: target ?? profile,
        http: http,
        session: () => session,
        uiSmoke: () => smoke,
      );
  Future<TransactionManualResult> run(
    ManualSyncDirection d, {
    int? selectedId,
    String? module,
  }) => service().run(
    selectedModule:
        module ??
        (d == ManualSyncDirection.download ? 'transaksi' : 'transaksi_notaris'),
    direction: d,
    transactionId: selectedId,
  );
  Future<Map<String, dynamic>> monitor() async => (await SyncMonitorRepository(
    db,
  ).read()).singleWhere((r) => r['module'] == 'transaksi_notaris');
  setUp(() async {
    folder = await Directory.systemTemp.createTemp('transaction_manual_unit_');
    db = AppDatabase.forTesting(
      NativeDatabase(File('${folder.path}/a.sqlite')),
    );
    await db.customSelect('SELECT 1').get();
    profile = TransactionManualProfile(
      sqlitePath: '${folder.path}/a.sqlite',
      baseUrl: 'http://127.0.0.1:18081/api/v1',
      databaseTarget: '127.0.0.1:55452/notaris_publish_test_manual',
      deployment: 'test-deployment',
      device: 'a',
      generation: 'test-generation',
      accountId: 1,
      groupId: 1,
    );
    transport = Transport();
    http = Dio(BaseOptions(baseUrl: profile.baseUrl))
      ..httpClientAdapter = transport;
    session = auth();
    smoke = false;
    await db.customStatement(
      "INSERT INTO pemohons(id,uuid,nama,is_sync_dirty,last_synced_at) VALUES(10,?,'A',0,1)",
      [applicant],
    );
    await db.customStatement(
      "INSERT INTO petugas(id,uuid,nama,email,is_sync_dirty) VALUES(20,?,'O','synthetic@example.invalid',0)",
      [officer],
    );
    await db.customStatement(
      "INSERT INTO petugas_identity_map(local_uuid,cloud_uuid,server_id,state,evidence,created_at,updated_at) VALUES(?,?,104,'server_only','authenticated fixture',1,1)",
      [officer, cloudOfficer],
    );
    await db.customStatement(
      'INSERT INTO petugas_sync_feed(id,scope,cursor) VALUES(1,?,4)',
      [profile.petugasScope],
    );
    await db.customStatement(
      'INSERT INTO petugas_sync_journal(local_uuid,row_version) VALUES(?,1)',
      [officer],
    );
    await db.customStatement(
      "INSERT INTO pekerjaan_kategori(id,uuid,nama,is_sync_dirty) VALUES(30,?,'C',0)",
      [category],
    );
    await db.customStatement(
      "INSERT INTO pekerjaan_notaris(id,uuid,nama,is_sync_dirty) VALUES(40,?,'J',0)",
      [job],
    );
    await db.customStatement(
      'INSERT INTO pekerjaan_notaris_sync_identity(local_uuid,cloud_uuid,scope,revision) VALUES(?,?,?,1)',
      [job, job, profile.masterScope],
    );
    await db.customStatement(
      "INSERT INTO pekerjaan_notaris_harga(uuid,pekerjaan_notaris_id,kategori_pekerjaan_id,harga,estimasi_waktu,is_sync_dirty) VALUES(?,40,30,'100','2 hari',0)",
      [price],
    );
    id = await TransactionRepository(db).save(
      nomorTransaksi: 'OFFLINE',
      jenisTransaksi: 'notaris',
      pemohonId: 10,
      pemohonUuid: applicant,
      petugasId: 20,
      petugasUuid: officer,
      status: 'Baru',
      tanggalTransaksi: DateTime.utc(2020),
      pembayaranSekarang: 25,
      jobs: [
        const TransactionJobInput(
          jenisPekerjaan: 'notaris',
          namaPekerjaan: 'Snapshot',
          detailUuid: '00000000-0000-4000-8000-000000000007',
          pekerjaanNotarisId: 40,
          hargaUuid: price,
          kategoriUuid: category,
          biayaLayanan: 100,
        ),
      ],
    );
  });
  tearDown(() async {
    http.close();
    await db.close();
    await folder.delete(recursive: true);
  });
  Matcher failure(String code) => throwsA(
    isA<ManualTransactionFailure>().having((e) => e.code, 'code', code),
  );
  test(
    'Check is read-only and eligibility is revalidated before dispatch',
    () async {
      final header = await (db.select(
        db.transaksis,
      )..where((r) => r.id.equals(id))).getSingle();
      final before = await db
          .customSelect('SELECT total_changes() AS n')
          .getSingle();
      expect(
        await service().checkUploadEligibility(
          selectedModule: 'transaksi_notaris',
          transactionId: id,
          uuid: header.uuid,
        ),
        isEmpty,
      );
      final after = await db
          .customSelect('SELECT total_changes() AS n')
          .getSingle();
      expect(after.read<int>('n'), before.read<int>('n'));
      expect(transport.calls, 0);
      expect(await SyncLogRepository(db).list(), isEmpty);
      await db.customStatement(
        'UPDATE transaksi_details SET harga_uuid=NULL WHERE transaksi_id=?',
        [id],
      );
      final blocked = await service().checkUploadEligibility(
        selectedModule: 'transaksi_notaris',
        transactionId: id,
        uuid: header.uuid,
      );
      expect(blocked.join(), contains('Provenance harga/kategori'));
      await expectLater(
        run(ManualSyncDirection.upload, selectedId: id),
        throwsA(isA<ManualTransactionFailure>()),
      );
      expect(transport.calls, 0);
      expect(
        (await db
                .customSelect(
                  'SELECT count(*) AS n FROM transaction_cloud_pending',
                )
                .getSingle())
            .read<int>('n'),
        0,
      );
      expect(
        (await (db.select(
          db.transaksis,
        )..where((r) => r.id.equals(id))).getSingle()).isSyncDirty,
        true,
      );
    },
  );

  test('Check blocks unresolved actor provenance without changing identity or cursor', () async {
    final header = await (db.select(
      db.transaksis,
    )..where((r) => r.id.equals(id))).getSingle();
    await db.customStatement(
      "INSERT INTO transaksi_proses(uuid,transaksi_id,transaksi_detail_uuid,nama_proses_snapshot,submitted_by_user_id) VALUES('00000000-0000-4000-8000-000000000099',?,'00000000-0000-4000-8000-000000000007','Audit fixture',123)",
      [id],
    );
    final issues = await service().checkUploadEligibility(
      selectedModule: 'transaksi_notaris',
      transactionId: id,
      uuid: header.uuid,
    );
    expect(issues.join(), contains('provenance actor cloud'));
    expect(transport.calls, 0);
    expect(await SyncLogRepository(db).list(), isEmpty);
  });

  test('one selected upload durable ack and count; repeat no-op; publication not assumed healthy', () async {
    final first = await run(ManualSyncDirection.upload, selectedId: id);
    expect(first.count, 1);
    expect(first.receipt!['revision'], 1);
    expect(transport.calls, 1);
    final again = await run(ManualSyncDirection.upload, selectedId: id);
    expect(again.count, 0);
    expect(transport.calls, 1);
    final rows = await SyncLogRepository(db).list();
    expect(rows.map((r) => r['record_count']), [0, 1]);
    expect(rows.every((r) => r['status'] == 'success'), true);
    expect((await monitor())['color'], 'yellow');
    expect((await monitor())['progress'].toString(), contains('publication'));
  });
  test('scope account and permission failures do not dispatch; smoke blocks both directions', () async {
    session = auth(permission: false);
    await expectLater(
      run(ManualSyncDirection.upload, selectedId: id),
      failure('forbidden'),
    );
    session = auth(user: 2);
    await expectLater(run(ManualSyncDirection.download), failure('scope'));
    session = auth();
    smoke = true;
    for (final d in ManualSyncDirection.values) {
      await expectLater(
        run(d, selectedId: d == ManualSyncDirection.upload ? id : null),
        failure('forbidden'),
      );
    }
    smoke = false;
    await expectLater(
      run(ManualSyncDirection.upload, selectedId: id, module: 'pemohon'),
      failure('validation'),
    );
    expect(transport.calls, 0);
    expect(
      await db.customSelect('SELECT * FROM transaction_cloud_pending').get(),
      isEmpty,
    );
  });
  test('profile DB file/device generation mismatch fails before network or attempt insertion', () async {
    final wrong = TransactionManualProfile(
      sqlitePath: profile.sqlitePath,
      baseUrl: profile.baseUrl,
      databaseTarget: profile.databaseTarget,
      deployment: profile.deployment,
      device: 'other',
      generation: profile.generation,
      accountId: 1,
      groupId: 1,
    );
    await expectLater(
      service(target: wrong).run(
        selectedModule: 'transaksi',
        direction: ManualSyncDirection.download,
      ),
      failure('scope'),
    );
    expect(await SyncLogRepository(db).list(), isEmpty);
    expect(transport.calls, 0);
  });
  test(
    'unresolved dependency never sends and leaves local dirty unchanged',
    () async {
      await db.customStatement('UPDATE pekerjaan_kategori SET is_sync_dirty=1');
      await expectLater(
        run(ManualSyncDirection.upload, selectedId: id),
        failure('validation'),
      );
      expect(transport.calls, 0);
      expect((await db.select(db.transaksis).getSingle()).isSyncDirty, true);
    },
  );
  test('timeout persists pending request; retry same mutation succeeds without losing failed attempt', () async {
    String? sent;
    transport.respond = (o) async {
      sent = jsonEncode(o.data);
      throw DioException(
        requestOptions: o,
        type: DioExceptionType.receiveTimeout,
        error: 'private password payload JWT',
      );
    };
    await expectLater(
      run(ManualSyncDirection.upload, selectedId: id),
      failure('timeout'),
    );
    final pending =
        (await db
                .customSelect('SELECT payload FROM transaction_cloud_pending')
                .getSingle())
            .read<String>('payload');
    expect(jsonDecode(pending), jsonDecode(sent!));
    expect((await monitor())['color'], 'yellow');
    transport.respond = null;
    await run(ManualSyncDirection.upload, selectedId: id);
    final rows = await SyncLogRepository(db).list();
    expect(rows.map((r) => r['status']), ['success', 'pending']);
    expect(rows[0]['operation_id'], rows[1]['operation_id']);
    expect(jsonEncode(rows), isNot(contains('private password')));
    expect(jsonEncode(rows), isNot(contains('test-secret-JWT')));
  });
  test('409 leaves pending immutable and dirty, red monitor; restart preserves history', () async {
    transport.respond = (_) async =>
        Transport.json({'error': 'secret JWT payload'}, 409);
    await expectLater(
      run(ManualSyncDirection.upload, selectedId: id),
      failure('conflict'),
    );
    final pending =
        (await db
                .customSelect('SELECT payload FROM transaction_cloud_pending')
                .getSingle())
            .read<String>('payload');
    await expectLater(
      run(ManualSyncDirection.upload, selectedId: id),
      failure('conflict'),
    );
    expect(
      (await db
              .customSelect('SELECT payload FROM transaction_cloud_pending')
              .getSingle())
          .read<String>('payload'),
      pending,
    );
    expect((await db.select(db.transaksis).getSingle()).isSyncDirty, true);
    expect((await monitor())['color'], 'red');
    await db.close();
    db = AppDatabase.forTesting(NativeDatabase(File(profile.sqlitePath)));
    expect((await SyncLogRepository(db).list(status: 'failed')).length, 2);
    expect((await monitor())['color'], 'red');
  });
  test('410 requires explicit recovery; cursor data and journal retained, no implicit reset/retry', () async {
    await db.customStatement(
      'INSERT INTO transaction_cloud_feed(scope,cursor) VALUES(?,7)',
      [profile.transactionScope],
    );
    transport.respond = (_) async =>
        Transport.json({'error': 'full_resync_required secret'}, 410);
    await expectLater(
      run(ManualSyncDirection.download),
      failure('feed_expired'),
    );
    expect(transport.calls, 1);
    transport.respond = null;
    await expectLater(
      run(ManualSyncDirection.upload, selectedId: id),
      failure('feed_expired'),
    );
    await expectLater(
      run(ManualSyncDirection.upload, selectedId: id, module: 'transaksi_ppat'),
      failure('feed_expired'),
    );
    expect(transport.calls, 1);
    expect(
      (await db
              .customSelect('SELECT cursor FROM transaction_cloud_feed')
              .getSingle())
          .read<int>('cursor'),
      7,
    );
    expect((await db.select(db.transaksis).get()).length, 1);
    expect((await monitor())['color'], 'red');
  });
  test('unknown feed domain blocks whole page and cursor', () async {
    transport.respond = (_) async => Transport.json({
      'changes': [
        {
          'sequence': 1,
          'aggregate': {'domain': 'unknown'},
        },
      ],
      'next_cursor': 1,
      'has_more': false,
    }, 200);
    await expectLater(
      run(ManualSyncDirection.download),
      failure('unsupported_domain'),
    );
    expect(
      (await db
              .customSelect('SELECT cursor FROM transaction_cloud_feed')
              .getSingle())
          .read<int>('cursor'),
      0,
    );
    expect(
      await db.customSelect('SELECT * FROM transaction_cloud_identity').get(),
      isEmpty,
    );
  });
  test('single flight is shared across service instances; pending progress observable', () async {
    final waiting = Completer<void>();
    transport.respond = (_) async {
      await waiting.future;
      return Transport.json({
        'changes': [],
        'next_cursor': 0,
        'has_more': false,
      }, 200);
    };
    final first = run(ManualSyncDirection.download);
    while (transport.calls == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    final status = await monitor();
    expect(status['pending_operations'], 1);
    expect(status['progress'].toString(), isNot(contains('%')));
    await expectLater(
      service().run(
        selectedModule: 'transaksi',
        direction: ManualSyncDirection.download,
      ),
      failure('busy'),
    );
    waiting.complete();
    await first;
    expect(transport.calls, 1);
    expect((await SyncLogRepository(db).list()).length, 1);
  });
  test('bounded pull persists actual count and cursor, then explicit next page clears pending status', () async {
    await run(ManualSyncDirection.upload, selectedId: id);
    transport.respond = (_) async => Transport.json({
      'changes': [
        {
          'sequence': 1,
          'operation': 'create',
          'revision': 1,
          'aggregate': transport.aggregate,
        },
      ],
      'next_cursor': 1,
      'has_more': true,
    }, 200);
    final limited = await service().run(
      selectedModule: 'transaksi',
      direction: ManualSyncDirection.download,
      pageSize: 1,
      maxPages: 1,
    );
    expect(limited.more, true);
    expect(limited.count, 1);
    expect(limited.cursor, 1);
    var entries = await SyncLogRepository(db).list();
    expect(entries.first['status'], 'pending');
    expect(entries.first['record_count'], 1);
    expect(entries.first['error_code'], 'bounded');
    expect((await monitor())['color'], 'yellow');
    transport.respond = (_) async => Transport.json({
      'changes': [],
      'next_cursor': 1,
      'has_more': false,
    }, 200);
    final done = await run(ManualSyncDirection.download);
    expect(done.count, 0);
    expect(done.cursor, 1);
    expect((await monitor())['color'], 'green');
    entries = await SyncLogRepository(db).list();
    expect(entries.map((r) => r['status']), ['success', 'pending', 'success']);
  });
  test('unknown second event rolls back the full page', () async {
    await run(ManualSyncDirection.upload, selectedId: id);
    transport.respond = (_) async => Transport.json({
      'changes': [
        {
          'sequence': 1,
          'operation': 'create',
          'revision': 1,
          'aggregate': transport.aggregate,
        },
        {
          'sequence': 2,
          'operation': 'create',
          'revision': 1,
          'aggregate': {'domain': 'unknown'},
        },
      ],
      'next_cursor': 2,
      'has_more': false,
    }, 200);
    await expectLater(
      run(ManualSyncDirection.download),
      failure('unsupported_domain'),
    );
    expect(
      (await db
              .customSelect('SELECT cursor FROM transaction_cloud_feed')
              .getSingle())
          .read<int>('cursor'),
      0,
    );
    expect((await db.select(db.transaksis).get()).length, 1);
  });
  group('historical Master references', () {
    late Map<String, dynamic> historical;
    late Map<String, dynamic> create;

    void serve(List<Map<String, dynamic>> changes) {
      transport.respond = (_) async => Transport.json({
        'changes': changes,
        'next_cursor': changes.isEmpty ? 0 : changes.last['sequence'],
        'has_more': false,
      }, 200);
    }

    setUp(() async {
      await run(ManualSyncDirection.upload, selectedId: id);
      historical =
          jsonDecode(jsonEncode(transport.aggregate)) as Map<String, dynamic>;
      historical['uuid'] = '00000000-0000-4000-8000-000000000091';
      historical['mutation_id'] = '00000000-0000-4000-8000-000000000092';
      historical['final_number'] = '1000611260002';
      historical['details'][0]['uuid'] = '00000000-0000-4000-8000-000000000093';
      historical['payments'][0]['uuid'] =
          '00000000-0000-4000-8000-000000000094';
      create = {
        'sequence': 1,
        'operation': 'create',
        'revision': 1,
        'aggregate': historical,
      };
      await db.customStatement(
        'UPDATE pekerjaan_notaris SET status=0,deleted_at=1',
      );
      await db.customStatement(
        'UPDATE pekerjaan_notaris_sync_identity SET revision=2',
      );
      await db.customStatement(
        'INSERT INTO pekerjaan_notaris_sync_feed(scope,cursor) VALUES(?,2)',
        [profile.masterScope],
      );
    });

    test('replays the snapshot without reactivating the Master', () async {
      historical['header']['status'] = 'Selesai';
      serve([create]);
      final result = await run(ManualSyncDirection.download);
      expect(result.cursor, 1);
      expect(result.count, 1);
      final detail = (await db.select(db.transaksiDetails).get()).singleWhere(
        (row) => row.uuid == historical['details'][0]['uuid'],
      );
      expect(detail.pekerjaanNotarisId, 40);
      expect(detail.hargaUuid, price);
      expect(detail.kategoriUuid, category);
      expect(detail.namaPekerjaanSnapshot, 'Snapshot');
      final master = await db.select(db.pekerjaanNotarisLocals).getSingle();
      expect(master.status, 0);
      expect(master.deletedAt, isNotNull);
      final row = (await db.select(db.transaksis).get()).singleWhere(
        (row) => row.uuid == historical['uuid'],
      );
      expect(row.statusTransaksi, 'Selesai');
      expect(row.judulAkta, isNull);
    });

    test('newer feed revision cannot overwrite local deed data', () async {
      serve([create]);
      await run(ManualSyncDirection.download);
      // Exercise the deed guard independently of the dirty-state guard.
      await db.customStatement(
        "UPDATE transaksis SET judul_akta='Fidusia',nomor_akta='25211' WHERE uuid=?",
        [historical['uuid']],
      );
      final newer = {
        ...historical,
        'mutation_id': '00000000-0000-4000-8000-000000000099',
        'expected_revision': 1,
      };
      serve([
        {
          'sequence': 2,
          'operation': 'update',
          'revision': 2,
          'aggregate': newer,
        },
      ]);
      await expectLater(
        run(ManualSyncDirection.download),
        failure('validation'),
      );
      final local = (await db.select(db.transaksis).get()).singleWhere(
        (row) => row.uuid == historical['uuid'],
      );
      expect(local.nomorAkta, '25211');
      expect(
        (await db
                .customSelect('SELECT cursor FROM transaction_cloud_feed')
                .getSingle())
            .read<int>('cursor'),
        1,
      );
    });

    for (final entry in {
      'unknown Master': 'DELETE FROM pekerjaan_notaris_sync_identity',
      'scope mismatch':
          "UPDATE pekerjaan_notaris_sync_identity SET scope='other'",
      'missing publication evidence':
          'UPDATE pekerjaan_notaris_sync_feed SET cursor=1',
      'local delete ACK': "INSERT INTO pekerjaan_notaris_sync_pending(local_uuid,mutation_id,payload,state) SELECT uuid,'ack','{}','acked' FROM pekerjaan_notaris",
    }.entries) {
      test('rejects ${entry.key} without advancing the cursor', () async {
        await db.customStatement(entry.value);
        serve([create]);
        await expectLater(
          run(ManualSyncDirection.download),
          failure('validation'),
        );
        expect(
          (await db
                  .customSelect('SELECT cursor FROM transaction_cloud_feed')
                  .getSingle())
              .read<int>('cursor'),
          0,
        );
        expect((await db.select(db.transaksis).getSingle()).id, id);
      });
    }

    test(
      'dirty second event rolls back the preceding historical CREATE',
      () async {
        await db.customStatement(
          "UPDATE transaksis SET is_sync_dirty=1,catatan='local edit'",
        );
        final update = {...transport.aggregate!, 'expected_revision': 1};
        serve([
          create,
          {
            'sequence': 2,
            'operation': 'update',
            'revision': 2,
            'aggregate': update,
          },
        ]);
        await expectLater(
          run(ManualSyncDirection.download),
          failure('conflict'),
        );
        expect(
          (await db
                  .customSelect('SELECT cursor FROM transaction_cloud_feed')
                  .getSingle())
              .read<int>('cursor'),
          0,
        );
        final local = await db.select(db.transaksis).getSingle();
        expect(local.isSyncDirty, isTrue);
        expect(local.catatan, 'local edit');
      },
    );
  });
  test('unselected dirty PPAT is not uploaded or marked clean', () async {
    await db.customStatement(
      "INSERT INTO transaksis(uuid,no_akta,total,jenis_transaksi) VALUES('00000000-0000-4000-8000-000000000099','PPAT-OFFLINE',100,'ppat')",
    );
    await run(ManualSyncDirection.upload, selectedId: id);
    expect(transport.calls, 1);
    expect(transport.aggregate!['domain'], 'notaris');
    final other = (await db.select(db.transaksis).get()).singleWhere(
      (t) => t.jenisTransaksi == 'ppat',
    );
    expect(other.isSyncDirty, true);
    expect(other.noAkta, 'PPAT-OFFLINE');
    expect((await monitor())['pending_records'], 0);
    await expectLater(
      run(ManualSyncDirection.upload, selectedId: other.id),
      failure('unsupported_domain'),
    );
    expect(transport.calls, 1);
  });
  test(
    'dirty child tombstone cannot disappear behind a clean parent/no-op',
    () async {
      await run(ManualSyncDirection.upload, selectedId: id);
      await db.customStatement(
        'UPDATE transaksi_details SET is_sync_dirty=1,deleted_at=1',
      );
      await expectLater(
        run(ManualSyncDirection.upload, selectedId: id),
        failure('validation'),
      );
      expect(transport.calls, 1);
      final child = await db.select(db.transaksiDetails).getSingle();
      expect(child.isSyncDirty, true);
      expect(child.deletedAt, isNotNull);
      expect((await monitor())['pending_records'], 1);
    },
  );
  test(
    'offline cached session records pending without any HTTP dispatch',
    () async {
      session = auth().asOffline();
      await expectLater(run(ManualSyncDirection.download), failure('offline'));
      expect(transport.calls, 0);
      expect((await SyncLogRepository(db).list()).single['status'], 'pending');
      expect((await monitor())['color'], 'yellow');
    },
  );
  test('empty pull after upload does not prove publication; matching event/cursor atomically retires only ACKED request', () async {
    await run(ManualSyncDirection.upload, selectedId: id);
    await run(ManualSyncDirection.download);
    expect((await monitor())['color'], 'yellow');
    expect(
      (await db
              .customSelect(
                "SELECT * FROM transaction_cloud_pending WHERE state='acked'",
              )
              .get())
          .length,
      1,
    );
    transport.respond = (_) async => Transport.json({
      'changes': [
        {
          'sequence': 1,
          'operation': 'create',
          'revision': 1,
          'aggregate': transport.aggregate,
        },
      ],
      'next_cursor': 999,
      'has_more': false,
    }, 200);
    await expectLater(run(ManualSyncDirection.download), failure('validation'));
    expect(
      (await db
              .customSelect('SELECT cursor FROM transaction_cloud_feed')
              .getSingle())
          .read<int>('cursor'),
      0,
    );
    expect(
      (await db
              .customSelect(
                "SELECT * FROM transaction_cloud_pending WHERE state='acked'",
              )
              .get())
          .length,
      1,
    );
    transport.respond = (_) async => Transport.json({
      'changes': [
        {
          'sequence': 1,
          'operation': 'create',
          'revision': 1,
          'aggregate': transport.aggregate,
        },
      ],
      'next_cursor': 1,
      'has_more': false,
    }, 200);
    await run(ManualSyncDirection.download);
    expect(
      await db.customSelect('SELECT * FROM transaction_cloud_pending').get(),
      isEmpty,
    );
    expect((await monitor())['color'], 'green');
    expect((await SyncLogRepository(db).list(status: 'failed')).length, 1);
  });
  Future<int> ppat() async {
    await db.customStatement(
      "INSERT INTO pekerjaan_ppat(id,uuid,nama,is_sync_dirty) VALUES(40,?,'J PPAT',0)",
      [job],
    );
    await db.customStatement(
      'INSERT INTO pekerjaan_ppat_sync_identity(local_uuid,cloud_uuid,scope,revision) VALUES(?,?,?,1)',
      [job, job, profile.masterScope],
    );
    await db.customStatement(
      "INSERT INTO pekerjaan_ppat_harga(uuid,pekerjaan_ppat_id,kategori_pekerjaan_id,harga,estimasi_waktu,is_sync_dirty) VALUES(?,40,30,'100','2 hari',0)",
      [price],
    );
    return TransactionRepository(db).save(
      nomorTransaksi: 'PPAT-OFFLINE',
      jenisTransaksi: 'ppat',
      pemohonId: 10,
      pemohonUuid: applicant,
      petugasId: 20,
      petugasUuid: officer,
      status: 'Baru',
      tanggalTransaksi: DateTime.utc(2020),
      pembayaranSekarang: 25,
      jobs: [
        const TransactionJobInput(
          jenisPekerjaan: 'ppat',
          namaPekerjaan: 'PPAT snapshot',
          pekerjaanPpatId: 40,
          hargaUuid: price,
          kategoriUuid: category,
          biayaLayanan: 100,
          detailUuid: '00000000-0000-4000-8000-000000000017',
        ),
      ],
    );
  }

  test(
    'PPAT replay preserves local completion and blocks a newer revision',
    () async {
      final other = await ppat();
      await run(
        ManualSyncDirection.upload,
        selectedId: other,
        module: 'transaksi_ppat',
      );
      await db.customStatement(
        "UPDATE transaksi_details SET status_pekerjaan_ppat='selesai', nomor_akta_ppat='25' WHERE transaksi_id=?",
        [other],
      );
      final cloud = TransactionCloudRepository(
        db,
        http,
        domain: 'ppat',
        scope: profile.transactionScope,
        petugasScope: profile.petugasScope,
        masterScope: profile.masterScope,
      );
      void serve(int revision, Map<String, dynamic> aggregate) {
        transport.respond = (_) async => Transport.json({
          'changes': [
            {
              'sequence': revision,
              'revision': revision,
              'operation': revision == 1 ? 'create' : 'update',
              'aggregate': aggregate,
            },
          ],
          'next_cursor': revision,
          'has_more': false,
        }, 200);
      }

      final accepted = transport.aggregate!;
      serve(1, accepted);
      expect(await cloud.pullPage(), 1);
      final pending =
          (await db
                  .customSelect('SELECT * FROM transaction_cloud_pending')
                  .getSingle())
              .data;
      final identity =
          (await db
                  .customSelect('SELECT * FROM transaction_cloud_identity')
                  .getSingle())
              .data;
      serve(2, {
        ...accepted,
        'expected_revision': 1,
        'mutation_id': '00000000-0000-4000-8000-000000000109',
      });
      await expectLater(
        cloud.pullPage(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('data akta PPAT'),
          ),
        ),
      );
      final detail = (await db.select(db.transaksiDetails).get()).singleWhere(
        (row) => row.transaksiId == other,
      );
      expect(detail.nomorAktaPpat, '25');
      expect(detail.statusPekerjaanPpat, 'selesai');
      expect(
        (await db
                .customSelect('SELECT cursor FROM transaction_cloud_feed')
                .getSingle())
            .read<int>('cursor'),
        1,
      );
      expect(
        (await db
                .customSelect('SELECT * FROM transaction_cloud_pending')
                .getSingle())
            .data,
        pending,
      );
      expect(
        (await db
                .customSelect('SELECT * FROM transaction_cloud_identity')
                .getSingle())
            .data,
        identity,
      );
    },
  );

  test('PPAT selective upload does not send dirty Notaris; upload/download selections are explicit', () async {
    final other = await ppat();
    await expectLater(
      run(ManualSyncDirection.download, module: 'transaksi_ppat'),
      failure('validation'),
    );
    await expectLater(
      run(ManualSyncDirection.download, module: 'transaksi_notaris'),
      failure('validation'),
    );
    await expectLater(
      run(ManualSyncDirection.upload, selectedId: id, module: 'transaksi'),
      failure('validation'),
    );
    expect(transport.calls, 0);
    final result = await run(
      ManualSyncDirection.upload,
      selectedId: other,
      module: 'transaksi_ppat',
    );
    expect(result.receipt!['final_number'], '2000611260001');
    expect(result.count, 1);
    expect(transport.calls, 1);
    expect(transport.aggregate!['domain'], 'ppat');
    expect(
      (await SyncMonitorRepository(
        db,
      ).read()).singleWhere((r) => r['module'] == 'transaksi_ppat')['color'],
      'yellow',
    );
    expect((await TransactionRepository(db).findById(id))!.isSyncDirty, true);
    expect(
      (await db
              .customSelect('SELECT local_uuid FROM transaction_cloud_pending')
              .get())
          .length,
      1,
    );
    await expectLater(
      run(ManualSyncDirection.upload, selectedId: id, module: 'transaksi_ppat'),
      failure('unsupported_domain'),
    );
    expect(transport.calls, 1);
    final entries = await SyncLogRepository(db).list(module: 'transaksi_ppat');
    expect(entries.map((r) => r['status']), ['failed', 'success']);
    expect(
      (await SyncMonitorRepository(
        db,
      ).read()).singleWhere((r) => r['module'] == 'transaksi')['color'],
      'red',
    );
  });
  test('PPAT feed scope mismatch blocks shared download before HTTP or log insertion', () async {
    await db.customStatement(
      "INSERT INTO pekerjaan_ppat_sync_feed(scope,cursor) VALUES('wrong-generation',0)",
    );
    await expectLater(run(ManualSyncDirection.download), failure('scope'));
    expect(transport.calls, 0);
    expect(await SyncLogRepository(db).list(), isEmpty);
  });
  test('invalid child UUID and malformed revision/number never advance shared cursor', () async {
    await run(ManualSyncDirection.upload, selectedId: id);
    final accepted =
        jsonDecode(jsonEncode(transport.aggregate)) as Map<String, dynamic>;
    for (final field in ['child', 'revision', 'number']) {
      final a = jsonDecode(jsonEncode(accepted)) as Map<String, dynamic>;
      if (field == 'child') a['details'][0]['uuid'] = 'bad-uuid';
      if (field == 'revision') a['expected_revision'] = 7;
      if (field == 'number') a['final_number'] = '2000611260001';
      transport.respond = (_) async => Transport.json({
        'changes': [
          {'sequence': 1, 'operation': 'create', 'revision': 1, 'aggregate': a},
        ],
        'next_cursor': 1,
        'has_more': false,
      }, 200);
      await expectLater(
        run(ManualSyncDirection.download),
        failure('validation'),
      );
      expect(
        (await db
                .customSelect('SELECT cursor FROM transaction_cloud_feed')
                .getSingle())
            .read<int>('cursor'),
        0,
      );
      expect(
        (await db
                .customSelect(
                  "SELECT * FROM transaction_cloud_pending WHERE state='acked'",
                )
                .get())
            .length,
        1,
      );
    }
  });
  test(
    'tombstone with changed historical provenance rejects without page commit',
    () async {
      await run(ManualSyncDirection.upload, selectedId: id);
      final tombstone =
          jsonDecode(jsonEncode(transport.aggregate)) as Map<String, dynamic>;
      tombstone['expected_revision'] = 1;
      tombstone['deleted_at'] = '2026-11-06T00:00:00Z';
      tombstone['details'][0]['job_uuid'] =
          '00000000-0000-4000-8000-000000000099';
      transport.respond = (_) async => Transport.json({
        'changes': [
          {
            'sequence': 1,
            'revision': 2,
            'operation': 'delete',
            'aggregate': tombstone,
          },
        ],
        'next_cursor': 1,
        'has_more': false,
      }, 200);
      await expectLater(
        run(ManualSyncDirection.download),
        failure('validation'),
      );
      expect(
        (await db
                .customSelect('SELECT cursor FROM transaction_cloud_feed')
                .getSingle())
            .read<int>('cursor'),
        0,
      );
      expect((await db.select(db.transaksis).getSingle()).deletedAt, isNull);
      expect(
        (await db.select(db.transaksiDetails).getSingle()).deletedAt,
        isNull,
      );
    },
  );

  test(
    'shared import requires actual applicant and officer provenance',
    () async {
      await run(ManualSyncDirection.upload, selectedId: id);
      final imported =
          jsonDecode(jsonEncode(transport.aggregate)) as Map<String, dynamic>;
      imported['uuid'] = '00000000-0000-4000-8000-000000000088';
      transport.respond = (_) async => Transport.json({
        'changes': [
          {
            'sequence': 1,
            'revision': 1,
            'operation': 'create',
            'aggregate': imported,
          },
        ],
        'next_cursor': 1,
        'has_more': false,
      }, 200);
      await db.customStatement("UPDATE petugas_identity_map SET evidence=''");
      await expectLater(
        run(ManualSyncDirection.download),
        failure('validation'),
      );
      await db.customStatement(
        "UPDATE petugas_identity_map SET evidence='authenticated fixture'",
      );
      await db.customStatement('UPDATE pemohons SET last_synced_at=NULL');
      await expectLater(
        run(ManualSyncDirection.download),
        failure('validation'),
      );
      expect(
        (await db
                .customSelect('SELECT cursor FROM transaction_cloud_feed')
                .getSingle())
            .read<int>('cursor'),
        0,
      );
      expect((await db.select(db.transaksis).get()).length, 1);
    },
  );
}
