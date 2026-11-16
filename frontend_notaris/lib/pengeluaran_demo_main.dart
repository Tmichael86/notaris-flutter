import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

import 'database/app_database.dart';
import 'notaris_completion_demo_main.dart';
import 'payment_demo_main.dart';

Directory pengeluaranDemoRoot(String id) {
  final root = paymentDemoRoot(id);
  final marker = File(p.join(root.path, 'pengeluaran-owner'));
  if (!marker.existsSync() ||
      !p.equals(marker.path, marker.resolveSymbolicLinksSync()) ||
      marker.readAsStringSync() != id) {
    throw StateError('Profil disposable Pengeluaran diperlukan.');
  }
  return root;
}

Future<AppDatabase> openPengeluaranDemo(String id) async {
  final root = pengeluaranDemoRoot(id);
  final file = File(p.join(root.path, 'offline.sqlite'));
  if (!file.existsSync() ||
      !p.equals(file.path, file.resolveSymbolicLinksSync()) ||
      ['-wal', '-shm', '-journal'].any(
        (suffix) =>
            FileSystemEntity.typeSync(file.path + suffix, followLinks: false) !=
            FileSystemEntityType.notFound,
      )) {
    throw StateError('SQLite Pengeluaran tidak terverifikasi.');
  }
  final db = AppDatabase.forTesting(
    NativeDatabase(
      file,
      enableMigrations: false,
      setup: (sqlite) => sqlite.execute('PRAGMA foreign_keys = ON'),
    ),
  );
  try {
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    if (version.read<int>('user_version') != db.schemaVersion) {
      throw StateError('Versi SQLite demo berbeda dari schema aplikasi.');
    }
    return db;
  } catch (_) {
    await db.close();
    rethrow;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kDebugMode || !Platform.isWindows) {
    throw StateError('Demo Pengeluaran hanya untuk Windows debug.');
  }
  HttpOverrides.global = CompletionDemoNoHttp();
  const id = String.fromEnvironment('NOTARIS_PENGELUARAN_DEMO_ID');
  const hash = String.fromEnvironment('NOTARIS_PENGELUARAN_HELPER_SHA256');
  pengeluaranDemoRoot(id);
  final verifier = Dio();
  late final AppDatabase db;
  try {
    await PaymentDemoAuth(verifier, id, hash).verifyProfile();
    db = await openPengeluaranDemo(id);
  } finally {
    verifier.close();
  }
  runCompletionDemo(
    db,
    auth: (dio) => PaymentDemoAuth(dio, id, hash, expireSidebarAccess: true),
    banner: 'DATA SINTETIS · PENGELUARAN',
  );
}
