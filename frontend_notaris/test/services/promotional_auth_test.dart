import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart' hide Fake;
import 'package:frontend_notaris/promotional_demo_main.dart';

import '../repositories/petugas_local_sync_test.dart' show Fake, reply;

const profile = '0123456789abcdef0123456789abcdef';
String token({bool expired = false, int version = 1}) =>
    'header.${base64Url.encode(utf8.encode(jsonEncode({'iss': 'backend-notaris-go', 'uid': 104, 'gid': 104, if (version > 0) 'sv': version, 'exp': DateTime.now().add(Duration(hours: expired ? -1 : 1)).millisecondsSinceEpoch ~/ 1000})))}.signature';
Map<String, Object> attestation({String id = profile}) => {
  'profile': id,
  'scope': 'promotional/$id',
  'database': 'promotional_$id',
  'host': '127.0.0.1',
  'port': 55794,
  'marker': 'NOTARIS PROMOTIONAL DISPOSABLE $id',
  'account_id': 104,
  'group_id': 104,
  'security_version': 1,
  'cloud_sync': false,
  'http_writes': 'auth_only',
};
Map<String, Object> permissions() => {
  'success': true,
  'data': {
    'user': {
      'id': 104,
      'group_id': 104,
      'username': 'superadmin.promo',
      'nama': 'Rani Wulandari',
    },
    'group_jenis': 'superadmin',
    'sidebars': [],
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => FlutterSecureStorage.setMockInitialValues({
      'unrelated-profile': 'preserve',
    }),
  );
  test(
    'normal online login, scope attestation, session refresh and scoped logout',
    () async {
      final requests = <String>[];
      final http = promotionalHttp()
        ..httpClientAdapter = Fake((r) async {
          requests.add(r.path);
          if (r.path == '/auth/login') {
            expect(r.data, {
              'username': 'superadmin.promo',
              'password': 'unit-test-input-only',
            });
            return reply({
              'success': true,
              'data': {'token': token()},
            });
          }
          if (r.path == '/auth/me/sidebar-access') return reply(permissions());
          expect(r.path, '/development/promotional');
          expect(r.headers['Authorization'], startsWith('Bearer '));
          return reply(attestation());
        });
      final auth = PromotionalAuth(http, profile);
      final session = await auth.login(
        username: 'superadmin.promo',
        password: 'unit-test-input-only',
        rememberMe: true,
      );
      expect(session.isOffline, isFalse);
      expect(session.canUseOnlineAdministration, isTrue);
      expect((await auth.restoreSession())!.userId, 104);
      expect(
        (await auth.refreshPermissions(session.token)).groupType,
        'superadmin',
      );
      expect(requests.where((r) => r == '/development/promotional').length, 3);
      await auth.clearPersistedSession();
      expect(await auth.restoreSession(), isNull);
      expect(
        await const FlutterSecureStorage().read(key: 'unrelated-profile'),
        'preserve',
      );
    },
  );
  test(
    'wrong runtime profile rejects login and removes only this scope cache',
    () async {
      final http = promotionalHttp()
        ..httpClientAdapter = Fake((r) async {
          if (r.path == '/auth/login') {
            return reply({
              'success': true,
              'data': {'token': token()},
            });
          }
          if (r.path == '/auth/me/sidebar-access') return reply(permissions());
          return reply(attestation(id: 'f' * 32));
        });
      final auth = PromotionalAuth(http, profile);
      await expectLater(
        auth.login(
          username: 'superadmin.promo',
          password: 'unit-test-input-only',
          rememberMe: true,
        ),
        throwsA(anything),
      );
      expect(
        await const FlutterSecureStorage().read(
          key: 'notaris.promotional.$profile.auth',
        ),
        isNull,
      );
    },
  );
  test('expired/versionless credentials and offline restoration cannot unlock demo', () async {
    for (final version in [0, 1]) {
      final http = promotionalHttp()
        ..httpClientAdapter = Fake((r) async {
          if (r.path == '/auth/login') {
            return reply({
              'success': true,
              'data': {'token': token(expired: version == 1, version: version)},
            });
          }
          return reply(permissions());
        });
      final auth = PromotionalAuth(http, profile);
      await expectLater(
        auth.login(
          username: 'superadmin.promo',
          password: 'unit-test-input-only',
          rememberMe: true,
        ),
        throwsA(anything),
      );
    }
    final online = promotionalHttp()
      ..httpClientAdapter = Fake((r) async {
        if (r.path == '/auth/login') {
          return reply({
            'success': true,
            'data': {'token': token()},
          });
        }
        if (r.path == '/auth/me/sidebar-access') return reply(permissions());
        return reply(attestation());
      });
    final auth = PromotionalAuth(online, profile);
    await auth.login(
      username: 'superadmin.promo',
      password: 'unit-test-input-only',
      rememberMe: true,
    );
    online.httpClientAdapter = Fake(
      (r) async => throw DioException(
        requestOptions: r,
        type: DioExceptionType.connectionError,
      ),
    );
    expect(await auth.restoreSession(), isNull);
  });
  test('HTTP factory blocks cloud, administration writes, foreign origins and queries before transport', () async {
    var sent = 0;
    final http = promotionalHttp()
      ..httpClientAdapter = Fake((r) async {
        sent++;
        return reply({'success': true});
      });
    for (final (method, path) in [
      ('POST', '/users'),
      ('PUT', '/groups/104'),
      ('DELETE', '/users/104'),
      ('GET', '/transaksi-notaris/sync/pull'),
      ('GET', 'http://127.0.0.1:8081/api/v1/health'),
      ('GET', '/health?override=true'),
    ]) {
      await expectLater(
        http.request<Object?>(path, options: Options(method: method)),
        throwsA(isA<DioException>()),
      );
    }
    expect(sent, 0);
    await http.get<Object?>('/health');
    expect(sent, 1);
    expect(() => promotionalRoot('../daily'), throwsA(anything));
  });
}
