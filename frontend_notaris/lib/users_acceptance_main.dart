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
import 'main.dart';
import 'models/auth_session.dart';
import 'payment_demo_main.dart' show paymentDemoRoot;
import 'providers/app_providers.dart';
import 'providers/auth_provider.dart';
import 'providers/authenticated_api_provider.dart';
import 'providers/database_provider.dart';
import 'providers/development_smoke_provider.dart';
import 'providers/pekerjaan_provider.dart' show userApiServiceProvider;
import 'providers/petugas_manual_sync_provider.dart';
import 'providers/users_provider.dart';
import 'services/auth_service.dart';
import 'services/user_api_service.dart';

const usersAcceptanceURL = 'http://127.0.0.1:55883/api/v1';

Directory usersAcceptanceRoot(String id) {
  final root = paymentDemoRoot(id);
  final marker = File(p.join(root.path, 'users-v1-owner'));
  if (!marker.existsSync() ||
      !p.equals(marker.path, marker.resolveSymbolicLinksSync()) ||
      marker.readAsStringSync() != id) {
    throw StateError('Profil Users V1 baru yang terisolasi diperlukan.');
  }
  return root;
}

/// Only the dedicated debug entry constructs this transport. Normal UiSmoke
/// and all other API clients retain their original mutation guard.
Dio usersAcceptanceHttp({bool administration = false}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: usersAcceptanceURL,
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 8),
      sendTimeout: const Duration(seconds: 8),
      followRedirects: false,
    ),
  );
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () => HttpClient()..findProxy = (_) => 'DIRECT',
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (r, h) {
        final path = r.uri.path.replaceFirst('/api/v1', '');
        final user = RegExp(r'^/users/[1-9][0-9]*$').hasMatch(path);
        final allowed =
            r.uri.origin == 'http://127.0.0.1:55883' &&
            (administration
                ? ((r.method == 'GET' &&
                          (path == '/users' ||
                              path == '/users/assignable-groups' ||
                              user)) ||
                      (r.method == 'POST' &&
                          (path == '/users' ||
                              RegExp(r'^/users/[1-9][0-9]*/password-reset$')
                                  .hasMatch(path))) ||
                      ((r.method == 'PUT' || r.method == 'DELETE') && user))
                : ((r.method == 'POST' && path == '/auth/login') ||
                      (r.method == 'GET' &&
                          const {
                            '/auth/me',
                            '/auth/me/sidebar-access',
                            '/development/users-v1',
                          }.contains(path))));
        if (!allowed) {
          h.reject(
            DioException(
              requestOptions: r,
              type: DioExceptionType.cancel,
              error: 'Jalur di luar scope Users V1 disposable ditolak.',
            ),
          );
        } else {
          h.next(r);
        }
      },
    ),
  );
  return dio;
}

