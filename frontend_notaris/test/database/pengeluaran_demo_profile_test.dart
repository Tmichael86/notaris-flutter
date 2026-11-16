import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/payment_demo_main.dart';
import 'package:frontend_notaris/pengeluaran_demo_main.dart';
import 'package:frontend_notaris/repositories/pengeluaran_repository.dart';
import 'package:path/path.dart' as p;

import '../repositories/pengeluaran_repository_test.dart' show expenseSession;
import '../repositories/recycle_bin_repository_test.dart' show seedTransaction;

void main() {
  test('expired demo sessions cannot authorize Pengeluaran actions', () {
    final expired = ExpiringPaymentDemoSession(
      expenseSession(),
      DateTime.now().subtract(const Duration(minutes: 1)),
      expireSidebarAccess: true,
    );
    for (final action in PengeluaranAction.values) {
      expect(allowsPengeluaran(expired, action), isFalse);
    }
  });
  final id = Platform.environment['NOTARIS_PENGELUARAN_PREPARE'];
  test('provision and reopen a fresh Pengeluaran demo', () async {
    final root = pengeluaranDemoRoot(id!);
    final file = File(p.join(root.path, 'offline.sqlite'));
    await file.create(exclusive: true);
    final db = AppDatabase.forTesting(
      NativeDatabase(
        file,
        setup: (sqlite) => sqlite.execute('PRAGMA foreign_keys = ON'),
      ),
    );
    try {
      await seedTransaction(db, 'notaris');
      await db.customStatement("""
        INSERT INTO transaction_cloud_feed(scope,cursor) VALUES('expense-demo',3)
        """);
      await db.customStatement("""
        INSERT INTO transaction_cloud_pending(local_uuid,mutation_id,payload,state)
        SELECT uuid,'expense-demo-ack','{}','acked' FROM transaksis
        """);
      await db.customStatement("""
        INSERT INTO transaction_cloud_identity(local_uuid,cloud_uuid,scope,revision,final_number,snapshot)
        SELECT uuid,uuid,'expense-demo',1,no_akta,'{}' FROM transaksis
        """);
      await db.customStatement("""
        INSERT INTO transaksi_proses_riwayat(uuid,transaksi_proses_id,status_baru,created_at)
        SELECT 'expense-demo-process-audit',id,'valid',1 FROM transaksi_proses
        """);
      final repo = PengeluaranRepository(db, expenseSession);
      final types = [
        for (final name in ['ATK', 'Transport'])
          await db
              .into(db.pengeluaranJenis)
              .insert(
                PengeluaranJenisCompanion.insert(
                  uuid: 'expense-demo-$name',
                  nama: name,
                ),
              ),
      ];
      for (var day = 1; day <= 12; day++) {
        final kind = day.isOdd ? 0 : 1;
        await repo.create((
          noFaktur: 'DEMO-${day.toString().padLeft(2, '0')}',
          tanggal: DateTime(2026, 11, day),
          nominal: 10000,
          jenisId: types[kind],
          keterangan: kind == 0 ? 'ATK kantor $day' : 'Transport kantor $day',
        ));
      }
    } finally {
      await db.close();
    }
    final reopened = await openPengeluaranDemo(id);
    try {
      expect(
        await reopened.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
      expect(
        (await reopened.customSelect('PRAGMA integrity_check').getSingle())
            .read<String>('integrity_check'),
        'ok',
      );
      final repo = PengeluaranRepository(reopened, expenseSession);
      final page = await repo.watchPage((
        from: null,
        through: null,
        jenisId: null,
        search: '',
        page: 0,
      )).first;
      expect(page.count, 12);
      expect(page.total, BigInt.from(120000));
      expect(page.rows, hasLength(10));
    } finally {
      await reopened.close();
    }
  }, skip: id == null);
}
