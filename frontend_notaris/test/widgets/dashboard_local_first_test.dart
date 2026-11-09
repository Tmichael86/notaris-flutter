import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/core/widgets/searchable_dropdown.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/models/dashboard_transactions.dart';
import 'package:frontend_notaris/providers/database_provider.dart';
import 'package:frontend_notaris/providers/transaction_provider.dart';
import 'package:frontend_notaris/repositories/transaction_repository.dart';
import 'package:frontend_notaris/screens/dashboard_desktop_screen.dart';

import '../support/transaction_ui_test_support.dart' show cycleUi;

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
      final payment = (await tester.runAsync(
        () => TransactionRepository(db).addPayment(
          transactionId: id,
          paymentDate: DateTime(year, 2, 1),
          amount: 100,
        ),
      ))!;
      await cycleUi(tester);
      expect(find.text('Rp 100'), findsOneWidget);
      await tester.runAsync(
        () => TransactionRepository(db).deletePayment(payment),
      );
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
      expect(tester.takeException(), isNull);
    },
  );
}
