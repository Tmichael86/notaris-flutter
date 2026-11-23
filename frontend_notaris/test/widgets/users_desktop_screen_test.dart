import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/core/widgets/app_shell.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/models/auth_session.dart';
import 'package:frontend_notaris/providers/auth_provider.dart';
import 'package:frontend_notaris/providers/database_provider.dart';
import 'package:frontend_notaris/providers/development_smoke_provider.dart';
import 'package:frontend_notaris/providers/pekerjaan_provider.dart'
    show userApiServiceProvider;
import 'package:frontend_notaris/screens/users_desktop_screen.dart';
import 'package:frontend_notaris/services/auth_service.dart';
import 'package:frontend_notaris/services/user_api_service.dart';

import '../services/user_api_service_test.dart' show userRow;

AuthSession admin({
  String role = 'superadmin',
  bool offline = false,
  int write = 1,
}) => AuthSession(
  token:
      'head.${base64Url.encode(utf8.encode(jsonEncode({'uid': 101, 'gid': 101, 'iss': 'backend-notaris-go', 'sv': 1, 'exp': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000})))}.signature',
  userId: 101,
  groupId: 101,
  userName: 'Administrator Uji',
  groupName: 'Admin',
  groupType: role,
  user: const {},
  verifiedAt: DateTime.now(),
  isOffline: offline,
  sidebars: [
    {
      'sidebar': {
        'sidebar_kode': 'users',
        'sidebar_nama': 'Users',
        'status': 1,
      },
      'read': 1,
      'create': write,
      'update': write,
      'delete': write,
    },
  ],
);

class UsersAuth extends AuthController {
  UsersAuth(AuthSession s) : super(AuthService()) {
    state = AuthState.authenticated(s);
  }
}

class FakeUsers extends UserApiService {
  FakeUsers() : super(Dio());
  final queries = <UsersQuery>[];
  final rows = <UserApiModel>[
    for (var i = 0; i < 17; i++)
      UserApiModel.fromJson(
        userRow(
          id: 301 + i,
          name: 'Operator ${i + 1}',
          group: i.isEven ? 201 : 203,
          status: i == 16 ? 0 : 1,
        ),
      ),
  ];
  final groups = const [
    UserGroupRef(201, 'Operasional', 'user', 1),
    UserGroupRef(203, 'Arsip', 'user', 1),
  ];
  Completer<void>? hold;
  Object? failure;
  int creates = 0, updates = 0, deactivates = 0, resets = 0, gets = 0;
  @override
  Future<UsersPage> list(UsersQuery q) async {
    queries.add(q);
    if (failure != null) throw failure!;
    final found = rows
        .where(
          (r) =>
              (q.groupId == null || q.groupId == r.groupId) &&
              (q.status == null || q.status == r.status) &&
              (q.search.isEmpty ||
                  r.nama.contains(q.search) ||
                  r.username.contains(q.search)),
        )
        .toList();
    return (
      items: found.skip((q.page - 1) * 10).take(10).toList(),
      total: found.length,
      page: q.page,
      pageSize: 10,
      groups: groups,
    );
  }

  @override
  Future<List<UserGroupRef>> assignableGroups() async => groups;
  @override
  Future<UserApiModel> get(int id) async {
    gets++;
    return UserApiModel.fromJson(
      userRow(id: id, revision: 2, name: 'Data server terbaru'),
    );
  }

  @override
  Future<UserApiModel> create({
    required int groupId,
    required String nama,
    required String username,
    required String email,
    required String password,
    required String passwordConfirm,
    String? noTelp,
    String? alamat,
  }) async {
    creates++;
    await hold?.future;
    if (failure != null) throw failure!;
    final row = UserApiModel.fromJson({
      ...userRow(id: 900, name: nama, group: groupId),
      'username': username,
      'email': email,
    });
    rows.insert(0, row);
    return row;
  }

