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
import 'package:frontend_notaris/screens/groups_desktop_screen.dart';
import 'package:frontend_notaris/services/auth_service.dart';
import 'package:frontend_notaris/services/group_api_service.dart';
import 'package:frontend_notaris/services/group_sidebar_access_api_service.dart';

import '../services/administration_auth_test.dart' show ReadyAuth;
import 'groups_v1_http_test.dart' show click;
import 'users_v1_http_test.dart' show network;

class _Http extends HttpOverrides {}

void main() {
  final base = Platform.environment['NOTARIS_GROUPS_V2_HTTP'];
  testWidgets(
    'Atur Akses UI->authenticated HTTP, reopen/revoke/permission refresh and protected SQLite',
    (t) async {
      t.view.physicalSize = const Size(1366, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final font = FontLoader('AccessHTTP')
        ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
      await font.load();
      final dio = Dio(BaseOptions(baseUrl: base!, followRedirects: false));
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () =>
            _Http().createHttpClient(null)..findProxy = (_) => 'DIRECT',
      );
      final auth = AuthService(dio: dio);
      final actor = (await t.runAsync(
        () => auth.refreshPermissions(
          Platform.environment['NOTARIS_GROUPS_V2_TOKEN']!,
        ),
      ))!;
      final memberToken = Platform.environment['NOTARIS_GROUPS_V2_MEMBER']!;
      final controller = ReadyAuth(auth, actor);
      installAuthenticatedSessionInterceptor(
        dio,
        baseUrl: base,
        currentSession: () => controller.state.session,
        onRejected: controller.handleApiRejection,
      );
      final api = GroupSidebarAccessApiService(dio),
          db = MateraiProfileDatabase(NativeDatabase.memory());
      await db.customSelect('SELECT 1').get();
      final before = await db.customSelect('SELECT * FROM transaksis').get();
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            authControllerProvider.overrideWith((_) => controller),
            groupApiServiceProvider.overrideWithValue(GroupApiService(dio)),
            groupSidebarAccessApiServiceProvider.overrideWithValue(api),
          ],
          child: MaterialApp(
            theme: ThemeData(fontFamily: 'AccessHTTP'),
            home: const Scaffold(body: GroupsDesktopScreen()),
          ),
        ),
      );
      await network(t);
      await click(t, find.byTooltip('Atur Akses Operator'));
      // Existing fixture starts READ+CUD. Revoking READ clears dependent flags.
      await click(t, find.byKey(const ValueKey('access-4-0')));
      await click(t, find.text('Simpan Perubahan'));
      await network(t);
      final revoked = await t.runAsync(
        () =>
            AuthService(dio: _member(base, memberToken))
                .refreshPermissions(memberToken),
      );
      final entry = revoked!.sidebars.firstWhere(
        (r) => (r['sidebar'] as Map)['id'] == 4,
      );
      expect(entry['read'], 0);
      expect(revoked.token, memberToken);
      await t.runAsync(() async {
        final d = _member(base, memberToken);
        await expectLater(
          d.get('/petugas/references/users/1'),
          throwsA(
            isA<DioException>().having(
              (e) => e.response?.statusCode,
              'status',
              403,
            ),
          ),
        );
        d.close();
      });
      await click(t, find.byTooltip('Atur Akses Operator'));
      expect(
        t.widget<Checkbox>(find.byKey(const ValueKey('access-4-0'))).value,
        false,
      );
      await click(t, find.byKey(const ValueKey('access-4-1')));
      expect(
        t.widget<Checkbox>(find.byKey(const ValueKey('access-4-0'))).value,
        true,
      );
      await click(t, find.text('Simpan Perubahan'));
      await network(t);
      final restored = await t.runAsync(
        () =>
            AuthService(dio: _member(base, memberToken))
                .refreshPermissions(memberToken),
      );
      expect(
        restored!.sidebars.firstWhere(
          (r) => (r['sidebar'] as Map)['id'] == 4,
        )['create'],
        1,
      );
      expect(restored.token, memberToken);
      await t.runAsync(() async {
        final d = _member(base, memberToken);
        expect((await d.get('/petugas/references/users/1')).statusCode, 200);
        d.close();
      });
      final s = await t.runAsync(() => api.getByGroup(2));
      expect(s!.revision, 3);
      expect(s.entries.last.editable, false);
      expect(s.entries.last.flags, [1, 1, 0, 0]);
      // Native SQLite completion must run outside the widget fake clock,
      // just like the real HTTP operations above.
      await t.runAsync(() async {
        expect(await db.customSelect('SELECT * FROM transaksis').get(), before);
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
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pump();
      await t.runAsync(db.close);
      dio.close();
    },
    skip: base == null,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Dio _member(String base, String token) {
  final d = Dio(
    BaseOptions(baseUrl: base, headers: {'Authorization': 'Bearer $token'}),
  );
  d.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () =>
        _Http().createHttpClient(null)..findProxy = (_) => 'DIRECT',
  );
  return d;
}
