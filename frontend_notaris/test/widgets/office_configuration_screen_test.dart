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
import 'package:frontend_notaris/providers/office_configuration_provider.dart';
import 'package:frontend_notaris/screens/konfigurasi_umum_desktop_screen.dart';
import 'package:frontend_notaris/services/auth_service.dart';
import 'package:frontend_notaris/services/office_configuration_api_service.dart';

import '../services/administration_auth_test.dart' show ReadyAuth;
import '../services/office_configuration_test.dart';

class OfficeApi extends OfficeConfigurationApiService {
  OfficeApi() : super(Dio());
  int calls = 0;
  Object? error;
  Completer<void>? hold;
  @override
  Future<OfficeConfiguration> read() async {
    calls++;
    await hold?.future;
    if (error != null) throw error!;
    return OfficeConfiguration.fromJson(officeData());
  }
}

Future<ReadyAuth> mountOffice(
  WidgetTester t,
  OfficeApi api, {
  Size size = const Size(1366, 768),
  bool read = true,
  bool shell = false,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await (FontLoader(
    'OfficeTest',
  )..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))).load();
  final db = MateraiProfileDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final auth = ReadyAuth(AuthService(dio: Dio()), officeSession(read: read));
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith((_) => auth),
        officeConfigurationApiProvider.overrideWithValue(api),
        appDatabaseProvider.overrideWithValue(db),
      ],
      child: MaterialApp(
        theme: ThemeData(fontFamily: 'OfficeTest'),
        home: shell
            ? AppShell(session: auth.state.session)
            : const Scaffold(body: KonfigurasiUmumDesktopScreen()),
      ),
    ),
  );
  await t.pumpAndSettle();
  if (shell) {
    await t.tap(find.text('System').first);
    await t.pumpAndSettle();
    await t.tap(find.text('Konfigurasi Umum').first);
    await t.pumpAndSettle();
  }
  return auth;
}

void main() {
  for (final size in [
    const Size(1920, 1080),
    const Size(1728, 900),
    const Size(1366, 768),
    const Size(1080, 640),
  ]) {
    testWidgets('13 fields and responsive read-only $size', (t) async {
      final api = OfficeApi();
      await mountOffice(t, api, size: size);
      for (final key in [...officeTextFields, ...officeAmountFields]) {
        expect(find.byKey(Key('office-$key')), findsOneWidget);
      }
      expect(find.text('Belum diisi'), findsNWidgets(2));
      expect(find.text('NOTARISDEV SYNTHETIC v1'), findsNothing);
      expect(find.text('Simpan'), findsNothing);
      expect(find.byIcon(Icons.edit), findsNothing);
      expect(find.byType(TextField), findsNothing);
      await t.tap(find.byKey(const Key('office-refresh')));
      await t.pumpAndSettle();
      expect(api.calls, 2);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('permission refresh hides old values and never loads denied', (
    t,
  ) async {
    final api = OfficeApi();
    final auth = await mountOffice(t, api, read: false);
    expect(api.calls, 0);
    auth.state = AuthState.authenticated(officeSession());
    await t.pumpAndSettle();
    expect(api.calls, 1);
    auth.state = AuthState.authenticated(officeSession(read: false));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('office-alamat')), findsNothing);
  });
  testWidgets('loading refresh is single-flight without stale values', (
    t,
  ) async {
    final api = OfficeApi();
    await mountOffice(t, api);
    api.hold = Completer<void>();
    await t.tap(find.byKey(const Key('office-refresh')));
    await t.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      t
          .widget<OutlinedButton>(find.byKey(const Key('office-refresh')))
          .onPressed,
      isNull,
    );
    expect(find.byKey(const Key('office-alamat')), findsNothing);
    api.hold!.complete();
    await t.pumpAndSettle();
    expect(api.calls, 2);
  });
  for (final status in [401, 403, 404, 409, 422, 500, null]) {
    testWidgets('honest backend failure $status', (t) async {
      final api = OfficeApi()
        ..error = DioException(
          requestOptions: RequestOptions(),
          response: status == null
              ? null
              : Response(
                  requestOptions: RequestOptions(),
                  statusCode: status,
                  data: {'code': 'configuration_missing'},
                ),
        );
      await mountOffice(t, api);
      expect(find.text(officeConfigurationError(api.error!)), findsOneWidget);
      expect(find.byKey(const Key('office-alamat')), findsNothing);
    });
  }
  testWidgets('persistent shell contains real configuration viewer', (t) async {
    await mountOffice(t, OfficeApi(), shell: true);
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byKey(const Key('office-alamat')), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
