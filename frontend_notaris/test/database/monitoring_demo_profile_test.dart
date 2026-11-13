import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/monitoring_demo_main.dart';
import 'package:frontend_notaris/repositories/transaction_repository.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../repositories/recycle_bin_repository_test.dart' show seedMaster;

void main() {
  final id = Platform.environment['NOTARIS_MONITORING_PREPARE'];
  test('provision and open a read-only Monitoring demo', () async {
    final root = monitoringDemoRoot(id!);
    final file = File(p.join(root.path, 'offline.sqlite'));
    expect(
      FileSystemEntity.typeSync(file.path, followLinks: false),
      FileSystemEntityType.notFound,
    );
    final db = AppDatabase.forTesting(NativeDatabase(file));
    try {
      final repo = TransactionRepository(db);
      final master = {
        for (final domain in ['notaris', 'ppat'])
          domain: await seedMaster(db, domain),
      };
      await db.customStatement(
        "UPDATE pekerjaan_notaris SET nama='Pembuatan Akta'",
      );
      await db.customStatement(
        "UPDATE pekerjaan_ppat SET nama='Akta Jual Beli'",
      );
      await db.customStatement("""
        INSERT INTO pemohons(id,uuid,nama,nik) VALUES
          (1,'10000000-0000-4000-8000-000000000001','Bagas Pradipta','0000000000000001'),
          (2,'10000000-0000-4000-8000-000000000002','Laras Mahendra','0000000000000002')
        """);
      await db.customStatement("""
        INSERT INTO petugas(id,uuid,nama,email) VALUES
          (1,'20000000-0000-4000-8000-000000000001','Dimas Prasetyo','dimas@example.invalid'),
          (2,'20000000-0000-4000-8000-000000000002','Nadia Pertiwi','nadia@example.invalid')
        """);
      for (var i = 1; i <= 16; i++) {
        final notaris = i.isOdd;
        final domain = notaris ? 'notaris' : 'ppat';
        final contact = notaris ? 1 : 2;
        final status = const ['Baru', 'Dalam Proses', 'Selesai'][(i - 1) % 3];
        await repo.save(
          nomorTransaksi: '${contact}00${i.toString().padLeft(2, '0')}11260001',
          jenisTransaksi: domain,
          pemohonId: contact,
          pemohonUuid: '10000000-0000-4000-8000-00000000000$contact',
          petugasId: contact,
          petugasUuid: '20000000-0000-4000-8000-00000000000$contact',
          status: status,
          deed: notaris && status == 'Selesai'
              ? NotarisDeedInput('Akta contoh', '$i', DateTime(2026, 11, i))
              : null,
          tanggalTransaksi: DateTime(2026, 11, i, 10),
          pembayaranSekarang: 50000,
          jobs: [
            for (final supplemental in [false, if (i >= 15) true])
              TransactionJobInput(
                detailUuid: const Uuid().v4(),
                jenisPekerjaan: domain,
                namaPekerjaan: supplemental
                    ? 'Pemeriksaan Berkas'
                    : notaris
                    ? 'Pembuatan Akta'
                    : 'Akta Jual Beli',
                pekerjaanNotarisId: notaris ? master[domain] : null,
                pekerjaanPpatId: notaris ? null : master[domain],
                biayaLayanan: supplemental ? 50000 : 300000,
                kategoriSnapshot: supplemental
                    ? 'Administrasi'
                    : notaris
                    ? 'Kenotariatan'
                    : 'Pertanahan',
                prosesSnapshot: supplemental
                    ? '[{"id":"2","name":"Periksa kelengkapan berkas"}]'
                    : notaris
                    ? '[{"id":"1","name":"Periksa draf akta"}]'
                    : '[{"id":"1","name":"Periksa dokumen jual beli"}]',
              ),
          ],
        );
      }
      await db.customStatement(
        "INSERT INTO transaction_cloud_feed(scope,cursor) VALUES('monitoring-demo',3)",
      );
    } finally {
      await db.close();
    }
    final readOnly = await openMonitoringDemo(id);
    try {
      expect(
        await readOnly.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
      expect(
        (await readOnly.customSelect('PRAGMA integrity_check').getSingle())
            .read<String>('integrity_check'),
        'ok',
      );
      expect(
        (await readOnly.customSelect('PRAGMA query_only').getSingle())
            .read<int>('query_only'),
        1,
      );
    } finally {
      await readOnly.close();
    }
  }, skip: id == null);
}
