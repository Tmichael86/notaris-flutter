import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart' hide Fake;
import 'package:path/path.dart' as p;

import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/models/auth_session.dart';
import 'package:frontend_notaris/providers/auth_provider.dart';
import 'package:frontend_notaris/providers/authenticated_api_provider.dart';
import 'package:frontend_notaris/providers/database_provider.dart';
import 'package:frontend_notaris/providers/pekerjaan_provider.dart';
import 'package:frontend_notaris/providers/petugas_baseline_pull_provider.dart';
import 'package:frontend_notaris/repositories/petugas_baseline_pull.dart';
import 'package:frontend_notaris/repositories/petugas_identity_reconciliation.dart';
import 'package:frontend_notaris/repositories/petugas_reference_resolver.dart';
import 'package:frontend_notaris/services/petugas_sync_api.dart';
import 'package:frontend_notaris/services/auth_service.dart';
import 'package:frontend_notaris/services/user_api_service.dart';

import 'petugas_local_sync_test.dart' show Fake, reply;

const clouds = [
  'e85be759-1e15-4b2f-8243-120131475207',
  '6e302bea-4999-4180-b322-665b94f3495b',
  'e8875e8a-4b4a-4773-a1ad-7d799885a937',
  '1a2ccb82-e8ca-44a8-bb76-44e5c550e2de',
];
AuthSession auth([int id = 2001]) => AuthSession(
  token: 'fixture-token-$id',
  userId: id,
  groupId: 11,
  userName: 'Fixture',
  groupName: 'Fixture',
  user: const {},
  sidebars: const [],
  verifiedAt: DateTime.now(),
);
Map<String, dynamic> event(int index) => {
  'publication_sequence': index + 1,
  'petugas_uuid': clouds[index],
  'server_id': 101 + index,
  'row_version': 1,
  'tombstone': false,
  'payload': {
    'nama': 'Server baseline $index',
    'email': 'fixture$index@example.invalid',
    'jenis_kelamin_id': index.isEven ? 11 : 29,
    'user_id': 2001,
    'tanggal_lahir': '1990-01-01',
  },
};

class FixtureAuthController extends AuthController {
  FixtureAuthController(AuthSession session, Dio dio)
    : super(AuthService(dio: dio)) {
    state = AuthState.authenticated(session);
  }
}

