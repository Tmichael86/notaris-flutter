import 'package:dio/dio.dart';

class GroupSidebarAccessApiService {
  GroupSidebarAccessApiService(this._dio);

  final Dio _dio;

  Future<List<GroupSidebarAccessModel>> getByGroup(int groupId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/groups/$groupId/sidebar-access',
    );
    final envelope = _asMap(response.data);
    final data = envelope['data'];

    if (envelope['success'] != true || data is! List) {
      throw const FormatException(
        'Format response hak akses sidebar tidak valid.',
      );
    }

    return data
        .whereType<Map>()
        .map(
          (item) =>
              GroupSidebarAccessModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<void> replaceForGroup({
    required int groupId,
    required List<GroupSidebarAccessInput> access,
  }) async {
    final seen = <int>{};
    for (final item in access) {
      if (item.sidebarId <= 0 ||
          !seen.add(item.sidebarId) ||
          !_isFlag(item.read) ||
          !_isFlag(item.create) ||
          !_isFlag(item.update) ||
          !_isFlag(item.delete)) {
        throw ArgumentError('Data hak akses sidebar tidak valid.');
      }
    }

    final response = await _dio.put<Map<String, dynamic>>(
      '/groups/$groupId/sidebar-access',
      data: {'access': access.map((item) => item.toJson()).toList()},
    );
    final envelope = _asMap(response.data);

    if (envelope['success'] != true) {
      throw const FormatException('Server gagal menyimpan hak akses sidebar.');
    }
  }

  bool _isFlag(int value) => value == 0 || value == 1;

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }
}

class GroupSidebarAccessInput {
  const GroupSidebarAccessInput({
    required this.sidebarId,
    this.read = 0,
    this.create = 0,
    this.update = 0,
    this.delete = 0,
  });

  final int sidebarId;
  final int read;
  final int create;
  final int update;
  final int delete;

  Map<String, dynamic> toJson() => {
    'sidebar_id': sidebarId,
    'read': read,
    'create': create,
    'update': update,
    'delete': delete,
  };
}

class GroupSidebarAccessModel {
  const GroupSidebarAccessModel({
    required this.sidebarId,
    required this.read,
    required this.create,
    required this.update,
    required this.delete,
    required this.sidebar,
  });

  final int sidebarId;
  final int read;
  final int create;
  final int update;
  final int delete;
  final GroupSidebarModel sidebar;

  factory GroupSidebarAccessModel.fromJson(Map<String, dynamic> json) {
    final sidebarId = _parseInt(json['sidebar_id']);
    final sidebarJson = _asMap(json['sidebar']);

    if (sidebarId <= 0 || sidebarJson.isEmpty) {
      throw const FormatException('Data akses sidebar tidak valid.');
    }

    final result = GroupSidebarAccessModel(
      sidebarId: sidebarId,
      read: _parseInt(json['read']),
      create: _parseInt(json['create']),
      update: _parseInt(json['update']),
      delete: _parseInt(json['delete']),
      sidebar: GroupSidebarModel.fromJson(sidebarJson),
    );

    if (!_isFlag(result.read) ||
        !_isFlag(result.create) ||
        !_isFlag(result.update) ||
        !_isFlag(result.delete)) {
      throw const FormatException('Nilai permission sidebar tidak valid.');
    }

    return result;
  }

  static bool _isFlag(int value) => value == 0 || value == 1;

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? -1;
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }
}

class GroupSidebarModel {
  const GroupSidebarModel({
    required this.id,
    required this.nama,
    required this.route,
    required this.kode,
    required this.icon,
    required this.index,
    this.parentId,
    this.status = 1,
  });

  final int id;
  final int? parentId;
  final String nama;
  final String route;
  final String kode;
  final String icon;
  final int index;
  final int status;

  factory GroupSidebarModel.fromJson(Map<String, dynamic> json) {
    final id = _parseInt(json['id']);
    final nama = json['sidebar_nama']?.toString().trim() ?? '';
    final kode = json['sidebar_kode']?.toString().trim() ?? '';

    if (id <= 0 || nama.isEmpty || kode.isEmpty) {
      throw const FormatException('Data sidebar tidak valid.');
    }

    return GroupSidebarModel(
      id: id,
      parentId: _parseNullableInt(json['sidebar_parent_id']),
      nama: nama,
      route: json['sidebar_route']?.toString() ?? '',
      kode: kode,
      icon: json['sidebar_icon']?.toString() ?? '',
      index: _parseInt(json['sidebar_index']),
      status: _parseInt(json['status'], fallback: 1),
    );
  }

  static int _parseInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static int? _parseNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }
}
