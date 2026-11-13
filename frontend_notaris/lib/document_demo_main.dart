import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'database/app_database.dart';
import 'notaris_completion_demo_main.dart';
import 'payment_demo_main.dart';

import 'package:dio/dio.dart';

Directory documentDemoRoot(String id) {
  if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(id)) {
    throw StateError('ID profil dokumen tidak valid.');
  }
  final root = Directory(
    p.join(
      Directory.systemTemp.resolveSymbolicLinksSync(),
      'notaris-documents-$id',
    ),
  );
  final marker = File(p.join(root.path, 'owner'));
  if (!root.existsSync() ||
      !p.equals(root.path, root.resolveSymbolicLinksSync()) ||
      !marker.existsSync() ||
      !p.equals(marker.path, marker.resolveSymbolicLinksSync()) ||
      marker.readAsStringSync().trim() != id) {
    throw StateError('Profil dokumen disposable tidak terverifikasi.');
  }
  return root;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kDebugMode || !Platform.isWindows) {
    throw StateError('Demo dokumen hanya untuk Windows debug.');
  }
  HttpOverrides.global = CompletionDemoNoHttp();
  const id = String.fromEnvironment('NOTARIS_DOCUMENT_DEMO_ID');
  const helperSha = String.fromEnvironment('NOTARIS_DOCUMENT_HELPER_SHA256');
  if (helperSha.isNotEmpty) {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(helperSha)) {
      throw StateError('Fingerprint helper demo tidak valid.');
    }
    final root = paymentDemoRoot(id);
    final marker = File(p.join(root.path, 'document-lifecycle-owner'));
    if (!marker.existsSync() ||
        !p.equals(marker.path, marker.resolveSymbolicLinksSync()) ||
        marker.readAsStringSync() != id) {
      throw StateError('Profil khusus lifecycle dokumen diperlukan.');
    }
    final verifier = Dio();
    try {
      await PaymentDemoAuth(verifier, id, helperSha).verifyProfile();
    } finally {
      verifier.close();
    }
    final (db, file) = await openDocumentDemo(id, lifecycle: true);
    runCompletionDemo(
      db,
      auth: (dio) => PaymentDemoAuth(dio, id, helperSha),
      documents: (databasePath: file.path, appDirectory: root.path),
    );
    return;
  }
  final (db, dbFile) = await openDocumentDemo(id);
  runCompletionDemo(
    db,
    allowReadOnly: true,
    documents: (databasePath: dbFile.path, appDirectory: dbFile.parent.path),
  );
}

Future<(DocumentProfileDatabase, File)> openDocumentDemo(
  String id, {
  bool lifecycle = false,
}) => _openDocumentDatabase(
  lifecycle ? paymentDemoRoot(id) : documentDemoRoot(id),
  lifecycle: lifecycle,
);

Future<(DocumentProfileDatabase, File)> _openDocumentDatabase(
  Directory root, {
  bool lifecycle = false,
}) async {
  final dbFile = File(p.join(root.path, 'offline.sqlite'));
  if (!dbFile.existsSync() ||
      !p.equals(dbFile.path, dbFile.resolveSymbolicLinksSync()) ||
      ['-wal', '-shm', '-journal'].any(
        (suffix) =>
            FileSystemEntity.typeSync(
              dbFile.path + suffix,
              followLinks: false,
            ) !=
            FileSystemEntityType.notFound,
      )) {
    throw StateError('SQLite demo dokumen belum terverifikasi.');
  }
  final db = DocumentProfileDatabase(
    NativeDatabase(
      dbFile,
      enableMigrations: false,
      setup: (sqlite) {
        if (sqlite.select('PRAGMA user_version').single.values.single !=
            (lifecycle ? 26 : 25)) {
          throw StateError('Versi SQLite demo dokumen tidak sesuai.');
        }
      },
    ),
    lifecycle: lifecycle,
  );
  try {
    final transactions = await db.select(db.transaksis).get();
    if (transactions.length != 2 ||
        !transactions.any(
          (t) =>
              t.jenisTransaksi == 'notaris' && t.noAkta == completionDemoNumber,
        ) ||
        !transactions.any(
          (t) => t.jenisTransaksi == 'ppat' && t.noAkta == '2001111260001',
        )) {
      throw StateError('Fixture transaksi dokumen tidak sesuai.');
    }
    return (db, dbFile);
  } catch (_) {
    await db.close();
    rethrow;
  }
}
