import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

import '../database/app_database.dart';
import 'development_transaction_pilot_bootstrap.dart';
import 'development_transaction_pilot_download.dart';
import 'transaction_manual_sync_service.dart';

String pilotFileHash(File file) =>
    sha256.convert(file.readAsBytesSync()).toString();

/// An explicit, hash-pinned development launch. The disposable factory stays strict.
class DevelopmentTransactionPilotProfile extends TransactionManualProfile {
  DevelopmentTransactionPilotProfile._(this.manifest, this.data, this.hash)
    : super(
        sqlitePath: data['sqlite'] as String,
        baseUrl: 'http://127.0.0.1:8081/api/v1',
        databaseTarget: '127.0.0.1:5432/notarisdev',
        deployment: 'NOTARISDEV SYNTHETIC v1',
        device: 'ndpetugas-b49369a4fdaf38d731905f080cddc68c',
        generation: '14af5452144b42d0be2ad88bac41b656',
        accountId: 2001,
        groupId: 11,
      );

  factory DevelopmentTransactionPilotProfile.open(String path, String hash) {
    final file = File(path);
    final bytes = file.readAsBytesSync();
    if (sha256.convert(bytes).toString() != hash) {
      throw const ManualTransactionFailure('scope');
    }
    final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    final profile = DevelopmentTransactionPilotProfile._(
      file,
      Map.unmodifiable(data),
      hash,
    );
    profile.validateLocation();
    return profile;
  }

  final File manifest;
  final Map<String, dynamic> data;
  final String hash;
  String get stage => data['stage'] as String;
  bool get upload => stage == 'UploadPilot';
  bool get downloadOnly => stage == 'DownloadOnly';
  @override
  bool get requiresPpatBootstrap => downloadOnly;
  String? _downloadBaseline;
  String get approvedUuid => data['uuid'] as String? ?? '';
  File get uploadLock => File(
    p.join(
      manifest.parent.parent.path,
      'development-transaction-pilot-upload-attempt.lock',
    ),
  );
  File get bootstrapLock => File(
    p.join(
      manifest.parent.parent.path,
      'development-transaction-pilot-bootstrap.lock',
    ),
  );
  File get checkpointFile => File(
    p.join(
      manifest.parent.parent.path,
      'development-transaction-pilot-checkpoint.json',
    ),
  );

  @override
  String get petugasScope => jsonEncode([
    baseUrl,
    'notarisdev',
    generation,
    accountId,
    device,
    sqlitePath,
  ]);

  @override
  String validateLocation() {
    final appData = Platform.environment['APPDATA'];
    if (appData == null ||
        Platform.environment['NOTARIS_DEV_UI_SMOKE'] == '1' ||
        !{'LocalBootstrap', 'UploadPilot', 'DownloadOnly'}.contains(stage) ||
        pilotFileHash(manifest) != hash ||
        !p
            .basename(manifest.parent.path)
            .startsWith('development-pilot-run-') ||
        p.basename(manifest.parent.parent.path) != '.local') {
      throw const ManualTransactionFailure('scope');
    }
    final expected = p.join(
      appData,
      'com.notaris',
      'frontend_notaris',
      'notarisdev',
      generation,
      'offline.sqlite',
    );
    if (!p.equals(sqlitePath, expected) ||
        !File(expected).existsSync() ||
        !p.equals(
          AppDatabase.petugasBaselineFilePath(File(expected)),
          expected,
        )) {
      throw const ManualTransactionFailure('scope');
    }
    final plan = File(data['runtime_plan'] as String);
    if (!p.equals(plan.parent.path, manifest.parent.path) ||
        pilotFileHash(plan) != data['runtime_sha256']) {
      throw const ManualTransactionFailure('scope');
    }
    final runtime = jsonDecode(plan.readAsStringSync()) as Map;
    final pilot = runtime['pilot'] as Map;
    if (runtime['target'] != databaseTarget ||
        pilot['stage'] != stage ||
        (upload &&
            (pilot['uuid'] != approvedUuid ||
                pilot['mutation_id'] != data['mutation_id'] ||
                pilot['payload_sha256'] != data['payload_sha256'] ||
                pilotFileHash(checkpointFile) != data['checkpoint_sha256'] ||
                pilotFileHash(File(data['recovery_backup'] as String)) !=
                    data['recovery_sha256']))) {
      throw const ManualTransactionFailure('scope');
    }
    if (downloadOnly) {
      final reviewFile = File(data['download_review'] as String);
      final review = _downloadReview;
      if (!p.equals(reviewFile.parent.path, manifest.parent.parent.path) ||
          p.basename(reviewFile.path) !=
              'development-transaction-pilot-download-check.json' ||
          pilotFileHash(reviewFile) != data['download_review_sha256'] ||
          review['sqlite'] != expected ||
          review['target'] != databaseTarget ||
          review['base_url'] != baseUrl ||
          review['deployment'] != deployment ||
          review['account_id'] != accountId ||
          review['group_id'] != groupId ||
          review['device'] != device ||
          review['generation'] != generation ||
          !_sameFeeds(pilot['feeds'], review['feeds']) ||
          review['backup'] != data['backup'] ||
          review['backup_sha256'] != data['backup_sha256'] ||
          pilotFileHash(File(review['backup'] as String)) !=
              review['backup_sha256']) {
        throw const ManualTransactionFailure('scope');
      }
    }
    return expected;
  }

