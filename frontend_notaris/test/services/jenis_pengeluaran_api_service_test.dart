import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/services/jenis_pengeluaran_api_service.dart';

void main() {
  group('JenisPengeluaranApiService', () {
    test('getAll parses items and sends pagination parameters', () async {
      final adapter = _FakeAdapter((request) {
        expect(request.method, 'GET');
        expect(request.path, '/jenis-pengeluaran');
        expect(request.queryParameters, {'page': 2, 'page_size': 10});

        return _jsonResponse({
          'success': true,
          'data': {
            'items': [
              {
                'id': 7,
                'nama': 'Operasional',
                'created_at': '2026-10-01T08:00:00Z',
                'updated_at': '2026-10-02T09:30:00Z',
                'status': 1,
              },
              {'id': '8', 'nama': 'Transportasi', 'status': '0'},
            ],
            'pagination': {'page': 2, 'page_size': 10},
          },
        });
      });
      final service = _service(adapter);

      final result = await service.getAll(page: 2, pageSize: 10);

      expect(result, hasLength(2));
      expect(result[0].id, 7);
      expect(result[0].nama, 'Operasional');
      expect(result[0].createdAt, DateTime.utc(2026, 10, 1, 8));
      expect(result[0].updatedAt, DateTime.utc(2026, 10, 2, 9, 30));
      expect(result[0].status, 1);
      expect(result[1].id, 8);
      expect(result[1].status, 0);
    });

    test('getAll throws FormatException for an invalid envelope', () async {
      final service = _service(
        _FakeAdapter(
          (_) => _jsonResponse({
            'success': false,
            'data': {'items': []},
          }),
        ),
      );

      await expectLater(service.getAll(), throwsA(isA<FormatException>()));
    });

    test('getAll throws FormatException when items is not a list', () async {
      final service = _service(
        _FakeAdapter(
          (_) => _jsonResponse({
            'success': true,
            'data': {'items': 'not-a-list'},
          }),
        ),
      );

      await expectLater(service.getAll(), throwsA(isA<FormatException>()));
    });

    test('create trims the name and parses the created record', () async {
      final adapter = _FakeAdapter((request) {
        expect(request.method, 'POST');
        expect(request.path, '/jenis-pengeluaran');
        expect(_requestJson(request), {'nama': 'Operasional'});

        return _jsonResponse({
          'success': true,
          'data': {'id': 12, 'nama': 'Operasional'},
        }, statusCode: 201);
      });
      final service = _service(adapter);

      final result = await service.create(nama: '  Operasional  ');

      expect(result.id, 12);
      expect(result.nama, 'Operasional');
      expect(result.status, 1);
    });

    test('create throws FormatException for an invalid record envelope',
        () async {
      final service = _service(
        _FakeAdapter(
          (_) => _jsonResponse(
            {'success': true, 'data': {}},
            statusCode: 201,
          ),
        ),
      );

      await expectLater(
        service.create(nama: 'Operasional'),
        throwsA(isA<FormatException>()),
      );
    });

    test('update sends the ID and trimmed name', () async {
      final adapter = _FakeAdapter((request) {
        expect(request.method, 'PUT');
        expect(request.path, '/jenis-pengeluaran/21');
        expect(_requestJson(request), {'nama': 'Pemeliharaan'});

        return _jsonResponse({
          'success': true,
          'data': {'id': 21, 'nama': 'Pemeliharaan', 'status': 1},
        });
      });
      final service = _service(adapter);

      final result = await service.update(id: 21, nama: ' Pemeliharaan ');

      expect(result.id, 21);
      expect(result.nama, 'Pemeliharaan');
    });

    test('update throws FormatException for an invalid record envelope',
        () async {
      final service = _service(
        _FakeAdapter(
          (_) => _jsonResponse({'success': true, 'data': {}}),
        ),
      );

      await expectLater(
        service.update(id: 21, nama: 'Pemeliharaan'),
        throwsA(isA<FormatException>()),
      );
    });

    test('deactivate sends DELETE and accepts a successful response', () async {
      final adapter = _FakeAdapter((request) {
        expect(request.method, 'DELETE');
        expect(request.path, '/jenis-pengeluaran/5');
        return _jsonResponse({'success': true, 'message': 'Deactivated'});
      });
      final service = _service(adapter);

      await expectLater(service.deactivate(5), completes);
    });

    test('deactivate throws FormatException when success is false', () async {
      final service = _service(
        _FakeAdapter(
          (_) => _jsonResponse({
            'success': false,
            'message': 'Could not deactivate',
          }),
        ),
      );

      await expectLater(
        service.deactivate(5),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('JenisPengeluaranApiModel.fromJson', () {
    test('parses numeric values, trims name, and handles optional fields', () {
      final model = JenisPengeluaranApiModel.fromJson({
        'id': 3.0,
        'nama': '  Administrasi  ',
        'status': 1.0,
        'created_at': '2026-10-10T12:00:00Z',
      });

      expect(model.id, 3);
      expect(model.nama, 'Administrasi');
      expect(model.status, 1);
      expect(model.createdAt, DateTime.utc(2026, 10, 10, 12));
      expect(model.updatedAt, isNull);
    });

    test('defaults status to active when status is absent or invalid', () {
      final model = JenisPengeluaranApiModel.fromJson({
        'id': 4,
        'nama': 'Listrik',
        'status': 'invalid',
      });

      expect(model.status, 1);
    });

    test('rejects a non-positive ID', () {
      expect(
        () => JenisPengeluaranApiModel.fromJson({'id': 0, 'nama': 'Valid'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects an empty name', () {
      expect(
        () => JenisPengeluaranApiModel.fromJson({'id': 1, 'nama': '  '}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

JenisPengeluaranApiService _service(_FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
  dio.httpClientAdapter = adapter;
  return JenisPengeluaranApiService(dio);
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
