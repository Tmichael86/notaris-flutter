import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'providers/app_providers.dart';
import 'providers/auth_provider.dart';
import 'providers/authenticated_api_provider.dart';
import 'providers/database_provider.dart';
import 'providers/transaction_document_provider.dart';
import 'services/auth_service.dart';
import 'services/release_qa_profile.dart';

export 'services/release_qa_profile.dart';

Dio releaseQaDisconnectedHttp(ReleaseQaProfile profile) {
  final dio = Dio(
    BaseOptions(
      baseUrl: profile.configuration.endpoint,
      followRedirects: false,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (r, h) {
        profile.assertBound();
        profile.record('http_blocked', {
          'method': r.method,
          'reason': 'QA_BACKEND_UNCONFIGURED',
        });
        h.reject(
          DioException(
            requestOptions: r,
            type: DioExceptionType.connectionError,
            error:
                'Backend QA belum dikonfigurasi. Tidak ada koneksi jaringan.',
          ),
        );
      },
    ),
  );
  return dio;
}

class _QaObserver extends ProviderObserver {
  _QaObserver(this.profile);
  final ReleaseQaProfile profile;
  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    if (provider == authControllerProvider && newValue is AuthState) {
      profile.record('auth_state', {
        'status': newValue.status.name,
        'account': newValue.session?.userId,
        'group': newValue.session?.groupId,
      });
    }
  }
}

Future<Widget> releaseQaApplication(
  ReleaseQaConfiguration config,
  Widget application,
) async {
  config.validate();
  if (!kReleaseMode) throw StateError('qa_release_required');
  final support = await getApplicationSupportDirectory();
  final profile = await ReleaseQaProfile.open(
    config,
    applicationSupport: support,
  );
  return ProviderScope(
    observers: [_QaObserver(profile)],
    overrides: [
      appDatabaseProvider.overrideWith((ref) {
        ref.onDispose(profile.close);
        return profile.database;
      }),
      dioProvider.overrideWith((ref) {
        final dio = releaseQaDisconnectedHttp(profile);
        ref.onDispose(dio.close);
        return dio;
      }),
      authenticatedDioProvider.overrideWith((ref) {
        final dio = releaseQaDisconnectedHttp(profile);
        installAuthenticatedSessionInterceptor(
          dio,
          baseUrl: config.endpoint,
          currentSession: () => ref.read(authControllerProvider).session,
          onRejected: (status, token) => ref
              .read(authControllerProvider.notifier)
              .handleApiRejection(status, token),
        );
        ref.onDispose(dio.close);
        return dio;
      }),
      authServiceProvider.overrideWith(
        (ref) => AuthService(
          dio: ref.watch(dioProvider),
          cacheKey: profile.authKey,
          sessionCache: ReleaseQaSessionCache(profile),
        ),
      ),
      transactionDocumentProfileProvider.overrideWithValue((
        databasePath: profile.databasePath,
        appDirectory: profile.directory.path,
      )),
    ],
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        children: [
          Expanded(
            child: Banner(
              message: 'QA · v27',
              location: BannerLocation.topEnd,
              child: application,
            ),
          ),
          const ColoredBox(
            color: Color(0xfff5f1ed),
            child: SizedBox(
              height: 32,
              width: double.infinity,
              child: Center(
                child: Text(
                  'MY NOTARIS · QA terisolasi — Backend belum dikonfigurasi; login online belum tersedia.',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 12,
                    color: Color(0xff6c2835),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class ReleaseQaBlocked extends StatelessWidget {
  const ReleaseQaBlocked({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(
    home: Scaffold(
      body: Center(
        child: Text(
          'Startup QA diblokir. Konfigurasi atau binding profil tidak valid.\n'
          'Tidak ada fallback ke database atau sesi lama.',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}
