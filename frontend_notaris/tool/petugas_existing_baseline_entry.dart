// Explicit headless Flutter entry: run only through the reviewed PowerShell CLI.
// Not part of normal startup or the default test directory.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/models/auth_session.dart';
import 'package:frontend_notaris/repositories/petugas_baseline_pull.dart';
import 'package:frontend_notaris/repositories/petugas_identity_reconciliation.dart';
import 'package:frontend_notaris/repositories/petugas_reference_resolver.dart';
import 'package:frontend_notaris/services/petugas_reference_api.dart';
import 'package:frontend_notaris/services/petugas_sync_api.dart';

const reviewedClouds = [
  'e85be759-1e15-4b2f-8243-120131475207',
  '6e302bea-4999-4180-b322-665b94f3495b',
  'e8875e8a-4b4a-4773-a1ad-7d799885a937',
  '1a2ccb82-e8ca-44a8-bb76-44e5c550e2de',
];

void require(bool condition, String message) {
  if (!condition) throw StateError(message);
}

String fileDigest(File file) =>
    sha256.convert(file.readAsBytesSync()).toString();

/// This adapter only supplies explicit inputs to existing production services.
/// Dry-run never opens Drift; source and API fixtures can be isolated in tests.
Future<Map<String, dynamic>> runExistingPetugasBaseline({
  required Map<String, dynamic> preparation,
  required File expectedTarget,
  required Dio dio,
  required String token,
  bool apply = false,
  String? confirmTarget,
}) async {
  final target = AppDatabase.petugasBaselineFilePath(expectedTarget);
  final source = syncMap(preparation['source']);
  final backup = syncMap(preparation['backup']);
  final inventory = syncMap(preparation['inventory']);
  final counts = syncMap(inventory['counts']);
  require(
    preparation['kind'] == 'existing-petugas-baseline-v1' &&
        preparation['source_unchanged'] == true &&
        preparation['database_path'] == target &&
        preparation['account_id'] == 2001 &&
        preparation['group_id'] == 11 &&
        inventory['version'] == 13 &&
        counts['pemohons'] == 20 &&
        counts['petugas'] == 0 &&
        counts['petugas_sync_feed'] == 0 &&
        backup['verified_reopened'] == true &&
        token.isNotEmpty,
    'Reviewed profile, backup and authenticated account required',
  );
  final context = PetugasBaselineContext(
    generation: preparation['generation'] as String,
    accountId: 2001,
    deviceId: preparation['device_id'] as String,
    databasePath: target,
  );
  require(context.scope == preparation['scope'], 'Scope mismatch');
  require(
    !apply || confirmTarget == target,
    'Apply needs exact target confirmation',
  );
  void unchanged() {
    require(File(target).existsSync(), 'Target missing');
    for (final suffix in ['-wal', '-shm', '-journal']) {
      require(!File('$target$suffix').existsSync(), 'Sidecar appeared; stop');
    }
    require(
      fileDigest(File(target)) == source['sha256'],
      'Source changed; stop',
    );
    require(
      fileDigest(File(backup['path'] as String)) == backup['sha256'],
      'Backup changed; stop',
    );
  }

  unchanged();
  require(
    Uri.parse(dio.options.baseUrl) == PetugasBaselineContext.apiBase,
    'Unexpected API deployment',
  );
  dio.options.followRedirects = false;
  dio.options.headers['Authorization'] = 'Bearer $token';
  final requests = <Map<String, dynamic>>[];
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.method != 'GET' ||
            options.data != null ||
            options.uri.origin != 'http://127.0.0.1:8081' ||
            !{
              '/api/v1/petugas/sync/pull',
              '/api/v1/petugas/references/jenis-kelamin',
            }.contains(options.uri.path)) {
          return handler.reject(
            DioException(requestOptions: options, error: 'GET-only boundary'),
          );
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        requests.add({
          'method': response.requestOptions.method,
          'path': response.requestOptions.path,
          'query': response.requestOptions.queryParameters,
          'status': response.statusCode,
        });
        handler.next(response);
      },
    ),
  );
  final api = AuthenticatedPetugasPullApi(dio, verifiedToken: () => token);
  final events = <Map<String, dynamic>>[];
  for (final cursor in [0, 2, 4]) {
    final page = await api.pull(cursor, limit: 2);
    final changes = (page['changes'] as List).map(syncMap).toList();
    require(
      changes.length == (cursor == 4 ? 0 : 2) &&
          page['next_cursor'] == (cursor == 0 ? 2 : 4) &&
          page['has_more'] == (cursor == 0),
      'Unexpected baseline pagination',
    );
    events.addAll(changes);
  }
  for (var i = 0; i < 4; i++) {
    final event = events[i];
    final payload = syncMap(event['payload']);
    require(
      event['publication_sequence'] == i + 1 &&
          event['server_id'] == 101 + i &&
          event['petugas_uuid'] == reviewedClouds[i] &&
          event['row_version'] == 1 &&
          event['tombstone'] == false &&
          payload['jenis_kelamin_id'] == 11 &&
          // Go PetugasPayload uses omitempty: absent nullable user_id is NULL.
          payload['user_id'] == null,
      'Baseline identity/reference changed',
    );
  }
  final catalog = await PetugasReferenceApi(dio).genders();
  require(
    catalog.where((g) => g.serverId == 11).length == 1,
    'Gender11 unavailable',
  );
  final genders = (inventory['genders'] as List).map(syncMap);
  require(
    genders
            .where(
              (g) =>
                  g['id'] == 1 &&
                  g['uuid'] == 'notarisdev-smoke-gender-11' &&
                  g['status'] == 1 &&
                  g['dirty'] == 0 &&
                  g['deleted'] == null,
            )
            .length ==
        1,
    'Reviewed fixture UUID reference unavailable',
  );
  final evidence =
      'smoke-v1 explicit fixture producer pair + authenticated GET gender catalog11; generation ${context.generation}; existing profile audit/backup';
  final plan = PetugasBaselinePlan(
    scope: context.scope,
    reviewedLocalUuids: const <String>{},
    selections: events.map(
      (e) => PetugasBaselineSelection.serverOnly(
        server: PetugasServerIdentity.fromRecord({
          'id': e['server_id'],
          'uuid': e['petugas_uuid'],
          'row_version': e['row_version'],
        }, scope: context.scope),
        sequence: e['publication_sequence'] as int,
        evidence: 'Authenticated GET exact reviewed cloud identity; empty local inventory in verified SQLite backup',
      ),
    ),
  );
  unchanged();
  final result = <String, dynamic>{
    'status': 'dry_run_ready_awaiting_approval',
    'applied': false,
    'database_path': target,
    'scope': context.scope,
    'account_id': 2001,
    'group_id': 11,
    'device_id': context.deviceId,
    'source_sha256': source['sha256'],
    'backup_sha256': backup['sha256'],
    'gender': {
      'server_id': 11,
      'local_id': 1,
      'local_uuid': 'notarisdev-smoke-gender-11',
      'evidence': evidence,
    },
    'user_ids': [null],
    'decisions': [
      for (final e in events)
        {
          'server_id': e['server_id'],
          'cloud_uuid': e['petugas_uuid'],
          'sequence': e['publication_sequence'],
          'row_version': 1,
          'selection': 'serverOnly',
        },
    ],
    'requests': requests,
    'normal_sync_started': false,
  };
  if (!apply) return result;

  // No retries: each page is atomic in the existing repository. The CLI owns
  // a durable attempt marker before entering this branch, even if this fails.
  var db = AppDatabase.forIsolatedPetugasPull(File(target));
  try {
    await db.customStatement('PRAGMA foreign_keys=ON');
    require(
      (await db.select(db.petugasLocals).get()).isEmpty,
      'Petugas inventory changed',
    );
    for (final table in [
      'petugas_identity_map',
      'petugas_sync_feed',
      'petugas_sync_journal',
      'petugas_sync_conflict',
      'petugas_gender_reference',
      'petugas_user_reference',
    ]) {
      require(
        (await db.customSelect('SELECT * FROM $table').get()).isEmpty,
        'Sync state changed',
      );
    }
    final refs = VerifiedPetugasReferences(db, scope: context.scope);
    await refs.confirmGender(
      localUuid: 'notarisdev-smoke-gender-11',
      serverId: 11,
      evidence: evidence,
    );
    final session = AuthSession(
      token: token,
      userId: 2001,
      groupId: 11,
      userName: 'fixture.operator',
      groupName: 'development fixture',
      user: const {'id': 2001, 'group_id': 11},
      sidebars: const [],
      verifiedAt: DateTime.now(),
    );
    await PetugasBaselinePull(
      db: db,
      dio: dio,
      context: context,
      plan: plan,
      references: refs,
      session: () => session,
    ).pull(limit: 2);
    await db.close();
    db = AppDatabase.forIsolatedPetugasPull(File(target));
    final feed =
        (await db
                .customSelect(
                  'SELECT scope,cursor,blocked FROM petugas_sync_feed',
                )
                .getSingle())
            .data;
    require(
      feed['scope'] == context.scope &&
          feed['cursor'] == 4 &&
          feed['blocked'] == null,
      'Persisted cursor mismatch',
    );
    final maps = await db.select(db.petugasIdentityMaps).get();
    final rows = await db.select(db.petugasLocals).get();
    require(
      rows.length == 4 &&
          maps.length == 4 &&
          maps.map((m) => m.cloudUuid).toSet().containsAll(reviewedClouds),
      'Local acceptance mismatch',
    );
    for (final row in rows) {
      final map = maps.singleWhere((m) => m.localUuid == row.uuid);
      require(
        map.cloudUuid != row.uuid &&
            map.state == 'server_only' &&
            !row.isSyncDirty &&
            row.status == 1 &&
            row.deletedAt == null &&
            row.userId == null &&
            row.jenisKelamin == 1,
        'Local identity/reference mismatch',
      );
    }
    result.addAll({
      'status': 'applied_cursor4_reopened',
      'applied': true,
      'cursor_after_reopen': 4,
      'local_mappings': [
        for (final m in maps)
          {
            'server_id': m.serverId,
            'cloud_uuid': m.cloudUuid,
            'local_uuid': m.localUuid,
          },
      ],
      'commit_evidence': 'page commits persisted, independently reopened cursor4 + maps; external SQLite postcheck still required',
    });
    return result;
  } finally {
    await db.close();
  }
}

