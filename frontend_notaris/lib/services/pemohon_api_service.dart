import 'package:dio/dio.dart';

class PemohonApiService {
  PemohonApiService(this._dio);

  final Dio _dio;

  Future<List<PemohonApiModel>> getAll({
    int page = 1,
    int pageSize = 50,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/pemohon',
      queryParameters: {'page': page, 'page_size': pageSize},
    );

    final envelope = _asMap(response.data);
    final data = _asMap(envelope['data']);
    final items = data['items'];

    if (envelope['success'] != true || items is! List) {
      throw const FormatException('Format response pemohon tidak valid.');
    }

    return items
        .whereType<Map>()
        .map(
          (item) => PemohonApiModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<List<PemohonApiModel>> getAllPages({int pageSize = 100}) async {
    if (pageSize < 1 || pageSize > 100) {
      throw ArgumentError.value(pageSize, 'pageSize', 'Harus 1 sampai 100.');
    }
    final result = <PemohonApiModel>[];
    var page = 1;
    while (true) {
      final response = await _dio.get<Map<String, dynamic>>(
        '/pemohon',
        queryParameters: {'page': page, 'page_size': pageSize},
      );
      final envelope = _asMap(response.data);
      final data = _asMap(envelope['data']);
      final items = data['items'];
      final pagination = _asMap(data['pagination']);
      if (envelope['success'] != true || items is! List) {
        throw const FormatException('Format response pemohon tidak valid.');
      }
      final batch = items
          .whereType<Map>()
          .map(
            (item) => PemohonApiModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
      result.addAll(batch);
      final hasMore = pagination['has_more'];
      if (hasMore is bool) {
        if (!hasMore) break;
      } else if (batch.length < pageSize) {
        break;
      }
      if (batch.isEmpty) {
        throw const FormatException(
          'Pagination pemohon tidak valid: halaman kosong saat has_more bernilai true.',
        );
      }
      page++;
    }
    return result;
  }

  Future<PemohonApiModel> syncUpsert({
    required String uuid,
    required String nama,
    String? alamat,
    String? jenisKelaminNama,
    int? jenisKelamin,
    String? noTelp,
    String? nik,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/pemohon/sync/$uuid',
      data: {
        'nama': nama.trim(),
        'alamat': _nullableText(alamat),
        if (jenisKelamin != null)
          'jenis_kelamin': jenisKelamin
        else
          'jenis_kelamin_nama': _nullableText(jenisKelaminNama),
        'no_telp': _nullableText(noTelp),
        'nik': _nullableText(nik),
      },
    );
    return _parseRecord(response.data);
  }

  Future<void> syncDeactivate({required String uuid}) async {
    final response = await _dio.delete<Map<String, dynamic>>(
      '/pemohon/sync/$uuid',
    );
    if (_asMap(response.data)['success'] != true) {
      throw const FormatException('Server gagal menonaktifkan pemohon.');
    }
  }

  Future<PemohonApiModel> getById(int id) async {
    final response = await _dio.get<Map<String, dynamic>>('/pemohon/$id');
    return _parseRecord(response.data);
  }

  Future<PemohonApiModel> create({
    required String nama,
    String? alamat,
    int? jenisKelamin,
    String? noTelp,
    String? nik,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/pemohon',
      data: _buildPayload(
        nama: nama,
        alamat: alamat,
        jenisKelamin: jenisKelamin,
        noTelp: noTelp,
        nik: nik,
      ),
    );

    return _parseRecord(response.data);
  }

  Future<PemohonApiModel> update({
    required int id,
    required String nama,
    String? alamat,
    int? jenisKelamin,
    String? noTelp,
    String? nik,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/pemohon/$id',
      data: _buildPayload(
        nama: nama,
        alamat: alamat,
        jenisKelamin: jenisKelamin,
        noTelp: noTelp,
        nik: nik,
      ),
    );

    return _parseRecord(response.data);
  }

  Future<void> deactivate(int id) async {
    final response = await _dio.delete<Map<String, dynamic>>('/pemohon/$id');
    final envelope = _asMap(response.data);

    if (envelope['success'] != true) {
      throw const FormatException('Server gagal menonaktifkan pemohon.');
    }
  }

  Map<String, dynamic> _buildPayload({
    required String nama,
    String? alamat,
    int? jenisKelamin,
    String? noTelp,
    String? nik,
  }) {
    return {
      'nama': nama.trim(),
      'alamat': _nullableText(alamat),
      'jenis_kelamin': jenisKelamin,
      'no_telp': _nullableText(noTelp),
      'nik': _nullableText(nik),
    };
  }

  String? _nullableText(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  PemohonApiModel _parseRecord(dynamic responseData) {
    final envelope = _asMap(responseData);
    final data = _asMap(envelope['data']);

    if (envelope['success'] != true || data.isEmpty) {
      throw const FormatException('Format data pemohon tidak valid.');
    }

    return PemohonApiModel.fromJson(data);
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }
}

class PemohonApiModel {
  const PemohonApiModel({
    required this.id,
    required this.nama,
    this.alamat,
    this.jenisKelamin,
    this.jenisKelaminNama,
    this.noTelp,
    this.nik,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
    this.status = 1,
    this.uuid,
    this.isDirty = false,
    this.lastSyncedAt,
    this.deletedAt,
  });

  final int id;
  final String nama;
  final String? alamat;
  final int? jenisKelamin;
  final String? jenisKelaminNama;
  final String? noTelp;
  final String? nik;
  final int? createdBy;
  final int? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int status;
  final String? uuid;
  final bool isDirty;
  final DateTime? lastSyncedAt;
  final DateTime? deletedAt;

  factory PemohonApiModel.fromJson(Map<String, dynamic> json) {
    final id = _parseInt(json['id']);
    final nama = json['nama']?.toString().trim() ?? '';

    if (id <= 0 || nama.isEmpty) {
      throw const FormatException('ID atau nama pemohon tidak valid.');
    }

    return PemohonApiModel(
      id: id,
      nama: nama,
      alamat: _parseNullableText(json['alamat']),
      jenisKelamin: _parseNullableInt(json['jenis_kelamin']),
      jenisKelaminNama: _parseNullableText(json['jenis_kelamin_nama']),
      noTelp: _parseNullableText(json['no_telp']),
      nik: _parseNullableText(json['nik']),
      createdBy: _parseNullableInt(json['created_by']),
      updatedBy: _parseNullableInt(json['updated_by']),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
      status: _parseInt(json['status'], fallback: 1),
      uuid: _parseNullableText(json['uuid']),
      isDirty: json['is_dirty'] == true || json['is_dirty'] == 1,
      lastSyncedAt: DateTime.tryParse(json['last_synced_at']?.toString() ?? ''),
      deletedAt: DateTime.tryParse(json['deleted_at']?.toString() ?? ''),
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

  static String? _parseNullableText(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
