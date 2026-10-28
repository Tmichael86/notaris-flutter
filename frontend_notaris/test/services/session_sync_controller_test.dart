import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/services/session_sync_controller.dart';

void main() {
  group('SessionSyncController', () {
    test('runs an initial sync immediately when the session starts', () async {
      var syncCount = 0;
      final controller = SessionSyncController(
        synchronize: () async {
          syncCount++;
        },
        interval: const Duration(hours: 1),
      );

      controller.start();
      await Future<void>.delayed(Duration.zero);

      expect(syncCount, 1);
      controller.dispose();
    });

    test('reports the initial sync result on success', () async {
      Object? reportedError = Object();
      final controller = SessionSyncController(
        synchronize: () async {},
        onInitialSyncResult: (error) => reportedError = error,
        interval: const Duration(hours: 1),
      );

      controller.start();
      await Future<void>.delayed(Duration.zero);

      expect(reportedError, isNull);
      controller.dispose();
    });

    test('reports the initial sync error on failure', () async {
      Object? reportedError;
      final failure = StateError('offline');
      final controller = SessionSyncController(
        synchronize: () async => throw failure,
        onInitialSyncResult: (error) => reportedError = error,
        interval: const Duration(hours: 1),
      );

      controller.start();
      await Future<void>.delayed(Duration.zero);

      expect(reportedError, same(failure));
      controller.dispose();
    });

    test('triggers another sync when the app resumes', () async {
      var syncCount = 0;
      final controller = SessionSyncController(
        synchronize: () async {
          syncCount++;
        },
        interval: const Duration(hours: 1),
      );

      controller.start();
      await Future<void>.delayed(Duration.zero);
      controller.onAppResumed();
      await Future<void>.delayed(Duration.zero);

      expect(syncCount, 2);
      controller.dispose();
    });

    test('does not trigger sync before start or after disposal', () async {
      var syncCount = 0;
      final controller = SessionSyncController(
        synchronize: () async {
          syncCount++;
        },
        interval: const Duration(hours: 1),
      );

      controller.onAppResumed();
      expect(syncCount, 0);

      controller.start();
      await Future<void>.delayed(Duration.zero);
      controller.dispose();
      controller.onAppResumed();
      await Future<void>.delayed(Duration.zero);

      expect(syncCount, 1);
    });

    test('continues to accept triggers after a failed sync', () async {
      var syncCount = 0;
      final controller = SessionSyncController(
        synchronize: () async {
          syncCount++;
          if (syncCount == 1) throw StateError('offline');
        },
        interval: const Duration(hours: 1),
      );

      controller.start();
      await Future<void>.delayed(Duration.zero);
      controller.onAppResumed();
      await Future<void>.delayed(Duration.zero);

      expect(syncCount, 2);
      controller.dispose();
    });

    test('starting twice does not duplicate the initial sync', () async {
      var syncCount = 0;
      final controller = SessionSyncController(
        synchronize: () async {
          syncCount++;
        },
        interval: const Duration(hours: 1),
      );

      controller.start();
      controller.start();
      await Future<void>.delayed(Duration.zero);

      expect(syncCount, 1);
      controller.dispose();
    });
  });
}
