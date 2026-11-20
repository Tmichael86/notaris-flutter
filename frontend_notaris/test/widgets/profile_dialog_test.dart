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
import 'package:frontend_notaris/providers/development_smoke_provider.dart';
import 'package:frontend_notaris/providers/profile_provider.dart';
import 'package:frontend_notaris/screens/profile_dialog.dart';
import 'package:frontend_notaris/services/auth_service.dart';
import 'package:frontend_notaris/services/profile_api_service.dart';

import '../services/administration_auth_test.dart' show ReadyAuth, session;
import '../services/profile_api_test.dart';

class ProfileAuth extends ReadyAuth {
  ProfileAuth() : super(AuthService(dio: Dio()), session(role: 'user'));
  int refreshes = 0;
  @override
  Future<void> refreshCurrentPermissions() async {
    refreshes++;
    state = AuthState.authenticated(state.session!);
  }
}

class ProfileApi extends ProfileApiService {
  ProfileApi() : super(Dio(), session: () => session(role: 'user'));
  int reads = 0, saves = 0;
  Object? error;
  Completer<void>? hold;
  Map<String, dynamic> data = ownProfileData();
  @override
  Future<OwnProfile> read() async {
    reads++;
    if (error != null && saves == 0) throw error!;
    return OwnProfile.fromJson(data, 1);
  }

  @override
  Future<OwnProfile> save({
    required int expectedRevision,
    required String nama,
    required String? noTelp,
    required String? alamat,
  }) async {
    saves++;
    await hold?.future;
    if (error != null) throw error!;
    data = {
      ...data,
      'nama': nama,
      'no_telp': noTelp,
      'alamat': alamat,
      'revision': expectedRevision + 1,
    };
    return OwnProfile.fromJson(data, 1);
  }
}

Future<ProfileAuth> mountProfile(
  WidgetTester t,
  ProfileApi api, {
  Size size = const Size(1366, 768),
  bool shell = false,
  bool smoke = false,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await (FontLoader(
    'ProfileTest',
  )..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))).load();
  final db = MateraiProfileDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final auth = ProfileAuth();
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith((_) => auth),
        appDatabaseProvider.overrideWithValue(db),
        profileApiProvider.overrideWithValue(api),
        developmentUiSmokeProvider.overrideWithValue(smoke),
      ],
      child: MaterialApp(
        theme: ThemeData(fontFamily: 'ProfileTest'),
        home: shell
            ? AppShell(session: auth.state.session)
            : Scaffold(
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
  await t.pumpAndSettle();
  if (shell) {
    await t.tap(find.byTooltip('Akun'));
    await t.pumpAndSettle();
    await t.tap(find.text('Profile').last);
  } else {
    await t.tap(find.text('Open Profile'));
  }
  await t.pumpAndSettle();
  return auth;
}

Future<void> editName(WidgetTester t, String value) async {
  await t.tap(find.byKey(const Key('profile-edit')));
  await t.pumpAndSettle();
  await t.enterText(find.byKey(const Key('profile-nama')), value);
}

void main() {
  for (final size in [
    const Size(1920, 1080),
    const Size(1728, 900),
    const Size(1366, 768),
    const Size(1080, 640),
  ]) {
    testWidgets('view/edit/Save/readback at $size', (t) async {
      final api = ProfileApi();
      final auth = await mountProfile(t, api, size: size);
      expect(find.text('Username: rani.uji'), findsOneWidget);
      expect(find.textContaining('Belum diisi'), findsNWidgets(2));
      await editName(t, 'Rani Baru');
      expect(find.byType(TextFormField), findsNWidgets(3));
      await t.tap(find.byKey(const Key('profile-save')));
      await t.pumpAndSettle();
      expect(api.saves, 1);
      expect(auth.refreshes, 1);
      expect(api.reads, greaterThan(1));
      expect(find.textContaining('dibaca kembali'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('Cancel/ESC discard protects draft and safe repeated close', (
    t,
  ) async {
    final api = ProfileApi();
    await mountProfile(t, api);
    await editName(t, 'Belum Disimpan');
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(find.text('Buang perubahan?'), findsOneWidget);
    await t.tap(find.text('Lanjut edit'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('profile-cancel')));
    await t.pumpAndSettle();
    await t.tap(find.text('Buang perubahan'));
    await t.pumpAndSettle();
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(api.saves, 0);
    expect(find.byType(ProfileDialog), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets('loading Save blocks double-submit and ESC', (t) async {
    final api = ProfileApi()..hold = Completer<void>();
    await mountProfile(t, api);
    await editName(t, 'Rani Baru');
    await t.tap(find.byKey(const Key('profile-save')));
    await t.pump();
    await t.tap(find.byKey(const Key('profile-save')));
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pump();
    expect(api.saves, 1);
    expect(find.byType(ProfileDialog), findsOneWidget);
    api.hold!.complete();
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
  testWidgets('validation prevents HTTP and UiSmoke disables edit', (t) async {
    final api = ProfileApi();
    await mountProfile(t, api);
    await editName(t, ' ');
    await t.tap(find.byKey(const Key('profile-save')));
    await t.pumpAndSettle();
    expect(api.saves, 0);
    expect(find.text('Nama wajib diisi.'), findsOneWidget);
  });
  testWidgets('UiSmoke profile mutation unavailable', (t) async {
    await mountProfile(t, ProfileApi(), smoke: true);
    expect(
      t.widget<FilledButton>(find.byKey(const Key('profile-edit'))).onPressed,
      isNull,
    );
  });
  for (final status in [401, 403, 409, 400, 500, null]) {
    testWidgets('error $status is honest and no automatic retry', (t) async {
      final api = ProfileApi();
      await mountProfile(t, api);
      await editName(t, 'Rani Baru');
      api.error = DioException(
        requestOptions: RequestOptions(),
        response: status == null
            ? null
            : Response(requestOptions: RequestOptions(), statusCode: status),
      );
      await t.tap(find.byKey(const Key('profile-save')));
      await t.pumpAndSettle();
      expect(api.saves, 1);
      expect(find.text(profileError(api.error!)), findsOneWidget);
      expect(
        t.widget<FilledButton>(find.byKey(const Key('profile-save'))).onPressed,
        isNull,
      );
    });
  }
  testWidgets('account menu opens Profile in the same persistent AppShell', (
    t,
  ) async {
    await mountProfile(t, ProfileApi(), shell: true);
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(ProfileDialog), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
