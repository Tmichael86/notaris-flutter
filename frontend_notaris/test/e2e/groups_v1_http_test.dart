import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/providers/auth_provider.dart';
import 'package:frontend_notaris/providers/authenticated_api_provider.dart';
import 'package:frontend_notaris/providers/database_provider.dart';
import 'package:frontend_notaris/providers/development_smoke_provider.dart';
import 'package:frontend_notaris/providers/pekerjaan_provider.dart'
    show groupApiServiceProvider;
import 'package:frontend_notaris/screens/groups_desktop_screen.dart';
import 'package:frontend_notaris/services/auth_service.dart';
import 'package:frontend_notaris/services/group_api_service.dart';

import '../widgets/users_desktop_screen_test.dart' show UsersAuth;
import 'users_v1_http_test.dart' show network, input;

class _Http extends HttpOverrides {}

Future<void> click(WidgetTester t, Finder f) async {
  // Wait for the real response + route teardown/provider refresh to render.
  // This never retries an HTTP mutation or changes application timing.
  for (var i = 0; i < 10 && f.evaluate().isEmpty; i++) {
    await network(t);
  }
  expect(f, findsOneWidget);
  await t.ensureVisible(f);
  await t.tap(f);
  await network(t);
}

void main() {
  final base = Platform.environment['NOTARIS_GROUPS_V1_HTTP'];
  testWidgets(
    'Groups UI authenticates HTTP create rename deactivate on PostgreSQL',
    (t) async {
      final font = FontLoader('GroupsHTTP')
        ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
      await font.load();
      t.view.physicalSize = const Size(1366, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final dio = Dio(BaseOptions(baseUrl: base!, followRedirects: false));
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () =>
            _Http().createHttpClient(null)..findProxy = (_) => 'DIRECT',
      );
      final s = await t.runAsync(
        () => AuthService(
          dio: dio,
        ).refreshPermissions(Platform.environment['NOTARIS_GROUPS_V1_TOKEN']!),
      );
      expect(s!.canUseOnlineAdministration, true);
      installAuthenticatedSessionInterceptor(
        dio,
        baseUrl: base,
        currentSession: () => s,
        onRejected: (_, _) async {},
      );
      final api = GroupApiService(dio),
          db = MateraiProfileDatabase(NativeDatabase.memory());
      await db.customSelect('SELECT 1').get();
      final before = await db.customSelect('SELECT * FROM transaksis').get();
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            developmentUiSmokeProvider.overrideWithValue(true),
            authControllerProvider.overrideWith((_) => UsersAuth(s)),
            groupApiServiceProvider.overrideWithValue(api),
          ],
          child: MaterialApp(
            theme: ThemeData(fontFamily: 'GroupsHTTP'),
            home: const Scaffold(body: GroupsDesktopScreen()),
          ),
        ),
      );
      await network(t);
      await click(t, find.text('Tambah Grup'));
      await input(t, 'Nama grup', 'HTTP Group');
      await click(t, find.widgetWithText(FilledButton, 'Simpan'));
      expect(find.byType(Dialog), findsNothing);
      final created = await t.runAsync(() => api.get(11));
      expect(created!.revision, 1);
      expect(created.activeMembers, 0);
      await click(t, find.byTooltip('Ubah nama HTTP Group'));
      await input(t, 'Nama grup', 'HTTP Group Renamed');
      await click(t, find.widgetWithText(FilledButton, 'Simpan'));
      expect((await t.runAsync(() => api.get(11)))!.revision, 2);
      await click(t, find.byTooltip('Nonaktifkan HTTP Group Renamed'));
      await click(t, find.byType(CheckboxListTile));
      await click(t, find.widgetWithText(FilledButton, 'Nonaktifkan Grup'));
      final finalRow = await t.runAsync(() => api.get(11));
      expect(finalRow!.status, 0);
      expect(finalRow.revision, 3);
      expect(await db.customSelect('SELECT * FROM transaksis').get(), before);
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pump();
      await db.close();
      dio.close();
    },
    skip: base == null,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
