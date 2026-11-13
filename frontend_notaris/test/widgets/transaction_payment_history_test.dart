import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/providers/auth_provider.dart';
import 'package:frontend_notaris/providers/database_provider.dart';
import 'package:frontend_notaris/widgets/transaction_payment_history_dialog.dart';

import '../repositories/recycle_bin_repository_test.dart' show seedTransaction;
import '../support/transaction_ui_test_support.dart'
    show TransactionUiAuth, uiSession;

void main() {
  for (final readOnly in [false, true]) {
    testWidgets(
      'payment dialog reflects persisted totals and permissions: readOnly=$readOnly',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final id = await seedTransaction(db, 'notaris');
        await db.customStatement(
          'UPDATE transaksis SET total=200000 WHERE id=?',
          [id],
        );
        final session = uiSession(groupType: 'superadmin');
        if (readOnly) session.sidebars.single['update'] = 0;
        tester.view.physicalSize = const Size(1100, 960);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              authControllerProvider.overrideWith(
                (_) => TransactionUiAuth(session),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: TransactionPaymentHistoryDialog(
                  transactionNumber: '1000611260001',
                  transactionId: id,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('06/11/2026 · Cash'), findsOneWidget);
        expect(find.text('Sisa Tagihan  Rp 199.980'), findsOneWidget);
        if (readOnly) {
          expect(find.text('Tambah Pembayaran'), findsNothing);
          expect(find.byTooltip('Edit cicilan 1'), findsNothing);
          expect(find.byTooltip('Batalkan cicilan 1'), findsNothing);
        } else {
          await tester.tap(find.text('Tambah Pembayaran'));
          await tester.pumpAndSettle();
          final amount = find.widgetWithText(TextField, 'Nominal (Rp)');
          await tester.enterText(amount, '200000');
          await tester.tap(find.text('Simpan'));
          await tester.pumpAndSettle();
          expect(
            find.text('Total pembayaran melebihi total tagihan.'),
            findsOneWidget,
          );
          expect(find.text('Pembayaran disimpan.'), findsNothing);
          await tester.enterText(amount, '125000');
          await tester.tap(find.text('Simpan'));
          await tester.pumpAndSettle();
          expect(find.text('Total Dibayar  Rp 125.020'), findsOneWidget);
          expect(find.text('Sisa Tagihan  Rp 74.980'), findsOneWidget);

          await tester.tap(find.byTooltip('Edit cicilan 2'));
          await tester.pumpAndSettle();
          await tester.enterText(amount, '130000');
          await tester.enterText(
            find.widgetWithText(TextField, 'Alasan'),
            'Konfirmasi bukti setor',
          );
          await tester.tap(find.text('Simpan'));
          await tester.pumpAndSettle();
          expect(find.text('Total Dibayar  Rp 130.020'), findsOneWidget);

          await tester.tap(find.byTooltip('Batalkan cicilan 2'));
          await tester.pumpAndSettle();
          expect(
            find.textContaining('Riwayat tetap tersimpan'),
            findsOneWidget,
          );
          await tester.enterText(
            find.widgetWithText(TextField, 'Alasan'),
            'Salah pencatatan',
          );
          await tester.tap(find.text('Konfirmasi Pembatalan'));
          await tester.pumpAndSettle();
          expect(find.textContaining('Dibatalkan'), findsOneWidget);
          expect(find.text('Total Dibayar  Rp 20'), findsOneWidget);
          expect(find.text('Sisa Tagihan  Rp 199.980'), findsOneWidget);
        }
        tester.view.physicalSize = const Size(760, 540);
        await tester.pumpAndSettle();
        expect(find.text('Sisa Tagihan  Rp 199.980'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
      },
    );
  }
}
