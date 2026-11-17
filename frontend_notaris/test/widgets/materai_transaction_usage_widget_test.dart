import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/providers/auth_provider.dart';
import 'package:frontend_notaris/providers/database_provider.dart';
import 'package:frontend_notaris/providers/materai_provider.dart';
import 'package:frontend_notaris/repositories/materai_stock_repository.dart';
import 'package:frontend_notaris/repositories/transaction_repository.dart';
import 'package:frontend_notaris/screens/transaction_desktop_screen.dart';

import '../support/materai_stock_fixture.dart';
import '../support/penghasilan_fixture.dart';
import '../repositories/materai_transaction_usage_test.dart' show saveUsage;
import '../support/transaction_ui_test_support.dart'
    show TransactionUiAuth, cycleUi;

void main() {
  testWidgets(
    'existing linked transaction previews, cancels and confirms a return once',
    (tester) async {
      final db = MateraiProfileDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final fixture = (await tester.runAsync(() async {
        await seedPenghasilan(db);
        final opening = await seedMateraiOpening(
          db,
          transactionUsage: true,
          transactionCorrection: true,
        );
        final binding = MateraiStockBinding(
          db,
          opening.profileId,
          opening.openingSha256,
          transactionUsageEnabled: true,
          transactionCorrectionsEnabled: true,
        );
        final actor = usageActor(binding.profileId);
        final stock = MateraiStockRepository(binding, () => actor);
        final repo = TransactionRepository(db, materaiStock: stock);
        final id = await saveUsage(repo, deadline: DateTime(2026, 11, 20));
        final row = await (db.select(
          db.transaksis,
        )..where((t) => t.id.equals(id))).getSingle();
        return (binding: binding, actor: actor, number: row.noAkta);
      }))!;
      await tester.binding.setSurfaceSize(const Size(1366, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            authControllerProvider.overrideWith(
              (_) => TransactionUiAuth(fixture.actor),
            ),
            materaiStockBindingProvider.overrideWithValue(fixture.binding),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: TransactionDesktopScreen()),
            ),
          ),
        ),
      );
      await cycleUi(tester);
      await tester.tap(find.text('Cari No. Transaksi'));
      await cycleUi(tester);
      await tester.enterText(find.byType(TextField).last, fixture.number);
      await cycleUi(tester);
      await tester.tap(find.text(fixture.number).last);
      await cycleUi(tester);
      final field = find.widgetWithText(
        TextFormField,
        'Jumlah Materai (lembar)',
      );
      expect(tester.widget<TextFormField>(field).enabled, isTrue);
      expect(
        find.textContaining('Stok terverifikasi: 17 lembar'),
        findsOneWidget,
      );
      await tester.enterText(field, '1');
      await tester.pump();
      expect(find.textContaining('Pengembalian 2 lembar'), findsOneWidget);
      expect(find.textContaining('Proyeksi stok: 19 lembar'), findsOneWidget);
      final lastStep = find.text('Selesai Transaksi').first;
      await tester.ensureVisible(lastStep);
      await tester.tap(lastStep);
      await cycleUi(tester);
      final save = find.text('Simpan Perubahan').first;
      await tester.ensureVisible(save);
      final confirmation = find.text('Konfirmasi koreksi meterai');
      await tester.tap(save);
      await cycleUi(tester);
      expect(confirmation, findsOneWidget);
      await tester.tap(find.text('Batal').last);
      await cycleUi(tester);
      expect(confirmation, findsNothing);
      Future<int> movementCount() async {
        final count = await tester.runAsync(
          () => db
              .customSelect('SELECT COUNT(*) AS n FROM materai_movements')
              .getSingle(),
        );
        return count!.read<int>('n');
      }

      expect(await movementCount(), 2);
      await tester.tap(save);
      await cycleUi(tester);
      final confirm = find.text('Lanjutkan Simpan');
      await tester.tap(confirm);
      await tester.tap(confirm, warnIfMissed: false);
      await cycleUi(tester);
      expect(await movementCount(), 3);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

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
