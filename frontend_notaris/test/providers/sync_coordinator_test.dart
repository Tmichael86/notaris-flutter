import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/providers/pekerjaan_provider.dart';

void main() {
  group('SyncCoordinator', () {
    test('coalesces concurrent requests into one sync operation', () async {
      final completer = Completer<void>();
      var runCount = 0;
      final statuses = <SyncStatus>[];
      final coordinator = SyncCoordinator(
        runSync: () {
          runCount++;
          return completer.future;
        },
        onStatusChanged: statuses.add,
      );

      final first = coordinator.synchronizeNow();
      final second = coordinator.synchronizeNow();

      expect(runCount, 1);
      expect(statuses, [SyncStatus.syncing]);

      completer.complete();
      await Future.wait([first, second]);

      expect(statuses, [SyncStatus.syncing, SyncStatus.success]);
    });

    test('sets success after a completed sync', () async {
      final statuses = <SyncStatus>[];
      final coordinator = SyncCoordinator(
        runSync: () async {},
        onStatusChanged: statuses.add,
      );

      await coordinator.synchronizeNow();

      expect(statuses, [SyncStatus.syncing, SyncStatus.success]);
    });

    test('marks connection errors as pending and allows retry', () async {
      final statuses = <SyncStatus>[];
      var attempts = 0;
      final coordinator = SyncCoordinator(
        runSync: () async {
          attempts++;
          if (attempts == 1) {
            throw DioException(
              requestOptions: RequestOptions(path: '/sync'),
              type: DioExceptionType.connectionError,
            );
          }
        },
        onStatusChanged: statuses.add,
      );

      await expectLater(
        coordinator.synchronizeNow(),
        throwsA(
          isA<SyncFailure>().having(
            (failure) => failure.kind,
            'kind',
            SyncFailureKind.offline,
          ),
        ),
      );

      await coordinator.synchronizeNow();

      expect(attempts, 2);
      expect(statuses, [
        SyncStatus.syncing,
        SyncStatus.pending,
        SyncStatus.syncing,
        SyncStatus.success,
      ]);
    });

    test('maps authorization errors to a non-retryable failure', () {
      final request = RequestOptions(path: '/sync');
      final failure = SyncCoordinator.mapSyncFailure(
        DioException(
          requestOptions: request,
          response: Response<dynamic>(requestOptions: request, statusCode: 401),
        ),
      );

      expect(failure.kind, SyncFailureKind.unauthorized);
      expect(failure.userMessage, contains('login kembali'));
    });

    test('maps server errors to a retryable failure', () {
      final request = RequestOptions(path: '/sync');
      final failure = SyncCoordinator.mapSyncFailure(
        DioException(
          requestOptions: request,
          response: Response<dynamic>(requestOptions: request, statusCode: 503),
        ),
      );

      expect(failure.kind, SyncFailureKind.server);
    });

    test('preserves an existing SyncFailure', () {
      const original = SyncFailure(
        SyncFailureKind.conflict,
        'Conflict detected',
      );

      expect(
        identical(SyncCoordinator.mapSyncFailure(original), original),
        isTrue,
      );
    });
  });
}
