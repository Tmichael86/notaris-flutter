import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/core/widgets/searchable_dropdown.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/models/dashboard_transactions.dart';
import 'package:frontend_notaris/providers/database_provider.dart';
import 'package:frontend_notaris/providers/transaction_provider.dart';
import 'package:frontend_notaris/repositories/transaction_repository.dart';
import 'package:frontend_notaris/screens/dashboard_desktop_screen.dart';

import '../support/transaction_ui_test_support.dart' show cycleUi, uiSession;

Future<int> header(
  AppDatabase db,
  String number, {
  DateTime? date,
  DateTime? deadline,
  String status = 'Baru',
  bool deleted = false,
}) => db
    .into(db.transaksis)
    .insert(
      TransaksisCompanion.insert(
        uuid: 'uuid-$number',
        noAkta: number,
        total: 1000,
        statusTransaksi: Value(status),
        tanggalTransaksi: Value(date),
        tanggalJatuhTempo: Value(deadline),
        pembayaranSekarang: const Value(999),
        deletedAt: Value(deleted ? DateTime(2026, 1, 1) : null),
      ),
    );

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  for (final count in [0, 1, 2, 10, 11]) {
    testWidgets('Dashboard review adapts to $count transactions', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1240, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final year = DateTime.now().year;
      await tester.runAsync(() async {
        for (var i = 1; i <= count; i++) {
          await header(
            db,
            'FIT-$i',
            date: DateTime(year, 2, i),
            deadline: DateTime(year, 3, i),
          );
        }
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DashboardDesktopScreen(canReadTransactions: true),
              ),
            ),
          ),
        ),
      );
      await cycleUi(tester);
      final action = find.widgetWithText(TextButton, 'Lihat semua').first;
      await tester.ensureVisible(action);
      await tester.tap(action);
      await cycleUi(tester);
      final dialog = find.byType(Dialog);
      final body = find.descendant(
        of: dialog,
        matching: find.byType(Scrollable),
      );
      final surface = find.byKey(const Key('transaction-review-surface'));
      final page = count == 0
          ? '0 / 0'
          : count > 10
          ? '1 / 2'
          : '1 / 1';
      expect(find.text('$count transaksi · Halaman $page'), findsOneWidget);
      final height = tester.getSize(surface).height;
      expect(height, lessThanOrEqualTo(760 * .84 + 1));
      final position = tester.state<ScrollableState>(body).position;
      if (count <= 2) {
        expect(height, lessThan(350));
        expect(position.maxScrollExtent, 0);
      } else {
        expect(position.maxScrollExtent, greaterThan(0));
        final closeRect = tester.getRect(find.byTooltip('Tutup'));
        final next = find.widgetWithText(TextButton, 'Berikutnya');
        final nextRect = tester.getRect(next);
        position.jumpTo(position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(tester.getRect(find.byTooltip('Tutup')), closeRect);
        expect(tester.getRect(next), nextRect);
        if (count == 11) {
          await tester.tap(next);
          await cycleUi(tester);
          expect(find.text('11 transaksi · Halaman 2 / 2'), findsOneWidget);
          expect(tester.getSize(surface).height, lessThan(350));
        }
      }
      expect(tester.takeException(), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });
  }

  test(
    'Dashboard pages use SQLite filters and stable date and ID ordering',
    () async {
      final date = DateTime(2026, 2);
      final deadline = DateTime(2026, 3);
      for (var i = 1; i <= 12; i++) {
        await header(db, 'PAGE-$i', date: date, deadline: deadline);
      }
      await header(
        db,
        'closed',
        date: date,
        deadline: deadline,
        status: 'Selesai',
      );
      await header(db, 'missing-deadline', date: date);
      await header(
        db,
        'previous-year',
        date: DateTime(2025),
        deadline: deadline,
      );
      await header(
        db,
        'tombstone',
        date: date,
        deadline: deadline,
        deleted: true,
      );
      await header(
        db,
        'legacy-tombstone',
        date: date,
        deadline: deadline,
        status: 'Dihapus',
      );
      final repo = TransactionRepository(db);
      Future<DashboardTransactionPage> page(
        DashboardTransactionList list,
        int index,
      ) => repo
          .watchDashboardPage(list: list, year: 2026, pageIndex: index)
          .first;
      final tasks = await page(DashboardTransactionList.deadlines, 0);
      final tasksTail = await page(DashboardTransactionList.deadlines, 1);
      expect(tasks.total, 12);
      expect(
        tasks.rows.map((row) => row.noAkta),
        List.generate(10, (i) => 'PAGE-${i + 1}'),
      );
      expect(tasksTail.rows.map((row) => row.noAkta), ['PAGE-11', 'PAGE-12']);
      final recent = await page(DashboardTransactionList.recent, 0);
      final recentTail = await page(DashboardTransactionList.recent, 8);
      expect(recent.total, 14);
      expect(recent.rows.map((row) => row.noAkta), [
        'missing-deadline',
        'closed',
        ...List.generate(8, (i) => 'PAGE-${12 - i}'),
      ]);
      expect(recentTail.index, 1);
      expect(recentTail.rows.map((row) => row.noAkta), [
        'PAGE-4',
        'PAGE-3',
        'PAGE-2',
        'PAGE-1',
      ]);
    },
  );

  testWidgets(
    'contextual Dashboard dialogs page, follow the selected year and show empty states',
    (tester) async {
      tester.view.physicalSize = const Size(1240, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final year = DateTime.now().year;
      await tester.runAsync(() async {
        for (var i = 1; i <= 12; i++) {
          await header(
            db,
            'DASH-PAGE-$i',
            date: DateTime(year, 1, i),
            deadline: DateTime(year, 2, i),
          );
        }
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DashboardDesktopScreen(canReadTransactions: true),
              ),
            ),
          ),
        ),
      );
      await cycleUi(tester);
      Finder inDialog(String text) =>
          find.descendant(of: find.byType(Dialog), matching: find.text(text));
      Future<void> open(int index) async {
        await tester.tap(
          find.widgetWithText(TextButton, 'Lihat semua').at(index),
        );
        await cycleUi(tester);
      }

      bool enabled(String label) =>
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, label))
              .onPressed !=
          null;
      await open(0);
      expect(inDialog('Tugas & Aktivitas'), findsOneWidget);
      expect(inDialog('12 transaksi · Halaman 1 / 2'), findsOneWidget);
      expect(inDialog('DASH-PAGE-1'), findsOneWidget);
      expect(enabled('Sebelumnya'), isFalse);
      await tester.tap(inDialog('Berikutnya'));
      await cycleUi(tester);
      expect(inDialog('12 transaksi · Halaman 2 / 2'), findsOneWidget);
      expect(inDialog('DASH-PAGE-11'), findsOneWidget);
      expect(inDialog('DASH-PAGE-12'), findsOneWidget);
      expect(enabled('Berikutnya'), isFalse);
      await tester.tap(inDialog('Sebelumnya'));
      await cycleUi(tester);
      expect(inDialog('DASH-PAGE-1'), findsOneWidget);
      await tester.tap(find.byTooltip('Tutup'));
      await tester.pumpAndSettle();
      await open(1);
      expect(inDialog('Transaksi Terbaru'), findsOneWidget);
      expect(inDialog('DASH-PAGE-12'), findsOneWidget);
      tester.view.physicalSize = const Size(340, 480);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Tutup'));
      tester.view.physicalSize = const Size(1240, 1000);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SearchableDropdown<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('${year - 1}'));
      await tester.pumpAndSettle();
      await open(1);
      expect(inDialog('Tahun ${year - 1}'), findsOneWidget);
      expect(inDialog('Belum ada transaksi pada tahun ini.'), findsOneWidget);
      expect(inDialog('0 transaksi · Halaman 0 / 0'), findsOneWidget);
      expect(enabled('Sebelumnya'), isFalse);
      expect(enabled('Berikutnya'), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets(
    'Dashboard modal disables pagination while loading or on query error',
    (tester) async {
      tester.view.physicalSize = const Size(1240, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final pages = StreamController<DashboardTransactionPage>.broadcast();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            transactionsProvider.overrideWith((ref) => Stream.value([])),
            receivedPaymentsProvider.overrideWith((ref, _) => Stream.value(0)),
            dashboardTransactionPageProvider.overrideWith(
              (ref, _) => pages.stream,
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DashboardDesktopScreen(canReadTransactions: true),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Lihat semua').first);
      await cycleUi(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      void expectDisabled() {
        for (final label in ['Sebelumnya', 'Berikutnya']) {
          expect(
            tester
                .widget<TextButton>(find.widgetWithText(TextButton, label))
                .onPressed,
            isNull,
          );
        }
      }

      expectDisabled();
      pages.addError(StateError('fixture page error'));
      await tester.pumpAndSettle();
      expect(find.text('Data transaksi lokal gagal dimuat.'), findsOneWidget);
      expectDisabled();
      await tester.pumpWidget(const SizedBox.shrink());
      unawaited(pages.close());
      await tester.pump();
    },
  );

  test('calendar metrics exclude undated and deleted rows and classify known statuses', () async {
    final today = DateTime(2026, 5, 10);
    await header(
      db,
      'running',
      date: DateTime(2026, 1, 1),
      deadline: today,
      status: ' Dalam Proses ',
    );
    await header(
      db,
      'completed',
      date: DateTime(2026, 12, 31),
      deadline: today,
      status: 'Selesai',
    );
    await header(
      db,
      'new',
      date: DateTime(2026, 1, 31),
      deadline: DateTime(2026, 5, 11),
    );
    await header(db, 'no-deadline', date: DateTime(2026, 2, 1));
    await header(
      db,
      'unknown',
      date: DateTime(2026, 5, 1),
      deadline: today,
      status: 'Legacy',
    );
    await header(db, 'no-date', deadline: today);
    await header(db, 'previous', date: DateTime(2025, 12, 31), deadline: today);
    await header(db, 'deleted', date: today, deleted: true);
    await header(db, 'legacy-tombstone', date: today, status: 'Dihapus');

    final source = await TransactionRepository(db).watchAll().first;
    final summary = DashboardTransactions(source, 2026, today);
    expect(summary.total, 5);
    expect(summary.running, 1);
    expect(summary.due, 1);
    expect(summary.statusCounts, [1, 1, 2]);
    expect(summary.monthlyCounts, [2, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1]);
    expect(summary.recent.map((t) => t.noAkta), [
      'completed',
      'unknown',
      'no-deadline',
      'new',
      'running',
    ]);
    expect(summary.upcoming.map((t) => t.noAkta), ['running', 'new']);
    final empty = DashboardTransactions(source, 2024, today);
    expect(empty.total, 0);
    expect(empty.statusCounts, [0, 0, 0]);
    expect(empty.recent, isEmpty);
  });

  test(
    'received payments use payment year and active history, not header amounts',
    () async {
      final repository = TransactionRepository(db);
      expect(await repository.watchReceivedPayments(2026).first, 0);
      final old = await header(db, 'old', date: DateTime(2025, 12, 31));
      final deleted = await header(
        db,
        'deleted',
        date: DateTime(2026, 1, 1),
        deleted: true,
      );
      final legacyTombstone = await header(
        db,
        'legacy-tombstone',
        status: ' Dihapus ',
      );
      Future<void> payment(
        String uuid,
        int id,
        DateTime date, {
        int status = 1,
        bool deleted = false,
      }) async {
        await db
            .into(db.transaksiRiwayatPembayarans)
            .insert(
              TransaksiRiwayatPembayaransCompanion.insert(
                uuid: uuid,
                transaksiId: id,
                tanggalPembayaran: date,
                nominal: 70,
                status: Value(status),
                deletedAt: Value(deleted ? date : null),
              ),
            );
      }

      await payment('last-year', old, DateTime(2025, 12, 31, 23, 59, 59));
      await payment('first-day', old, DateTime(2026));
      await payment('last-day', old, DateTime(2026, 12, 31, 23, 59, 59));
      await payment('next-year', old, DateTime(2027));
      await payment('deleted-payment', old, DateTime(2026), deleted: true);
      await payment('inactive-payment', old, DateTime(2026), status: 0);
      await payment('deleted-parent', deleted, DateTime(2026));
      await payment('legacy-deleted-parent', legacyTombstone, DateTime(2026));
      expect(await repository.watchReceivedPayments(2026).first, 140);
      expect(await repository.watchReceivedPayments(2025).first, 70);
    },
  );

  testWidgets(
    'Dashboard refreshes on local header and payment changes and filters the year',
    (tester) async {
      tester.view.physicalSize = const Size(1240, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DashboardDesktopScreen(canReadTransactions: true),
              ),
            ),
          ),
        ),
      );
      final year = DateTime.now().year;
      await cycleUi(tester);
      expect(
        find.text('Belum ada transaksi pada tahun $year.'),
        findsOneWidget,
      );
      expect(find.text('Rp 0'), findsOneWidget);

      final id = (await tester.runAsync(
        () => header(db, 'DASH-LOCAL', date: DateTime(year, 1, 1)),
      ))!;
      await cycleUi(tester);
      expect(find.text('DASH-LOCAL'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      await tester.runAsync(
        () => TransactionRepository(db).addPayment(
          session: uiSession(),
          transactionId: id,
          paymentUuid: '00000000-0000-4000-8000-000000000182',
          paymentDate: DateTime(year, 2, 1),
          amount: 100,
        ),
      );
      await cycleUi(tester);
      expect(find.text('Rp 100'), findsOneWidget);
      await tester.runAsync(() async {
        final repo = TransactionRepository(db);
        await repo.cancelPayment(
          session: uiSession(groupType: 'superadmin'),
          transactionId: id,
          expected: (await repo.getPaymentHistory(id)).single,
          reason: 'Koreksi pembayaran',
        );
      });
      await cycleUi(tester);
      expect(find.text('Rp 0'), findsOneWidget);

      await tester.tap(find.byType(SearchableDropdown<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('${year - 1}'));
      await tester.pumpAndSettle();
      await cycleUi(tester);
      expect(find.text('DASH-LOCAL'), findsNothing);
      expect(
        find.text('Belum ada transaksi pada tahun ${year - 1}.'),
        findsOneWidget,
      );
      await tester.tap(find.byType(SearchableDropdown<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('$year'));
      await tester.pumpAndSettle();
      expect(find.text('DASH-LOCAL'), findsOneWidget);
      expect(
        await tester.runAsync(() => TransactionRepository(db).delete(id)),
        isTrue,
      );
      await cycleUi(tester);
      expect(find.text('DASH-LOCAL'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('compact Dashboard shows loading and error without fake values', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(340, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final headers = StreamController<List<Transaksi>>.broadcast();
    final receipts = StreamController<double>.broadcast();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionsProvider.overrideWith((ref) => headers.stream),
          receivedPaymentsProvider.overrideWith((ref, _) => receipts.stream),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DashboardDesktopScreen(canReadTransactions: true),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Memuat transaksi lokal…'), findsWidgets);
    expect(find.text('—'), findsNWidgets(4));
    headers.addError(StateError('fixture transaction error'));
    receipts.addError(StateError('fixture payment error'));
    await tester.pumpAndSettle();
    expect(find.text('Data transaksi lokal gagal dimuat.'), findsWidgets);
    expect(find.text('Pembayaran gagal dimuat'), findsOneWidget);
    expect(find.text('Rp 0'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    unawaited(headers.close());
    unawaited(receipts.close());
    await tester.pump();
  });

  testWidgets(
    'Dashboard without transaction permission does not read the repository',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWith(
              (ref) => throw StateError('Unexpected database access'),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DashboardDesktopScreen(canReadTransactions: false),
            ),
          ),
        ),
      );
      expect(
        find.textContaining('Izin baca Transaksi diperlukan'),
        findsOneWidget,
      );
      expect(find.text('Pendapatan'), findsNothing);
      expect(find.text('Lihat semua'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
