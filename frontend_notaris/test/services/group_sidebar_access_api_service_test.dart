import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/services/group_sidebar_access_api_service.dart';

Map<String, dynamic> accessFixture({
  int revision = 1,
  String kind = 'user',
  int status = 1,
}) => {
  'group': {
    'id': 2,
    'group_nama': 'CS',
    'group_jenis': kind,
    'status': status,
    'revision': revision,
    'active_members': 2,
  },
  'catalog_fingerprint': 'a' * 64,
  'entries': [
    for (final (id, parent, name, active) in [
      (10, 0, 'Master', true),
      (11, 10, 'Pemohon', true),
      (12, 10, 'Historis', false),
    ])
      {
        'sidebar': {
          'id': id,
          'sidebar_parent_id': parent,
          'sidebar_nama': name,
          'sidebar_kode': 'menu_$id',
          'sidebar_route': id == 10 ? '#' : '/menu_$id',
          'sidebar_icon': 'folder',
          'sidebar_index': id,
          'status': active ? 1 : 0,
        },
        'read': active ? 0 : 1,
        'create': 0,
        'update': 0,
        'delete': 0,
        'editable': active,
        'reason': active ? '' : 'Nonaktif; hanya baca',
      },
  ],
};

class AccessFakeAdapter implements HttpClientAdapter {
  AccessFakeAdapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions r,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) => respond(r);
  @override
  void close({bool force = false}) {}
}

ResponseBody accessReply(Object? data, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode({'success': status == 200, 'data': data}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

void main() {
  test('GET captures identity revision catalog and frozen rows; wrong owner rejected', () async {
    final dio = Dio()
      ..httpClientAdapter = AccessFakeAdapter(
        (r) async => accessReply(accessFixture()),
      );
    final api = GroupSidebarAccessApiService(dio);
    final s = await api.getByGroup(2);
    expect(s.entries.length, 3);
    expect(s.entries.last.editable, false);
    expect(s.entries.last.flags, [1, 0, 0, 0]);
    expect(s.revision, 1);
    await expectLater(api.getByGroup(3), throwsFormatException);
  });
  test('PUT sends exact editable zeros revision/hash; never echoes inactive grants', () async {
    final s = GroupAccessSnapshot.fromJson(accessFixture());
    final dio = Dio()
      ..httpClientAdapter = AccessFakeAdapter((r) async {
        expect(r.method, 'PUT');
        expect(r.path, '/groups/2/sidebar-access');
        final b = r.data as Map;
        expect(b['expected_revision'], 1);
        expect(b['catalog_fingerprint'], s.catalog);
        expect(b['access'], [
          for (final id in [10, 11])
            {
              'sidebar_id': id,
              'read': 0,
              'create': 0,
              'update': 0,
              'delete': 0,
            },
        ]);
        return accessReply(null);
      });
    await GroupSidebarAccessApiService(dio).replaceForGroup(
      snapshot: s,
      access: [
        for (final id in [10, 11]) GroupSidebarAccessInput(sidebarId: id),
      ],
    );
  });
  test('partial duplicate hidden invalid flags and CUD without READ fail before HTTP', () async {
    final api = GroupSidebarAccessApiService(
      Dio()
        ..httpClientAdapter = AccessFakeAdapter((_) async => fail('No HTTP')),
    );
    final s = GroupAccessSnapshot.fromJson(accessFixture());
    for (final rows in <List<GroupSidebarAccessInput>>[
      [],
      [const GroupSidebarAccessInput(sidebarId: 10)],
      [
        const GroupSidebarAccessInput(sidebarId: 10),
        const GroupSidebarAccessInput(sidebarId: 10),
      ],
      [
        const GroupSidebarAccessInput(sidebarId: 12),
        const GroupSidebarAccessInput(sidebarId: 11),
      ],
      [
        const GroupSidebarAccessInput(sidebarId: 10, read: 2),
        const GroupSidebarAccessInput(sidebarId: 11),
      ],
      [
        const GroupSidebarAccessInput(sidebarId: 10, create: 1),
        const GroupSidebarAccessInput(sidebarId: 11),
      ],
    ]) {
      await expectLater(
        api.replaceForGroup(snapshot: s, access: rows),
        throwsArgumentError,
      );
    }
  });
  test(
    'protected/inactive and malformed security metadata fail closed',
    () async {
      final api = GroupSidebarAccessApiService(
        Dio()
          ..httpClientAdapter = AccessFakeAdapter((_) async => fail('No HTTP')),
      );
      for (final m in [
        accessFixture(kind: 'superadmin'),
        accessFixture(status: 0),
      ]) {
        await expectLater(
          api.replaceForGroup(
            snapshot: GroupAccessSnapshot.fromJson(m),
            access: [],
          ),
          throwsStateError,
        );
      }
      for (final field in ['status', 'revision', 'group_jenis']) {
        final m = accessFixture();
        (m['group'] as Map).remove(field);
        expect(() => GroupAccessSnapshot.fromJson(m), throwsFormatException);
      }
      final m = accessFixture();
      m['catalog_fingerprint'] = 'bad';
      expect(() => GroupAccessSnapshot.fromJson(m), throwsFormatException);
    },
  );
  for (final code in [401, 403, 409, 500]) {
    test('HTTP $code remains failure without retry', () async {
      var calls = 0;
      final api = GroupSidebarAccessApiService(
        Dio()
          ..httpClientAdapter = AccessFakeAdapter((_) async {
            calls++;
            return accessReply(null, status: code);
          }),
      );
      await expectLater(api.getByGroup(2), throwsA(isA<DioException>()));
      expect(calls, 1);
    });
  }
}
