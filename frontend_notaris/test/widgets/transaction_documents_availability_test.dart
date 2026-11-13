import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/providers/auth_provider.dart';
import 'package:frontend_notaris/providers/database_provider.dart';
import 'package:frontend_notaris/providers/transaction_document_provider.dart';
import 'package:frontend_notaris/screens/transaction_desktop_screen.dart';
import 'package:frontend_notaris/repositories/transaction_document_repository.dart';

import '../repositories/recycle_bin_repository_test.dart'
    show recoverySession, seedTransaction;
import '../support/transaction_ui_test_support.dart'
    show TransactionUiAuth, uiSession;

void main() {
  for (final domain in ['notaris', 'ppat']) {
    testWidgets(
      'document dialog opens on bound $domain profile with reader permissions',
      (tester) async {
        final db = DocumentProfileDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await seedTransaction(db, domain);
        final session = recoverySession(update: false, only: 'transaksi');
        final repo = _ReaderRepository(db);
        tester.view.physicalSize = const Size(1500, 950);
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
              transactionDocumentProfileProvider.overrideWithValue((
                databasePath: 'fixture',
                appDirectory: 'fixture',
              )),
              transactionDocumentRepositoryProvider.overrideWithValue(repo),
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
        await tester.tap(
          find
              .text(domain == 'notaris' ? '1000611260001' : '2000611260001')
              .last,
        );
        await tester.pumpAndSettle();
        final step = find.text('Dokumen & Catatan').first;
        await tester.ensureVisible(step);
        await tester.tap(step);
        await tester.pumpAndSettle();
        final button = find.widgetWithText(OutlinedButton, 'Kelola Dokumen');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(repo.owner?.domain, domain);
        expect(find.text('Belum ada dokumen.'), findsOneWidget);
        expect(find.text('Impor dokumen'), findsNothing);
        await tester.tap(find.text('Tutup'));
        await tester.pumpAndSettle();
        tester.view.physicalSize = const Size(1024, 640);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 1));
      },
    );
  }
  for (final domain in ['notaris', 'ppat']) {
    testWidgets('unverified attachment operations stay disabled for $domain', (
      tester,
    ) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await seedTransaction(db, domain);
      Future<int> changes() async =>
          (await db.customSelect('SELECT total_changes() AS n').getSingle())
              .read<int>('n');
      final before = await changes();
      tester.view.physicalSize = const Size(1500, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            authControllerProvider.overrideWith(
              (_) => TransactionUiAuth(uiSession(groupType: 'superadmin')),
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
      await tester.tap(find.text('Cari No. Transaksi'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(domain == 'notaris' ? '1000611260001' : '2000611260001').last,
      );
      await tester.pumpAndSettle();
      final step = find.text('Dokumen & Catatan').first;
      await tester.ensureVisible(step);
      await tester.tap(step);
      await tester.pumpAndSettle();
      final manage = find.widgetWithText(OutlinedButton, 'Kelola Dokumen');
      expect(tester.widget<OutlinedButton>(manage).onPressed, isNull);
      expect(
        find.textContaining(
          'Aturan penyimpanan dan akses dokumen belum terverifikasi.',
        ),
        findsOneWidget,
      );
      expect(find.text('Catatan Transaksi'), findsOneWidget);
      expect(find.text('Lihat Invoice'), findsOneWidget);
      expect(
        find.widgetWithText(OutlinedButton, 'Serah Terima'),
        findsOneWidget,
      );
      expect(await changes(), before);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });
  }
}

class _ReaderRepository extends TransactionDocumentRepository {
  _ReaderRepository(AppDatabase db)
    : super(
        db: db,
        session: () => null,
        verifiedDatabasePath: 'fixture',
        verifiedAppDirectory: 'fixture',
      );
  DocumentOwner? owner;

  @override
  Future<List<TransactionDocument>> listActive(DocumentOwner owner) async {
    this.owner = owner;
    return [];
  }
}
