import '../support/transaction_test_authority.dart';
import '../support/local_master_test_authority.dart';

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/materai_stock_demo_main.dart';
import 'package:frontend_notaris/repositories/pekerjaan_repository.dart';
import 'package:path/path.dart' as p;

import '../support/materai_stock_fixture.dart';
import '../support/penghasilan_fixture.dart';

void main() {
  final id = Platform.environment['NOTARIS_MATERAI_USAGE_PREPARE'];
  final correction =
      Platform.environment['NOTARIS_MATERAI_CORRECTION_PREPARE'] == '1';
  test(
    'provisions one fresh stock-out profile and verifies read-only reopen',
    () async {
      final root = materaiStockDemoRoot(
        id!,
        usage: true,
        correction: correction,
      );
      final file = await File(p.join(root.path, 'offline.sqlite'))
          .create(exclusive: true);
      final writer = MateraiProfileDatabase(NativeDatabase(file));
      try {
        await seedPenghasilan(writer);
        await seedMateraiOpening(
          writer,
          id: id,
          transactionUsage: true,
          transactionCorrection: correction,
        );
        PekerjaanAggregateInput job(String name) => PekerjaanAggregateInput(
          nama: name,
          harga: const [
            PekerjaanHargaInput(
              harga: '100000',
              kategoriPekerjaanId: 1,
              estimasiWaktu: '1 hari',
            ),
          ],
          proses: const [
            PekerjaanProsesInput(
              nama: 'Periksa berkas',
              detail: 'Pemeriksaan fixture',
              atribut: [],
            ),
          ],
        );
        await PekerjaanNotarisRepository(
          writer.pekerjaanDao,
          authorization: masterTestAuthority(writer),
        ).createAggregate(input: job('Materai Uji Notaris'));
        final ppat = PekerjaanPpatRepository(
          writer.pekerjaanDao,
          authorization: masterTestAuthority(writer),
        );
        await ppat.createAggregate(input: job('Materai Uji PPAT A'));
        await ppat.createAggregate(input: job('Materai Uji PPAT B'));
      } finally {
        await writer.close();
      }
      final before = sha256.convert(await file.readAsBytes());
      final db = openMateraiStockDemo(
        id,
        writable: false,
        usage: true,
        correction: correction,
      );
      try {
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        expect(
          (await db.customSelect('PRAGMA integrity_check').getSingle())
              .data
              .values
              .single,
          'ok',
        );
        expect(
          (await db.customSelect('PRAGMA query_only').getSingle())
              .data
              .values
              .single,
          1,
        );
        expect(
          (await db
                  .customSelect('SELECT recorded_stock FROM materai_movements')
                  .getSingle())
              .read<int>('recorded_stock'),
          20,
        );
        final repo = testTransactionRepository(db);
        expect(
          await repo.generateNextTransactionNumber(
            jenisTransaksi: 'notaris',
            date: DateTime(2026, 11, 17),
          ),
          '1001711260001',
        );
      } finally {
        await db.close();
      }
      expect(sha256.convert(await file.readAsBytes()), before);
    },
    skip: id == null,
  );
}
