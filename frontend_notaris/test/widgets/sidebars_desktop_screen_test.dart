import 'dart:async';

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
import 'package:frontend_notaris/providers/pekerjaan_provider.dart';
import 'package:frontend_notaris/screens/sidebar_desktop_screen.dart';
import 'package:frontend_notaris/services/auth_service.dart';
import 'package:frontend_notaris/services/sidebar_api_service.dart';

import '../services/administration_auth_test.dart' show ReadyAuth;
import '../services/sidebar_catalog_test.dart';

class CatalogApi extends SidebarApiService {
  CatalogApi() : super(Dio());
  final calls = <SidebarCatalogQuery>[];
  Object? error;
  Completer<void>? hold;
  bool empty = false;
  @override
  Future<SidebarCatalogPage> catalog(SidebarCatalogQuery q) async {
    calls.add(q);
    await hold?.future;
    if (error != null) throw error!;
    return SidebarCatalogPage.fromJson(
      catalogData(
        page: q.page,
        total: empty
            ? 0
            : q.search.isEmpty
            ? 25
            : 1,
      ),
      q,
    );
  }
}

Future<ReadyAuth> mountCatalog(
  WidgetTester t,
  CatalogApi api, {
  Size size = const Size(1366, 768),
  bool shell = false,
  bool read = true,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final font = FontLoader('CatalogTest')
    ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
  await font.load();
  final db = MateraiProfileDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final auth = ReadyAuth(AuthService(dio: Dio()), catalogSession(read: read));
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        authControllerProvider.overrideWith((_) => auth),
        sidebarApiServiceProvider.overrideWithValue(api),
      ],
      child: MaterialApp(
        theme: ThemeData(fontFamily: 'CatalogTest'),
        home: shell
            ? AppShell(session: auth.state.session)
            : const Scaffold(body: SidebarDesktopScreen()),
      ),
    ),
  );
  await t.pumpAndSettle();
  if (shell) {
    await t.tap(find.text('System').first);
    await t.pumpAndSettle();
    await t.tap(find.text('Sidebars').first);
    await t.pumpAndSettle();
  }
  return auth;
}

void main() {
  testWidgets(
    'server pagination, search reset, status, refresh; no mutation controls',
    (t) async {
      final api = CatalogApi();
      await mountCatalog(t, api);
      expect(find.text('25 definisi'), findsOneWidget);
      expect(
        t
            .widget<IconButton>(find.byKey(const Key('sidebars-previous')))
            .onPressed,
        isNull,
      );
      await t.tap(find.byKey(const Key('sidebars-next')));
      await t.pumpAndSettle();
      expect(api.calls.last.page, 2);
      await t.enterText(find.byKey(const Key('sidebars-search')), '%_');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pumpAndSettle();
      expect(api.calls.last, (page: 1, search: '%_', status: 'all'));
      await t.tap(find.byKey(const Key('sidebars-status')));
      await t.pumpAndSettle();
      await t.tap(find.text('Nonaktif').last);
      await t.pumpAndSettle();
      expect(api.calls.last.status, 'inactive');
      final count = api.calls.length;
      await t.tap(find.byKey(const Key('sidebars-refresh')));
      await t.pumpAndSettle();
      expect(api.calls.length, count + 1);
      expect(find.byIcon(Icons.edit), findsNothing);
      expect(find.byIcon(Icons.delete), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.textContaining('29/06/2026'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'permission denial before HTTP and after session permission refresh',
    (t) async {
      final api = CatalogApi();
      final auth = await mountCatalog(t, api, read: false);
      expect(api.calls, isEmpty);
      expect(find.textContaining('izin baca Sidebars'), findsOneWidget);
      auth.state = AuthState.authenticated(catalogSession());
      await t.pumpAndSettle();
      expect(api.calls.length, 1);
      auth.state = AuthState.authenticated(catalogSession(read: false));
      await t.pumpAndSettle();
      expect(find.byType(DataTable), findsNothing);
    },
  );
  testWidgets('empty and indeterminate loading do not fabricate rows', (
    t,
  ) async {
    final api = CatalogApi()..empty = true;
    await mountCatalog(t, api);
    expect(
      find.text('Tidak ada definisi Sidebars yang cocok.'),
      findsOneWidget,
    );
    api.empty = false;
    api.hold = Completer<void>();
    await t.tap(find.byKey(const Key('sidebars-refresh')));
    await t.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(DataTable), findsNothing);
    api.hold!.complete();
    await t.pumpAndSettle();
    expect(find.byType(DataTable), findsOneWidget);
  });
  for (final status in [401, 403, 500, null]) {
    testWidgets('honest error state $status', (t) async {
      final api = CatalogApi()
        ..error = DioException(
          requestOptions: RequestOptions(),
          response: status == null
              ? null
              : Response(requestOptions: RequestOptions(), statusCode: status),
        );
      await mountCatalog(t, api);
      expect(find.byType(DataTable), findsNothing);
      expect(find.text(sidebarCatalogError(api.error!)), findsOneWidget);
    });
  }
  for (final size in [
    const Size(1920, 1080),
    const Size(1728, 900),
    const Size(1366, 768),
    const Size(1080, 640),
  ]) {
    testWidgets('shared shell and horizontal scroll without overflow $size', (
      t,
    ) async {
      await mountCatalog(t, CatalogApi(), size: size, shell: true);
      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.byType(Scrollbar), findsWidgets);
      expect(t.takeException(), isNull);
    });
  }
  test(
    'icon references are bounded display-only; unknown gets neutral glyph',
    () {
      expect(sidebarReferenceIcon('folder'), Icons.folder_outlined);
      expect(sidebarReferenceIcon('invalid-path.exe'), Icons.help_outline);
      expect(sidebarReferenceIcon(null), Icons.help_outline);
    },
  );
  test(
    'timestamp without zone is displayed as stored, not converted to UTC',
    () {
      final r = SidebarCatalogItem.fromJson({
        ...catalogRow(1),
        'created_at': '2026-11-20T00:00:00',
      });
      expect(
        sidebarCatalogTimestamp(r),
        '2026-11-20 00:00:00 · tanpa zona waktu',
      );
      expect(
        sidebarCatalogTimestamp(
          SidebarCatalogItem.fromJson({...catalogRow(1), 'created_at': null}),
        ),
        'Belum tersedia',
      );
    },
  );
}
