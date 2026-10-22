import 'package:dio/dio.dart';

class PetugasApiService {
  PetugasApiService(this._dio);

  final Dio _dio;

  Future<List<PetugasApiModel>> getAll({
    int page = 1,
    int pageSize = 50,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/petugas',
      queryParameters: {'page': page, 'page_size': pageSize},
    );

    final envelope = _asMap(response.data);
    final data = _asMap(envelope['data']);
    final items = data['items'];

    if (envelope['success'] != true || items is! List) {
      throw const FormatException('Format response petugas tidak valid.');
    }

    return items
        .whereType<Map>()
        .map(
          (item) => PetugasApiModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<PetugasApiModel> getById(int id) async {
    final response = await _dio.get<Map<String, dynamic>>('/petugas/$id');
    return _parseRecord(response.data);
  }

  Future<PetugasApiModel> create({
    required String nama,
    String? nik,
    String? alamat,
    String? tempatLahir,
    String? tanggalLahir,
    int? jenisKelamin,
    String? noTelp,
    required String email,
    int? userId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/petugas',
      data: _buildPayload(
        nama: nama,
        nik: nik,
        alamat: alamat,
        tempatLahir: tempatLahir,
        tanggalLahir: tanggalLahir,
        jenisKelamin: jenisKelamin,
        noTelp: noTelp,
        email: email,
        userId: userId,
      ),
    );
    return _parseRecord(response.data);
  }

  Future<PetugasApiModel> update({
    required int id,
    required String nama,
    String? nik,
    String? alamat,
    String? tempatLahir,
    String? tanggalLahir,
    int? jenisKelamin,
    String? noTelp,
    required String email,
    int? userId,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/petugas/$id',
      data: _buildPayload(
        nama: nama,
        nik: nik,
        alamat: alamat,
        tempatLahir: tempatLahir,
        tanggalLahir: tanggalLahir,
        jenisKelamin: jenisKelamin,
        noTelp: noTelp,
        email: email,
        userId: userId,
      ),
    );
    return _parseRecord(response.data);
  }

  Future<void> deactivate(int id) async {
    final response = await _dio.delete<Map<String, dynamic>>('/petugas/$id');
    final envelope = _asMap(response.data);

    if (envelope['success'] != true) {
      throw const FormatException('Server gagal menonaktifkan petugas.');
    }
  }

  Map<String, dynamic> _buildPayload({
    required String nama,
    String? nik,
    String? alamat,
    String? tempatLahir,
    String? tanggalLahir,
    int? jenisKelamin,
    String? noTelp,
    required String email,
    int? userId,
  }) {
    return {
      'nama': nama.trim(),
      'nik': _normalizeText(nik),
      'alamat': _normalizeText(alamat),
      'tempat_lahir': _normalizeText(tempatLahir),
      'tanggal_lahir': _normalizeText(tanggalLahir),
      'jenis_kelamin': jenisKelamin,
      'no_telp': _normalizeText(noTelp),
      'email': email.trim(),
      'user_id': userId,
    };
  }

  String? _normalizeText(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  PetugasApiModel _parseRecord(dynamic responseData) {
    final envelope = _asMap(responseData);
    final data = _asMap(envelope['data']);

    if (envelope['success'] != true || data.isEmpty) {
      throw const FormatException('Format data petugas tidak valid.');
    }
    return PetugasApiModel.fromJson(data);
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }
}

class PetugasApiModel {
  const PetugasApiModel({
    required this.id,
    required this.nama,
    required this.email,
    this.nik,
    this.alamat,
    this.tempatLahir,
    this.tanggalLahir,
    this.jenisKelamin,
    this.jenisKelaminNama,
    this.noTelp,
    this.userId,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
    this.status = 1,
  });

  final int id;
  final String nama;
  final String email;
  final String? nik;
  final String? alamat;
  final String? tempatLahir;
  final String? tanggalLahir;
  final int? jenisKelamin;
  final String? jenisKelaminNama;
  final String? noTelp;
  final int? userId;
  final int? createdBy;
  final int? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int status;

  factory PetugasApiModel.fromJson(Map<String, dynamic> json) {
    final id = _parseInt(json['id']);
    final nama = json['nama']?.toString().trim() ?? '';
    final email = json['email']?.toString().trim() ?? '';

    if (id <= 0 || nama.isEmpty || email.isEmpty) {
      throw const FormatException('ID, nama, atau email petugas tidak valid.');
    }

    return PetugasApiModel(
      id: id,
      nama: nama,
      email: email,
      nik: _parseNullableText(json['nik']),
      alamat: _parseNullableText(json['alamat']),
      tempatLahir: _parseNullableText(json['tempat_lahir']),
      tanggalLahir: _parseDateOnly(json['tanggal_lahir']),
      jenisKelamin: _parseNullableInt(json['jenis_kelamin']),
      jenisKelaminNama: _parseNullableText(json['jenis_kelamin_nama']),
      noTelp: _parseNullableText(json['no_telp']),
      userId: _parseNullableInt(json['user_id']),
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
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static String? _parseDateOnly(dynamic value) {
    final text = _parseNullableText(value);
    if (text == null) return null;

    if (DateTime.tryParse(text) == null) {
      throw const FormatException('Format tanggal lahir petugas tidak valid.');
    }
    return text;
  }
}
