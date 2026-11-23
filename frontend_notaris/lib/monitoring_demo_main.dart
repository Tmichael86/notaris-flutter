import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

import 'database/app_database.dart';
import 'notaris_completion_demo_main.dart';
import 'payment_demo_main.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kDebugMode || !Platform.isWindows) {
    throw StateError('Demo Monitoring hanya untuk Windows debug.');
  }
  HttpOverrides.global = CompletionDemoNoHttp();
  const id = String.fromEnvironment('NOTARIS_MONITORING_DEMO_ID');
  const helperSha = String.fromEnvironment('NOTARIS_MONITORING_HELPER_SHA256');
  final verifier = Dio();
  late final AppDatabase db;
  try {
    await PaymentDemoAuth(verifier, id, helperSha).verifyProfile();
    db = await openMonitoringDemo(id);
  } finally {
    verifier.close();
  }
  runCompletionDemo(
    db,
    auth: (dio) => PaymentDemoAuth(dio, id, helperSha),
    banner: 'DATA SINTETIS · MONITORING',
  );
}

Directory monitoringDemoRoot(String id) {
  final root = paymentDemoRoot(id);
  final marker = File(p.join(root.path, 'monitoring-owner'));
  if (!marker.existsSync() ||
      !p.equals(marker.path, marker.resolveSymbolicLinksSync()) ||
      marker.readAsStringSync() != id) {
    throw StateError('Profil disposable Monitoring diperlukan.');
  }
  return root;
}

Future<AppDatabase> openMonitoringDemo(String id) async {
  final root = monitoringDemoRoot(id);
  final file = File(p.join(root.path, 'offline.sqlite'));
  if (!file.existsSync() ||
      !p.equals(file.path, file.resolveSymbolicLinksSync()) ||
      ['-wal', '-shm', '-journal'].any(
        (suffix) =>
            FileSystemEntity.typeSync(file.path + suffix, followLinks: false) !=
            FileSystemEntityType.notFound,
      )) {
    throw StateError('SQLite Monitoring tidak terverifikasi.');
  }
  final db = AppDatabase.forTesting(
    NativeDatabase(
      file,
      enableMigrations: false,
      setup: (sqlite) {
        if (sqlite.select('PRAGMA user_version').single.values.single != 24) {
          throw StateError('SQLite Monitoring harus v24.');
        }
        sqlite.execute('PRAGMA query_only = ON');
      },
    ),
  );
  try {
    final counts = await db
        .customSelect(
          'SELECT jenis_transaksi, count(*) AS n FROM transaksis GROUP BY jenis_transaksi',
        )
        .get();
    if (counts.length != 2 ||
        !counts.every(
          (row) =>
              const [
                'notaris',
                'ppat',
              ].contains(row.read<String>('jenis_transaksi')) &&
              row.read<int>('n') == 8,
        )) {
      throw StateError('Fixture transaksi Monitoring berbeda.');
    }
    return db;
  } catch (_) {
    await db.close();
    rethrow;
  }
}
