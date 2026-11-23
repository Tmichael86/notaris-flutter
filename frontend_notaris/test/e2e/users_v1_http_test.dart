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
    show userApiServiceProvider;
import 'package:frontend_notaris/screens/users_desktop_screen.dart';
import 'package:frontend_notaris/services/auth_service.dart';
import 'package:frontend_notaris/services/user_api_service.dart';

import '../widgets/users_desktop_screen_test.dart' show UsersAuth, field;

class _DisposableHttp extends HttpOverrides {}

Future<void> network(WidgetTester t) async {
  for (var i = 0; i < 20; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await t.pump(const Duration(milliseconds: 30));
  }
}

Future<void> input(WidgetTester t, String label, String value) async {
  final f = field(label);
  await t.ensureVisible(f);
  await t.enterText(f, value);
  await t.pump();
}

Future<void> click(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.tap(f);
  await network(t);
}

void main() {
  final base = Platform.environment['NOTARIS_USERS_V1_HTTP'];
  testWidgets(
    'Users UI performs authenticated real HTTP CRUD, group assignment, reset and revocation',
    (t) async {
      final font = FontLoader('UsersHttp')
        ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
      await font.load();
      t.view.physicalSize = const Size(1366, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final dio = Dio(BaseOptions(baseUrl: base!, followRedirects: false));
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () =>
            _DisposableHttp().createHttpClient(null)
              ..findProxy = (_) => 'DIRECT',
      );
      final session = await t.runAsync(
        () => AuthService(
          dio: dio,
        ).refreshPermissions(Platform.environment['NOTARIS_USERS_V1_TOKEN']!),
      );
      expect(session!.canUseOnlineAdministration, isTrue);
      installAuthenticatedSessionInterceptor(
        dio,
        baseUrl: base,
        currentSession: () => session,
        onRejected: (_, _) async {},
      );
      final api = UserApiService(dio),
          db = MateraiProfileDatabase(NativeDatabase.memory());
      await db.customSelect('SELECT 1').get();
      final before = await db.customSelect('SELECT * FROM transaksis').get();
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            developmentUiSmokeProvider.overrideWithValue(true),
            authControllerProvider.overrideWith((_) => UsersAuth(session)),
            userApiServiceProvider.overrideWithValue(api),
          ],
          child: MaterialApp(
            theme: ThemeData(fontFamily: 'UsersHttp'),
            home: const Scaffold(body: UsersDesktopScreen()),
          ),
        ),
      );
      await network(t);
      await click(t, find.text('Tambah User'));
      await input(t, 'Nama', 'HTTP Operator');
      await input(t, 'Username', 'http.operator');
      await input(t, 'Email', 'http.operator@example.invalid');
      await click(t, find.byType(DropdownButtonFormField<int>).last);
      await click(t, find.text('Operator').last);
      final password = Platform.environment['NOTARIS_USERS_V1_PASSWORD']!;
      await input(t, 'Password', password);
      await input(t, 'Konfirmasi password', password);
      await click(t, find.widgetWithText(FilledButton, 'Simpan'));
      expect(find.byType(Dialog), findsNothing);
      final row = await t.runAsync(() => api.get(11));
      expect(row!.revision, 1);
      await click(t, find.byTooltip('Edit http.operator'));
      await input(t, 'Nama', 'HTTP Edited');
      await click(t, find.widgetWithText(FilledButton, 'Simpan'));
      expect((await t.runAsync(() => api.get(11)))!.revision, 2);
      await click(t, find.byTooltip('Edit http.operator'));
      await click(t, find.byType(DropdownButtonFormField<int>).last);
      await click(t, find.text('Arsip').last);
      await click(t, find.widgetWithText(FilledButton, 'Simpan'));
      expect((await t.runAsync(() => api.get(11)))!.groupId, 5);
      await click(t, find.byTooltip('Nonaktifkan http.operator'));
      await click(t, find.byType(CheckboxListTile));
      await click(t, find.widgetWithText(FilledButton, 'Nonaktifkan Akun'));
      expect((await t.runAsync(() => api.get(11)))!.status, 0);
      await click(t, find.byTooltip('Reset password user5'));
      await input(t, 'Password', password);
      await input(t, 'Konfirmasi password', password);
      await click(t, find.byType(CheckboxListTile));
      await click(t, find.widgetWithText(FilledButton, 'Reset Password'));
      expect((await t.runAsync(() => api.get(5)))!.revision, 2);
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
