import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../repositories/pekerjaan_notaris_cloud_repository.dart';
import '../repositories/transaction_cloud_repository.dart';
import '../repositories/transaction_repository.dart';
import 'transaction_manual_sync_service.dart';

String pilotHash(String text) => sha256.convert(utf8.encode(text)).toString();

const pilotLabel = 'PILOT-DEV-NOTARIS-01';
const pilotMasterUuid = '19566301-0540-4e1a-8b17-948bc3dec96e';
const pilotPriceUuid = 'ef324a08-d51f-49ea-b4f9-08a0c8305d96';
const pilotCategoryUuid = 'fa000002-0000-4000-8000-000000000001';
const pilotApplicantUuid = 'fa000001-0000-4000-8000-000000000001';
const pilotOfficerUuid = 'e85be759-1e15-4b2f-8243-120131475207';

Future<String> pilotLegacyFingerprint(AppDatabase db) async {
  final snapshot = <String, Object>{};
  for (final entry in const {
    'transaksis': 'id IN (1,2,3)',
    'transaksi_details': 'transaksi_id IN (1,2,3)',
    'transaksi_proses': 'transaksi_id IN (1,2,3)',
    'transaksi_riwayat_pembayaran': 'transaksi_id IN (1,2,3)',
    'transaksi_proses_riwayat': 'transaksi_proses_id IN (SELECT id FROM transaksi_proses WHERE transaksi_id IN (1,2,3))',
    'petugas_sync_feed': 'id=1',
  }.entries) {
    snapshot[entry.key] =
        (await db
                .customSelect(
                  'SELECT * FROM ${entry.key} WHERE ${entry.value} ORDER BY id',
                )
                .get())
            .map((r) => r.data)
            .toList();
  }
  return pilotHash(jsonEncode(snapshot));
}

Object? _sortJson(Object? value) {
  if (value is Map) {
    return {
      for (final key in (value.keys.cast<String>().toList()..sort()))
        key: _sortJson(value[key]),
    };
  }
  if (value is List) return value.map(_sortJson).toList();
  return value;
}

String pilotMasterFeedHash(Map page) {
  if (page['next_cursor'] != 6 ||
      page['has_more'] != false ||
      (page['changes'] as List).length != 6) {
    throw const ManualTransactionFailure('scope');
  }
  final events = (page['changes'] as List).cast<Map>().map((event) {
    final aggregate = event['aggregate'] as Map;
    return {
      'sequence': event['sequence'],
      'revision': event['revision'],
      'operation': event['operation'],
      'uuid': aggregate['uuid'],
      'payload_uuid': aggregate['uuid'],
      'nama': event['operation'] == 'delete' ? null : aggregate['nama'],
      'harga': aggregate['harga'],
      'proses': aggregate['proses'],
    };
  }).toList();
  return pilotHash(jsonEncode(_sortJson(events)));
}

