import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/providers/database_provider.dart';
import 'package:frontend_notaris/providers/auth_provider.dart';
import 'package:frontend_notaris/providers/development_smoke_provider.dart';
import 'package:frontend_notaris/screens/transaction_desktop_screen.dart';
import 'package:frontend_notaris/repositories/recycle_bin_repository.dart';

import '../repositories/recycle_bin_repository_test.dart'
    show recoverySession, seedTransaction;
import '../support/transaction_ui_test_support.dart' show TransactionUiAuth;

void main() {
  for (final domain in ['notaris', 'ppat']) {
    for (final allowed in [false, true]) {
      testWidgets(
        'saved $domain permission=$allowed delete confirmation local restore preserves payment',
        (tester) async {
          final db = AppDatabase.forTesting(NativeDatabase.memory());
          addTearDown(db.close);
          await seedTransaction(db, domain);
          final session = recoverySession();
          for (final a in session.sidebars) {
            a['delete'] = allowed ? 1 : 0;
          }
          tester.view.physicalSize = const Size(1500, 1600);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                appDatabaseProvider.overrideWithValue(db),
                authControllerProvider.overrideWith(
                  (ref) => TransactionUiAuth(session),
                ),
                developmentUiSmokeProvider.overrideWithValue(true),
              ],
              child: const MaterialApp(
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: TransactionDesktopScreen(),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('delete-saved-transaction')),
            findsNothing,
          );
          if (domain == 'ppat') {
            await tester.tap(find.text('PPAT').first);
            await tester.pumpAndSettle();
          }
          await tester.tap(find.text('Cari No. Transaksi'));
          await tester.pumpAndSettle();
          final number = (await db.select(db.transaksis).getSingle()).noAkta;
          await tester.tap(find.text(number).last);
          await tester.pumpAndSettle();
          final button = find.byKey(const Key('delete-saved-transaction'));
          if (!allowed) {
            expect(button, findsNothing);
            await tester.pumpWidget(const SizedBox());
            await tester.pumpAndSettle();
            await db.close();
            return;
          }
          expect(button, findsOneWidget);
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(find.textContaining(number), findsWidgets);
          await tester.tap(find.text('Batal').last);
          await tester.pumpAndSettle();
          expect(
            (await db.select(db.transaksis).getSingle()).deletedAt,
            isNull,
          );
          await tester.tap(button);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Hapus').last);
          await tester.pumpAndSettle();
          expect(
            (await db.select(db.transaksis).getSingle()).deletedAt,
            isNotNull,
          );
          final bin = RecycleBinRepository(db, () => session);
          await bin.restore((await bin.list()).single);
          expect((await db.select(db.transaksis).getSingle()).noAkta, number);
          expect(
            await db.select(db.transaksiRiwayatPembayarans).get(),
            hasLength(1),
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          await db.close();
        },
      );
    }
  }
}
