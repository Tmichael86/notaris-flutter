import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/providers/auth_provider.dart';
import 'package:frontend_notaris/providers/database_provider.dart';
import 'package:frontend_notaris/repositories/transaction_repository.dart';
import 'package:frontend_notaris/screens/transaction_desktop_screen.dart';

import '../repositories/recycle_bin_repository_test.dart' show seedTransaction;
import '../support/transaction_ui_test_support.dart'
    show TransactionUiAuth, uiSession;

void main() {
  for (final canEdit in [true, false]) {
    testWidgets('Status PPAT opens the saved job editor, update=$canEdit', (
      tester,
    ) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await seedTransaction(db, 'ppat');
      final session = uiSession();
      session.sidebars.single['update'] = canEdit ? 1 : 0;
      if (!canEdit) {
        await db.customStatement(
          "UPDATE transaksi_details SET status_pekerjaan_ppat='selesai', judul_akta_ppat='Akta Jual Beli'",
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
      await tester.tap(find.text('PPAT').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cari No. Transaksi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2000611260001').last);
      await tester.pumpAndSettle();
      final action = find.widgetWithText(OutlinedButton, 'Status PPAT');
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      final status = find.byType(DropdownButtonFormField<PpatJobStatus>);
      final title = find.widgetWithText(TextFormField, 'Judul Akta');
      final save = find.widgetWithText(FilledButton, 'Simpan');
      if (!canEdit) {
        expect(
          tester.widget<TextFormField>(title).controller?.text,
          'Akta Jual Beli',
        );
        expect(tester.widget<TextFormField>(title).controller, isNotNull);
        expect(save, findsNothing);
      } else {
        expect(
          find.descendant(of: status, matching: find.text('Baru')),
          findsOneWidget,
        );
        expect(title, findsNothing);
        await tester.tap(status);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Selesai').last);
        await tester.pumpAndSettle();
        await tester.enterText(title, 'Akta Jual Beli');
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Nomor Akta'),
          '25211',
        );
        await tester.tap(find.byTooltip('Pilih tanggal akta'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Pilih').last);
        await tester.pumpAndSettle();
        expect(
          (await db.select(db.transaksiDetails).getSingle())
              .statusPekerjaanPpat,
          isNull,
        );
        await tester.tap(save);
        await tester.pumpAndSettle();
        final saved = await db.select(db.transaksiDetails).getSingle();
        expect(saved.statusPekerjaanPpat, 'selesai');
        expect(saved.nomorAktaPpat, '25211');
        expect(saved.tanggalAktaPpat, isNotNull);
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextFormField>(title).controller?.text,
          'Akta Jual Beli',
        );
        expect(find.text('25211'), findsOneWidget);
      }
      await tester.tap(find.widgetWithText(TextButton, 'Tutup').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
