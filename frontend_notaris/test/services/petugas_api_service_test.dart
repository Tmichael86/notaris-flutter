import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/services/petugas_api_service.dart';

void main() {
  group('PetugasApiService', () {
    test('getAll parses records and sends pagination parameters', () async {
      final adapter = _FakeAdapter((request) {
        expect(request.method, 'GET');
        expect(request.path, '/petugas');
        expect(request.queryParameters, {'page': 2, 'page_size': 10});

        return _jsonResponse({
          'success': true,
          'data': {
            'items': [
              {
                'id': 7,
                'nama': 'Petugas Satu',
                'email': 'satu@example.com',
                'nik': '123',
                'alamat': null,
                'tempat_lahir': 'Blitar',
                'tanggal_lahir': '1995-04-12',
                'jenis_kelamin': 1,
                'jenis_kelamin_nama': 'Laki-laki',
                'no_telp': '08123456789',
                'user_id': 8,
                'created_by': 2,
                'updated_by': null,
                'created_at': '2026-10-01T08:00:00Z',
                'updated_at': null,
                'status': 1,
              },
            ],
            'pagination': {'page': 2, 'page_size': 10, 'total': 1},
          },
        });
      });
      final service = _service(adapter);

      final result = await service.getAll(page: 2, pageSize: 10);

      expect(result, hasLength(1));
      expect(result.single.id, 7);
      expect(result.single.nama, 'Petugas Satu');
      expect(result.single.jenisKelaminNama, 'Laki-laki');
      expect(result.single.tanggalLahir, '1995-04-12');
      expect(result.single.alamat, isNull);
      expect(result.single.userId, 8);
      expect(result.single.createdAt, DateTime.utc(2026, 10, 1, 8));
      expect(result.single.updatedAt, isNull);
    });

    test('getAll rejects an invalid response envelope', () async {
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

    test('getById requests the specified ID and parses the record', () async {
      final adapter = _FakeAdapter((request) {
        expect(request.method, 'GET');
        expect(request.path, '/petugas/12');
        return _jsonResponse({
          'success': true,
          'data': {
            'id': 12,
            'nama': 'Petugas Dua',
            'email': 'dua@example.com',
          },
        });
      });

      final result = await _service(adapter).getById(12);

      expect(result.id, 12);
      expect(result.nama, 'Petugas Dua');
      expect(result.nik, isNull);
    });

    test('create trims fields and sends the expected payload', () async {
      final adapter = _FakeAdapter((request) {
        expect(request.method, 'POST');
        expect(request.path, '/petugas');
        expect(_requestJson(request), {
          'nama': 'Petugas Baru',
          'nik': '12345',
          'alamat': null,
          'tempat_lahir': 'Blitar',
          'tanggal_lahir': '1998-01-02',
          'jenis_kelamin': 2,
          'no_telp': null,
          'email': 'baru@example.com',
          'user_id': 4,
        });

        return _jsonResponse({
          'success': true,
          'data': {
            'id': 20,
            'nama': 'Petugas Baru',
            'email': 'baru@example.com',
          },
        }, statusCode: 201);
      });

      final result = await _service(adapter).create(
        nama: ' Petugas Baru ',
        nik: ' 12345 ',
        alamat: ' ',
        tempatLahir: ' Blitar ',
        tanggalLahir: '1998-01-02',
        jenisKelamin: 2,
        noTelp: '',
        email: ' baru@example.com ',
        userId: 4,
      );

      expect(result.id, 20);
      expect(result.email, 'baru@example.com');
    });

    test('update sends the ID and payload', () async {
      final adapter = _FakeAdapter((request) {
        expect(request.method, 'PUT');
        expect(request.path, '/petugas/21');
        expect(_requestJson(request)['nama'], 'Petugas Update');

        return _jsonResponse({
          'success': true,
          'data': {
            'id': 21,
            'nama': 'Petugas Update',
            'email': 'update@example.com',
          },
        });
      });

      final result = await _service(adapter).update(
        id: 21,
        nama: ' Petugas Update ',
        email: 'update@example.com',
      );

      expect(result.id, 21);
      expect(result.nama, 'Petugas Update');
    });

    test('deactivate accepts a successful response', () async {
      final adapter = _FakeAdapter((request) {
        expect(request.method, 'DELETE');
        expect(request.path, '/petugas/5');
        return _jsonResponse({'success': true, 'message': 'Deactivated'});
      });

      await expectLater(_service(adapter).deactivate(5), completes);
    });

    test('deactivate rejects an unsuccessful response', () async {
      final service = _service(
        _FakeAdapter(
          (_) => _jsonResponse({
            'success': false,
            'message': 'Could not deactivate',
          }),
        ),
      );

      await expectLater(service.deactivate(5), throwsA(isA<FormatException>()));
    });
  });

  group('PetugasApiModel.fromJson', () {
    test('parses numeric IDs and nullable fields', () {
      final model = PetugasApiModel.fromJson({
        'id': 3.0,
        'nama': ' Petugas ',
        'email': ' petugas@example.com ',
        'jenis_kelamin': 1.0,
        'user_id': '9',
        'status': 1.0,
      });

      expect(model.id, 3);
      expect(model.nama, 'Petugas');
      expect(model.email, 'petugas@example.com');
      expect(model.jenisKelamin, 1);
      expect(model.userId, 9);
      expect(model.status, 1);
      expect(model.tanggalLahir, isNull);
    });

    test('rejects an invalid birth date', () {
      expect(
        () => PetugasApiModel.fromJson({
          'id': 1,
          'nama': 'Petugas',
          'email': 'petugas@example.com',
          'tanggal_lahir': 'not-a-date',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a record without a valid ID, name, or email', () {
      expect(
        () => PetugasApiModel.fromJson({
          'id': 0,
          'nama': 'Petugas',
          'email': 'petugas@example.com',
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => PetugasApiModel.fromJson({
          'id': 1,
          'nama': ' ',
          'email': 'petugas@example.com',
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => PetugasApiModel.fromJson({
          'id': 1,
          'nama': 'Petugas',
          'email': '',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

PetugasApiService _service(_FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
  dio.httpClientAdapter = adapter;
  return PetugasApiService(dio);
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
