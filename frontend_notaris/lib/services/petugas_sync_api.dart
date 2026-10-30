import 'package:dio/dio.dart';

enum PetugasSyncFailureKind {
  invalid,
  conflict,
  unauthorized,
  forbidden,
  expired,
  reference,
  timeout,
  server,
  network,
  blocked,
}

class PetugasSyncFailure implements Exception {
  const PetugasSyncFailure(this.kind, [this.details]);
  final PetugasSyncFailureKind kind;
  final Object? details;
}

Map<String, dynamic> syncMap(Object? value) {
  if (value is! Map) {
    throw const FormatException('Invalid Petugas sync object');
  }
  return Map<String, dynamic>.from(value);
}

/// Inject the project's authenticatedDioProvider Dio; no independent base URL,
/// credentials or automatic execution is installed by this adapter.
class PetugasSyncApi {
  PetugasSyncApi(this.dio);
  final Dio dio;
  Future<Map<String, dynamic>> push(Map<String, dynamic> mutation) => _request(
    'PUT',
    '/petugas/sync/${mutation['petugas_uuid']}',
    data: mutation,
  );
  Future<Map<String, dynamic>> pull(int cursor, {int limit = 100}) => _request(
    'GET',
    '/petugas/sync/pull',
    query: {'cursor': cursor, 'limit': limit},
  );
  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Object? data,
    Map<String, dynamic>? query,
  }) async {
    try {
      final response = await dio.request<Object?>(
        path,
        data: data,
        queryParameters: query,
        options: Options(method: method),
      );
      if ((response.statusCode ?? 500) >= 400) {
        throw _failure(response.statusCode, response.data);
      }
      final envelope = syncMap(response.data);
      if (envelope['success'] != true) {
        throw const FormatException('Invalid sync envelope');
      }
      return syncMap(envelope['data']);
    } on DioException catch (e) {
      if (e.response != null) {
        throw _failure(e.response!.statusCode, e.response!.data);
      }
      if ({
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      }.contains(e.type)) {
        throw const PetugasSyncFailure(PetugasSyncFailureKind.timeout);
      }
      throw const PetugasSyncFailure(PetugasSyncFailureKind.network);
    }
  }

  PetugasSyncFailure _failure(int? status, Object? data) =>
      PetugasSyncFailure(switch (status) {
        400 => PetugasSyncFailureKind.invalid,
        401 => PetugasSyncFailureKind.unauthorized,
        403 => PetugasSyncFailureKind.forbidden,
        409 => PetugasSyncFailureKind.conflict,
        410 => PetugasSyncFailureKind.expired,
        422 => PetugasSyncFailureKind.reference,
        _ => PetugasSyncFailureKind.server,
      }, data);
}
