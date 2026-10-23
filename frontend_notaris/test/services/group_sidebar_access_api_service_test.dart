import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/services/group_sidebar_access_api_service.dart';

void main() {
  group('GroupSidebarAccessApiService', () {
    test('getByGroup parses sidebar permissions', () async {
      final service = _service(
        _FakeAdapter((request) {
          expect(request.method, 'GET');
          expect(request.path, '/groups/2/sidebar-access');
          return _jsonResponse({
            'success': true,
            'data': [
              {
                'sidebar_id': 5,
                'read': 1,
                'create': 0,
                'update': 1,
                'delete': 0,
                'sidebar': {
                  'id': 5,
                  'sidebar_parent_id': null,
                  'sidebar_nama': 'Pemohon',
                  'sidebar_route': '/pemohon',
                  'sidebar_kode': 'pemohon',
                  'sidebar_icon': 'users',
                  'sidebar_index': 3,
                  'status': 1,
                },
              },
            ],
          });
        }),
      );

      final result = await service.getByGroup(2);

      expect(result, hasLength(1));
      expect(result.single.sidebarId, 5);
      expect(result.single.read, 1);
      expect(result.single.create, 0);
      expect(result.single.sidebar.nama, 'Pemohon');
      expect(result.single.sidebar.kode, 'pemohon');
    });

    test('getByGroup rejects invalid response envelope', () async {
      final service = _service(
        _FakeAdapter((_) => _jsonResponse({'success': false, 'data': []})),
      );

      await expectLater(
        service.getByGroup(2),
        throwsA(isA<FormatException>()),
      );
    });

    test('replaceForGroup sends permissions in expected shape', () async {
      final service = _service(
        _FakeAdapter((request) {
          expect(request.method, 'PUT');
          expect(request.path, '/groups/2/sidebar-access');
          expect(_requestJson(request), {
            'access': [
              {
                'sidebar_id': 5,
                'read': 1,
                'create': 0,
                'update': 1,
                'delete': 0,
              },
            ],
          });
          return _jsonResponse({'success': true, 'data': null});
        }),
      );

      await expectLater(
        service.replaceForGroup(
          groupId: 2,
          access: [
            const GroupSidebarAccessInput(
              sidebarId: 5,
              read: 1,
              create: 0,
              update: 1,
              delete: 0,
            ),
          ],
        ),
        completes,
      );
    });

    test('replaceForGroup rejects duplicate sidebar IDs before request', () {
      final service = _service(
        _FakeAdapter((_) => fail('No request should be sent')),
      );

      expect(
        () => service.replaceForGroup(
          groupId: 2,
          access: [
            const GroupSidebarAccessInput(sidebarId: 5),
            const GroupSidebarAccessInput(sidebarId: 5),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('replaceForGroup rejects invalid permission flags before request', () {
      final service = _service(
        _FakeAdapter((_) => fail('No request should be sent')),
      );

      expect(
        () => service.replaceForGroup(
          groupId: 2,
          access: [
            const GroupSidebarAccessInput(sidebarId: 5, read: 2),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('replaceForGroup rejects failed response', () async {
      final service = _service(
        _FakeAdapter((_) => _jsonResponse({'success': false})),
      );

      await expectLater(
        service.replaceForGroup(
          groupId: 2,
          access: [const GroupSidebarAccessInput(sidebarId: 5)],
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

GroupSidebarAccessApiService _service(_FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
  dio.httpClientAdapter = adapter;
  return GroupSidebarAccessApiService(dio);
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
