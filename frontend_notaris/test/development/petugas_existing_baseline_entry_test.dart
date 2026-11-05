import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart' hide Fake;
import 'package:path/path.dart' as p;

import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/repositories/petugas_baseline_pull.dart';

import '../../tool/petugas_existing_baseline_entry.dart' as entry;
import '../repositories/petugas_baseline_pull_test.dart' show event;
import '../repositories/petugas_local_sync_test.dart' show Fake, reply;

void main() {
  late Directory temp;
  late File file;
  late Dio dio;
  late Map<String, dynamic> preparation;
  late List<Map<String, dynamic>> events;
  late List<int> cursors;
  late Future<ResponseBody> Function(RequestOptions) respond;

  Future<Map<String, dynamic>> run({bool apply = false, String? confirm}) =>
      entry.runExistingPetugasBaseline(
        preparation: preparation,
        expectedTarget: file,
        dio: dio,
        token: 'fixture-token',
        apply: apply,
        confirmTarget: confirm,
      );

  setUp(() async {
    final created = await Directory.systemTemp.createTemp(
      'petugas-existing-entry-fixture-',
    );
    temp = Directory(await created.resolveSymbolicLinks());
    file = File(p.join(temp.path, 'notarisdev', 'a' * 32, 'offline.sqlite'));
    await file.parent.create(recursive: true);
    final db = AppDatabase.forIsolatedPetugasPull(file);
    await db
        .into(db.jenisKelamins)
        .insert(
          JenisKelaminsCompanion.insert(
            uuid: 'notarisdev-smoke-gender-11',
            nama: 'Explicit fixture',
            isSyncDirty: const Value(false),
          ),
        );
    for (var i = 0; i < 20; i++) {
      await db
          .into(db.pemohons)
          .insert(
            PemohonsCompanion.insert(
              uuid: 'fixture-pemohon-$i',
              nama: 'Fixture $i',
              isSyncDirty: const Value(false),
            ),
          );
    }
    await db.close();
    final backup = await file.copy(p.join(temp.path, 'backup.sqlite'));
    final context = PetugasBaselineContext(
      generation: 'a' * 32,
      accountId: 2001,
      deviceId: 'ndpetugas-fixture-stable',
      databasePath: file.path,
    );
    preparation = {
      'kind': 'existing-petugas-baseline-v1',
      'source_unchanged': true,
      'database_path': file.path,
      'account_id': 2001,
      'group_id': 11,
      'generation': 'a' * 32,
      'device_id': context.deviceId,
      'scope': context.scope,
      'source': {'sha256': entry.fileDigest(file)},
      'backup': {
        'path': backup.path,
        'sha256': entry.fileDigest(backup),
        'verified_reopened': true,
      },
      'inventory': {
        'version': 13,
        'counts': {'pemohons': 20, 'petugas': 0, 'petugas_sync_feed': 0},
        'genders': [
          {
            'id': 1,
            'uuid': 'notarisdev-smoke-gender-11',
            'status': 1,
            'dirty': 0,
            'deleted': null,
          },
        ],
      },
    };
    events = List.generate(4, (i) {
      final value = event(i);
      value['payload'] = <String, dynamic>{
        ...Map<String, dynamic>.from(value['payload'] as Map),
        'jenis_kelamin_id': 11,
      };
      // Match the real Go omitempty response for a NULL user reference.
      (value['payload'] as Map).remove('user_id');
      return value;
    });
    cursors = [];
    respond = (request) async {
      if (request.path == '/petugas/references/jenis-kelamin') {
        return reply({
          'success': true,
          'data': {
            'items': [
              {'id': 11, 'nama': 'Display only', 'status': 1},
            ],
          },
        });
      }
      final cursor = request.queryParameters['cursor'] as int;
      cursors.add(cursor);
      final changes = events.skip(cursor).take(2).toList();
      final next = changes.isEmpty
          ? cursor
          : changes.last['publication_sequence'];
      return reply({
        'success': true,
        'data': {
          'changes': changes,
          'next_cursor': next,
          'has_more': (next as int) < 4,
        },
      });
    };
    dio = Dio(BaseOptions(baseUrl: PetugasBaselineContext.apiBase.toString()));
    dio.httpClientAdapter = Fake((request) async {
      expect(request.method, 'GET');
      expect(request.headers['Authorization'], 'Bearer fixture-token');
      return respond(request);
    });
  });
  tearDown(() async {
    dio.close(force: true);
    expect(
      p.basename(temp.path).startsWith('petugas-existing-entry-fixture-'),
      true,
    );
    await temp.delete(recursive: true);
  });

  test(
    'default dry-run leaves existing SQLite bytes and cursor unbound',
    () async {
      final before = entry.fileDigest(file);
      final result = await run();
      expect(result['status'], 'dry_run_ready_awaiting_approval');
      expect(result['applied'], false);
      expect(cursors, [0, 2, 4]);
      expect(entry.fileDigest(file), before);
      final db = AppDatabase.forIsolatedPetugasPull(file);
      expect(await db.select(db.petugasLocals).get(), isEmpty);
      expect(
        await db.customSelect('SELECT * FROM petugas_sync_feed').get(),
        isEmpty,
      );
      expect((await db.select(db.pemohons).get()).length, 20);
      await db.close();
    },
  );

  test(
    'explicit fixture apply preserves Pemohon and reuses local gender UUID',
    () async {
      final result = await run(apply: true, confirm: file.path);
      expect(result['cursor_after_reopen'], 4);
      expect(cursors, [0, 2, 4, 0, 2]);
      final db = AppDatabase.forIsolatedPetugasPull(file);
      expect((await db.select(db.pemohons).get()).map((r) => r.uuid).toSet(), {
        for (var i = 0; i < 20; i++) 'fixture-pemohon-$i',
      });
      expect(
        (await db.select(db.jenisKelamins).get()).single.uuid,
        'notarisdev-smoke-gender-11',
      );
      expect(
        (await db.select(db.petugasLocals).get()).every(
          (r) => r.jenisKelamin == 1 && r.userId == null,
        ),
        true,
      );
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      await db.close();
    },
  );

  test('apply without exact target fails before GET or SQLite write', () async {
    await expectLater(run(apply: true), throwsStateError);
    expect(cursors, isEmpty);
    expect(entry.fileDigest(file), (preparation['source'] as Map)['sha256']);
  });

  test('scope switch and changed backup stop before any GET', () async {
    preparation['scope'] = 'another-owner';
    await expectLater(run(), throwsStateError);
    expect(cursors, isEmpty);
  });

  test('changed backup stops without touching source', () async {
    await File((preparation['backup'] as Map)['path'] as String)
        .writeAsString('changed');
    await expectLater(run(), throwsStateError);
    expect(cursors, isEmpty);
  });

  test(
    'explicit NULL user is equivalent to Go omitted nullable field',
    () async {
      for (final e in events) {
        (e['payload'] as Map)['user_id'] = null;
      }
      expect((await run())['applied'], false);
    },
  );

  test('non-null user or changed cloud UUID requires fresh review', () async {
    (events.first['payload'] as Map)['user_id'] = 2001;
    await expectLater(run(), throwsStateError);
    expect(entry.fileDigest(file), (preparation['source'] as Map)['sha256']);
  });

  test('GET-only interceptor refuses an accidental HTTP write', () async {
    await run();
    await expectLater(
      dio.post<Object?>('/petugas/sync/pull'),
      throwsA(isA<DioException>()),
    );
    expect(entry.fileDigest(file), (preparation['source'] as Map)['sha256']);
  });

  test(
    'second apply page failure preserves only committed prefix and Pemohon',
    () async {
      final page = respond;
      var secondCursor = 0;
      respond = (request) async {
        if (request.queryParameters['cursor'] == 2 && ++secondCursor == 2) {
          return ResponseBody.fromString(
            '{}',
            503,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        }
        return page(request);
      };
      await expectLater(
        run(apply: true, confirm: file.path),
        throwsA(anything),
      );
      final db = AppDatabase.forIsolatedPetugasPull(file);
      expect((await db.select(db.petugasLocals).get()).length, 2);
      expect(
        (await db
                .customSelect('SELECT cursor FROM petugas_sync_feed')
                .getSingle())
            .read<int>('cursor'),
        2,
      );
      expect((await db.select(db.pemohons).get()).length, 20);
      await db.close();
    },
  );
}
