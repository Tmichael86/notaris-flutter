import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

import 'database/app_database.dart';
import 'notaris_completion_demo_main.dart';
import 'payment_demo_main.dart';

Directory presentationDemoRoot(String id) {
  final root = paymentDemoRoot(id);
  final marker = File(p.join(root.path, 'presentation-owner'));
  if (!marker.existsSync() ||
      !p.equals(marker.path, marker.resolveSymbolicLinksSync()) ||
      marker.readAsStringSync() != id) {
    throw StateError('Profil disposable presentasi diperlukan.');
  }
  return root;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kDebugMode || !Platform.isWindows) {
    throw StateError('Demo presentasi hanya tersedia untuk Windows debug.');
  }
  HttpOverrides.global = CompletionDemoNoHttp();
  const id = String.fromEnvironment('NOTARIS_PRESENTATION_DATA_ID');
  const authId = String.fromEnvironment('NOTARIS_PRESENTATION_AUTH_ID');
  const hash = String.fromEnvironment('NOTARIS_PRESENTATION_HELPER_SHA256');
  final root = presentationDemoRoot(id);
  presentationDemoRoot(authId);
  final binding = File(p.join(root.path, 'presentation-session.json'));
  final data = File(p.join(root.path, 'offline.sqlite'));
  if (!p.equals(binding.path, binding.resolveSymbolicLinksSync()) ||
      !p.equals(data.path, data.resolveSymbolicLinksSync()) ||
      ['-wal', '-shm', '-journal'].any(
        (suffix) =>
            FileSystemEntity.typeSync(data.path + suffix, followLinks: false) !=
            FileSystemEntityType.notFound,
      )) {
    throw StateError('Lokasi atau journal profil presentasi tidak valid.');
  }
  final manifest =
      jsonDecode(binding.readAsStringSync()) as Map<String, dynamic>;
  if (manifest['data_id'] != id ||
      manifest['auth_id'] != authId ||
      manifest['helper_sha256'] != hash) {
    throw StateError('Binding sesi dan data presentasi berbeda.');
  }
  final verifier = Dio();
  try {
    await PaymentDemoAuth(
      verifier,
      authId,
      hash,
      presentation: true,
    ).verifyProfile();
  } finally {
    verifier.close();
  }
  final db = DocumentProfileDatabase(
    NativeDatabase(
      data,
      enableMigrations: false,
      setup: (sqlite) => sqlite.execute('PRAGMA foreign_keys = ON'),
    ),
    lifecycle: true,
  );
  try {
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    if (version.read<int>('user_version') != db.schemaVersion) {
      throw StateError('Versi SQLite presentasi tidak cocok.');
    }
  } catch (_) {
    await db.close();
    rethrow;
  }
  runCompletionDemo(
    db,
    verifiedProfileId: authId,
    auth: (dio) => PaymentDemoAuth(
      dio,
      authId,
      hash,
      presentation: true,
      expireSidebarAccess: true,
    ),
    documents: (databasePath: data.path, appDirectory: root.path),
    banner: 'DEMO MAGANG · DATA SINTETIS',
  );
}
