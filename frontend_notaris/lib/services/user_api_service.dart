import 'package:dio/dio.dart';

class UserApiService {
  UserApiService(this._dio);

  final Dio _dio;

  Future<List<UserApiModel>> getAll() async {
    final response = await _dio.get<Map<String, dynamic>>('/users');
    final envelope = _asMap(response.data);
    final data = envelope['data'];

    if (envelope['success'] != true || data is! List) {
      throw const FormatException('Format response user tidak valid.');
    }

    return data
        .whereType<Map>()
        .map((item) => UserApiModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<UserApiModel> create({
    required int groupId,
    required String nama,
    required String email,
    required String username,
    required String password,
    required String passwordConfirm,
    String? noTelp,
    String? alamat,
    String? image,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/users',
      data: _buildPayload(
        groupId: groupId,
        nama: nama,
        email: email,
        username: username,
        password: password,
        passwordConfirm: passwordConfirm,
        noTelp: noTelp,
        alamat: alamat,
        image: image,
      ),
    );

    return _parseRecord(response.data);
  }

  Future<UserApiModel> update({
    required int id,
    required int groupId,
    required String nama,
    required String email,
    required String username,
    String password = '',
    String passwordConfirm = '',
    String? noTelp,
    String? alamat,
    String? image,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/users/$id',
      data: _buildPayload(
        groupId: groupId,
        nama: nama,
        email: email,
        username: username,
        password: password,
        passwordConfirm: passwordConfirm,
        noTelp: noTelp,
        alamat: alamat,
        image: image,
      ),
    );

    return _parseRecord(response.data);
  }

  Future<void> deactivate(int id) async {
    final response = await _dio.delete<Map<String, dynamic>>('/users/$id');
    final envelope = _asMap(response.data);

    if (envelope['success'] != true) {
      throw const FormatException('Server gagal menonaktifkan user.');
    }
  }

  Map<String, dynamic> _buildPayload({
    required int groupId,
    required String nama,
    required String email,
    required String username,
    required String password,
    required String passwordConfirm,
    String? noTelp,
    String? alamat,
    String? image,
  }) {
    return {
      'group_id': groupId,
      'nama': nama.trim(),
      'no_telp': _nullableText(noTelp),
      'email': email.trim(),
      'username': username.trim(),
      'password': password,
      'password_confirm': passwordConfirm,
      'alamat': _nullableText(alamat),
      'image': _nullableText(image),
    };
  }

  String? _nullableText(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  UserApiModel _parseRecord(dynamic responseData) {
    final envelope = _asMap(responseData);
    final data = _asMap(envelope['data']);

    if (envelope['success'] != true || data.isEmpty) {
      throw const FormatException('Format data user tidak valid.');
    }

    return UserApiModel.fromJson(data);
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }
}

class UserApiModel {
  const UserApiModel({
    required this.id,
    required this.groupId,
    required this.username,
    required this.email,
    required this.nama,
    this.groupNama,
    this.noTelp,
    this.alamat,
    this.image,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
    this.status = 1,
  });

  final int id;
  final int groupId;
  final String username;
  final String email;
  final String nama;
  final String? groupNama;
  final String? noTelp;
  final String? alamat;
  final String? image;
  final int? createdBy;
  final int? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int status;

  factory UserApiModel.fromJson(Map<String, dynamic> json) {
    final id = _parseInt(json['id']);
    final groupId = _parseInt(json['group_id']);
    final username = json['username']?.toString().trim() ?? '';
    final email = json['email']?.toString().trim() ?? '';
    final nama = json['nama']?.toString().trim() ?? '';

    if (id <= 0 ||
        groupId <= 0 ||
        username.isEmpty ||
        email.isEmpty ||
        nama.isEmpty) {
      throw const FormatException(
        'ID, group, username, email, atau nama user tidak valid.',
      );
    }

    return UserApiModel(
      id: id,
      groupId: groupId,
      username: username,
      email: email,
      nama: nama,
      groupNama: _parseNullableText(json['group_nama']),
      noTelp: _parseNullableText(json['no_telp']),
      alamat: _parseNullableText(json['alamat']),
      image: _parseNullableText(json['image']),
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