  Map<String, dynamic> get _downloadReview =>
      jsonDecode(File(data['download_review'] as String).readAsStringSync())
          as Map<String, dynamic>;

  bool _sameFeeds(Object? a, Object? b) =>
      a is Map &&
      b is Map &&
      a.length == 5 &&
      b.length == 5 &&
      a.keys.every((key) => a[key] is String && a[key] == b[key]);

  AppDatabase openDatabase() {
    final location = validateLocation();
    if (downloadOnly &&
        ([
              '-wal',
              '-shm',
              '-journal',
            ].any((suffix) => File('$location$suffix').existsSync()) ||
            pilotFileHash(File(location)) !=
                _downloadReview['source_sha256'])) {
      throw const ManualTransactionFailure('scope');
    }
    return _openV19(File(location));
  }

  AppDatabase _openV19(File file, {bool queryOnly = false}) =>
      AppDatabase.forTesting(
        NativeDatabase(
          file,
          setup: (db) {
            if (db.select('PRAGMA user_version').single['user_version'] != 19) {
              throw const ManualTransactionFailure('scope');
            }
            if (queryOnly) db.execute('PRAGMA query_only=ON');
          },
        ),
      );

  @override
  Future<void> validate(AppDatabase db) async {
    await super.validate(db);
    final rows = await db
        .customSelect(
          'SELECT scope,cursor,blocked FROM petugas_sync_feed WHERE id=1',
        )
        .get();
    if (rows.length != 1 ||
        rows.single.read<String>('scope') != petugasScope ||
        rows.single.read<int>('cursor') != 4 ||
        rows.single.readNullable<String>('blocked') != null) {
      throw const ManualTransactionFailure('scope');
    }
    if (upload) {
      if (uploadLock.existsSync()) {
        throw const ManualTransactionFailure('scope');
      }
      final checkpoint = jsonDecode(checkpointFile.readAsStringSync()) as Map;
      if (checkpoint['uuid'] != approvedUuid ||
          checkpoint['mutation_id'] != data['mutation_id'] ||
          checkpoint['payload_sha256'] != data['payload_sha256']) {
        throw const ManualTransactionFailure('scope');
      }
      final noNetwork = Dio();
      try {
        await validateDevelopmentPilotCheckpoint(
          db,
          this,
          noNetwork,
          checkpoint,
        );
      } finally {
        noNetwork.close();
      }
    }
    if (downloadOnly) {
      final cursor = await db
          .customSelect('SELECT cursor FROM transaction_cloud_feed')
          .getSingleOrNull();
      if (cursor?.read<int>('cursor') == 9) {
        throw const ManualTransactionFailure('download_complete');
      }
      if (_downloadBaseline == null) {
        final backup = _openV19(
          File(data['backup'] as String),
          queryOnly: true,
        );
        try {
          _downloadBaseline = await pilotDownloadDataFingerprint(backup);
        } finally {
          await backup.close();
        }
      }
      if (await pilotDownloadDataFingerprint(db) != _downloadBaseline) {
        throw const ManualTransactionFailure('scope');
      }
    }
  }

