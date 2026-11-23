import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/models/auth_session.dart';
import 'package:frontend_notaris/providers/sidebar_catalog_provider.dart';
import 'package:frontend_notaris/services/sidebar_api_service.dart';

import '../services/administration_auth_test.dart' show session;
import 'group_sidebar_access_api_service_test.dart'
    show AccessFakeAdapter, accessReply;

Map<String, dynamic> catalogRow(int id) => {
  'id': id,
  'sidebar_parent_id': 0,
  'sidebar_nama': 'Menu $id',
  'sidebar_kode': 'menu_$id',
  'sidebar_route': id == 1 ? '#' : '/menu_$id',
  'sidebar_icon': 'folder',
  'sidebar_index': id,
  'status': 1,
  'parent_name': null,
  'parent_status': null,
  'parent_exists': false,
  'created_at': '2026-11-20T00:00:00Z',
};
Map<String, dynamic> catalogData({int page = 1, int total = 25}) => {
  'page': page,
  'page_size': 10,
  'total': total,
  'total_pages': total == 0 ? 1 : (total + 9) ~/ 10,
  'items': [
    for (var id = (page - 1) * 10 + 1; id <= page * 10 && id <= total; id++)
      catalogRow(id),
  ],
};
AuthSession catalogSession({
  bool read = true,
  bool offline = false,
  bool expired = false,
  bool duplicate = false,
}) {
  final s = session(
    offline: offline,
    role: 'user',
    token: expired ? 'expired' : null,
  );
  final grant = {
    'sidebar': {
      'sidebar_kode': 'sidebars',
      'sidebar_nama': 'Sidebars',
      'status': 1,
    },
    'read': read ? 1 : 0,
  };
  return AuthSession(
    token: s.token,
    userId: s.userId,
    groupId: s.groupId,
    userName: s.userName,
    groupName: s.groupName,
    groupType: s.groupType,
    user: s.user,
    verifiedAt: s.verifiedAt,
    isOffline: offline,
    sidebars: [grant, if (duplicate) grant],
  );
}

void main() {
  test(
    'GET catalog sends bounded literal query and preserves canonical values',
    () async {
      final dio = Dio()
        ..httpClientAdapter = AccessFakeAdapter((r) async {
          expect(r.method, 'GET');
          expect(r.path, '/sidebars/catalog');
          expect(r.queryParameters, {
            'page': 2,
            'page_size': 10,
            'search': '%_',
            'status': 'all',
          });
          final data = catalogData(page: 2);
          (data['items'] as List)[0]['sidebar_kode'] = 'laporan_materai';
          return accessReply(data);
        });
      final p = await SidebarApiService(dio)
          .catalog((page: 2, search: '%_', status: 'all'));
      expect(p.items.length, 10);
      expect(p.total, 25);
      expect(p.items.first.code, 'laporan_materai');
      dio.close();
    },
  );
  test('missing or malformed status never defaults to active', () {
    for (final value in ['1', true, 1.5]) {
      expect(
        () => SidebarCatalogItem.fromJson({...catalogRow(1), 'status': value}),
        throwsFormatException,
      );
    }
    final missing = catalogRow(1)..remove('status');
    expect(() => SidebarCatalogItem.fromJson(missing), throwsFormatException);
    expect(
      SidebarCatalogItem.fromJson({...catalogRow(1), 'status': null})
          .statusLabel,
      'Tidak diketahui',
    );
    expect(
      SidebarCatalogItem.fromJson({...catalogRow(1), 'status': 2}).statusLabel,
      'Tidak diketahui (2)',
    );
    for (final value in [null, 'bad', 1.5]) {
      expect(
        () => SidebarApiModel.fromJson({...catalogRow(1), 'status': value}),
        throwsFormatException,
      );
    }
  });
  test('nullable metadata and orphan/inactive/deep parent remain explicit', () {
    final row = SidebarCatalogItem.fromJson({
      ...catalogRow(1),
      'sidebar_parent_id': 999,
      'sidebar_nama': null,
      'sidebar_icon': null,
    });
    expect(row.parentLabel, 'Parent tidak ditemukan · ID 999');
    expect(row.name, null);
    final child = SidebarCatalogItem.fromJson({
      ...catalogRow(2),
      'sidebar_parent_id': 35,
      'parent_exists': true,
      'parent_name': 'Arsip',
      'parent_status': 0,
    });
    expect(child.parentLabel, 'Arsip · ID 35 · Nonaktif');
    expect(child.createdAt, DateTime.utc(2026, 11, 20));
  });
  test(
    'strict pagination rejects inconsistent metadata, rows and duplicate IDs',
    () {
      const q = (page: 1, search: '', status: 'all');
      for (final patch in [
        {'total': -1},
        {'page': 2},
        {'page_size': 50},
        {'total_pages': 8},
        {'items': []},
        {
          'items': [for (var i = 0; i < 10; i++) catalogRow(1)],
        },
      ]) {
        expect(
          () => SidebarCatalogPage.fromJson({...catalogData(), ...patch}, q),
          throwsFormatException,
        );
      }
      expect(
        SidebarCatalogPage.fromJson(catalogData(total: 0), q).items,
        isEmpty,
      );
      expect(
        SidebarCatalogPage.fromJson(catalogData(page: 100), (
          page: 100,
          search: '',
          status: 'all',
        )).items,
        isEmpty,
      );
    },
  );
  test('ordinary authorized user allowed; offline, expiry, missing and ambiguous grants denied', () {
    expect(allowsSidebarCatalog(catalogSession()), true);
    for (final s in [
      null,
      catalogSession(read: false),
      catalogSession(offline: true),
      catalogSession(expired: true),
      catalogSession(duplicate: true),
    ]) {
      expect(allowsSidebarCatalog(s), false);
    }
  });
  test('sanitized failures never echo server payload or request headers', () {
    for (final status in [400, 401, 403, 404, 500, null]) {
      final d = DioException(
        requestOptions: RequestOptions(headers: {'Authorization': 'secret'}),
        response: status == null
            ? null
            : Response(
                requestOptions: RequestOptions(),
                statusCode: status,
                data: {'password': 'secret'},
              ),
      );
      expect(sidebarCatalogError(d), isNot(contains('secret')));
    }
  });
}
