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
