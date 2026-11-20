import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart' hide Fake;
import 'package:frontend_notaris/groups_acceptance_main.dart';
import 'package:frontend_notaris/services/auth_service.dart';

import '../repositories/petugas_local_sync_test.dart' show Fake, reply;
import '../widgets/users_desktop_screen_test.dart' show admin;

void main() {
  test('runtime attestation rejects wrong marker, account, target or cloud enabled', () async {
    const profile = '00000000000000000000000000000000';
    final valid = <String, Object>{
      'profile': profile,
      'scope': 'groups-v1/$profile',
      'database': 'groups_v1_$profile',
      'host': '127.0.0.1',
      'port': 55796,
      'marker': 'NOTARIS GROUPS V1 DISPOSABLE $profile',
      'account_id': 101,
      'group_id': 101,
      'cloud_sync': false,
    };
    for (final bad in <Map<String, Object>>[
      {'port': 5432},
      {'marker': 'notarisdev'},
      {'account_id': 102},
      {'cloud_sync': true},
      {'scope': 'promotional/$profile'},
    ]) {
      final dio = groupsAcceptanceHttp()
        ..httpClientAdapter = Fake((r) async => reply({...valid, ...bad}));
      await expectLater(
        GroupsAcceptanceAuth(dio, profile).attest(admin()),
        throwsA(isA<AuthException>()),
      );
      dio.close();
    }
  });
  test(
    'Groups acceptance transport binds exact origin and Groups routes only',
    () async {
      final dio = groupsAcceptanceHttp(administration: true);
      var sent = 0;
      dio.httpClientAdapter = Fake((r) async {
        sent++;
        return reply({'success': true, 'data': null});
      });
      for (final path in [
        'http://127.0.0.1:8081/api/v1/groups',
        '/users',
        '/groups/1/sidebar-access',
        '/transaksi-notaris/sync/create',
        '/groups/0',
        '/groups/1/activate',
      ]) {
        await expectLater(
          dio.post<Object?>(path),
          throwsA(isA<DioException>()),
        );
      }
      expect(sent, 0);
      await dio.get<Object?>(
        '/groups',
        queryParameters: {'page': 1, 'page_size': 10},
      );
      expect(sent, 1);
      dio.close();
    },
  );
  test('authentication transport cannot perform Groups mutations or cloud requests', () async {
    final dio = groupsAcceptanceHttp();
    var sent = 0;
    dio.httpClientAdapter = Fake((r) async {
      sent++;
      return reply({'success': true});
    });
    await expectLater(
      dio.post<Object?>('/groups'),
      throwsA(isA<DioException>()),
    );
    await expectLater(
      dio.get<Object?>('/transaksi/sync'),
      throwsA(isA<DioException>()),
    );
    expect(sent, 0);
    dio.close();
  });
  test('new marker cannot use an old profile or a free-form ID', () {
    expect(() => groupsAcceptanceRoot('../daily'), throwsStateError);
  });
}
