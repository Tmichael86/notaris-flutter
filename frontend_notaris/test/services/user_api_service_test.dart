import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/services/user_api_service.dart';

void main() {
  group('UserApiService', () {
    test('getAll parses a list returned directly in data', () async {
      final service = _service(
        _FakeAdapter((request) {
          expect(request.method, 'GET');
          expect(request.path, '/users');
          expect(request.queryParameters, isEmpty);
          return _jsonResponse({
            'success': true,
            'data': [
              {
                'id': 2,
                'group_id': 1,
                'group_nama': 'Admin',
                'username': 'admin2',
                'email': 'admin@example.com',
                'nama': 'Admin Dua',
                'status': 1,
              },
              {
                'id': '3',
                'group_id': '2',
                'username': 'staff3',
                'email': 'staff@example.com',
                'nama': 'Staff Tiga',
                'status': 0,
              },
            ],
          });
        }),
      );

      final result = await service.getAll();

      expect(result, hasLength(2));
      expect(result.first.id, 2);
      expect(result.first.groupNama, 'Admin');
      expect(result.last.id, 3);
      expect(result.last.groupId, 2);
      expect(result.last.status, 0);
    });

    test('getAll rejects an invalid response envelope', () async {
      final service = _service(
        _FakeAdapter((_) => _jsonResponse({'success': false, 'data': []})),
      );

      await expectLater(service.getAll(), throwsA(isA<FormatException>()));
    });

    test('create trims required text and normalizes optional blanks', () async {
      final service = _service(
        _FakeAdapter((request) {
          expect(request.method, 'POST');
          expect(request.path, '/users');
          expect(_requestJson(request), {
            'group_id': 2,
            'nama': 'User Baru',
            'no_telp': null,
            'email': 'user@example.com',
            'username': 'userbaru',
            'password': 'secret123',
            'password_confirm': 'secret123',
            'alamat': 'Blitar',
            'image': null,
          });
          return _jsonResponse({
            'success': true,
            'data': {
              'id': 10,
              'group_id': 2,
              'username': 'userbaru',
              'email': 'user@example.com',
              'nama': 'User Baru',
            },
          });
        }),
      );

      final result = await service.create(
        groupId: 2,
        nama: ' User Baru ',
        email: ' user@example.com ',
        username: ' userbaru ',
        password: 'secret123',
        passwordConfirm: 'secret123',
        alamat: ' Blitar ',
        noTelp: ' ',
        image: '',
      );

      expect(result.id, 10);
      expect(result.nama, 'User Baru');
    });

    test('update sends a payload to the user ID endpoint', () async {
      final service = _service(
        _FakeAdapter((request) {
          expect(request.method, 'PUT');
          expect(request.path, '/users/11');
          expect(_requestJson(request), {
            'group_id': 3,
            'nama': 'User Update',
            'no_telp': '081234567890',
            'email': 'updated@example.com',
            'username': 'updateduser',
            'password': '',
            'password_confirm': '',
            'alamat': null,
            'image': 'avatar.png',
          });
          return _jsonResponse({
            'success': true,
            'data': {
              'id': 11,
              'group_id': 3,
              'username': 'updateduser',
              'email': 'updated@example.com',
              'nama': 'User Update',
            },
          });
        }),
      );

      final result = await service.update(
        id: 11,
        groupId: 3,
        nama: ' User Update ',
        email: ' updated@example.com ',
        username: ' updateduser ',
        noTelp: '081234567890',
        image: ' avatar.png ',
      );

      expect(result.id, 11);
      expect(result.username, 'updateduser');
    });

    test('deactivate accepts a successful response', () async {
      final service = _service(
        _FakeAdapter((request) {
          expect(request.method, 'DELETE');
          expect(request.path, '/users/5');
          return _jsonResponse({
            'success': true,
            'message': 'User berhasil dinonaktifkan',
          });
        }),
      );

      await expectLater(service.deactivate(5), completes);
    });

    test('deactivate rejects a failed response', () async {
      final service = _service(
        _FakeAdapter(
          (_) => _jsonResponse({'success': false, 'message': 'Failed'}),
        ),
      );

      await expectLater(service.deactivate(5), throwsA(isA<FormatException>()));
    });
  });

  group('UserApiModel.fromJson', () {
    test('parses numeric IDs and nullable fields', () {
      final model = UserApiModel.fromJson({
        'id': 3.0,
        'group_id': 2.0,
        'username': ' usertest ',
        'email': ' user@example.com ',
        'nama': ' User Test ',
        'group_nama': ' Admin ',
        'created_by': 9.0,
        'updated_by': '10',
        'status': 1.0,
        'created_at': '2026-10-10T12:00:00Z',
      });

      expect(model.id, 3);
      expect(model.groupId, 2);
      expect(model.username, 'usertest');
      expect(model.email, 'user@example.com');
      expect(model.nama, 'User Test');
      expect(model.groupNama, 'Admin');
      expect(model.createdBy, 9);
      expect(model.updatedBy, 10);
      expect(model.status, 1);
      expect(model.createdAt, DateTime.utc(2026, 10, 10, 12));
      expect(model.updatedAt, isNull);
      expect(model.noTelp, isNull);
      expect(model.alamat, isNull);
      expect(model.image, isNull);
    });

    test('defaults status to active when absent or invalid', () {
      final model = UserApiModel.fromJson({
        'id': 4,
        'group_id': 1,
        'username': 'validuser',
        'email': 'valid@example.com',
        'nama': 'Valid User',
        'status': 'invalid',
      });

      expect(model.status, 1);
    });

    test('rejects invalid IDs and empty required text', () {
      expect(
        () => UserApiModel.fromJson({
          'id': 0,
          'group_id': 1,
          'username': 'validuser',
          'email': 'valid@example.com',
          'nama': 'Valid User',
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => UserApiModel.fromJson({
          'id': 1,
          'group_id': 1,
          'username': ' ',
          'email': 'valid@example.com',
          'nama': 'Valid User',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

UserApiService _service(_FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
  dio.httpClientAdapter = adapter;
  return UserApiService(dio);
}

dynamic _requestJson(RequestOptions request) {
  final data = request.data;
  if (data is String) return jsonDecode(data);
  return data;
}

ResponseBody _jsonResponse(
  Map<String, dynamic> payload, {
  int statusCode = 200,
}) {
  return ResponseBody.fromString(
    jsonEncode(payload),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.respond);

  final ResponseBody Function(RequestOptions request) respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}
