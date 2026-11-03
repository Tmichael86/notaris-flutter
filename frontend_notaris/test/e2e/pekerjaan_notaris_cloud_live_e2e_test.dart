import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/repositories/pekerjaan_notaris_cloud_repository.dart';
import 'package:frontend_notaris/repositories/pekerjaan_repository.dart';

const categoryUuid = '00000000-0000-4000-8000-000000000011';

void main() {
  final url = Platform.environment['NOTARIS_NOTARIS_E2E_URL'];
  final token = Platform.environment['NOTARIS_NOTARIS_E2E_TOKEN'];
  if (url == null || token == null) {
    test(
      'Notaris cloud live E2E requires disposable opt-in',
      () {},
      skip: true,
    );
    return;
  }
  test(
    'Device A HTTP create, PostgreSQL publish, Device B HTTP pull',
    () async {
      final folder = await Directory.systemTemp.createTemp(
        'notaris-cloud-devices-',
      );
      addTearDown(() => folder.delete(recursive: true));
      final a = AppDatabase.forTesting(
        NativeDatabase(File('${folder.path}/a.sqlite')),
      );
      final b = AppDatabase.forTesting(
        NativeDatabase(File('${folder.path}/b.sqlite')),
      );
      addTearDown(a.close);
      addTearDown(b.close);
      for (final db in [a, b]) {
        await db.customStatement(
          "INSERT INTO pekerjaan_kategori(uuid,nama,status,is_sync_dirty) VALUES(?,'Category',1,0)",
          [categoryUuid],
        );
      }
      final id = await PekerjaanNotarisRepository(a.pekerjaanDao)
          .createAggregate(
            input: const PekerjaanAggregateInput(
              nama: 'E2E Notaris fixture',
              harga: [
                PekerjaanHargaInput(
                  harga: '100000',
                  kategoriPekerjaanId: 1,
                  estimasiWaktu: '2 hari',
                ),
              ],
              proses: [
                PekerjaanProsesInput(
                  nama: 'Periksa',
                  detail: 'Fixture',
                  atribut: [PekerjaanAtributInput(atribut: 'KTP')],
                ),
              ],
            ),
          );
      final dio = Dio(
        BaseOptions(baseUrl: url, headers: {'Authorization': 'Bearer $token'}),
      );
      final sender = PekerjaanNotarisCloudRepository(
        a,
        dio,
        scope: 'disposable-shared-v1',
      );
      final receiver = PekerjaanNotarisCloudRepository(
        b,
        dio,
        scope: 'disposable-shared-v1',
      );
      final ack = await sender.pushCreate(id);
      expect(ack['revision'], 1);
      final pending = await a
          .customSelect('SELECT payload FROM pekerjaan_notaris_sync_pending')
          .getSingle();
      final payload =
          jsonDecode(pending.read<String>('payload')) as Map<String, dynamic>;
      final retry = await dio.post<Map<String, dynamic>>(
        '/pekerjaan-notaris/sync/create',
        data: payload,
      );
      expect(
        (retry.data!['acknowledgement'] as Map)['server_id'],
        ack['server_id'],
      );
      final reuse = Map<String, dynamic>.from(payload)..['nama'] = 'Different';
      await expectLater(
        dio.post('/pekerjaan-notaris/sync/create', data: reuse),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            409,
          ),
        ),
      );
      final invalid = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
      invalid['mutation_id'] = '00000000-0000-4000-8000-000000000701';
      invalid['uuid'] = '00000000-0000-4000-8000-000000000702';
      (invalid['harga'] as List).first['uuid'] =
          '00000000-0000-4000-8000-000000000703';
      (invalid['harga'] as List).first['category_uuid'] =
          '00000000-0000-4000-8000-000000000799';
      await expectLater(
        dio.post('/pekerjaan-notaris/sync/create', data: invalid),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            422,
          ),
        ),
      );
      invalid['mutation_id'] = '00000000-0000-4000-8000-000000000704';
      invalid['uuid'] = '00000000-0000-4000-8000-000000000705';
      (invalid['harga'] as List).first['category_uuid'] = categoryUuid;
      (invalid['harga'] as List).first['harga'] = 'fail';
      await expectLater(
        dio.post('/pekerjaan-notaris/sync/create', data: invalid),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            500,
          ),
        ),
      );
      final published = await dio.post<Map<String, dynamic>>(
        '/pekerjaan-notaris/testing/publish',
      );
      expect(published.data!['published'], 1);
      expect(await receiver.pullPage(), 1);
      final received = (await b.pekerjaanDao.getPekerjaanNotaris()).single;
      expect(received.uuid, ack['uuid']);
      expect(received.isSyncDirty, false);
      expect(
        (await b.pekerjaanDao.getHargaNotaris(received.id)).single.harga,
        '100000',
      );
      final process = (await b.pekerjaanDao.getProsesNotaris(received.id))
          .single;
      expect(
        (await b.pekerjaanDao.getAtributNotaris(process.id)).single.atribut,
        'KTP',
      );
      await b.customStatement(
        "UPDATE pekerjaan_notaris_sync_feed SET cursor=0 WHERE scope='disposable-shared-v1'",
      );
      expect(await receiver.pullPage(), 1);
      expect(await b.pekerjaanDao.getPekerjaanNotaris(), hasLength(1));
      expect(await b.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      expect(
        (await b.customSelect('PRAGMA integrity_check').getSingle())
            .read<String>('integrity_check'),
        'ok',
      );
      await a.close();
      await b.close();
      final restart = AppDatabase.forTesting(
        NativeDatabase(File('${folder.path}/b.sqlite')),
      );
      expect(
        (await restart.pekerjaanDao.getPekerjaanNotaris()).single.uuid,
        ack['uuid'],
      );
      expect(
        (await restart
                .customSelect('SELECT cursor FROM pekerjaan_notaris_sync_feed')
                .getSingle())
            .read<int>('cursor'),
        1,
      );
      await restart.close();
    },
  );
}
