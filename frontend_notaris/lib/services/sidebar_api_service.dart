import 'package:dio/dio.dart';

class SidebarApiService {
  SidebarApiService(this._dio);

  final Dio _dio;

  Future<List<SidebarApiModel>> getAll() async {
    final response = await _dio.get<Map<String, dynamic>>('/sidebars');
    final envelope = _asMap(response.data);
    final data = envelope['data'];

    if (envelope['success'] != true || data is! List) {
      throw const FormatException('Format response sidebar tidak valid.');
    }

    return data
        .whereType<Map>()
        .map(
          (item) => SidebarApiModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<List<SidebarTreeApiModel>> getTree() async {
    final response = await _dio.get<Map<String, dynamic>>('/sidebars/tree');
    final envelope = _asMap(response.data);
    final data = envelope['data'];

    if (envelope['success'] != true || data is! List) {
      throw const FormatException(
        'Format response struktur sidebar tidak valid.',
      );
    }

    return data
        .whereType<Map>()
        .map(
          (item) =>
              SidebarTreeApiModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<SidebarApiModel> getById(int id) async {
    final response = await _dio.get<Map<String, dynamic>>('/sidebars/$id');
    final envelope = _asMap(response.data);
    final data = _asMap(envelope['data']);

    if (envelope['success'] != true || data.isEmpty) {
      throw const FormatException('Format data sidebar tidak valid.');
    }

    return SidebarApiModel.fromJson(data);
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }
}

class SidebarTreeApiModel {
  const SidebarTreeApiModel({required this.sidebar, this.childs = const []});

  final SidebarApiModel sidebar;
  final List<SidebarApiModel> childs;

  factory SidebarTreeApiModel.fromJson(Map<String, dynamic> json) {
    final sidebarJson = _asMap(json['sidebar']);
    final childrenJson = json['childs'];

    if (sidebarJson.isEmpty ||
        (childrenJson != null && childrenJson is! List)) {
      throw const FormatException('Struktur sidebar tidak valid.');
    }

    final children = childrenJson is List
        ? childrenJson
              .whereType<Map>()
              .map(
                (item) =>
                    SidebarApiModel.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : <SidebarApiModel>[];

    return SidebarTreeApiModel(
      sidebar: SidebarApiModel.fromJson(sidebarJson),
      childs: children,
    );
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }
}

class SidebarApiModel {
  const SidebarApiModel({
    required this.id,
    required this.nama,
    required this.route,
    required this.kode,
    required this.icon,
    required this.index,
    this.parentId,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
    this.status = 1,
  });

  final int id;
  final int? parentId;
  final String nama;
  final String route;
  final String kode;
  final String icon;
  final int index;
  final int? createdBy;
  final int? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int status;

  factory SidebarApiModel.fromJson(Map<String, dynamic> json) {
    final id = _parseInt(json['id']);
    final nama = json['sidebar_nama']?.toString().trim() ?? '';
    final kode = json['sidebar_kode']?.toString().trim() ?? '';

    if (id <= 0 || nama.isEmpty || kode.isEmpty) {
      throw const FormatException('Data sidebar tidak valid.');
    }

    return SidebarApiModel(
      id: id,
      parentId: _parseNullableInt(json['sidebar_parent_id']),
      nama: nama,
      route: json['sidebar_route']?.toString() ?? '',
      kode: kode,
      icon: json['sidebar_icon']?.toString() ?? '',
      index: _parseInt(json['sidebar_index']),
      createdBy: _parseNullableInt(json['created_by']),
      updatedBy: _parseNullableInt(json['updated_by']),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
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
