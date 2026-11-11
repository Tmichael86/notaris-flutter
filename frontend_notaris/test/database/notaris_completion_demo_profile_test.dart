import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/notaris_completion_demo_main.dart';
import 'package:frontend_notaris/providers/transaction_provider.dart';
import 'package:frontend_notaris/repositories/transaction_repository.dart';
import 'package:frontend_notaris/services/auth_service.dart';
import 'package:uuid/uuid.dart';

void main() {
  final prepareId = Platform.environment['NOTARIS_COMPLETION_PREPARE'];
  test('opening an owned v20 profile fails without upgrading it', () async {
    final id = const Uuid().v4().replaceAll('-', '');
    final folder = Directory(
      '${Directory.systemTemp.path}/notaris-completion-$id',
    )..createSync();
    addTearDown(() => folder.delete(recursive: true));
    File('${folder.path}/owner').writeAsStringSync(id);
    final file = completionDemoDatabaseFile(id, preparing: true);
    final fixture = AppDatabase.forTesting(NativeDatabase(file));
    await fixture.customStatement('PRAGMA user_version = 20');
    await fixture.close();
    await expectLater(openCompletionDemo(id), throwsStateError);
    final readback = AppDatabase.forTesting(
      NativeDatabase(file, enableMigrations: false),
    );
    try {
      expect(
        (await readback.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        20,
      );
    } finally {
      await readback.close();
    }
  });
  test('prepare owned Windows acceptance profile', () async {
    final id = prepareId!;
    final file = completionDemoDatabaseFile(id, preparing: true);
    final db = AppDatabase.forTesting(NativeDatabase(file));
    const pemohon = '8164c13a-b6a4-41f5-8553-fc9ea5d107b1';
    const petugas = '8164c13a-b6a4-41f5-8553-fc9ea5d107b2';
    try {
      await db.transaction(() async {
        for (final sql in [
          "INSERT INTO pemohons(id,uuid,nama) VALUES(1,'$pemohon','Bagas Pradipta')",
          "INSERT INTO petugas(id,uuid,nama,email) VALUES(1,'$petugas','Dimas Prasetyo','dimas@example.invalid')",
          "INSERT INTO pekerjaan_kategori(id,uuid,nama) VALUES(1,'8164c13a-b6a4-41f5-8553-fc9ea5d107b3','Perjanjian dan Jaminan'),(2,'8164c13a-b6a4-41f5-8553-fc9ea5d107b4','Peralihan Hak')",
          "INSERT INTO pekerjaan_notaris(id,uuid,nama) VALUES(1,'8164c13a-b6a4-41f5-8553-fc9ea5d107b5','Pembuatan Akta Fidusia')",
          "INSERT INTO pekerjaan_ppat(id,uuid,nama) VALUES(1,'8164c13a-b6a4-41f5-8553-fc9ea5d107b6','Pembuatan Akta Jual Beli')",
          "INSERT INTO pekerjaan_notaris_harga(id,uuid,pekerjaan_notaris_id,kategori_pekerjaan_id,harga,estimasi_waktu) VALUES(1,'8164c13a-b6a4-41f5-8553-fc9ea5d107b7',1,1,'1500000','3 hari')",
          "INSERT INTO pekerjaan_ppat_harga(id,uuid,pekerjaan_ppat_id,kategori_pekerjaan_id,harga,estimasi_waktu) VALUES(1,'8164c13a-b6a4-41f5-8553-fc9ea5d107b8',1,2,'2500000','5 hari')",
          "INSERT INTO pekerjaan_notaris_proses(id,uuid,pekerjaan_notaris_id,nama,detail) VALUES(1,'8164c13a-b6a4-41f5-8553-fc9ea5d107b9',1,'Pemeriksaan dokumen jaminan','Periksa kelengkapan berkas')",
        ]) {
          await db.customStatement(sql);
        }
        final repo = TransactionRepository(db);
        for (final domain in ['notaris', 'ppat']) {
          final notaris = domain == 'notaris';
          final id = await repo.save(
            nomorTransaksi: notaris ? completionDemoNumber : '2001111260001',
            jenisTransaksi: domain,
            pemohonId: 1,
            pemohonUuid: pemohon,
            petugasId: 1,
            petugasUuid: petugas,
            status: 'Dalam Proses',
            tanggalTransaksi: DateTime(2026, 11, 10),
            tanggalJatuhTempo: DateTime(2026, 11, 13),
            pembayaranSekarang: notaris ? 500000 : 0,
            jobs: [
              TransactionJobInput(
                jenisPekerjaan: domain,
                namaPekerjaan: notaris
                    ? 'Pembuatan Akta Fidusia'
                    : 'Pembuatan Akta Jual Beli',
                detailUuid: notaris
                    ? '8164c13a-b6a4-41f5-8553-fc9ea5d107c1'
                    : '8164c13a-b6a4-41f5-8553-fc9ea5d107c2',
                pekerjaanNotarisId: notaris ? 1 : null,
                pekerjaanPpatId: notaris ? null : 1,
                hargaUuid: notaris
                    ? '8164c13a-b6a4-41f5-8553-fc9ea5d107b7'
                    : '8164c13a-b6a4-41f5-8553-fc9ea5d107b8',
                kategoriUuid: notaris
                    ? '8164c13a-b6a4-41f5-8553-fc9ea5d107b3'
                    : '8164c13a-b6a4-41f5-8553-fc9ea5d107b4',
                kategoriSnapshot: notaris
                    ? 'Perjanjian dan Jaminan'
                    : 'Peralihan Hak',
                estimasiWaktuSnapshot: notaris ? '3 hari' : '5 hari',
                biayaLayanan: notaris ? 1500000 : 2500000,
                prosesSnapshot: notaris
                    ? jsonEncode([
                        {
                          'id': '1',
                          'name': 'Pemeriksaan dokumen jaminan',
                          'status': 'Belum Valid',
                          'attributes': <String>[],
                        },
                      ])
                    : null,
              ),
            ],
          );
          if (notaris) {
            await db.customStatement(
              'UPDATE transaksis SET uuid=? WHERE id=?',
              [completionDemoUuid, id],
            );
          }
        }
      });
    } finally {
      await db.close();
    }
    final reopened = await openCompletionDemo(id);
    try {
      expect(reopened.schemaVersion, 21);
      expect(
        await reopened.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
      expect(
        await reopened.select(reopened.transaksiRiwayatPembayarans).get(),
        hasLength(1),
      );
    } finally {
      await reopened.close();
    }
  }, skip: prepareId == null);

  test(
    'demo login grants only transaction read/update and never uses HTTP',
    () async {
      final dio = Dio();
      addTearDown(dio.close);
      final auth = CompletionDemoAuth(dio);
      await expectLater(
        auth.login(
          username: completionDemoUsername,
          password: 'wrong',
          rememberMe: false,
        ),
        throwsA(isA<AuthException>()),
      );
      final session = await auth.login(
        username: completionDemoUsername,
        password: completionDemoPassword,
        rememberMe: true,
      );
      expect(await auth.restoreSession(), isNull);
      expect(
        canSaveNotarisTransaction(session, editing: true, completing: true),
        isTrue,
      );
      expect(
        canSaveNotarisTransaction(session, editing: false, completing: true),
        isFalse,
      );
      expect(
        () => CompletionDemoNoHttp().createHttpClient(null),
        throwsStateError,
      );
      expect(
        () => completionDemoDatabaseFile('../notarisdev'),
        throwsStateError,
      );
    },
  );
}
