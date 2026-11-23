import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'database/app_database.dart';
import 'notaris_completion_demo_main.dart';
import 'payment_demo_main.dart';
import 'presentation_demo_main.dart' show presentationDemoRoot;

String readPendapatanMarker(Directory root, String name) {
  final marker = File(p.join(root.path, name));
  if (!marker.existsSync() ||
      !p.equals(marker.path, marker.resolveSymbolicLinksSync())) {
    throw StateError('Marker profil Pendapatan tidak terverifikasi.');
  }
  return marker.readAsStringSync();
}

Directory pendapatanDemoRoot(String id) {
  final root = presentationDemoRoot(id);
  if (readPendapatanMarker(root, 'pendapatan-owner') != id) {
    throw StateError('Profil disposable Pendapatan diperlukan.');
  }
  return root;
}

MateraiProfileDatabase openPendapatanDemo(String id) {
  final root = pendapatanDemoRoot(id);
  final file = File(p.join(root.path, 'offline.sqlite'));
  if (!file.existsSync() ||
      !p.equals(file.path, file.resolveSymbolicLinksSync()) ||
      ['-wal', '-shm', '-journal'].any(
        (suffix) =>
            FileSystemEntity.typeSync(file.path + suffix, followLinks: false) !=
            FileSystemEntityType.notFound,
      )) {
    throw StateError('SQLite disposable Pendapatan tidak terverifikasi.');
  }
  final sqlite = sqlite3.open(file.path, mode: OpenMode.readOnly);
  try {
    if (sqlite.select('PRAGMA user_version').single.values.single != 27) {
      throw StateError('SQLite disposable Pendapatan harus v27.');
    }
    sqlite.execute('PRAGMA foreign_keys=ON');
    sqlite.execute('PRAGMA query_only=ON');
    return MateraiProfileDatabase(
      NativeDatabase.opened(sqlite, enableMigrations: false),
    );
  } catch (_) {
    sqlite.close();
    rethrow;
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Platform.isWindows || !kDebugMode) {
    throw StateError('Demo Pendapatan hanya untuk Windows debug.');
  }
  HttpOverrides.global = CompletionDemoNoHttp();
  const id = String.fromEnvironment('NOTARIS_PENDAPATAN_DEMO_ID');
  const authId = String.fromEnvironment('NOTARIS_PENDAPATAN_AUTH_ID');
  const sha = String.fromEnvironment('NOTARIS_PENDAPATAN_HELPER_SHA256');
  final root = pendapatanDemoRoot(id);
  final reader = authId == id;
  if (!reader && readPendapatanMarker(root, 'pendapatan-denied-id') != authId) {
    throw StateError('Scope autentikasi demo Pendapatan berbeda.');
  }
  final authRoot = paymentDemoRoot(authId);
  if (!reader &&
      (readPendapatanMarker(authRoot, 'monitoring-owner') != authId ||
          [
            'offline.sqlite',
            'offline.sqlite-wal',
            'offline.sqlite-shm',
            'offline.sqlite-journal',
          ].any(
            (name) =>
                FileSystemEntity.typeSync(
                  p.join(authRoot.path, name),
                  followLinks: false,
                ) !=
                FileSystemEntityType.notFound,
          ))) {
    throw StateError('Identitas penolakan harus terpisah dari file data demo.');
  }
  runCompletionDemo(
    openPendapatanDemo(id),
    auth: (dio) => PaymentDemoAuth(
      dio,
      authId,
      sha,
      presentation: reader,
      expectedAccount: reader ? 'superadmin.demo' : 'pembaca.demo',
      expireSidebarAccess: true,
    ),
    banner: 'DATA SINTETIS · PENDAPATAN BACA SAJA',
  );
}
