import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/auth_session.dart';

bool allowsOwnProfile(AuthSession? s) {
  if (s == null || s.isOffline || s.userId < 1 || s.groupId < 1) return false;
  try {
    final p = s.token.split('.');
    if (p.length != 3 || p.any((v) => v.isEmpty)) return false;
    final c = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(p[1]))),
    );
    return c is Map &&
        c['iss'] == 'backend-notaris-go' &&
        c['uid'] == s.userId &&
        c['gid'] == s.groupId &&
        c['sv'] is int &&
        (c['sv'] as int) > 0 &&
        c['exp'] is int &&
        (c['exp'] as int) >
            DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
  } catch (_) {
    return false;
  }
}

class OwnProfile {
  OwnProfile.fromJson(Map<String, dynamic> m, int ownId)
    : id = _positive(m, 'id'),
      groupId = _positive(m, 'group_id'),
      revision = _positive(m, 'revision'),
      nama = _text(m, 'nama')!,
      username = _text(m, 'username')!,
      email = _text(m, 'email')!,
      groupName = _text(m, 'group_nama')!,
      groupKind = _text(m, 'group_jenis')!,
      noTelp = _text(m, 'no_telp', nullable: true),
      alamat = _text(m, 'alamat', nullable: true) {
    if (id != ownId ||
        m['status'] != 1 ||
        !{'user', 'superadmin'}.contains(groupKind) ||
        m.length != 11) {
      throw const FormatException('Identitas profil tidak valid.');
    }
  }
  final int id, groupId, revision;
  final String nama, username, email, groupName, groupKind;
  final String? noTelp, alamat;
  static int _positive(Map<String, dynamic> m, String k) {
    final v = m[k];
    if (v is! int || v < 1) {
      throw const FormatException('Revisi/identitas profil tidak valid.');
    }
    return v;
  }

  static String? _text(
    Map<String, dynamic> m,
    String k, {
    bool nullable = false,
  }) {
    final v = m[k];
    if (!m.containsKey(k) ||
        (v != null && v is! String) ||
        (!nullable && (v == null || (v as String).trim().isEmpty))) {
      throw const FormatException('Field profil tidak valid.');
    }
    return v as String?;
  }
}

class ProfileApiService {
  ProfileApiService(this.dio, {required this.session});
  final Dio dio;
  final AuthSession? Function() session;
  int _ownId() {
    final s = session();
    if (!allowsOwnProfile(s)) {
      throw StateError('Profil memerlukan sesi P0 online yang valid.');
    }
    return s!.userId;
  }

  OwnProfile _parse(Object? raw, int id) {
    if (raw is! Map || raw['success'] != true || raw['data'] is! Map) {
      throw const FormatException('Response profil tidak valid.');
    }
    return OwnProfile.fromJson(
      Map<String, dynamic>.from(raw['data'] as Map),
      id,
    );
  }

  Future<OwnProfile> read() async {
    final id = _ownId();
    final r = await dio.get<Object?>('/profile');
    if (session()?.userId != id) throw StateError('Akun berubah.');
    return _parse(r.data, id);
  }

  Future<OwnProfile> save({
    required int expectedRevision,
    required String nama,
    required String? noTelp,
    required String? alamat,
  }) async {
    final id = _ownId();
    final r = await dio.patch<Object?>(
      '/profile',
      data: {
        'expected_revision': expectedRevision,
        'nama': nama,
        'no_telp': noTelp,
        'alamat': alamat,
      },
    );
    if (session()?.userId != id) throw StateError('Akun berubah.');
    return _parse(r.data, id);
  }
}

String profileError(Object error) {
  if (error is DioException) {
    return switch (error.response?.statusCode) {
      401 => 'Sesi berakhir atau dicabut. Silakan login kembali.',
      403 => 'Akun atau Group tidak aktif; akses profil ditolak.',
      409 =>
        'Profil berubah di server. Refresh dan tinjau sebelum menyimpan lagi.',
      400 || 422 =>
        'Data profil tidak valid. Nama wajib diisi; periksa panjang field.',
      503 => 'Layanan Profile P0 belum tersedia.',
      _ =>
        'Backend tidak dapat dihubungi atau hasil operasi belum terkonfirmasi.',
    };
  }
  return 'Profil belum dapat diverifikasi. Refresh sebelum melanjutkan.';
}
