
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_notaris/main.dart';

void main() {
  testWidgets('MyApp renders the Notaris PPAT login screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify the login form is displayed.
    expect(find.text('Login'), findsNWidgets(2));
    expect(find.text('User Name'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);
  });
}
