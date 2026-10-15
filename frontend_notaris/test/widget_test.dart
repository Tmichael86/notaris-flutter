import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_notaris/main.dart';

void main() {
  testWidgets('app starts on the Notaris login screen', (
    WidgetTester tester,
  ) async {
    // The branding title is shown in the desktop layout, so use a desktop
    // test viewport instead of the default compact test viewport.
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('SIM Notaris PPAT'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'User Name',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Password',
      ),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Forgot Password?'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });
}
