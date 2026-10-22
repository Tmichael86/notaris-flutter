
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_providers.dart';
import 'auth_provider.dart';

/// Dio untuk endpoint API yang membutuhkan autentikasi.
///
/// Dio dasar tetap dipakai oleh AuthService untuk login dan pemulihan sesi,
/// sehingga tidak terjadi dependency cycle antara autentikasi dan API client.
final authenticatedDioProvider = Provider<Dio>((ref) {
  final baseDio = ref.watch(dioProvider);
  final dio = Dio(baseDio.options);

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = ref.read(authControllerProvider).session?.token;

        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        } else {
          options.headers.remove('Authorization');
        }

        handler.next(options);
      },
    ),
  );

  ref.onDispose(dio.close);

  return dio;
});
