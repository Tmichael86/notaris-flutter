import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart' hide Fake;
import 'package:frontend_notaris/h01_acceptance_bootstrap.dart';

import '../repositories/petugas_local_sync_test.dart' show Fake, reply;

void main() {
  test('H01 transport logs attempts without secrets, binds target and refuses business GET/POST/PUT/PATCH/DELETE', () async {
    final folder = Directory.systemTemp.createTempSync('h01-transport-');
    final log = File('${folder.path}/trace.jsonl');
    final dio = h01ReadOnlyHttp(H01Trace(log));
    var calls = 0;
    dio.httpClientAdapter = Fake((r) async {
      calls++;
      expect(r.followRedirects, false);
      return reply({'success': true});
    });
    try {
      await dio.get('/auth/me/sidebar-access');
      await dio.post('/auth/login', data: {'password': 'do-not-log-password'});
      for (final method in ['GET', 'POST', 'PUT', 'PATCH', 'DELETE']) {
        await expectLater(
          dio.request(
            '/sync/push',
            data: {'secret': 'do-not-log-payload'},
            options: Options(
              method: method,
              headers: {'Authorization': 'do-not-log-token'},
            ),
          ),
          throwsA(isA<DioException>()),
        );
      }
      await expectLater(
        dio.get('http://127.0.0.1:8081/api/v1/profile'),
        throwsA(isA<DioException>()),
      );
      expect(calls, 2);
      final text = log.readAsStringSync();
      expect(text, isNot(contains('do-not-log')));
      final rows = text
          .trim()
          .split('\n')
          .map((l) => jsonDecode(l) as Map)
          .where((r) => r['event'] == 'http')
          .toList();
      expect(rows.length, 8);
      expect(rows.where((r) => r['allowed'] == false).length, 6);
    } finally {
      dio.close();
      folder.deleteSync(recursive: true);
    }
  });
  test(
    'invalid acceptance identity fails before normal database fallback',
    () async {
      await expectLater(
        h01AcceptanceApplication('../notarisdev', 'invalid', const SizedBox()),
        throwsA(anything),
      );
    },
  );
}
