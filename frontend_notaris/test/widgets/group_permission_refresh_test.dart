import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/core/widgets/app_shell.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/providers/auth_provider.dart';
import 'package:frontend_notaris/providers/database_provider.dart';
import 'package:frontend_notaris/services/auth_service.dart';

import '../services/administration_auth_test.dart' show ReadyAuth, session;
import '../services/group_sidebar_access_api_service_test.dart'
    show AccessFakeAdapter, accessReply;

void main() {
  testWidgets(
    'explicit account refresh adds/removes navigation with same JWT, no polling or SQLite mutation',
    (t) async {
      t.view.physicalSize = const Size(1366, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final font = FontLoader('RefreshTest')
        ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
      await font.load();
      var calls = 0, read = 1;
      final initial = session();
      final dio = Dio()
        ..httpClientAdapter = AccessFakeAdapter((r) async {
          calls++;
          expect(r.method, 'GET');
          expect(r.path, '/auth/me/sidebar-access');
          expect(r.headers['Authorization'], 'Bearer ${initial.token}');
          return accessReply({
            'user': {'id': 1, 'group_id': 1, 'nama': 'Verified'},
            'group_jenis': 'user',
            'sidebars': [
              {
                'read': read,
                'create': 0,
                'update': 0,
                'delete': 0,
                'sidebar': {
                  'id': 2,
                  'sidebar_kode': 'groups',
                  'sidebar_nama': 'Groups',
                  'status': 1,
                },
              },
            ],
          });
        });
      final controller = ReadyAuth(AuthService(dio: dio), initial);
      final db = MateraiProfileDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      addTearDown(dio.close);
      await db.customSelect('SELECT 1').get();
      final before = await db.customSelect('SELECT * FROM transaksis').get();
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            authControllerProvider.overrideWith((_) => controller),
          ],
          child: MaterialApp(
            theme: ThemeData(fontFamily: 'RefreshTest'),
            home: Consumer(
              builder: (c, ref, _) =>
                  AppShell(session: ref.watch(authControllerProvider).session),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(calls, 0);
      Future<void> refresh() async {
        await t.tap(find.byTooltip('Akun'));
        await t.pumpAndSettle();
        await t.tap(find.text('Muat Ulang Izin'));
        await t.pumpAndSettle();
      }

      await refresh();
      expect(calls, 1);
      expect(controller.state.session!.token, initial.token);
      await t.tap(find.text('System').first);
      await t.pumpAndSettle();
      expect(find.text('Groups'), findsOneWidget);
      read = 0;
      await refresh();
      expect(calls, 2);
      expect(find.text('Groups'), findsNothing);
      expect(controller.state.session!.token, initial.token);
      await t.pump(const Duration(seconds: 30));
      expect(calls, 2);
      expect(await db.customSelect('SELECT * FROM transaksis').get(), before);
      expect(t.takeException(), isNull);
    },
  );
}
