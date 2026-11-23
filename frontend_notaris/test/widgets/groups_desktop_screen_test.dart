import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:frontend_notaris/core/widgets/app_shell.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/providers/database_provider.dart';
import 'package:frontend_notaris/providers/development_smoke_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/providers/auth_provider.dart';
import 'package:frontend_notaris/providers/pekerjaan_provider.dart'
    show groupApiServiceProvider;
import 'package:frontend_notaris/screens/groups_desktop_screen.dart';
import 'package:frontend_notaris/services/group_api_service.dart';

import '../services/group_api_service_test.dart' show groupRow;
import 'users_desktop_screen_test.dart' show admin, UsersAuth;

class FakeGroups extends GroupApiService {
  FakeGroups() : super(Dio());
  final rows = [
    GroupApiModel.fromJson(
      groupRow(id: 1, kind: 'superadmin', name: 'Pemulihan'),
    ),
    for (int i = 2; i <= 18; i++)
      GroupApiModel.fromJson(
        groupRow(id: i, name: 'Grup $i', status: i == 18 ? 0 : 1),
      ),
  ];
  final queries = <GroupsQuery>[];
  Completer<void>? hold;
  Object? failure;
  int creates = 0, renames = 0, deactivates = 0, gets = 0;
  @override
  Future<GroupsPage> list(GroupsQuery q) async {
    queries.add(q);
    if (failure != null) throw failure!;
    final found = rows
        .where(
          (r) =>
              (q.status == null || r.status == q.status) &&
              (q.kind == null || r.groupJenis == q.kind) &&
              r.groupNama.contains(q.search),
        )
        .toList();
    return (
      items: found.skip((q.page - 1) * 10).take(10).toList(),
      total: found.length,
      page: q.page,
      pageSize: 10,
    );
  }

  @override
  Future<GroupApiModel> get(int id) async {
    gets++;
    return rows.firstWhere((r) => r.id == id);
  }

  @override
  Future<void> create({required String groupNama}) async {
    creates++;
    await hold?.future;
    if (failure != null) throw failure!;
    rows.add(GroupApiModel.fromJson(groupRow(id: 99, name: groupNama)));
  }

  @override
  Future<void> rename(GroupApiModel group, {required String name}) async {
    renames++;
    await hold?.future;
    if (failure != null) throw failure!;
  }

  @override
  Future<void> deactivate(GroupApiModel group) async {
    deactivates++;
    await hold?.future;
    if (failure != null) throw failure!;
  }
}

Future<void> mountGroups(
  WidgetTester t,
  FakeGroups api, {
  String role = 'superadmin',
  bool offline = false,
  int write = 1,
  bool shell = false,
  Size size = const Size(1366, 768),
}) async {
  final font = FontLoader('GroupsTest')
    ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
  await font.load();
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final db = MateraiProfileDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final s = admin(role: role, offline: offline, write: write);
  s.sidebars.single['sidebar'] = {
    'sidebar_kode': 'groups',
    'sidebar_nama': 'Groups',
    'status': 1,
  };
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        developmentUiSmokeProvider.overrideWithValue(true),
        authControllerProvider.overrideWith((_) => UsersAuth(s)),
        groupApiServiceProvider.overrideWithValue(api),
      ],
      child: MaterialApp(
        theme: ThemeData(fontFamily: 'GroupsTest'),
        home: shell
            ? AppShell(session: s)
            : const Scaffold(body: GroupsDesktopScreen()),
      ),
    ),
  );
  await t.pumpAndSettle();
  if (shell) {
    await t.tap(find.text('System').first);
    await t.pumpAndSettle();
    final f = find.text('Groups').first;
    await t.ensureVisible(f);
    await t.tap(f);
    await t.pumpAndSettle();
  }
}

