import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/services/group_api_service.dart';

void main() {
  group('GroupApiService', () {
    test('getAll parses active groups from the data array', () async {
      final service = _service(
        _FakeAdapter((request) {
          expect(request.method, 'GET');
          expect(request.path, '/groups');
          return _jsonResponse({
            'success': true,
            'data': [
              {
                'id': 1,
                'group_nama': 'Super Admin',
                'group_jenis': 'superadmin',
                'status': 1,
              },
              {
                'id': '2',
                'group_nama': 'Staff',
                'group_jenis': 'user',
                'status': 1,
              },
            ],
          });
        }),
      );

      final result = await service.getAll();

      expect(result, hasLength(2));
      expect(result.first.groupJenis, 'superadmin');
      expect(result.last.id, 2);
      expect(result.last.groupNama, 'Staff');
    });

    test('getAll rejects invalid response envelope', () async {
      final service = _service(
        _FakeAdapter((_) => _jsonResponse({'success': false, 'data': []})),
      );

      await expectLater(service.getAll(), throwsA(isA<FormatException>()));
    });

    test('create trims payload and parses returned group', () async {
      final service = _service(
        _FakeAdapter((request) {
          expect(request.method, 'POST');
          expect(request.path, '/groups');
          expect(_requestJson(request), {
            'group_nama': 'Operator',
            'group_jenis': 'user',
          });
          return _jsonResponse({
            'success': true,
            'data': {
              'id': 3,
              'group_nama': 'Operator',
              'group_jenis': 'user',
              'status': 1,
            },
          });
        }),
      );

      final result = await service.create(
        groupNama: ' Operator ',
        groupJenis: 'user',
      );

      expect(result.id, 3);
      expect(result.groupNama, 'Operator');
    });

    test('create rejects invalid group type before request', () async {
      final service = _service(
        _FakeAdapter((_) => fail('No request should be sent')),
      );

      await expectLater(
        service.create(groupNama: 'Staff', groupJenis: 'admin'),
        throwsArgumentError,
      );
    });

    test('update sends PUT to group ID endpoint', () async {
      final service = _service(
        _FakeAdapter((request) {
          expect(request.method, 'PUT');
          expect(request.path, '/groups/4');
          expect(_requestJson(request), {
            'group_nama': 'Staff Updated',
            'group_jenis': 'user',
          });
          return _jsonResponse({
            'success': true,
            'data': {
              'id': 4,
              'group_nama': 'Staff Updated',
              'group_jenis': 'user',
              'status': 1,
            },
          });
        }),
      );

      final result = await service.update(
        id: 4,
        groupNama: 'Staff Updated',
        groupJenis: 'user',
      );

      expect(result.groupNama, 'Staff Updated');
    });

    test('deactivate accepts successful response', () async {
      final service = _service(
        _FakeAdapter((request) {
          expect(request.method, 'DELETE');
          expect(request.path, '/groups/4');
          return _jsonResponse({'success': true, 'data': null});
        }),
      );

      await expectLater(service.deactivate(4), completes);
    });

    test('deactivate rejects failed response', () async {
      final service = _service(
        _FakeAdapter((_) => _jsonResponse({'success': false})),
      );

      await expectLater(service.deactivate(4), throwsA(isA<FormatException>()));
    });
  });

  group('GroupApiModel.fromJson', () {
    test('parses numeric and nullable fields', () {
      final model = GroupApiModel.fromJson({
        'id': 2.0,
        'group_nama': ' Staff ',
        'group_jenis': 'user',
        'created_by': 8.0,
        'updated_by': '9',
        'created_at': '2026-10-10T12:00:00Z',
        'status': 1.0,
      });

      expect(model.id, 2);
      expect(model.groupNama, 'Staff');
      expect(model.createdBy, 8);
      expect(model.updatedBy, 9);
      expect(model.createdAt, DateTime.utc(2026, 10, 10, 12));
      expect(model.status, 1);
    });

    test('rejects invalid ID or group type', () {
      expect(
        () => GroupApiModel.fromJson({
          'id': 0,
          'group_nama': 'Staff',
          'group_jenis': 'user',
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => GroupApiModel.fromJson({
          'id': 1,
          'group_nama': 'Staff',
          'group_jenis': 'admin',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

GroupApiService _service(_FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
  dio.httpClientAdapter = adapter;
  return GroupApiService(dio);
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
