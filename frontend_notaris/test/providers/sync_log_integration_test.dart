import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart' hide Fake;
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/providers/app_providers.dart';
import 'package:frontend_notaris/providers/database_provider.dart';
import 'package:frontend_notaris/providers/authenticated_api_provider.dart';
import 'package:frontend_notaris/providers/pekerjaan_provider.dart';
import 'package:frontend_notaris/providers/development_smoke_provider.dart';

import '../repositories/petugas_local_sync_test.dart' show Fake;

void main() {
  for (final smoke in [false, true]) {
    test(
      'global deny opens neither SQLite nor either Dio; smoke=$smoke',
      () async {
        var touched = 0;
        final c = ProviderContainer(
          overrides: [
            developmentUiSmokeProvider.overrideWithValue(smoke),
            appDatabaseProvider.overrideWith((ref) {
              touched++;
              throw StateError('must not open');
            }),
            dioProvider.overrideWith((ref) {
              touched++;
              throw StateError('must not resolve base HTTP');
            }),
            authenticatedDioProvider.overrideWith((ref) {
              touched++;
              throw StateError('must not clone HTTP');
            }),
          ],
        );
        addTearDown(c.dispose);
        await expectLater(
          c.read(syncCoordinatorProvider).synchronizeNow(),
          throwsA(isA<SyncFailure>()),
        );
        expect(c.read(syncStatusProvider), SyncStatus.disabledByPolicy);
        expect(touched, 0);
      },
    );
  }
  test('different authenticated transport cannot escape global containment or fabricate logs', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'http://fixture.invalid/api/v1'));
    dio.httpClientAdapter = Fake((r) async {
      requests.add(r);
      throw StateError('unexpected network');
    });
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        authenticatedDioProvider.overrideWithValue(dio),
      ],
    );
    await db.customStatement(
      "INSERT INTO sync_logs(operation_id,attempt_id,module,direction,started_at,status,error_code,error_message) VALUES('old','old','transaksi_ppat','push','2026-01-01','failed','conflict','Riwayat 409')",
    );
    final before = await db.customSelect('SELECT * FROM sync_logs').get();
    await expectLater(
      c.read(pekerjaanKategoriControllerProvider.notifier).synchronize(),
      throwsA(isA<SyncFailure>()),
    );
    expect(requests, isEmpty);
    expect(
      (await db.customSelect('SELECT * FROM sync_logs').get()).map(
        (r) => r.data,
      ),
      before.map((r) => r.data),
    );
    c.dispose();
    dio.close();
    await db.close();
  });
}
