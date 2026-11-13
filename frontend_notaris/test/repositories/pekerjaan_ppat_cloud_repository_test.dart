import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/repositories/pekerjaan_ppat_cloud_repository.dart';
import 'package:frontend_notaris/repositories/pekerjaan_repository.dart';

const categoryUUID = '00000000-0000-4000-8000-000000000011';

Future<void> category(AppDatabase db) => db.customStatement(
  "INSERT INTO pekerjaan_kategori(uuid,nama,status,is_sync_dirty) VALUES(?,'Synthetic Category',1,0)",
  [categoryUUID],
);

void main() {
  test(
    'Device A create, Device B apply and replay are atomic and scoped',
    () async {
      final folder = await Directory.systemTemp.createTemp(
        'ppat-cloud-sqlite-',
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
      await category(a);
      await category(b);
      final localId = await PekerjaanPpatRepository(a.pekerjaanDao)
          .createAggregate(
            input: const PekerjaanAggregateInput(
              nama: 'Cloud fixture',
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
      Map<String, dynamic>? published;
      var posts = 0;
      final dio = Dio(BaseOptions(baseUrl: 'http://example.invalid/api/v1'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            if (request.method == 'POST') {
              posts++;
              published = Map<String, dynamic>.from(request.data as Map);
              handler.resolve(
                Response(
                  requestOptions: request,
                  statusCode: 200,
                  data: {
                    'acknowledgement': {
                      'mutation_id': published!['mutation_id'],
                      'uuid': published!['uuid'],
                      'revision': 1,
                      'server_id': 100,
                    },
                  },
                ),
              );
            } else {
              handler.resolve(
                Response(
                  requestOptions: request,
                  statusCode: 200,
                  data: {
                    'changes': [
                      {'sequence': 1, 'revision': 1, 'aggregate': published},
                    ],
                    'next_cursor': 1,
                    'has_more': false,
                  },
                ),
              );
            }
          },
        ),
      );
      final sender = PekerjaanPpatCloudRepository(a, dio, scope: 'test-scope');
      final receiver = PekerjaanPpatCloudRepository(
        b,
        dio,
        scope: 'test-scope',
      );
      final ack = await sender.pushCreate(localId);
      expect(ack['revision'], 1);
      expect(
        (await a.pekerjaanDao.getPekerjaanPpatById(localId))!.isSyncDirty,
        false,
      );
      expect(posts, 1);
      expect(
        (published!['harga'] as List).single['category_uuid'],
        categoryUUID,
      );
      expect(
        (published!['proses'] as List).single['atribut'][0]['atribut'],
        'KTP',
      );
      expect(await receiver.pullPage(), 1);
      final received = (await b.pekerjaanDao.getPekerjaanPpat()).single;
      expect(received.uuid, published!['uuid']);
      expect(received.isSyncDirty, false);
      expect(
        (await b.pekerjaanDao.getHargaPpat(received.id)).single.harga,
        '100000',
      );
      final process = (await b.pekerjaanDao.getProsesPpat(received.id)).single;
      expect(
        (await b.pekerjaanDao.getAtributPpat(process.id)).single.atribut,
        'KTP',
      );
      await b.customStatement(
        "UPDATE pekerjaan_ppat_sync_feed SET cursor=0 WHERE scope='test-scope'",
      );
      expect(await receiver.pullPage(), 1);
      expect(await b.pekerjaanDao.getPekerjaanPpat(), hasLength(1));
      expect(await b.customSelect('PRAGMA integrity_check').get(), isNotEmpty);
      expect(await b.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      await expectLater(sender.pushCreate(localId), throwsStateError);
      await a.close();
      await b.close();
      final reopened = AppDatabase.forTesting(
        NativeDatabase(File('${folder.path}/b.sqlite')),
      );
      expect(
        (await reopened.pekerjaanDao.getPekerjaanPpat()).single.uuid,
        published!['uuid'],
      );
      expect(
        (await reopened
                .customSelect('SELECT cursor FROM pekerjaan_ppat_sync_feed')
                .getSingle())
            .read<int>('cursor'),
        1,
      );
      await reopened.close();
    },
  );

  test(
    'missing category rolls back entire page and preserves cursor',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final dio = Dio(BaseOptions(baseUrl: 'http://example.invalid/api/v1'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) => handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 200,
              data: {
                'changes': [
                  {
                    'sequence': 1,
                    'revision': 1,
                    'aggregate': {
                      'uuid': '00000000-0000-4000-8000-000000000201',
                      'nama': 'Fixture',
                      'harga': [
                        {
                          'uuid': '00000000-0000-4000-8000-000000000301',
                          'category_uuid': categoryUUID,
                          'harga': '100',
                          'estimasi_waktu': '1 hari',
                        },
                      ],
                      'proses': [
                        {
                          'uuid': '00000000-0000-4000-8000-000000000401',
                          'nama': 'Check',
                          'detail': 'Fixture',
                          'atribut': [],
                        },
                      ],
                    },
                  },
                ],
                'next_cursor': 1,
                'has_more': false,
              },
            ),
          ),
        ),
      );
      final receiver = PekerjaanPpatCloudRepository(
        db,
        dio,
        scope: 'test-scope',
      );
      await expectLater(receiver.pullPage(), throwsStateError);
      expect(await db.pekerjaanDao.getPekerjaanPpat(), isEmpty);
      expect(
        (await db
                .customSelect('SELECT cursor FROM pekerjaan_ppat_sync_feed')
                .getSingle())
            .read<int>('cursor'),
        0,
      );
      await category(db);
      await db.customStatement(
        "INSERT INTO pekerjaan_ppat(uuid,nama,is_sync_dirty) VALUES('00000000-0000-4000-8000-000000000201','Local dirty',1)",
      );
      await expectLater(receiver.pullPage(), throwsStateError);
      expect(
        (await db.pekerjaanDao.getPekerjaanPpat()).single.nama,
        'Local dirty',
      );
      expect(
        (await db
                .customSelect('SELECT cursor FROM pekerjaan_ppat_sync_feed')
                .getSingle())
            .read<int>('cursor'),
        0,
      );
    },
  );

  test(
    'edit during in-flight CREATE stays dirty after acknowledgement',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await category(db);
      final id = await PekerjaanPpatRepository(db.pekerjaanDao).createAggregate(
        input: const PekerjaanAggregateInput(
          nama: 'Original',
          harga: [
            PekerjaanHargaInput(
              harga: '100',
              kategoriPekerjaanId: 1,
              estimasiWaktu: '1 hari',
            ),
          ],
          proses: [PekerjaanProsesInput(nama: 'Periksa', detail: 'Fixture')],
        ),
      );
      final dio = Dio(BaseOptions(baseUrl: 'http://example.invalid/api/v1'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) async {
            await db.customStatement(
              "UPDATE pekerjaan_ppat SET nama='Edited',is_sync_dirty=1 WHERE id=?",
              [id],
            );
            final payload = request.data as Map;
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: {
                  'acknowledgement': {
                    'mutation_id': payload['mutation_id'],
                    'uuid': payload['uuid'],
                    'revision': 1,
                    'server_id': 1,
                  },
                },
              ),
            );
          },
        ),
      );
      await PekerjaanPpatCloudRepository(
        db,
        dio,
        scope: 'test-scope',
      ).pushCreate(id);
      final parent = (await db.pekerjaanDao.getPekerjaanPpat()).single;
      expect(parent.nama, 'Edited');
      expect(parent.isSyncDirty, true);
      expect(
        (await db
                .customSelect('SELECT state FROM pekerjaan_ppat_sync_pending')
                .getSingle())
            .read<String>('state'),
        'acked',
      );
    },
  );

  test(
    'UPDATE 409 keeps the durable pending mutation and local edit',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await category(db);
      final id = await PekerjaanPpatRepository(db.pekerjaanDao).createAggregate(
        input: const PekerjaanAggregateInput(
          nama: 'Original',
          harga: [
            PekerjaanHargaInput(
              harga: '100',
              kategoriPekerjaanId: 1,
              estimasiWaktu: '1 hari',
            ),
          ],
          proses: [PekerjaanProsesInput(nama: 'Periksa', detail: 'Fixture')],
        ),
      );
      final dio = Dio(BaseOptions(baseUrl: 'http://example.invalid/api/v1'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            if (request.path.endsWith('/update')) {
              handler.reject(
                DioException(
                  requestOptions: request,
                  response: Response(
                    requestOptions: request,
                    statusCode: 409,
                    data: {'code': 'revision_conflict'},
                  ),
                ),
              );
            } else {
              final payload = request.data as Map;
              handler.resolve(
                Response(
                  requestOptions: request,
                  statusCode: 200,
                  data: {
                    'acknowledgement': {
                      'mutation_id': payload['mutation_id'],
                      'uuid': payload['uuid'],
                      'revision': 1,
                      'server_id': 100,
                    },
                  },
                ),
              );
            }
          },
        ),
      );
      final cloud = PekerjaanPpatCloudRepository(db, dio, scope: 'test-scope');
      await cloud.pushCreate(id);
      await PekerjaanPpatRepository(db.pekerjaanDao)
          .updateNama(id: id, nama: 'Unsent edit');
      await expectLater(
        cloud.pushUpdate(id),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            409,
          ),
        ),
      );
      final saved = await db
          .customSelect('SELECT payload,state FROM pekerjaan_ppat_sync_pending')
          .getSingle();
      expect(saved.read<String>('state'), 'pending');
      expect(saved.read<String>('payload'), contains('Unsent edit'));
      final parent = (await db.pekerjaanDao.getPekerjaanPpat()).single;
      expect(parent.nama, 'Unsent edit');
      expect(parent.isSyncDirty, isTrue);
      expect(
        (await db
                .customSelect(
                  'SELECT revision FROM pekerjaan_ppat_sync_identity',
                )
                .getSingle())
            .read<int>('revision'),
        1,
      );
    },
  );
}
