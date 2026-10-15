import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_notaris/main.dart';

void main() {
  testWidgets('app starts on the Notaris login screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('SIM Notaris PPAT'), findsOneWidget);
    expect(find.text('User Name'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Forgot Password?'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });
}
