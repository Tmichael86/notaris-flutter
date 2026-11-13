import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'database/app_database.dart';
import 'models/auth_session.dart';
import 'notaris_completion_demo_main.dart';
import 'payment_demo_main.dart' show openPaymentFixture;
import 'services/auth_service.dart';

Future<AppDatabase> openInvoiceDemo(String id) {
  if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(id)) {
    throw StateError('ID profil invoice tidak valid.');
  }
  final root = Directory(
    p.join(
      Directory.systemTemp.resolveSymbolicLinksSync(),
      'notaris-invoice-$id',
    ),
  );
  final owner = File(p.join(root.path, 'owner'));
  if (!root.existsSync() ||
      !p.equals(root.path, root.resolveSymbolicLinksSync()) ||
      !owner.existsSync() ||
      !p.equals(owner.path, owner.resolveSymbolicLinksSync()) ||
      owner.readAsStringSync() != id) {
    throw StateError('Profil invoice disposable tidak terverifikasi.');
  }
  return openPaymentFixture(
    File(p.join(root.path, 'offline.sqlite')),
    readOnly: true,
  );
}

class InvoiceDemoAuth extends CompletionDemoAuth {
  InvoiceDemoAuth(super.dio) : super(allowReadOnly: true);

  @override
  Future<AuthSession> login({
    required String username,
    required String password,
    required bool rememberMe,
  }) async {
    if (username.trim() != CompletionDemoAuth.readerUsername) {
      throw const AuthException(
        'Profil invoice hanya mendukung akun pembaca demo.',
      );
    }
    return super.login(
      username: username,
      password: password,
      rememberMe: false,
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Platform.isWindows || !kDebugMode) {
    throw StateError('Demo invoice hanya untuk Windows debug.');
  }
  HttpOverrides.global = CompletionDemoNoHttp();
  final db = await openInvoiceDemo(
    const String.fromEnvironment('NOTARIS_INVOICE_DEMO_ID'),
  );
  runCompletionDemo(db, auth: InvoiceDemoAuth.new);
}
