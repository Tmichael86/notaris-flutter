import '../repositories/transaction_upload_readiness.dart';

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../models/auth_session.dart';
import '../repositories/sync_log_repository.dart';
import '../repositories/transaction_cloud_repository.dart';
import '../repositories/transaction_cloud_references.dart';

enum ManualSyncDirection { upload, download }

class ManualTransactionFailure implements Exception {
  const ManualTransactionFailure(this.code);
  final String code;
  @override
  String toString() => 'Manual transaction sync: $code';
}

/// First bridge deliberately accepts only isolated, file-backed disposable
/// profiles. A normal development/production profile needs a reviewed factory.
class TransactionManualProfile {
  TransactionManualProfile({
    required this.sqlitePath,
    required this.baseUrl,
    required this.databaseTarget,
    required this.deployment,
    required this.device,
    required this.generation,
    required this.accountId,
    required this.groupId,
  });
  final String sqlitePath,
      baseUrl,
      databaseTarget,
      deployment,
      device,
      generation;
  final int accountId, groupId;
  String get scope => jsonEncode([
    baseUrl,
    databaseTarget,
    deployment,
    accountId,
    groupId,
    device,
    generation,
    File(sqlitePath).resolveSymbolicLinksSync(),
  ]);
  String get transactionScope => '$scope/transactions';
  String get petugasScope => '$scope/petugas';
  String get masterScope => '$scope/masters';

  String validateLocation() {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null ||
        uri.scheme != 'http' ||
        uri.host != '127.0.0.1' ||
        uri.port < 1024 ||
        {8080, 8081, 5432}.contains(uri.port) ||
        uri.path != '/api/v1' ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !RegExp(
          r'^127\.0\.0\.1:55[4-9]\d\d/notaris_(publish_test[a-z0-9_]*|transaction_sim)$',
        ).hasMatch(databaseTarget) ||
        deployment.isEmpty ||
        device.isEmpty ||
        generation.isEmpty ||
        accountId < 1 ||
        groupId < 1) {
      throw const ManualTransactionFailure('scope');
    }
    return validateTemporaryLocation();
  }

  String validateTemporaryLocation() {
    final canonical = File(sqlitePath).resolveSymbolicLinksSync();
    final parent = p.dirname(canonical);
    final temp = Directory.systemTemp.resolveSymbolicLinksSync();
    // Explicit disposable directory naming; never accept a generic AppData or
    // ordinary SQLite file just because a caller supplied a testing boolean.
    if (!p.isWithin(temp, parent) ||
        !p.basename(parent).startsWith('transaction_manual_') ||
        !{'a.sqlite', 'b.sqlite'}.contains(p.basename(canonical))) {
      throw const ManualTransactionFailure('scope');
    }
    return canonical;
  }

  Future<void> verifyRequest(RequestOptions request) async {}

  void validateSelection(
    String module,
    ManualSyncDirection direction, [
    String? uuid,
  ]) {}

  Future<void> validate(AppDatabase db) async {
    final canonical = validateLocation();
    final main = (await db.customSelect('PRAGMA database_list').get())
        .singleWhere((row) => row.read<String>('name') == 'main');
    if (File(main.read<String>('file')).resolveSymbolicLinksSync() !=
        canonical) {
      throw const ManualTransactionFailure('scope');
    }
    for (final table in [
      'transaction_cloud_feed',
      'pekerjaan_notaris_sync_feed',
      'pekerjaan_ppat_sync_feed',
    ]) {
      final expected = table == 'transaction_cloud_feed'
          ? transactionScope
          : masterScope;
      final scopes = await db.customSelect('SELECT scope FROM $table').get();
      if (scopes.any((r) => r.read<String>('scope') != expected)) {
        throw const ManualTransactionFailure('scope');
      }
    }
    final officer = await db
        .customSelect('SELECT scope FROM petugas_sync_feed')
        .get();
    if (officer.any((r) => r.read<String>('scope') != petugasScope)) {
      throw const ManualTransactionFailure('scope');
    }
  }
}

class TransactionManualResult {
  const TransactionManualResult({
    required this.count,
    this.cursor,
    this.receipt,
    this.more = false,
  });
  final int count;
  final int? cursor;
  final Map<String, dynamic>? receipt;
  final bool more;
}

