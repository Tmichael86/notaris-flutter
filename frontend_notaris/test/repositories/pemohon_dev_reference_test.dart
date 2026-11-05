import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/repositories/people_repository.dart';
import 'package:frontend_notaris/repositories/pemohon_gender_references.dart';
import 'package:frontend_notaris/services/pemohon_api_service.dart';

class Catalog implements HttpClientAdapter {
  List<Map<String, dynamic>> rows = [
    {'id': 11, 'nama': 'renamed display A', 'status': 1},
    {'id': 29, 'nama': 'renamed display B', 'status': 1},
  ];
  Map<String, dynamic>? pushed;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    Object body;
    if (options.method == 'PUT') {
      pushed = Map<String, dynamic>.from(options.data as Map);
      body = {
        'success': true,
        'data': {
          'id': 900,
          'uuid': options.path.split('/').last,
          'nama': pushed!['nama'],
        },
      };
    } else {
      body = {
        'success': true,
        'data': {'items': rows},
      };
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> manifest() => {
  'fixture': 'smoke-v1',
  'genders': <Map<String, dynamic>>[
    {
      'server_id': 11,
      'local_uuid': 'explicit-a',
      'label': 'Fixture Gender A',
      'state': 'verified',
    },
    {
      'server_id': 29,
      'local_uuid': 'explicit-b',
      'label': 'Fixture Gender B',
      'state': 'verified',
    },
  ],
};
PemohonApiModel remote(int id, int gender, {String? label}) => PemohonApiModel(
  id: id,
  uuid: 'remote-$id',
  nama: 'Synthetic $id',
  jenisKelamin: gender,
  jenisKelaminNama: label,
);

void main() {
  late AppDatabase db;
  late Catalog catalog;
  late Dio dio;
  late Map<String, dynamic> pairs;
  late DevelopmentPemohonGenderReferences refs;
  late PemohonRepository repo;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    catalog = Catalog();
    dio = Dio()..httpClientAdapter = catalog;
    pairs = manifest();
    refs = DevelopmentPemohonGenderReferences(db, dio, pairs);
    repo = PemohonRepository(db, genderReferences: refs);
  });
  tearDown(() async {
    dio.close();
    await db.close();
  });
  test('initial fixture pull uses explicit UUID mapping, not display names or integer equality', () async {
    await db
        .into(db.jenisKelamins)
        .insert(
          JenisKelaminsCompanion.insert(
            uuid: 'unrelated',
            nama: 'Fixture Gender B',
            id: const Value(29),
          ),
        );
    await repo.syncFromCloud([
      remote(301, 29, label: 'different display'),
      remote(302, 11),
    ]);
    final rows = await db.select(db.pemohons).get();
    expect(rows.length, 2);
    expect(rows.every((r) => !r.isSyncDirty), isTrue);
    expect(rows.first.jenisKelamin, await refs.toLocal(29));
    expect(rows.first.jenisKelamin, isNot(29));
    expect(await refs.toLocal(11), isNot(11));
    await repo.syncFromCloud([remote(301, 29), remote(302, 11)]);
    expect((await db.select(db.pemohons).get()).length, 2);
  });
  test('unmapped same-label reference never silently matches; whole batch rolls back then retries', () async {
    await refs.prepare();
    await db
        .into(db.jenisKelamins)
        .insert(
          JenisKelaminsCompanion.insert(
            uuid: 'unverified-c',
            nama: 'Fixture Gender B',
            id: const Value(99),
          ),
        );
    await db.customStatement(
      "INSERT INTO petugas_sync_feed(id,scope,cursor) VALUES(1,'untouched',7)",
    );
    await expectLater(
      repo.syncFromCloud([
        remote(301, 29),
        remote(302, 99, label: 'Fixture Gender B'),
      ]),
      throwsStateError,
    );
    expect(await db.select(db.pemohons).get(), isEmpty);
    expect(
      (await db
              .customSelect('SELECT cursor FROM petugas_sync_feed')
              .getSingle())
          .read<int>('cursor'),
      7,
    );
    (pairs['genders'] as List).add({
      'server_id': 99,
      'local_uuid': 'verified-c',
      'label': 'Fixture Gender B',
      'state': 'verified',
    });
    catalog.rows.add({'id': 99, 'nama': 'display C', 'status': 1});
    await repo.syncFromCloud([remote(301, 29), remote(302, 99)]);
    expect((await db.select(db.pemohons).get()).length, 2);
  });
  test('missing catalog dependency preserves pending local edits', () async {
    final id = await repo.create(nama: 'Offline pending');
    catalog.rows.removeLast();
    await expectLater(repo.syncFromCloud([remote(301, 29)]), throwsStateError);
    final row = await (db.select(
      db.pemohons,
    )..where((r) => r.id.equals(id))).getSingle();
    expect(row.isSyncDirty, isTrue);
    expect(row.nama, 'Offline pending');
    expect(row.lastSyncedAt, isNull);
  });
  test(
    'ambiguous and unverified manifest rejected before any bootstrap',
    () async {
      (pairs['genders'] as List).add(
        Map<String, dynamic>.from((pairs['genders'] as List).first),
      );
      await expectLater(refs.prepare(), throwsStateError);
      expect(await db.select(db.jenisKelamins).get(), isEmpty);
      pairs['genders'] = manifest()['genders'];
      (pairs['genders'][0] as Map)['state'] = 'ambiguous';
      await expectLater(refs.prepare(), throwsStateError);
    },
  );
  test('duplicate server catalog blocked', () async {
    catalog.rows.add(Map<String, dynamic>.from(catalog.rows.first));
    await expectLater(refs.prepare(), throwsStateError);
  });
  test('dirty existing Pemohon is not overwritten by pull', () async {
    await repo.syncFromCloud([remote(301, 29)]);
    final row = await db.select(db.pemohons).getSingle();
    await repo.update(
      id: row.id,
      nama: 'New offline edit',
      jenisKelamin: row.jenisKelamin,
    );
    await repo.syncFromCloud([remote(301, 29)]);
    final current = await db.select(db.pemohons).getSingle();
    expect(current.nama, 'New offline edit');
    expect(current.isSyncDirty, isTrue);
  });
  test(
    'push uses verified server integer reference, never local ID or name',
    () async {
      await refs.prepare();
      final local = await refs.toLocal(29);
      await repo.create(nama: 'Offline synthetic', jenisKelamin: local);
      await repo.syncToCloud(PemohonApiService(dio));
      expect(catalog.pushed!['jenis_kelamin'], 29);
      expect(catalog.pushed!.containsKey('jenis_kelamin_nama'), isFalse);
      expect((await db.select(db.pemohons).getSingle()).isSyncDirty, isFalse);
    },
  );
  test('label-only payload is blocked on verified path', () async {
    await expectLater(
      repo.syncFromCloud([
        const PemohonApiModel(
          id: 1,
          uuid: 'old',
          nama: 'Fixture',
          jenisKelaminNama: 'Fixture Gender B',
        ),
      ]),
      throwsStateError,
    );
    expect(await db.select(db.pemohons).get(), isEmpty);
  });
}