class UsersAcceptanceAuth extends AuthService {
  UsersAcceptanceAuth(this.http, this.profile)
    : super(dio: http, cacheKey: 'notaris.users-v1.$profile.auth');
  final Dio http;
  final String profile;
  Future<AuthSession> attest(AuthSession session) async {
    if (session.isOffline) {
      throw const AuthException('Sesi Users V1 online diperlukan.');
    }
    final response = await http.get<Map<String, dynamic>>(
      '/development/users-v1',
      options: Options(headers: {'Authorization': 'Bearer ${session.token}'}),
    );
    final s = response.data;
    if (s == null ||
        s['profile'] != profile ||
        s['scope'] != 'users-v1/$profile' ||
        s['database'] != 'users_v1_$profile' ||
        s['host'] != '127.0.0.1' ||
        s['port'] != 55795 ||
        s['marker'] != 'NOTARIS USERS V1 DISPOSABLE $profile' ||
        s['account_id'] != session.userId ||
        s['group_id'] != session.groupId ||
        s['cloud_sync'] != false) {
      throw const AuthException('Binding backend Users V1 tidak cocok.');
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
      return await attest(
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
      final s = await super.restoreSession();
      return s == null ? null : await attest(s);
    } catch (_) {
      await clearPersistedSession();
      return null;
    }
  }

  @override
  Future<AuthSession> refreshPermissions(String token) async =>
      attest(await super.refreshPermissions(token));
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kDebugMode || !Platform.isWindows) {
    throw StateError('Windows debug saja.');
  }
  const id = String.fromEnvironment('NOTARIS_USERS_V1_ID');
  const hash = String.fromEnvironment('NOTARIS_USERS_V1_HELPER_SHA256');
  final root = usersAcceptanceRoot(id),
      helper = File(p.join(usersAcceptanceRoot(id).path, 'session.exe'));
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(hash) ||
      !p.equals(helper.path, helper.resolveSymbolicLinksSync()) ||
      sha256.convert(await helper.readAsBytes()).toString() != hash) {
    throw StateError('Helper Users V1 tidak cocok.');
  }
  final proof = await Process.run(helper.path, ['users-v1-validate', id]);
  if (proof.exitCode != 0) throw StateError('Verifikasi DPAPI/profil ditolak.');
  final m = jsonDecode(proof.stdout as String) as Map;
  if (m['Profile'] != id ||
      m['Scope'] != 'users-v1/$id' ||
      m['BaseURL'] != usersAcceptanceURL ||
      m['Database'] != 'users_v1_$id' ||
      m['Port'] != 55795 ||
      m['Schema'] != 27) {
    throw StateError('Manifest Users V1 tidak valid.');
  }
  final file = File(p.join(root.path, 'offline.sqlite'));
  if (!file.existsSync() ||
      !p.equals(file.path, file.resolveSymbolicLinksSync())) {
    throw StateError('SQLite disposable diperlukan.');
  }
  final db = MateraiProfileDatabase(
    NativeDatabase(
      file,
      enableMigrations: false,
      setup: (sqlite) {
        if (sqlite.select('PRAGMA user_version').single.values.single != 27) {
          throw StateError('Schema disposable harus v27.');
        }
        sqlite.execute('PRAGMA foreign_keys=ON');
        sqlite.execute('PRAGMA query_only=ON');
      },
    ),
  );
  await db.customSelect('SELECT 1').get();
  final http = usersAcceptanceHttp(),
      auth = UsersAcceptanceAuth(usersAcceptanceHttp(), id);
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
        authServiceProvider.overrideWithValue(auth),
        developmentUiSmokeProvider.overrideWithValue(true),
        petugasManualEnabledProvider.overrideWithValue(false),
        userApiServiceProvider.overrideWith((ref) {
          final client = usersAcceptanceHttp(administration: true);
          installAuthenticatedSessionInterceptor(
            client,
            baseUrl: usersAcceptanceURL,
            currentSession: () => ref.read(authControllerProvider).session,
            onRejected: (status, token) => ref
                .read(authControllerProvider.notifier)
                .handleApiRejection(status, token),
          );
          client.interceptors.add(
            InterceptorsWrapper(
              onRequest: (r, h) async {
                try {
                  final s = ref.read(authControllerProvider).session;
                  final action = r.method == 'GET'
                      ? 'read'
                      : r.method == 'DELETE'
                      ? 'delete'
                      : r.method == 'POST' && r.uri.path.endsWith('/users')
                      ? 'create'
                      : 'update';
                  if (s == null || !allowsUsers(s, action)) {
                    throw StateError('Izin Users ditolak.');
                  }
                  await auth.attest(s);
                  h.next(r);
                } catch (_) {
                  h.reject(
                    DioException(
                      requestOptions: r,
                      type: DioExceptionType.cancel,
                      error: 'Sesi/attestation Users V1 ditolak.',
                    ),
                  );
                }
              },
            ),
          );
          ref.onDispose(client.close);
          return UserApiService(client);
        }),
      ],
      child: const Directionality(
        textDirection: TextDirection.ltr,
        child: Banner(
          message: 'DEMO USERS V1 · POSTGRESQL DISPOSABLE · SYNC OFF',
          location: BannerLocation.topEnd,
          child: MyApp(),
        ),
      ),
    ),
  );
}
