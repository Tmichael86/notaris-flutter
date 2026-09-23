import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../services/sync_service.dart';

// Provider Database Singleton
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

// Provider Dio HTTP Client
final dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );
});

// Provider Sync Engine Service
final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(databaseProvider);
  final dio = ref.watch(dioProvider);
  return SyncService(db: db, dio: dio);
});

// Stream Provider untuk Data Pemohon (Real-time dari SQLite)
final pemohonListProvider = StreamProvider<List<Pemohon>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.pemohons)
        ..where((tbl) => tbl.deletedAt.isNull()))
      .watch();
});