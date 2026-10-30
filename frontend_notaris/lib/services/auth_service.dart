import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/auth_session.dart';

class AuthService {
  AuthService({
    Dio? dio,
    FlutterSecureStorage? storage,
    this.cacheKey = 'notaris.auth.session.v1',
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: const String.fromEnvironment(
                 'API_BASE_URL',
                 defaultValue: 'http://127.0.0.1:8080/api/v1',
               ),
               connectTimeout: const Duration(seconds: 5),
               receiveTimeout: const Duration(seconds: 8),
               sendTimeout: const Duration(seconds: 8),
               headers: const {'Accept': 'application/json'},
             ),
           ),
       _storage = storage ?? const FlutterSecureStorage();

  final String cacheKey;
  static const offlineGracePeriod = Duration(days: 7);

  final Dio _dio;
  final FlutterSecureStorage _storage;

  Future<AuthSession> login({
    required String username,
    required String password,
    required bool rememberMe,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'username': username.trim(), 'password': password},
    );
    final envelope = _asMap(response.data);
    final data = _asMap(envelope['data']);
    final token = data['token']?.toString() ?? '';
    if (token.isEmpty) {
      throw const AuthException(
        'Server tidak mengembalikan token autentikasi.',
      );
    }

    final session = await _fetchSession(token);
    if (rememberMe) {
      await _writeCache(session);
    } else {
      await clearPersistedSession();
    }
    return session;
  }

  Future<AuthSession?> restoreSession() async {
    final raw = await _storage.read(key: cacheKey);
    if (raw == null || raw.isEmpty) return null;

    AuthSession cached;
    try {
      cached = AuthSession.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      await clearPersistedSession();
      return null;
    }

    try {
      final refreshed = await _fetchSession(cached.token);
      await _writeCache(refreshed);
      return refreshed;
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      // A server-side rejection (including expired/revoked token) is not an
      // offline condition. Do not silently trust an old cache in that case.
      if (statusCode != null && statusCode < 500) {
        await clearPersistedSession();
        return null;
      }

      if (_isConnectivityFailure(error) ||
          (statusCode != null && statusCode >= 500)) {
        if (DateTime.now().difference(cached.verifiedAt) <=
            offlineGracePeriod) {
          return cached.asOffline();
        }
      }
      await clearPersistedSession();
      return null;
    } catch (_) {
      // Unknown failures must not silently grant offline access.
      return null;
    }
  }

  Future<AuthSession> _fetchSession(String token) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/auth/me/sidebar-access',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final envelope = _asMap(response.data);
    final data = _asMap(envelope['data']);
    final user = _asMap(data['user']);
    final sidebarsRaw = data['sidebars'];
    final sidebars = sidebarsRaw is List
        ? sidebarsRaw
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];

    final userId = _asInt(user['id']);
    final groupId = _asInt(user['group_id']);
    final name = (user['nama'] ?? user['username'])?.toString().trim() ?? '';
    final groupName = user['group_nama']?.toString().trim() ?? '';

    if (userId <= 0 || groupId <= 0 || name.isEmpty) {
      throw const AuthException('Profil pengguna dari server tidak valid.');
    }

    return AuthSession(
      token: token,
      userId: userId,
      groupId: groupId,
      userName: name,
      groupName: groupName.isEmpty ? 'Pengguna' : groupName,
      user: user,
      sidebars: sidebars,
      verifiedAt: DateTime.now(),
    );
  }

  Future<void> _writeCache(AuthSession session) async {
    await _storage.write(key: cacheKey, value: session.encode());
  }

  Future<void> clearPersistedSession() => _storage.delete(key: cacheKey);

  bool _isConnectivityFailure(DioException error) {
    return error.response == null &&
        (error.type == DioExceptionType.connectionError ||
            error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.sendTimeout);
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String messageFor(Object error) {
    if (error is DioException) {
      final body = error.response?.data;
      if (body is Map && body['message'] is String) {
        return body['message'] as String;
      }
      if (_isConnectivityFailure(error)) {
        return 'Server tidak dapat dihubungi. Periksa koneksi atau alamat API.';
      }
    }
    if (error is AuthException) return error.message;
    return 'Login gagal. Periksa kredensial dan koneksi server.';
  }
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}
