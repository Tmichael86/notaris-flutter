import 'package:dio/dio.dart';

class KategoriPekerjaanApiService {
  KategoriPekerjaanApiService(this._dio);

  final Dio _dio;

  Future<List<KategoriPekerjaanApiModel>> getAll({
    int page = 1,
    int pageSize = 50,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/kategori-pekerjaan',
      queryParameters: {'page': page, 'page_size': pageSize},
    );

    final envelope = _asMap(response.data);
    final data = _asMap(envelope['data']);
    final items = data['items'];

    if (envelope['success'] != true || items is! List) {
      throw const FormatException(
        'Format response kategori pekerjaan tidak valid.',
      );
    }

    return items
        .whereType<Map>()
        .map(
          (item) => KategoriPekerjaanApiModel.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<List<KategoriPekerjaanApiModel>> getAllPages({
    int pageSize = 100,
  }) async {
    if (pageSize < 1 || pageSize > 100) {
      throw ArgumentError.value(pageSize, 'pageSize', 'Must be between 1 and 100.');
    }

    final all = <KategoriPekerjaanApiModel>[];
    var page = 1;

    while (true) {
      final items = await getAll(page: page, pageSize: pageSize);
      all.addAll(items);
      if (items.length < pageSize) return all;
      page++;
    }
  }

  Future<KategoriPekerjaanApiModel> create({required String nama}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/kategori-pekerjaan',
      data: {'nama': nama.trim()},
    );

    return _parseRecord(response.data);
  }

  Future<KategoriPekerjaanApiModel> update({
    required int id,
    required String nama,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/kategori-pekerjaan/$id',
      data: {'nama': nama.trim()},
    );

    return _parseRecord(response.data);
  }

  Future<void> deactivate(int id) async {
    final response = await _dio.delete<Map<String, dynamic>>(
      '/kategori-pekerjaan/$id',
    );

    final envelope = _asMap(response.data);

    if (envelope['success'] != true) {
      throw const FormatException(
        'Server gagal menonaktifkan kategori pekerjaan.',
      );
    }
  }

  KategoriPekerjaanApiModel _parseRecord(dynamic responseData) {
    final envelope = _asMap(responseData);
    final data = _asMap(envelope['data']);

    if (envelope['success'] != true || data.isEmpty) {
      throw const FormatException(
        'Format data kategori pekerjaan tidak valid.',
      );
    }

    return KategoriPekerjaanApiModel.fromJson(data);
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }
}

class KategoriPekerjaanApiModel {
  const KategoriPekerjaanApiModel({
    required this.id,
    required this.nama,
    this.uuid = '',
    this.createdAt,
    this.updatedAt,
    this.status = 1,
  });

  final int id;
  final String nama;
  final String uuid;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int status;

  factory KategoriPekerjaanApiModel.fromJson(Map<String, dynamic> json) {
    final id = _parseInt(json['id']);
    final nama = json['nama']?.toString().trim() ?? '';

    if (id <= 0 || nama.isEmpty) {
      throw const FormatException(
        'ID atau nama kategori pekerjaan tidak valid.',
      );
    }

    return KategoriPekerjaanApiModel(
      id: id,
      nama: nama,
      uuid: json['uuid']?.toString().trim() ?? '',
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
