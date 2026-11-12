import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/providers/auth_provider.dart';
import 'package:frontend_notaris/providers/database_provider.dart';
import 'package:frontend_notaris/widgets/transaction_handover_dialog.dart';

import '../repositories/recycle_bin_repository_test.dart'
    show recoverySession, seedTransaction;
import '../support/transaction_ui_test_support.dart'
    show TransactionUiAuth, uiSession;

void main() {
  for (final readOnly in [false, true]) {
    testWidgets('handover actions respect permission (readOnly=$readOnly)', (
      tester,
    ) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final id = await seedTransaction(db, 'ppat');
      final session = readOnly
          ? recoverySession(update: false, only: 'transaksi')
          : uiSession(userId: 37);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            authControllerProvider.overrideWith(
              (_) => TransactionUiAuth(session),
            ),
          ],
          child: MaterialApp(
            home: TransactionHandoverDialog(transactionId: id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pemohon: Applicant'), findsOneWidget);
      expect(find.text('Petugas penanggung jawab: Officer'), findsOneWidget);
      expect(find.text('Cetak'), findsNothing);
      if (readOnly) {
        expect(find.text('Tambah Data'), findsNothing);
      } else {
        await tester.tap(find.text('Tambah Data'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Simpan'));
        await tester.pumpAndSettle();
        expect(
          find.text('Isi uraian atau keperluan sebelum menyimpan.'),
          findsOneWidget,
        );
        await tester.enterText(
          find.byType(TextField).first,
          'Salinan Akta Jual Beli',
        );
        await tester.tap(find.text('Simpan'));
        await tester.pumpAndSettle();
        expect(
          find.text('Data cetak tersimpan di perangkat ini.'),
          findsOneWidget,
        );
        expect(find.text('Salinan Akta Jual Beli'), findsOneWidget);
        expect(find.byTooltip('Edit data cetak'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
