import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/services/periodic_sync_runner.dart';

void main() {
  group('PeriodicSyncRunner', () {
    test('starts only one timer when start is called repeatedly', () {
      final runner = PeriodicSyncRunner(
        onTick: () async {},
        interval: const Duration(hours: 1),
      );

      runner.start();
      runner.start();

      expect(runner.isRunning, isTrue);
      runner.dispose();
      expect(runner.isRunning, isFalse);
    });

    test('runs callback on interval and stops after dispose', () async {
      var tickCount = 0;
      final runner = PeriodicSyncRunner(
        onTick: () async {
          tickCount++;
        },
        interval: const Duration(milliseconds: 10),
      );

      runner.start();
      await Future<void>.delayed(const Duration(milliseconds: 35));
      runner.dispose();
      final countAtDispose = tickCount;
      await Future<void>.delayed(const Duration(milliseconds: 25));

      expect(countAtDispose, greaterThanOrEqualTo(1));
      expect(tickCount, countAtDispose);
    });

    test('continues scheduling after callback throws', () async {
      var tickCount = 0;
      final runner = PeriodicSyncRunner(
        onTick: () async {
          tickCount++;
          if (tickCount == 1) throw StateError('temporary failure');
        },
        interval: const Duration(milliseconds: 10),
      );

      runner.start();
      await Future<void>.delayed(const Duration(milliseconds: 35));
      runner.dispose();

      expect(tickCount, greaterThanOrEqualTo(2));
    });
  });
}
