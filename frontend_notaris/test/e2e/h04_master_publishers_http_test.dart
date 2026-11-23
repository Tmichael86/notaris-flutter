import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/models/auth_session.dart';
import 'package:frontend_notaris/repositories/pekerjaan_kategori_repository.dart';
import 'package:frontend_notaris/repositories/pengeluaran_jenis_repository.dart';
import 'package:frontend_notaris/repositories/people_repository.dart';
import 'package:frontend_notaris/services/jenis_pengeluaran_api_service.dart';
import 'package:frontend_notaris/services/kategori_pekerjaan_api_service.dart';
import 'package:frontend_notaris/services/pemohon_api_service.dart';

import '../support/local_master_test_authority.dart';

void main() {
  final url = Platform.environment['NOTARIS_H04_HTTP'];
  final token = Platform.environment['NOTARIS_H04_TOKEN'];
  for (final module in ['category', 'expenseType', 'applicant']) {
    test(
      'H04 $module real selective publisher: lost ACK, retry, update',
      () async {
        final target = Uri.parse(url!);
        expect(target.scheme, 'http');
        expect(target.host, '127.0.0.1');
        expect(target.port, isNot(anyOf(8080, 8081, 5432)));
        expect(target.path, '/api/v1');
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final session = AuthSession(
          token: token!,
          userId: 1,
          groupId: 1,
          userName: 'H04 isolated',
          groupName: 'H04 isolated',
          user: const {},
          sidebars: masterTestSession().sidebars,
          verifiedAt: DateTime.now(),
        );
        final authority = masterTestAuthority(db, session: () => session);
        final dio = Dio(
          BaseOptions(
            baseUrl: url,
            headers: {'Authorization': 'Bearer $token'},
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        );
        addTearDown(() => dio.close(force: true));
        var loseFirstAck = true;
        var writes = 0;
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.method == 'PUT') writes++;
              handler.next(options);
            },
            onResponse: (response, handler) {
              if (loseFirstAck && response.requestOptions.method == 'PUT') {
                loseFirstAck = false;
                handler.reject(
                  DioException(
                    requestOptions: response.requestOptions,
                    type: DioExceptionType.connectionError,
                    message: 'Disposable test: committed response intentionally lost',
                  ),
                );
              } else {
                handler.next(response);
              }
            },
          ),
        );
        late Future<void> Function() push;
        late Future<void> Function() edit;
        late Future<bool> Function() dirty;
        late Future<String> Function() uuid;
        late Future<List<dynamic>> Function() remote;
        if (module == 'category') {
          final repo = PekerjaanKategoriRepository(
            db,
            authorization: authority,
          );
          final api = KategoriPekerjaanApiService(dio);
          final id = await repo.create(nama: 'H04 category');
          push = () async {
            await repo.syncToCloud(api);
          };
          edit = () async {
            await repo.update(id: id, nama: 'H04 category updated');
          };
          dirty = () async => (await repo.watchAll().first).single.isSyncDirty;
          uuid = () async => (await repo.watchAll().first).single.uuid;
          remote = api.getAll;
        } else if (module == 'expenseType') {
          final repo = PengeluaranJenisRepository(db, authorization: authority);
          final api = JenisPengeluaranApiService(dio);
          final id = await repo.create(nama: 'H04 expense type');
          push = () async {
            await repo.syncToCloud(api);
          };
          edit = () async {
            await repo.update(id: id, nama: 'H04 expense type updated');
          };
          dirty = () async => (await repo.watchAll().first).single.isSyncDirty;
          uuid = () async => (await repo.watchAll().first).single.uuid;
          remote = api.getAll;
        } else {
          final repo = PemohonRepository(db, authorization: authority);
          final api = PemohonApiService(dio);
          final id = await repo.create(
            nama: 'H04 applicant',
            nik: '1122334455667788',
          );
          push = () => repo.syncToCloud(api);
          edit = () async {
            await repo.update(
              id: id,
              nama: 'H04 applicant updated',
              nik: '1122334455667788',
            );
          };
          dirty = () async => (await repo.watchAll().first).single.isSyncDirty;
          uuid = () async => (await repo.watchAll().first).single.uuid;
          remote = api.getAll;
        }
        final originalUUID = await uuid();
        await expectLater(push(), throwsA(isA<DioException>()));
        expect(
          await dirty(),
          isTrue,
        ); // Failed/lost ACK cannot clear pending data.
        await push();
        expect(await dirty(), isFalse);
        expect(await uuid(), originalUUID);
        await edit();
        expect(await dirty(), isTrue);
        await push();
        expect(await dirty(), isFalse);
        await push(); // Clean publisher must not silently send another mutation.
        expect(writes, 3);
        final rows = await remote();
        expect(rows, hasLength(1));
        expect(rows.single.uuid, originalUUID);
        expect(rows.single.nama, endsWith('updated'));
        expect(
          (await db.customSelect('PRAGMA integrity_check').get())
              .single
              .data
              .values
              .single,
          'ok',
        );
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      },
      skip: url == null || token == null
          ? 'Owned H04 Go HTTP harness required'
          : false,
    );
  }
}
