import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/providers/auth_provider.dart';
import 'package:frontend_notaris/providers/database_provider.dart';
import 'package:frontend_notaris/providers/pendapatan_provider.dart';
import 'package:frontend_notaris/repositories/pendapatan_repository.dart';
import 'package:frontend_notaris/screens/laporan_pendapatan_desktop_screen.dart';

import '../support/pendapatan_fixture.dart';
import '../support/transaction_ui_test_support.dart'
    show TransactionUiAuth, cycleUi;

DateTime _clock() => DateTime.utc(2026, 10, 31, 17);

void main() {
  test(
    'provider denies missing source permission before resolving SQLite',
    () async {
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            (_) => TransactionUiAuth(pendapatanActor(without: 'pengeluaran')),
          ),
          appDatabaseProvider.overrideWith(
            (_) => throw StateError('Unexpected SQLite access'),
          ),
        ],
      );
      addTearDown(container.dispose);
      await expectLater(
        container.read(pendapatanReportProvider(pendapatanNovember).future),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            pendapatanDenied,
          ),
        ),
      );
    },
  );

  testWidgets('denied, loading, error and empty do not imply a zero balance', (
    tester,
  ) async {
    final stream = StreamController<PendapatanReport>.broadcast();
    addTearDown(() => unawaited(stream.close()));
    Future<void> show(bool allowed) => tester.pumpWidget(
      ProviderScope(
        key: ValueKey(allowed),
        overrides: [
          authControllerProvider.overrideWith(
            (_) => TransactionUiAuth(
              pendapatanActor(without: allowed ? null : pendapatanPermission),
            ),
          ),
          pendapatanReportProvider.overrideWith((_, _) => stream.stream),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LaporanPendapatanDesktopScreen(now: _clock),
            ),
          ),
        ),
      ),
    );
    await show(false);
    expect(find.text(pendapatanDenied), findsOneWidget);
    await show(true);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Total Penerimaan Tercatat'), findsNothing);
    stream.addError(StateError('fixture error'));
    await tester.pumpAndSettle();
    expect(find.text('Laporan Pendapatan gagal dimuat.'), findsOneWidget);
    stream.add(PendapatanReport([], []));
    await tester.pumpAndSettle();
    expect(
      find.text('Tidak ada catatan terverifikasi pada periode ini.'),
      findsOneWidget,
    );
    expect(find.text('Rp 0'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'desktop sizes, pagination, reviews, inclusive date input and WIB reset',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.runAsync(() async {
        final font = FontLoader('PendapatanTestSans')
          ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
        await font.load();
        await seedPendapatan(db);
      });
      final actor = pendapatanActor();
      await tester.binding.setSurfaceSize(const Size(1728, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              (_) => TransactionUiAuth(actor),
            ),
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            theme: ThemeData(fontFamily: 'PendapatanTestSans'),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.only(left: 248),
                child: SingleChildScrollView(
                  child: LaporanPendapatanDesktopScreen(now: _clock),
                ),
              ),
            ),
          ),
        ),
      );
      try {
        await cycleUi(tester);
        expect(find.text('13 hari'), findsOneWidget);
        expect(find.text('-Rp 15.000'), findsOneWidget);
        expect(
          find.textContaining('1 dalam periode · 0 tanpa tanggal'),
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
        final next = find.byTooltip('Halaman berikutnya');
        await tester.ensureVisible(next);
        await tester.tap(next);
        await tester.pumpAndSettle();
        expect(find.text('Halaman 2 dari 2'), findsOneWidget);
        expect(tester.widget<DataTable>(find.byType(DataTable)).rows.length, 3);
        expect(find.text('-Rp 15.000'), findsOneWidget);
        final start = find.textContaining('Tanggal Awal');
        await tester.ensureVisible(start);
        await tester.tap(start);
        await tester.pumpAndSettle();
        final day = find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.text('11'),
        );
        await tester.tap(day);
        await tester.tap(find.text('OK'));
        await cycleUi(tester);
        expect(find.text('3 hari'), findsOneWidget);
        expect(find.text('-Rp 8.000'), findsOneWidget);
        expect(find.text('Perlu Ditinjau'), findsNothing);
        await tester.tap(find.text('Reset'));
        await cycleUi(tester);
        expect(find.text('13 hari'), findsOneWidget);
        expect(find.text('Halaman 1 dari 2'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 1));
      }
    },
  );
}
