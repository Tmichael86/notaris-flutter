import 'package:dio/dio.dart';

class GroupApiService {
  GroupApiService(this._dio);

  final Dio _dio;

  Future<List<GroupApiModel>> getAll() async {
    final response = await _dio.get<Map<String, dynamic>>('/groups');
    final envelope = _asMap(response.data);
    final data = envelope['data'];

    if (envelope['success'] != true || data is! List) {
      throw const FormatException('Format response group tidak valid.');
    }

    return data
        .whereType<Map>()
        .map((item) => GroupApiModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<GroupApiModel> create({
    required String groupNama,
    required String groupJenis,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/groups',
      data: _buildPayload(groupNama: groupNama, groupJenis: groupJenis),
    );
    return _parseRecord(response.data);
  }

  Future<GroupApiModel> update({
    required int id,
    required String groupNama,
    required String groupJenis,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/groups/$id',
      data: _buildPayload(groupNama: groupNama, groupJenis: groupJenis),
    );
    return _parseRecord(response.data);
  }

  Future<void> deactivate(int id) async {
    final response = await _dio.delete<Map<String, dynamic>>('/groups/$id');
    final envelope = _asMap(response.data);

    if (envelope['success'] != true) {
      throw const FormatException('Server gagal menonaktifkan group.');
    }
  }

  Map<String, dynamic> _buildPayload({
    required String groupNama,
    required String groupJenis,
  }) {
    final nama = groupNama.trim();
    final jenis = groupJenis.trim();

    if (nama.isEmpty || !const {'superadmin', 'user'}.contains(jenis)) {
      throw ArgumentError('Nama atau jenis group tidak valid.');
    }

    return {'group_nama': nama, 'group_jenis': jenis};
  }

  GroupApiModel _parseRecord(dynamic responseData) {
    final envelope = _asMap(responseData);
    final data = _asMap(envelope['data']);

    if (envelope['success'] != true || data.isEmpty) {
      throw const FormatException('Format data group tidak valid.');
    }

    return GroupApiModel.fromJson(data);
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }
}

class GroupApiModel {
  const GroupApiModel({
    required this.id,
    required this.groupNama,
    required this.groupJenis,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
    this.status = 1,
  });

  final int id;
  final String groupNama;
  final String groupJenis;
  final int? createdBy;
  final int? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int status;

  factory GroupApiModel.fromJson(Map<String, dynamic> json) {
    final id = _parseInt(json['id']);
    final groupNama = json['group_nama']?.toString().trim() ?? '';
    final groupJenis = json['group_jenis']?.toString().trim() ?? '';

    if (id <= 0 ||
        groupNama.isEmpty ||
        !const {'superadmin', 'user'}.contains(groupJenis)) {
      throw const FormatException('Data group tidak valid.');
    }

    return GroupApiModel(
      id: id,
      groupNama: groupNama,
      groupJenis: groupJenis,
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
