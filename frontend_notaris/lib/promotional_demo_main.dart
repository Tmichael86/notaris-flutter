import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'database/app_database.dart';
import 'core/widgets/promotional_preview.dart';
import 'main.dart';
import 'models/auth_session.dart';
import 'payment_demo_main.dart' show paymentDemoRoot;
import 'providers/app_providers.dart';
import 'providers/auth_provider.dart';
import 'providers/database_provider.dart';
import 'providers/development_smoke_provider.dart';
import 'providers/petugas_manual_sync_provider.dart';
import 'services/auth_service.dart';

const promotionalBaseUrl = 'http://127.0.0.1:55882/api/v1';

Directory promotionalRoot(String id) {
  final root = paymentDemoRoot(id);
  final marker = File(p.join(root.path, 'promotional-owner'));
  if (!marker.existsSync() ||
      !p.equals(marker.path, marker.resolveSymbolicLinksSync()) ||
      marker.readAsStringSync() != id) {
    throw StateError('Profil promosi terisolasi diperlukan.');
  }
  return root;
}

Dio promotionalHttp() {
  final dio = Dio(
    BaseOptions(
      baseUrl: promotionalBaseUrl,
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 8),
      followRedirects: false,
    ),
  );
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () => HttpClient()..findProxy = (_) => 'DIRECT',
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (r, h) {
        final path = r.uri.path;
        final allowed =
            r.uri.origin == 'http://127.0.0.1:55882' &&
            !r.uri.hasQuery &&
            ((r.method == 'POST' && path == '/api/v1/auth/login') ||
                (r.method == 'GET' &&
                    const {
                      '/api/v1/health',
                      '/api/v1/auth/me',
                      '/api/v1/auth/me/sidebar-access',
                      '/api/v1/development/promotional',
                      '/api/v1/users',
                      '/api/v1/groups',
                      '/api/v1/sidebars',
                    }.contains(path)));
        if (!allowed) {
          h.reject(
            DioException(
              requestOptions: r,
              type: DioExceptionType.cancel,
              error:
                  'Profil promosi: autentikasi dan pembacaan terkontrol saja.',
            ),
          );
          return;
        }
        h.next(r);
      },
    ),
  );
  return dio;
}

/// Uses normal bcrypt/JWT backend login and scoped secure storage. No synthetic
/// role, offline unlock, expiry override, or credential injection is used by UI.
class PromotionalAuth extends AuthService {
  PromotionalAuth(this.http, this.profile)
    : super(dio: http, cacheKey: 'notaris.promotional.$profile.auth');
  final Dio http;
  final String profile;
  Future<AuthSession> _attest(AuthSession session) async {
    if (session.isOffline || !session.canUseOnlineAdministration) {
      throw const AuthException(
        'Backend demo dan sesi online yang valid diperlukan.',
      );
    }
    final response = await http.get<Map<String, dynamic>>(
      '/development/promotional',
      options: Options(headers: {'Authorization': 'Bearer ${session.token}'}),
    );
    final state = response.data;
    if (state == null ||
        state['profile'] != profile ||
        state['scope'] != 'promotional/$profile' ||
        state['database'] != 'promotional_$profile' ||
        state['host'] != '127.0.0.1' ||
        state['port'] != 55794 ||
        state['marker'] != 'NOTARIS PROMOTIONAL DISPOSABLE $profile' ||
        state['account_id'] != session.userId ||
        state['group_id'] != session.groupId ||
        session.userId != 104 ||
        session.groupId != 104 ||
        session.user['username'] != 'superadmin.promo' ||
        state['security_version'] != 1 ||
        state['cloud_sync'] != false ||
        state['http_writes'] != 'auth_only') {
      throw const AuthException(
        'Identitas backend/profil promosi tidak cocok.',
      );
    }
    return session;
  }

  @override
  Future<AuthSession> login({
    required String username,
    required String password,
    required bool rememberMe,
  }) async {
    try {
      return await _attest(
        await super.login(
          username: username,
          password: password,
          rememberMe: rememberMe,
        ),
      );
    } catch (_) {
      await clearPersistedSession();
      rethrow;
    }
  }

  @override
  Future<AuthSession?> restoreSession() async {
    try {
      final session = await super.restoreSession();
      return session == null ? null : await _attest(session);
    } catch (_) {
      await clearPersistedSession();
      return null;
    }
  }

  @override
  Future<AuthSession> refreshPermissions(String token) async =>
      _attest(await super.refreshPermissions(token));
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kDebugMode || !Platform.isWindows) {
    throw StateError('Profil promosi hanya untuk Windows debug.');
  }
  const id = String.fromEnvironment('NOTARIS_PROMOTIONAL_ID');
  const hash = String.fromEnvironment('NOTARIS_PROMOTIONAL_HELPER_SHA256');
  final root = promotionalRoot(id);
  final helper = File(p.join(root.path, 'session.exe'));
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(hash) ||
      !p.equals(helper.path, helper.resolveSymbolicLinksSync()) ||
      sha256.convert(await helper.readAsBytes()).toString() != hash) {
    throw StateError('Helper promosi tidak cocok.');
  }
  final proof = await Process.run(helper.path, ['promo-validate-profile', id]);
  if (proof.exitCode != 0) throw StateError('Binding profil promosi ditolak.');
  final manifest = jsonDecode(proof.stdout as String) as Map;
  if (manifest['profile'] != id ||
      manifest['scope'] != 'promotional/$id' ||
      manifest['base_url'] != promotionalBaseUrl ||
      manifest['database'] != 'promotional_$id' ||
      manifest['port'] != 55794 ||
      manifest['sqlite_schema'] != 27) {
    throw StateError('Manifest promosi tidak valid.');
  }
  final file = File(p.join(root.path, 'offline.sqlite'));
  if (!file.existsSync() ||
      !p.equals(file.path, file.resolveSymbolicLinksSync())) {
    throw StateError('SQLite promosi terisolasi diperlukan.');
  }
  final db = MateraiProfileDatabase(
    NativeDatabase(
      file,
      enableMigrations: false,
      setup: (sqlite) {
        if (sqlite.select('PRAGMA user_version').single.values.single != 27) {
          throw StateError('SQLite promosi harus v27.');
        }
        sqlite.execute('PRAGMA foreign_keys=ON');
        sqlite.execute('PRAGMA query_only=ON');
      },
    ),
  );
  await db.customSelect('SELECT 1').get();
  final http = promotionalHttp();
  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWith((ref) {
          ref.onDispose(db.close);
          return db;
        }),
        dioProvider.overrideWith((ref) {
          ref.onDispose(http.close);
          return http;
        }),
        authServiceProvider.overrideWith((ref) => PromotionalAuth(http, id)),
        developmentUiSmokeProvider.overrideWithValue(true),
        petugasManualEnabledProvider.overrideWithValue(false),
      ],
      child: const PromotionalPreview(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Banner(
            message: 'DEMO PROMOSI · FIKTIF · BACA SAJA',
            location: BannerLocation.topEnd,
            child: MyApp(),
          ),
        ),
      ),
    ),
  );
}
