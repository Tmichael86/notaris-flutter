import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'database/app_database.dart';
import 'main.dart' show MyApp;
import 'models/auth_session.dart';
import 'providers/app_providers.dart';
import 'providers/auth_provider.dart';
import 'providers/database_provider.dart';
import 'providers/development_smoke_provider.dart';
import 'providers/petugas_manual_sync_provider.dart';
import 'providers/transaction_document_provider.dart';
import 'services/auth_service.dart';

const completionDemoSchema = 21;
const completionDemoNumber = '1001111260001';
const completionDemoUuid = '8164c13a-b6a4-41f5-8553-fc9ea5d107b0';
const completionDemoUsername = 'petugas.demo';
// Public credential for an in-process fixture. It cannot authenticate to a server.
const completionDemoPassword = 'Petugas-Akta-25211';

File completionDemoDatabaseFile(
  String id, {
  bool preparing = false,
  bool ppat = false,
}) {
  if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(id)) {
    throw StateError('Identitas profil demo tidak valid.');
  }
  final temp = Directory.systemTemp.resolveSymbolicLinksSync();
  final folder = Directory(
    p.join(temp, ppat ? 'notaris-ppat-$id' : 'notaris-completion-$id'),
  );
  final marker = File(p.join(folder.path, 'owner'));
  final file = File(p.join(folder.path, 'offline.sqlite'));
  if (!folder.existsSync() ||
      !p.equals(folder.resolveSymbolicLinksSync(), folder.path) ||
      !marker.existsSync() ||
      !p.equals(marker.resolveSymbolicLinksSync(), marker.path) ||
      marker.readAsStringSync().trim() != id) {
    throw StateError('Folder profil demo tidak terverifikasi.');
  }
  if (preparing) {
    if (FileSystemEntity.typeSync(file.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw StateError('SQLite persiapan harus baru.');
    }
  } else if (!file.existsSync() ||
      !p.equals(file.resolveSymbolicLinksSync(), file.path)) {
    throw StateError('SQLite demo tidak terverifikasi.');
  }
  for (final suffix in ['-wal', '-shm', '-journal']) {
    if (FileSystemEntity.typeSync(file.path + suffix, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw StateError(
        'SQLite demo memiliki file journal yang belum ditinjau.',
      );
    }
  }
  return file;
}

Future<AppDatabase> openCompletionDemo(String id) async {
  final file = completionDemoDatabaseFile(id);
  final db = AppDatabase.forTesting(
    NativeDatabase(
      file,
      enableMigrations: false,
      setup: (database) {
        final version = database
            .select('PRAGMA user_version')
            .single
            .values
            .single;
        if (version != completionDemoSchema) {
          throw StateError('Schema SQLite demo bukan v21.');
        }
      },
    ),
  );
  try {
    final rows = await db.select(db.transaksis).get();
    if (db.schemaVersion != completionDemoSchema ||
        rows.length != 2 ||
        !rows.any(
          (row) =>
              row.uuid == completionDemoUuid &&
              row.noAkta == completionDemoNumber &&
              row.jenisTransaksi == 'notaris',
        ) ||
        !rows.any(
          (row) =>
              row.noAkta == '2001111260001' && row.jenisTransaksi == 'ppat',
        )) {
      throw StateError('Fixture Transaksi profil demo tidak terverifikasi.');
    }
    return db;
  } catch (_) {
    await db.close();
    rethrow;
  }
}

class CompletionDemoAuth extends AuthService {
  CompletionDemoAuth(Dio dio, {this.allowReadOnly = false}) : super(dio: dio);

  final bool allowReadOnly;
  static const readerUsername = 'pembaca.demo';
  static const readerPassword = 'Baca-Akta-25211';

  @override
  Future<AuthSession?> restoreSession() async => null;

  @override
  Future<void> clearPersistedSession() async {}

  @override
  Future<AuthSession> login({
    required String username,
    required String password,
    required bool rememberMe,
  }) async {
    final reader =
        allowReadOnly &&
        username.trim() == readerUsername &&
        password == readerPassword;
    if (!reader &&
        (username.trim() != completionDemoUsername ||
            password != completionDemoPassword)) {
      throw const AuthException('Kredensial petugas demo tidak cocok.');
    }
    return AuthSession(
      token: 'local-completion-demo',
      userId: reader ? 2 : 1,
      groupId: reader ? 2 : 1,
      userName: reader ? 'Nadia Pertiwi' : 'Dimas Prasetyo',
      groupName: reader ? 'Pembaca Demonstrasi' : 'Petugas Demonstrasi',
      user: const {},
      sidebars: [
        {
          'sidebar': const {
            'sidebar_kode': 'transaksi',
            'sidebar_nama': 'Transaksi',
            'status': 1,
          },
          'read': 1,
          'update': reader ? 0 : 1,
        },
      ],
      verifiedAt: DateTime.now(),
      isOffline: true,
    );
  }
}

class CompletionDemoNoHttp extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      throw StateError('HTTP diblokir pada profil demonstrasi.');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kDebugMode || !Platform.isWindows) {
    throw StateError('Profil demonstrasi hanya untuk Windows debug.');
  }
  HttpOverrides.global = CompletionDemoNoHttp();
  final db = await openCompletionDemo(
    const String.fromEnvironment('NOTARIS_COMPLETION_DEMO_ID'),
  );
  runCompletionDemo(db);
}

void runCompletionDemo(
  AppDatabase db, {
  bool allowReadOnly = false,
  AuthService Function(Dio)? auth,
  TransactionDocumentProfile? documents,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:0'));
  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWith((ref) {
          ref.onDispose(db.close);
          return db;
        }),
        dioProvider.overrideWith((ref) {
          ref.onDispose(dio.close);
          return dio;
        }),
        authServiceProvider.overrideWith(
          (ref) =>
              auth?.call(dio) ??
              CompletionDemoAuth(dio, allowReadOnly: allowReadOnly),
        ),
        developmentUiSmokeProvider.overrideWithValue(true),
        petugasManualEnabledProvider.overrideWithValue(false),
        if (documents != null)
          transactionDocumentProfileProvider.overrideWithValue(documents),
      ],
      child: const Directionality(
        textDirection: TextDirection.ltr,
        child: Banner(
          message: 'PROFIL DEMONSTRASI',
          location: BannerLocation.topEnd,
          child: MyApp(),
        ),
      ),
    ),
  );
}
