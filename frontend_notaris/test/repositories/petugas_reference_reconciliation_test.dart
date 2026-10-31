import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart' hide Fake;
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/repositories/people_repository.dart';
import 'package:frontend_notaris/repositories/petugas_reference_resolver.dart';
import 'package:frontend_notaris/repositories/petugas_identity_reconciliation.dart';
import 'package:frontend_notaris/repositories/petugas_sync_repository.dart';
import 'package:frontend_notaris/services/petugas_sync_api.dart';
import 'package:frontend_notaris/services/user_api_service.dart';

import 'petugas_local_sync_test.dart' show Fake, reply;

void main() {
  late AppDatabase db;
  late VerifiedPetugasReferences refs;
  late PetugasIdentityReconciliation reconcile;
  late int gender, id;
  late String uuid;
  const scope = 'deployment-A/account-1';
  const cloud = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  PetugasServerIdentity identity({
    int serverId = 91,
    String cloudUuid = cloud,
    int version = 4,
  }) => PetugasServerIdentity.fromRecord({
    'uuid': cloudUuid,
    'id': serverId,
    'row_version': version,
  }, scope: scope);
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    refs = VerifiedPetugasReferences(db, scope: scope);
    reconcile = PetugasIdentityReconciliation(db, scope: scope);
    gender = await db
        .into(db.jenisKelamins)
        .insert(
          JenisKelaminsCompanion.insert(
            uuid: 'dev-gender-local-only',
            nama: 'Noncanonical label',
          ),
        );
    id = await PetugasRepository(db)
        .create(nama: 'Local', email: 'a@example.com', jenisKelamin: gender);
    uuid = (await db.select(db.petugasLocals).getSingle()).uuid;
  });
  tearDown(() async => db.close());
  Dio dio(Future<ResponseBody> Function(RequestOptions) handle) =>
      Dio(BaseOptions(baseUrl: 'https://deployment-A/api/v1'))
        ..httpClientAdapter = Fake(handle);
  final blockedReference = isA<PetugasSyncFailure>().having(
    (e) => e.code,
    'code',
    'blocked_reference',
  );
  test('explicit proof maps unequal gender IDs bidirectionally; local dev UUID is never cloud identity', () async {
    await expectLater(refs.genderToServer(gender), throwsA(blockedReference));
    await refs.confirmGender(
      localUuid: 'dev-gender-local-only',
      serverId: 77,
      evidence: 'operator verified PostgreSQL row 77 in deployment A',
    );
    expect(await refs.genderToServer(gender), 77);
    expect(await refs.genderToLocal(77), gender);
    await refs.confirmGender(
      localUuid: 'dev-gender-local-only',
      serverId: 77,
      evidence: 'same confirmation repeated',
    );
    await refs.markGenderAmbiguous(
      'dev-gender-local-only',
      'operator withdrew proof',
    );
    await expectLater(refs.genderToServer(gender), throwsA(blockedReference));
    await expectLater(refs.genderToLocal(77), throwsA(blockedReference));
  });
  test(
    'duplicate gender mapping and cross-deployment reuse rejected',
    () async {
      await refs.confirmGender(
        localUuid: 'dev-gender-local-only',
        serverId: 77,
        evidence: 'reviewed',
      );
      await db
          .into(db.jenisKelamins)
          .insert(
            JenisKelaminsCompanion.insert(
              uuid: 'other-gender',
              nama: 'Same label',
            ),
          );
      await expectLater(
        refs.confirmGender(
          localUuid: 'other-gender',
          serverId: 77,
          evidence: 'reviewed',
        ),
        throwsA(blockedReference),
      );
      await expectLater(
        VerifiedPetugasReferences(
          db,
          scope: 'deployment-B',
        ).genderToServer(gender),
        throwsA(blockedReference),
      );
    },
  );
  test('user reference requires authenticated server provenance, revocation removes it', () async {
    await expectLater(refs.verifiedServerUser(20), throwsA(blockedReference));
    final users = UserApiService(
      dio((r) async {
        expect(r.path, '/users');
        return reply({
          'success': true,
          'data': [
            {
              'id': 20,
              'group_id': 1,
              'nama': 'User',
              'username': 'user',
              'email': 'u@example.com',
              'status': 1,
            },
          ],
        });
      }),
    );
    await refs.verifyUserFromServer(users, 20);
    expect(await refs.verifiedServerUser(20), 20);
    await expectLater(
      VerifiedPetugasReferences(
        db,
        scope: 'deployment-B',
      ).verifiedServerUser(20),
      throwsA(blockedReference),
    );
    await expectLater(
      refs.verifyUserFromServer(
        UserApiService(dio((_) async => reply({'success': true, 'data': []}))),
        20,
      ),
      throwsA(blockedReference),
    );
    await expectLater(refs.verifiedServerUser(20), throwsA(blockedReference));
  });
  test('verified reconciliation initializes version without touching local identity/transactions; repeat safe', () async {
    await db
        .into(db.transaksis)
        .insert(
          TransaksisCompanion.insert(
            uuid: 'tx-ref',
            noAkta: '1000000000001',
            total: 0,
            petugasId: Value(id),
            petugasUuid: Value(uuid),
          ),
        );
    await reconcile.confirmVerified(
      localUuid: uuid,
      server: identity(),
      evidence: 'confirmed legacy pair',
    );
    await reconcile.confirmVerified(
      localUuid: uuid,
      server: identity(),
      evidence: 'repeat',
    );
    final row = await db.select(db.petugasLocals).getSingle();
    expect(row.id, id);
    expect(row.uuid, uuid);
    expect(row.isSyncDirty, true);
    final tx = await db.select(db.transaksis).getSingle();
    expect(tx.petugasUuid, uuid);
    expect(tx.petugasId, id);
    expect(
      (await db
              .customSelect('SELECT row_version FROM petugas_sync_journal')
              .getSingle())
          .read<int>('row_version'),
      4,
    );
    await expectLater(
      reconcile.confirmVerified(
        localUuid: uuid,
        server: identity(cloudUuid: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'),
        evidence: 'reassign',
      ),
      throwsA(isA<PetugasSyncFailure>()),
    );
  });
  test(
    'all reconciliation states and duplicate active identity protection',
    () async {
      expect(
        (await reconcile.confirmLocalOnly(uuid, 'confirmed local only')).state,
        'local_only',
      );
      expect(
        (await reconcile.markAmbiguous(
          uuid,
          'multiple unverified candidates',
        )).state,
        'ambiguous',
      );
      expect(
        (await reconcile.markDevelopment(uuid, 'development fixture')).state,
        'development',
      );
      await expectLater(
        PetugasLocalSyncRepository(
          db,
          PetugasSyncApi(dio((_) async => throw StateError('must not push'))),
          refs,
          scope: scope,
        ).push(uuid),
        throwsA(isA<PetugasSyncFailure>()),
      );
      await reconcile.confirmVerified(
        localUuid: uuid,
        server: identity(),
        evidence: 'explicit operator promotion',
      );
      final otherId = await PetugasRepository(db)
          .create(nama: 'Other', email: 'other@example.com');
      final other = (await (db.select(
        db.petugasLocals,
      )..where((r) => r.id.equals(otherId))).getSingle()).uuid;
      await expectLater(
        reconcile.confirmVerified(
          localUuid: other,
          server: identity(),
          evidence: 'duplicate',
        ),
        throwsA(anything),
      );
      await expectLater(
        reconcile.markAmbiguous(uuid, 'linked record'),
        throwsA(isA<PetugasSyncFailure>()),
      );
    },
  );
  test('invalid reference sends no HTTP; verified resolver supplies server ID and established version', () async {
    await reconcile.confirmVerified(
      localUuid: uuid,
      server: identity(),
      evidence: 'reviewed pair',
    );
    var requests = 0;
    final api = PetugasSyncApi(
      dio((req) async {
        requests++;
        final m = req.data as Map;
        expect(m['expected_row_version'], 4);
        expect((m['payload'] as Map)['jenis_kelamin_id'], 77);
        return reply({
          'success': true,
          'data': {
            'acknowledgement': {
              'mutation_id': m['mutation_id'],
              'petugas_uuid': cloud,
              'server_id': 91,
              'row_version': 5,
              'tombstone': false,
            },
            'record': {'uuid': cloud, 'id': 91, 'row_version': 5},
          },
        });
      }),
    );
    final sync = PetugasLocalSyncRepository(db, api, refs, scope: scope);
    await expectLater(sync.push(uuid), throwsA(blockedReference));
    expect(requests, 0);
    await refs.confirmGender(
      localUuid: 'dev-gender-local-only',
      serverId: 77,
      evidence: 'verified server row',
    );
    await sync.push(uuid);
    expect(requests, 1);
  });
  test('server-only pull uses reference mapping and repeat does not duplicate or overwrite dirty data', () async {
    await refs.confirmGender(
      localUuid: 'dev-gender-local-only',
      serverId: 77,
      evidence: 'reviewed',
    );
    final api = PetugasSyncApi(
      dio(
        (req) async => reply({
          'success': true,
          'data': {
            'changes': [
              {
                'publication_sequence': req.queryParameters['cursor'] == 0
                    ? 1
                    : 2,
                'petugas_uuid': cloud,
                'server_id': 91,
                'row_version': req.queryParameters['cursor'] == 0 ? 1 : 2,
                'tombstone': false,
                'payload': {
                  'nama': 'Server',
                  'email': 's@example.com',
                  'jenis_kelamin_id': 77,
                },
              },
            ],
            'next_cursor': req.queryParameters['cursor'] == 0 ? 1 : 2,
            'has_more': false,
          },
        }),
      ),
    );
    final sync = PetugasLocalSyncRepository(db, api, refs, scope: scope);
    await sync.pull();
    final server = (await db.select(db.petugasLocals).get()).singleWhere(
      (r) => r.id != id,
    );
    expect(server.jenisKelamin, gender);
    await reconcile.confirmServerOnly(
      localUuid: server.uuid,
      server: identity(version: 1),
      evidence: 'reviewed server-only materialization',
    );
    await PetugasRepository(db).update(
      id: server.id,
      nama: 'Offline edit',
      email: server.email,
      jenisKelamin: gender,
    );
    await expectLater(sync.pull(), throwsA(isA<PetugasSyncFailure>()));
    expect((await db.select(db.petugasLocals).get()).length, 2);
    expect(
      (await (db.select(
        db.petugasLocals,
      )..where((r) => r.id.equals(server.id))).getSingle()).nama,
      'Offline edit',
    );
  });
  test('pending mutation prevents identity reclassification and retains original mutation', () async {
    await reconcile.confirmLocalOnly(uuid, 'reviewed');
    await refs.confirmGender(
      localUuid: 'dev-gender-local-only',
      serverId: 77,
      evidence: 'reviewed',
    );
    final sync = PetugasLocalSyncRepository(
      db,
      PetugasSyncApi(
        dio(
          (req) async => throw DioException(
            requestOptions: req,
            type: DioExceptionType.receiveTimeout,
          ),
        ),
      ),
      refs,
      scope: scope,
    );
    await expectLater(sync.push(uuid), throwsA(isA<PetugasSyncFailure>()));
    final before = await db
        .customSelect('SELECT pending FROM petugas_sync_journal')
        .getSingle();
    await expectLater(
      reconcile.markAmbiguous(uuid, 'review'),
      throwsA(isA<PetugasSyncFailure>()),
    );
    expect(
      (await db
              .customSelect('SELECT pending FROM petugas_sync_journal')
              .getSingle())
          .read<String>('pending'),
      before.read<String>('pending'),
    );
  });
}
