import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/providers/auth_provider.dart';
import 'package:frontend_notaris/providers/database_provider.dart';
import 'package:frontend_notaris/providers/materai_provider.dart';
import 'package:frontend_notaris/repositories/materai_stock_repository.dart';
import 'package:frontend_notaris/screens/transaction_desktop_screen.dart';

import '../support/materai_stock_fixture.dart';
import '../support/transaction_ui_test_support.dart'
    show TransactionUiAuth, cycleUi;

void main() {
  testWidgets(
    'actual transaction workflow shows sheet input and verified stock for both domains',
    (tester) async {
      final db = MateraiProfileDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final opening = (await tester.runAsync(
        () => seedMateraiOpening(db, transactionUsage: true),
      ))!;
      await tester.binding.setSurfaceSize(const Size(1366, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            authControllerProvider.overrideWith(
              (_) => TransactionUiAuth(usageActor(opening.profileId)),
            ),
            materaiStockBindingProvider.overrideWithValue(
              MateraiStockBinding(
                db,
                opening.profileId,
                opening.openingSha256,
                transactionUsageEnabled: true,
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: TransactionDesktopScreen()),
            ),
          ),
        ),
      );
      await cycleUi(tester);
      expect(find.text('Stok terverifikasi: 20 lembar.'), findsOneWidget);
      final field = find.widgetWithText(
        TextFormField,
        'Jumlah Materai (lembar)',
      );
      await tester.enterText(field, '3');
      expect(tester.widget<TextFormField>(field).controller!.text, '3');
      await tester.tap(find.text('PPAT').first);
      await cycleUi(tester);
      expect(find.text('Stok terverifikasi: 20 lembar.'), findsOneWidget);
      expect(tester.widget<TextFormField>(field).controller!.text, '0');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );
}
