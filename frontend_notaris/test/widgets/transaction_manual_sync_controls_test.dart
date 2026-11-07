import 'dart:async';

import 'package:flutter/services.dart';

import 'dart:io';
import 'dart:convert';

import 'package:frontend_notaris/transaction_monitor_isolated_main.dart'
    show loadIsolatedTransactionUiProfile;

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/models/auth_session.dart';
import 'package:frontend_notaris/providers/auth_provider.dart';
import 'package:frontend_notaris/providers/app_providers.dart';
import 'package:frontend_notaris/providers/pekerjaan_provider.dart';
import 'package:frontend_notaris/services/session_sync_controller.dart';
import 'package:frontend_notaris/providers/database_provider.dart';
import 'package:frontend_notaris/providers/development_smoke_provider.dart';
import 'package:frontend_notaris/providers/sync_monitor_provider.dart';
import 'package:frontend_notaris/providers/transaction_manual_sync_provider.dart';
import 'package:frontend_notaris/repositories/sync_log_repository.dart';
import 'package:frontend_notaris/screens/sync_monitor_desktop_screen.dart';
import 'package:frontend_notaris/services/transaction_manual_sync_service.dart';

import '../services/transaction_manual_sync_service_test.dart' show Transport;
import '../support/transaction_ui_test_support.dart';

