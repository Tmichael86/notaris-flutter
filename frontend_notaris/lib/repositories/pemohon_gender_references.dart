import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../database/app_database.dart';

class PemohonReferenceBlocked extends StateError {
  PemohonReferenceBlocked(super.message);
}

abstract interface class PemohonGenderReferences {
  Future<void> prepare();
  Future<int> toLocal(int serverId);
  Future<int> toServer(int localId);
}

/// Only installed by the explicit notarisdev entry point. The fixture producer
/// supplies UUID/server-ID pairs; labels are display data, never lookup keys.
class DevelopmentPemohonGenderReferences implements PemohonGenderReferences {
  DevelopmentPemohonGenderReferences(this.db, this.dio, this.manifest);
  final AppDatabase db;
  final Dio dio;
  final Map<String, dynamic> manifest;

  List<Map<String, dynamic>> _pairs() {
    final values = manifest['genders'];
    if (manifest['fixture'] != 'smoke-v1' ||
        values is! List ||
        values.isEmpty) {
      throw PemohonReferenceBlocked(
        'blocked_reference: fixture reference manifest missing',
      );
    }
    final ids = <int>{};
    final uuids = <String>{};
    return values.map((value) {
      if (value is! Map) {
        throw PemohonReferenceBlocked('blocked_reference: invalid pair');
      }
      final row = Map<String, dynamic>.from(value);
      if (row['state'] != 'verified' ||
          row['server_id'] is! int ||
          row['server_id'] < 1 ||
          row['local_uuid'] is! String ||
          (row['local_uuid'] as String).isEmpty ||
          row['label'] is! String ||
          !ids.add(row['server_id']) ||
          !uuids.add(row['local_uuid'])) {
        throw PemohonReferenceBlocked(
          'blocked_reference: unverified or ambiguous fixture mapping',
        );
      }
      return row;
    }).toList();
  }

  Future<void> bootstrapLocal() async {
    final pairs = _pairs();
    await db.transaction(() async {
      for (final pair in pairs) {
        final rows = await (db.select(
          db.jenisKelamins,
        )..where((r) => r.uuid.equals(pair['local_uuid'] as String))).get();
        if (rows.length > 1) {
          throw PemohonReferenceBlocked(
            'blocked_reference: duplicate local reference UUID',
          );
        }
        if (rows.isEmpty) {
          await db
              .into(db.jenisKelamins)
              .insert(
                JenisKelaminsCompanion.insert(
                  uuid: pair['local_uuid'] as String,
                  nama: pair['label'] as String,
                  isSyncDirty: const Value(false),
                ),
              );
        } else if (rows.single.status != 1 || rows.single.deletedAt != null) {
          throw PemohonReferenceBlocked(
            'blocked_reference: local reference inactive',
          );
        }
      }
    });
  }

  @override
  Future<void> prepare() async {
    final pairs = _pairs();
    // Existing read-only catalog requires Petugas-read permission. This fixture
    // operator has it; failure blocks dependency resolution, never bypasses auth.
    final response = await dio.get<Map<String, dynamic>>(
      '/petugas/references/jenis-kelamin',
    );
    final body = response.data;
    final items = body?['data'] is Map ? body!['data']['items'] : null;
    if (body?['success'] != true || items is! List) {
      throw PemohonReferenceBlocked(
        'blocked_reference: server catalog unavailable',
      );
    }
    final seen = <int>{};
    for (final row in items) {
      if (row is! Map ||
          row['id'] is! int ||
          row['status'] != 1 ||
          !seen.add(row['id'])) {
        throw PemohonReferenceBlocked(
          'blocked_reference: ambiguous server catalog',
        );
      }
    }
    if (pairs.any((p) => !seen.contains(p['server_id']))) {
      throw PemohonReferenceBlocked(
        'blocked_reference: fixture reference absent on server',
      );
    }
    await bootstrapLocal();
  }

  @override
  Future<int> toLocal(int serverId) async {
    final pair = _pairs().where((p) => p['server_id'] == serverId).toList();
    if (pair.length != 1) {
      throw PemohonReferenceBlocked(
        'blocked_reference: unmapped server gender',
      );
    }
    final rows = await (db.select(
      db.jenisKelamins,
    )..where((r) => r.uuid.equals(pair.single['local_uuid'] as String))).get();
    if (rows.length != 1 ||
        rows.single.status != 1 ||
        rows.single.deletedAt != null) {
      throw PemohonReferenceBlocked(
        'blocked_reference: local reference unavailable',
      );
    }
    return rows.single.id;
  }

  @override
  Future<int> toServer(int localId) async {
    final row = await (db.select(
      db.jenisKelamins,
    )..where((r) => r.id.equals(localId))).getSingleOrNull();
    final pairs = _pairs().where((p) => p['local_uuid'] == row?.uuid).toList();
    if (row == null ||
        row.status != 1 ||
        row.deletedAt != null ||
        pairs.length != 1) {
      throw PemohonReferenceBlocked(
        'blocked_reference: local gender not explicitly mapped',
      );
    }
    return pairs.single['server_id'] as int;
  }
}
