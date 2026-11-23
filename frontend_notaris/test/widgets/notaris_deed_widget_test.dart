import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/providers/auth_provider.dart';
import 'package:frontend_notaris/providers/database_provider.dart';
import 'package:frontend_notaris/screens/transaction_desktop_screen.dart';

import '../repositories/recycle_bin_repository_test.dart'
    show recoverySession, seedTransaction;
import '../support/transaction_ui_test_support.dart' show TransactionUiAuth;

void main() {
  for (final scenario in ['complete', 'read-only', 'ppat']) {
    testWidgets('deed fields on the saved transaction workflow: $scenario', (
      tester,
    ) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final domain = scenario == 'ppat' ? 'ppat' : 'notaris';
      await seedTransaction(db, domain);
      final session = recoverySession();
      for (final access in session.sidebars) {
        access['update'] = scenario == 'read-only' ? 0 : 1;
      }
      if (scenario == 'read-only') {
        await db.customStatement(
          '''
          UPDATE transaksis SET status_transaksi='Selesai', judul_akta='Fidusia',
            nomor_akta='25211', tanggal_akta=?
        ''',
          [DateTime.utc(2026, 11, 11).millisecondsSinceEpoch ~/ 1000],
        );
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
              (_) => TransactionUiAuth(session),
            ),
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
        await tester.tap(find.text('Cari No. Transaksi'));
        await tester.pumpAndSettle();
        final number = (await db.select(db.transaksis).getSingle()).noAkta;
        await tester.tap(find.text(number).last);
        await tester.pumpAndSettle();
        final step = find.text('Selesai Transaksi');
        await tester.ensureVisible(step);
        await tester.tap(step);
        await tester.pumpAndSettle();
      }

      await reopen();
      final status = find.byKey(const ValueKey('finish-transaction-status'));
      final title = find.widgetWithText(TextFormField, 'Judul Akta');
      final save = find.widgetWithText(ElevatedButton, 'Simpan Perubahan');
      if (scenario == 'read-only') {
        expect(tester.widget<TextFormField>(title).controller?.text, 'Fidusia');
        expect(find.text('11/11/2026'), findsOneWidget);
        expect(tester.widget<ElevatedButton>(save).onPressed, isNull);
      } else {
        expect(title, findsNothing);
        await tester.tap(status);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Selesai').last);
        await tester.pumpAndSettle();
        if (domain == 'ppat') {
          expect(title, findsNothing);
        } else {
          expect(title, findsOneWidget);
          await tester.ensureVisible(save);
          await tester.tap(save);
          await tester.pumpAndSettle();
          expect(find.text('Judul Akta wajib diisi.'), findsOneWidget);
          await tester.enterText(title, 'Fidusia');
          await tester.enterText(
            find.widgetWithText(TextFormField, 'Nomor Akta'),
            '25211',
          );
          await tester.tap(find.byTooltip('Pilih tanggal akta'));
          await tester.pumpAndSettle();
          expect(find.byType(DatePickerDialog), findsOneWidget);
          await tester.tap(find.text('Pilih').last);
          await tester.pumpAndSettle();
          await tester.ensureVisible(save);
          await tester.tap(save);
          await tester.pumpAndSettle();
          final saved = await db.select(db.transaksis).getSingle();
          expect(saved.statusTransaksi, 'Selesai');
          expect(saved.nomorAkta, '25211');
          expect(saved.tanggalAkta, isNotNull);
          await reopen();
          expect(
            tester.widget<TextFormField>(title).controller?.text,
            'Fidusia',
          );
          expect(find.text('25211'), findsOneWidget);
        }
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
