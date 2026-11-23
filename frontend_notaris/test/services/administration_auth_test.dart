import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart' hide Fake;
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/models/auth_session.dart';
import 'package:frontend_notaris/providers/app_providers.dart';
import 'package:frontend_notaris/providers/auth_provider.dart';
import 'package:frontend_notaris/providers/authenticated_api_provider.dart';
import 'package:frontend_notaris/providers/development_smoke_provider.dart';
import 'package:frontend_notaris/services/auth_service.dart';

import '../repositories/petugas_local_sync_test.dart' show Fake, reply;

String jwt({int? version = 1, bool expired = false, int uid = 1}) {
  final claims = <String, Object>{
    'uid': uid,
    'gid': 1,
    'iss': 'backend-notaris-go',
    'exp':
        DateTime.now()
            .toUtc()
            .add(Duration(hours: expired ? -1 : 1))
            .millisecondsSinceEpoch ~/
        1000,
    'sv': ?version,
  };
  return 'header.${base64Url.encode(utf8.encode(jsonEncode(claims)))}.test-signature';
}

AuthSession session({
  String? token,
  bool offline = false,
  String role = 'superadmin',
}) => AuthSession(
  token: token ?? jwt(),
  userId: 1,
  groupId: 1,
  groupType: role,
  userName: 'Verified',
  groupName: 'Administrators',
  user: const {'id': 1},
  sidebars: const [],
  verifiedAt: DateTime.now(),
  isOffline: offline,
);

class ReadyAuth extends AuthController {
  ReadyAuth(super.service, AuthSession initial) {
    state = AuthState.authenticated(initial);
  }
}

class UnavailableCache extends AuthService {
  @override
  Future<void> clearPersistedSession() async =>
      throw StateError('Storage unavailable');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'profile authentication is never forwarded to another HTTP origin',
    () async {
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            (ref) => ReadyAuth(AuthService(), session()),
          ),
          dioProvider.overrideWithValue(
            Dio(
              BaseOptions(baseUrl: 'https://verified.example.invalid/api/v1'),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final dio = container.read(authenticatedDioProvider)
        ..httpClientAdapter = Fake(
          (r) async =>
              throw StateError('Credentials must not leave bound origin'),
        );
      await expectLater(
        dio.get<Object?>('https://other.example.invalid/api/v1/users'),
        throwsA(isA<DioException>()),
      );
    },
  );
  test(
    '401 invalidates in-memory authority even when secure cache deletion fails',
    () async {
      final s = session();
      final controller = ReadyAuth(UnavailableCache(), s);
      addTearDown(controller.dispose);
      await expectLater(
        controller.handleApiRejection(401, s.token),
        throwsStateError,
      );
      expect(controller.state.status, AuthStatus.unauthenticated);
    },
  );
  test('online admin requires current versioned identity, expiry, role and connectivity', () {
    expect(session().canUseOnlineAdministration, isTrue);
    for (final value in [
      session(offline: true),
      session(token: jwt(expired: true)),
      session(token: jwt(version: null)),
      session(token: jwt(uid: 9)),
      session(token: 'malformed'),
      session(role: 'user'),
    ]) {
      expect(value.canUseOnlineAdministration, isFalse);
    }
  });

