import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../repositories/pekerjaan_ppat_cloud_repository.dart';
import 'development_transaction_pilot_bootstrap.dart';
import 'transaction_manual_sync_service.dart';

void verifyReviewedPilotFeed(Response<dynamic> response, String fingerprint) {
  final bytes = response.data;
  if (bytes is! List<int> || sha256.convert(bytes).toString() != fingerprint) {
    throw const ManualTransactionFailure('scope');
  }
  response.data = jsonDecode(utf8.decode(bytes));
}

/// Compare application data to the reviewed recovery copy. Sync log attempts
/// are recorded outside the replay, so they are not part of the data baseline.
Future<String> pilotDownloadDataFingerprint(AppDatabase db) async {
  final tables = await db.customSelect('''SELECT name FROM sqlite_master
    WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name!='sync_logs'
    ORDER BY name''').get();
  return pilotHash(
    jsonEncode({
      for (final row in tables)
        row.read<String>(
          'name',
        ): (await db
                .customSelect(
                  'SELECT * FROM "${row.read<String>('name').replaceAll('"', '""')}" ORDER BY rowid',
                )
                .get())
            .map((r) => r.data)
            .toList(),
    }),
  );
}

/// A single commit includes both feeds, ACK confirmation, and postconditions.
/// A crash or failed fetch leaves neither cursor advanced.
Future<TransactionManualResult> applyReviewedPilotDownload({
  required AppDatabase db,
  required Dio http,
  required TransactionManualProfile profile,
  required String baseline,
  required Map<String, dynamic> review,
  required Future<TransactionManualResult> Function() pull,
}) => db.transaction(() async {
  Future<int> cursor(String table) async =>
      (await db.customSelect('SELECT cursor FROM $table').getSingleOrNull())
          ?.read<int>('cursor') ??
      0;
  Future<bool> preserved() async =>
      await pilotLegacyFingerprint(db) == review['legacy_sha256'] &&
      await cursor('pekerjaan_notaris_sync_feed') == 6 &&
      await cursor('petugas_sync_feed') == 4;
  final uuid = review['uuid'] as String;
  Future<Map<String, dynamic>> pilot() async =>
      (await db
              .customSelect(
                '''
    SELECT t.*, i.scope, i.cloud_uuid, i.revision, i.final_number, i.snapshot
    FROM transaksis t JOIN transaction_cloud_identity i ON i.local_uuid=t.uuid
    WHERE t.uuid=?''',
                variables: [Variable(uuid)],
              )
              .getSingle())
          .data;
  final before = await pilot();
  final ack = await db
      .customSelect(
        'SELECT local_uuid,mutation_id,state FROM transaction_cloud_pending',
      )
      .getSingleOrNull();
  if (await pilotDownloadDataFingerprint(db) != baseline ||
      !await preserved() ||
      await cursor('pekerjaan_ppat_sync_feed') != 0 ||
      await cursor('transaction_cloud_feed') != 0 ||
      before['scope'] != profile.transactionScope ||
      before['cloud_uuid'] != uuid ||
      before['revision'] != 1 ||
      before['final_number'] != review['final_number'] ||
      before['no_akta'] != review['final_number'] ||
      before['is_sync_dirty'] != 0 ||
      ack?.data['local_uuid'] != uuid ||
      ack?.data['mutation_id'] != review['mutation_id'] ||
      ack?.data['state'] != 'acked') {
    throw const ManualTransactionFailure('scope');
  }
  final ppat = PekerjaanPpatCloudRepository(
    db,
    http,
    scope: profile.masterScope,
  );
  if (await ppat.pullPage(limit: 20) != 6) {
    throw const ManualTransactionFailure('validation');
  }
  final result = await pull();
  if (result.count != 9 || result.cursor != 9 || result.more) {
    throw const ManualTransactionFailure('validation');
  }
  final applied = await pilotDownloadDataFingerprint(db);
  final repeat = await pull();
  final integrity = await db.customSelect('PRAGMA integrity_check').get();
  final verified = await db.customSelect(
    '''SELECT
    (SELECT count(*)=5 AND count(t.deleted_at)=2
      FROM transaction_cloud_identity i JOIN transaksis t ON t.uuid=i.local_uuid)
    AND (SELECT count(*)=3 AND sum(p.status=0 AND p.deleted_at IS NOT NULL)=2
      AND sum(p.status=1 AND p.deleted_at IS NULL)=1
      FROM pekerjaan_ppat_sync_identity i JOIN pekerjaan_ppat p ON p.uuid=i.local_uuid)
    AND NOT EXISTS (SELECT 1 FROM transaksis GROUP BY no_akta HAVING count(*)>1) AS ok''',
  ).getSingle();
  if (await ppat.pullPage(limit: 20) != 6 ||
      repeat.count != 0 ||
      repeat.cursor != 9 ||
      repeat.more ||
      await pilotDownloadDataFingerprint(db) != applied ||
      verified.read<int>('ok') != 1 ||
      !await preserved() ||
      jsonEncode(await pilot()) != jsonEncode(before) ||
      (await db.customSelect('SELECT 1 FROM transaction_cloud_pending').get())
          .isNotEmpty ||
      (await db.customSelect('PRAGMA foreign_key_check').get()).isNotEmpty ||
      integrity.length != 1 ||
      integrity.single.data.values.single != 'ok') {
    throw const ManualTransactionFailure('validation');
  }
  return result;
});
