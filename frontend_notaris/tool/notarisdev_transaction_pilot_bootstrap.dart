import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/services/development_transaction_pilot_bootstrap.dart';
import 'package:frontend_notaris/services/development_transaction_pilot_profile.dart';
import 'package:frontend_notaris/services/transaction_manual_sync_service.dart';

void main() {
  final env = Platform.environment;
  final manifest = env['DEVELOPMENT_PILOT_BOOTSTRAP_MANIFEST'];
  if (manifest == null) {
    test(
      'LocalBootstrap requires a reviewed stage manifest',
      () {},
      skip: true,
    );
    return;
  }
  test('commit reviewed Master replay and one frozen local CREATE', () async {
    final profile = DevelopmentTransactionPilotProfile.open(
      manifest,
      env['DEVELOPMENT_PILOT_MANIFEST_SHA256']!,
    );
    final token = env['DEVELOPMENT_PILOT_BOOTSTRAP_TOKEN'];
    if (profile.upload ||
        token == null ||
        token.isEmpty ||
        profile.checkpointFile.existsSync()) {
      throw const ManualTransactionFailure('scope');
    }
    final approved = File(profile.data['check'] as String);
    final check = jsonDecode(approved.readAsStringSync()) as Map;
    if (pilotFileHash(approved) != profile.data['check_sha256'] ||
        check['backup'] != 'matches' ||
        check['sqlite'] != profile.sqlitePath ||
        pilotFileHash(File(profile.sqlitePath)) != check['sqlite_sha256'] ||
        check['binding']['petugas_scope'] != profile.petugasScope ||
        check['binding']['proposed_master_scope'] != profile.masterScope ||
        check['binding']['proposed_transaction_scope'] !=
            profile.transactionScope ||
        pilotFileHash(File(profile.data['backup'] as String)) !=
            profile.data['backup_sha256']) {
      throw const ManualTransactionFailure('scope');
    }
    await profile.attest('Bearer $token');
    await profile.bootstrapLock.create(exclusive: true);
    await profile.bootstrapLock.writeAsString(
      '${profile.data['check_sha256']}\n',
      flush: true,
    );
    final http = Dio(
      BaseOptions(
        baseUrl: profile.baseUrl,
        followRedirects: false,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    final db = profile.openDatabase();
    Map<String, dynamic> receipt;
    try {
      final dirty = (check['binding']['dirty_transactions'] as List)
          .map((r) => r['uuid'] as String)
          .toList();
      receipt = await bootstrapDevelopmentPilot(
        db: db,
        profile: profile,
        masterHttp: http,
        reviewedDirtyUuids: dirty,
        masterFeedHash: check['master_feed_sha256'] as String,
      );
      await validateDevelopmentPilotCheckpoint(db, profile, http, receipt);
    } finally {
      await db.close();
      http.close();
    }
    final temp = File('${profile.manifest.parent.path}/local-checkpoint.json');
    await temp.writeAsString(
      jsonEncode({...receipt, 'check_sha256': profile.data['check_sha256']}),
      flush: true,
    );
    await temp.rename(profile.checkpointFile.path);
  });
}
