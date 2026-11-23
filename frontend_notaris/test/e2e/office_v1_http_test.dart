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
import 'package:frontend_notaris/providers/office_configuration_provider.dart';
import 'package:frontend_notaris/screens/konfigurasi_umum_desktop_screen.dart';
import 'package:frontend_notaris/services/auth_service.dart';
import 'package:frontend_notaris/services/office_configuration_api_service.dart';

import '../services/administration_auth_test.dart' show ReadyAuth;
import 'users_v1_http_test.dart' show network;

class _Direct extends HttpOverrides {}

void main() {
  final url = Platform.environment['NOTARIS_OFFICE_V1_HTTP'];
  testWidgets(
    'real ordinary session -> configuration UI -> HTTP -> PostgreSQL, read-only SQLite',
    (t) async {
      t.view.physicalSize = const Size(1366, 768);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await (FontLoader(
        'OfficeHTTP',
      )..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))).load();
      final dio = Dio(
        BaseOptions(
          baseUrl: url!,
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
          followRedirects: false,
        ),
      );
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = _Direct().createHttpClient(null);
          client.findProxy = (_) => 'DIRECT';
          client.idleTimeout = Duration.zero;
          return client;
        },
      );
      final actor = (await t.runAsync(
        () => AuthService(
          dio: dio,
        ).refreshPermissions(Platform.environment['NOTARIS_OFFICE_V1_TOKEN']!),
      ))!;
      expect(actor.groupType, 'user');
      expect(allowsOfficeConfiguration(actor), isTrue);
      final auth = ReadyAuth(AuthService(dio: dio), actor);
      installAuthenticatedSessionInterceptor(
        dio,
        baseUrl: url,
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
        dio.close(force: true);
        await t.runAsync(db.close);
        await t.pumpAndSettle();
      }

      addTearDown(cleanup);
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((_) => auth),
            appDatabaseProvider.overrideWithValue(db),
            officeConfigurationApiProvider.overrideWithValue(
              OfficeConfigurationApiService(dio),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData(fontFamily: 'OfficeHTTP'),
            home: const Scaffold(body: KonfigurasiUmumDesktopScreen()),
          ),
        ),
      );
      await network(t);
      expect(find.text('Kantor Uji'), findsOneWidget);
      expect(find.text('Rp 18.446.744.073.709.551.615'), findsOneWidget);
      expect(find.text('Rp 0'), findsOneWidget);
      expect(find.text('Belum diisi'), findsNWidgets(2));
      expect(find.text('NOTARISDEV SYNTHETIC v1'), findsNothing);
      expect(find.text('Simpan'), findsNothing);
      await t.tap(find.byKey(const Key('office-refresh')));
      await network(t);
      expect(find.text('Kantor Uji'), findsOneWidget);
      expect(t.takeException(), isNull);
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
    skip: url == null,
  );
}
