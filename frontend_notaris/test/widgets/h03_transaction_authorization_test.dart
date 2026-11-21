import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/models/auth_session.dart';
import 'package:frontend_notaris/providers/auth_provider.dart';
import 'package:frontend_notaris/providers/database_provider.dart';
import 'package:frontend_notaris/screens/transaction_desktop_screen.dart';

import '../repositories/recycle_bin_repository_test.dart' show seedTransaction;
import '../repositories/local_master_authorization_test.dart'
    show masterSnapshot;
import '../support/transaction_test_authority.dart';
import '../support/transaction_ui_test_support.dart' show TransactionUiAuth;

class _SwitchingAuth extends TransactionUiAuth {
  _SwitchingAuth(super.session);
  void replace(AuthSession next) => state = AuthState.authenticated(next);
}

void main() {
  for (final domain in ['notaris', 'ppat']) {
    testWidgets(
      '$domain edit controls revalidate grants and stale session without writing',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await seedTransaction(db, domain);
        final before = await masterSnapshot(db);
        final controller = _SwitchingAuth(
          transactionTestSession(actions: ['read']),
        );
        tester.view.physicalSize = const Size(1500, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              authControllerProvider.overrideWith((_) => controller),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(child: TransactionDesktopScreen()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (domain == 'ppat') {
          await tester.tap(find.text('PPAT').first);
          await tester.pumpAndSettle();
        }
        Future<void> reopen() async {
          await tester.ensureVisible(find.text('Cari No. Transaksi'));
          await tester.tap(find.text('Cari No. Transaksi'));
          await tester.pumpAndSettle();
          final number = (await db.select(db.transaksis).getSingle()).noAkta;
          await tester.tap(find.text(number).last);
          await tester.pumpAndSettle();
          expect(find.text('Edit Transaksi'), findsOneWidget);
        }

        await reopen();
        await tester.ensureVisible(find.text('Selesai Transaksi').first);
        await tester.tap(find.text('Selesai Transaksi').first);
        await tester.pumpAndSettle();
        final save = find.widgetWithText(ElevatedButton, 'Simpan Perubahan');
        expect(tester.widget<ElevatedButton>(save).onPressed, isNull);
        controller.replace(transactionTestSession());
        await tester.pumpAndSettle();
        expect(
          tester.widget<ElevatedButton>(save).onPressed,
          isNull,
          reason:
              'New authority cannot approve the stale form; reset is explicit',
        );
        expect(find.textContaining('Sesi atau profil berubah'), findsOneWidget);
        await reopen();
        await tester.ensureVisible(find.text('Selesai Transaksi').first);
        await tester.tap(find.text('Selesai Transaksi').first);
        await tester.pumpAndSettle();
        expect(tester.widget<ElevatedButton>(save).onPressed, isNotNull);
        expect(await masterSnapshot(db), before);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      '$domain delete confirmation cannot switch actor before commit',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await seedTransaction(db, domain);
        final before = await masterSnapshot(db);
        final controller = _SwitchingAuth(transactionTestSession());
        tester.view.physicalSize = const Size(1500, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              authControllerProvider.overrideWith((_) => controller),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(child: TransactionDesktopScreen()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (domain == 'ppat') {
          await tester.tap(find.text('PPAT').first);
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('Cari No. Transaksi'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('delete-transaction-1')));
        await tester.pumpAndSettle();
        expect(find.text('Hapus Transaksi?'), findsOneWidget);
        controller.replace(transactionTestSession(uid: 2));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Hapus').last);
        await tester.pumpAndSettle();
        expect(await masterSnapshot(db), before);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