  @override
  void validateSelection(
    String module,
    ManualSyncDirection direction, [
    String? uuid,
  ]) {
    if (downloadOnly &&
        module == TransactionManualSyncService.feedModule &&
        direction == ManualSyncDirection.download &&
        (uuid == null || uuid.isEmpty)) {
      return;
    }
    if (!upload ||
        module != 'transaksi_notaris' ||
        direction != ManualSyncDirection.upload ||
        (uuid != null && uuid != approvedUuid) ||
        uploadLock.existsSync()) {
      throw const ManualTransactionFailure('scope');
    }
  }

  Future<void> attest(Object? bearer) async {
    validateLocation();
    final probe = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        followRedirects: false,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ),
    );
    try {
      final response = await probe.get(
        '/development/transaction-acceptance',
        options: Options(headers: {'Authorization': bearer}),
      );
      final d = response.data['data'] as Map;
      if (d['database'] != 'notarisdev' ||
          d['host'] != '127.0.0.1' ||
          d['port'] != 5432 ||
          d['role'] != 'nd_app_14af5452144b' ||
          d['marker'] != deployment ||
          d['plan_sha256'] != data['runtime_sha256'] ||
          d['account_id'] != accountId ||
          d['group_id'] != groupId ||
          d['pilot_stage'] != stage ||
          (downloadOnly && !_sameFeeds(d['feeds'], _downloadReview['feeds']))) {
        throw const ManualTransactionFailure('scope');
      }
    } finally {
      probe.close(force: true);
    }
  }

  @override
  Future<void> verifyRequest(RequestOptions request) async {
    if (downloadOnly) {
      _downloadFeedKey(request);
      await attest(request.headers['Authorization']);
      request.responseType = ResponseType.bytes;
      return;
    }
    if (!upload ||
        request.method != 'POST' ||
        request.uri.origin != 'http://127.0.0.1:8081' ||
        request.uri.path != '/api/v1/transaksi-notaris/sync/create' ||
        pilotHash(jsonEncode(request.data)) != data['payload_sha256']) {
      throw const ManualTransactionFailure('scope');
    }
    await attest(request.headers['Authorization']);
    // A lost response is a stop condition across process restarts.
    await uploadLock.create(exclusive: true);
    await uploadLock.writeAsString(
      '${data['checkpoint_sha256']}\n',
      flush: true,
    );
    request.headers['X-Notaris-Acceptance'] = data['runtime_sha256'];
  }

  String _downloadFeedKey(RequestOptions request) {
    if (request.method != 'GET' ||
        request.uri.origin != Uri.parse(baseUrl).origin ||
        request.queryParameters.length != 2 ||
        request.queryParameters['limit'] != 20) {
      throw const ManualTransactionFailure('scope');
    }
    return switch ((request.uri.path, request.queryParameters['cursor'])) {
      ('/api/v1/pekerjaan-ppat/sync/pull', 0) => 'ppat',
      ('/api/v1/pekerjaan-ppat/sync/pull', 6) => 'ppat_tail',
      ('/api/v1/transaksi-notaris/sync/pull', 0) => 'transaction',
      ('/api/v1/transaksi-notaris/sync/pull', 9) => 'transaction_tail',
      _ => throw const ManualTransactionFailure('scope'),
    };
  }

  @override
  void verifyResponse(Response<dynamic> response) {
    if (!downloadOnly) return;
    final key = _downloadFeedKey(response.requestOptions);
    verifyReviewedPilotFeed(
      response,
      (_downloadReview['feeds'] as Map)[key] as String,
    );
  }

  @override
  Future<TransactionManualResult> applyDownload(
    AppDatabase db,
    Dio http,
    Future<TransactionManualResult> Function() pull,
  ) => applyReviewedPilotDownload(
    db: db,
    http: http,
    profile: this,
    baseline: _downloadBaseline!,
    review: _downloadReview,
    pull: pull,
  );
}
