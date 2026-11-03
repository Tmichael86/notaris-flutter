import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/repositories/transaction_repository.dart';
import 'package:frontend_notaris/screens/transaction_desktop_screen.dart';

void main() {
  testWidgets(
    'payment history reads persisted rows, loading, empty and error',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = TransactionRepository(db);
      await db.customStatement(
        "INSERT INTO pemohons(id,uuid,nama) VALUES(1,'pemohon-fixture','Fixture')",
      );
      await db.customStatement(
        "INSERT INTO petugas(id,uuid,nama,email) VALUES(1,'petugas-fixture','Fixture','fixture@example.invalid')",
      );
      await db.customStatement(
        "INSERT INTO pekerjaan_notaris(id,uuid,nama) VALUES(1,'job-fixture','Fixture')",
      );
      final id = await repository.save(
        nomorTransaksi: '1000311260001',
        jenisTransaksi: 'notaris',
        pemohonId: 1,
        pemohonUuid: 'pemohon-fixture',
        petugasId: 1,
        petugasUuid: 'petugas-fixture',
        status: 'Baru',
        tanggalTransaksi: DateTime(2026, 11, 3),
        jobs: const [
          TransactionJobInput(
            jenisPekerjaan: 'notaris',
            namaPekerjaan: 'Fixture',
            pekerjaanNotarisId: 1,
            biayaLayanan: 200000,
            detailUuid: 'fixture-detail',
          ),
        ],
      );
      Future<void> show(
        Future<List<TransaksiRiwayatPembayaran>> future, {
        bool saved = true,
      }) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TransactionPaymentHistoryDialog(
                transactionNumber: '1000311260001',
                history: future,
                saved: saved,
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await show(repository.getPaymentHistory(id));
      await tester.pumpAndSettle();
      expect(find.text('Belum ada riwayat pembayaran.'), findsOneWidget);

      await repository.addPayment(
        transactionId: id,
        paymentDate: DateTime(2026, 11, 4),
        amount: 125000,
        method: 'Cash',
        note: 'DP fixture',
      );
      final pending = Completer<List<TransaksiRiwayatPembayaran>>();
      await show(pending.future);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      pending.complete(await repository.getPaymentHistory(id));
      await tester.pumpAndSettle();
      expect(find.text('Rp 125.000'), findsOneWidget);
      expect(
        find.textContaining('04/11/2026 · Cash · DP fixture'),
        findsOneWidget,
      );

      await show(
        Future<List<TransaksiRiwayatPembayaran>>.delayed(
          Duration.zero,
          () => throw StateError('private failure'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Gagal memuat riwayat pembayaran.'), findsOneWidget);
      expect(find.textContaining('private failure'), findsNothing);

      await show(Future.value([]), saved: false);
      expect(
        find.text('Simpan transaksi untuk melihat riwayat pembayaran.'),
        findsOneWidget,
      );
    },
  );
}
