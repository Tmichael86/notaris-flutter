// Opt-in live GET → production baseline service → fresh owned SQLite only.
// No Flutter application startup, global coordinator, mocks, login POST or push.
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/models/auth_session.dart';
import 'package:frontend_notaris/repositories/petugas_baseline_pull.dart';
import 'package:frontend_notaris/repositories/petugas_identity_reconciliation.dart';
import 'package:frontend_notaris/repositories/petugas_reference_resolver.dart';
import 'package:frontend_notaris/services/petugas_reference_api.dart';
import 'package:frontend_notaris/services/petugas_sync_api.dart';
import 'package:frontend_notaris/services/user_api_service.dart';

void main() {
  test('controlled live authenticated GET baseline persists four Petugas and cursor4', () async {
    final root = Directory(Platform.environment['NOTARIS_BASELINE_LIVE_ROOT']!);
    final workspace = Directory.current.parent;
    if (!p.isAbsolute(root.path) ||
        !p.isWithin(p.join(workspace.path, '.local'), root.path) ||
        !p.basename(root.path).startsWith('petugas-baseline-live-')) {
      fail('An explicit workspace-owned .local audit directory is required');
    }
    final marker = jsonDecode(
      await File(p.join(root.path, 'ownership.json')).readAsString(),
    ) as Map<String, dynamic>;
    final token = Platform.environment['NOTARIS_BASELINE_LIVE_TOKEN'] ?? '';
    final generation = marker['generation'] as String;
    final account = marker['account_id'] as int;
    final group = marker['group_id'] as int;
    if (marker['kind'] != 'petugas-baseline-get-live-v1' ||
        marker['target'] != '127.0.0.1:5432/notarisdev' ||
        marker['postgres_preflight_verified'] != true ||
        token.isEmpty ||
        account != 2001 ||
        group != 11) {
      fail(
        'Verified notarisdev deployment and legitimate fixture session required',
      );
    }
    final profile = Directory(p.join(root.path, 'notarisdev', generation));
    final file = File(p.join(profile.path, 'offline.sqlite'));
    if (profile.existsSync() || file.existsSync()) {
      fail(
        'Refusing an existing SQLite/profile; retain it and inspect, no reset',
      );
    }
    await profile.create(recursive: true);
    final context = PetugasBaselineContext(
      generation: generation,
      accountId: account,
      deviceId: marker['device_id'] as String,
      databasePath: file.path,
    );
    AppDatabase? db;
    final requests = <Map<String, dynamic>>[];
    var phase = 'reference preflight';
    final result = <String, dynamic>{
      'sqlite_path': context.databasePath,
      'generation': generation,
      'account_id': account,
      'group_id': group,
      'device_id': context.deviceId,
      'http_adapter': 'real IOHttpClientAdapter',
      'http_methods': ['GET'],
      'publisher_enabled': false,
    };
    final dio = Dio(
      BaseOptions(
        baseUrl: PetugasBaselineContext.apiBase.toString(),
        headers: {'Authorization': 'Bearer $token'},
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 5),
      ),
    );
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => HttpClient()..findProxy = (_) => 'DIRECT',
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.method != 'GET' ||
              options.data != null ||
              options.uri.origin != 'http://127.0.0.1:8081' ||
              !{
                '/petugas/sync/pull',
                '/petugas/references/jenis-kelamin',
                '/users',
              }.contains(options.path)) {
            return handler.reject(
              DioException(
                requestOptions: options,
                error: 'Only reviewed live GET requests permitted',
              ),
            );
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          final data = syncMap(response.data)['data'];
          requests.add({
            'phase': phase,
            'method': response.requestOptions.method,
            'path': response.requestOptions.path,
            'query': response.requestOptions.queryParameters,
            'status': response.statusCode,
            if (data is Map && data['changes'] is List)
              'events': (data['changes'] as List).length,
            if (data is Map && data['next_cursor'] is int)
              'next_cursor': data['next_cursor'],
          });
          handler.next(response);
        },
      ),
    );
    Future<int> cursor() async =>
        (await db!
                .customSelect('SELECT cursor FROM petugas_sync_feed WHERE id=1')
                .getSingle())
            .read<int>('cursor');
    Future<void> save() => File(p.join(root.path, 'flutter-live-result.json'))
        .writeAsString(
          const JsonEncoder.withIndent('  ')
              .convert({...result, 'requests': requests}),
        );
    try {
      db = AppDatabase.forIsolatedPetugasPull(file);
      await db.customStatement('PRAGMA foreign_keys=ON');
      expect(await db.select(db.petugasLocals).get(), isEmpty);
      expect(await db.select(db.petugasIdentityMaps).get(), isEmpty);
      expect(
        await db.customSelect('SELECT * FROM petugas_sync_feed').get(),
        isEmpty,
      );
      final api = AuthenticatedPetugasPullApi(dio, verifiedToken: () => token);
      final first = await api.pull(0, limit: 2);
      final second = await api.pull(2, limit: 2);
      expect(first['next_cursor'], 2);
      expect(first['has_more'], true);
      expect(second['next_cursor'], 4);
      expect(second['has_more'], false);
      final events = [
        ...first['changes'] as List,
        ...second['changes'] as List,
      ].map(syncMap).toList();
      expect(events.length, 4);
      final expected = marker['expected_events'] as List;
      for (var i = 0; i < 4; i++) {
        final e = events[i];
        final approved = syncMap(expected[i]);
        expect(e['publication_sequence'], i + 1);
        expect(e['server_id'], approved['petugas_id']);
        expect(e['petugas_uuid'], approved['uuid']);
        expect(e['row_version'], 1);
        expect(e['tombstone'], false);
      }
      final refs = VerifiedPetugasReferences(db, scope: context.scope);
      final catalog = await PetugasReferenceApi(dio).genders();
      final genders = events
          .map((e) => syncMap(e['payload'])['jenis_kelamin_id'])
          .whereType<int>()
          .toSet();
      final users = events
          .map((e) => syncMap(e['payload'])['user_id'])
          .whereType<int>()
          .toSet();
      final genderProof = <Map<String, dynamic>>[];
      for (final serverId in (genders.toList()..sort())) {
        final selected = catalog.where((r) => r.serverId == serverId).toList();
        expect(selected.length, 1);
        final localUuid = const Uuid().v4();
        final localId = await db
            .into(db.jenisKelamins)
            .insert(
              JenisKelaminsCompanion.insert(
                uuid: localUuid,
                nama: selected.single.label,
                isSyncDirty: const Value(false),
              ),
            );
        final evidence =
            'authenticated GET /petugas/references/jenis-kelamin explicit server ID $serverId; generation $generation; fresh owned profile';
        await refs.confirmGender(
          localUuid: localUuid,
          serverId: serverId,
          evidence: evidence,
        );
        expect(await refs.genderToLocal(serverId), localId);
        genderProof.add({
          'server_id': serverId,
          'local_id': localId,
          'local_uuid': localUuid,
          'evidence': evidence,
        });
      }
      for (final serverId in users) {
        await refs.verifyUserFromServer(UserApiService(dio), serverId);
      }
      final plan = PetugasBaselinePlan(
        scope: context.scope,
        reviewedLocalUuids: const {},
        selections: events.map(
          (e) => PetugasBaselineSelection.serverOnly(
            server: PetugasServerIdentity.fromRecord({
              'uuid': e['petugas_uuid'],
              'id': e['server_id'],
              'row_version': e['row_version'],
            }, scope: context.scope),
            sequence: e['publication_sequence'] as int,
            evidence: 'authenticated live GET baseline; empty disposable local identity inventory; approved PostgreSQL identity match',
          ),
        ),
      );
      final session = AuthSession(
        token: token,
        userId: account,
        groupId: group,
        userName: 'fixture.operator',
        groupName: 'development fixture',
        user: {'id': account, 'group_id': group},
        sidebars: const [],
        verifiedAt: DateTime.now(),
      );
      phase = 'production baseline import';
      await PetugasBaselinePull(
        db: db,
        dio: dio,
        context: context,
        plan: plan,
        references: refs,
        session: () => session,
      ).pull(limit: 2);
      expect(await cursor(), 4);
      phase = 'local identity acceptance';
      result.addAll({
        'imported_petugas': 4,
        'cursor_before': 0,
        'cursor_after': 4,
      });
      final rows = await (db.select(
        db.petugasLocals,
      )..orderBy([(r) => OrderingTerm.asc(r.id)])).get();
      final mappings = await db.select(db.petugasIdentityMaps).get();
      expect(rows.length, 4);
      expect(rows.map((r) => r.uuid).toSet().length, 4);
      expect(
        mappings.map((m) => m.cloudUuid).toSet(),
        events.map((e) => e['petugas_uuid']).toSet(),
      );
      expect(
        rows.every(
          (r) =>
              !{101, 102, 103, 104}.contains(r.id) &&
              !r.isSyncDirty &&
              r.status == 1 &&
              r.deletedAt == null,
        ),
        true,
      );
      for (final row in rows) {
        final m = mappings.singleWhere((m) => m.localUuid == row.uuid);
        expect(m.cloudUuid, isNot(row.uuid));
        final source = events.singleWhere((e) => e['server_id'] == m.serverId);
        expect(row.userId, syncMap(source['payload'])['user_id']);
        if (row.userId != null) {
          expect(await refs.verifiedServerUser(row.userId!), row.userId);
        }
      }
      final snapshot = jsonEncode(rows.map((r) => r.toJson()).toList());
      result.addAll({
        'gender_provenance': genderProof,
        'user_provenance': users
            .map(
              (id) => {
                'server_id': id,
                'evidence': 'authenticated GET /users active user selection',
              },
            )
            .toList(),
        'identity_selections': 'four explicit server-only decisions after authenticated discovery and empty inventory check',
        'mappings': mappings
            .map(
              (m) => {
                'server_id': m.serverId,
                'cloud_uuid': m.cloudUuid,
                'local_uuid': m.localUuid,
                'local_id': rows.singleWhere((r) => r.uuid == m.localUuid).id,
                'state': m.state,
              },
            )
            .toList(),
        'imported_petugas': 4,
        'cursor_before': 0,
        'cursor_after': await cursor(),
      });
      phase = 'SQLite restart';
      await db.close();
      db = AppDatabase.forIsolatedPetugasPull(file);
      await db.customStatement('PRAGMA foreign_keys=ON');
      result['cursor_after_restart'] = await cursor();
      expect(await cursor(), 4);
      phase = 'restart replay';
      await PetugasBaselinePull(
        db: db,
        dio: dio,
        context: context,
        plan: plan,
        references: VerifiedPetugasReferences(db, scope: context.scope),
        session: () => session,
      ).pull(limit: 2);
      expect(await cursor(), 4);
      expect(
        jsonEncode(
          (await (db.select(
                db.petugasLocals,
              )..orderBy([(r) => OrderingTerm.asc(r.id)])).get())
              .map((r) => r.toJson())
              .toList(),
        ),
        snapshot,
      );
      final integrity =
          (await db.customSelect('PRAGMA integrity_check').getSingle())
              .read<String>('integrity_check');
      final fk = await db.customSelect('PRAGMA foreign_key_check').get();
      expect(integrity, 'ok');
      expect(fk, isEmpty);
      expect(await db.select(db.pemohons).get(), isEmpty);
      expect(await db.select(db.transaksis).get(), isEmpty);
      expect(
        await db.customSelect('SELECT * FROM petugas_sync_conflict').get(),
        isEmpty,
      );
      expect(
        await db
            .customSelect(
              'SELECT * FROM petugas_sync_journal WHERE pending IS NOT NULL',
            )
            .get(),
        isEmpty,
      );
      final imports = requests
          .where((r) => r['phase'] == 'production baseline import')
          .toList();
      expect(imports.map((r) => (r['query'] as Map)['cursor']).toList(), [
        0,
        2,
      ]);
      expect(imports.map((r) => r['events']).toList(), [2, 2]);
      final replay = requests.last;
      expect((replay['query'] as Map)['cursor'], 4);
      expect(replay['events'], 0);
      result.addAll({
        'status': 'LIVE_GET_FLUTTER_SQLITE_VERIFIED',
        'cursor_after_replay': 4,
        'records_after_replay': 4,
        'integrity_check': integrity,
        'foreign_key_violations': fk.length,
        'other_local_business_tables': 'empty and unchanged',
        'normal_coordinator_started': false,
      });
      await save();
    } catch (error, stack) {
      result.addAll({
        'status': 'STOP_RETAIN_DISPOSABLE_FOR_INSPECTION',
        'phase': phase,
        'error_type': error.runtimeType.toString(),
        'stack_frames': stack.toString().split('\n').take(8).toList(),
        'failure_kind': error is PetugasSyncFailure
            ? error.kind.name
            : 'validation_or_transport_failure',
      });
      await save();
      // Never dump a Dio request, Authorization header or raw credential error.
      fail(
        'Controlled live pull stopped in $phase; inspect sanitized local result. SQLite retained.',
      );
    } finally {
      await db?.close();
      dio.close(force: true);
    }
  }, skip: Platform.environment['NOTARIS_PETUGAS_BASELINE_LIVE'] != '1');
}
