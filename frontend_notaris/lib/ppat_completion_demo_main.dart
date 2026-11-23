import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'database/app_database.dart';
import 'notaris_completion_demo_main.dart';

const ppatDemoSchema = 22;
const ppatDemoNumber = '2001111260001';
const ppatDemoUuid = '4c8d9686-de87-481e-962a-e61c56d6e001';
const ppatSaleDetailUuid = '4c8d9686-de87-481e-962a-e61c56d6e002';
const ppatTransferDetailUuid = '4c8d9686-de87-481e-962a-e61c56d6e003';

Future<AppDatabase> openPpatCompletionDemo(String id) async {
  final db = AppDatabase.forTesting(
    NativeDatabase(
      completionDemoDatabaseFile(id, ppat: true),
      enableMigrations: false,
      setup: (sqlite) {
        if (sqlite.select('PRAGMA user_version').single.values.single !=
            ppatDemoSchema) {
          throw StateError('Schema SQLite demo PPAT bukan v22.');
        }
      },
    ),
  );
  try {
    final parent = await db.select(db.transaksis).getSingle();
    final details = await db.select(db.transaksiDetails).get();
    if (db.schemaVersion != ppatDemoSchema ||
        parent.uuid != ppatDemoUuid ||
        parent.noAkta != ppatDemoNumber ||
        parent.jenisTransaksi != 'ppat' ||
        details.length != 2 ||
        details.any(
          (row) => row.transaksiId != parent.id || row.jenisPekerjaan != 'ppat',
        ) ||
        !details.any((row) => row.uuid == ppatSaleDetailUuid) ||
        !details.any((row) => row.uuid == ppatTransferDetailUuid)) {
      throw StateError('Fixture Transaksi PPAT tidak terverifikasi.');
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
    throw StateError('Profil demonstrasi hanya untuk Windows debug.');
  }
  HttpOverrides.global = CompletionDemoNoHttp();
  final db = await openPpatCompletionDemo(
    const String.fromEnvironment('NOTARIS_COMPLETION_DEMO_ID'),
  );
  runCompletionDemo(db, allowReadOnly: true);
}
