import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_notaris/main.dart';

void main() {
  testWidgets('MyApp can be instantiated', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(tester.takeException(), isNull);
  });
}
