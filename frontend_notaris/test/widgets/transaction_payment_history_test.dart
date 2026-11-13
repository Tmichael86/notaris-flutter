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
        expect(find.text('Sisa Tagihan'), findsOneWidget);
        expect(find.text('Rp 199.980'), findsOneWidget);
        final history = find.byType(AlertDialog);
        expect(
          tester.widget<AlertDialog>(history).backgroundColor,
          Colors.white,
        );
        final surface = find
            .ancestor(
              of: find.text('Sisa Tagihan'),
              matching: find.byType(Material),
            )
            .first;
        expect(tester.getSize(surface).height, lessThan(450));
        if (readOnly) {
          expect(find.text('Tambah Pembayaran'), findsNothing);
          expect(find.byTooltip('Edit cicilan 1'), findsNothing);
          expect(find.byTooltip('Batalkan cicilan 1'), findsNothing);
        } else {
          await tester.tap(find.text('Tambah Pembayaran'));
          await tester.pumpAndSettle();
          expect(
            tester.widget<AlertDialog>(history.last).backgroundColor,
            Colors.white,
          );
          final dateButton = find.widgetWithIcon(
            OutlinedButton,
            Icons.calendar_month_outlined,
          );
          await tester.tap(dateButton);
          await tester.pumpAndSettle();
          expect(find.byType(DatePickerDialog), findsOneWidget);
          await tester.tap(find.text('Batal'));
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
          expect(find.text('Rp 125.020'), findsOneWidget);
          expect(find.text('Rp 74.980'), findsOneWidget);

          await tester.tap(find.byTooltip('Edit cicilan 2'));
          await tester.pumpAndSettle();
          expect(
            tester.widget<AlertDialog>(history.last).backgroundColor,
            Colors.white,
          );
          await tester.enterText(amount, '130000');
          await tester.enterText(
            find.widgetWithText(TextField, 'Alasan'),
            'Konfirmasi bukti setor',
          );
          await tester.tap(find.text('Simpan'));
          await tester.pumpAndSettle();
          expect(find.text('Rp 130.020'), findsOneWidget);

          await tester.tap(find.byTooltip('Batalkan cicilan 2'));
          await tester.pumpAndSettle();
          expect(
            tester.widget<AlertDialog>(history.last).backgroundColor,
            Colors.white,
          );
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
          expect(find.text('Rp 20'), findsOneWidget);
          expect(find.text('Rp 199.980'), findsOneWidget);
        }
        tester.view.physicalSize = const Size(760, 340);
        await tester.pumpAndSettle();
        expect(find.text('Rp 199.980'), findsOneWidget);
        expect(find.text('Tutup').hitTestable(), findsOneWidget);
        if (!readOnly) {
          await tester.ensureVisible(find.textContaining('Dibatalkan'));
          await tester.pumpAndSettle();
          expect(
            find.textContaining('Dibatalkan').hitTestable(),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
      },
    );
  }
}
