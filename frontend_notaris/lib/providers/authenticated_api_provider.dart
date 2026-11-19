import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_session.dart';
import 'app_providers.dart';
import 'auth_provider.dart';
import 'development_smoke_provider.dart';

/// Dio untuk endpoint API yang membutuhkan autentikasi.
///
/// Dio dasar tetap dipakai oleh AuthService untuk login dan pemulihan sesi,
/// sehingga tidak terjadi dependency cycle antara autentikasi dan API client.
final authenticatedDioProvider = Provider<Dio>((ref) {
  final baseDio = ref.watch(dioProvider);
  final dio = Dio(baseDio.options);
  if (ref.watch(developmentUiSmokeProvider)) {
    installDevelopmentSmokeHttpGuard(dio);
  }

  installAuthenticatedSessionInterceptor(
    dio,
    baseUrl: baseDio.options.baseUrl,
    currentSession: () => ref.read(authControllerProvider).session,
    onRejected: (status, token) => ref
        .read(authControllerProvider.notifier)
        .handleApiRejection(status, token),
  );

  ref.onDispose(dio.close);

  return dio;
});

/// Shared P0 online session behavior for independently verified isolated clients.
/// This does not remove or override a client's environment/UiSmoke guard.
void installAuthenticatedSessionInterceptor(
  Dio dio, {
  required String baseUrl,
  required AuthSession? Function() currentSession,
  required Future<void> Function(int, String) onRejected,
}) {
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final target = Uri.tryParse(baseUrl);
        if (target == null ||
            !target.hasAuthority ||
            options.uri.origin != target.origin) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.cancel,
              error: 'Target autentikasi tidak cocok dengan profil aktif.',
            ),
          );
          return;
        }
        final session = currentSession();
        final token = session?.token;
        final path = options.uri.path.replaceFirst(RegExp(r'^/api/v1'), '');
        final administrative =
            path == '/users' ||
            path.startsWith('/users/') ||
            ((path == '/groups' || path.startsWith('/groups/')) &&
                options.method != 'GET');
        if (administrative && session?.canUseOnlineAdministration != true) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.cancel,
              error: 'Administrasi memerlukan sesi Superadmin online yang masih valid.',
            ),
          );
          return;
        }

        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        } else {
          options.headers.remove('Authorization');
        }

        handler.next(options);
      },
      onError: (error, handler) async {
        final status = error.response?.statusCode;
        final authorization = error.requestOptions.headers['Authorization'];
        if ((status == 401 || status == 403) &&
            authorization is String &&
            authorization.startsWith('Bearer ')) {
          try {
            await onRejected(status!, authorization.substring(7));
          } on Object {
            /* Preserve the original HTTP failure. */
          }
        }
        handler.next(error);
      },
    ),
  );
}
