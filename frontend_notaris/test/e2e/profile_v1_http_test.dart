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
import 'package:frontend_notaris/providers/profile_provider.dart';
import 'package:frontend_notaris/screens/profile_dialog.dart';
import 'package:frontend_notaris/services/auth_service.dart';
import 'package:frontend_notaris/services/profile_api_service.dart';

import '../services/administration_auth_test.dart' show ReadyAuth;
import 'users_v1_http_test.dart' show network;

class _Direct extends HttpOverrides {}

void main() {
  final url = Platform.environment['NOTARIS_PROFILE_V1_HTTP'];
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
        ).refreshPermissions(Platform.environment['NOTARIS_PROFILE_V1_TOKEN']!),
      ))!;
      expect(actor.groupType, 'user');
      expect(allowsOwnProfile(actor), isTrue);
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
            profileApiProvider.overrideWithValue(
              ProfileApiService(dio, session: () => auth.state.session),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData(fontFamily: 'OfficeHTTP'),
            home: Scaffold(
              body: Builder(
                builder: (c) => TextButton(
                  onPressed: () => showOwnProfile(c),
                  child: const Text('Open Profile'),
                ),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Open Profile'));
      await network(t);
      expect(find.text('Username: user3'), findsOneWidget);
      await t.tap(find.byKey(const Key('profile-edit')));
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const Key('profile-nama')),
        'Rani HTTP Baru',
      );
      await t.tap(find.byKey(const Key('profile-save')));
      await network(t);
      await network(t);
      expect(find.textContaining('dibaca kembali'), findsOneWidget);
      expect(find.text('Nama: Rani HTTP Baru'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.tap(find.byKey(const Key('profile-cancel')));
      await t.pumpAndSettle();
      await t.tap(find.text('Open Profile'));
      await network(t);
      expect(find.text('Nama: Rani HTTP Baru'), findsOneWidget);
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
