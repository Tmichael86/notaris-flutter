import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/notaris_completion_demo_main.dart';
import 'package:frontend_notaris/ppat_completion_demo_main.dart';
import 'package:frontend_notaris/repositories/transaction_repository.dart';

void main() {
  final prepareId = Platform.environment['NOTARIS_PPAT_PREPARE'];

  test('prepare an owned PPAT demo v22 with two independent jobs', () async {
    final id = prepareId!;
    final file = completionDemoDatabaseFile(id, ppat: true, preparing: true);
    final db = AppDatabase.forTesting(NativeDatabase(file));
    final dio = Dio();
    addTearDown(dio.close);
    final actor = await CompletionDemoAuth(dio).login(
      username: completionDemoUsername,
      password: completionDemoPassword,
      rememberMe: false,
    );
    const applicant = '4c8d9686-de87-481e-962a-e61c56d6e004';
    const officer = '4c8d9686-de87-481e-962a-e61c56d6e005';
    const category = '4c8d9686-de87-481e-962a-e61c56d6e006';
    const salePrice = '4c8d9686-de87-481e-962a-e61c56d6e009';
    const transferPrice = '4c8d9686-de87-481e-962a-e61c56d6e010';
    try {
      await db.transaction(() async {
        for (final sql in [
          "INSERT INTO pemohons(id,uuid,nama) VALUES(1,'$applicant','Laras Mahendra')",
          "INSERT INTO petugas(id,uuid,nama,email) VALUES(1,'$officer','Dimas Prasetyo','dimas@example.invalid')",
          "INSERT INTO pekerjaan_kategori(id,uuid,nama) VALUES(1,'$category','Peralihan Hak')",
          "INSERT INTO pekerjaan_ppat(id,uuid,nama) VALUES(1,'4c8d9686-de87-481e-962a-e61c56d6e007','Akta Jual Beli'),(2,'4c8d9686-de87-481e-962a-e61c56d6e008','Balik Nama Sertifikat')",
          "INSERT INTO pekerjaan_ppat_harga(id,uuid,pekerjaan_ppat_id,kategori_pekerjaan_id,harga,estimasi_waktu) VALUES(1,'$salePrice',1,1,'2500000','5 hari'),(2,'$transferPrice',2,1,'1500000','7 hari')",
          "INSERT INTO pekerjaan_ppat_proses(id,uuid,pekerjaan_ppat_id,nama,detail) VALUES(1,'4c8d9686-de87-481e-962a-e61c56d6e011',1,'Pemeriksaan dokumen jual beli','Periksa kelengkapan dokumen'),(2,'4c8d9686-de87-481e-962a-e61c56d6e012',2,'Pemeriksaan berkas peralihan','Periksa data sertifikat')",
        ]) {
          await db.customStatement(sql);
        }
        final repo = TransactionRepository(db);
        final masters = await db.select(db.pekerjaanPpatLocals).get();
        final processes = await db.select(db.pekerjaanPpatProsesLocals).get();
        final transaction = await repo.save(
          nomorTransaksi: ppatDemoNumber,
          jenisTransaksi: 'ppat',
          pemohonId: 1,
          pemohonUuid: applicant,
          petugasId: 1,
          petugasUuid: officer,
          status: 'Dalam Proses',
          tanggalTransaksi: DateTime(2026, 11, 10),
          tanggalJatuhTempo: DateTime(2026, 11, 18),
          pembayaranSekarang: 500000,
          jobs: [
            for (final job in masters)
              TransactionJobInput(
                jenisPekerjaan: 'ppat',
                namaPekerjaan: job.nama,
                pekerjaanPpatId: job.id,
                detailUuid: job.id == 1
                    ? ppatSaleDetailUuid
                    : ppatTransferDetailUuid,
                hargaUuid: job.id == 1 ? salePrice : transferPrice,
                kategoriUuid: category,
                kategoriSnapshot: 'Peralihan Hak',
                estimasiWaktuSnapshot: job.id == 1 ? '5 hari' : '7 hari',
                biayaLayanan: job.id == 1 ? 2500000 : 1500000,
                prosesSnapshot: jsonEncode([
                  for (final process in processes)
                    if (process.pekerjaanPpatId == job.id)
                      {
                        'id': '${process.id}',
                        'name': process.nama,
                        'status': 'Belum Valid',
                        'attributes': <String>[],
                      },
                ]),
              ),
          ],
        );
        await db.customStatement('UPDATE transaksis SET uuid=? WHERE id=?', [
          ppatDemoUuid,
          transaction,
        ]);
        for (final detail in await repo.watchDetailsOnce(transaction)) {
          await repo.savePpatJobStatus(
            session: actor,
            expected: detail,
            status: PpatJobStatus.dalamProses,
          );
        }
      });
    } finally {
      await db.close();
    }
    final reopened = await openPpatCompletionDemo(id);
    try {
      expect(reopened.schemaVersion, 22);
      expect(
        await reopened.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
      final details = await reopened.select(reopened.transaksiDetails).get();
      expect(
        details.map((row) => row.statusPekerjaanPpat),
        everyElement('dalamProses'),
      );
      expect(details.map((row) => row.tanggalAktaPpat), everyElement(isNull));
      expect(
        await reopened.select(reopened.transaksiProses).get(),
        hasLength(2),
      );
      expect(
        await reopened.select(reopened.transaksiProsesRiwayat).get(),
        isEmpty,
      );
      expect(
        (await reopened
                .select(reopened.transaksiRiwayatPembayarans)
                .getSingle())
            .nominal,
        500000,
      );
    } finally {
      await reopened.close();
    }
  }, skip: prepareId == null);

  test(
    'local reader can inspect a PPAT job but repository denies saving',
    () async {
      final dio = Dio();
      addTearDown(dio.close);
      final auth = CompletionDemoAuth(dio, allowReadOnly: true);
      final session = await auth.login(
        username: CompletionDemoAuth.readerUsername,
        password: CompletionDemoAuth.readerPassword,
        rememberMe: true,
      );
      expect(await auth.restoreSession(), isNull);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customStatement(
        "INSERT INTO transaksis(id,uuid,no_akta,total,jenis_transaksi) VALUES(1,'tx','20001',0,'ppat')",
      );
      await db.customStatement(
        "INSERT INTO transaksi_details(uuid,transaksi_id,jenis_pekerjaan,nama_pekerjaan_snapshot) VALUES('job',1,'ppat','Akta Jual Beli')",
      );
      final repo = TransactionRepository(db);
      final detail = await repo.readPpatJob(
        session: session,
        transactionId: 1,
        detailUuid: 'job',
      );
      await expectLater(
        repo.savePpatJobStatus(
          session: session,
          expected: detail,
          status: PpatJobStatus.selesai,
        ),
        throwsStateError,
      );
      expect(
        await repo.readPpatJob(
          session: session,
          transactionId: 1,
          detailUuid: 'job',
        ),
        detail,
      );
      expect(
        () => CompletionDemoNoHttp().createHttpClient(null),
        throwsStateError,
      );
    },
  );
}