void main() {
  late Directory temp;
  late File file;
  late AppDatabase db;
  late Dio dio;
  late PetugasBaselineContext context;
  late VerifiedPetugasReferences refs;
  late AuthSession? session;
  late Future<ResponseBody> Function(RequestOptions) respond;
  late List<int> requests;

  ResponseBody page(RequestOptions request) {
    final cursor = request.queryParameters['cursor'] as int;
    final limit = request.queryParameters['limit'] as int;
    final changes = List.generate(4, event).skip(cursor).take(limit).toList();
    final next = changes.isEmpty
        ? cursor
        : changes.last['publication_sequence'];
    return reply({
      'success': true,
      'data': {
        'changes': changes,
        'next_cursor': next,
        'has_more': (next as int) < 4,
      },
    });
  }

  Future<int?> cursor() async =>
      (await db
              .customSelect('SELECT cursor FROM petugas_sync_feed WHERE id=1')
              .getSingleOrNull())
          ?.read<int>('cursor');

  PetugasBaselinePlan plan({
    List<String>? existing,
    Set<String>? inventory,
  }) => PetugasBaselinePlan(
    scope: context.scope,
    reviewedLocalUuids: inventory ?? existing?.toSet() ?? {},
    selections: List.generate(4, (i) {
      final server = PetugasServerIdentity.fromRecord({
        'id': 101 + i,
        'uuid': clouds[i],
        'row_version': 1,
      }, scope: context.scope);
      return existing == null
          ? PetugasBaselineSelection.serverOnly(
              server: server,
              sequence: i + 1,
              evidence:
                  'authenticated synthetic baseline + empty inventory review',
            )
          : PetugasBaselineSelection.existing(
              server: server,
              sequence: i + 1,
              localUuid: existing[i],
              evidence: 'explicit reviewed UUID pair, not name or numeric ID matching',
            );
    }),
  );
  PetugasBaselinePull puller([PetugasBaselinePlan? reviewed]) =>
      PetugasBaselinePull(
        db: db,
        dio: dio,
        context: context,
        plan: reviewed ?? plan(),
        references: refs,
        session: () => session,
      );
  Future<void> reopen() async {
    await db.close();
    db = AppDatabase.forIsolatedPetugasPull(file);
    await db.customStatement('PRAGMA foreign_keys=ON');
    refs = VerifiedPetugasReferences(db, scope: context.scope);
  }

  setUp(() async {
    temp = await Directory.systemTemp.createTemp(
      'notaris-baseline-disposable-',
    );
    file = File(p.join(temp.path, 'notarisdev', 'a' * 32, 'offline.sqlite'));
    await file.parent.create(recursive: true);
    db = AppDatabase.forIsolatedPetugasPull(file);
    await db.customStatement('PRAGMA foreign_keys=ON');
    context = PetugasBaselineContext(
      generation: 'a' * 32,
      accountId: 2001,
      deviceId: 'fixture-device',
      databasePath: file.path,
    );
    session = auth();
    requests = [];
    respond = (r) async => page(r);
    dio = Dio(
      BaseOptions(
        baseUrl: PetugasBaselineContext.apiBase.toString(),
        headers: {'Authorization': 'Bearer fixture-token-2001'},
      ),
    );
    dio.httpClientAdapter = Fake((request) async {
      expect(request.method, 'GET', reason: 'fixtures must never push');
      expect(request.headers['Authorization'], 'Bearer fixture-token-2001');
      if (request.path == '/users') {
        return reply({
          'success': true,
          'data': [
            {
              'id': 2001,
              'status': 1,
              'group_id': 11,
              'nama': 'Fixture',
              'username': 'fixture.operator',
              'email': 'fixture@example.invalid',
            },
          ],
        });
      }
      expect(request.path, '/petugas/sync/pull');
      expect(request.headers['Authorization'], 'Bearer fixture-token-2001');
      requests.add(request.queryParameters['cursor'] as int);
      return respond(request);
    });
    refs = VerifiedPetugasReferences(db, scope: context.scope);
    for (final id in [11, 29]) {
      await db
          .into(db.jenisKelamins)
          .insert(
            JenisKelaminsCompanion.insert(
              uuid: 'local-gender-$id',
              nama: 'Synthetic reference $id',
            ),
          );
      await refs.confirmGender(
        localUuid: 'local-gender-$id',
        serverId: id,
        evidence: 'explicit authenticated fixture catalog proof',
      );
    }
    await refs.verifyUserFromServer(UserApiService(dio), 2001);
  });
  tearDown(() async {
    await db.close();
    dio.close(force: true);
    await temp.delete(recursive: true);
  });

  test(
    'four unique baselines, GET auth, pagination, cursor4 replay and restart',
    () async {
      await puller().pull();
      expect(requests, [0, 2]);
      expect(await cursor(), 4);
      final first = await db.select(db.petugasLocals).get();
      expect(first.length, 4);
      expect(first.map((r) => r.id).toSet(), {1, 2, 3, 4});
      expect(first.every((r) => !r.isSyncDirty && r.userId == 2001), true);
      expect(first.map((r) => r.jenisKelamin).toSet(), {1, 2});
      expect(
        (await db.select(db.petugasIdentityMaps).get())
            .map((r) => r.cloudUuid)
            .toSet(),
        clouds.toSet(),
      );
      await reopen();
      expect(await cursor(), 4);
      await puller().pull();
      expect(requests, [0, 2, 4]);
      expect(
        (await db.select(db.petugasLocals).get())
            .map((r) => r.toJson())
            .toList(),
        first.map((r) => r.toJson()).toList(),
      );
    },
  );

  test('existing local rows reused by explicit UUID pairs; numeric collisions and FKs unchanged', () async {
    final locals = ['local-a', 'local-b', 'local-c', 'local-d'];
    for (var i = 0; i < 4; i++) {
      await db
          .into(db.petugasLocals)
          .insert(
            PetugasLocalsCompanion.insert(
              id: Value(101 + i),
              uuid: locals[i],
              nama: 'Identical ambiguous name',
              email: 'same@example.invalid',
              isSyncDirty: const Value(false),
            ),
          );
      await db
          .into(db.transaksis)
          .insert(
            TransaksisCompanion.insert(
              uuid: 'transaction-$i',
              noAkta: '100000000000${i + 1}',
              total: 0,
              petugasId: Value(101 + i),
              petugasUuid: Value(locals[i]),
            ),
          );
    }
    final transactions = (await db.select(db.transaksis).get())
        .map((r) => r.toJson())
        .toList();
    final selected = locals.reversed.toList();
    await puller(plan(existing: selected)).pull(limit: 4);
    expect((await db.select(db.petugasLocals).get()).length, 4);
    final rows = await db.select(db.petugasLocals).get();
    for (var i = 0; i < 4; i++) {
      final row = rows.singleWhere((r) => r.uuid == selected[i]);
      expect(row.id, 104 - i);
      expect(
        row.nama,
        'Server baseline $i',
      ); // Not skipped by premature journal acknowledgement.
    }
    expect(
      (await db.select(db.transaksis).get()).map((r) => r.toJson()).toList(),
      transactions,
    );
    await puller(plan(existing: selected)).pull();
    expect((await db.select(db.petugasLocals).get()).length, 4);
  });

  test('unreviewed local data blocks before GET, including matching names or server numeric IDs', () async {
    await db
        .into(db.petugasLocals)
        .insert(
          PetugasLocalsCompanion.insert(
            id: const Value(101),
            uuid: 'unknown-local',
            nama: 'Server baseline 0',
            email: 'fixture0@example.invalid',
          ),
        );
    await expectLater(puller().pull(), throwsA(isA<PetugasSyncFailure>()));
    expect(requests, isEmpty);
    expect(await cursor(), isNull);
    expect((await db.select(db.petugasLocals).get()).length, 1);
  });

  test('dirty existing selection is not cleaned or duplicated', () async {
    final locals = <String>[];
    for (var i = 0; i < 4; i++) {
      locals.add('dirty-$i');
      await db
          .into(db.petugasLocals)
          .insert(
            PetugasLocalsCompanion.insert(
              uuid: locals.last,
              nama: 'Offline edit',
              email: 'offline@example.invalid',
            ),
          );
    }
    await expectLater(
      puller(plan(existing: locals)).pull(),
      throwsA(isA<PetugasSyncFailure>()),
    );
    expect(await cursor(), 0);
    expect(
      (await db.select(db.petugasLocals).get()).every(
        (r) => r.isSyncDirty && r.nama == 'Offline edit',
      ),
      true,
    );
    expect(await db.select(db.petugasIdentityMaps).get(), isEmpty);
  });

  test('interruption at cursor commit rolls all four upserts/maps/journals back, restart replays safely', () async {
    await db.customStatement(
      "CREATE TRIGGER stop_checkpoint BEFORE UPDATE OF cursor ON petugas_sync_feed BEGIN SELECT RAISE(ABORT,'fixture interruption before commit'); END",
    );
    await expectLater(puller().pull(limit: 4), throwsA(anything));
    expect(await cursor(), 0);
    expect(await db.select(db.petugasLocals).get(), isEmpty);
    expect(await db.select(db.petugasIdentityMaps).get(), isEmpty);
    expect(
      await db.customSelect('SELECT * FROM petugas_sync_journal').get(),
      isEmpty,
    );
    await db.customStatement('DROP TRIGGER stop_checkpoint');
    await reopen();
    await puller().pull(limit: 4);
    expect(await cursor(), 4);
    expect((await db.select(db.petugasLocals).get()).length, 4);
  });

  test('network interruption after page1 keeps cursor2 and resumes on reopened file', () async {
    respond = (request) async {
      if (request.queryParameters['cursor'] == 2) {
        throw DioException(
          requestOptions: request,
          type: DioExceptionType.receiveTimeout,
        );
      }
      return page(request);
    };
    await expectLater(puller().pull(), throwsA(isA<PetugasSyncFailure>()));
    expect(await cursor(), 2);
    expect((await db.select(db.petugasLocals).get()).length, 2);
    await reopen();
    respond = (r) async => page(r);
    await puller().pull();
    expect(requests, [0, 2, 2]);
    expect(await cursor(), 4);
    expect((await db.select(db.petugasLocals).get()).length, 4);
  });

  for (final status in [401, 403, 409, 410]) {
    test(
      'HTTP $status preserves local rows/cursor and 410 persists blocked recovery',
      () async {
        respond = (_) async => reply({'success': false}, status);
        await expectLater(puller().pull(), throwsA(isA<PetugasSyncFailure>()));
        expect(await cursor(), 0);
        expect(await db.select(db.petugasLocals).get(), isEmpty);
        await reopen();
        if (status == 410) {
          final count = requests.length;
          await expectLater(
            puller().pull(),
            throwsA(isA<PetugasSyncFailure>()),
          );
          expect(requests.length, count);
          expect(
            (await db
                    .customSelect('SELECT blocked FROM petugas_sync_feed')
                    .getSingle())
                .read<String>('blocked'),
            'full_resync_required',
          );
        }
      },
    );
  }

  test(
    'account switch during HTTP cannot apply another account response',
    () async {
      respond = (request) async {
        session = auth(2002);
        return page(request);
      };
      await expectLater(puller().pull(), throwsA(isA<PetugasSyncFailure>()));
      expect(await cursor(), 0);
      expect(await db.select(db.petugasLocals).get(), isEmpty);
    },
  );

  test(
    'missing reference, malformed payload or sequence gap roll the page back',
    () async {
      for (final corrupt in [
        (Map<String, dynamic> e) =>
            (e['payload'] as Map)['jenis_kelamin_id'] = 999,
        (Map<String, dynamic> e) => (e['payload'] as Map).remove('nama'),
        (Map<String, dynamic> e) => e['publication_sequence'] = 4,
      ]) {
        respond = (_) async {
          final changes = [event(0), event(1)];
          corrupt(changes[1]);
          return reply({
            'success': true,
            'data': {'changes': changes, 'next_cursor': 2, 'has_more': true},
          });
        };
        await expectLater(puller().pull(), throwsA(anything));
        expect(await cursor(), 0);
        expect(await db.select(db.petugasLocals).get(), isEmpty);
        expect(await db.select(db.petugasIdentityMaps).get(), isEmpty);
      }
    },
  );

  test('scope cannot change device/account after binding; origin rejected before GET', () async {
    await puller().pull();
    final otherContext = PetugasBaselineContext(
      generation: context.generation,
      accountId: 2001,
      deviceId: 'different-device',
      databasePath: file.path,
    );
    final otherPlan = PetugasBaselinePlan(
      scope: otherContext.scope,
      reviewedLocalUuids: {},
      selections: List.generate(
        4,
        (i) => PetugasBaselineSelection.serverOnly(
          server: PetugasServerIdentity.fromRecord({
            'id': 101 + i,
            'uuid': clouds[i],
            'row_version': 1,
          }, scope: otherContext.scope),
          sequence: i + 1,
          evidence: 'fixture',
        ),
      ),
    );
    await expectLater(
      PetugasBaselinePull(
        db: db,
        dio: dio,
        context: otherContext,
        plan: otherPlan,
        references: VerifiedPetugasReferences(db, scope: otherContext.scope),
        session: () => session,
      ).pull(),
      throwsA(isA<PetugasSyncFailure>()),
    );
    expect(await cursor(), 4);
    dio.options.baseUrl = 'http://127.0.0.1:8080/api/v1';
    final count = requests.length;
    await expectLater(puller().pull(), throwsA(isA<PetugasSyncFailure>()));
    expect(requests.length, count);
  });

  test('normal provider remains disabled and never opens daily DB/auth; daily file factory rejected', () {
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWith(
          (ref) => throw StateError('must never open normal DB'),
        ),
        authControllerProvider.overrideWith(
          (ref) => throw StateError('must not start normal auth'),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(petugasBaselinePullProvider), isNull);
    expect(
      () => AppDatabase.forIsolatedPetugasPull(
        File(p.join(temp.path, 'notaris_offline.sqlite')),
      ),
      throwsArgumentError,
    );
    expect(
      () => PetugasBaselineContext(
        generation: '../daily',
        accountId: 2001,
        deviceId: 'fixture',
        databasePath: file.path,
      ),
      throwsArgumentError,
    );
  });

  test('pull-only API cannot send a mutation', () async {
    await expectLater(
      AuthenticatedPetugasPullApi(dio, verifiedToken: () => 'unused').push({}),
      throwsA(isA<PetugasSyncFailure>()),
    );
    expect(requests, isEmpty);
  });

  test('explicit provider pull uses isolated target and authenticated session without global sync', () async {
    final container = ProviderContainer(
      overrides: [
        petugasBaselinePullConfigurationProvider.overrideWithValue(
          PetugasBaselinePullConfiguration(
            database: db,
            context: context,
            plan: plan(),
            references: refs,
          ),
        ),
        authenticatedDioProvider.overrideWithValue(dio),
        authControllerProvider.overrideWith(
          (ref) => FixtureAuthController(session!, dio),
        ),
        appDatabaseProvider.overrideWith(
          (ref) => throw StateError('must not open normal DB'),
        ),
        syncCoordinatorProvider.overrideWith(
          (ref) => throw StateError('must not invoke push/global sync'),
        ),
      ],
    );
    try {
      await container.read(petugasBaselinePullProvider)!.pull();
    } finally {
      container.dispose();
    }
    expect(await cursor(), 4);
    expect((await db.select(db.petugasLocals).get()).length, 4);
  });

  test('old prematurely acknowledged version cannot silently skip a stale baseline row', () async {
    final locals = <String>[];
    for (var i = 0; i < 4; i++) {
      locals.add('reviewed-$i');
      await db
          .into(db.petugasLocals)
          .insert(
            PetugasLocalsCompanion.insert(
              uuid: locals[i],
              nama: 'Stale payload',
              email: 'stale@example.invalid',
              isSyncDirty: const Value(false),
            ),
          );
    }
    final reviewed = plan(existing: locals);
    await PetugasIdentityReconciliation(
      db,
      scope: context.scope,
    ).confirmVerified(
      localUuid: locals.first,
      server: reviewed.selections.first.server,
      evidence: 'legacy push reconciliation, not applied baseline',
    );
    await expectLater(
      puller(reviewed).pull(),
      throwsA(isA<PetugasSyncFailure>()),
    );
    expect(await cursor(), 0);
    expect(
      (await db.select(db.petugasLocals).get()).every(
        (r) => r.nama == 'Stale payload',
      ),
      true,
    );
  });

  test('stale in-flight page cannot rewind a checkpoint changed by another connection', () async {
    respond = (request) async {
      final other = AppDatabase.forIsolatedPetugasPull(file);
      try {
        await other.customStatement(
          'UPDATE petugas_sync_feed SET cursor=1 WHERE id=1',
        );
      } finally {
        await other.close();
      }
      return page(request);
    };
    await expectLater(puller().pull(), throwsA(isA<PetugasSyncFailure>()));
    expect(await cursor(), 1);
    expect(await db.select(db.petugasLocals).get(), isEmpty);
  });

  test(
    'reviewed baseline stops at cursor4 even if later server events exist',
    () async {
      respond = (request) async {
        final start = request.queryParameters['cursor'] as int;
        final events = List.generate(4, event).skip(start).take(2).toList();
        return reply({
          'success': true,
          'data': {
            'changes': events,
            'next_cursor': start + events.length,
            'has_more': true,
          },
        });
      };
      await puller().pull();
      expect(requests, [0, 2]);
      expect(await cursor(), 4);
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    },
  );
}