/// Caller checks the target, backup and approved input, and owns a durable attempt lock.
/// One transaction includes the feed cursor, draft and frozen mutation journal.
Future<Map<String, dynamic>> bootstrapDevelopmentPilot({
  required AppDatabase db,
  required TransactionManualProfile profile,
  required Dio masterHttp,
  required List<String> reviewedDirtyUuids,
  required String masterFeedHash,
}) => db.transaction(() async {
  await profile.validate(db);
  final existing = await db
      .customSelect(
        'SELECT id,uuid FROM transaksis WHERE is_sync_dirty=1 ORDER BY id',
      )
      .get();
  if (reviewedDirtyUuids.length != 3 ||
      jsonEncode(existing.map((r) => r.read<int>('id')).toList()) !=
          '[1,2,3]' ||
      jsonEncode(existing.map((r) => r.read<String>('uuid')).toList()) !=
          jsonEncode(reviewedDirtyUuids) ||
      (await db
                  .customSelect('SELECT count(*) AS n FROM transaksis')
                  .getSingle())
              .read<int>('n') !=
          3) {
    throw const ManualTransactionFailure('scope');
  }
  for (final table in const [
    'transaction_cloud_identity',
    'transaction_cloud_pending',
    'transaction_cloud_feed',
    'pekerjaan_notaris_sync_identity',
    'pekerjaan_notaris_sync_pending',
    'pekerjaan_notaris_sync_feed',
    'pekerjaan_ppat_sync_identity',
    'pekerjaan_ppat_sync_pending',
    'pekerjaan_ppat_sync_feed',
  ]) {
    if ((await db.customSelect('SELECT 1 FROM $table LIMIT 1').get())
        .isNotEmpty) {
      throw const ManualTransactionFailure('scope');
    }
  }
  final before = await pilotLegacyFingerprint(db);
  final feed = masterHttp.clone();
  feed.interceptors.add(
    InterceptorsWrapper(
      onResponse: (response, handler) {
        try {
          if (pilotMasterFeedHash(response.data as Map) != masterFeedHash) {
            throw const ManualTransactionFailure('scope');
          }
          handler.next(response);
        } catch (error) {
          handler.reject(
            DioException(requestOptions: response.requestOptions, error: error),
          );
        }
      },
    ),
  );
  try {
    final cursor = await PekerjaanNotarisCloudRepository(
      db,
      feed,
      scope: profile.masterScope,
    ).pullPage();
    if (cursor != 6) throw const ManualTransactionFailure('scope');
  } finally {
    feed.close();
  }
  final master = await db
      .customSelect(
        '''SELECT m.id,m.nama,c.nama AS category,h.estimasi_waktu
    FROM pekerjaan_notaris m JOIN pekerjaan_notaris_sync_identity i ON i.local_uuid=m.uuid
    JOIN pekerjaan_notaris_harga h ON h.pekerjaan_notaris_id=m.id
    JOIN pekerjaan_kategori c ON c.id=h.kategori_pekerjaan_id
    WHERE m.uuid=? AND i.cloud_uuid=m.uuid AND i.revision=1 AND i.scope=? AND m.status=1
      AND h.uuid=? AND h.harga='100000' AND c.uuid=? AND h.status=1 AND c.status=1''',
        variables: [
          Variable(pilotMasterUuid),
          Variable(profile.masterScope),
          Variable(pilotPriceUuid),
          Variable(pilotCategoryUuid),
        ],
      )
      .getSingle();
  final applicant = await db
      .customSelect(
        'SELECT id,uuid FROM pemohons WHERE uuid=?',
        variables: [Variable(pilotApplicantUuid)],
      )
      .getSingle();
  final officer = await db
      .customSelect(
        '''SELECT p.id,p.uuid FROM petugas p JOIN petugas_identity_map i ON i.local_uuid=p.uuid
    WHERE i.cloud_uuid=? AND i.server_id=101''',
        variables: [Variable(pilotOfficerUuid)],
      )
      .getSingle();
  final masterId = master.read<int>('id');
  final processes = await db
      .customSelect(
        'SELECT id,uuid,nama,detail FROM pekerjaan_notaris_proses WHERE pekerjaan_notaris_id=? AND status=1 ORDER BY id',
        variables: [Variable(masterId)],
      )
      .get();
  final processSnapshot = <Map<String, dynamic>>[];
  for (final process in processes) {
    final attrs = await db
        .customSelect(
          'SELECT atribut FROM pekerjaan_notaris_atributs WHERE proses_pekerjaan_notaris_id=? AND status=1 ORDER BY id',
          variables: [Variable(process.read<int>('id'))],
        )
        .get();
    processSnapshot.add({
      'id': process.read<String>('uuid'),
      'name': process.read<String>('nama'),
      'detail': process.readNullable<String>('detail'),
      'attributes': attrs
          .map((a) => a.readNullable<String>('atribut'))
          .toList(),
    });
  }
  final id = await TransactionRepository(db).save(
    nomorTransaksi: pilotLabel,
    jenisTransaksi: 'notaris',
    pemohonId: applicant.read<int>('id'),
    pemohonUuid: applicant.read<String>('uuid'),
    petugasId: officer.read<int>('id'),
    petugasUuid: officer.read<String>('uuid'),
    status: 'Baru',
    tanggalTransaksi: DateTime.now(),
    catatan: pilotLabel,
    jobs: [
      TransactionJobInput(
        jenisPekerjaan: 'notaris',
        namaPekerjaan: master.read<String>('nama'),
        biayaLayanan: 100000,
        pekerjaanNotarisId: masterId,
        hargaUuid: pilotPriceUuid,
        kategoriUuid: pilotCategoryUuid,
        kategoriSnapshot: master.read<String>('category'),
        estimasiWaktuSnapshot: master.read<String>('estimasi_waktu'),
        prosesSnapshot: jsonEncode(processSnapshot),
        detailUuid: const Uuid().v4(),
      ),
    ],
  );
  final cloud = TransactionCloudRepository(
    db,
    masterHttp,
    scope: profile.transactionScope,
    petugasScope: profile.petugasScope,
    masterScope: profile.masterScope,
  );
  final payload = await cloud.stageCreate(id);
  final body = jsonDecode(payload) as Map;
  if (reviewedDirtyUuids.contains(body['uuid']) ||
      await pilotLegacyFingerprint(db) != before ||
      (await db.customSelect('PRAGMA foreign_key_check').get()).isNotEmpty) {
    throw const ManualTransactionFailure('scope');
  }
  final receipt = <String, dynamic>{
    'status': 'LOCAL_COMMITTED_PENDING',
    'id': id,
    'uuid': body['uuid'],
    'mutation_id': body['mutation_id'],
    'payload_sha256': pilotHash(payload),
    'identity': null,
    'mutation_state': 'pending',
    'scope': profile.transactionScope,
    'master_scope': profile.masterScope,
    'petugas_scope': profile.petugasScope,
    'master_cursor': 6,
    'legacy_sha256': before,
    'master_feed_sha256': masterFeedHash,
  };
  await validateDevelopmentPilotCheckpoint(db, profile, masterHttp, receipt);
  return receipt;
});

