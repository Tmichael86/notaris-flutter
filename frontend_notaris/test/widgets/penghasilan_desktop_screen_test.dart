import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/core/widgets/app_shell.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/providers/auth_provider.dart';
import 'package:frontend_notaris/providers/database_provider.dart';
import 'package:frontend_notaris/providers/penghasilan_provider.dart';
import 'package:frontend_notaris/repositories/penghasilan_repository.dart';
import 'package:frontend_notaris/screens/penghasilan_desktop_screen.dart';

import '../support/penghasilan_fixture.dart';
import '../support/transaction_ui_test_support.dart'
    show TransactionUiAuth, cycleUi;

void main() {
  test('provider rejects denied sessions before resolving SQLite', () async {
    var dbOpened = false;
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(
          (_) => TransactionUiAuth(penghasilanReader(allowed: false)),
        ),
        appDatabaseProvider.overrideWith((_) {
          dbOpened = true;
          throw StateError('Unexpected database access');
        }),
      ],
    );
    addTearDown(container.dispose);
    await expectLater(
      container.read(penghasilanReportProvider.future),
      throwsStateError,
    );
    expect(dbOpened, isFalse);
  });

  testWidgets('denied, loading, error and empty states', (tester) async {
    final results = StreamController<PenghasilanReport>.broadcast();
    addTearDown(() => unawaited(results.close()));
    Future<void> show({required bool allowed}) async {
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey(allowed),
          overrides: [
            authControllerProvider.overrideWith(
              (_) => TransactionUiAuth(penghasilanReader(allowed: allowed)),
            ),
            penghasilanReportProvider.overrideWith((_) => results.stream),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: PenghasilanDesktopScreen()),
            ),
          ),
        ),
      );
    }

    await show(allowed: false);
    expect(
      find.text('Anda tidak memiliki izin membaca Penghasilan.'),
      findsOneWidget,
    );
    await show(allowed: true);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Total Dibayar'), findsNothing);
    results.addError(StateError('fixture error'));
    await tester.pumpAndSettle();
    expect(find.text('Daftar Penghasilan gagal dimuat.'), findsOneWidget);
    results.add(PenghasilanReport([], []));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Tidak ada pembayaran terverifikasi'),
      findsOneWidget,
    );
    expect(find.text('Rp 0'), findsOneWidget);
  });

  testWidgets('shell, desktop widths, pagination, review, filters and reset', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.runAsync(() async {
      final font = FontLoader('PenghasilanTestSans')
        ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
      await font.load();
      await seedPenghasilan(db);
    });
    final auth = penghasilanReader();
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1728, 900));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((_) => TransactionUiAuth(auth)),
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          theme: ThemeData(fontFamily: 'PenghasilanTestSans'),
          home: AppShell(session: auth),
        ),
      ),
    );
    try {
      await tester.pumpAndSettle();
      await tester.tap(find.text('Penghasilan').first);
      await cycleUi(tester);
      expect(find.text('13 pembayaran terverifikasi'), findsOneWidget);
      expect(find.text('Rp 480.000'), findsOneWidget);
      expect(find.text('Excel'), findsNothing);
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
      await tester.ensureVisible(find.text('Next'));
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);
      expect(tester.widget<DataTable>(find.byType(DataTable)).rows.length, 3);
      expect(find.text('Rp 480.000'), findsOneWidget);
      await tester.ensureVisible(find.text('Perlu Ditinjau (1)'));
      await tester.tap(find.text('Perlu Ditinjau (1)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Rupiah'), findsOneWidget);
      final domain = find.byKey(const ValueKey(('Jenis Pekerjaan', '')));
      await tester.ensureVisible(domain);
      await tester.tap(domain);
      await tester.pumpAndSettle();
      await tester.tap(find.text('PPAT').last);
      await cycleUi(tester);
      expect(find.text('6 pembayaran terverifikasi'), findsOneWidget);
      expect(find.text('Rp 185.000'), findsOneWidget);
      final search = find.byType(TextField);
      await tester.ensureVisible(search);
      await tester.enterText(search, 'PEN-02');
      await cycleUi(tester);
      expect(find.text('1 pembayaran terverifikasi'), findsOneWidget);
      await tester.ensureVisible(find.text('Reset'));
      await tester.tap(find.text('Reset'));
      await cycleUi(tester);
      expect(find.text('13 pembayaran terverifikasi'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    }
  });
}
