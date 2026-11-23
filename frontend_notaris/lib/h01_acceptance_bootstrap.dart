// Debug-only binding for a NEW H01 profile. Runs the ordinary MyApp/auth shell,
// with UiSmoke=false and no isolated manual-sync configuration or coordinator
// override. This transport is a secondary containment and records ALL attempts.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'database/app_database.dart';
import 'models/auth_session.dart';
import 'profile_v1_acceptance_main.dart'
    show profileV1AcceptanceRoot, ProfileV1AcceptanceAuth;
import 'providers/app_providers.dart';
import 'providers/auth_provider.dart';
import 'providers/authenticated_api_provider.dart';
import 'providers/database_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/pekerjaan_provider.dart';

const h01AcceptanceURL = 'http://127.0.0.1:55889/api/v1';

class H01Trace extends ProviderObserver with WidgetsBindingObserver {
  H01Trace(this.file);
  final File file;
  void record(Map<String, Object?> entry) {
    file.writeAsStringSync(
      '${jsonEncode({'at': DateTime.now().toUtc().toIso8601String(), 'unix_ms': DateTime.now().millisecondsSinceEpoch, 'launch': const String.fromEnvironment('NOTARIS_H01_LAUNCH'), ...entry})}\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      record({'event': 'lifecycle', 'state': state.name});

  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    if (provider == syncStatusProvider) {
      record({
        'event': 'global_outcome',
        'outcome': (newValue as SyncStatus).name,
      });
    }
    if (provider == authControllerProvider && newValue is AuthState) {
      record({
        'event': 'session',
        'state': newValue.status.name,
        'account': newValue.session?.userId,
      });
    }
  }
}

Dio h01ReadOnlyHttp(H01Trace trace) {
  final dio = Dio(
    BaseOptions(
      baseUrl: h01AcceptanceURL,
      followRedirects: false,
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () => HttpClient()..findProxy = (_) => 'DIRECT',
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onResponse: (r, h) {
        trace.record({
          'event': 'http_response',
          'path': r.requestOptions.uri.path,
          'status': r.statusCode,
        });
        h.next(r);
      },
      onError: (e, h) {
        trace.record({
          'event': 'http_error',
          'kind': e.type.name,
          'status': e.response?.statusCode,
        });
        h.next(e);
      },
      onRequest: (r, h) {
        final allowed =
            r.uri.origin == 'http://127.0.0.1:55889' &&
            ((r.method == 'POST' && r.uri.path == '/api/v1/auth/login') ||
                (r.method == 'GET' &&
                    const {
                      '/api/v1/auth/me',
                      '/api/v1/auth/me/sidebar-access',
                      '/api/v1/development/profile-v1',
                      '/api/v1/profile',
                    }.contains(r.uri.path)));
        // No headers/body/query/token/password are recorded, including failures.
        trace.record({
          'event': 'http',
          'method': r.method,
          'path': r.uri.path,
          'allowed': allowed,
        });
        if (!allowed) {
          h.reject(
            DioException(
              requestOptions: r,
              type: DioExceptionType.cancel,
              error: 'H01: hanya autentikasi dan GET read-only terikat profil.',
            ),
          );
          return;
        }
        r.followRedirects = false;
        h.next(r);
      },
    ),
  );
  return dio;
}

class H01Auth extends ProfileV1AcceptanceAuth {
  H01Auth(super.http, super.profile, this.trace);
  final H01Trace trace;
  @override
  Future<AuthSession> attest(AuthSession session) async {
    if (session.isOffline) {
      throw StateError('H01 session harus online untuk verifikasi.');
    }
    final response = await http.get<Map<String, dynamic>>(
      '/development/profile-v1',
      options: Options(headers: {'Authorization': 'Bearer ${session.token}'}),
    );
    final s = response.data;
    if (s == null ||
        s['profile'] != profile ||
        s['scope'] != 'profile-v1/$profile' ||
        s['database'] != 'profile_v1_$profile' ||
        s['host'] != '127.0.0.1' ||
        s['port'] != 55801 ||
        s['marker'] != 'NOTARIS PROFILE V1 DISPOSABLE $profile' ||
        s['account_id'] != session.userId ||
        s['group_id'] != session.groupId ||
        s['cloud_sync'] != false) {
      throw StateError('H01 active connection/account attestation ditolak.');
    }
    return session;
  }

