import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/providers/pekerjaan_provider.dart';

void main() {
  group('SyncCoordinator', () {
    test(
      'direct global invocation always denies without an executable callback',
      () async {
        final statuses = <SyncStatus>[];
        final coordinator = SyncCoordinator(onStatusChanged: statuses.add);
        for (var i = 0; i < 3; i++) {
          await expectLater(
            coordinator.synchronizeNow(),
            throwsA(
              isA<SyncFailure>().having(
                (e) => e.kind,
                'kind',
                SyncFailureKind.disabledByPolicy,
              ),
            ),
          );
        }
        expect(statuses, List.filled(3, SyncStatus.disabledByPolicy));
        expect(statuses, isNot(contains(SyncStatus.success)));
      },
    );

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
