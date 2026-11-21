import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

import 'database/app_database.dart';
import 'notaris_completion_demo_main.dart';
import 'payment_demo_main.dart';
import 'repositories/materai_stock_repository.dart';

Directory materaiStockDemoRoot(
  String id, {
  bool usage = false,
  bool correction = false,
}) {
  final root = paymentDemoRoot(id);
  final marker = File(
    p.join(root.path, usage ? 'materai-usage-owner' : 'materai-owner'),
  );
  if (!marker.existsSync() ||
      !p.equals(marker.path, marker.resolveSymbolicLinksSync()) ||
      marker.readAsStringSync() != id ||
      File(p.join(root.path, 'presentation-owner')).existsSync()) {
    throw StateError('Profil stock-in Materai disposable diperlukan.');
  }
  if (correction) {
    final correctionMarker = File(
      p.join(root.path, 'materai-correction-owner'),
    );
    if (!usage ||
        !correctionMarker.existsSync() ||
        !p.equals(
          correctionMarker.path,
          correctionMarker.resolveSymbolicLinksSync(),
        ) ||
        correctionMarker.readAsStringSync() != id) {
      throw StateError('Profil koreksi Materai disposable diperlukan.');
    }
  }
  return root;
}

MateraiProfileDatabase openMateraiStockDemo(
  String id, {
  required bool writable,
  bool usage = false,
  bool correction = false,
}) {
  final root = materaiStockDemoRoot(id, usage: usage, correction: correction);
  final file = File(p.join(root.path, 'offline.sqlite'));
  if (!file.existsSync() ||
      !p.equals(file.path, file.resolveSymbolicLinksSync()) ||
      ['-wal', '-shm', '-journal'].any(
        (suffix) =>
            FileSystemEntity.typeSync(file.path + suffix, followLinks: false) !=
            FileSystemEntityType.notFound,
      )) {
    throw StateError('SQLite disposable belum siap.');
  }
  return MateraiProfileDatabase(
    NativeDatabase(
      file,
      enableMigrations: false,
      setup: (raw) {
        if (raw.select('PRAGMA user_version').single['user_version'] != 27) {
          throw StateError('SQLite stock-in Materai harus v27.');
        }
        raw.execute('PRAGMA foreign_keys=ON');
        if (!writable) raw.execute('PRAGMA query_only=ON');
      },
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Platform.isWindows || !kDebugMode) {
    throw StateError('Demo stock-in Materai hanya untuk Windows debug.');
  }
  HttpOverrides.global = CompletionDemoNoHttp();
  const id = String.fromEnvironment('NOTARIS_MATERAI_STOCK_ID');
  const helperSha = String.fromEnvironment('NOTARIS_MATERAI_STOCK_HELPER_SHA');
  const openingSha = String.fromEnvironment(
    'NOTARIS_MATERAI_STOCK_OPENING_SHA',
  );
  const account = String.fromEnvironment('NOTARIS_MATERAI_STOCK_ACCOUNT');
  const writable = bool.fromEnvironment('NOTARIS_MATERAI_STOCK_WRITE');
  const usage = bool.fromEnvironment('NOTARIS_MATERAI_TRANSACTION_USAGE');
  const correction = bool.fromEnvironment(
    'NOTARIS_MATERAI_TRANSACTION_CORRECTION',
  );
  if (!PaymentDemoAuth.usernames.contains(account) ||
      (writable && account != 'admin.demo')) {
    throw StateError('Scope akun uji Materai berbeda.');
  }
  final root = materaiStockDemoRoot(id, usage: usage, correction: correction);
  final db = openMateraiStockDemo(
    id,
    writable: writable,
    usage: usage,
    correction: correction,
  );
  final binding = writable || usage
      ? MateraiStockBinding(
          db,
          id,
          openingSha,
          transactionUsageEnabled: usage,
          transactionCorrectionsEnabled: correction,
          acceptsWrites: writable,
          pendingReceipt: writable
              ? File(p.join(root.path, 'materai-pending-receipt.json'))
              : null,
        )
      : null;
  runCompletionDemo(
    db,
    verifiedProfileId: id,
    materaiStock: binding,
    auth: (dio) => PaymentDemoAuth(
      dio,
      id,
      helperSha,
      expectedAccount: account,
      expireSidebarAccess: true,
    ),
    banner: writable
        ? (correction
              ? 'DATA SINTETIS · UJI KOREKSI MATERAI'
              : usage
              ? 'DATA SINTETIS · UJI STOK KELUAR MATERAI'
              : 'DATA SINTETIS · UJI STOK MASUK MATERAI')
        : 'DATA SINTETIS · MATERAI BACA SAJA',
  );
}
