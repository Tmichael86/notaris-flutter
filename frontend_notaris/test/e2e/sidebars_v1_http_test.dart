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
import 'package:frontend_notaris/providers/pekerjaan_provider.dart';
import 'package:frontend_notaris/screens/sidebar_desktop_screen.dart';
import 'package:frontend_notaris/services/auth_service.dart';
import 'package:frontend_notaris/services/sidebar_api_service.dart';

import '../services/administration_auth_test.dart' show ReadyAuth;
import 'users_v1_http_test.dart' show network;

class _Http extends HttpOverrides {}

void main() {
  final base = Platform.environment['NOTARIS_SIDEBARS_V1_HTTP'];
  testWidgets(
    'Sidebars real HTTP list literal search status pagination and read-only SQLite',
    (t) async {
      t.view.physicalSize = const Size(1366, 768);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final font = FontLoader('CatalogHTTP')
        ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
      await font.load();
      final dio = Dio(
        BaseOptions(
          baseUrl: base!,
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
          followRedirects: false,
        ),
      );
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () =>
            _Http().createHttpClient(null)..findProxy = (_) => 'DIRECT',
      );
      final actor = (await t.runAsync(
        () => AuthService(dio: dio).refreshPermissions(
          Platform.environment['NOTARIS_SIDEBARS_V1_TOKEN']!,
        ),
      ))!;
      expect(actor.groupType, 'user');
      final auth = ReadyAuth(AuthService(dio: dio), actor);
      installAuthenticatedSessionInterceptor(
        dio,
        baseUrl: base,
        currentSession: () => auth.state.session,
        onRejected: auth.handleApiRejection,
      );
      final db = MateraiProfileDatabase(NativeDatabase.memory());
      await db.customSelect('SELECT 1').get();
      await db.customStatement('PRAGMA query_only=ON');
      var closed = false;
      Future<void> cleanup() async {
        if (closed) return;
        closed = true;
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
        dio.close(force: true);
        await t.runAsync(db.close);
      }

      addTearDown(cleanup);
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((_) => auth),
            appDatabaseProvider.overrideWithValue(db),
            sidebarApiServiceProvider.overrideWithValue(SidebarApiService(dio)),
          ],
          child: MaterialApp(
            theme: ThemeData(fontFamily: 'CatalogHTTP'),
            home: const Scaffold(body: SidebarDesktopScreen()),
          ),
        ),
      );
      await network(t);
      expect(find.text('25 definisi'), findsOneWidget);
      expect(find.text('Arsip Nonaktif'), findsOneWidget);
      await t.tap(find.byKey(const Key('sidebars-next')));
      await network(t);
      expect(find.textContaining('Halaman 2 / 3'), findsOneWidget);
      await t.enterText(find.byKey(const Key('sidebars-search')), '%_');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await network(t);
      expect(find.text('Referensi %_ Literal'), findsOneWidget);
      expect(find.text('1 definisi'), findsOneWidget);
      await t.enterText(find.byKey(const Key('sidebars-search')), '');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await network(t);
      await t.tap(find.byKey(const Key('sidebars-status')));
      await t.pumpAndSettle();
      await t.tap(find.text('Nonaktif').last);
      await network(t);
      expect(find.text('2 definisi'), findsOneWidget);
      expect(find.text('Historis'), findsOneWidget);
      expect(find.text('Arsip Nonaktif'), findsOneWidget);
      await t.tap(find.byKey(const Key('sidebars-refresh')));
      await network(t);
      expect(find.text('2 definisi'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.byIcon(Icons.delete), findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      await t.runAsync(() async {
        expect(
          await db.customSelect('SELECT * FROM transaksis').get(),
          isEmpty,
        );
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        expect(
          (await db.customSelect('PRAGMA integrity_check').getSingle())
              .data
              .values
              .single,
          'ok',
        );
      });
      await cleanup();
    },
    skip: base == null,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
