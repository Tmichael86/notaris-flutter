import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/services/pemohon_api_service.dart';

void main() {
  group('PemohonApiService', () {
    test('getAll parses items and sends pagination parameters', () async {
      final adapter = _FakeAdapter((request) {
        expect(request.method, 'GET');
        expect(request.path, '/pemohon');
        expect(request.queryParameters, {'page': 2, 'page_size': 10});
        return _jsonResponse({
          'success': true,
          'data': {
            'items': [
              {
                'id': 7,
                'nama': 'Pemohon Satu',
                'alamat': 'Blitar',
                'jenis_kelamin': 1,
                'jenis_kelamin_nama': 'Laki-laki',
                'no_telp': '081234567890',
                'nik': '1234567890123456',
                'status': 1,
              },
              {'id': '8', 'nama': 'Pemohon Dua', 'status': '0'},
            ],
            'pagination': {'page': 2, 'page_size': 10},
          },
        });
      });

      final result = await _service(adapter).getAll(page: 2, pageSize: 10);

      expect(result, hasLength(2));
      expect(result.first.id, 7);
      expect(result.first.nama, 'Pemohon Satu');
      expect(result.first.jenisKelaminNama, 'Laki-laki');
      expect(result.first.nik, '1234567890123456');
      expect(result.last.id, 8);
      expect(result.last.status, 0);
    });

    test('getAll rejects an invalid response envelope', () async {
      final service = _service(
        _FakeAdapter((_) => _jsonResponse({
          'success': false,
          'data': {'items': []},
        })),
      );

      await expectLater(service.getAll(), throwsA(isA<FormatException>()));
    });

    test('getById requests a record and parses it', () async {
      final service = _service(_FakeAdapter((request) {
        expect(request.method, 'GET');
        expect(request.path, '/pemohon/12');
        return _jsonResponse({
          'success': true,
          'data': {'id': 12, 'nama': 'Pemohon Detail'},
        });
      }));

      final result = await service.getById(12);

      expect(result.id, 12);
      expect(result.nama, 'Pemohon Detail');
    });

    test('create trims text and normalizes optional blanks to null', () async {
      final service = _service(_FakeAdapter((request) {
        expect(request.method, 'POST');
        expect(request.path, '/pemohon');
        expect(_requestJson(request), {
          'nama': 'Pemohon Baru',
          'alamat': 'Kediri',
          'jenis_kelamin': 2,
          'no_telp': null,
          'nik': null,
        });
        return _jsonResponse({
          'success': true,
          'data': {'id': 20, 'nama': 'Pemohon Baru', 'alamat': 'Kediri'},
        }, statusCode: 201);
      }));

      final result = await service.create(
        nama: ' Pemohon Baru ',
        alamat: ' Kediri ',
        jenisKelamin: 2,
        noTelp: '  ',
        nik: '',
      );

      expect(result.id, 20);
      expect(result.nama, 'Pemohon Baru');
      expect(result.alamat, 'Kediri');
    });

    test('update sends ID and payload to the matching endpoint', () async {
      final service = _service(_FakeAdapter((request) {
        expect(request.method, 'PUT');
        expect(request.path, '/pemohon/21');
        expect(_requestJson(request), {
          'nama': 'Pemohon Update',
          'alamat': null,
          'jenis_kelamin': null,
          'no_telp': '081234567890',
          'nik': '1234567890123456',
        });
        return _jsonResponse({
          'success': true,
          'data': {'id': 21, 'nama': 'Pemohon Update'},
        });
      }));

      final result = await service.update(
        id: 21,
        nama: ' Pemohon Update ',
        noTelp: ' 081234567890 ',
        nik: ' 1234567890123456 ',
      );

      expect(result.id, 21);
      expect(result.nama, 'Pemohon Update');
    });

    test('deactivate accepts a successful response', () async {
      final service = _service(_FakeAdapter((request) {
        expect(request.method, 'DELETE');
        expect(request.path, '/pemohon/5');
        return _jsonResponse({'success': true, 'message': 'Deactivated'});
      }));

      await expectLater(service.deactivate(5), completes);
    });

    test('deactivate rejects a failed response', () async {
      final service = _service(_FakeAdapter((_) =>
          _jsonResponse({'success': false, 'message': 'Failed'})));

      await expectLater(service.deactivate(5), throwsA(isA<FormatException>()));
    });
  });

  group('PemohonApiModel.fromJson', () {
    test('parses numeric values and optional fields', () {
      final model = PemohonApiModel.fromJson({
        'id': 3.0,
        'nama': '  Pemohon Tes  ',
        'alamat': '  Blitar  ',
        'jenis_kelamin': 1.0,
        'jenis_kelamin_nama': ' Laki-laki ',
        'created_by': 9.0,
        'updated_by': '10',
        'status': 1.0,
        'created_at': '2026-10-10T12:00:00Z',
      });

      expect(model.id, 3);
      expect(model.nama, 'Pemohon Tes');
      expect(model.alamat, 'Blitar');
      expect(model.jenisKelamin, 1);
      expect(model.jenisKelaminNama, 'Laki-laki');
      expect(model.createdBy, 9);
      expect(model.updatedBy, 10);
      expect(model.status, 1);
      expect(model.createdAt, DateTime.utc(2026, 10, 10, 12));
      expect(model.updatedAt, isNull);
      expect(model.noTelp, isNull);
      expect(model.nik, isNull);
    });

    test('defaults status to active when absent or invalid', () {
      final model = PemohonApiModel.fromJson({
        'id': 4,
        'nama': 'Pemohon Valid',
        'status': 'invalid',
      });

      expect(model.status, 1);
    });

    test('rejects a non-positive ID or empty name', () {
      expect(
        () => PemohonApiModel.fromJson({'id': 0, 'nama': 'Valid'}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => PemohonApiModel.fromJson({'id': 1, 'nama': '  '}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

PemohonApiService _service(_FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
  dio.httpClientAdapter = adapter;
  return PemohonApiService(dio);
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