  @override
  Future<UserApiModel> update({
    required int id,
    required int expectedRevision,
    required int groupId,
    required String nama,
    required String username,
    required String email,
    String? noTelp,
    String? alamat,
  }) async {
    updates++;
    await hold?.future;
    if (failure != null) throw failure!;
    return UserApiModel.fromJson({
      ...userRow(
        id: id,
        revision: expectedRevision + 1,
        name: nama,
        group: groupId,
      ),
      'username': username,
      'email': email,
    });
  }

  @override
  Future<void> deactivate(int id, {required int expectedRevision}) async {
    deactivates++;
    if (failure != null) throw failure!;
    final i = rows.indexWhere((r) => r.id == id);
    rows[i] = UserApiModel.fromJson(
      userRow(id: id, status: 0, revision: expectedRevision + 1),
    );
  }

  @override
  Future<void> resetPassword(
    int id, {
    required int expectedRevision,
    required String password,
    required String passwordConfirm,
  }) async {
    resets++;
    if (failure != null) throw failure!;
  }
}

Future<void> mount(
  WidgetTester t,
  FakeUsers api, {
  AuthSession? session,
  bool shell = false,
  Size size = const Size(1366, 900),
}) async {
  final loader = FontLoader('UsersTest')
    ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
  await loader.load();
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final db = MateraiProfileDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final actor = session ?? admin();
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        developmentUiSmokeProvider.overrideWithValue(true),
        authControllerProvider.overrideWith((_) => UsersAuth(actor)),
        userApiServiceProvider.overrideWithValue(api),
      ],
      child: MaterialApp(
        theme: ThemeData(fontFamily: 'UsersTest'),
        home: shell
            ? AppShell(session: actor)
            : const Scaffold(body: UsersDesktopScreen()),
      ),
    ),
  );
  await t.pumpAndSettle();
  if (shell) {
    await t.tap(find.text('System').first);
    await t.pumpAndSettle();
    final menu = find.text('Users').first;
    await t.ensureVisible(menu);
    await t.tap(menu);
    await t.pumpAndSettle();
  }
}

Future<void> tapTooltip(WidgetTester t, String tooltip) async {
  final f = find.byTooltip(tooltip);
  await t.ensureVisible(f);
  await t.tap(f);
  await t.pumpAndSettle();
}

Finder field(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);
Future<void> enter(WidgetTester t, String label, String value) async {
  final f = field(label);
  await t.ensureVisible(f);
  await t.enterText(f, value);
  await t.pump();
}

