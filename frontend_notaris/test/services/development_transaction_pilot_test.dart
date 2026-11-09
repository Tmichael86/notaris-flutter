import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/repositories/transaction_cloud_repository.dart';
import 'package:frontend_notaris/services/development_transaction_pilot_bootstrap.dart';
import 'package:frontend_notaris/services/development_transaction_pilot_profile.dart';
import 'package:frontend_notaris/services/transaction_manual_sync_service.dart';

import '../support/transaction_ui_test_support.dart';
import 'transaction_manual_sync_service_test.dart' show Transport;

class FrozenPayloadTransport extends Transport {
  FrozenPayloadTransport(this.receipt);
  final Map<String, dynamic> receipt;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    calls++;
    final bytes = await stream!.expand((chunk) => chunk).toList();
    expect(pilotHash(utf8.decode(bytes)), receipt['payload_sha256']);
    return Transport.json({
      'acknowledgement': {
        'uuid': receipt['uuid'],
        'mutation_id': receipt['mutation_id'],
        'revision': 1,
        'final_number': '1000911260001',
      },
    }, 200);
  }
}

class FixtureProfile extends TransactionManualProfile {
  FixtureProfile()
    : super(
        sqlitePath: 'memory',
        baseUrl: 'http://127.0.0.1:18081/api/v1',
        databaseTarget: 'test',
        deployment: 'test',
        device: 'test',
        generation: 'test',
        accountId: 1,
        groupId: 1,
      );
  @override
  String get scope => 'disposable-pilot';
  @override
  Future<void> validate(AppDatabase db) async {
    final row = await db
        .customSelect('SELECT scope,cursor FROM petugas_sync_feed')
        .getSingle();
    if (row.read<String>('scope') != petugasScope ||
        row.read<int>('cursor') != 4) {
      throw const ManualTransactionFailure('scope');
    }
  }
}

Map<String, dynamic> fixturePage() {
  Map<String, dynamic> event(
    int sequence,
    String uuid,
    int revision,
    String operation,
    String? price,
  ) => {
    'sequence': sequence,
    'revision': revision,
    'operation': operation,
    'aggregate': {
      'uuid': uuid,
      'nama': 'Synthetic $uuid',
      'harga': price == null
          ? null
          : [
              {
                'uuid': price,
                'category_uuid': pilotCategoryUuid,
                'harga': '100000',
                'estimasi_waktu': '2 hari',
              },
            ],
      'proses': price == null ? null : [],
    },
  };
  const a = '40000000-0000-4000-8000-000000000001',
      b = '40000000-0000-4000-8000-000000000002';
  const pa = '50000000-0000-4000-8000-000000000001',
      pb = '50000000-0000-4000-8000-000000000002';
  return {
    'next_cursor': 6,
    'has_more': false,
    'changes': [
      event(1, a, 1, 'create', pa),
      event(2, a, 2, 'update', pa),
      event(3, a, 3, 'delete', null),
      event(4, b, 1, 'create', pb),
      event(5, b, 2, 'delete', null),
      event(6, pilotMasterUuid, 1, 'create', pilotPriceUuid),
    ],
  };
}

