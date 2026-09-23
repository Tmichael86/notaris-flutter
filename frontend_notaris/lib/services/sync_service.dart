import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'dart:developer' as developer;
import '../database/app_database.dart';

class SyncService {
  final AppDatabase db;
  final Dio dio;
  final String baseUrl;

  SyncService({
    required this.db,
    required this.dio,
    this.baseUrl = 'http://192.168.1.32:3333/api/v1',
  });

  // 1. PULL: Ambil data pemohon & transaksi terbaru dari Server
  Future<void> pullFromCloud() async {
    try {
      final response = await dio.get('$baseUrl/sync/pull');
      if (response.statusCode == 200) {
        final data = response.data;

        // Sync Pull Pemohon
        if (data['pemohons'] != null) {
          for (var item in data['pemohons']) {
            await db.into(db.pemohons).insertOnConflictUpdate(
                  PemohonsCompanion(
                    uuid: Value(item['uuid']),
                    nama: Value(item['nama']),
                    alamat: Value(item['alamat']),
                    nik: Value(item['nik']),
                    isSyncDirty: const Value(false),
                    lastSyncedAt: Value(DateTime.now()),
                  ),
                );
          }
        }

        // Sync Pull Transaksi
        if (data['transaksis'] != null) {
          for (var item in data['transaksis']) {
            await db.into(db.transaksis).insertOnConflictUpdate(
                  TransaksisCompanion(
                    uuid: Value(item['uuid']),
                    noAkta: Value(item['no_akta'] ?? ''),
                    total: Value((item['total'] as num?)?.toDouble() ?? 0.0),
                    pemohonUuid: Value(item['pemohon_uuid']),
                    isSyncDirty: const Value(false),
                    lastSyncedAt: Value(DateTime.now()),
                  ),
                );
          }
        }
      }
    } catch (e, stackTrace) {
      developer.log('Error Sync Pull', error: e, stackTrace: stackTrace);
    }
  }

  // 2. PUSH: Kirim data lokal (Pemohon & Transaksi) yang dirty ke AdonisJS
  Future<void> pushData() async {
    try {
      final dirtyPemohons = await db.getDirtyPemohons();
      final dirtyTransaksis = await db.getDirtyTransaksis();

      if (dirtyPemohons.isEmpty && dirtyTransaksis.isEmpty) return;

      // Susun payload gabungan
      final payload = {
        "pemohons": dirtyPemohons
            .map((e) => {
                  "uuid": e.uuid,
                  "nama": e.nama,
                  "nik": e.nik,
                  "alamat": e.alamat,
                })
            .toList(),
        "transaksis": dirtyTransaksis
            .map((e) => {
                  "uuid": e.uuid,
                  "no_akta": e.noAkta,
                  "total": e.total,
                  "pemohon_uuid": e.pemohonUuid,
                })
            .toList(),
      };

      final response = await dio.post('$baseUrl/sync/push', data: payload);

      if (response.statusCode == 200) {
        final syncedAt = response.data['synced_at'] != null
            ? DateTime.parse(response.data['synced_at'])
            : DateTime.now();

        // Tandai Pemohon ter-sync
        for (var item in dirtyPemohons) {
          await db.markAsSynced(item.uuid, syncedAt);
        }

        // Tandai Transaksi ter-sync
        for (var item in dirtyTransaksis) {
          await db.markTransaksiAsSynced(item.uuid, syncedAt);
        }
      }
    } catch (e, stackTrace) {
      developer.log('Error Sync Push', error: e, stackTrace: stackTrace);
    }
  }
}