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
import 'package:frontend_notaris/screens/groups_desktop_screen.dart';
import 'package:frontend_notaris/services/group_sidebar_access_api_service.dart';

import '../services/group_sidebar_access_api_service_test.dart'
    show accessFixture;
import 'groups_desktop_screen_test.dart' show FakeGroups, clickGroups;
import 'users_desktop_screen_test.dart' show admin, UsersAuth;

class AccessApi extends GroupSidebarAccessApiService {
  AccessApi() : super(Dio());
  Map<String, dynamic> data = accessFixture();
  Completer<void>? hold, readHold;
  Object? error;
  int writes = 0, reads = 0;
  List<GroupSidebarAccessInput>? sent;
  @override
  Future<GroupAccessSnapshot> getByGroup(int id) async {
    reads++;
    await readHold?.future;
    return GroupAccessSnapshot.fromJson(data);
  }

  @override
  Future<void> replaceForGroup({
    required GroupAccessSnapshot snapshot,
    required List<GroupSidebarAccessInput> access,
  }) async {
    writes++;
    sent = access;
    await hold?.future;
    if (error != null) throw error!;
    (data['group'] as Map)['revision'] = snapshot.revision + 1;
    for (final row in data['entries'] as List) {
      final id = (row['sidebar'] as Map)['id'];
      for (final p in access.where((p) => p.sidebarId == id)) {
        p.toJson().forEach((key, value) {
          row[key] = value;
        });
      }
    }
  }
}

class AccessAuth extends UsersAuth {
  AccessAuth(super.s);
  int refreshes = 0;
  @override
  Future<void> refreshCurrentPermissions() async {
    refreshes++;
  }
}

Future<AccessAuth> mountAccess(
  WidgetTester t,
  AccessApi api, {
  bool shell = false,
  Size size = const Size(1366, 768),
  String role = 'superadmin',
  bool offline = false,
  int write = 1,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final font = FontLoader('AccessTest')
    ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
  await font.load();
  final db = MateraiProfileDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final s = admin(role: role, offline: offline, write: write);
  s.sidebars.single['sidebar'] = {
    'sidebar_kode': 'groups',
    'sidebar_nama': 'Groups',
    'status': 1,
  };
  final auth = AccessAuth(s);
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        authControllerProvider.overrideWith((_) => auth),
        groupApiServiceProvider.overrideWithValue(FakeGroups()),
        groupSidebarAccessApiServiceProvider.overrideWithValue(api),
      ],
      child: MaterialApp(
        theme: ThemeData(fontFamily: 'AccessTest'),
        home: shell
            ? AppShell(session: s)
            : const Scaffold(body: GroupsDesktopScreen()),
      ),
    ),
  );
  await t.pumpAndSettle();
  if (shell) {
    await clickGroups(t, find.text('System').first);
    await clickGroups(t, find.text('Groups').first);
  }
  return auth;
}

Finder flag(int id, int col) => find.byKey(ValueKey('access-$id-$col'));
Future<void> openAccess(WidgetTester t) async =>
    clickGroups(t, find.byTooltip('Atur Akses Grup 2'));
