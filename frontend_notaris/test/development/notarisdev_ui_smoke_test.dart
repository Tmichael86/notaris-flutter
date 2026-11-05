import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart' hide Fake;
import 'package:frontend_notaris/providers/development_smoke_provider.dart';
import 'package:frontend_notaris/providers/authenticated_api_provider.dart';
import 'package:frontend_notaris/providers/app_providers.dart';
import 'package:frontend_notaris/providers/pekerjaan_provider.dart';
import 'package:frontend_notaris/services/session_sync_controller.dart';

import '../repositories/petugas_local_sync_test.dart' show Fake, reply;

void main() {
  test('smoke startup/resume/manual never resolve sync repositories', () async {
    var touched = 0;
    final container = ProviderContainer(
      overrides: [
        developmentUiSmokeProvider.overrideWithValue(true),
        pekerjaanKategoriRepositoryProvider.overrideWith((ref) {
          touched++;
          throw StateError('Sync must not start');
        }),
      ],
    );
    addTearDown(container.dispose);
    final sync = container.read(syncCoordinatorProvider);
    // Also protects callers bypassing the shell startup/resume guard.
    final controller = SessionSyncController(
      synchronize: sync.synchronizeNow,
      resumeCooldown: Duration.zero,
    );
    controller.start();
    await Future<void>.delayed(Duration.zero);
    controller.onAppResumed();
    await Future<void>.delayed(Duration.zero);
    await sync.synchronizeNow();
    controller.dispose();
    expect(touched, 0);
  });

  test('normal mode still executes existing synchronization', () async {
    var touched = 0;
    final container = ProviderContainer(
      overrides: [
        pekerjaanKategoriRepositoryProvider.overrideWith((ref) {
          touched++;
          throw StateError('Normal sync reached repository');
        }),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(developmentUiSmokeProvider), false);
    await expectLater(
      container.read(syncCoordinatorProvider).synchronizeNow(),
      throwsA(anything),
    );
    expect(touched, 1);
  });

  test(
    'base smoke client allows GET/login but blocks every business write',
    () async {
      var sent = 0;
      final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8081/api/v1'));
      installDevelopmentSmokeHttpGuard(dio);
      dio.httpClientAdapter = Fake((request) async {
        sent++;
        expect(request.followRedirects, false);
        return reply({'success': true});
      });
      addTearDown(() => dio.close(force: true));
      await dio.get<Object?>('/auth/me/sidebar-access');
      await dio.post<Object?>('/auth/login', data: {'username': 'fixture'});
      for (final path in [
        '/kategori-pekerjaan',
        '/jenis-pengeluaran',
        '/pemohon',
        '/petugas/sync/uuid',
      ]) {
        for (final method in ['POST', 'PUT', 'PATCH', 'DELETE']) {
          await expectLater(
            dio.request<Object?>(path, options: Options(method: method)),
            throwsA(isA<DioException>()),
          );
        }
      }
      await expectLater(
        dio.get<Object?>('http://example.invalid/api/v1/auth/login'),
        throwsA(isA<DioException>()),
      );
      expect(sent, 2);
    },
  );

  test(
    'authenticated Dio clone retains smoke write boundary before auth lookup',
    () async {
      final container = ProviderContainer(
        overrides: [
          developmentUiSmokeProvider.overrideWithValue(true),
          dioProvider.overrideWith(
            (ref) => Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8081/api/v1')),
          ),
        ],
      );
      addTearDown(container.dispose);
      final dio = container.read(authenticatedDioProvider);
      dio.httpClientAdapter = Fake(
        (request) async => throw StateError('Network must not be reached'),
      );
      await expectLater(
        dio.put<Object?>('/petugas/sync/uuid'),
        throwsA(isA<DioException>()),
      );
    },
  );
}
