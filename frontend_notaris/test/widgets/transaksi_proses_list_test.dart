import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/providers/database_provider.dart';
import 'package:frontend_notaris/widgets/transaksi_proses_list.dart';

void main() {
  late AppDatabase database;
  late int transactionId;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    transactionId = await database
        .into(database.transaksis)
        .insert(
          TransaksisCompanion.insert(
            uuid: 'process-list-transaction',
            noAkta: '1000000000001',
            total: 100000,
          ),
        );

    await database
        .into(database.transaksiDetails)
        .insert(
          TransaksiDetailsCompanion.insert(
            uuid: 'process-list-detail',
            transaksiId: transactionId,
            jenisPekerjaan: 'notaris',
            namaPekerjaanSnapshot: 'Akta Test',
          ),
        );
    await database
        .into(database.transaksiDetails)
        .insert(
          TransaksiDetailsCompanion.insert(
            uuid: 'other-process-list-detail',
            transaksiId: transactionId,
            jenisPekerjaan: 'notaris',
            namaPekerjaanSnapshot: 'Akta Lain',
          ),
        );
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> disposeSubject(WidgetTester tester) async {
    // Cancel Riverpod's Drift stream subscription, then let Drift's deferred
    // query-stream cleanup timer fire before the test's fake clock is torn down.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  Widget buildSubject({
    required int? id,
    required String detailUuid,
    List<TransaksiProsesFallbackItem> fallback = const [],
  }) {
    return ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 700,
            height: 420,
            child: TransaksiProsesList(
              transactionId: id,
              detailUuid: detailUuid,
              fallbackProcesses: fallback,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('draft uses the process snapshot without querying SQLite', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        id: null,
        detailUuid: 'draft-detail',
        fallback: const [
          TransaksiProsesFallbackItem(
            name: 'Pemeriksaan dokumen',
            status: 'Belum Valid',
          ),
        ],
      ),
    );

    expect(find.text('Pemeriksaan dokumen'), findsOneWidget);
    expect(find.text('Belum Valid'), findsOneWidget);
  });

  testWidgets('saved transaction shows only the selected detail processes', (
    tester,
  ) async {
    await database
        .into(database.transaksiProses)
        .insert(
          TransaksiProsesCompanion.insert(
            uuid: 'selected-process',
            transaksiId: transactionId,
            transaksiDetailUuid: 'process-list-detail',
            namaProsesSnapshot: 'Pemeriksaan dokumen',
            statusProses: const Value('valid'),
          ),
        );
    await database
        .into(database.transaksiProses)
        .insert(
          TransaksiProsesCompanion.insert(
            uuid: 'other-process',
            transaksiId: transactionId,
            transaksiDetailUuid: 'other-process-list-detail',
            namaProsesSnapshot: 'Proses pekerjaan lain',
          ),
        );

    await tester.pumpWidget(
      buildSubject(id: transactionId, detailUuid: 'process-list-detail'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pemeriksaan dokumen'), findsOneWidget);
    expect(find.text('Valid'), findsOneWidget);
    expect(find.text('Proses pekerjaan lain'), findsNothing);

    await disposeSubject(tester);
  });

  testWidgets('saved process status updates reactively from SQLite', (
    tester,
  ) async {
    await database
        .into(database.transaksiProses)
        .insert(
          TransaksiProsesCompanion.insert(
            uuid: 'reactive-process',
            transaksiId: transactionId,
            transaksiDetailUuid: 'process-list-detail',
            namaProsesSnapshot: 'Pemeriksaan berkas',
            statusProses: const Value('valid'),
          ),
        );

    await tester.pumpWidget(
      buildSubject(id: transactionId, detailUuid: 'process-list-detail'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Valid'), findsOneWidget);

    await (database.update(
      database.transaksiProses,
    )..where((process) => process.uuid.equals('reactive-process'))).write(
      const TransaksiProsesCompanion(statusProses: Value('perlu_revisi')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Perlu Revisi'), findsOneWidget);
    expect(find.text('Valid'), findsNothing);

    await disposeSubject(tester);
  });

  testWidgets('saved transaction shows an empty state when no process exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(id: transactionId, detailUuid: 'process-list-detail'),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Belum ada proses tersimpan untuk pekerjaan ini.'),
      findsOneWidget,
    );

    await disposeSubject(tester);
  });
}
