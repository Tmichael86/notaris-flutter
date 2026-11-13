import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'database/app_database.dart';
import 'models/auth_session.dart';
import 'notaris_completion_demo_main.dart';

Future<AppDatabase> openHandoverDemo(String id, {bool prepare = false}) async {
  if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(id)) {
    throw StateError('ID profil Serah Terima tidak valid.');
  }
  final root = Directory(
    p.join(
      Directory.systemTemp.resolveSymbolicLinksSync(),
      'notaris-handover-$id',
    ),
  );
  final owner = File(p.join(root.path, 'owner'));
  final file = File(p.join(root.path, 'offline.sqlite'));
  if (!root.existsSync() ||
      !p.equals(root.path, root.resolveSymbolicLinksSync()) ||
      !owner.existsSync() ||
      !p.equals(owner.path, owner.resolveSymbolicLinksSync()) ||
      owner.readAsStringSync() != id ||
      !file.existsSync() ||
      !p.equals(file.path, file.resolveSymbolicLinksSync())) {
    throw StateError('Profil Serah Terima disposable tidak terverifikasi.');
  }
  final db = AppDatabase.forTesting(
    NativeDatabase(
      file,
      enableMigrations: prepare,
      setup: (sqlite) {
        if (sqlite.select('PRAGMA user_version').single.values.single !=
            (prepare ? 23 : 24)) {
          throw StateError('Versi SQLite Serah Terima tidak sesuai tahap.');
        }
      },
    ),
  );
  try {
    final rows = await db.select(db.transaksis).get();
    if (rows.length != 2 ||
        !rows.any(
          (row) =>
              row.noAkta == '1001111260001' && row.jenisTransaksi == 'notaris',
        ) ||
        !rows.any(
          (row) =>
              row.noAkta == '2001111260001' && row.jenisTransaksi == 'ppat',
        )) {
      throw StateError('Fixture transaksi tidak sesuai.');
    }
    return db;
  } catch (_) {
    await db.close();
    rethrow;
  }
}

class HandoverDemoAuth extends CompletionDemoAuth {
  HandoverDemoAuth(super.dio) : super(allowReadOnly: true);

  @override
  Future<AuthSession> login({
    required String username,
    required String password,
    required bool rememberMe,
  }) async {
    final session = await super.login(
      username: username,
      password: password,
      rememberMe: false,
    );
    if (session.hasTransactionAccess(update: true)) {
      session.sidebars.single['create'] = 1;
    }
    return session;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Platform.isWindows || !kDebugMode) {
    throw StateError('Demo Serah Terima hanya untuk Windows debug.');
  }
  HttpOverrides.global = CompletionDemoNoHttp();
  final db = await openHandoverDemo(
    const String.fromEnvironment('NOTARIS_HANDOVER_DEMO_ID'),
  );
  runCompletionDemo(db, auth: HandoverDemoAuth.new);
}
