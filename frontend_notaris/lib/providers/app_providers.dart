import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../services/sync_service.dart';
import 'database_provider.dart';
import '../repositories/pemohon_gender_references.dart';

final pemohonGenderReferencesProvider = Provider<PemohonGenderReferences?>(
  (ref) => null,
);

/// Satu konfigurasi Dio untuk komunikasi HTTP aplikasi.
final dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      baseUrl: const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://127.0.0.1:8080/api/v1',
      ),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      headers: const {'Accept': 'application/json'},
    ),
  );
});

/// Service sinkronisasi menggunakan database dan HTTP client bersama.
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    db: ref.watch(appDatabaseProvider),
    dio: ref.watch(dioProvider),
  );
});

/// Stream data Pemohon dari SQLite lokal.
final pemohonListProvider = StreamProvider<List<Pemohon>>((ref) {
  final db = ref.watch(appDatabaseProvider);

  return (db.select(
    db.pemohons,
  )..where((tbl) => tbl.deletedAt.isNull())).watch();
});
