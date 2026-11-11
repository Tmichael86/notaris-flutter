import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/models/auth_session.dart';
import 'package:frontend_notaris/providers/auth_provider.dart';
import 'package:frontend_notaris/services/auth_service.dart';
import 'package:frontend_notaris/services/transaction_manual_sync_service.dart';
import 'package:frontend_notaris/repositories/transaction_repository.dart';

const uiApplicant = '00000000-0000-4000-8000-000000000001',
    uiOfficer = '00000000-0000-4000-8000-000000000002',
    uiCloudOfficer = '00000000-0000-4000-8000-000000000003',
    uiJob = '00000000-0000-4000-8000-000000000004',
    uiPrice = '00000000-0000-4000-8000-000000000005',
    uiCategory = '00000000-0000-4000-8000-000000000006';
AuthSession uiSession({
  String token = 'test-ui-token',
  bool permission = true,
  String? groupType,
  int userId = 1,
}) => AuthSession(
  token: token,
  userId: userId,
  groupId: 1,
  userName: 'Fixture',
  groupName: 'Fixture',
  groupType: groupType,
  user: const {},
  sidebars: [
    {
      'sidebar': {'sidebar_kode': 'transaksi', 'status': 1},
      'read': permission ? 1 : 0,
      'create': permission ? 1 : 0,
      'update': permission ? 1 : 0,
      'delete': permission ? 1 : 0,
    },
  ],
  verifiedAt: DateTime.now(),
);

class TransactionUiAuth extends AuthController {
  TransactionUiAuth(AuthSession session) : super(AuthService(dio: Dio())) {
    state = AuthState.authenticated(session);
  }
}

Future<void> seedTransactionUiReferences(
  AppDatabase db,
  TransactionManualProfile profile,
) async {
  await db.customStatement(
    "INSERT INTO pemohons(id,uuid,nama,is_sync_dirty,last_synced_at) VALUES(10,?,'Reviewed applicant',0,1)",
    [uiApplicant],
  );
  await db.customStatement(
    "INSERT INTO petugas(id,uuid,nama,email,is_sync_dirty) VALUES(20,?,'Reviewed officer','fixture@example.invalid',0)",
    [uiOfficer],
  );
  await db.customStatement(
    "INSERT INTO petugas_identity_map(local_uuid,cloud_uuid,server_id,state,evidence,created_at,updated_at) VALUES(?,?,104,'server_only','authenticated test fixture UUID mapping',1,1)",
    [uiOfficer, uiCloudOfficer],
  );
  await db.customStatement(
    'INSERT INTO petugas_sync_feed(id,scope,cursor) VALUES(1,?,4)',
    [profile.petugasScope],
  );
  await db.customStatement(
    'INSERT INTO petugas_sync_journal(local_uuid,row_version) VALUES(?,1)',
    [uiOfficer],
  );
  await db.customStatement(
    "INSERT INTO pekerjaan_kategori(id,uuid,nama,is_sync_dirty,last_synced_at) VALUES(30,?,'Reviewed category',0,1)",
    [uiCategory],
  );
  for (final domain in ['notaris', 'ppat']) {
    await db.customStatement(
      "INSERT INTO pekerjaan_$domain(id,uuid,nama,is_sync_dirty) VALUES(40,?,'Reviewed $domain job',0)",
      [uiJob],
    );
    await db.customStatement(
      'INSERT INTO pekerjaan_${domain}_sync_identity(local_uuid,cloud_uuid,scope,revision) VALUES(?,?,?,1)',
      [uiJob, uiJob, profile.masterScope],
    );
    await db.customStatement(
      "INSERT INTO pekerjaan_${domain}_harga(uuid,pekerjaan_${domain}_id,kategori_pekerjaan_id,harga,estimasi_waktu,is_sync_dirty) VALUES(?,40,30,'100','2 hari',0)",
      [uiPrice],
    );
  }
}

Future<int> createTransactionUiRecord(AppDatabase db, String domain) =>
    TransactionRepository(db).save(
      nomorTransaksi: 'UI-OFFLINE-$domain',
      jenisTransaksi: domain,
      pemohonId: 10,
      pemohonUuid: uiApplicant,
      petugasId: 20,
      petugasUuid: uiOfficer,
      status: 'Baru',
      tanggalTransaksi: DateTime.utc(2020),
      pembayaranSekarang: 25,
      jobs: [
        TransactionJobInput(
          jenisPekerjaan: domain,
          namaPekerjaan: 'UI $domain snapshot',
          pekerjaanNotarisId: domain == 'notaris' ? 40 : null,
          pekerjaanPpatId: domain == 'ppat' ? 40 : null,
          hargaUuid: uiPrice,
          kategoriUuid: uiCategory,
          detailUuid: domain == 'notaris'
              ? '00000000-0000-4000-8000-000000000007'
              : '00000000-0000-4000-8000-000000000017',
          biayaLayanan: 100,
          kategoriSnapshot: 'Reviewed category',
          estimasiWaktuSnapshot: '2 hari',
          prosesSnapshot: jsonEncode([
            {
              'id': 'ui-$domain',
              'name': 'Periksa',
              'attributes': ['KTP sintetis'],
            },
          ]),
        ),
      ],
    );

Future<void> cycleUi(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await t.pump(const Duration(milliseconds: 16));
  }
}

Future<void> chooseUiModule(WidgetTester t, String label) async {
  if (find.byKey(const Key('manual-sync-dialog')).evaluate().isEmpty) {
    await t.tap(find.byKey(const Key('open-manual-sync')));
    await cycleUi(t);
  }
  final desired = label == 'Transaksi (feed gabungan)' ? 'pull' : 'push';
  await t.tap(
    find.byKey(
      Key(desired == 'pull' ? 'manual-sync-download' : 'manual-sync-upload'),
    ),
  );
  await cycleUi(t);
  if (desired == 'push') {
    await t.tap(
      find.text(label == 'Transaksi PPAT' ? 'PPAT' : 'Notaris').first,
    );
    await cycleUi(t);
  }
}

Future<void> chooseUiRecord(WidgetTester t, String module) async {
  final choice = find
      .byWidgetPredicate((w) => w is RadioListTile<int> && w.enabled == true)
      .first;
  await t.ensureVisible(choice);
  await t.tap(choice);
  await cycleUi(t);
}
