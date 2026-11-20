import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart' hide Fake;
import 'package:frontend_notaris/services/group_api_service.dart';

import '../repositories/petugas_local_sync_test.dart' show Fake, reply;

Map<String, Object?> groupRow({
  int id = 2,
  String name = 'Operasional',
  String kind = 'user',
  int status = 1,
  int revision = 1,
  int members = 3,
}) => {
  'id': id,
  'group_nama': name,
  'group_jenis': kind,
  'status': status,
  'revision': revision,
  'active_members': members,
  'total_members': members,
  'membership': '00000000000000000000000000000000',
};
Map<String, Object?> groupPage({
  List<Map<String, Object?>>? rows,
  int page = 1,
  int? total,
}) => {
  'success': true,
  'data': {
    'items': rows ?? [groupRow()],
    'total': total ?? rows?.length ?? 1,
    'page': page,
    'page_size': 10,
  },
};
void main() {
  test('detail never substitutes a different Group identity', () async {
    final d = Dio()
      ..httpClientAdapter = Fake(
        (_) async => reply({'success': true, 'data': groupRow(id: 3)}),
      );
    await expectLater(GroupApiService(d).get(2), throwsFormatException);
  });
  test(
    'bounded server page retains revision, inactive status and members',
    () async {
      final d = Dio()
        ..httpClientAdapter = Fake((r) async {
          expect(r.queryParameters, {
            'page': 2,
            'page_size': 10,
            'status': 0,
            'group_jenis': 'user',
            'search': '100%',
          });
          return reply(
            groupPage(rows: [groupRow(status: 0)], page: 2, total: 11),
          );
        });
      final p = await GroupApiService(d)
          .list((page: 2, search: '100%', kind: 'user', status: 0));
      expect(p.items.single.status, 0);
      expect(p.items.single.revision, 1);
      expect(p.items.single.activeMembers, 3);
    },
  );
  test(
    'missing status/type/revision/member token never defaults permissively',
    () {
      for (final k in [
        'status',
        'group_jenis',
        'revision',
        'active_members',
        'membership',
      ]) {
        expect(
          () => GroupApiModel.fromJson(groupRow()..remove(k)),
          throwsFormatException,
        );
      }
      for (final value in ['1', 2, null]) {
        expect(
          () => GroupApiModel.fromJson(groupRow()..['status'] = value),
          throwsFormatException,
        );
      }
    },
  );
  test('create, rename and deactivate support data:null, exact revisions and membership', () async {
    final calls = <RequestOptions>[];
    final d = Dio()
      ..httpClientAdapter = Fake((r) async {
        calls.add(r);
        return reply({'success': true, 'data': null});
      });
    final api = GroupApiService(d), r = GroupApiModel.fromJson(groupRow());
    await api.create(groupNama: '  Biasa ');
    await api.rename(r, name: 'Baru');
    await api.deactivate(r);
    expect(calls[0].data, {'group_nama': 'Biasa', 'group_jenis': 'user'});
    expect((calls[1].data as Map)['expected_revision'], 1);
    expect(calls[2].data, {
      'expected_revision': 1,
      'expected_membership': r.membership,
    });
  });
  test('protected and inactive targets rejected before network', () async {
    final d = Dio()
      ..httpClientAdapter = Fake(
        (_) async => throw StateError('network must not run'),
      );
    final api = GroupApiService(d);
    for (final r in [groupRow(kind: 'superadmin'), groupRow(status: 0)]) {
      final g = GroupApiModel.fromJson(r);
      await expectLater(api.rename(g, name: 'X'), throwsStateError);
      await expectLater(api.deactivate(g), throwsStateError);
    }
    await expectLater(api.create(groupNama: ' '), throwsArgumentError);
  });
  test('mutation failure never becomes success, arbitrary server content stays hidden', () async {
    for (final code in [401, 403, 409, 422, 500]) {
      final d = Dio()
        ..httpClientAdapter = Fake(
          (_) async =>
              reply({'code': 'stale_revision', 'message': 'SECRET SQL'}, code),
        );
      try {
        await GroupApiService(d).create(groupNama: 'X');
        fail('should reject');
      } catch (e) {
        expect(e, isA<DioException>());
        expect(groupsError(e), isNot(contains('SECRET SQL')));
      }
    }
  });
  test('invalid success envelope and page totals are rejected', () async {
    final d = Dio()
      ..httpClientAdapter = Fake(
        (_) async => reply({'success': false, 'data': null}),
      );
    await expectLater(
      GroupApiService(d).create(groupNama: 'X'),
      throwsFormatException,
    );
  });
}
