import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

import 'database/app_database.dart';
import 'notaris_completion_demo_main.dart';
import 'payment_demo_main.dart';
import 'presentation_demo_main.dart' show presentationDemoRoot;

Directory penghasilanDemoRoot(String id) {
  final root = presentationDemoRoot(id);
  final marker = File(p.join(root.path, 'penghasilan-owner'));
  if (!marker.existsSync() ||
      !p.equals(marker.path, marker.resolveSymbolicLinksSync()) ||
      marker.readAsStringSync() != id) {
    throw StateError('Profil disposable Penghasilan diperlukan.');
  }
  return root;
}

Future<AppDatabase> openPenghasilanDemo(String id) async {
  final root = penghasilanDemoRoot(id);
  final file = File(p.join(root.path, 'offline.sqlite'));
  if (!file.existsSync() ||
      !p.equals(file.path, file.resolveSymbolicLinksSync()) ||
      ['-wal', '-shm', '-journal'].any(
        (suffix) =>
            FileSystemEntity.typeSync(file.path + suffix, followLinks: false) !=
            FileSystemEntityType.notFound,
      )) {
    throw StateError('SQLite disposable Penghasilan tidak terverifikasi.');
  }
  final db = AppDatabase.forTesting(
    NativeDatabase(
      file,
      enableMigrations: false,
      setup: (sqlite) {
        if (sqlite.select('PRAGMA user_version').single.values.single != 24) {
          throw StateError('SQLite disposable Penghasilan harus v24.');
        }
        sqlite.execute('PRAGMA foreign_keys=ON');
        sqlite.execute('PRAGMA query_only=ON');
      },
    ),
  );
  try {
    final count = await db
        .customSelect('SELECT count(*) AS n FROM transaksis')
        .getSingle();
    if (count.read<int>('n') != 16) {
      throw StateError('Jumlah transaksi fixture Penghasilan berbeda.');
    }
    return db;
  } catch (_) {
    await db.close();
    rethrow;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Platform.isWindows || !kDebugMode) {
    throw StateError('Demo Penghasilan hanya untuk Windows debug.');
  }
  HttpOverrides.global = CompletionDemoNoHttp();
  const id = String.fromEnvironment('NOTARIS_PENGHASILAN_DEMO_ID');
  const authId = String.fromEnvironment('NOTARIS_PENGHASILAN_AUTH_ID');
  const sha = String.fromEnvironment('NOTARIS_PENGHASILAN_HELPER_SHA256');
  final root = penghasilanDemoRoot(id);
  final authorized = authId == id;
  final denied = File(p.join(root.path, 'penghasilan-denied-id'));
  if (!authorized &&
      (!p.equals(denied.path, denied.resolveSymbolicLinksSync()) ||
          denied.readAsStringSync() != authId)) {
    throw StateError('Scope autentikasi demo Penghasilan berbeda.');
  }
  paymentDemoRoot(authId);
  final db = await openPenghasilanDemo(id);
  runCompletionDemo(
    db,
    auth: (dio) => PaymentDemoAuth(
      dio,
      authId,
      sha,
      presentation: authorized,
      expireSidebarAccess: true,
    ),
    banner: 'DATA SINTETIS · PENGHASILAN BACA SAJA',
  );
}
