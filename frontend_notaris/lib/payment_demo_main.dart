import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'database/app_database.dart';
import 'models/auth_session.dart';
import 'notaris_completion_demo_main.dart';
import 'services/auth_service.dart';

const paymentDemoNotaris = '1001111260001';
const paymentDemoPpat = '2001111260001';

Directory paymentDemoRoot(String id) {
  if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(id)) {
    throw StateError('ID profil pembayaran tidak valid.');
  }
  final folder = Directory(
    p.join(
      Directory.systemTemp.resolveSymbolicLinksSync(),
      'notaris-payment-$id',
    ),
  );
  final owner = File(p.join(folder.path, 'owner'));
  if (!folder.existsSync() ||
      !p.equals(folder.path, folder.resolveSymbolicLinksSync()) ||
      !owner.existsSync() ||
      !p.equals(owner.path, owner.resolveSymbolicLinksSync()) ||
      owner.readAsStringSync() != id) {
    throw StateError(
      'Profil pembayaran bukan folder disposable yang dimiliki runner.',
    );
  }
  return folder;
}

class ExpiringPaymentDemoSession extends AuthSession {
  ExpiringPaymentDemoSession(AuthSession session, this.expiresAt)
    : super(
        token: session.token,
        userId: session.userId,
        groupId: session.groupId,
        userName: session.userName,
        groupName: session.groupName,
        user: session.user,
        sidebars: session.sidebars,
        verifiedAt: session.verifiedAt,
        groupType: session.groupType,
        isOffline: true,
      );

  final DateTime expiresAt;

  @override
  bool hasTransactionAccess({bool create = false, bool update = false}) =>
      DateTime.now().isBefore(expiresAt) &&
      super.hasTransactionAccess(create: create, update: update);
}

class PaymentDemoAuth extends AuthService {
  PaymentDemoAuth(Dio dio, this.id, this.helperSha) : super(dio: dio);

  final String id;
  final String helperSha;
  static const usernames = {'petugas.demo', 'admin.demo', 'pembaca.demo'};

  @override
  Future<AuthSession?> restoreSession() async => null;

  @override
  Future<void> clearPersistedSession() async {}

  Future<File> _verifiedHelper() async {
    final file = File(p.join(paymentDemoRoot(id).path, 'session.exe'));
    if (!file.existsSync() ||
        !p.equals(file.path, file.resolveSymbolicLinksSync()) ||
        sha256.convert(await file.readAsBytes()).toString() != helperSha) {
      throw StateError('Helper berbeda.');
    }
    return file;
  }

  Future<void> verifyProfile() async {
    final file = await _verifiedHelper();
    final checked = await Process.run(file.path, ['verify-db', id]);
    if (checked.exitCode != 0) throw StateError('Profil pembayaran tidak sah.');
  }

  @override
  Future<AuthSession> login({
    required String username,
    required String password,
    required bool rememberMe,
  }) async {
    final account = username.trim();
    if (!usernames.contains(account)) {
      throw const AuthException('Kredensial atau sesi demo tidak valid.');
    }
    try {
      final file = await _verifiedHelper();
      final helper = await Process.start(file.path, ['unlock', id, account]);
      final output = utf8.decoder.bind(helper.stdout).join();
      final drained = helper.stderr.drain<void>();
      helper.stdin.write(jsonEncode(password));
      await helper.stdin.close();
      final status = await helper.exitCode.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          helper.kill();
          return 1;
        },
      );
      final text = await output;
      await drained;
      if (status != 0) throw StateError('Unlock ditolak.');
      final data = jsonDecode(text) as Map<String, dynamic>;
      final expiry = DateTime.parse(data['expiresAt'] as String);
      final now = DateTime.now();
      if (data['profile'] != id ||
          data['username'] != account ||
          !now.isBefore(expiry)) {
        throw StateError('Sesi terverifikasi tidak berlaku.');
      }
      // No server JWT is persisted or needed for a fully offline demo.
      final session = ExpiringPaymentDemoSession(
        AuthSession.fromJson({...data, 'token': 'offline-payment-demo'}),
        expiry,
      );
      if (!session.hasTransactionAccess() || now.isBefore(session.verifiedAt)) {
        throw StateError('Izin demo tidak valid.');
      }
      return session;
    } catch (_) {
      throw const AuthException(
        'Kredensial atau sesi demo tidak valid atau kedaluwarsa.',
      );
    }
  }
}

Future<AppDatabase> openPaymentDemo(String id) async {
  final file = File(p.join(paymentDemoRoot(id).path, 'offline.sqlite'));
  if (!file.existsSync() ||
      !p.equals(file.path, file.resolveSymbolicLinksSync()) ||
      ['-wal', '-shm', '-journal'].any(
        (suffix) =>
            FileSystemEntity.typeSync(file.path + suffix, followLinks: false) !=
            FileSystemEntityType.notFound,
      )) {
    throw StateError('SQLite pembayaran tidak terverifikasi.');
  }
  final db = AppDatabase.forTesting(
    NativeDatabase(
      file,
      enableMigrations: false,
      setup: (sqlite) {
        if (sqlite.select('PRAGMA user_version').single.values.single != 23) {
          throw StateError('SQLite demo pembayaran harus v23.');
        }
      },
    ),
  );
  try {
    final transactions = await db.select(db.transaksis).get();
    if (db.schemaVersion != 23 ||
        transactions.length != 2 ||
        !transactions.any(
          (row) =>
              row.noAkta == paymentDemoNotaris &&
              row.jenisTransaksi == 'notaris',
        ) ||
        !transactions.any(
          (row) =>
              row.noAkta == paymentDemoPpat && row.jenisTransaksi == 'ppat',
        )) {
      throw StateError('Fixture pembayaran berbeda.');
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
    throw StateError('Demo pembayaran hanya untuk Windows debug.');
  }
  HttpOverrides.global = CompletionDemoNoHttp();
  const id = String.fromEnvironment('NOTARIS_PAYMENT_DEMO_ID');
  const helperSha = String.fromEnvironment('NOTARIS_PAYMENT_HELPER_SHA256');
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(helperSha)) {
    throw StateError('Fingerprint helper demo diperlukan.');
  }
  final verifier = Dio();
  try {
    await PaymentDemoAuth(verifier, id, helperSha).verifyProfile();
  } finally {
    verifier.close();
  }
  final db = await openPaymentDemo(id);
  runCompletionDemo(db, auth: (dio) => PaymentDemoAuth(dio, id, helperSha));
}
