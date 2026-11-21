import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/services/periodic_sync_runner.dart';

void main() {
  testWidgets(
    'legacy periodic boundary cannot schedule or execute a write callback',
    (tester) async {
      var calls = 0;
      final runner = PeriodicSyncRunner(
        onTick: () async {
          calls++;
        },
        interval: const Duration(milliseconds: 1),
      );
      runner.start();
      runner.start();
      expect(runner.isRunning, false);
      await tester.pump(const Duration(minutes: 16));
      runner.dispose();
      runner.start();
      await tester.pump(const Duration(minutes: 16));
      expect(calls, 0);
      expect(runner.isRunning, false);
    },
  );
}