void main() {
  late AppDatabase db;
  late FixtureProfile profile;
  late Dio http;
  late Transport transport;
  late List<String> dirty;
  late String original;
  late Map<String, dynamic> page;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    profile = FixtureProfile();
    await seedTransactionUiReferences(db, profile);
    await createTransactionUiRecord(db, 'notaris');
    await createTransactionUiRecord(db, 'ppat');
    await db.customStatement(
      "INSERT INTO transaksis(uuid,no_akta,jenis_transaksi,total) VALUES('60000000-0000-4000-8000-000000000003','OLD-3','notaris',0)",
    );
    await db.customStatement('DELETE FROM pekerjaan_notaris_sync_identity');
    await db.customStatement('DELETE FROM pekerjaan_ppat_sync_identity');
    await db.customStatement(
      "INSERT INTO pemohons(uuid,nama,is_sync_dirty,last_synced_at) VALUES(?,'Pilot applicant',0,1)",
      [pilotApplicantUuid],
    );
    await db.customStatement(
      'UPDATE petugas_identity_map SET cloud_uuid=?,server_id=101',
      [pilotOfficerUuid],
    );
    await db.customStatement(
      "INSERT INTO pekerjaan_kategori(uuid,nama,is_sync_dirty) VALUES(?,'Pilot category',0)",
      [pilotCategoryUuid],
    );
    dirty =
        (await db.customSelect('SELECT uuid FROM transaksis ORDER BY id').get())
            .map((r) => r.read<String>('uuid'))
            .toList();
    original = await pilotLegacyFingerprint(db);
    page = fixturePage();
    transport = Transport()
      ..respond = (options) async {
        expect(options.method, 'GET');
        expect(options.path, '/pekerjaan-notaris/sync/pull');
        expect(options.queryParameters['cursor'], 0);
        return Transport.json(page, 200);
      };
    http = Dio(BaseOptions(baseUrl: profile.baseUrl))
      ..httpClientAdapter = transport;
  });
  tearDown(() async {
    http.close();
    await db.close();
  });

  Future<Map<String, dynamic>> bootstrap({String? hash}) =>
      bootstrapDevelopmentPilot(
        db: db,
        profile: profile,
        masterHttp: http,
        reviewedDirtyUuids: dirty,
        masterFeedHash: hash ?? pilotMasterFeedHash(page),
      );

  test('one atomic bootstrap preserves all legacy aggregates and stages a frozen CREATE', () async {
    final receipt = await bootstrap();
    expect(await pilotLegacyFingerprint(db), original);
    expect(receipt['uuid'], isNot(isIn(dirty)));
    expect(receipt['identity'], isNull);
    expect(receipt['mutation_state'], 'pending');
    final pending = await db
        .customSelect('SELECT payload FROM transaction_cloud_pending')
        .getSingle();
    final payload = pending.read<String>('payload');
    final body = jsonDecode(payload) as Map;
    expect(body['payments'], isEmpty);
    expect(body['details'], hasLength(1));
    expect(receipt['payload_sha256'], pilotHash(payload));
    await validateDevelopmentPilotCheckpoint(db, profile, http, receipt);
    expect(transport.calls, 1);
    await expectLater(bootstrap(), throwsA(isA<ManualTransactionFailure>()));
    expect(transport.calls, 1);
    await db.customStatement(
      "UPDATE transaksis SET catatan='changed' WHERE id=?",
      [receipt['id']],
    );
    await expectLater(
      validateDevelopmentPilotCheckpoint(db, profile, http, receipt),
      throwsA(isA<ManualTransactionFailure>()),
    );
  });

  test('reference failure after replay rolls back Master, cursor and mutation together', () async {
    await db.customStatement('DELETE FROM pemohons WHERE uuid=?', [
      pilotApplicantUuid,
    ]);
    await expectLater(bootstrap(), throwsA(isA<StateError>()));
    expect(await pilotLegacyFingerprint(db), original);
    for (final table in [
      'pekerjaan_notaris_sync_feed',
      'pekerjaan_notaris_sync_identity',
      'transaction_cloud_pending',
      'transaction_cloud_feed',
    ]) {
      expect(await db.customSelect('SELECT * FROM $table').get(), isEmpty);
    }
    expect((await db.select(db.transaksis).get()), hasLength(3));
  });

  test(
    'changed feed and mismatched Petugas cursor stop before local commit',
    () async {
      await expectLater(bootstrap(hash: 'wrong'), throwsA(isA<DioException>()));
      expect(
        await db
            .customSelect('SELECT * FROM pekerjaan_notaris_sync_feed')
            .get(),
        isEmpty,
      );
      await db.customStatement('UPDATE petugas_sync_feed SET cursor=5');
      await expectLater(bootstrap(), throwsA(isA<ManualTransactionFailure>()));
      expect(transport.calls, 1);
    },
  );

  test('profile refuses unreviewed manifest bytes before opening SQLite', () {
    // The hash gate is independent from the legacy disposable path gate.
    expect(
      () => DevelopmentTransactionPilotProfile.open('pubspec.yaml', 'wrong'),
      throwsA(isA<ManualTransactionFailure>()),
    );
  });

  test(
    'wire body matches frozen checkpoint hash and ACK preserves old rows',
    () async {
      final receipt = await bootstrap();
      final adapter = FrozenPayloadTransport(receipt);
      final upload = Dio(BaseOptions(baseUrl: profile.baseUrl))
        ..httpClientAdapter = adapter;
      try {
        final cloud = TransactionCloudRepository(
          db,
          upload,
          scope: profile.transactionScope,
          petugasScope: profile.petugasScope,
          masterScope: profile.masterScope,
        );
        await cloud.pushCreate(receipt['id'] as int);
        expect(adapter.calls, 1);
        expect(
          (await db
                  .customSelect('SELECT state FROM transaction_cloud_pending')
                  .getSingle())
              .read<String>('state'),
          'acked',
        );
        expect(await pilotLegacyFingerprint(db), original);
        await expectLater(
          validateDevelopmentPilotCheckpoint(db, profile, upload, receipt),
          throwsA(isA<ManualTransactionFailure>()),
        );
      } finally {
        upload.close();
      }
    },
  );

  test('hash-pinned manifest still rejects a daily SQLite path', () async {
    final temp = await Directory.systemTemp.createTemp('pilot_manifest_test_');
    final folder = await Directory(
      '${temp.path}/.local/development-pilot-run-test',
    ).create(recursive: true);
    final file = File('${folder.path}/manifest.json');
    try {
      await file.writeAsString(
        jsonEncode({
          'stage': 'LocalBootstrap',
          'sqlite': '${temp.path}/notaris_offline.sqlite',
        }),
      );
      expect(
        () => DevelopmentTransactionPilotProfile.open(
          file.path,
          pilotFileHash(file),
        ),
        throwsA(isA<ManualTransactionFailure>()),
      );
    } finally {
      await file.delete();
      await folder.delete();
      await folder.parent.delete();
      await temp.delete();
    }
  });
}
