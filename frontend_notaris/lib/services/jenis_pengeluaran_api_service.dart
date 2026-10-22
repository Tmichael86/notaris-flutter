import 'package:dio/dio.dart';

class JenisPengeluaranApiService {
  JenisPengeluaranApiService(this._dio);

  final Dio _dio;

  Future<List<JenisPengeluaranApiModel>> getAll({
    int page = 1,
    int pageSize = 50,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/jenis-pengeluaran',
      queryParameters: {'page': page, 'page_size': pageSize},
    );

    final envelope = _asMap(response.data);
    final data = _asMap(envelope['data']);
    final items = data['items'];

    if (envelope['success'] != true || items is! List) {
      throw const FormatException(
        'Format response jenis pengeluaran tidak valid.',
      );
    }

    return items
        .whereType<Map>()
        .map(
          (item) => JenisPengeluaranApiModel.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<JenisPengeluaranApiModel> create({required String nama}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/jenis-pengeluaran',
      data: {'nama': nama.trim()},
    );

    return _parseRecord(response.data);
  }

  Future<JenisPengeluaranApiModel> update({
    required int id,
    required String nama,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/jenis-pengeluaran/$id',
      data: {'nama': nama.trim()},
    );

    return _parseRecord(response.data);
  }

  Future<void> deactivate(int id) async {
    final response = await _dio.delete<Map<String, dynamic>>(
      '/jenis-pengeluaran/$id',
    );

    final envelope = _asMap(response.data);

    if (envelope['success'] != true) {
      throw const FormatException(
        'Server gagal menonaktifkan jenis pengeluaran.',
      );
    }
  }

  JenisPengeluaranApiModel _parseRecord(dynamic responseData) {
    final envelope = _asMap(responseData);
    final data = _asMap(envelope['data']);

    if (envelope['success'] != true || data.isEmpty) {
      throw const FormatException('Format data jenis pengeluaran tidak valid.');
    }

    return JenisPengeluaranApiModel.fromJson(data);
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }
}

class JenisPengeluaranApiModel {
  const JenisPengeluaranApiModel({
    required this.id,
    required this.nama,
    this.createdAt,
    this.updatedAt,
    this.status = 1,
  });

  final int id;
  final String nama;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int status;

  factory JenisPengeluaranApiModel.fromJson(Map<String, dynamic> json) {
    final id = _parseInt(json['id']);
    final nama = json['nama']?.toString().trim() ?? '';

    if (id <= 0 || nama.isEmpty) {
      throw const FormatException(
        'ID atau nama jenis pengeluaran tidak valid.',
      );
    }

    return JenisPengeluaranApiModel(
      id: id,
      nama: nama,
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
}
