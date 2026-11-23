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
import 'providers/pekerjaan_provider.dart' show sidebarApiServiceProvider;
import 'providers/petugas_manual_sync_provider.dart';
import 'providers/sidebar_catalog_provider.dart';
import 'services/auth_service.dart';
import 'services/sidebar_api_service.dart';

const sidebarsV1AcceptanceURL = 'http://127.0.0.1:55886/api/v1';

Directory sidebarsV1AcceptanceRoot(String id) {
  final root = paymentDemoRoot(id);
  final marker = File(p.join(root.path, 'sidebars-v1-owner'));
  if (!marker.existsSync() ||
      !p.equals(marker.path, marker.resolveSymbolicLinksSync()) ||
      marker.readAsStringSync() != id) {
    throw StateError('Profil Sidebars V1 baru yang terisolasi diperlukan.');
  }
  return root;
}

/// Only the dedicated debug entry constructs this transport. Normal UiSmoke
/// and all other API clients retain their original mutation guard.
Dio sidebarsV1AcceptanceHttp({bool administration = false}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: sidebarsV1AcceptanceURL,
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
        final allowed =
            r.uri.origin == 'http://127.0.0.1:55886' &&
            (administration
                ? r.method == 'GET' && path == '/sidebars/catalog'
                : ((r.method == 'POST' && path == '/auth/login') ||
                      (r.method == 'GET' &&
                          const {
                            '/auth/me',
                            '/auth/me/sidebar-access',
                            '/development/sidebars-v1',
                          }.contains(path))));
        if (!allowed) {
          h.reject(
            DioException(
              requestOptions: r,
              type: DioExceptionType.cancel,
              error: 'Jalur di luar scope Sidebars V1 disposable ditolak.',
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

class SidebarsV1AcceptanceAuth extends AuthService {
  SidebarsV1AcceptanceAuth(this.http, this.profile)
    : super(dio: http, cacheKey: 'notaris.sidebars-v1.$profile.auth');
  final Dio http;
  final String profile;
  Future<AuthSession> attest(AuthSession session) async {
    if (session.isOffline) {
      throw const AuthException('Sesi Sidebars V1 online diperlukan.');
    }
    final response = await http.get<Map<String, dynamic>>(
      '/development/sidebars-v1',
      options: Options(headers: {'Authorization': 'Bearer ${session.token}'}),
    );
    final s = response.data;
    if (s == null ||
        s['profile'] != profile ||
        s['scope'] != 'sidebars-v1/$profile' ||
        s['database'] != 'sidebars_v1_$profile' ||
        s['host'] != '127.0.0.1' ||
        s['port'] != 55798 ||
        s['marker'] != 'NOTARIS SIDEBARS V1 DISPOSABLE $profile' ||
        s['account_id'] != session.userId ||
        s['group_id'] != session.groupId ||
        s['cloud_sync'] != false) {
      throw const AuthException('Binding backend Sidebars V1 tidak cocok.');
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
  const id = String.fromEnvironment('NOTARIS_SIDEBARS_V1_ID');
  const hash = String.fromEnvironment('NOTARIS_SIDEBARS_V1_HELPER_SHA256');
  final root = sidebarsV1AcceptanceRoot(id),
      helper = File(p.join(sidebarsV1AcceptanceRoot(id).path, 'session.exe'));
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(hash) ||
      !p.equals(helper.path, helper.resolveSymbolicLinksSync()) ||
      sha256.convert(await helper.readAsBytes()).toString() != hash) {
    throw StateError('Helper Sidebars V1 tidak cocok.');
  }
  final proof = await Process.run(helper.path, ['sidebars-v1-validate', id]);
  if (proof.exitCode != 0) throw StateError('Verifikasi DPAPI/profil ditolak.');
  final m = jsonDecode(proof.stdout as String) as Map;
  if (m['Profile'] != id ||
      m['Scope'] != 'sidebars-v1/$id' ||
      m['BaseURL'] != sidebarsV1AcceptanceURL ||
      m['Database'] != 'sidebars_v1_$id' ||
      m['Port'] != 55798 ||
      m['Schema'] != 27 ||
      m['Catalog'] != 'sidebars-v1') {
    throw StateError('Manifest Sidebars V1 tidak valid.');
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
  final http = sidebarsV1AcceptanceHttp(),
      auth = SidebarsV1AcceptanceAuth(sidebarsV1AcceptanceHttp(), id);
  Dio adminClient(Ref ref) {
    final client = sidebarsV1AcceptanceHttp(administration: true);
    installAuthenticatedSessionInterceptor(
      client,
      baseUrl: sidebarsV1AcceptanceURL,
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

            if (s == null || !allowsSidebarCatalog(s)) {
              throw StateError('Izin baca Sidebars ditolak.');
            }
            await auth.attest(s);
            h.next(r);
          } catch (_) {
            h.reject(
              DioException(
                requestOptions: r,
                type: DioExceptionType.cancel,
                error: 'Sesi/attestation Sidebars V1 ditolak.',
              ),
            );
          }
        },
      ),
    );
    ref.onDispose(client.close);
    return client;
  }

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
        sidebarApiServiceProvider.overrideWith(
          (ref) => SidebarApiService(adminClient(ref)),
        ),
      ],
      child: const Directionality(
        textDirection: TextDirection.ltr,
        child: Banner(
          message: 'DEMO SIDEBARS V1 · POSTGRESQL DISPOSABLE · SYNC OFF',
          location: BannerLocation.topEnd,
          child: MyApp(),
        ),
      ),
    ),
  );
}
