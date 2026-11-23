import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Only overridden by the explicit Windows notarisdev entry point.
final developmentUiSmokeProvider = Provider<bool>((ref) => false);

void installDevelopmentSmokeHttpGuard(Dio dio) {
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (request, handler) {
        // Existing login only authenticates; no business mutation is permitted.
        final login =
            request.method == 'POST' &&
            request.uri.path == '/api/v1/auth/login';
        if (request.uri.origin != 'http://127.0.0.1:8081' ||
            (request.method != 'GET' && !login)) {
          return handler.reject(
            DioException(
              requestOptions: request,
              error: 'UI smoke mode: synchronization and data writes disabled',
            ),
          );
        }
        request.followRedirects = false;
        handler.next(request);
      },
    ),
  );
}
