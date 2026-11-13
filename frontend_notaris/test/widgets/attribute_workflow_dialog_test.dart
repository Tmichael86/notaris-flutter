import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/attribute_workflow_demo_main.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/providers/auth_provider.dart';
import 'package:frontend_notaris/providers/database_provider.dart';
import 'package:frontend_notaris/services/attribute_workflow.dart';
import 'package:frontend_notaris/widgets/transaksi_proses_list.dart';

import '../support/transaction_ui_test_support.dart';

class _Drafts implements AttributeDraftStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  testWidgets(
    'process workflow reads only, saves a draft, and leaves Monitoring read-only',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.runAsync(() => seedAttributeDemo(db));
      final storage = _Drafts();
      final http = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:56781/api/v1'));
      addTearDown(http.close);
      final calls = <String>[];
      http.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            calls.add(request.method);
            handler.resolve(
              Response(
                requestOptions: request,
                data: {
                  'data': {
                    'transaction_uuid': demoTransaction,
                    'detail_uuid': demoDetail,
                    'process_uuid': demoProcess,
                    'definition_uuid': '74100000-0000-4000-8000-000000000006',
                    'name': 'Catatan Pemeriksaan Identitas',
                    'value_type': 'text',
                    'status': 'draft',
                    'revision': 1,
                    'version': 0,
                    'role': 'worker',
                    'can_fill': true,
                    'can_decide': false,
                    'initialized_at': '2026-11-10T01:00:00Z',
                    'history': [],
                  },
                },
              ),
            );
          },
        ),
      );
      Widget subject({bool embedded = false}) => ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          authControllerProvider.overrideWith(
            (_) => TransactionUiAuth(uiSession()),
          ),
          attributeDraftStoreProvider.overrideWithValue(storage),
          attributeDemoProvider.overrideWithValue(
            AttributeDemoConnection(http, 'widget'),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: TransaksiProsesList(
              transactionId: 1,
              detailUuid: demoDetail,
              fallbackProcesses: const [],
              embedded: embedded,
            ),
          ),
        ),
      );
      await tester.pumpWidget(subject(embedded: true));
      await tester.pumpAndSettle();
      expect(find.text('Validasi atribut'), findsNothing);
      expect(calls, isEmpty);
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Validasi atribut'));
      await tester.pumpAndSettle();
      expect(find.text('Catatan Pemeriksaan Identitas'), findsOneWidget);
      expect(find.text('Belum Diajukan'), findsOneWidget);
      expect(find.text('Nyatakan Valid'), findsNothing);
      await tester.enterText(
        find.byType(TextField),
        'Ejaan identitas diperiksa',
      );
      await tester.tap(find.text('Simpan draft lokal'));
      await tester.pumpAndSettle();
      expect(find.text('Draft tersimpan di perangkat.'), findsOneWidget);
      expect(calls, ['GET']);
      expect(
        storage.values.values.single,
        contains('Ejaan identitas diperiksa'),
      );
      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();
      expect(
        (await tester.runAsync(() => db.select(db.transaksiProses).getSingle()))
            ?.statusProses,
        isNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );
}
