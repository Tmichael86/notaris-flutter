import 'dart:convert';

import 'package:dio/dio.dart';

import 'user_api_service.dart' show usersError;

typedef GroupsQuery = ({int page, String search, String? kind, int? status});
typedef GroupsPage = ({
  List<GroupApiModel> items,
  int total,
  int page,
  int pageSize,
});

class GroupApiService {
  GroupApiService(this._dio);
  final Dio _dio;
  Future<GroupsPage> list(GroupsQuery q) async {
    final d = _map(
      _envelope(
        (await _dio.get<Object?>(
          '/groups',
          queryParameters: {
            'page': q.page,
            'page_size': 10,
            'status': q.status ?? 'all',
            if (q.kind != null) 'group_jenis': q.kind,
            if (q.search.trim().isNotEmpty) 'search': q.search.trim(),
          },
        )).data,
      ),
    );
    final rows = d['items'];
    if (rows is! List ||
        rows.length > 10 ||
        d['total'] is! int ||
        (d['total'] as int) < 0 ||
        d['page'] != q.page ||
        d['page_size'] != 10) {
      throw const FormatException('Halaman Groups tidak valid.');
    }
    return (
      items: rows.map((r) => GroupApiModel.fromJson(_map(r))).toList(),
      total: d['total'] as int,
      page: q.page,
      pageSize: 10,
    );
  }

  Future<GroupApiModel> get(int id) async {
    if (id < 1) {
      throw ArgumentError('ID grup tidak valid.');
    }
    final row = GroupApiModel.fromJson(
      _map(_envelope((await _dio.get<Object?>('/groups/$id')).data)),
    );
    if (row.id != id) {
      throw const FormatException('Identitas grup tidak cocok.');
    }
    return row;
  }

  Future<void> create({required String groupNama}) async {
    _envelope(
      (await _dio.post<Object?>(
        '/groups',
        data: {'group_nama': _name(groupNama), 'group_jenis': 'user'},
      )).data,
    );
  }

  Future<void> rename(GroupApiModel group, {required String name}) async {
    _eligible(group);
    _envelope(
      (await _dio.put<Object?>(
        '/groups/${group.id}',
        data: {
          'group_nama': _name(name),
          'group_jenis': 'user',
          'expected_revision': group.revision,
        },
      )).data,
    );
  }

  Future<void> deactivate(GroupApiModel group) async {
    _eligible(group);
    _envelope(
      (await _dio.delete<Object?>(
        '/groups/${group.id}',
        data: {
          'expected_revision': group.revision,
          'expected_membership': group.membership,
        },
      )).data,
    );
  }

  void _eligible(GroupApiModel g) {
    if (!g.editable) throw StateError('Grup nonaktif atau terproteksi.');
  }

  String _name(String value) {
    final v = value.trim();
    if (v.isEmpty || utf8.encode(v).length > 160) {
      throw ArgumentError('Nama grup wajib, maksimal 160 byte.');
    }
    return v;
  }

  Object? _envelope(Object? value) {
    final d = _map(value);
    if (d['success'] != true) {
      throw const FormatException(
        'Server belum mengonfirmasi perubahan Groups.',
      );
    }
    return d['data'];
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map) {
    throw const FormatException('Response Groups tidak valid.');
  }
  return Map<String, dynamic>.from(value);
}

class GroupApiModel {
  const GroupApiModel({
    required this.id,
    required this.groupNama,
    required this.groupJenis,
    required this.status,
    required this.revision,
    required this.activeMembers,
    required this.totalMembers,
    required this.membership,
  });
  final int id, status, revision, activeMembers, totalMembers;
  final String groupNama, groupJenis, membership;
  bool get protected => groupJenis == 'superadmin';
  bool get editable => groupJenis == 'user' && status == 1;
  factory GroupApiModel.fromJson(Map<String, dynamic> d) {
    for (final key in ['id', 'revision', 'active_members', 'total_members']) {
      if (d[key] is! int ||
          (d[key] as int) < (key == 'id' || key == 'revision' ? 1 : 0)) {
        throw const FormatException('Identitas/revisi Groups tidak valid.');
      }
    }
    if (d['group_nama'] is! String ||
        (d['group_nama'] as String).trim().isEmpty ||
        !['user', 'superadmin'].contains(d['group_jenis']) ||
        d['status'] is! int ||
        ![0, 1].contains(d['status']) ||
        d['membership'] is! String ||
        !RegExp(r'^[a-f0-9]{32}$').hasMatch(d['membership'] as String) ||
        (d['active_members'] as int) > (d['total_members'] as int)) {
      throw const FormatException('Status atau metadata Groups tidak valid.');
    }
    return GroupApiModel(
      id: d['id'] as int,
      groupNama: d['group_nama'] as String,
      groupJenis: d['group_jenis'] as String,
      status: d['status'] as int,
      revision: d['revision'] as int,
      activeMembers: d['active_members'] as int,
      totalMembers: d['total_members'] as int,
      membership: d['membership'] as String,
    );
  }
}

String groupsError(Object error) {
  if (error is DioException) {
    final raw = error.response?.data;
    final code = raw is Map ? raw['code'] : null;
    if ([
      'protected_group',
      'group_inactive',
      'membership_changed',
    ].contains(code)) {
      return switch (code) {
        'protected_group' =>
          'Grup Superadmin terproteksi dan hanya dapat dibaca.',
        'group_inactive' => 'Grup sudah nonaktif. Muat ulang data. ',
        _ =>
          'Keanggotaan berubah. Muat ulang dan konfirmasikan dampak terbaru.',
      };
    }
  }
  return usersError(error).replaceAll('Users', 'Groups');
}
