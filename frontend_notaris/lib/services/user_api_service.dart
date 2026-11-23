import 'package:dio/dio.dart';

typedef UsersQuery = ({int page, String search, int? groupId, int? status});
typedef UsersPage = ({
  List<UserApiModel> items,
  int total,
  int page,
  int pageSize,
  List<UserGroupRef> groups,
});

class UserApiService {
  UserApiService(this._dio);
  final Dio _dio;
  Future<int> verifiedPetugasReference(int serverId) async {
    if (serverId < 1) {
      throw const FormatException('Referensi user tidak valid.');
    }
    final row = _map(
      _envelope(
        (await _dio.get<Object?>('/petugas/references/users/$serverId')).data,
      ),
    );
    if (row['id'] != serverId || row['status'] != 1) {
      throw const FormatException('Referensi user tidak tersedia.');
    }
    return serverId;
  }

  Future<UsersPage> list(UsersQuery query) async {
    final data = _map(
      _envelope(
        (await _dio.get<Object?>(
          '/users',
          queryParameters: {
            'page': query.page,
            'page_size': 10,
            if (query.search.trim().isNotEmpty) 'search': query.search.trim(),
            if (query.groupId != null) 'group_id': query.groupId,
            if (query.status != null) 'status': query.status,
          },
        )).data,
      ),
    );
    final rows = data['items'], groups = data['groups'];
    if (rows is! List ||
        groups is! List ||
        data['total'] is! int ||
        data['page'] != query.page ||
        data['page_size'] != 10 ||
        (data['total'] as int) < 0 ||
        rows.length > 10) {
      throw const FormatException('Halaman Users tidak valid.');
    }
    return (
      items: rows.map((r) => UserApiModel.fromJson(_map(r))).toList(),
      total: data['total'] as int,
      page: query.page,
      pageSize: 10,
      groups: groups.map((r) => UserGroupRef.fromJson(_map(r))).toList(),
    );
  }

  Future<UserApiModel> get(int id) async =>
      _user((await _dio.get<Object?>('/users/$id')).data);
  Future<List<UserGroupRef>> assignableGroups() async {
    final data = _envelope(
      (await _dio.get<Object?>('/users/assignable-groups')).data,
    );
    if (data is! List) {
      throw const FormatException('Referensi group tidak valid.');
    }
    final rows = data.map((r) => UserGroupRef.fromJson(_map(r))).toList();
    if (rows.any((g) => g.status != 1 || g.kind != 'user')) {
      throw const FormatException('Group tidak dapat ditugaskan.');
    }
    return rows;
  }

  Map<String, Object?> _profile({
    required int groupId,
    required String nama,
    required String username,
    required String email,
    String? noTelp,
    String? alamat,
  }) => {
    'group_id': groupId,
    'nama': nama.trim(),
    'username': username.trim(),
    'email': email.trim(),
    'no_telp': _text(noTelp),
    'alamat': _text(alamat),
  };
  Future<UserApiModel> create({
    required int groupId,
    required String nama,
    required String username,
    required String email,
    required String password,
    required String passwordConfirm,
    String? noTelp,
    String? alamat,
  }) async => _user(
    (await _dio.post<Object?>(
      '/users',
      data: {
        ..._profile(
          groupId: groupId,
          nama: nama,
          username: username,
          email: email,
          noTelp: noTelp,
          alamat: alamat,
        ),
        'password': password,
        'password_confirm': passwordConfirm,
      },
    )).data,
  );
  Future<UserApiModel> update({
    required int id,
    required int expectedRevision,
    required int groupId,
    required String nama,
    required String username,
    required String email,
    String? noTelp,
    String? alamat,
  }) async => _user(
    (await _dio.put<Object?>(
      '/users/$id',
      data: {
        ..._profile(
          groupId: groupId,
          nama: nama,
          username: username,
          email: email,
          noTelp: noTelp,
          alamat: alamat,
        ),
        'expected_revision': expectedRevision,
      },
    )).data,
  );
  Future<void> deactivate(int id, {required int expectedRevision}) async {
    _envelope(
      (await _dio.delete<Object?>(
        '/users/$id',
        data: {'expected_revision': expectedRevision},
      )).data,
    );
  }