/// Application orchestration only: no publication, dependency push, timer,
/// global coordinator, identity guessing or second sync engine.
class TransactionManualSyncService {
  TransactionManualSyncService({
    required this.db,
    required this.profile,
    required Dio http,
    required this.session,
    required this.uiSmoke,
    SyncLogRepository? logs,
  }) : logs = logs ?? SyncLogRepository(db),
       _http = http.clone(
         options: http.options.copyWith(
           connectTimeout: const Duration(seconds: 5),
           sendTimeout: const Duration(seconds: 15),
           receiveTimeout: const Duration(seconds: 20),
           validateStatus: (status) =>
               status != null && status >= 200 && status < 300,
           responseType: ResponseType.json,
           followRedirects: false,
         ),
       ) {
    // clone retains existing auth/smoke interceptors. The final boundary limits
    // every request to this profile and supported Transaction routes.
    _http.interceptors.add(
      InterceptorsWrapper(
        onRequest: (r, h) async {
          try {
            final current = _authorize();
            if (r.uri.origin != Uri.parse(profile.baseUrl).origin ||
                !RegExp(
                  r'^/api/v1/transaksi-(notaris|ppat)/sync/(create|update|delete|pull)$',
                ).hasMatch(r.uri.path) ||
                ((r.uri.path.endsWith('/pull'))
                    ? r.method != 'GET'
                    : r.method != 'POST')) {
              throw const ManualTransactionFailure('scope');
            }
            r.headers['Authorization'] = 'Bearer ${current.token}';
            final action = r.uri.path.split('/').last;
            if (!_permission(current, action == 'pull' ? 'read' : action)) {
              throw const ManualTransactionFailure('forbidden');
            }
            await profile.verifyRequest(r);
            r.followRedirects = false;
            h.next(r);
          } catch (e) {
            h.reject(DioException(requestOptions: r, error: e));
          }
        },
      ),
    );
  }
  final AppDatabase db;
  final TransactionManualProfile profile;
  final AuthSession? Function() session;
  final bool Function() uiSmoke;
  final SyncLogRepository logs;
  final Dio _http;
  static final _inFlight = <String>{};
  static const uploadModules = {
    'transaksi_notaris': 'notaris',
    'transaksi_ppat': 'ppat',
  };
  static const feedModule = 'transaksi';

  AuthSession _authorize() {
    if (uiSmoke()) throw const ManualTransactionFailure('forbidden');
    final s = session();
    if (s == null || s.token.isEmpty) {
      throw const ManualTransactionFailure('unauthorized');
    }
    if (s.isOffline) throw const ManualTransactionFailure('offline');
    if (s.userId != profile.accountId ||
        s.groupId != profile.groupId ||
        _http.options.baseUrl != profile.baseUrl) {
      throw const ManualTransactionFailure('scope');
    }
    return s;
  }

  bool _permission(AuthSession s, String action) => s.sidebars.any((a) {
    final sidebar = a['sidebar'];
    bool yes(dynamic x) => x == true || x == 1 || x == '1';
    return sidebar is Map &&
        sidebar['sidebar_kode'] == 'transaksi' &&
        yes(a['read']) &&
        yes(a[action]) &&
        (sidebar['status'] == null || yes(sidebar['status']));
  });

  /// Read-only eligibility for isolated UI. Execution repeats these guards;
  /// discovery must not create a successful sync log or bind a new cursor.
  Future<void> validateUiContext({
    required String selectedModule,
    required ManualSyncDirection direction,
  }) async {
    profile.validateSelection(selectedModule, direction);
    final domain = uploadModules[selectedModule];
    if ((direction == ManualSyncDirection.upload && domain == null) ||
        (direction == ManualSyncDirection.download &&
            selectedModule != feedModule)) {
      throw const ManualTransactionFailure('validation');
    }
    await profile.validate(db);
    final current = _authorize();
    if (!_permission(current, 'read') ||
        (direction == ManualSyncDirection.upload &&
            ![
              'create',
              'update',
              'delete',
            ].any((action) => _permission(current, action)))) {
      throw const ManualTransactionFailure('forbidden');
    }
  }

