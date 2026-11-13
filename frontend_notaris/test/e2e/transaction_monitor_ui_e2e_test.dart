import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/models/auth_session.dart';
import 'package:frontend_notaris/providers/auth_provider.dart';
import 'package:frontend_notaris/providers/development_smoke_provider.dart';
import 'package:frontend_notaris/providers/transaction_manual_sync_provider.dart';
import 'package:frontend_notaris/repositories/sync_log_repository.dart';
import 'package:frontend_notaris/screens/sync_monitor_desktop_screen.dart';
import 'package:frontend_notaris/services/transaction_manual_sync_service.dart';

import '../support/transaction_ui_test_support.dart';

// Only this disposable HTTP opt-in uses a real client instead of Flutter's
// default widget-test HTTP-400 stub. Service/profile guards remain installed.
class _RealDisposableHttp extends HttpOverrides {}

void main() {
  final env = Platform.environment,
      url = Platform.environment['TRANSACTION_E2E_URL'],
      token = Platform.environment['TRANSACTION_E2E_TOKEN'];
  if (url == null || token == null) {
    test(
      'isolated Monitoring UI HTTP requires disposable opt-in',
      () {},
      skip: true,
    );
    return;
  }
  if (!url.startsWith('http://127.0.0.1:') || url.contains(':8081/')) {
    throw StateError('Disposable HTTP only');
  }
  testWidgets(
    'Monitoring UI → real service → authenticated HTTP → PostgreSQL → second UI profile',
    (t) async {
      t.view.physicalSize = const Size(1400, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      late Directory folder;
      late AppDatabase a, b;
      late File aFile, bFile;
      late Dio dio;
      late AuthSession session;
      final profiles = <String, TransactionManualProfile>{},
          configs = <IsolatedTransactionSyncConfiguration>[],
          containers = <ProviderContainer>[];
      await t.runAsync(() async {
        folder = await Directory.systemTemp.createTemp(
          'transaction_manual_ui_e2e_',
        );
        aFile = File('${folder.path}/a.sqlite');
        bFile = File('${folder.path}/b.sqlite');
        a = AppDatabase.forTesting(NativeDatabase(aFile));
        b = AppDatabase.forTesting(NativeDatabase(bFile));
        dio = Dio(
          BaseOptions(
            baseUrl: url,
            headers: {'Authorization': 'Bearer $token'},
          ),
        );
        dio.httpClientAdapter = IOHttpClientAdapter(
          createHttpClient: () {
            final client = _RealDisposableHttp().createHttpClient(null);
            client.findProxy = (_) => 'DIRECT';
            client.idleTimeout = Duration.zero;
            return client;
          },
        );
        final data =
            (await dio.get<Map<String, dynamic>>('/auth/me/sidebar-access'))
                    .data!['data']
                as Map;
        session = AuthSession(
          token: token,
          userId: data['user']['id'] as int,
          groupId: data['user']['group_id'] as int,
          userName: 'UI fixture',
          groupName: 'UI fixture',
          user: Map<String, dynamic>.from(data['user'] as Map),
          sidebars: (data['sidebars'] as List)
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList(),
          verifiedAt: DateTime.now(),
        );
        for (final item in {'a': a, 'b': b}.entries) {
          final file = item.key == 'a' ? aFile : bFile;
          final profile = TransactionManualProfile(
            sqlitePath: file.path,
            baseUrl: url,
            databaseTarget: env['TRANSACTION_DISPOSABLE_TARGET']!,
            deployment: env['TRANSACTION_DISPOSABLE_DEPLOYMENT']!,
            device: item.key,
            generation: 'monitor-ui-v1',
            accountId: 1,
            groupId: 1,
          );
          profiles[item.key] = profile;
          await seedTransactionUiReferences(item.value, profile);
        }
        await createTransactionUiRecord(a, 'notaris');
        await createTransactionUiRecord(a, 'ppat');
      });
      addTearDown(() async {
        for (final c in containers) {
          c.dispose();
        }
        for (final c in configs) {
          await c.database.close();
        }
        await a.close();
        await b.close();
        dio.close(force: true);
        await folder.delete(recursive: true);
      });
      Future<ProviderContainer> mount(String device) async {
        final config = IsolatedTransactionSyncConfiguration.open(
          profile: profiles[device]!,
          http: dio,
        );
        configs.add(config);
        final c = ProviderContainer(
          overrides: [
            isolatedTransactionSyncConfigurationProvider.overrideWithValue(
              config,
            ),
            authControllerProvider.overrideWith(
              (_) => TransactionUiAuth(session),
            ),
            developmentUiSmokeProvider.overrideWithValue(false),
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

      Future<void> until(String text) async {
        for (var n = 0; n < 400; n++) {
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await t.pump(const Duration(milliseconds: 16));
          if (find.textContaining(text).evaluate().isNotEmpty) return;
        }
        throw StateError('UI outcome not reached: $text');
      }

      final first = await mount('a');
      var seq = 0;
      for (final domain in ['notaris', 'ppat']) {
        await chooseUiModule(
          t,
          domain == 'ppat' ? 'Transaksi PPAT' : 'Transaksi Notaris',
        );
        await chooseUiRecord(t, 'transaksi_$domain');
        final click = t
            .widget<FilledButton>(find.byKey(const Key('manual-sync-execute')))
            .onPressed!;
        click();
        click();
        await t.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await t.tap(find.byKey(const Key('confirm-transaction-upload')));
        await until('Upload ${domain == 'ppat' ? 'PPAT' : 'Notaris'}');
        // Labels use display case; wait on the actual controller, not an HTTP send.
        for (
          var n = 0;
          n < 400 && first.read(isolatedTransactionSyncControllerProvider).busy;
          n++
        ) {
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await t.pump(const Duration(milliseconds: 16));
        }
        expect(
          first.read(isolatedTransactionSyncControllerProvider).errorCode,
          isNull,
        );
        expect(
          find.textContaining('Upload terkonfirmasi: 1 record'),
          findsOneWidget,
        );
        await t.runAsync(() async {
          final row = (await a.select(a.transaksis).get()).singleWhere(
            (r) => r.jenisTransaksi == domain,
          );
          expect(
            row.noAkta,
            matches(domain == 'ppat' ? r'^200\d{6}0001$' : r'^100\d{6}0001$'),
          );
          final published = (await dio.post<Map<String, dynamic>>(
            '/transaksi-notaris/testing/publish',
            data: {
              'domain': domain,
              'uuid': row.uuid,
              'operation': 'create',
              'revision': 1,
              'expected_last_seq': seq,
            },
          )).data!;
          expect(published['published'], 1);
          expect(published['last_seq'], ++seq);
          expect(
            (await SyncLogRepository(a).list(module: 'transaksi_$domain'))
                .single['status'],
            'success',
          );
        });
      }
      await mount('b');
      await chooseUiModule(t, 'Transaksi (feed gabungan)');
      expect(
        find.textContaining('Download menerima Transaksi Notaris dan PPAT'),
        findsOneWidget,
      );
      await t.tap(find.byKey(const Key('manual-sync-execute')));
      await until('Download selesai: 2 event, cursor 2.');
      expect(find.byType(AlertDialog), findsNothing);
      await t.runAsync(() async {
        final source = await a.select(a.transaksis).get(),
            target = await b.select(b.transaksis).get();
        expect(target.length, 2);
        for (final row in target) {
          final original = source.singleWhere((x) => x.uuid == row.uuid);
          expect(row.noAkta, original.noAkta);
          expect(row.total, original.total);
        }
        expect(
          (await b.select(b.transaksiRiwayatPembayarans).get())
              .map((p) => p.uuid)
              .toSet(),
          (await a.select(a.transaksiRiwayatPembayarans).get())
              .map((p) => p.uuid)
              .toSet(),
        );
        expect(
          (await b.select(b.transaksiProses).get()).map((p) => p.uuid).toSet(),
          (await a.select(a.transaksiProses).get()).map((p) => p.uuid).toSet(),
        );
        expect(
          (await b.select(b.transaksiDetails).get())
              .map((p) => p.prosesSnapshot)
              .toList(),
          (await a.select(a.transaksiDetails).get())
              .map((p) => p.prosesSnapshot)
              .toList(),
        );
      });
      await t.tap(find.byKey(const Key('manual-sync-execute')));
      await until('Download selesai: 0 event, cursor 2.');
      await t.pumpWidget(const SizedBox());
      for (final c in containers) {
        c.dispose();
      }
      containers.clear();
      for (final config in configs) {
        await t.runAsync(config.database.close);
      }
      configs.clear();
      await t.runAsync(b.close);
      b = AppDatabase.forTesting(NativeDatabase(bFile));
      await mount('b');
      expect(find.text('Berhasil (diketahui)'), findsWidgets);
      await t.runAsync(() async {
        expect(
          (await b
                  .customSelect('SELECT cursor FROM transaction_cloud_feed')
                  .getSingle())
              .read<int>('cursor'),
          2,
        );
        expect(
          (await SyncLogRepository(b).list(module: 'transaksi')).length,
          2,
        );
        expect((await b.select(b.transaksiRiwayatPembayarans).get()).length, 2);
        expect(await b.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
        expect(
          (await b.customSelect('PRAGMA integrity_check').getSingle())
              .read<String>('integrity_check'),
          'ok',
        );
      });
      // Close real sockets in the test body, before widget binding verifies fake
      // timer invariants (package tearDown happens after that verification).
      await t.pumpWidget(const SizedBox());
      dio.close(force: true);
      await t.pump();
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
