import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/repositories/pekerjaan_ppat_cloud_repository.dart';
import 'package:frontend_notaris/repositories/pekerjaan_repository.dart';

const categoryUuid = '00000000-0000-4000-8000-000000000011';

void main() {
  final url = Platform.environment['NOTARIS_PPAT_E2E_URL'];
  final token = Platform.environment['NOTARIS_PPAT_E2E_TOKEN'];
  if (url == null || token == null) {
    test('Ppat cloud live E2E requires disposable opt-in', () {}, skip: true);
    return;
  }
  test(
    'Device A create, update, delete through HTTP publication to Device B',
    () async {
      final folder = await Directory.systemTemp.createTemp(
        'ppat-cloud-devices-',
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
      final id = await PekerjaanPpatRepository(a.pekerjaanDao).createAggregate(
        input: const PekerjaanAggregateInput(
          nama: 'E2E Ppat fixture',
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
      final sender = PekerjaanPpatCloudRepository(
        a,
        dio,
        scope: 'disposable-shared-v1',
      );
      final receiver = PekerjaanPpatCloudRepository(
        b,
        dio,
        scope: 'disposable-shared-v1',
      );
      final ack = await sender.pushCreate(id);
      expect(ack['revision'], 1);
      final pending = await a
          .customSelect('SELECT payload FROM pekerjaan_ppat_sync_pending')
          .getSingle();
      final payload =
          jsonDecode(pending.read<String>('payload')) as Map<String, dynamic>;
      final retry = await dio.post<Map<String, dynamic>>(
        '/pekerjaan-ppat/sync/create',
        data: payload,
      );
      expect(
        (retry.data!['acknowledgement'] as Map)['server_id'],
        ack['server_id'],
      );
      final reuse = Map<String, dynamic>.from(payload)..['nama'] = 'Different';
      await expectLater(
        dio.post('/pekerjaan-ppat/sync/create', data: reuse),
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
        dio.post('/pekerjaan-ppat/sync/create', data: invalid),
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
        dio.post('/pekerjaan-ppat/sync/create', data: invalid),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            500,
          ),
        ),
      );
      final published = await dio.post<Map<String, dynamic>>(
        '/pekerjaan-ppat/testing/publish',
      );
      expect(published.data!['published'], 1);
      expect(await sender.pullPage(), 1);
      expect(await receiver.pullPage(), 1);
      final received = (await b.pekerjaanDao.getPekerjaanPpat()).single;
      expect(received.uuid, ack['uuid']);
      expect(received.isSyncDirty, false);
      // The same UUID and name in the other domain must remain independent.
      await b.customStatement(
        'INSERT INTO pekerjaan_notaris(uuid,nama,is_sync_dirty) VALUES(?,?,0)',
        [received.uuid, received.nama],
      );
      expect(
        (await b.pekerjaanDao.getHargaPpat(received.id)).single.harga,
        '100000',
      );
      final process = (await b.pekerjaanDao.getProsesPpat(received.id)).single;
      expect(
        (await b.pekerjaanDao.getAtributPpat(process.id)).single.atribut,
        'KTP',
      );
      final aHarga = (await a.pekerjaanDao.getHargaPpat(id)).single;
      final aProses = (await a.pekerjaanDao.getProsesPpat(id)).single;
      expect(
        await PekerjaanPpatRepository(a.pekerjaanDao).updateAggregate(
          id: id,
          input: PekerjaanAggregateInput(
            nama: 'E2E Ppat updated',
            harga: [
              PekerjaanHargaInput(
                id: aHarga.id,
                harga: '150000',
                kategoriPekerjaanId: 1,
                estimasiWaktu: '3 hari',
              ),
            ],
            proses: [
              PekerjaanProsesInput(
                id: aProses.id,
                nama: 'Periksa',
                detail: 'Updated',
                atribut: const [PekerjaanAtributInput(atribut: 'Akta')],
              ),
            ],
          ),
        ),
        isTrue,
      );
      final updatedAck = await sender.pushUpdate(id);
      expect(updatedAck['revision'], 2);
      final updatePayload = jsonDecode(
        (await a
                .customSelect('SELECT payload FROM pekerjaan_ppat_sync_pending')
                .getSingle())
            .read<String>('payload'),
      ) as Map<String, dynamic>;
      final updateRetry = await dio.post<Map<String, dynamic>>(
        '/pekerjaan-ppat/sync/update',
        data: updatePayload,
      );
      expect((updateRetry.data!['acknowledgement'] as Map)['revision'], 2);
      final changedUpdate = Map<String, dynamic>.from(updatePayload)
        ..['nama'] = 'Other';
      await expectLater(
        dio.post('/pekerjaan-ppat/sync/update', data: changedUpdate),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            409,
          ),
        ),
      );
      final stale = Map<String, dynamic>.from(updatePayload)
        ..['mutation_id'] = '00000000-0000-4000-8000-000000000781';
      await expectLater(
        dio.post('/pekerjaan-ppat/sync/update', data: stale),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            409,
          ),
        ),
      );
      expect(
        (await dio.post<Map<String, dynamic>>(
          '/pekerjaan-ppat/testing/publish',
        )).data!['published'],
        1,
      );
      expect(await sender.pullPage(), 2);
      expect(await receiver.pullPage(), 2);
      final updatedB = (await b.pekerjaanDao.getPekerjaanPpat()).single;
      expect(updatedB.nama, 'E2E Ppat updated');
      expect(
        (await b.pekerjaanDao.getHargaPpat(updatedB.id)).single.uuid,
        aHarga.uuid,
      );
      expect(
        (await b.pekerjaanDao.getHargaPpat(updatedB.id)).single.harga,
        '150000',
      );
      final updatedProcess = (await b.pekerjaanDao.getProsesPpat(updatedB.id))
          .single;
      expect(updatedProcess.uuid, aProses.uuid);
      expect(
        (await b.pekerjaanDao.getAtributPpat(updatedProcess.id)).single.atribut,
        'Akta',
      );
      expect(
        (await b
                .customSelect(
                  'SELECT count(*) AS n FROM pekerjaan_ppat_atributs WHERE pekerjaan_ppat_id=? AND status=0',
                  variables: [Variable.withInt(updatedB.id)],
                )
                .getSingle())
            .read<int>('n'),
        1,
      );
      final invalidUpdate =
          jsonDecode(jsonEncode(updatePayload)) as Map<String, dynamic>;
      invalidUpdate['mutation_id'] = '00000000-0000-4000-8000-000000000782';
      invalidUpdate['expected_revision'] = 2;
      (invalidUpdate['harga'] as List).first['category_uuid'] =
          '00000000-0000-4000-8000-000000000799';
      await expectLater(
        dio.post('/pekerjaan-ppat/sync/update', data: invalidUpdate),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            422,
          ),
        ),
      );
      invalidUpdate['mutation_id'] = '00000000-0000-4000-8000-000000000783';
      (invalidUpdate['harga'] as List).first['category_uuid'] = categoryUuid;
      (invalidUpdate['harga'] as List).first['harga'] = 'fail';
      await expectLater(
        dio.post('/pekerjaan-ppat/sync/update', data: invalidUpdate),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            500,
          ),
        ),
      );
      expect(
        (await dio.post<Map<String, dynamic>>(
          '/pekerjaan-ppat/testing/publish',
        )).data!['published'],
        0,
      );
      expect(
        await PekerjaanPpatRepository(a.pekerjaanDao).deleteAggregate(id),
        isTrue,
      );
      final deletedAck = await sender.pushDelete(id);
      expect(deletedAck['revision'], 3);
      final deletePayload = jsonDecode(
        (await a
                .customSelect('SELECT payload FROM pekerjaan_ppat_sync_pending')
                .getSingle())
            .read<String>('payload'),
      ) as Map<String, dynamic>;
      deletePayload.remove('delete');
      final deleteRetry = await dio.post<Map<String, dynamic>>(
        '/pekerjaan-ppat/sync/delete',
        data: deletePayload,
      );
      expect((deleteRetry.data!['acknowledgement'] as Map)['revision'], 3);
      final changedDelete = Map<String, dynamic>.from(deletePayload)
        ..['expected_revision'] = 1;
      await expectLater(
        dio.post('/pekerjaan-ppat/sync/delete', data: changedDelete),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            409,
          ),
        ),
      );
      expect(
        (await dio.post<Map<String, dynamic>>(
          '/pekerjaan-ppat/testing/publish',
        )).data!['published'],
        1,
      );
      expect(await sender.pullPage(), 3);
      await b.customStatement(
        "UPDATE pekerjaan_ppat SET nama='Device B pending edit',is_sync_dirty=1 WHERE id=?",
        [updatedB.id],
      );
      await expectLater(receiver.pullPage(), throwsStateError);
      expect(
        (await b.pekerjaanDao.getPekerjaanPpat()).single.nama,
        'Device B pending edit',
      );
      expect(
        (await b
                .customSelect('SELECT cursor FROM pekerjaan_ppat_sync_feed')
                .getSingle())
            .read<int>('cursor'),
        2,
      );
      // Resolve the fixture edit explicitly; production never discards it.
      await b.customStatement(
        "UPDATE pekerjaan_ppat SET nama='E2E Ppat updated',is_sync_dirty=0 WHERE id=?",
        [updatedB.id],
      );
      expect(await receiver.pullPage(), 3);
      expect(await b.pekerjaanDao.getPekerjaanPpat(), isEmpty);
      expect(
        (await b.pekerjaanDao.getPekerjaanNotaris()).single.nama,
        'E2E Ppat fixture',
      );
      expect(
        await b.customSelect('SELECT * FROM pekerjaan_notaris_sync_feed').get(),
        isEmpty,
      );
      expect(
        (await b
                .customSelect(
                  'SELECT status FROM pekerjaan_ppat WHERE id=?',
                  variables: [Variable.withInt(updatedB.id)],
                )
                .getSingle())
            .read<int>('status'),
        0,
      );
      await b.customStatement(
        "UPDATE pekerjaan_ppat_sync_feed SET cursor=0 WHERE scope='disposable-shared-v1'",
      );
      expect(await receiver.pullPage(), 3);
      expect(await b.pekerjaanDao.getPekerjaanPpat(), isEmpty);
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
      expect(await restart.pekerjaanDao.getPekerjaanPpat(), isEmpty);
      expect(
        (await restart.pekerjaanDao.getPekerjaanNotaris()).single.uuid,
        ack['uuid'],
      );
      expect(
        (await restart
                .customSelect('SELECT cursor FROM pekerjaan_ppat_sync_feed')
                .getSingle())
            .read<int>('cursor'),
        3,
      );
      await restart.close();
    },
  );
}
