import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart' hide Fake;
import 'package:frontend_notaris/services/petugas_reference_api.dart';

import '../repositories/petugas_local_sync_test.dart' show Fake, reply;

void main() {
  PetugasReferenceApi api(List<Object> rows) => PetugasReferenceApi(
    Dio()
      ..httpClientAdapter = Fake((req) async {
        expect(req.path, '/petugas/references/jenis-kelamin');
        return reply({
          'success': true,
          'data': {'items': rows},
        });
      }),
  );
  test(
    'catalog returns server ID and display label without automatic mapping',
    () async {
      final rows = await api([
        {'id': 77, 'nama': 'Display', 'status': 1},
      ]).genders();
      expect(rows.single.serverId, 77);
    },
  );
  test('unavailable catalog is empty', () async {
    expect(await api([]).genders(), isEmpty);
  });
  test('duplicate server identities are rejected as ambiguous', () async {
    await expectLater(
      api([
        {'id': 7, 'nama': 'A', 'status': 1},
        {'id': 7, 'nama': 'B', 'status': 1},
      ]).genders(),
      throwsFormatException,
    );
  });
}
