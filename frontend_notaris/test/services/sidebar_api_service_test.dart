import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/services/sidebar_api_service.dart';

void main() {
  group('SidebarApiService', () {
    test('getAll parses sidebar list', () async {
      final service = _service(
        _FakeAdapter((request) {
          expect(request.method, 'GET');
          expect(request.path, '/sidebars');
          return _jsonResponse({
            'success': true,
            'data': [
              _sidebarJson(id: 1, nama: 'Master', kode: 'master'),
              _sidebarJson(id: 2, nama: 'Pemohon', kode: 'pemohon'),
            ],
          });
        }),
      );

      final result = await service.getAll();

      expect(result, hasLength(2));
      expect(result.first.nama, 'Master');
      expect(result.last.id, 2);
      expect(result.last.kode, 'pemohon');
    });

    test('getAll rejects invalid envelope', () async {
      final service = _service(
        _FakeAdapter((_) => _jsonResponse({'success': false, 'data': []})),
      );

      await expectLater(service.getAll(), throwsA(isA<FormatException>()));
    });

    test('getTree parses roots and children', () async {
      final service = _service(
        _FakeAdapter((request) {
          expect(request.method, 'GET');
          expect(request.path, '/sidebars/tree');
          return _jsonResponse({
            'success': true,
            'data': [
              {
                'sidebar': _sidebarJson(id: 1, nama: 'Master', kode: 'master'),
                'childs': [
                  _sidebarJson(id: 2, nama: 'Pemohon', kode: 'pemohon'),
                ],
              },
            ],
          });
        }),
      );

      final result = await service.getTree();

      expect(result, hasLength(1));
      expect(result.single.sidebar.nama, 'Master');
      expect(result.single.childs, hasLength(1));
      expect(result.single.childs.single.kode, 'pemohon');
    });

    test('getTree accepts roots without children', () async {
      final service = _service(
        _FakeAdapter(
          (_) => _jsonResponse({
            'success': true,
            'data': [
              {'sidebar': _sidebarJson(id: 1, nama: 'Master', kode: 'master')},
            ],
          }),
        ),
      );

      final result = await service.getTree();

      expect(result.single.childs, isEmpty);
    });

    test('getById parses sidebar detail', () async {
      final service = _service(
        _FakeAdapter((request) {
          expect(request.method, 'GET');
          expect(request.path, '/sidebars/8');
          return _jsonResponse({
            'success': true,
            'data': _sidebarJson(id: 8, nama: 'Petugas', kode: 'petugas'),
          });
        }),
      );

      final result = await service.getById(8);

      expect(result.id, 8);
      expect(result.nama, 'Petugas');
    });

    test('getById rejects invalid envelope', () async {
      final service = _service(
        _FakeAdapter((_) => _jsonResponse({'success': false, 'data': null})),
      );

      await expectLater(service.getById(8), throwsA(isA<FormatException>()));
    });
  });

  group('SidebarApiModel.fromJson', () {
    test('parses numeric and nullable fields', () {
      final model = SidebarApiModel.fromJson({
        ..._sidebarJson(id: 4, nama: ' Reports ', kode: 'reports'),
        'sidebar_parent_id': 1.0,
        'created_by': 9.0,
        'updated_by': '10',
        'created_at': '2026-10-10T12:00:00Z',
        'status': 1.0,
      });

      expect(model.id, 4);
      expect(model.nama, 'Reports');
      expect(model.parentId, 1);
      expect(model.createdBy, 9);
      expect(model.updatedBy, 10);
      expect(model.status, 1);
      expect(model.createdAt, DateTime.utc(2026, 10, 10, 12));
    });

    test('rejects invalid ID or missing required fields', () {
      expect(
        () => SidebarApiModel.fromJson({
          ..._sidebarJson(id: 0, nama: 'Master', kode: 'master'),
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => SidebarApiModel.fromJson({
          ..._sidebarJson(id: 1, nama: 'Master', kode: ' '),
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('SidebarTreeApiModel.fromJson', () {
    test('rejects missing sidebar object', () {
      expect(
        () => SidebarTreeApiModel.fromJson({'childs': []}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

Map<String, dynamic> _sidebarJson({
  required int id,
  required String nama,
  required String kode,
}) => {
  'id': id,
  'sidebar_parent_id': null,
  'sidebar_nama': nama,
  'sidebar_route': '/$kode',
  'sidebar_kode': kode,
  'sidebar_icon': 'folder',
  'sidebar_index': id,
  'created_by': null,
  'updated_by': null,
  'created_at': null,
  'updated_at': null,
  'status': 1,
};

SidebarApiService _service(_FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
  dio.httpClientAdapter = adapter;
  return SidebarApiService(dio);
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
