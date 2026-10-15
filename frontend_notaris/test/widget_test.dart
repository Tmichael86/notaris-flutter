import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_notaris/main.dart';
import 'package:frontend_notaris/providers/auth_provider.dart';
import 'package:frontend_notaris/services/auth_service.dart';

class _UnauthenticatedAuthController extends AuthController {
  _UnauthenticatedAuthController() : super(AuthService()) {
    state = AuthState.unauthenticated();
  }
}

void main() {
  testWidgets('app starts on the Notaris login screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            (ref) => _UnauthenticatedAuthController(),
          ),
        ],
        child: const MyApp(),
      ),
    );

    await tester.pump();

    expect(find.text('SIM Notaris PPAT'), findsOneWidget);
  });
}