Future<void> clickGroups(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.tap(f);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('real provider pagination, search, empty and filters', (t) async {
    final api = FakeGroups();
    await mountGroups(t, api);
    expect(find.text('17 grup · Halaman 1 / 2'), findsOneWidget);
    expect(find.text('Hanya baca'), findsOneWidget);
    await clickGroups(t, find.byTooltip('Halaman berikutnya'));
    expect(api.queries.last.page, 2);
    await t.enterText(find.byKey(const Key('groups-search')), 'missing');
    await clickGroups(t, find.byTooltip('Cari Groups'));
    expect(api.queries.last.page, 1);
    expect(find.text('Tidak ada grup yang cocok.'), findsOneWidget);
    await clickGroups(t, find.byKey(const Key('groups-status')));
    await clickGroups(t, find.text('Nonaktif').last);
    expect(api.queries.last.status, 0);
    await clickGroups(t, find.byKey(const Key('groups-kind')));
    await clickGroups(t, find.text('Superadmin').last);
    expect(api.queries.last.kind, 'superadmin');
  });
  testWidgets(
    'ordinary or offline denied before API; no write grant disables create',
    (t) async {
      final api = FakeGroups();
      await mountGroups(t, api, role: 'user');
      expect(api.queries, isEmpty);
      expect(find.textContaining('Administrasi offline'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await mountGroups(t, api, offline: true);
      expect(api.queries, isEmpty);
      await t.pumpWidget(const SizedBox());
      await mountGroups(t, api, write: 0);
      expect(
        t
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Tambah Grup'),
            )
            .onPressed,
        isNull,
      );
    },
  );
  testWidgets(
    'create double submit, busy ESC and guarded controller lifecycle',
    (t) async {
      final api = FakeGroups();
      await mountGroups(t, api);
      await clickGroups(t, find.text('Tambah Grup'));
      await t.enterText(find.byKey(const Key('group-name')), 'Grup Baru');
      api.hold = Completer<void>();
      await t.tap(find.widgetWithText(FilledButton, 'Simpan'));
      await t.pump();
      await t.tap(find.byType(FilledButton).last);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pump();
      expect(api.creates, 1);
      expect(find.byType(Dialog), findsOneWidget);
      api.hold!.complete();
      await t.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('dirty ESC discard and repeated cancel safe', (t) async {
    final api = FakeGroups();
    await mountGroups(t, api);
    await clickGroups(t, find.text('Tambah Grup'));
    await t.enterText(find.byKey(const Key('group-name')), 'Unsent');
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(find.text('Buang perubahan?'), findsOneWidget);
    await clickGroups(t, find.text('Buang perubahan'));
    expect(api.creates, 0);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
  testWidgets('deactivate loads fresh detail, requires impact confirmation', (
    t,
  ) async {
    final api = FakeGroups();
    await mountGroups(t, api);
    await clickGroups(t, find.byTooltip('Nonaktifkan Grup 2'));
    expect(api.gets, 1);
    expect(find.textContaining('3 anggota aktif'), findsOneWidget);
    expect(
      t
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Nonaktifkan Grup'),
          )
          .onPressed,
      isNull,
    );
    await clickGroups(t, find.byType(CheckboxListTile));
    await clickGroups(t, find.widgetWithText(FilledButton, 'Nonaktifkan Grup'));
    expect(api.deactivates, 1);
  });
  testWidgets(
    '409 reload requires explicit review; timeout prevents blind retry',
    (t) async {
      final api = FakeGroups();
      await mountGroups(t, api);
      await clickGroups(t, find.byTooltip('Ubah nama Grup 2'));
      await t.enterText(find.byKey(const Key('group-name')), 'Renamed');
      api.failure = DioException(
        requestOptions: RequestOptions(path: '/groups/2'),
        response: Response(
          requestOptions: RequestOptions(path: '/groups/2'),
          statusCode: 409,
        ),
      );
      await clickGroups(t, find.widgetWithText(FilledButton, 'Simpan'));
      expect(api.renames, 1);
      expect(api.gets, 2);
      expect(find.text('Gunakan data server terbaru'), findsOneWidget);
      expect(
        t
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Simpan'))
            .onPressed,
        isNull,
      );
      await clickGroups(t, find.text('Gunakan data server terbaru'));
      api.failure = DioException(
        requestOptions: RequestOptions(path: '/groups/2'),
        type: DioExceptionType.receiveTimeout,
      );
      await clickGroups(t, find.widgetWithText(FilledButton, 'Simpan'));
      expect(
        find.textContaining('Hasil operasi belum terkonfirmasi.'),
        findsOneWidget,
      );
      expect(
        t
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Simpan'))
            .onPressed,
        isNull,
      );
    },
  );
  testWidgets('loading and sanitized failure do not offer create', (t) async {
    final api = FakeGroups()..failure = StateError('SECRET SQL');
    await mountGroups(t, api);
    expect(find.textContaining('SECRET SQL'), findsNothing);
    expect(
      t
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Tambah Grup'),
          )
          .onPressed,
      isNull,
    );
  });
  for (final size in [
    const Size(1920, 1080),
    const Size(1728, 900),
    const Size(1366, 768),
    const Size(1080, 640),
  ]) {
    testWidgets(
      'Groups desktop $size has no overflow, protected editor absent',
      (t) async {
        await mountGroups(t, FakeGroups(), size: size, shell: true);
        expect(find.byType(AppShell), findsOneWidget);
        await clickGroups(t, find.text('Tambah Grup'));
        expect(find.byType(CheckboxListTile), findsNothing);
        expect(
          find.textContaining('tanpa izin Sidebar otomatis'),
          findsOneWidget,
        );
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      },
    );
  }
}