void main() {
  test('explicit existing-development Petugas baseline operation', () async {
    final env = Platform.environment;
    final root = Directory(env['NOTARIS_EXISTING_BASELINE_RECEIPT'] ?? '');
    require(
      p.isAbsolute(root.path) &&
          p.isWithin(
            p.join(Directory.current.parent.path, '.local'),
            root.path,
          ),
      'Workspace-owned receipt required',
    );
    final preparation = syncMap(
      jsonDecode(
        File(p.join(root.path, 'preparation.json')).readAsStringSync(),
      ),
    );
    final target = File(
      p.join(
        env['APPDATA']!,
        'com.notaris',
        'frontend_notaris',
        'notarisdev',
        preparation['generation'] as String,
        'offline.sqlite',
      ),
    );
    final apply = env['NOTARIS_EXISTING_BASELINE_APPLY'] == '1';
    if (apply) {
      final marker = syncMap(
        jsonDecode(
          File(p.join(root.path, 'apply-attempt.json')).readAsStringSync(),
        ),
      );
      final prior = syncMap(
        jsonDecode(
          File(p.join(root.path, 'pull-preflight.json')).readAsStringSync(),
        ),
      );
      require(
        marker['mode'] == 'apply' &&
            marker['target'] == target.path &&
            marker['scope'] == preparation['scope'] &&
            marker['sourceSha256'] ==
                syncMap(preparation['source'])['sha256'] &&
            prior['status'] == 'dry_run_ready_awaiting_approval' &&
            prior['scope'] == preparation['scope'],
        'Explicit CLI attempt marker and successful reviewed preflight required',
      );
    }
    final dio = Dio(
      BaseOptions(
        baseUrl: PetugasBaselineContext.apiBase.toString(),
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => HttpClient()..findProxy = (_) => 'DIRECT',
    );
    final output = File(
      p.join(root.path, apply ? 'pull-apply.json' : 'pull-preflight.json'),
    );
    require(
      !output.existsSync(),
      'Retain previous receipt; no overwrite/retry',
    );
    try {
      final result = await runExistingPetugasBaseline(
        preparation: preparation,
        expectedTarget: target,
        dio: dio,
        token: env['NOTARIS_BASELINE_LIVE_TOKEN'] ?? '',
        apply: apply,
        confirmTarget: env['NOTARIS_EXISTING_BASELINE_CONFIRM'],
      );
      output.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(result),
      );
    } catch (error) {
      output.writeAsStringSync(
        jsonEncode({
          'status': 'STOP_READONLY_INVESTIGATION',
          'error_type': error.runtimeType.toString(),
          if (error is StateError) 'reason': error.message,
          'applied_requested': apply,
        }),
      );
      fail(
        'Operation stopped; inspect sanitized receipt; no automatic retry/restore',
      );
    } finally {
      dio.close(force: true);
    }
  });
}
