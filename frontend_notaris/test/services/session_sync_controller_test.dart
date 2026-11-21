import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/services/session_sync_controller.dart';

void main() {
  testWidgets(
    'old lifecycle calls never retain/run callback, register timer or report success',
    (tester) async {
      var calls = 0;
      final outcomes = <Object?>[];
      final controller = SessionSyncController(
        synchronize: () async {
          calls++;
        },
        onInitialSyncResult: outcomes.add,
        interval: const Duration(milliseconds: 1),
        resumeCooldown: Duration.zero,
      );
      controller.onAppResumed();
      controller.start();
      controller.start();
      await tester.pump(const Duration(minutes: 16));
      for (var i = 0; i < 3; i++) {
        controller.onAppResumed();
      }
      await tester.pump(const Duration(minutes: 16));
      controller.dispose();
      controller.start();
      controller.onAppResumed();
      await tester.pump();
      expect(calls, 0);
      expect(outcomes, [isA<AutomaticSyncDisabled>()]);
      expect(outcomes.single.toString(), contains('DISABLED_BY_POLICY'));
      expect(tester.binding.transientCallbackCount, 0);
    },
  );
  test('disposed old session cannot schedule a callback on account change', () {
    var calls = 0;
    final old = SessionSyncController(
      synchronize: () async {
        calls++;
      },
    );
    old.dispose();
    old.start();
    old.onAppResumed();
    final next = SessionSyncController(
      synchronize: () async {
        calls++;
      },
    );
    next.start();
    next.onAppResumed();
    next.dispose();
    expect(calls, 0);
  });
}