void main() {
  late Directory folder;
  late AppDatabase db;
  late TransactionManualProfile profile;
  late Dio http;
  late Transport transport;
  late List<ProviderContainer> containers;
  final scopedDatabases = <AppDatabase>[];
  late int notarisId, ppatId;
  setUp(() async {
    folder = await Directory.systemTemp.createTemp('transaction_manual_ui_');
    db = AppDatabase.forTesting(
      NativeDatabase(File('${folder.path}/a.sqlite')),
    );
    profile = TransactionManualProfile(
      sqlitePath: '${folder.path}/a.sqlite',
      baseUrl: 'http://127.0.0.1:18081/api/v1',
      databaseTarget: '127.0.0.1:55452/notaris_publish_test_ui',
      deployment: 'widget-disposable',
      device: 'a',
      generation: 'widget-v1',
      accountId: 1,
      groupId: 1,
    );
    transport = Transport();
    http = Dio(BaseOptions(baseUrl: profile.baseUrl))
      ..httpClientAdapter = transport;
    containers = [];
    await seedTransactionUiReferences(db, profile);
    notarisId = await createTransactionUiRecord(db, 'notaris');
    ppatId = await createTransactionUiRecord(db, 'ppat');
  });
  tearDown(() async {
    for (final c in containers) {
      c.dispose();
    }
    http.close();
    for (final scoped in scopedDatabases) {
      await scoped.close();
    }
    scopedDatabases.clear();
    await db.close();
    await folder.delete(recursive: true);
  });
  Future<ProviderContainer> mount(
    WidgetTester t, {
    bool normal = false,
    bool smoke = false,
    AuthSession? session,
  }) async {
    t.view.physicalSize = const Size(1400, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final config = normal
        ? null
        : IsolatedTransactionSyncConfiguration.open(
            profile: profile,
            http: http,
          );
    if (config != null) scopedDatabases.add(config.database);
    final c = ProviderContainer(
      overrides: [
        if (normal)
          appDatabaseProvider.overrideWith(
            (_) => throw StateError('Normal database must not resolve'),
          ),

        if (normal) syncMonitorProvider.overrideWith((_) async => []),
        authControllerProvider.overrideWith(
          (_) => TransactionUiAuth(session ?? uiSession()),
        ),
        developmentUiSmokeProvider.overrideWithValue(smoke),
        if (!normal)
          isolatedTransactionSyncConfigurationProvider.overrideWithValue(
            config,
          ),
      ],
    );
    containers.add(c);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
          home: Scaffold(body: SyncMonitorDesktopScreen()),
        ),
      ),
    );
    await cycleUi(t);
    return c;
  }

  for (final domain in ['notaris', 'ppat']) {
    testWidgets(
      '$domain actual record confirmation and single flight calls correct service/HTTP only',
      (t) async {
        await mount(t);
        await chooseUiModule(
          t,
          domain == 'ppat' ? 'Transaksi PPAT' : 'Transaksi Notaris',
        );
        await chooseUiRecord(t, 'transaksi_$domain');
        expect(find.byType(TextField), findsOneWidget);
        expect(
          find.byKey(const Key('manual-sync-record-identity')),
          findsOneWidget,
        );
        final waiting = Completer<void>();
        transport.respond = (o) async {
          await waiting.future;
          final b = o.data as Map;
          return Transport.json({
            'acknowledgement': {
              'uuid': b['uuid'],
              'mutation_id': b['mutation_id'],
              'revision': 1,
              'final_number': domain == 'ppat'
                  ? '2000611260001'
                  : '1000611260001',
            },
          }, 200);
        };
        final click = t
            .widget<FilledButton>(find.byKey(const Key('manual-sync-execute')))
            .onPressed!;
        click();
        click();
        await t.pumpAndSettle();
        expect(find.byKey(const Key('manual-sync-dialog')), findsOneWidget);
        expect(transport.calls, 0);
        await t.tap(find.byKey(const Key('confirm-transaction-upload')));
        await cycleUi(t);
        expect(transport.calls, 1);
        expect(
          t
              .widget<FilledButton>(
                find.byKey(const Key('manual-sync-execute')),
              )
              .onPressed,
          isNull,
        );
        click();
        expect(transport.calls, 1);
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pump();
        expect(find.byKey(const Key('manual-sync-dialog')), findsOneWidget);
        waiting.complete();
        await cycleUi(t);
        expect(
          find.textContaining('Upload terkonfirmasi: 1 record'),
          findsOneWidget,
        );
        final rows = await t.runAsync(() => SyncLogRepository(db).list());
        expect(rows!.length, 1);
        expect(rows.single['module'], 'transaksi_$domain');
        expect(rows.single['status'], 'success');
        final selected = await t.runAsync(
          () =>
              (db.select(db.transaksis)..where(
                    (r) => r.id.equals(domain == 'ppat' ? ppatId : notarisId),
                  ))
                  .getSingle(),
        );
        final other = await t.runAsync(
          () =>
              (db.select(db.transaksis)..where(
                    (r) => r.id.equals(domain == 'ppat' ? notarisId : ppatId),
                  ))
                  .getSingle(),
        );
        expect(selected!.isSyncDirty, false);
        expect(other!.isSyncDirty, true);
        expect(
          find.textContaining('ACK belum membuktikan publication'),
          findsWidgets,
        );
      },
    );
  }
  testWidgets(
    'search uses actual records, radio is single, confirmation ESC and resize are safe',
    (t) async {
      await mount(t);
      await chooseUiModule(t, 'Transaksi Notaris');
      final search = find.byKey(
        const Key('manual-sync-search-transaksi_notaris'),
      );
      await t.enterText(search, 'does-not-exist');
      await t.pump();
      expect(
        find.text('Tidak ada transaksi sesuai pencarian.'),
        findsOneWidget,
      );
      expect(find.byType(RadioListTile<int>), findsNothing);
      await t.enterText(search, '');
      await t.pump();
      await chooseUiRecord(t, 'transaksi_notaris');
      expect(
        t.widget<RadioGroup<int>>(find.byType(RadioGroup<int>)).groupValue,
        notarisId,
      );
      await t.tap(find.byKey(const Key('manual-sync-execute')));
      await t.pumpAndSettle();
      expect(
        find.byKey(const Key('confirm-transaction-upload')),
        findsOneWidget,
      );
      expect(find.byType(Dialog), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('manual-sync-dialog')), findsOneWidget);
      expect(find.byKey(const Key('confirm-transaction-upload')), findsNothing);
      for (final size in [
        const Size(1366, 768),
        const Size(1920, 1080),
        const Size(600, 620),
        const Size(420, 560),
      ]) {
        t.view.physicalSize = size;
        await t.pumpAndSettle();
        final surface = t.getRect(find.byKey(const Key('manual-sync-surface')));
        expect(surface.width, lessThanOrEqualTo(720));
        if (size.width >= 1366) {
          expect(surface.width, 720);
          final selection = t.getRect(
            find.byKey(const Key('manual-sync-module')),
          );
          final summary = t.getRect(
            find.byKey(const Key('manual-sync-summary')),
          );
          expect(summary.left, greaterThan(selection.right));
          expect(surface.height, lessThan(size.height - 48));
        }
        expect(surface.right, lessThanOrEqualTo(size.width));
        expect(surface.bottom, lessThanOrEqualTo(size.height));
        expect(t.takeException(), isNull);
      }
      await t.tap(find.byKey(const Key('close-manual-sync')));
      await t.pumpAndSettle();
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(transport.calls, 0);
    },
  );
  for (final acked in [false, true]) {
    testWidgets(
      '${acked ? 'ACKed' : 'clean'} record is disabled with an explicit reason',
      (t) async {
        await t.runAsync(() async {
          if (acked) {
            final row = await (db.select(
              db.transaksis,
            )..where((r) => r.id.equals(notarisId))).getSingle();
            await db.customStatement(
              "INSERT INTO transaction_cloud_pending(local_uuid,mutation_id,payload,state) VALUES(?,?,?,?)",
              [row.uuid, '00000000-0000-4000-8000-000000000099', '{}', 'acked'],
            );
          } else {
            await db.customStatement(
              'UPDATE transaksis SET is_sync_dirty=0 WHERE id=?',
              [notarisId],
            );
            for (final table in [
              'transaksi_details',
              'transaksi_proses',
              'transaksi_riwayat_pembayaran',
            ]) {
              await db.customStatement(
                'UPDATE $table SET is_sync_dirty=0 WHERE transaksi_id=?',
                [notarisId],
              );
            }
          }
        });
        await mount(t);
        await chooseUiModule(t, 'Transaksi Notaris');
        expect(
          t
              .widget<RadioListTile<int>>(
                find.byKey(ValueKey('manual-sync-choice-$notarisId')),
              )
              .enabled,
          false,
        );
        expect(
          find.textContaining(acked ? 'ACK tersimpan' : 'Data bersih'),
          findsOneWidget,
        );
        expect(
          t
              .widget<FilledButton>(
                find.byKey(const Key('manual-sync-execute')),
              )
              .onPressed,
          isNull,
        );
        expect(transport.calls, 0);
      },
    );
  }
  testWidgets('cancel and stale selected UUID never upload another record', (
    t,
  ) async {
    await mount(t);
    await chooseUiModule(t, 'Transaksi Notaris');
    await chooseUiRecord(t, 'transaksi_notaris');
    await t.tap(find.byKey(const Key('manual-sync-execute')));
    await t.pumpAndSettle();
    await t.tap(find.text('Batal'));
    await cycleUi(t);
    expect(transport.calls, 0);
    await t.tap(find.byKey(const Key('manual-sync-execute')));
    await t.pumpAndSettle();
    await t.runAsync(
      () => db.customStatement(
        "UPDATE transaksis SET uuid='00000000-0000-4000-8000-000000000099' WHERE id=?",
        [notarisId],
      ),
    );
    await t.tap(find.byKey(const Key('confirm-transaction-upload')));
    await cycleUi(t);
    expect(transport.calls, 0);
    expect(find.textContaining('409 / dirty conflict'), findsOneWidget);
  });
  testWidgets(
    'normal config never resolves execution database and direct controller is blocked',
    (t) async {
      final c = await mount(t, normal: true);
      await chooseUiModule(t, 'Transaksi (feed gabungan)');
      expect(
        t
            .widget<FilledButton>(find.byKey(const Key('manual-sync-execute')))
            .onPressed,
        isNull,
      );
      await c
          .read(isolatedTransactionSyncControllerProvider.notifier)
          .execute(
            module: 'transaksi',
            direction: ManualSyncDirection.download,
          );
      await cycleUi(t);
      expect(transport.calls, 0);
      expect(find.textContaining('Profil/target tidak cocok'), findsOneWidget);
    },
  );
  for (final smoke in [true, false]) {
    testWidgets(
      smoke
          ? 'UI Smoke and direct service deny both directions'
          : 'invalid permission prevents UI and direct execution',
      (t) async {
        final c = await mount(
          t,
          smoke: smoke,
          session: uiSession(permission: smoke),
        );
        await chooseUiModule(t, 'Transaksi (feed gabungan)');
        expect(
          t
              .widget<FilledButton>(
                find.byKey(const Key('manual-sync-execute')),
              )
              .onPressed,
          isNull,
        );
        await t.runAsync(
          () => c
              .read(isolatedTransactionSyncControllerProvider.notifier)
              .execute(
                module: 'transaksi',
                direction: ManualSyncDirection.download,
              ),
        );
        await cycleUi(t);
        expect(transport.calls, 0);
        final service = c.read(isolatedTransactionSyncServiceProvider)!;
        for (final d in ManualSyncDirection.values) {
          await t.runAsync(
            () => expectLater(
              service.run(
                selectedModule: d == ManualSyncDirection.upload
                    ? 'transaksi_notaris'
                    : 'transaksi',
                direction: d,
                transactionId: d == ManualSyncDirection.upload
                    ? notarisId
                    : null,
              ),
              throwsA(
                isA<ManualTransactionFailure>().having(
                  (e) => e.code,
                  'code',
                  'forbidden',
                ),
              ),
            ),
          );
        }
        final logs = await t.runAsync(
          () => SyncLogRepository(db).list(status: 'failed'),
        );
        expect(logs, isNotEmpty);
      },
    );
  }
  for (final status in [409, 410]) {
    testWidgets('$status failure stays in Log and Monitoring after restart', (
      t,
    ) async {
      await mount(t);
      transport.respond = (_) async =>
          Transport.json({'message': 'private JWT payload'}, status);
      await chooseUiModule(
        t,
        status == 409 ? 'Transaksi Notaris' : 'Transaksi (feed gabungan)',
      );
      if (status == 409) {
        await chooseUiRecord(t, 'transaksi_notaris');
        await t.tap(find.byKey(const Key('manual-sync-execute')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('confirm-transaction-upload')));
      } else {
        await t.tap(find.byKey(const Key('manual-sync-execute')));
      }
      await cycleUi(t);
      expect(find.byKey(const Key('manual-sync-feedback')), findsOneWidget);
      expect(find.textContaining('$status'), findsWidgets);
      final logs = await t.runAsync(() => SyncLogRepository(db).list());
      expect(logs!.single['status'], 'failed');
      expect(logs.toString(), isNot(contains('private JWT')));
      await t.pumpWidget(const SizedBox());
      for (final c in containers) {
        c.dispose();
      }
      containers = [];
      await t.runAsync(db.close);
      db = AppDatabase.forTesting(NativeDatabase(File(profile.sqlitePath)));
      await mount(t);
      expect(find.text('Perlu penanganan'), findsWidgets);
      expect(
        (await t.runAsync(() => SyncLogRepository(db).list(status: 'failed')))!
            .length,
        1,
      );
    });
  }
  testWidgets('empty upload list cannot execute', (t) async {
    for (final table in [
      'transaksi_proses',
      'transaksi_riwayat_pembayaran',
      'transaksi_details',
      'transaksis',
    ]) {
      await db.customStatement('DELETE FROM $table');
    } // Own disposable fixture only.
    await mount(t);
    await chooseUiModule(t, 'Transaksi Notaris');
    expect(find.textContaining('Belum ada transaksi lokal'), findsOneWidget);
    expect(
      t
          .widget<FilledButton>(find.byKey(const Key('manual-sync-execute')))
          .onPressed,
      isNull,
    );
  });
  testWidgets(
    'runtime generation mismatch and forbidden target factory stay blocked',
    (t) async {
      final bad = TransactionManualProfile(
        sqlitePath: profile.sqlitePath,
        baseUrl: 'http://127.0.0.1:8081/api/v1',
        databaseTarget: profile.databaseTarget,
        deployment: profile.deployment,
        device: profile.device,
        generation: profile.generation,
        accountId: 1,
        groupId: 1,
      );
      expect(
        () =>
            IsolatedTransactionSyncConfiguration.open(profile: bad, http: http),
        throwsA(isA<ManualTransactionFailure>()),
      );
      profile = TransactionManualProfile(
        sqlitePath: profile.sqlitePath,
        baseUrl: profile.baseUrl,
        databaseTarget: profile.databaseTarget,
        deployment: profile.deployment,
        device: profile.device,
        generation: 'changed-generation',
        accountId: 1,
        groupId: 1,
      );
      final c = await mount(t);
      await chooseUiModule(t, 'Transaksi (feed gabungan)');
      expect(
        t
            .widget<FilledButton>(find.byKey(const Key('manual-sync-execute')))
            .onPressed,
        isNull,
      );
      await t.runAsync(
        () => c
            .read(isolatedTransactionSyncControllerProvider.notifier)
            .execute(
              module: 'transaksi',
              direction: ManualSyncDirection.download,
            ),
      );
      await cycleUi(t);
      expect(transport.calls, 0);
      expect(find.textContaining('Profil/target tidak cocok'), findsWidgets);
    },
  );
  test('configuration owns its SQLite/auth scope; startup resume and global manual stay blocked', () async {
    final config = IsolatedTransactionSyncConfiguration.open(
      profile: profile,
      http: http,
    );
    scopedDatabases.add(config.database);
    var touched = 0;
    final c = ProviderContainer(
      overrides: [
        isolatedTransactionSyncConfigurationProvider.overrideWithValue(config),
        authControllerProvider.overrideWith(
          (_) => TransactionUiAuth(uiSession()),
        ),
        pekerjaanKategoriRepositoryProvider.overrideWith((_) {
          touched++;
          throw StateError('Global sync prohibited');
        }),
      ],
    );
    containers.add(c);
    expect(c.read(appDatabaseProvider), same(config.database));
    expect(
      c.read(authServiceProvider).cacheKey,
      startsWith('notaris.isolated.'),
    );
    await expectLater(
      c.read(dioProvider).post('/pemohon/sync/private'),
      throwsA(isA<DioException>()),
    );
    expect(transport.calls, 0);
    final coordinator = c.read(syncCoordinatorProvider);
    final session = SessionSyncController(
      synchronize: coordinator.synchronizeNow,
      resumeCooldown: Duration.zero,
    );
    session.start();
    await Future<void>.delayed(Duration.zero);
    session.onAppResumed();
    await Future<void>.delayed(Duration.zero);
    await coordinator.synchronizeNow();
    session.dispose();
    expect(touched, 0);
    await c
        .read(isolatedTransactionSyncServiceProvider)!
        .run(
          selectedModule: 'transaksi_notaris',
          direction: ManualSyncDirection.upload,
          transactionId: notarisId,
        );
    expect(transport.calls, 1);
  });
  test('explicit entry loads only same-directory disposable manifest without credentials', () async {
    final manifest = File('${folder.path}/profile.json');
    await manifest.writeAsString(
      jsonEncode({
        'sqlitePath': profile.sqlitePath,
        'baseUrl': profile.baseUrl,
        'databaseTarget': profile.databaseTarget,
        'deployment': profile.deployment,
        'device': profile.device,
        'generation': profile.generation,
        'accountId': 1,
        'groupId': 1,
      }),
    );
    final loaded = await loadIsolatedTransactionUiProfile(manifest.path);
    scopedDatabases.add(loaded.database);
    expect(loaded.profile.transactionScope, profile.transactionScope);
    loaded.http.close();
    await expectLater(
      loadIsolatedTransactionUiProfile(''),
      throwsA(isA<ManualTransactionFailure>()),
    );
  });
}