void main() {
  for (final size in [const Size(1366, 768), const Size(1920, 1080)]) {
    testWidgets('full catalog hierarchy survives collapse/save at $size', (
      t,
    ) async {
      final api = AccessApi();
      api.data['entries'] = [
        for (final (id, parent, name, code) in [
          (1, 34, 'Users', 'users'),
          (2, 34, 'Groups', 'groups'),
          (3, 34, 'Sidebars', 'sidebars'),
          (4, 10, 'Petugas', 'petugas'),
          (10, 0, 'Master', 'master'),
          (11, 10, 'Pemohon', 'pemohon'),
          (22, 0, 'Transaksi', 'transaksi'),
          (23, 0, 'Monitoring', 'monitoring'),
          (24, 0, 'Pengeluaran', 'pengeluaran'),
          (25, 0, 'Piutang', 'piutang'),
          (26, 0, 'Penghasilan', 'penghasilan'),
          (27, 10, 'Pekerjaan Notaris', 'pekerjaan_notaris'),
          (28, 10, 'Pekerjaan PPAT', 'pekerjaan_ppat'),
          (29, 10, 'Kategori Pekerjaan', 'kategori_pekerjaan'),
          (30, 10, 'Jenis Pengeluaran', 'jenis_pengeluaran'),
          (31, 0, 'Laporan', 'laporan'),
          (32, 31, 'Materai', 'laporan_materai'),
          (33, 31, 'Pendapatan', 'laporan_pendapatan'),
          (34, 0, 'System', 'system'),
          (20, 0, 'Historis', 'historis'),
          (21, 999, 'Parent tidak tersedia', 'unsupported'),
        ])
          {
            'sidebar': {
              'id': id,
              'sidebar_parent_id': parent,
              'sidebar_nama': name,
              'sidebar_kode': code,
              'sidebar_route': {10, 31, 34}.contains(id) ? '#' : '/$code',
              'sidebar_icon': 'folder',
              'sidebar_index': id,
              'status': id == 20 ? 0 : 1,
            },
            'read': id == 20 || id == 21 ? 1 : 0,
            'create': 0,
            'update': 0,
            'delete': 0,
            'editable': id != 20 && id != 21,
            'reason': id == 20
                ? 'Nonaktif'
                : id == 21
                ? 'Parent tidak tersedia'
                : '',
          },
      ];
      await mountAccess(t, api, size: size);
      await openAccess(t);
      expect(find.byKey(const ValueKey('access-row-33')), findsOneWidget);
      await clickGroups(t, flag(28, 2));
      expect(t.widget<Checkbox>(flag(28, 0)).value, true);
      expect(t.widget<Checkbox>(flag(10, 0)).value, false);
      await clickGroups(t, find.byTooltip('Buka/tutup Master'));
      expect(flag(28, 0), findsNothing);
      await clickGroups(t, flag(24, 0));
      await clickGroups(t, find.byTooltip('Buka/tutup Master'));
      expect(t.widget<Checkbox>(flag(28, 2)).value, true);
      expect(t.widget<Checkbox>(flag(20, 0)).onChanged, isNull);
      expect(t.widget<Checkbox>(flag(21, 0)).onChanged, isNull);
      await clickGroups(t, find.text('Simpan Perubahan'));
      expect(api.sent!.length, 19);
      expect(
        api.sent!.any((p) => p.sidebarId == 20 || p.sidebarId == 21),
        false,
      );
      await openAccess(t);
      expect(t.widget<Checkbox>(flag(28, 2)).value, true);
      expect(t.widget<Checkbox>(flag(24, 0)).value, true);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets(
    'API tree, explicit CRUD, independence, bulk and collapse preserve hidden rows',
    (t) async {
      final api = AccessApi();
      await mountAccess(t, api);
      await openAccess(t);
      expect(find.textContaining('ID 2 · revisi 1 ·'), findsOneWidget);
      expect(find.text('Historis'), findsOneWidget);
      expect(t.widget<Checkbox>(flag(12, 0)).onChanged, isNull);
      await t.tap(flag(11, 2));
      await t.pump();
      expect(t.widget<Checkbox>(flag(11, 0)).value, true);
      expect(t.widget<Checkbox>(flag(10, 0)).value, false);
      expect(
        t.widget<Checkbox>(find.byKey(const ValueKey('access-bulk-10'))).value,
        isNull,
      );
      await t.tap(flag(11, 0));
      await t.pump();
      for (var c = 0; c < 4; c++) {
        expect(t.widget<Checkbox>(flag(11, c)).value, false);
      }
      await t.tap(find.byKey(const ValueKey('access-bulk-10')));
      await t.pump();
      expect(t.widget<Checkbox>(flag(11, 3)).value, true);
      await clickGroups(t, find.byTooltip('Buka/tutup Master'));
      expect(flag(11, 0), findsNothing);
      await t.tap(find.byKey(const ValueKey('access-bulk-10')));
      await t.pump();
      await clickGroups(t, find.byTooltip('Buka/tutup Master'));
      expect(t.widget<Checkbox>(flag(11, 3)).value, true);
      expect(t.widget<Checkbox>(flag(10, 0)).value, false);
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'save full editable set/reopen, refresh admin; frozen grants never sent',
    (t) async {
      final api = AccessApi();
      final auth = await mountAccess(t, api);
      await openAccess(t);
      await t.tap(flag(11, 0));
      await t.pump();
      await clickGroups(t, find.text('Simpan Perubahan'));
      for (var i = 0; i < 5 && auth.refreshes == 0; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(api.writes, 1);
      expect(api.sent!.map((r) => r.sidebarId), [10, 11]);
      expect(auth.refreshes, 1);
      await openAccess(t);
      expect(t.widget<Checkbox>(flag(11, 0)).value, true);
      expect(find.textContaining('revisi 2'), findsOneWidget);
      expect(t.widget<Checkbox>(flag(12, 0)).value, true);
    },
  );
  testWidgets(
    'single-flight saving blocks ESC, then safely disposes repeated close',
    (t) async {
      final api = AccessApi()..hold = Completer<void>();
      await mountAccess(t, api);
      await openAccess(t);
      await t.tap(flag(11, 0));
      await t.pump();
      await t.tap(find.text('Simpan Perubahan'));
      await t.pump();
      await t.tap(find.byType(FilledButton).last);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pump();
      expect(api.writes, 1);
      expect(find.text('Atur Akses — CS'), findsOneWidget);
      api.hold!.complete();
      await t.pumpAndSettle();
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('dirty ESC discard does not mutate; loading closes safely', (
    t,
  ) async {
    final api = AccessApi();
    await mountAccess(t, api);
    await openAccess(t);
    await t.tap(flag(11, 0));
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(find.text('Buang perubahan?'), findsOneWidget);
    await clickGroups(t, find.text('Lanjut edit'));
    expect(flag(11, 0), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    await clickGroups(t, find.text('Buang perubahan').last);
    expect(api.writes, 0);
    api.readHold = Completer<void>();
    await t.tap(find.byTooltip('Atur Akses Grup 2'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 350));
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    api.readHold!.complete();
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
  for (final code in [409, 401, 403, 500]) {
    testWidgets('failure $code never retries or reports success', (t) async {
      final api = AccessApi()
        ..error = DioException(
          requestOptions: RequestOptions(),
          response: Response(
            requestOptions: RequestOptions(),
            statusCode: code,
          ),
        );
      await mountAccess(t, api);
      await openAccess(t);
      await t.tap(flag(11, 0));
      await t.pump();
      await clickGroups(t, find.text('Simpan Perubahan'));
      expect(api.writes, 1);
      expect(find.text('Atur Akses — CS'), findsOneWidget);
      if (code == 409) {
        expect(t.widget<Checkbox>(flag(11, 0)).value, true);
        await clickGroups(
          t,
          find.text('Muat ulang dari server (buang edit lokal)'),
        );
        expect(t.widget<Checkbox>(flag(11, 0)).value, false);
        expect(api.writes, 1);
      }
      if (code == 500) {
        expect(
          find.textContaining('Hasil belum terkonfirmasi'),
          findsOneWidget,
        );
        expect(
          t.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
          isNull,
        );
      }
    });
  }
  testWidgets(
    'offline/ordinary/permission deny before access API, protected rows have no action',
    (t) async {
      for (final c in [
        (true, 'superadmin', 1),
        (false, 'user', 1),
        (false, 'superadmin', 0),
      ]) {
        final api = AccessApi();
        await mountAccess(t, api, offline: c.$1, role: c.$2, write: c.$3);
        expect(find.byTooltip('Atur Akses Grup 2'), findsNothing);
        expect(api.reads, 0);
      }
      final api = AccessApi();
      await mountAccess(t, api);
      expect(find.byTooltip('Atur Akses Pemulihan'), findsNothing);
      expect(find.byTooltip('Atur Akses Grup 18'), findsNothing);
    },
  );
  for (final size in [
    const Size(1920, 1080),
    const Size(1728, 900),
    const Size(1366, 768),
    const Size(1080, 640),
  ]) {
    testWidgets('access dialog keeps AppShell and no overflow $size', (
      t,
    ) async {
      await mountAccess(t, AccessApi(), shell: true, size: size);
      await openAccess(t);
      expect(find.byType(AppShell), findsOneWidget);
      expect(find.text('Atur Akses — CS'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
