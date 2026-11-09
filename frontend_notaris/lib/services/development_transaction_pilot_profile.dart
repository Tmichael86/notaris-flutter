import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

import '../database/app_database.dart';
import 'development_transaction_pilot_bootstrap.dart';
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
        !{'LocalBootstrap', 'UploadPilot'}.contains(stage) ||
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
    return expected;
  }

  AppDatabase openDatabase() => AppDatabase.forTesting(
    NativeDatabase(
      File(validateLocation()),
      setup: (db) {
        if (db.select('PRAGMA user_version').single['user_version'] != 19) {
          throw const ManualTransactionFailure('scope');
        }
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
  }

  @override
  void validateSelection(
    String module,
    ManualSyncDirection direction, [
    String? uuid,
  ]) {
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
          d['pilot_stage'] != stage) {
        throw const ManualTransactionFailure('scope');
      }
    } finally {
      probe.close(force: true);
    }
  }

  @override
  Future<void> verifyRequest(RequestOptions request) async {
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
}
