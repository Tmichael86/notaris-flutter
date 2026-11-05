import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/repositories/pekerjaan_notaris_cloud_repository.dart';
import 'package:frontend_notaris/repositories/pekerjaan_ppat_cloud_repository.dart';
import 'package:frontend_notaris/repositories/pekerjaan_repository.dart';

void main() {
  final env = Platform.environment;
  final domain = env['MASTER_LIVE_DOMAIN'];
  if (!{'notaris', 'ppat'}.contains(domain) ||
      env['MASTER_LIVE_URL'] != 'http://127.0.0.1:8081/api/v1' ||
      env['MASTER_LIVE_CATEGORY_UUID'] !=
          'fa000002-0000-4000-8000-000000000001' ||
      env['MASTER_LIVE_TOKEN'] == null ||
      env['MASTER_LIVE_PUBLISH_EXE'] == null ||
      env['MASTER_LIVE_RECEIPT'] == null ||
      env['MASTER_LIVE_BASE_CURSOR'] == null) {
    test(
      'controlled live entry requires explicit private configuration',
      () {},
      skip: true,
    );
    return;
  }
  test('controlled $domain Device A → server → Device B', () async {
    final receipt = Directory(env['MASTER_LIVE_RECEIPT']!);
    final source = File('${receipt.path}/device-a.sqlite');
    final target = File('${receipt.path}/device-b.sqlite');
    final isNotaris = domain == 'notaris';
    if (isNotaris && (source.existsSync() || target.existsSync())) {
      throw StateError('Device files must be new before Notaris');
    }
    if (!isNotaris &&
        (!source.existsSync() ||
            !target.existsSync() ||
            !File('${receipt.path}/notaris-result.json').existsSync())) {
      throw StateError('Verified Notaris device checkpoint required');
    }
    final baseCursor = int.parse(env['MASTER_LIVE_BASE_CURSOR']!);
    final scope =
        'notarisdev-controlled-${receipt.uri.pathSegments.where((e) => e.isNotEmpty).last}';
    final state = <String, dynamic>{
      'domain': domain,
      'scope': scope,
      'base_cursor': baseCursor,
      'phase': 'opening_disposable_devices',
    };
    final resultFile = File('${receipt.path}/$domain-result.json');
    Future<void> record(
      String phase, [
      Map<String, dynamic> extra = const {},
    ]) async {
      state['phase'] = phase;
      state.addAll(extra);
      await resultFile.writeAsString(jsonEncode(state));
    }

    final a = AppDatabase.forTesting(NativeDatabase(source));
    final b = AppDatabase.forTesting(NativeDatabase(target));
    addTearDown(a.close);
    addTearDown(b.close);
    for (final db in [a, b]) {
      await db.customStatement(
        "INSERT OR IGNORE INTO pekerjaan_kategori(uuid,nama,status,is_sync_dirty) VALUES(?,'Verified server category',1,0)",
        [env['MASTER_LIVE_CATEGORY_UUID']],
      );
    }
    final category = await a
        .customSelect(
          'SELECT id FROM pekerjaan_kategori WHERE uuid=? AND status=1 AND is_sync_dirty=0',
          variables: [Variable.withString(env['MASTER_LIVE_CATEGORY_UUID']!)],
        )
        .get();
    if (category.length != 1) throw StateError('Verified category missing');
    final categoryId = category.single.read<int>('id');
    final dio = Dio(
      BaseOptions(
        baseUrl: env['MASTER_LIVE_URL']!,
        headers: {'Authorization': 'Bearer ${env['MASTER_LIVE_TOKEN']}'},
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    final notarisA = PekerjaanNotarisCloudRepository(a, dio, scope: scope);
    final notarisB = PekerjaanNotarisCloudRepository(b, dio, scope: scope);
    final ppatA = PekerjaanPpatCloudRepository(a, dio, scope: scope);
    final ppatB = PekerjaanPpatCloudRepository(b, dio, scope: scope);
    final name =
        'E2E-MASTER-${domain!.toUpperCase()}-${receipt.uri.pathSegments.where((e) => e.isNotEmpty).last}';
    final input = PekerjaanAggregateInput(
      nama: name,
      harga: [
        PekerjaanHargaInput(
          harga: '100000',
          kategoriPekerjaanId: categoryId,
          estimasiWaktu: '2 hari',
        ),
      ],
      proses: const [
        PekerjaanProsesInput(
          nama: 'Periksa',
          detail: 'Synthetic E2E',
          atribut: [PekerjaanAtributInput(atribut: 'KTP')],
        ),
      ],
    );
    final localId = isNotaris
        ? await PekerjaanNotarisRepository(a.pekerjaanDao)
              .createAggregate(input: input)
        : await PekerjaanPpatRepository(a.pekerjaanDao)
              .createAggregate(input: input);
    final parentA = isNotaris
        ? await a.pekerjaanDao.getPekerjaanNotarisById(localId)
        : await a.pekerjaanDao.getPekerjaanPpatById(localId);
    final uuid = (parentA as dynamic).uuid as String;
    final hargaA = isNotaris
        ? (await a.pekerjaanDao.getHargaNotaris(localId)).single
        : (await a.pekerjaanDao.getHargaPpat(localId)).single;
    final prosesA = isNotaris
        ? (await a.pekerjaanDao.getProsesNotaris(localId)).single
        : (await a.pekerjaanDao.getProsesPpat(localId)).single;
    await record('local_create_ready', {
      'aggregate_uuid': uuid,
      'local_id': localId,
      'harga_uuid': (hargaA as dynamic).uuid,
      'proses_uuid': (prosesA as dynamic).uuid,
    });
    for (final db in [a, b]) {
      await db.customStatement(
        'INSERT INTO pekerjaan_${domain}_sync_feed(scope,cursor) VALUES(?,?)',
        [scope, baseCursor],
      );
    }
    Future<Map<String, dynamic>> push(String operation) async {
      await record('${operation}_http_started');
      final ack = operation == 'create'
          ? (isNotaris
                ? await notarisA.pushCreate(localId)
                : await ppatA.pushCreate(localId))
          : operation == 'update'
          ? (isNotaris
                ? await notarisA.pushUpdate(localId)
                : await ppatA.pushUpdate(localId))
          : (isNotaris
                ? await notarisA.pushDelete(localId)
                : await ppatA.pushDelete(localId));
      final mutationIds = (state['mutation_ids'] as List?) ?? <String>[];
      mutationIds.add(ack['mutation_id'] as String);
      await record('${operation}_http_acknowledged', {
        'server_id': ack['server_id'],
        'mutation_ids': mutationIds,
        'revision': ack['revision'],
      });
      return ack;
    }

    Future<void> publish(String operation, int revision) async {
      await record('${operation}_publish_started');
      final result = await Process.run(env['MASTER_LIVE_PUBLISH_EXE']!, [
        '--apply',
        '--live-approved',
        '--confirm-target',
        '127.0.0.1:5432/notarisdev',
        '--domain',
        domain,
        '--batch-size',
        '1',
        '--max-batches',
        '1',
        '--timeout',
        '60s',
        '--only-uuid',
        uuid,
        '--expected-operation',
        operation,
        '--expected-revision',
        '$revision',
      ]);
      if (result.exitCode != 0) {
        throw StateError('Publisher stopped; inspect database read-only');
      }
      final published =
          jsonDecode((result.stdout as String).trim()) as Map<String, dynamic>;
      if (published['published'] != 1 ||
          published['aggregate_uuid'] != uuid ||
          published['operation'] != operation ||
          published['revision'] != revision ||
          published['last_seq'] != baseCursor + revision) {
        throw StateError('Publisher receipt mismatch; inspect read-only');
      }
      await File('${receipt.path}/$domain-publish-$operation.json')
          .writeAsString(jsonEncode(published));
      await record('${operation}_published', {
        'last_seq': published['last_seq'],
      });
    }

    Future<void> pull(int revision) async {
      final sourceCursor = isNotaris
          ? await notarisA.pullPage(limit: 1)
          : await ppatA.pullPage(limit: 1);
      final cursor = isNotaris
          ? await notarisB.pullPage(limit: 1)
          : await ppatB.pullPage(limit: 1);
      if (sourceCursor != baseCursor + revision ||
          cursor != baseCursor + revision) {
        throw StateError('Device A/B cursor mismatch');
      }
      await record('revision_${revision}_pulled', {
        'device_a_cursor': sourceCursor,
        'device_b_cursor': cursor,
      });
    }

    final create = await push('create');
    if (create['uuid'] != uuid || create['revision'] != 1) {
      throw StateError('CREATE acknowledgement mismatch');
    }
    final pendingPayload =
        (await a
                .customSelect(
                  'SELECT payload FROM pekerjaan_${domain}_sync_pending',
                )
                .getSingle())
            .read<String>('payload');
    final replay = await dio.post<Map<String, dynamic>>(
      '/pekerjaan-$domain/sync/create',
      data: jsonDecode(pendingPayload),
    );
    if ((replay.data!['acknowledgement'] as Map)['server_id'] !=
        create['server_id']) {
      throw StateError('CREATE mutation replay mismatch');
    }
    await record('create_replay_acknowledged');
    await publish('create', 1);
    await pull(1);
    final dynamic parentB = isNotaris
        ? (await b.pekerjaanDao.getPekerjaanNotaris()).single
        : (await b.pekerjaanDao.getPekerjaanPpat()).single;
    if ((parentB as dynamic).uuid != uuid || parentB.nama != name) {
      throw StateError('Device B CREATE mismatch');
    }
    final updated = PekerjaanAggregateInput(
      nama: '$name-UPDATED',
      harga: [
        PekerjaanHargaInput(
          id: (hargaA as dynamic).id,
          harga: '150000',
          kategoriPekerjaanId: categoryId,
          estimasiWaktu: '3 hari',
        ),
      ],
      proses: [
        PekerjaanProsesInput(
          id: (prosesA as dynamic).id,
          nama: 'Periksa',
          detail: 'Updated synthetic E2E',
          atribut: const [PekerjaanAtributInput(atribut: 'Akta')],
        ),
      ],
    );
    final didUpdate = isNotaris
        ? await PekerjaanNotarisRepository(a.pekerjaanDao)
              .updateAggregate(id: localId, input: updated)
        : await PekerjaanPpatRepository(a.pekerjaanDao)
              .updateAggregate(id: localId, input: updated);
    if (!didUpdate) throw StateError('Local UPDATE failed');
    final update = await push('update');
    if (update['revision'] != 2) {
      throw StateError('UPDATE acknowledgement mismatch');
    }
    await publish('update', 2);
    await pull(2);
    final dynamic updatedB = isNotaris
        ? (await b.pekerjaanDao.getPekerjaanNotaris()).single
        : (await b.pekerjaanDao.getPekerjaanPpat()).single;
    final dynamic hargaB = isNotaris
        ? (await b.pekerjaanDao.getHargaNotaris(updatedB.id)).single
        : (await b.pekerjaanDao.getHargaPpat(updatedB.id)).single;
    final dynamic prosesB = isNotaris
        ? (await b.pekerjaanDao.getProsesNotaris(updatedB.id)).single
        : (await b.pekerjaanDao.getProsesPpat(updatedB.id)).single;
    final dynamic atributB = isNotaris
        ? (await b.pekerjaanDao.getAtributNotaris(prosesB.id)).single
        : (await b.pekerjaanDao.getAtributPpat(prosesB.id)).single;
    if ((updatedB as dynamic).nama != '$name-UPDATED' ||
        (hargaB as dynamic).uuid != (hargaA as dynamic).uuid ||
        hargaB.harga != '150000' ||
        (prosesB as dynamic).uuid != (prosesA as dynamic).uuid ||
        (atributB as dynamic).atribut != 'Akta') {
      throw StateError('Device B UPDATE snapshot/child identity mismatch');
    }
    final didDelete = isNotaris
        ? await PekerjaanNotarisRepository(a.pekerjaanDao)
              .deleteAggregate(localId)
        : await PekerjaanPpatRepository(a.pekerjaanDao)
              .deleteAggregate(localId);
    if (!didDelete) throw StateError('Local DELETE failed');
    final deleted = await push('delete');
    if (deleted['revision'] != 3) {
      throw StateError('DELETE acknowledgement mismatch');
    }
    await publish('delete', 3);
    await b.customStatement(
      'UPDATE pekerjaan_$domain SET nama=?,is_sync_dirty=1 WHERE id=?',
      ['Device B pending edit', updatedB.id],
    );
    try {
      await (isNotaris
          ? notarisB.pullPage(limit: 1)
          : ppatB.pullPage(limit: 1));
      throw StateError('Dirty Device B row was overwritten');
    } on StateError {
      final cursor =
          (await b
                  .customSelect(
                    'SELECT cursor FROM pekerjaan_${domain}_sync_feed',
                  )
                  .getSingle())
              .read<int>('cursor');
      final dirty = (await b
          .customSelect(
            'SELECT is_sync_dirty,nama FROM pekerjaan_$domain WHERE id=?',
            variables: [Variable.withInt(updatedB.id)],
          )
          .getSingle());
      if (cursor != baseCursor + 2 ||
          dirty.read<int>('is_sync_dirty') != 1 ||
          dirty.read<String>('nama') != 'Device B pending edit') {
        rethrow;
      }
    }
    await record('dirty_pull_blocked');
    await b.customStatement(
      'UPDATE pekerjaan_$domain SET nama=?,is_sync_dirty=0 WHERE id=?',
      ['$name-UPDATED', updatedB.id],
    );
    await pull(3);
    final tombstone = (await b
        .customSelect(
          'SELECT status,deleted_at IS NOT NULL AS has_tombstone FROM pekerjaan_$domain WHERE id=?',
          variables: [Variable.withInt(updatedB.id)],
        )
        .getSingle());
    if (tombstone.read<int>('status') != 0 ||
        tombstone.read<int>('has_tombstone') != 1) {
      throw StateError('Device B tombstone missing');
    }
    await b.customStatement(
      'UPDATE pekerjaan_${domain}_sync_feed SET cursor=? WHERE scope=?',
      [baseCursor, scope],
    );
    final replayCursor = isNotaris
        ? await notarisB.pullPage(limit: 100)
        : await ppatB.pullPage(limit: 100);
    if (replayCursor != baseCursor + 3) {
      throw StateError('Pull replay cursor mismatch');
    }
    final emptyPage = await dio.get<Map<String, dynamic>>(
      '/pekerjaan-$domain/sync/pull',
      queryParameters: {'cursor': replayCursor, 'limit': 10},
    );
    if ((emptyPage.data!['changes'] as List).isNotEmpty ||
        emptyPage.data!['next_cursor'] != replayCursor) {
      throw StateError('Latest cursor returned duplicate events');
    }
    for (final db in [a, b]) {
      if ((await db.customSelect('PRAGMA integrity_check').getSingle())
                  .read<String>('integrity_check') !=
              'ok' ||
          (await db.customSelect('PRAGMA foreign_key_check').get())
              .isNotEmpty) {
        throw StateError('Disposable SQLite integrity/FK mismatch');
      }
    }
    await a.close();
    await b.close();
    final reopenedA = AppDatabase.forTesting(NativeDatabase(source));
    final reopened = AppDatabase.forTesting(NativeDatabase(target));
    final storedA =
        (await reopenedA
                .customSelect(
                  'SELECT cursor FROM pekerjaan_${domain}_sync_feed WHERE scope=?',
                  variables: [Variable.withString(scope)],
                )
                .getSingle())
            .read<int>('cursor');
    final stored =
        (await reopened
                .customSelect(
                  'SELECT cursor FROM pekerjaan_${domain}_sync_feed WHERE scope=?',
                  variables: [Variable.withString(scope)],
                )
                .getSingle())
            .read<int>('cursor');
    final count =
        (await reopened
                .customSelect(
                  'SELECT count(*) AS n FROM pekerjaan_$domain WHERE uuid=?',
                  variables: [Variable.withString(uuid)],
                )
                .getSingle())
            .read<int>('n');
    await reopened.close();
    await reopenedA.close();
    if (storedA != baseCursor + 3 || stored != baseCursor + 3 || count != 1) {
      throw StateError('Restart persistence/duplicate mismatch');
    }
    await record('verified', {
      'device_a_cursor': storedA,
      'device_b_cursor': stored,
      'server_revision': 3,
      'sqlite_integrity': 'ok',
      'foreign_key_violations': 0,
      'replay_duplicates': 0,
      'dirty_protection': true,
    });
  }, timeout: const Timeout(Duration(minutes: 5)));
}
