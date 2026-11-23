import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/models/auth_session.dart';
import 'package:frontend_notaris/providers/auth_provider.dart';
import 'package:frontend_notaris/release_qa_bootstrap.dart';
import 'package:frontend_notaris/services/auth_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as native;

ReleaseQaConfiguration config([String deployment = 'qa-h07-test']) =>
    ReleaseQaConfiguration(
      environment: 'qa-disconnected',
      deployment: deployment,
      endpoint: releaseQaEndpoint,
      schema: '27',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory support;
  final opened = <ReleaseQaProfile>[];
  Future<ReleaseQaProfile> open([ReleaseQaConfiguration? c]) async {
    final result = await ReleaseQaProfile.open(
      c ?? config(),
      applicationSupport: support,
    );
    opened.add(result);
    return result;
  }

  setUp(() async {
    support = await Directory.systemTemp.createTemp('notaris-h07-test-');
  });
  tearDown(() async {
    for (final v in opened.reversed) {
      await v.close();
    }
    opened.clear();
    await support.delete(recursive: true);
  });

  test('fresh production profile creates complete v27 schema, FK, no seeds or legacy access', () async {
    final sentinel = File(p.join(support.path, 'notaris_offline.sqlite'))
      ..writeAsStringSync('protected legacy sentinel');
    final auth = File(p.join(support.path, 'flutter_secure_storage.dat'))
      ..writeAsStringSync('protected historical cache');
    final dbhash = sha256.convert(sentinel.readAsBytesSync()),
        authhash = sha256.convert(auth.readAsBytesSync());
    final q = await open();
    expect(q.databasePath, contains('qa-release-v1'));
    expect(q.binding['phase'], 'ready');
    expect(
      (await q.database.customSelect('PRAGMA user_version').getSingle())
          .data
          .values
          .single,
      27,
    );
    expect(
      (await q.database.customSelect('PRAGMA foreign_keys').getSingle())
          .data
          .values
          .single,
      1,
    );
    expect(
      (await q.database.customSelect('PRAGMA integrity_check').getSingle())
          .data
          .values
          .single,
      'ok',
    );
    expect(
      await q.database.customSelect('PRAGMA foreign_key_check').get(),
      isEmpty,
    );
    final tables = await q.database
        .customSelect("SELECT name FROM sqlite_master WHERE type='table'")
        .get();
    expect(tables.length, 45); // 44 application tables and sqlite_sequence.
    for (final t in tables) {
      expect(
        (await q.database
                .customSelect(
                  'SELECT count(*) n FROM "${t.read<String>('name')}"',
                )
                .getSingle())
            .read<int>('n'),
        0,
      );
    }
    expect(q.authKey, isNot('notaris.auth.session.v1'));
    expect(q.authFile.existsSync(), false);
    expect(await ReleaseQaSessionCache(q).read(key: q.authKey), isNull);
    expect(sha256.convert(sentinel.readAsBytesSync()), dbhash);
    expect(sha256.convert(auth.readAsBytesSync()), authhash);
  });

  test('normal restart retains install/device/generation/profile/account namespace and local data', () async {
    final a = await open();
    final before = Map.of(a.binding);
    final key = a.authKey;
    await a.database.customStatement(
      "INSERT INTO pekerjaan_kategori(uuid,nama) VALUES('local-test','Local test')",
    );
    await a.close();
    final b = await open();
    expect(b.binding, before);
    expect(b.authKey, key);
    expect(
      (await b.database.select(b.database.pekerjaanKategoris).get())
          .single
          .nama,
      'Local test',
    );
  });

  test('configuration fails before any profile creation: no legacy/default/ambiguous environment', () async {
    for (final c in [
      const ReleaseQaConfiguration(
        environment: '',
        deployment: 'qa-test',
        endpoint: releaseQaEndpoint,
        schema: '27',
      ),
      const ReleaseQaConfiguration(
        environment: 'production',
        deployment: 'qa-test',
        endpoint: releaseQaEndpoint,
        schema: '27',
      ),
      const ReleaseQaConfiguration(
        environment: 'qa-disconnected',
        deployment: '../notarisdev',
        endpoint: releaseQaEndpoint,
        schema: '27',
      ),
      const ReleaseQaConfiguration(
        environment: 'qa-disconnected',
        deployment: 'qa-test',
        endpoint: 'http://127.0.0.1:8081/api/v1',
        schema: '27',
      ),
      const ReleaseQaConfiguration(
        environment: 'qa-disconnected',
        deployment: 'qa-test',
        endpoint: releaseQaEndpoint,
        schema: '24',
      ),
    ]) {
      await expectLater(open(c), throwsStateError);
      expect(support.listSync(), isEmpty);
    }
  });

  test('disconnected AuthService/controller cannot dispatch or restore historical sessions', () async {
    final q = await open();
    final http = releaseQaDisconnectedHttp(q);
    addTearDown(http.close);
    final service = AuthService(
      dio: http,
      sessionCache: ReleaseQaSessionCache(q),
      cacheKey: q.authKey,
    );
    expect(await service.restoreSession(), isNull);
    final controller = AuthController(service);
    addTearDown(controller.dispose);
    await controller.initialize();
    expect(controller.state.status, AuthStatus.unauthenticated);
    await controller.login(
      username: 'test-only-never-sent',
      password: 'never-transmitted',
      rememberMe: true,
    );
    expect(controller.state.status, AuthStatus.unauthenticated);
    expect(controller.state.errorMessage, isNotEmpty);
    expect(q.authFile.existsSync(), false);
    final log = File(p.join(q.directory.path, 'runtime-events.jsonl'))
        .readAsStringSync();
    expect(log, contains('QA_BACKEND_UNCONFIGURED'));
    expect(log, isNot(contains('never-transmitted')));
  });

  test(
    'single instance lock rejects another opener without modifying the binding',
    () async {
      final q = await open();
      final marker = File(p.join(q.root.path, 'binding.json'));
      final before = marker.readAsBytesSync();
      await expectLater(open(), throwsA(isA<FileSystemException>()));
      expect(marker.readAsBytesSync(), before);
      expect(await q.database.customSelect('SELECT 1').get(), hasLength(1));
    },
  );

  test('unknown binding fields and profile traversal fail closed', () async {
    final q = await open();
    final original = Map<String, dynamic>.of(q.binding);
    final marker = File(p.join(q.root.path, 'binding.json'));
    await q.close();
    for (final changed in [
      {...original, 'extra': 'unapproved'},
      {...original, 'profile_id': '../legacy'},
      {...original, 'deployment': 'qa-other'},
      {...original, 'device_id': 'not-a-uuid'},
    ]) {
      marker.writeAsStringSync(jsonEncode(changed), flush: true);
      await expectLater(open(), throwsStateError);
    }
  });

  test(
    'replacing a bound DB is rejected before SQLite opens the replacement',
    () async {
      final q = await open();
      await q.close();
      final original = File(q.databasePath);
      original.renameSync('${q.databasePath}.preserved');
      original.writeAsStringSync('replacement must never be opened');
      final before = sha256.convert(original.readAsBytesSync());
      await expectLater(open(), throwsStateError);
      expect(sha256.convert(original.readAsBytesSync()), before);
    },
  );

  for (final version in [0, 24, 25, 26, 28]) {
    test('bound existing schema $version is never silently migrated', () async {
      final q = await open();
      await q.close();
      // Only this test-owned fresh file: the production opener must reject it.
      final sqlite = native.sqlite3.open(q.databasePath);
      sqlite.execute('PRAGMA user_version=$version');
      sqlite.close();
      final f = File(q.databasePath);
      final before = sha256.convert(f.readAsBytesSync());
      await expectLater(open(), throwsStateError);
      expect(sha256.convert(f.readAsBytesSync()), before);
    });
  }

  test('initialization recovery opens committed v27 but does not invent a new identity', () async {
    final q = await open();
    final before = Map<String, dynamic>.of(q.binding);
    await q.close();
    final marker = File(p.join(q.root.path, 'binding.json'));
    marker.writeAsStringSync(jsonEncode({...before, 'phase': 'initializing'}));
    final recovered = await open();
    expect(recovered.binding, before);
  });

  test(
    'ambiguous allocation and orphan manifest are preserved, never reset',
    () async {
      final q = await open();
      final before = Map<String, dynamic>.of(q.binding);
      await q.close();
      final marker = File(p.join(q.root.path, 'binding.json'));
      marker.writeAsStringSync(jsonEncode({...before, 'phase': 'allocated'}));
      await expectLater(open(), throwsStateError);
      expect(File(q.databasePath).existsSync(), true);
      marker.writeAsStringSync(jsonEncode(before));
      final orphan = File('${marker.path}.next')
        ..writeAsStringSync('interrupted');
      await expectLater(open(), throwsStateError);
      expect(orphan.readAsStringSync(), 'interrupted');
    },
  );

  AuthSession fixture({int account = 101, DateTime? verified}) => AuthSession(
    token: 'unit-test-only-never-dispatched',
    userId: account,
    groupId: 11,
    userName: 'Test account $account',
    groupName: 'Test operators',
    user: {'id': account, 'group_id': 11},
    sidebars: const [],
    verifiedAt: verified ?? DateTime.now(),
  );

  test('DPAPI cache survives restart with exact account/profile binding and no plaintext', () async {
    final q = await open();
    final cache = ReleaseQaSessionCache(q);
    final session = fixture();
    await cache.write(key: q.authKey, value: session.encode());
    expect(await cache.read(key: q.authKey), session.encode());
    expect(
      utf8.decode(q.authFile.readAsBytesSync(), allowMalformed: true),
      isNot(contains(session.token)),
    );
    await expectLater(
      cache.read(key: 'notaris.auth.session.v1'),
      throwsStateError,
    );
    await q.close();
    final reopened = await open();
    final raw = await ReleaseQaSessionCache(reopened)
        .read(key: reopened.authKey);
    expect(
      AuthSession.fromJson(jsonDecode(raw!) as Map<String, dynamic>).userId,
      101,
    );
    await ReleaseQaSessionCache(reopened)
        .write(key: reopened.authKey, value: fixture(account: 202).encode());
    final switched = await ReleaseQaSessionCache(reopened)
        .read(key: reopened.authKey);
    expect(
      AuthSession.fromJson(jsonDecode(switched!) as Map<String, dynamic>)
          .userId,
      202,
    );
  });

  test('copying sealed cache to a different deployment cannot restore its privileges', () async {
    final a = await open();
    final b = await open(config('qa-h07-other'));
    await ReleaseQaSessionCache(a)
        .write(key: a.authKey, value: fixture().encode());
    a.authFile.copySync(b.authFile.path);
    await expectLater(
      ReleaseQaSessionCache(b).read(key: b.authKey),
      throwsStateError,
    );
    await ReleaseQaSessionCache(b).delete(key: b.authKey);
    expect(a.authFile.existsSync(), true);
    expect(b.authFile.existsSync(), false);
  });

  test('scoped cache preserves the existing offline grace, expiry and permission policy', () async {
    final q = await open();
    final http = releaseQaDisconnectedHttp(q);
    addTearDown(http.close);
    final cache = ReleaseQaSessionCache(q);
    final service = AuthService(
      dio: http,
      sessionCache: cache,
      cacheKey: q.authKey,
    );
    await cache.write(key: q.authKey, value: fixture().encode());
    final restored = await service.restoreSession();
    expect(restored?.isOffline, true);
    expect(restored?.hasTransactionAccess(update: true), false);
    expect(restored?.canUseOnlineAdministration, false);
    await cache.write(
      key: q.authKey,
      value: fixture(verified: DateTime.now().subtract(const Duration(days: 8)))
          .encode(),
    );
    expect(await service.restoreSession(), isNull);
    expect(q.authFile.existsSync(), false);
  });

  test(
    'every HTTP method stays disconnected, including arbitrary absolute URL',
    () async {
      final q = await open();
      final http = releaseQaDisconnectedHttp(q);
      addTearDown(http.close);
      for (final method in ['GET', 'POST', 'PUT', 'PATCH', 'DELETE']) {
        await expectLater(
          http.request<Object>(
            'http://127.0.0.1:8080/auth/login',
            options: Options(method: method),
          ),
          throwsA(isA<DioException>()),
        );
      }
      expect(q.authFile.existsSync(), false);
      final logs = File(p.join(q.directory.path, 'runtime-events.jsonl'))
          .readAsLinesSync();
      expect(logs.where((line) => line.contains('http_blocked')), hasLength(5));
    },
  );
}