  test('401 revocation clears only scoped auth and preserves dirty operational SQLite', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db
        .into(db.petugasLocals)
        .insert(
          PetugasLocalsCompanion.insert(
            uuid: 'protected-local',
            nama: 'Local',
            email: 'local@example.invalid',
          ),
        );
    FlutterSecureStorage.setMockInitialValues({
      'daily-auth': 'untouched',
      'scope-auth': 'revoked',
    });
    final s = session();
    final controller = ReadyAuth(AuthService(cacheKey: 'scope-auth'), s);
    addTearDown(controller.dispose);
    await controller.handleApiRejection(401, s.token);
    expect(controller.state.status, AuthStatus.unauthenticated);
    expect(await const FlutterSecureStorage().read(key: 'scope-auth'), isNull);
    expect(
      await const FlutterSecureStorage().read(key: 'daily-auth'),
      'untouched',
    );
    expect((await db.select(db.petugasLocals).getSingle()).isSyncDirty, isTrue);
  });

  test('403 refreshes actual permissions; stale rejection cannot replace a different account', () async {
    var requests = 0;
    final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid/api/v1'))
      ..httpClientAdapter = Fake((r) async {
        requests++;
        expect(r.path, '/auth/me/sidebar-access');
        return reply({
          'success': true,
          'data': {
            'user': {'id': 1, 'group_id': 1, 'nama': 'Verified'},
            'group_jenis': 'user',
            'sidebars': [],
          },
        });
      });
    final s = session();
    final controller = ReadyAuth(AuthService(dio: dio), s);
    addTearDown(controller.dispose);
    await controller.handleApiRejection(403, s.token);
    expect(requests, 1);
    expect(controller.state.session!.groupType, 'user');
    expect(controller.state.session!.canUseOnlineAdministration, isFalse);
    await controller.handleApiRejection(401, 'some-other-account-token');
    expect(controller.state.status, AuthStatus.authenticated);
  });

  test('offline fallback remains operational but cannot administer; rejection never falls back', () async {
    final s = session();
    FlutterSecureStorage.setMockInitialValues({'scope': s.encode()});
    final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid/api/v1'))
      ..httpClientAdapter = Fake(
        (r) async => throw DioException(
          requestOptions: r,
          type: DioExceptionType.connectionError,
        ),
      );
    final auth = AuthService(dio: dio, cacheKey: 'scope');
    final offline = await auth.restoreSession();
    expect(offline!.isOffline, isTrue);
    expect(offline.canUseOnlineAdministration, isFalse);
    dio.httpClientAdapter = Fake((r) async => reply({'success': false}, 401));
    expect(await auth.restoreSession(), isNull);
  });

  for (final path in ['/users', '/groups/2/sidebar-access']) {
    test('offline administration blocked before HTTP: $path', () async {
      final auth = ReadyAuth(AuthService(), session(offline: true));
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith((ref) => auth),
          dioProvider.overrideWithValue(
            Dio(BaseOptions(baseUrl: 'https://example.invalid/api/v1')),
          ),
        ],
      );
      addTearDown(container.dispose);
      var sent = 0;
      final dio = container.read(authenticatedDioProvider)
        ..httpClientAdapter = Fake((r) async {
          sent++;
          return reply({'success': true});
        });
      await expectLater(dio.post<Object?>(path), throwsA(isA<DioException>()));
      expect(sent, 0);
      await dio.get<Object?>('/petugas/references/users/1');
      expect(sent, 1);
    });
  }

  test('authenticated interceptor handles 401 and 403 without forwarding cache authority', () async {
    for (final status in [401, 403]) {
      final s = session();
      final base = Dio(BaseOptions(baseUrl: 'https://example.invalid/api/v1'))
        ..httpClientAdapter = Fake(
          (r) async => reply({
            'success': true,
            'data': {
              'user': {'id': 1, 'group_id': 1, 'nama': 'Verified'},
              'group_jenis': 'user',
              'sidebars': [],
            },
          }),
        );
      final auth = ReadyAuth(AuthService(dio: base), s);
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith((ref) => auth),
          dioProvider.overrideWithValue(base),
        ],
      );
      final dio = container.read(authenticatedDioProvider)
        ..httpClientAdapter = Fake(
          (r) async => reply({'success': false}, status),
        );
      await expectLater(
        dio.get<Object?>('/users'),
        throwsA(isA<DioException>()),
      );
      if (status == 401) {
        expect(auth.state.status, AuthStatus.unauthenticated);
      } else {
        expect(auth.state.session!.groupType, 'user');
      }
      container.dispose();
    }
  });

  test('UI Smoke still blocks valid online administrator writes', () async {
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(
          (ref) => ReadyAuth(AuthService(), session()),
        ),
        developmentUiSmokeProvider.overrideWithValue(true),
        dioProvider.overrideWithValue(
          Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8081/api/v1')),
        ),
      ],
    );
    addTearDown(container.dispose);
    final dio = container.read(authenticatedDioProvider)
      ..httpClientAdapter = Fake(
        (r) async => throw StateError('No request permitted'),
      );
    await expectLater(
      dio.post<Object?>('/users'),
      throwsA(isA<DioException>()),
    );
  });
}
