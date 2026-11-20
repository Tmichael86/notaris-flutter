import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/services/profile_api_service.dart';
import 'package:frontend_notaris/providers/development_smoke_provider.dart';

import 'administration_auth_test.dart' show session;
import 'group_sidebar_access_api_service_test.dart'
    show AccessFakeAdapter, accessReply;

Map<String, dynamic> ownProfileData({
  int revision = 1,
  String name = 'Rani Uji',
}) => {
  'id': 1,
  'nama': name,
  'no_telp': null,
  'alamat': null,
  'username': 'rani.uji',
  'email': 'rani@example.invalid',
  'group_id': 1,
  'group_nama': 'Pelayanan',
  'group_jenis': 'user',
  'status': 1,
  'revision': revision,
};
void main() {
  test('UiSmoke blocks direct Profile PATCH before adapter', () async {
    var requests = 0;
    final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8081/api/v1'))
      ..httpClientAdapter = AccessFakeAdapter((r) async {
        requests++;
        return accessReply(ownProfileData());
      });
    installDevelopmentSmokeHttpGuard(dio);
    await expectLater(
      ProfileApiService(
        dio,
        session: () => session(role: 'user'),
      ).save(expectedRevision: 1, nama: 'Rani', noTelp: null, alamat: null),
      throwsA(isA<DioException>()),
    );
    expect(requests, 0);
  });
  test(
    'own GET/PATCH exact complete fields; no target ID and no secret parsing',
    () async {
      var calls = 0;
      final dio = Dio()
        ..httpClientAdapter = AccessFakeAdapter((r) async {
          calls++;
          expect(r.path, '/profile');
          expect(r.queryParameters, isEmpty);
          if (r.method == 'PATCH') {
            expect(r.data, {
              'expected_revision': 1,
              'nama': 'Rani Baru',
              'no_telp': null,
              'alamat': null,
            });
          }
          return accessReply(
            ownProfileData(revision: r.method == 'PATCH' ? 2 : 1),
          );
        });
      final api = ProfileApiService(dio, session: () => session(role: 'user'));
      expect((await api.read()).noTelp, isNull);
      expect(
        (await api.save(
          expectedRevision: 1,
          nama: 'Rani Baru',
          noTelp: null,
          alamat: null,
        )).revision,
        2,
      );
      expect(calls, 2);
    },
  );
  test('offline, missing and expired sessions reject before HTTP; ordinary allowed', () async {
    var calls = 0;
    final dio = Dio()
      ..httpClientAdapter = AccessFakeAdapter((_) async {
        calls++;
        return accessReply(ownProfileData());
      });
    for (final s in [null, session(offline: true), session(token: 'expired')]) {
      await expectLater(
        ProfileApiService(dio, session: () => s).read(),
        throwsStateError,
      );
    }
    expect(calls, 0);
    expect(allowsOwnProfile(session(role: 'user')), isTrue);
  });
  test('cross-account, unexpected secrets and malformed profile rejected', () {
    expect(
      () => OwnProfile.fromJson({...ownProfileData(), 'id': 2}, 1),
      throwsFormatException,
    );
    expect(
      () => OwnProfile.fromJson({
        ...ownProfileData(),
        'password': 'forbidden',
      }, 1),
      throwsFormatException,
    );
    for (final k in ownProfileData().keys) {
      final d = ownProfileData()..remove(k);
      expect(() => OwnProfile.fromJson(d, 1), throwsFormatException);
    }
  });
}
