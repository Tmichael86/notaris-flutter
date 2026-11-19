import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final target = Uri.tryParse(baseDio.options.baseUrl);
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
        final session = ref.read(authControllerProvider).session;
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
            await ref
                .read(authControllerProvider.notifier)
                .handleApiRejection(status!, authorization.substring(7));
          } on Object {
            /* Preserve the original HTTP failure. */
          }
        }
        handler.next(error);
      },
    ),
  );

  ref.onDispose(dio.close);

  return dio;
});