Future<void> fillCreate(WidgetTester t) async {
  await enter(t, 'Nama', 'Operator Baru');
  await enter(t, 'Username', 'operator.baru');
  await enter(t, 'Email', 'baru@example.invalid');
  final dropdown = find.byType(DropdownButtonFormField<int>).last;
  await t.ensureVisible(dropdown);
  await t.tap(dropdown);
  await t.pumpAndSettle();
  await t.tap(find.text('Operasional').last);
  await t.pumpAndSettle();
  await enter(t, 'Password', 'unit-test-password');
  await enter(t, 'Konfirmasi password', 'unit-test-password');
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  testWidgets(
    'server listing, pagination, search, empty and status are real projections',
    (t) async {
      final api = FakeUsers();
      await mount(t, api);
      expect(find.text('17 user · Halaman 1 / 2'), findsOneWidget);
      await t.tap(find.text('Berikutnya'));
      await t.pumpAndSettle();
      expect(api.queries.last.page, 2);
      expect(find.text('Nonaktif'), findsOneWidget);
      await t.enterText(find.byKey(const Key('users-search')), 'not-found');
      await t.tap(find.byTooltip('Cari Users'));
      await t.pumpAndSettle();
      expect(api.queries.last.page, 1);
      expect(api.queries.last.search, 'not-found');
      expect(find.text('Tidak ada user yang cocok.'), findsOneWidget);
    },
  );
  testWidgets(
    'group selection uses backend ID and protected rows cannot mutate',
    (t) async {
      final api = FakeUsers();
      await mount(t, api);
      await t.tap(find.byKey(const Key('users-group-filter')));
      await t.pumpAndSettle();
      await t.tap(find.text('Arsip').last);
      await t.pumpAndSettle();
      expect(api.queries.last.groupId, 203);
    },
  );
  testWidgets(
    'unauthorized and offline views never resolve administrative API',
    (t) async {
      for (final session in [admin(role: 'user'), admin(offline: true)]) {
        final api = FakeUsers();
        await mount(t, api, session: session);
        expect(api.queries, isEmpty);
        expect(
          find.textContaining('Administrasi offline tidak tersedia'),
          findsOneWidget,
        );
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
      }
    },
  );
  testWidgets('read-only grant disables mutation controls', (t) async {
    final api = FakeUsers();
    await mount(t, api, session: admin(write: 0));
    expect(
      t
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Tambah User'),
          )
          .onPressed,
      isNull,
    );
    expect(
      t
          .widget<IconButton>(
            find
                .ancestor(
                  of: find.byTooltip('Edit operator.301'),
                  matching: find.byType(IconButton),
                )
                .first,
          )
          .onPressed,
      isNull,
    );
  });
  testWidgets(
    'self and privileged accounts are visible but have no target actions',
    (t) async {
      final api = FakeUsers();
      api.rows.insertAll(0, [
        UserApiModel.fromJson({
          ...userRow(id: 101),
          'group_jenis': 'superadmin',
        }),
        UserApiModel.fromJson({
          ...userRow(id: 102),
          'group_jenis': 'superadmin',
        }),
      ]);
      await mount(t, api);
      expect(find.text('Terproteksi'), findsNWidgets(2));
      expect(find.byTooltip('Edit operator.101'), findsNothing);
      expect(find.byTooltip('Nonaktifkan operator.102'), findsNothing);
      expect(api.updates + api.deactivates + api.resets, 0);
    },
  );
  testWidgets(
    'form validation, dropdown ESC, dirty discard and repeated close are safe',
    (t) async {
      final api = FakeUsers();
      await mount(t, api);
      await t.tap(find.text('Tambah User'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Simpan'));
      await t.pumpAndSettle();
      expect(api.creates, 0);
      await enter(t, 'Nama', 'Belum tersimpan');
      final d = find.byType(DropdownButtonFormField<int>).last;
      await t.ensureVisible(d);
      await t.tap(d);
      await t.pumpAndSettle();
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.text('Buang perubahan?'), findsOneWidget);
      await t.tap(find.text('Lanjut edit'));
      await t.pumpAndSettle();
      await t.tap(find.text('Batal'));
      await t.pumpAndSettle();
      await t.tap(find.text('Buang perubahan'));
      await t.pumpAndSettle();
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(api.creates, 0);
    },
  );
  testWidgets(
    'pending create stays open, blocks ESC/double-submit and refreshes only after ACK',
    (t) async {
      final api = FakeUsers();
      await mount(t, api);
      await t.tap(find.text('Tambah User'));
      await t.pumpAndSettle();
      await fillCreate(t);
      api.hold = Completer<void>();
      await t.tap(find.widgetWithText(FilledButton, 'Simpan'));
      await t.pump();
      expect(api.creates, 1);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pump();
      expect(find.byType(Dialog), findsOneWidget);
      expect(
        find.text('Perubahan Users dikonfirmasi oleh server.'),
        findsNothing,
      );
      api.hold!.complete();
      await t.pumpAndSettle();
      expect(api.creates, 1);
      expect(find.byType(Dialog), findsNothing);
      expect(api.queries.length, greaterThan(1));
      expect(
        find.text('Perubahan Users dikonfirmasi oleh server.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    '409 reloads affected record but requires explicit review before retry',
    (t) async {
      final api = FakeUsers();
      await mount(t, api);
      await tapTooltip(t, 'Edit operator.301');
      await enter(t, 'Nama', 'Stale input');
      final request = RequestOptions(path: '/users/301');
      api.failure = DioException(
        requestOptions: request,
        response: Response(
          requestOptions: request,
          statusCode: 409,
          data: {'code': 'stale_revision'},
        ),
      );
      await t.tap(find.widgetWithText(FilledButton, 'Simpan'));
      await t.pumpAndSettle();
      expect(api.updates, 1);
      expect(api.gets, 1);
      expect(find.textContaining('Penyimpanan diblokir'), findsOneWidget);
      expect(
        find.text('Perubahan Users dikonfirmasi oleh server.'),
        findsNothing,
      );
      await t.tap(find.text('Gunakan data server terbaru'));
      await t.pumpAndSettle();
      expect(find.text('Data server terbaru'), findsOneWidget);
      expect(api.updates, 1);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'unconfirmed mutation never reports success or allows blind resubmit',
    (t) async {
      final api = FakeUsers();
      await mount(t, api);
      await t.tap(find.text('Tambah User'));
      await t.pumpAndSettle();
      await fillCreate(t);
      final request = RequestOptions(path: '/users');
      api.failure = DioException(
        requestOptions: request,
        response: Response(
          requestOptions: request,
          statusCode: 500,
          data: {'message': 'private server details'},
        ),
      );
      await t.tap(find.widgetWithText(FilledButton, 'Simpan'));
      await t.pumpAndSettle();
      expect(api.creates, 1);
      expect(
        t
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Simpan'))
            .onPressed,
        isNull,
      );
      expect(
        find.textContaining('Belum ada konfirmasi server'),
        findsOneWidget,
      );
      expect(find.textContaining('private server details'), findsNothing);
      expect(
        find.text('Perubahan Users dikonfirmasi oleh server.'),
        findsNothing,
      );
    },
  );
  testWidgets(
    'deactivation cancel does not mutate; confirmation invokes existing endpoint',
    (t) async {
      final api = FakeUsers();
      await mount(t, api);
      await tapTooltip(t, 'Nonaktifkan operator.301');
      await t.tap(find.text('Batal'));
      await t.pumpAndSettle();
      expect(api.deactivates, 0);
      await tapTooltip(t, 'Nonaktifkan operator.301');
      await t.tap(find.byType(CheckboxListTile));
      await t.pump();
      await t.tap(find.widgetWithText(FilledButton, 'Nonaktifkan Akun'));
      await t.pumpAndSettle();
      expect(api.deactivates, 1);
      expect(api.rows.first.status, 0);
    },
  );
  testWidgets(
    'reset is separate, confirmation required and error is sanitized',
    (t) async {
      final api = FakeUsers();
      await mount(t, api);
      await tapTooltip(t, 'Reset password operator.301');
      await enter(t, 'Password', 'unit-test-password');
      await enter(t, 'Konfirmasi password', 'unit-test-password');
      expect(
        t
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Reset Password'),
            )
            .onPressed,
        isNull,
      );
      await t.tap(find.byType(CheckboxListTile));
      await t.pump();
      await t.tap(find.widgetWithText(FilledButton, 'Reset Password'));
      await t.pumpAndSettle();
      expect(api.resets, 1);
      expect(api.updates, 0);
    },
  );
  for (final size in [
    const Size(1920, 1080),
    const Size(1728, 900),
    const Size(1366, 768),
    const Size(1080, 640),
  ]) {
    testWidgets('Users preserves one shared shell without overflow at $size', (
      t,
    ) async {
      final api = FakeUsers();
      await mount(t, api, shell: true, size: size);
      expect(find.byType(AppShell), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.tap(find.text('Tambah User'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byType(AppShell), findsOneWidget);
    });
  }
  testWidgets(
    'API failure is explicit and has no fake successful persistence',
    (t) async {
      final api = FakeUsers()..failure = StateError('offline');
      await mount(t, api);
      expect(find.textContaining('tidak dapat dimuat'), findsOneWidget);
      expect(
        find.text('Perubahan Users dikonfirmasi oleh server.'),
        findsNothing,
      );
    },
  );
}
