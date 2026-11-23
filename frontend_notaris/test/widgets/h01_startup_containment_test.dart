import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart' hide Fake;
import 'package:frontend_notaris/main.dart';
import 'package:frontend_notaris/providers/app_providers.dart';
import 'package:frontend_notaris/providers/auth_provider.dart';
import 'package:frontend_notaris/providers/authenticated_api_provider.dart';
import 'package:frontend_notaris/providers/database_provider.dart';
import 'package:frontend_notaris/providers/development_smoke_provider.dart';
import 'package:frontend_notaris/providers/isolated_transaction_profile_provider.dart';
import 'package:frontend_notaris/providers/pekerjaan_provider.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/services/auth_service.dart';
import 'package:frontend_notaris/services/transaction_manual_sync_service.dart';

import '../repositories/petugas_local_sync_test.dart' show Fake, reply;
import '../support/transaction_ui_test_support.dart';

Future<String> stateFingerprint(AppDatabase db) async {
  final tables = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
      )
      .get();
  final rows = <String, Object?>{};
  for (final table in tables) {
    final name = table.read<String>('name');
    rows[name] =
        (await db
                .customSelect('SELECT * FROM "${name.replaceAll('"', '""')}"')
                .get())
            .map((r) => jsonEncode(r.data))
            .toList()
          ..sort();
  }
  return jsonEncode(rows);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'normal app login/restoration/refresh/reconnect/resume/navigation never drain dirty state',
    (t) async {
      FlutterSecureStorage.setMockInitialValues({});
      await t.runAsync(() async {
        await (FontLoader('Roboto')
              ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf')))
            .load();
      });
      t.view.physicalSize = const Size(1366, 768);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final folder = Directory.systemTemp.createTempSync('h01-test-');
      final file = File('${folder.path}/a.sqlite')..createSync();
      final profile = TransactionManualProfile(
        sqlitePath: file.path,
        databaseTarget: 'disposable',
        accountId: 1,
        groupId: 1,
        device: 'device',
        generation: 'generation',
        deployment: 'deployment',
        baseUrl: 'http://fixture.invalid/api/v1',
      );
      await t.runAsync(() async {
        await seedTransactionUiReferences(db, profile);
        await createTransactionUiRecord(db, 'notaris');
        await createTransactionUiRecord(db, 'ppat');
        await db.customStatement(
          "UPDATE pekerjaan_kategori SET is_sync_dirty=1",
        );
        await db.customStatement(
          "INSERT INTO pengeluaran_jenis(uuid,nama,is_sync_dirty) VALUES('00000000-0000-4000-8000-000000000090','Jenis pending',1)",
        );
        await db.customStatement(
          "INSERT INTO transaction_cloud_feed(scope,cursor) VALUES('h01/transactions',9)",
        );
      });
      await t.runAsync(() async {
        final parents = await db.select(db.transaksis).get();
        await db.customStatement(
          "INSERT INTO transaction_cloud_pending(local_uuid,mutation_id,payload,state) VALUES(?,'00000000-0000-4000-8000-000000000081','{\"immutable\":true}','pending')",
          [parents.first.uuid],
        );
        await db.customStatement(
          "INSERT INTO transaction_cloud_identity(local_uuid,cloud_uuid,scope,revision,final_number,snapshot) VALUES(?,?,'h01/transactions',1,?,'{}')",
          [parents.last.uuid, parents.last.uuid, parents.last.noAkta],
        );
        await db.customStatement(
          "INSERT INTO transaction_cloud_pending(local_uuid,mutation_id,payload,state) VALUES(?,'00000000-0000-4000-8000-000000000082','{}','acked')",
          [parents.last.uuid],
        );
      });
      final before = await t.runAsync(() => stateFingerprint(db));
      final calls = <String>[];
      var offline = false;
      final dio = Dio(BaseOptions(baseUrl: 'http://fixture.invalid/api/v1'));
      dio.httpClientAdapter = Fake((r) async {
        calls.add('${r.method} ${r.uri.path}');
        if (offline) {
          throw DioException(
            requestOptions: r,
            type: DioExceptionType.connectionError,
          );
        }
        if (r.method == 'POST' && r.path == '/auth/login') {
          return reply({
            'data': {'token': 'h01-unit-token'},
          });
        }
        if (r.method == 'GET' && r.path == '/auth/me/sidebar-access') {
          return reply({
            'data': {
              'user': {'id': 1, 'group_id': 1, 'nama': 'Petugas H01'},
              'sidebars': [],
            },
          });
        }
        throw StateError(
          'Unexpected endpoint, including GET mutations: ${r.method} ${r.path}',
        );
      });
      ProviderContainer container() => ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          dioProvider.overrideWithValue(dio),
          authServiceProvider.overrideWithValue(
            AuthService(dio: dio, cacheKey: 'h01-unit'),
          ),
        ],
      );
      var c = container();
      Future<void> mount() async {
        await t.pumpWidget(
          UncontrolledProviderScope(container: c, child: const MyApp()),
        );
        await cycleUi(t);
      }

      await mount();
      expect(c.read(developmentUiSmokeProvider), false);
      expect(c.read(isolatedTransactionSyncConfigurationProvider), isNull);
      await t.enterText(find.byType(TextFormField).at(0), 'h01');
      await t.enterText(
        find.byType(TextFormField).at(1),
        'not-a-real-credential',
      );
      await t.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await cycleUi(t);
      expect(c.read(authControllerProvider).session, isNotNull);
      expect(calls, [
        'POST /api/v1/auth/login',
        'GET /api/v1/auth/me/sidebar-access',
      ]);
      for (final active in [false, true]) {
        offline = active;
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await t.pump(const Duration(minutes: 16));
      }
      await t.runAsync(() async {
        await expectLater(
          c.read(authControllerProvider.notifier).refreshCurrentPermissions(),
          throwsA(isA<DioException>()),
        );
      });
      offline = false;
      await t.runAsync(
        () =>
            c.read(authControllerProvider.notifier).refreshCurrentPermissions(),
      );
      final authenticated = c.read(authenticatedDioProvider)
        ..httpClientAdapter = dio.httpClientAdapter;
      await t.runAsync(() => authenticated.get('/auth/me/sidebar-access'));
      await expectLater(
        c.read(syncCoordinatorProvider).synchronizeNow(),
        throwsA(isA<SyncFailure>()),
      );
      expect(c.read(syncStatusProvider), SyncStatus.disabledByPolicy);
      expect(find.text('Sinkronisasi awal berhasil.'), findsNothing);
      await t.tap(find.text('System').first);
      await cycleUi(t);
      await t.ensureVisible(find.text('Log Sinkronisasi').first);
      await t.tap(find.text('Log Sinkronisasi').first);
      await cycleUi(t);
      expect(find.text('Sinkronisasi awal berhasil.'), findsNothing);

      expect(await t.runAsync(() => stateFingerprint(db)), before);
      // Same encrypted-cache contract: process restart restores real AuthService,
      // then logout/new login cannot retain a queued sync operation.
      await t.pumpWidget(const SizedBox());
      c.dispose();
      c = container();
      await mount();
      expect(c.read(authControllerProvider).session, isNotNull);
      await t.runAsync(() => c.read(authControllerProvider.notifier).logout());
      await cycleUi(t);
      await t.runAsync(
        () => c
            .read(authControllerProvider.notifier)
            .login(username: 'next', password: 'not-real', rememberMe: false),
      );
      await cycleUi(t);
      await t.pump(const Duration(minutes: 16));
      expect(
        calls.where(
          (r) =>
              r != 'POST /api/v1/auth/login' &&
              r != 'GET /api/v1/auth/me/sidebar-access',
        ),
        isEmpty,
      );
      expect(await t.runAsync(() => stateFingerprint(db)), before);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      c.dispose();
      dio.close();
      await t.runAsync(db.close);
      folder.deleteSync(recursive: true);
    },
  );
}