  Future<void> resetPassword(
    int id, {
    required int expectedRevision,
    required String password,
    required String passwordConfirm,
  }) async {
    _envelope(
      (await _dio.post<Object?>(
        '/users/$id/password-reset',
        data: {
          'expected_revision': expectedRevision,
          'password': password,
          'password_confirm': passwordConfirm,
        },
      )).data,
    );
  }

  Object? _envelope(Object? value) {
    final data = _map(value);
    if (data['success'] != true) {
      throw const FormatException('Server tidak mengonfirmasi operasi Users.');
    }
    return data['data'];
  }

  UserApiModel _user(Object? value) =>
      UserApiModel.fromJson(_map(_envelope(value)));
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map) throw const FormatException('Response Users tidak valid.');
  return Map<String, dynamic>.from(value);
}

String? _text(String? value) =>
    value == null || value.trim().isEmpty ? null : value.trim();
int _id(Object? value) {
  if (value is! int || value < 1) {
    throw const FormatException('Identitas Users tidak valid.');
  }
  return value;
}

int _status(Object? value) {
  if (value is! int || (value != 0 && value != 1)) {
    throw const FormatException('Status Users tidak diketahui.');
  }
  return value;
}

class UserGroupRef {
  const UserGroupRef(this.id, this.name, this.kind, this.status);
  final int id, status;
  final String name, kind;
  factory UserGroupRef.fromJson(Map<String, dynamic> r) => UserGroupRef(
    _id(r['id']),
    r['group_nama'] as String? ?? 'Group tidak bernama',
    r['group_jenis'] as String? ?? '',
    _status(r['status']),
  );
}

class UserApiModel {
  const UserApiModel({
    required this.id,
    required this.groupId,
    required this.username,
    required this.email,
    required this.nama,
    required this.status,
    required this.revision,
    required this.groupKind,
    required this.groupStatus,
    this.groupNama,
    this.noTelp,
    this.alamat,
  });
  final int id, groupId, status, revision, groupStatus;
  final String nama, username, email, groupKind;
  final String? groupNama, noTelp, alamat;
  bool get ordinary => groupKind == 'user';
  factory UserApiModel.fromJson(Map<String, dynamic> r) {
    for (final key in ['nama', 'username', 'email']) {
      if (r[key] is! String || (r[key] as String).trim().isEmpty) {
        throw const FormatException('Data Users tidak lengkap.');
      }
    }
    return UserApiModel(
      id: _id(r['id']),
      groupId: _id(r['group_id']),
      username: r['username'] as String,
      email: r['email'] as String,
      nama: r['nama'] as String,
      status: _status(r['status']),
      revision: _id(r['revision']),
      groupKind: r['group_jenis'] as String? ?? '',
      groupStatus: _status(r['group_status']),
      groupNama: r['group_nama'] as String?,
      noTelp: r['no_telp'] as String?,
      alamat: r['alamat'] as String?,
    );
  }
}

/// Do not display arbitrary server/SQL bodies or Dio request payloads.
String usersError(Object error) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    final raw = error.response?.data;
    final code = raw is Map ? raw['code'] : null;
    final id = raw is Map ? raw['request_id'] : null;
    final message = switch (code) {
      'identity_conflict' => 'Username atau email sudah digunakan.',
      'stale_revision' =>
        'Data berubah di server. Muat ulang dan tinjau sebelum mencoba lagi.',
      'last_recovery_administrator' =>
        'Administrator pemulihan terakhir harus tetap aktif.',
      'group_not_assignable' =>
        'Group tidak aktif atau tidak dapat ditugaskan.',
      'invalid_password_input' =>
        'Password harus 12–72 byte dan konfirmasinya sama.',
      'admin_security_not_enabled' =>
        'Administrasi Users belum diaktifkan pada deployment ini.',
      _ => switch (status) {
        401 => 'Sesi berakhir atau dicabut. Silakan login kembali.',
        403 => 'Operasi ditolak oleh izin atau kebijakan akun.',
        409 => 'Konflik data. Muat ulang dan tinjau data terbaru.',
        400 || 422 => 'Data tidak valid. Periksa seluruh field.',
        503 => 'Layanan administrasi belum tersedia.',
        _ => 'Server tidak dapat dihubungi atau operasi belum terkonfirmasi.',
      },
    };
    return id is String && RegExp(r'^[a-f0-9-]{36}$').hasMatch(id)
        ? '$message ID: $id'
        : message;
  }
  return 'Data Users tidak dapat dimuat atau operasi belum terkonfirmasi.';
}
