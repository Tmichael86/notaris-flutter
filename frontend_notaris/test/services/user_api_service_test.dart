import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart' hide Fake;
import 'package:frontend_notaris/services/user_api_service.dart';

import '../repositories/petugas_local_sync_test.dart' show Fake, reply;

Map<String, Object?> userRow({
  int id = 301,
  int revision = 1,
  int status = 1,
  int group = 201,
  String name = 'Operator 01',
}) => {
  'id': id,
  'group_id': group,
  'group_nama': 'Administrasi Biasa',
  'group_jenis': 'user',
  'group_status': 1,
  'nama': name,
  'username': 'operator.$id',
  'email': 'operator$id@example.invalid',
  'status': status,
  'revision': revision,
  'no_telp': null,
  'alamat': null,
};
Map<String, Object?> pageReply({
  List<Map<String, Object?>>? rows,
  int total = 1,
  int page = 1,
}) => {
  'success': true,
  'data': {
    'items': rows ?? [userRow()],
    'total': total,
    'page': page,
    'page_size': 10,
    'groups': [
      {
        'id': 201,
        'group_nama': 'Administrasi Biasa',
        'group_jenis': 'user',
        'status': 1,
      },
    ],
  },
};
UserApiService api(Future<ResponseBody> Function(RequestOptions) handler) =>
    UserApiService(
      Dio(BaseOptions(baseUrl: 'http://test.invalid/api/v1'))
        ..httpClientAdapter = Fake(handler),
    );

void main() {
  test('bounded listing sends actual search/group/status/page and parses revisions', () async {
    final service = api((r) async {
      expect(r.path, '/users');
      expect(r.queryParameters, {
        'page': 2,
        'page_size': 10,
        'search': 'operator',
        'group_id': 201,
        'status': 0,
      });
      return reply(pageReply(rows: [userRow(status: 0)], total: 11, page: 2));
    });
    final result = await service.list((
      page: 2,
      search: ' operator ',
      groupId: 201,
      status: 0,
    ));
    expect(result.total, 11);
    expect(result.items.single.status, 0);
    expect(result.items.single.revision, 1);
    expect(result.groups.single.id, 201);
  });
  test(
    'create sends confirmation without photo/status/security/audit fields',
    () async {
      final service = api((r) async {
        expect(r.method, 'POST');
        expect(r.data, {
          'group_id': 201,
          'nama': 'Operator',
          'username': 'operator.new',
          'email': 'new@example.invalid',
          'no_telp': null,
          'alamat': null,
          'password': 'unit-test-password',
          'password_confirm': 'unit-test-password',
        });
        return reply({'success': true, 'data': userRow()});
      });
      expect(
        (await service.create(
          groupId: 201,
          nama: ' Operator ',
          username: 'operator.new',
          email: 'new@example.invalid',
          password: 'unit-test-password',
          passwordConfirm: 'unit-test-password',
        )).id,
        301,
      );
    },
  );
  test(
    'edit never sends password, status, image, or security version',
    () async {
      final service = api((r) async {
        expect(r.path, '/users/301');
        expect(r.method, 'PUT');
        final body = r.data as Map;
        expect(body['expected_revision'], 4);
        expect(
          body.keys,
          unorderedEquals([
            'group_id',
            'nama',
            'username',
            'email',
            'no_telp',
            'alamat',
            'expected_revision',
          ]),
        );
        return reply({
          'success': true,
          'data': userRow(revision: 5, status: 0),
        });
      });
      expect(
        (await service.update(
          id: 301,
          expectedRevision: 4,
          groupId: 201,
          nama: 'Operator',
          username: 'operator.301',
          email: 'operator301@example.invalid',
        )).status,
        0,
      );
    },
  );
  test('deactivate and separate reset carry expected revision', () async {
    var calls = 0;
    final service = api((r) async {
      calls++;
      if (r.method == 'DELETE') {
        expect(r.data, {'expected_revision': 3});
      } else {
        expect(r.path, '/users/301/password-reset');
        expect((r.data as Map)['expected_revision'], 4);
        expect((r.data as Map)['password_confirm'], 'unit-test-password');
      }
      return reply({'success': true, 'data': null});
    });
    await service.deactivate(301, expectedRevision: 3);
    await service.resetPassword(
      301,
      expectedRevision: 4,
      password: 'unit-test-password',
      passwordConfirm: 'unit-test-password',
    );
    expect(calls, 2);
  });
  test('malformed/absent status and invalid revision never become active', () {
    for (final key in ['status', 'revision', 'group_status']) {
      final row = userRow()..remove(key);
      expect(() => UserApiModel.fromJson(row), throwsFormatException);
    }
    expect(
      () => UserApiModel.fromJson(userRow()..['status'] = '1'),
      throwsFormatException,
    );
  });
  test('assignable groups reject privileged and inactive references', () async {
    for (final (kind, status) in [('superadmin', 1), ('user', 0)]) {
      final service = api(
        (r) async => reply({
          'success': true,
          'data': [
            {
              'id': 1,
              'group_nama': 'Wrong',
              'group_jenis': kind,
              'status': status,
            },
          ],
        }),
      );
      await expectLater(service.assignableGroups(), throwsFormatException);
    }
  });
  test('failure bodies and passwords are never echoed by error messages', () {
    final request = RequestOptions(
      path: '/users',
      data: {'password': 'DO_NOT_DISPLAY'},
    );
    final error = DioException(
      requestOptions: request,
      response: Response(
        requestOptions: request,
        statusCode: 409,
        data: {
          'code': 'identity_conflict',
          'message': 'SQL password DO_NOT_DISPLAY',
          'request_id': '12345678-1234-1234-1234-123456789abc',
        },
      ),
    );
    expect(usersError(error), contains('Username atau email'));
    expect(usersError(error), isNot(contains('DO_NOT_DISPLAY')));
    expect(usersError(error), contains('ID:'));
  });
  test('narrow Petugas reference never reads full Users', () async {
    final service = api((r) async {
      expect(r.path, '/petugas/references/users/201');
      return reply({
        'success': true,
        'data': {'id': 201, 'status': 1},
      });
    });
    expect(await service.verifiedPetugasReference(201), 201);
  });
}
