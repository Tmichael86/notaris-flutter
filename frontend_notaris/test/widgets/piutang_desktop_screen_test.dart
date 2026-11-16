import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/core/widgets/app_shell.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/models/auth_session.dart';
import 'package:frontend_notaris/providers/auth_provider.dart';
import 'package:frontend_notaris/providers/database_provider.dart';
import 'package:frontend_notaris/providers/piutang_provider.dart';
import 'package:frontend_notaris/repositories/piutang_repository.dart';
import 'package:frontend_notaris/screens/piutang_desktop_screen.dart';
import 'package:frontend_notaris/services/piutang_excel_export.dart';

import '../support/piutang_fixture.dart';
import '../support/transaction_ui_test_support.dart'
    show TransactionUiAuth, cycleUi;

class _Export extends PiutangExcelExport {
  PiutangFilter? captured;
  int? reportCount;

  @override
  Future<int?> run({
    required PiutangRepository repository,
    required AuthSession? Function() currentSession,
    required PiutangFilter filter,
  }) async {
    captured = filter;
    reportCount = (await repository.read(filter)).rows.length;
    return reportCount;
  }
}

void main() {
  testWidgets(
    'denial avoids database access; authorized loading, error and empty are explicit',
    (tester) async {
      final controller = StreamController<PiutangReport>.broadcast();
      addTearDown(() => unawaited(controller.close()));
      Future<void> show(AuthSession auth) async {
        await tester.pumpWidget(
          ProviderScope(
            key: ObjectKey(auth),
            overrides: [
              authControllerProvider.overrideWith(
                (_) => TransactionUiAuth(auth),
              ),
              appDatabaseProvider.overrideWith(
                (_) => throw StateError('Should not open'),
              ),
              piutangReportProvider.overrideWith((_, _) => controller.stream),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(child: PiutangDesktopScreen()),
              ),
            ),
          ),
        );
      }

      await show(piutangReader(allowed: false));
      expect(
        find.text('Anda tidak memiliki izin membaca Piutang.'),
        findsOneWidget,
      );
      expect(find.text('Excel'), findsNothing);
      await show(piutangReader());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining('Rp '), findsNothing);
      controller.addError(StateError('fixture'));
      await tester.pumpAndSettle();
      expect(find.text('Daftar Piutang gagal dimuat.'), findsOneWidget);
      controller.add(PiutangReport([], []));
      await tester.pumpAndSettle();
      expect(find.textContaining('Tidak ada piutang layanan'), findsOneWidget);
      expect(find.text('Rp 0'), findsOneWidget);
    },
  );

  testWidgets(
    'AppShell layout, review, page-independent totals, search/domain and reset',
    (tester) async {
      await tester.runAsync(() async {
        final font = FontLoader('PiutangTestSans')
          ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
        await font.load();
      });
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.runAsync(() => seedPiutang(db));
      final auth = piutangReader();
      final exporter = _Export();
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1728, 900));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((_) => TransactionUiAuth(auth)),
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            theme: ThemeData(fontFamily: 'PiutangTestSans'),
            home: AppShell(session: auth),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Piutang').first);
      await cycleUi(tester);
      expect(find.text('13 data terverifikasi'), findsOneWidget);
      expect(find.text('Rp 1.055.000'), findsOneWidget);
      for (final size in [
        const Size(1728, 900),
        const Size(1366, 768),
        const Size(1080, 640),
      ]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpAndSettle();
        expect(find.byType(DataTable), findsOneWidget);
        expect(tester.takeException(), isNull, reason: '$size');
      }
      await tester.ensureVisible(find.text('Next'));
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);
      expect(find.text(piutangNumber), findsOneWidget);
      expect(find.text('Rp 1.055.000'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('piutang-review')));
      await tester.tap(find.text('Perlu Ditinjau (1)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('ledger aktif'), findsOneWidget);
      await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PPAT').last);
      await cycleUi(tester);
      expect(find.text('6 data terverifikasi'), findsOneWidget);
      final search = find.byType(TextField);
      await tester.ensureVisible(search);
      await tester.enterText(search, 'PIU-02');
      await cycleUi(tester);
      expect(find.text('1 data terverifikasi'), findsOneWidget);
      await tester.ensureVisible(find.text('Reset'));
      await tester.tap(find.text('Reset'));
      await cycleUi(tester);
      expect(find.text('13 data terverifikasi'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));

      if (Platform.isWindows) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authControllerProvider.overrideWith(
                (_) => TransactionUiAuth(auth),
              ),
              appDatabaseProvider.overrideWithValue(db),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: PiutangDesktopScreen(exporter: exporter),
                ),
              ),
            ),
          ),
        );
        await cycleUi(tester);
        await tester.ensureVisible(find.text('Next'));
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        expect(find.text('2 / 2'), findsOneWidget);
        await tester.ensureVisible(find.text('Excel'));
        await tester.tap(find.text('Excel'));
        await cycleUi(tester);
        expect(exporter.captured, allPiutang);
        expect(exporter.reportCount, 13);
        expect(
          find.text('Excel tersimpan. 13 piutang layanan diekspor.'),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 1));
      }
    },
  );
}
