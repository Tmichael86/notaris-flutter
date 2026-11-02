import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart' hide Fake;
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/providers/database_provider.dart';
import 'package:frontend_notaris/providers/authenticated_api_provider.dart';
import 'package:frontend_notaris/providers/pekerjaan_provider.dart';
import 'package:frontend_notaris/providers/sync_log_provider.dart';
import 'package:frontend_notaris/providers/development_smoke_provider.dart';

import '../repositories/petugas_local_sync_test.dart' show Fake, reply;

void main() {
  test('real coordinator logs only reached modules; single flight retry preserves failure', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    var failed = true;
    var calls = 0;
    final dio = Dio(BaseOptions(baseUrl: 'http://fixture.invalid/api/v1'));
    dio.httpClientAdapter = Fake((request) async {
      calls++;
      expect(request.method, 'GET');
      if (failed) {
        return ResponseBody.fromString(
          '{}',
          403,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
      return reply({
        'success': true,
        'data': {
          'items': [],
          'pagination': {'has_more': false},
        },
      });
    });
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        authenticatedDioProvider.overrideWithValue(dio),
      ],
    );
    final sync = c.read(syncCoordinatorProvider);
    await expectLater(sync.synchronizeNow(), throwsA(anything));
    final logger = c.read(syncLogRepositoryProvider);
    expect((await logger.list()).single['status'], 'failed');
    expect((await logger.list()).single['module'], 'kategori');
    failed = false;
    final a = sync.synchronizeNow(), b = sync.synchronizeNow();
    expect(identical(a, b), true);
    await a;
    final rows = await logger.list();
    expect(rows.length, 4);
    expect(rows.where((r) => r['status'] == 'success').length, 3);
    expect(rows.where((r) => r['module'] == 'petugas'), isEmpty);
    expect(rows.first['record_count'], 0);
    expect(calls, 4);
    c.dispose();
    dio.close(force: true);
    await db.close();
  });
  test('smoke bypass opens neither log storage nor sync', () async {
    final c = ProviderContainer(
      overrides: [
        developmentUiSmokeProvider.overrideWithValue(true),
        appDatabaseProvider.overrideWith(
          (ref) => throw StateError('Must not open database'),
        ),
      ],
    );
    await c.read(syncCoordinatorProvider).synchronizeNow();
    c.dispose();
  });
}
