import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/invoice_demo_main.dart';
import 'package:frontend_notaris/notaris_completion_demo_main.dart';
import 'package:frontend_notaris/repositories/transaction_repository.dart';
import 'package:frontend_notaris/services/auth_service.dart';

void main() {
  final profile = Platform.environment['NOTARIS_INVOICE_DEMO_CHECK'];

  test('invoice demo uses the local reader and blocks network', () async {
    final dio = Dio();
    addTearDown(dio.close);
    final auth = InvoiceDemoAuth(dio);
    final session = await auth.login(
      username: CompletionDemoAuth.readerUsername,
      password: CompletionDemoAuth.readerPassword,
      rememberMe: true,
    );
    expect(session.hasTransactionAccess(), isTrue);
    expect(session.hasTransactionAccess(update: true), isFalse);
    expect(await auth.restoreSession(), isNull);
    await expectLater(
      auth.login(
        username: completionDemoUsername,
        password: completionDemoPassword,
        rememberMe: false,
      ),
      throwsA(isA<AuthException>()),
    );
    expect(
      () => CompletionDemoNoHttp().createHttpClient(null),
      throwsStateError,
    );
  });

  test(
    'prepared invoice SQLite is query-only and both invoices can be read',
    () async {
      final db = await openInvoiceDemo(profile!);
      addTearDown(db.close);
      final dio = Dio();
      addTearDown(dio.close);
      final session = await InvoiceDemoAuth(dio).login(
        username: CompletionDemoAuth.readerUsername,
        password: CompletionDemoAuth.readerPassword,
        rememberMe: false,
      );
      final repository = TransactionRepository(db);
      final transactions = await db.select(db.transaksis).get();
      for (final row in transactions) {
        final invoice = await repository.readInvoice(
          transactionId: row.id,
          session: session,
        );
        expect(
          (invoice.billed, invoice.paid, invoice.remaining),
          (3000000, 500000, 2500000),
        );
        expect(invoice.responsibleStaffName, 'Dimas Prasetyo');
      }
      expect(
        (await db.customSelect('PRAGMA query_only').getSingle())
            .data
            .values
            .single,
        1,
      );
    },
    skip: profile == null,
  );
}
