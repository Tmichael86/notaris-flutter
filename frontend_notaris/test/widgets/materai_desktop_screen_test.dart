import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/core/widgets/app_shell.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/providers/auth_provider.dart';
import 'package:frontend_notaris/providers/database_provider.dart';
import 'package:frontend_notaris/providers/materai_provider.dart';
import 'package:frontend_notaris/repositories/materai_repository.dart';
import 'package:frontend_notaris/screens/laporan_materai_desktop_screen.dart';

import '../support/materai_fixture.dart';
import '../support/transaction_ui_test_support.dart'
    show TransactionUiAuth, cycleUi;

void main() {
  test('denied provider does not resolve a database', () async {
    var opened = false;
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(
          (_) => TransactionUiAuth(materaiReader(read: 0)),
        ),
        appDatabaseProvider.overrideWith((_) {
          opened = true;
          throw StateError('unexpected database access');
        }),
      ],
    );
    addTearDown(container.dispose);
    await expectLater(
      container.read(materaiReportProvider.future),
      throwsStateError,
    );
    expect(opened, isFalse);
  });

  testWidgets('denied, loading, empty and error states are explicit', (
    tester,
  ) async {
    Future<void> show(int id, {bool allowed = true, bool fail = false}) async {
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey(id),
          overrides: [
            authControllerProvider.overrideWith(
              (_) => TransactionUiAuth(materaiReader(read: allowed ? 1 : 0)),
            ),
            materaiReportProvider.overrideWith((_) async {
              if (fail) throw StateError('fixture');
              return MateraiReport([], imported: false);
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(body: LaporanMateraiDesktopScreen()),
          ),
        ),
      );
    }

    await show(0, allowed: false);
    expect(find.textContaining('tidak memiliki izin'), findsOneWidget);
    await show(1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.textContaining('Belum ada snapshot'), findsOneWidget);
    expect(find.text('Tambah'), findsNothing);
    await show(2, fail: true);
    await tester.pumpAndSettle();
    expect(find.text('Laporan Materai gagal dimuat.'), findsOneWidget);
  });

  testWidgets(
    'AppShell with real ledger at three desktop sizes, review and pagination',
    (tester) async {
      final db = MateraiProfileDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.runAsync(() async {
        final font = FontLoader('MateraiTestSans')
          ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
        await font.load();
        await seedMaterai(db);
        await db.customStatement('PRAGMA query_only=ON');
      });
      final auth = materaiReader();
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1728, 900));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((_) => TransactionUiAuth(auth)),
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            theme: ThemeData(fontFamily: 'MateraiTestSans'),
            home: AppShell(session: auth),
          ),
        ),
      );
      try {
        await tester.pumpAndSettle();
        if (find.text('Materai').evaluate().isEmpty) {
          await tester.tap(find.text('Laporan').first);
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('Materai').first);
        await cycleUi(tester);
        expect(find.text('Laporan Mutasi Materai'), findsOneWidget);
        expect(find.text('Tambah'), findsNothing);
        expect(find.text('Excel'), findsNothing);
        expect(
          find.text('Masuk 20 lembar   ·   Keluar 12 lembar'),
          findsOneWidget,
        );
        for (final size in [
          const Size(1728, 900),
          const Size(1366, 768),
          const Size(1080, 640),
        ]) {
          await tester.binding.setSurfaceSize(size);
          await tester.pumpAndSettle();
          expect(
            tester.widget<DataTable>(find.byType(DataTable)).rows.length,
            10,
          );
          expect(tester.takeException(), isNull, reason: '$size');
        }
        await tester.ensureVisible(find.text('Berikutnya'));
        await tester.tap(find.text('Berikutnya'));
        await tester.pumpAndSettle();
        expect(find.text('2 / 2'), findsOneWidget);
        expect(tester.widget<DataTable>(find.byType(DataTable)).rows.length, 2);
        await tester.ensureVisible(find.text('Perlu Ditinjau (1)'));
        await tester.tap(find.text('Perlu Ditinjau (1)'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Saldo tercatat tidak cocok'),
          findsOneWidget,
        );
        final search = find.byType(TextField);
        await tester.ensureVisible(search);
        await tester.enterText(search, 'ppat');
        await tester.pumpAndSettle();
        expect(
          find.text('Tidak ada mutasi yang perlu ditinjau.'),
          findsOneWidget,
        );
        await tester.tap(find.text('Terverifikasi (1)'));
        await tester.pumpAndSettle();
        expect(find.text('Pemakaian PPAT'), findsOneWidget);
        await tester.ensureVisible(find.text('Reset'));
        await tester.tap(find.text('Reset'));
        await tester.pumpAndSettle();
        expect(find.text('1 / 2'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 1));
      }
    },
  );
}
