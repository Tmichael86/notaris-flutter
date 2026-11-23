import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/groups_v2_acceptance_main.dart';

import 'administration_auth_test.dart' show session;
import 'group_sidebar_access_api_service_test.dart'
    show AccessFakeAdapter, accessReply;

void main() {
  test('acceptance transport allows access PUT only; denies old ports, lifecycle, metadata and cloud', () async {
    var calls = 0;
    final d = groupsV2AcceptanceHttp(administration: true)
      ..httpClientAdapter = AccessFakeAdapter((_) async {
        calls++;
        return accessReply(null);
      });
    await d.put('/groups/201/sidebar-access');
    expect(calls, 1);
    for (final (method, path) in [
      ('POST', '/groups'),
      ('PUT', '/groups/201'),
      ('DELETE', '/groups/201'),
      ('PUT', '/sidebars/2'),
      ('PUT', '/transaksi-notaris/sync/create'),
      ('PUT', 'http://127.0.0.1:55884/api/v1/groups/201/sidebar-access'),
      ('GET', 'http://127.0.0.1:8081/api/v1/groups'),
    ]) {
      await expectLater(
        d.request(path, options: Options(method: method)),
        throwsA(isA<DioException>()),
      );
    }
    expect(calls, 1);
    d.close();
  });
  test('actual attestation fields and account/scope must all match; offline denied', () async {
    const id = '00000000000000000000000000000000';
    final s = session();
    final valid = <String, Object?>{
      'profile': id,
      'scope': 'groups-v2/$id',
      'database': 'groups_v2_$id',
      'host': '127.0.0.1',
      'port': 55797,
      'marker': 'NOTARIS GROUPS V2 DISPOSABLE $id',
      'account_id': s.userId,
      'group_id': s.groupId,
      'cloud_sync': false,
    };
    var proof = Map.of(valid);
    final dio = Dio()
      ..httpClientAdapter = AccessFakeAdapter(
        (_) async => ResponseBody.fromString('', 200),
      );
    dio.httpClientAdapter = AccessFakeAdapter(
      (_) async => ResponseBody.fromString(
        jsonEncode(proof),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
    final auth = GroupsV2AcceptanceAuth(dio, id);
    expect(await auth.attest(s), s);
    for (final key in valid.keys) {
      proof = Map.of(valid)..[key] = 'mismatch';
      await expectLater(auth.attest(s), throwsException);
    }
    proof = Map.of(valid);
    await expectLater(auth.attest(s.asOffline()), throwsException);
    dio.close();
  });
  test('no free-form profile/root accepted', () {
    expect(() => groupsV2AcceptanceRoot('../daily'), throwsA(anything));
  });
}