  /// No log, mutation, cursor binding or network request during Check.
  Future<List<String>> checkUploadEligibility({
    required String selectedModule,
    required int transactionId,
    required String uuid,
  }) async {
    await validateUiContext(
      selectedModule: selectedModule,
      direction: ManualSyncDirection.upload,
    );
    try {
      profile.validateSelection(
        selectedModule,
        ManualSyncDirection.upload,
        uuid,
      );
    } on ManualTransactionFailure {
      return ['UUID di luar pilot yang disetujui.'];
    }
    final identity = await db
        .customSelect(
          'SELECT scope FROM transaction_cloud_identity WHERE local_uuid=?',
          variables: [Variable(uuid)],
        )
        .getSingleOrNull();
    if (identity != null &&
        identity.read<String>('scope') != profile.transactionScope) {
      return ['Scope identity transaksi tidak cocok.'];
    }
    final pending = await db
        .customSelect(
          "SELECT operation FROM transaction_cloud_pending WHERE local_uuid=? AND state='pending'",
          variables: [Variable(uuid)],
        )
        .getSingleOrNull();
    final operation =
        pending?.read<String>('operation') ??
        (identity == null ? 'create' : 'update');
    if (!_permission(_authorize(), operation)) {
      return ['Permission operasi transaksi tidak tersedia.'];
    }
    return TransactionUploadReadiness(db).check(
      transactionId,
      domain: uploadModules[selectedModule]!,
      uuid: uuid,
      petugasScope: profile.petugasScope,
      masterScope: profile.masterScope,
    );
  }