  @override
  Future<AuthSession?> restoreSession() async {
    final session = await super.restoreSession();
    trace.record({'event': 'restore', 'restored': session != null});
    return session;
  }
}

Future<Widget> h01AcceptanceApplication(
  String id,
  String hash,
  Widget application,
) async {
  if (!kDebugMode || !Platform.isWindows) {
    throw StateError('H01 Windows debug saja.');
  }
  final root = profileV1AcceptanceRoot(id);
  final marker = File(p.join(root.path, 'h01-owner'));
  if (!marker.existsSync() ||
      marker.resolveSymbolicLinksSync() != marker.path ||
      marker.readAsStringSync() != id ||
      !File(p.join(root.path, 'h01-baseline.json')).existsSync()) {
    throw StateError('Profil H01 baru terverifikasi diperlukan.');
  }
  final helper = File(p.join(root.path, 'session.exe'));
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(hash) ||
      helper.resolveSymbolicLinksSync() != helper.path ||
      sha256.convert(await helper.readAsBytes()).toString() != hash) {
    throw StateError('Pin helper H01 ditolak.');
  }
  final result = await Process.run(helper.path, ['h01-validate', id]);
  if (result.exitCode != 0) throw StateError('DPAPI/manifest H01 ditolak.');
  final proof = jsonDecode(result.stdout as String) as Map;
  if (proof['Profile'] != id ||
      proof['Scope'] != 'profile-v1/$id' ||
      proof['BaseURL'] != h01AcceptanceURL ||
      proof['Database'] != 'profile_v1_$id' ||
      proof['Port'] != 55801 ||
      proof['Schema'] != 27 ||
      proof['Catalog'] != 'profile-v1') {
    throw StateError('Scope manifest H01 ditolak.');
  }
  final file = File(p.join(root.path, 'offline.sqlite'));
  if (!file.existsSync() || file.resolveSymbolicLinksSync() != file.path) {
    throw StateError('SQLite H01 tidak sah.');
  }
  final db = MateraiProfileDatabase(
    NativeDatabase(
      file,
      enableMigrations: false,
      setup: (sqlite) {
        if (sqlite.select('PRAGMA user_version').single.values.single != 27) {
          throw StateError('H01 v27 diperlukan.');
        }
        sqlite.execute('PRAGMA foreign_keys=ON');
        sqlite.execute('PRAGMA query_only=ON');
      },
    ),
  );
  await db.customSelect('SELECT 1').get();
  final trace = H01Trace(File(p.join(root.path, 'h01-events.jsonl')));
  trace.record({
    'event': 'entrypoint',
    'entry': 'lib/main.dart',
    'ui_smoke': false,
    'isolated_manual_configuration': false,
    'unix_ms': DateTime.now().millisecondsSinceEpoch,
    'launch': const String.fromEnvironment('NOTARIS_H01_LAUNCH'),
  });
  WidgetsBinding.instance.addObserver(trace);
  final authHttp = h01ReadOnlyHttp(trace),
      auth = H01Auth(h01ReadOnlyHttp(trace), id, trace);
  return ProviderScope(
    observers: [trace],
    overrides: [
      appDatabaseProvider.overrideWith((ref) {
        ref.onDispose(() => WidgetsBinding.instance.removeObserver(trace));
        ref.onDispose(db.close);
        return db;
      }),
      dioProvider.overrideWith((ref) {
        ref.onDispose(authHttp.close);
        return authHttp;
      }),
      authenticatedDioProvider.overrideWith((ref) {
        final http = h01ReadOnlyHttp(trace);
        installAuthenticatedSessionInterceptor(
          http,
          baseUrl: h01AcceptanceURL,
          currentSession: () => ref.read(authControllerProvider).session,
          onRejected: (status, token) => ref
              .read(authControllerProvider.notifier)
              .handleApiRejection(status, token),
        );
        ref.onDispose(http.close);
        return http;
      }),
      authServiceProvider.overrideWith((ref) {
        ref.onDispose(auth.http.close);
        return auth;
      }),
      profileEditingEnabledProvider.overrideWithValue(false),
      profileEditingExplanationProvider.overrideWithValue(
        'H01 read-only: perubahan akun tidak diizinkan.',
      ),
    ],
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Banner(
        message: 'H01 DEMONSTRASI · SYNC OTOMATIS OFF',
        location: BannerLocation.topEnd,
        child: application,
      ),
    ),
  );
}