Future<void> validateDevelopmentPilotCheckpoint(
  AppDatabase db,
  TransactionManualProfile profile,
  Dio http,
  Map checkpoint,
) => db.transaction(() async {
  final uuid = checkpoint['uuid'] as String;
  final mutationId = checkpoint['mutation_id'] as String;
  final pending =
      (await db.customSelect('SELECT * FROM transaction_cloud_pending').get())
          .single;
  final payload = pending.read<String>('payload');
  final header = await (db.select(
    db.transaksis,
  )..where((r) => r.id.equals(checkpoint['id'] as int))).getSingle();
  final identity = await db
      .customSelect('SELECT 1 FROM transaction_cloud_identity LIMIT 1')
      .get();
  final masterFeed = await db
      .customSelect('SELECT scope,cursor FROM pekerjaan_notaris_sync_feed')
      .getSingle();
  final txFeed = await db
      .customSelect('SELECT scope,cursor FROM transaction_cloud_feed')
      .getSingle();
  if (checkpoint['status'] != 'LOCAL_COMMITTED_PENDING' ||
      checkpoint['scope'] != profile.transactionScope ||
      checkpoint['petugas_scope'] != profile.petugasScope ||
      checkpoint['master_scope'] != profile.masterScope ||
      header.uuid != uuid ||
      header.id <= 3 ||
      (await db
                  .customSelect('SELECT count(*) AS n FROM transaksis')
                  .getSingle())
              .read<int>('n') !=
          4 ||
      !header.isSyncDirty ||
      header.deletedAt != null ||
      header.jenisTransaksi != 'notaris' ||
      identity.isNotEmpty ||
      pending.read<String>('local_uuid') != uuid ||
      pending.read<String>('mutation_id') != mutationId ||
      pending.read<String>('state') != 'pending' ||
      pending.read<String>('operation') != 'create' ||
      masterFeed.read<String>('scope') != profile.masterScope ||
      masterFeed.read<int>('cursor') != 6 ||
      txFeed.read<String>('scope') != profile.transactionScope ||
      txFeed.read<int>('cursor') != 0 ||
      pilotHash(payload) != checkpoint['payload_sha256'] ||
      await pilotLegacyFingerprint(db) != checkpoint['legacy_sha256']) {
    throw const ManualTransactionFailure('scope');
  }
  final cloud = TransactionCloudRepository(
    db,
    http,
    scope: profile.transactionScope,
    petugasScope: profile.petugasScope,
    masterScope: profile.masterScope,
  );
  if (await cloud.currentCreatePayload(header.id, mutationId) != payload) {
    throw const ManualTransactionFailure('scope');
  }
});