  Future<TransactionManualResult> run({
    required String selectedModule,
    required ManualSyncDirection direction,
    int? transactionId,
    String? expectedLocalUuid,
    int pageSize = 20,
    int maxPages = 1,
  }) async {
    final selectedDomain = uploadModules[selectedModule];
    profile.validateSelection(
      selectedModule,
      direction,
      expectedLocalUuid ?? '',
    );
    if ((direction == ManualSyncDirection.upload && selectedDomain == null) ||
        (direction == ManualSyncDirection.download &&
            selectedModule != feedModule)) {
      throw const ManualTransactionFailure('validation');
    }
    // Share the flight across service instances and handles for the same file.
    await profile.validate(db);
    final flight = File(profile.sqlitePath).resolveSymbolicLinksSync();
    if (!_inFlight.add(flight)) throw const ManualTransactionFailure('busy');
    TransactionManualResult? result;
    try {
      // Refuse a normal/different file before even writing a local attempt log.
      await profile.validate(db);
      await logs.track(
        module: selectedModule,
        direction: direction == ManualSyncDirection.upload ? 'push' : 'pull',
        attemptId: const Uuid().v4(),
        errorCode: (e) => e is ManualTransactionFailure ? e.code : 'unknown',
        completedCount: () => result?.count,
        action: () async {
          try {
            if (pageSize < 1 ||
                pageSize > 100 ||
                maxPages < 1 ||
                maxPages > 10 ||
                (direction == ManualSyncDirection.download &&
                    transactionId != null)) {
              throw const ManualTransactionFailure('validation');
            }
            final s = _authorize();
            await profile.validate(db);
            // A stale feed requires explicit recovery; never silently reset a
            // cursor or permit a new upload after this profile observed 410.
            final lastPull = await db
                .customSelect(
                  "SELECT error_code FROM sync_logs WHERE module IN ('transaksi','transaksi_notaris','transaksi_ppat') AND direction='pull' AND finished_at IS NOT NULL ORDER BY id DESC LIMIT 1",
                )
                .getSingleOrNull();
            if (lastPull?.readNullable<String>('error_code') ==
                'feed_expired') {
              throw const ManualTransactionFailure('feed_expired');
            }
            final cloud = TransactionCloudRepository(
              db,
              _http,
              scope: profile.transactionScope,
              petugasScope: profile.petugasScope,
              masterScope: profile.masterScope,
              domain:
                  selectedDomain ??
                  'notaris', // either pull alias consumes the same feed
            );
            if (direction == ManualSyncDirection.upload) {
              if (transactionId == null) {
                throw const ManualTransactionFailure('validation');
              }
              final header = await (db.select(
                db.transaksis,
              )..where((t) => t.id.equals(transactionId))).getSingle();
              if (header.jenisTransaksi != selectedDomain) {
                throw const ManualTransactionFailure('unsupported_domain');
              }
              if (expectedLocalUuid != null &&
                  header.uuid != expectedLocalUuid) {
                throw const ManualTransactionFailure('conflict');
              }
              if (!RegExp(
                r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
              ).hasMatch(header.uuid)) {
                throw const ManualTransactionFailure('validation');
              }
              final identity = await db
                  .customSelect(
                    'SELECT * FROM transaction_cloud_identity WHERE local_uuid=?',
                    variables: [Variable(header.uuid)],
                  )
                  .getSingleOrNull();
              final pending = await db
                  .customSelect(
                    "SELECT operation FROM transaction_cloud_pending WHERE local_uuid=? AND state='pending'",
                    variables: [Variable(header.uuid)],
                  )
                  .getSingleOrNull();
              final operation =
                  pending?.read<String>('operation') ??
                  (identity == null
                      ? 'create'
                      : header.deletedAt != null
                      ? 'delete'
                      : 'update');
              if (!_permission(s, operation)) {
                throw const ManualTransactionFailure('forbidden');
              }
              if (identity != null &&
                  identity.read<String>('scope') != profile.transactionScope) {
                throw const ManualTransactionFailure('scope');
              }
              // A repeated clean upload is an acknowledged no-op, not a new
              // mutation or a global scan. Child dirty/tombstones still count.
              final childDirty = await db
                  .customSelect(
                    'SELECT 1 FROM transaksi_details WHERE transaksi_id=? AND is_sync_dirty=1 UNION ALL SELECT 1 FROM transaksi_proses WHERE transaksi_id=? AND is_sync_dirty=1 UNION ALL SELECT 1 FROM transaksi_riwayat_pembayaran WHERE transaksi_id=? AND is_sync_dirty=1 LIMIT 1',
                    variables: [
                      Variable(transactionId),
                      Variable(transactionId),
                      Variable(transactionId),
                    ],
                  )
                  .get();
              if (identity != null &&
                  pending == null &&
                  !header.isSyncDirty &&
                  childDirty.isEmpty) {
                result = TransactionManualResult(
                  count: 0,
                  receipt: {
                    'uuid': header.uuid,
                    'revision': identity.read<int>('revision'),
                    'final_number': identity.read<String>('final_number'),
                  },
                );
              } else {
                if (operation != 'delete') {
                  final issues = await checkUploadEligibility(
                    selectedModule: selectedModule,
                    transactionId: transactionId,
                    uuid: header.uuid,
                  );
                  if (issues.isNotEmpty) {
                    throw const ManualTransactionFailure('validation');
                  }
                  await TransactionCloudReferences(
                    db,
                    petugasScope: profile.petugasScope,
                    masterScope: profile.masterScope,
                  ).prepare(transactionId);
                }
                final receipt = switch (operation) {
                  'create' => await cloud.pushCreate(transactionId),
                  'update' => await cloud.pushUpdate(transactionId),
                  'delete' => await cloud.pushDelete(transactionId),
                  _ => throw const ManualTransactionFailure('validation'),
                };
                // Repository has durably verified and recorded the server ack.
                result = TransactionManualResult(count: 1, receipt: receipt);
              }
            } else {
              if (!_permission(s, 'read')) {
                throw const ManualTransactionFailure('forbidden');
              }
              var count = 0;
              for (var n = 0; n < maxPages; n++) {
                final batch = await cloud.pullBatch(
                  limit: pageSize,
                  allowedDomains: const {'notaris', 'ppat'},
                  confirmAcknowledgements: true,
                );
                count += batch.count;
                result = TransactionManualResult(
                  count: count,
                  cursor: batch.cursor,
                  more: batch.hasMore,
                );
                if (!batch.hasMore) break;
              }
              if (result!.more) throw const ManualTransactionFailure('bounded');
            }
            _authorize();
            return result!.count;
          } catch (e) {
            throw ManualTransactionFailure(_code(e));
          }
        },
      );
      return result!;
    } on ManualTransactionFailure catch (e) {
      if (e.code == 'bounded') return result!;
      rethrow;
    } finally {
      _inFlight.remove(flight);
    }
  }

  String _code(Object e) {
    if (e is ManualTransactionFailure) return e.code;
    if (e is DioException) {
      if (e.error is ManualTransactionFailure) {
        return (e.error as ManualTransactionFailure).code;
      }
      final status = e.response?.statusCode;
      if (status == 401) return 'unauthorized';
      if (status == 403) return 'forbidden';
      if (status == 409) return 'conflict';
      if (status == 410) return 'feed_expired';
      if (status == 400 || status == 422) return 'validation';
      if (status != null && status >= 500) return 'server';
      if ({
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      }.contains(e.type)) {
        return 'timeout';
      }
      if (e.type == DioExceptionType.connectionError) return 'offline';
    }
    if (e is StateError) {
      if (e.message.toString().contains('Unselected')) {
        return 'unsupported_domain';
      }
      if (e.message.toString().contains('Dirty') ||
          e.message.toString().contains('dirty')) {
        return 'conflict';
      }
      return 'validation';
    }
    return 'unknown';
  }
}
