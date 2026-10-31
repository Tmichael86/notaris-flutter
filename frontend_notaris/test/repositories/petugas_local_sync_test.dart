import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/repositories/people_repository.dart';
import 'package:frontend_notaris/repositories/petugas_identity_map_repository.dart';
import 'package:frontend_notaris/repositories/petugas_sync_repository.dart';
import 'package:frontend_notaris/services/petugas_sync_api.dart';

class Fake implements HttpClientAdapter {
  Fake(this.handle);
  final Future<ResponseBody> Function(RequestOptions) handle;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) => handle(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody reply(Object data, [int status = 200]) => ResponseBody.fromString(
  jsonEncode(data),
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

class Refs implements PetugasSyncReferences {
  @override
  Future<int> genderToServer(int id) async =>
      throw const PetugasSyncFailure(PetugasSyncFailureKind.reference);
  @override
  Future<int> genderToLocal(int id) async =>
      throw const PetugasSyncFailure(PetugasSyncFailureKind.reference);
  @override
  Future<int> verifiedServerUser(int id) async =>
      throw const PetugasSyncFailure(PetugasSyncFailureKind.reference);
}

void main() {
  late AppDatabase db;
  late PetugasRepository people;
  late String uuid;
  late int id;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    people = PetugasRepository(db);
    id = await people.create(nama: 'Local', email: 'a@example.com');
    uuid = (await db.select(db.petugasLocals).getSingle()).uuid;
    await PetugasIdentityMapRepository(db).registerLocalOnly(localUuid: uuid);
  });
  tearDown(() async => db.close());
  PetugasLocalSyncRepository repo(
    Future<ResponseBody> Function(RequestOptions) fn,
  ) {
    final dio = Dio(BaseOptions(baseUrl: 'https://test/api/v1'));
    dio.httpClientAdapter = Fake(fn);
    return PetugasLocalSyncRepository(
      db,
      PetugasSyncApi(dio),
      Refs(),
      scope: 'test/account-1',
    );
  }

  Map<String, dynamic> event(int seq, {bool tomb = false, int? gender}) => {
    'publication_sequence': seq,
    'petugas_uuid': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    'server_id': 91,
    'row_version': seq,
    'tombstone': tomb,
    if (!tomb)
      'payload': {
        'nama': 'Cloud $seq',
        'email': 'cloud@example.com',
        'jenis_kelamin_id': gender,
      },
  };
  ResponseBody page(List<Object> events, int cursor, {bool more = false}) =>
      reply({
        'success': true,
        'data': {'changes': events, 'next_cursor': cursor, 'has_more': more},
      });
  ResponseBody ack(RequestOptions r) {
    final m = r.data as Map;
    final version = (m['expected_row_version'] as int? ?? 0) + 1;
    return reply({
      'success': true,
      'data': {
        'acknowledgement': {
          'mutation_id': m['mutation_id'],
          'petugas_uuid': m['petugas_uuid'],
          'server_id': 91,
          'row_version': version,
          'tombstone': m['operation'] == 'delete',
        },
        'record': {'id': 91, 'uuid': m['petugas_uuid'], 'row_version': version},
      },
    });
  }

  test(
    'local edit during pending HTTP response is not acknowledged clean',
    () async {
      await repo((req) async {
        await people.update(
          id: id,
          nama: 'Edited while awaiting HTTP',
          email: 'a@example.com',
        );
        return ack(req);
      }).push(uuid);
      final row = await db.select(db.petugasLocals).getSingle();
      expect(row.isSyncDirty, true);
      expect(row.nama, 'Edited while awaiting HTTP');
    },
  );
  test('transaction references survive push and tombstone pull', () async {
    await db
        .into(db.transaksis)
        .insert(
          TransaksisCompanion.insert(
            uuid: 'old-transaction',
            noAkta: '1000000000001',
            total: 0,
            petugasId: Value(id),
            petugasUuid: Value(uuid),
          ),
        );
    await repo((req) async => ack(req)).push(uuid);
    final mapping = await PetugasIdentityMapRepository(db)
        .findByLocalUuid(uuid);
    final tomb = event(2, tomb: true)..['petugas_uuid'] = mapping!.cloudUuid;
    await repo((_) async => page([tomb], 2)).pull();
    final tx = await db.select(db.transaksis).getSingle();
    expect(tx.petugasId, id);
    expect(tx.petugasUuid, uuid);
    expect((await db.select(db.petugasLocals).getSingle()).uuid, uuid);
  });
  test('development seed is excluded', () async {
    await PetugasIdentityMapRepository(db)
        .markDevelopment(localUuid: uuid, evidence: 'development fixture');
    await expectLater(
      repo((_) async => throw StateError('no HTTP')).push(uuid),
      throwsA(isA<PetugasSyncFailure>()),
    );
  });
  test(
    'local gender cannot be sent as server ID without explicit mapping',
    () async {
      await people.update(
        id: id,
        nama: 'Local',
        email: 'a@example.com',
        jenisKelamin: 999,
      );
      await expectLater(
        repo((_) async => throw StateError('no HTTP')).push(uuid),
        throwsA(
          isA<PetugasSyncFailure>().having(
            (e) => e.kind,
            'kind',
            PetugasSyncFailureKind.reference,
          ),
        ),
      );
    },
  );
  test('timeout retry persists mutation across repository instances; concurrent local edit remains dirty', () async {
    Object? first;
    final r = repo((req) async {
      first = req.data;
      throw DioException(
        requestOptions: req,
        type: DioExceptionType.receiveTimeout,
      );
    });
    await expectLater(r.push(uuid), throwsA(isA<PetugasSyncFailure>()));
    await people.update(
      id: id,
      nama: 'Edited during flight',
      email: 'a@example.com',
    );
    await repo((req) async {
      expect(req.data, first);
      return ack(req);
    }).push(uuid);
    final local = await db.select(db.petugasLocals).getSingle();
    expect(local.id, id);
    expect(local.uuid, uuid);
    expect(local.isSyncDirty, true);
    expect(local.nama, 'Edited during flight');
  });
  test(
    'successful upsert followed by delete uses cloud identity and version',
    () async {
      await repo((req) async {
        expect(req.path, startsWith('/petugas/sync/'));
        expect((req.data as Map)['expected_row_version'], null);
        return ack(req);
      }).push(uuid);
      expect(
        (await db.select(db.petugasLocals).getSingle()).isSyncDirty,
        false,
      );
      await people.delete(id);
      await repo((req) async {
        expect((req.data as Map)['operation'], 'delete');
        expect((req.data as Map)['expected_row_version'], 1);
        return ack(req);
      }).push(uuid);
      expect((await db.select(db.petugasLocals).getSingle()).status, 0);
    },
  );
  for (final pair in {
    400: PetugasSyncFailureKind.invalid,
    401: PetugasSyncFailureKind.unauthorized,
    403: PetugasSyncFailureKind.forbidden,
    409: PetugasSyncFailureKind.conflict,
    410: PetugasSyncFailureKind.expired,
    500: PetugasSyncFailureKind.server,
  }.entries) {
    test('HTTP ${pair.key} explicitly classified', () async {
      await expectLater(
        repo((_) async => reply({'success': false}, pair.key)).push(uuid),
        throwsA(
          isA<PetugasSyncFailure>().having((e) => e.kind, 'kind', pair.value),
        ),
      );
    });
  }
  test('ambiguous identity never pushed', () async {
    await PetugasIdentityMapRepository(db)
        .markAmbiguous(localUuid: uuid, evidence: 'review');
    await expectLater(
      repo((_) async => throw StateError('must not request')).push(uuid),
      throwsA(isA<PetugasSyncFailure>()),
    );
  });
  test('pagination and tombstone preserve existing local identity', () async {
    var requests = 0;
    final r = repo((req) async {
      requests++;
      return req.queryParameters['cursor'] == 0
          ? page([event(1)], 1, more: true)
          : page([event(2, tomb: true)], 2);
    });
    await r.pull();
    expect(requests, 2);
    final rows = await db.select(db.petugasLocals).get();
    expect(rows.length, 2);
    expect(rows.singleWhere((r) => r.id == id).uuid, uuid);
    expect(rows.singleWhere((r) => r.id != id).status, 0);
    await repo((_) async => page([], 2)).pull();
    expect((await db.select(db.petugasLocals).get()).length, 2);
  });
  test('missing reference rolls whole page and cursor back', () async {
    await expectLater(
      repo((_) async => page([event(1), event(2, gender: 999)], 2)).pull(),
      throwsA(isA<PetugasSyncFailure>()),
    );
    expect((await db.select(db.petugasLocals).get()).length, 1);
    expect(
      (await db
              .customSelect('SELECT cursor FROM petugas_sync_feed')
              .getSingle())
          .read<int>('cursor'),
      0,
    );
  });
  test('410 blocks future pull without resetting cursor', () async {
    await expectLater(
      repo((_) async => reply({}, 410)).pull(),
      throwsA(isA<PetugasSyncFailure>()),
    );
    await expectLater(
      repo((_) async => throw StateError('must stay blocked')).pull(),
      throwsA(
        isA<PetugasSyncFailure>().having(
          (e) => e.kind,
          'kind',
          PetugasSyncFailureKind.blocked,
        ),
      ),
    );
  });
  test('dirty pulled record blocks batch and cursor advancement', () async {
    await repo((_) async => page([event(1)], 1)).pull();
    final row = (await db.select(db.petugasLocals).get()).singleWhere(
      (r) => r.id != id,
    );
    await people.update(id: row.id, nama: 'Offline edit', email: row.email);
    await expectLater(
      repo((_) async => page([event(2)], 2)).pull(),
      throwsA(isA<PetugasSyncFailure>()),
    );
    expect(
      (await db
              .customSelect('SELECT cursor FROM petugas_sync_feed')
              .getSingle())
          .read<int>('cursor'),
      1,
    );
  });
}
