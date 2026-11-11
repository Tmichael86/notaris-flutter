import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'transaction_cloud_references.dart';
import 'transaction_cloud_repository.dart';

/// Read-only assessment, never authorization, mutation creation or scope binding.
class TransactionUploadReadiness {
  TransactionUploadReadiness(this.db);
  final AppDatabase db;
  Future<List<String>> check(
    int id, {
    required String domain,
    required String uuid,
    required String? petugasScope,
    required String? masterScope,
  }) => db.transaction(() async {
    final issues = <String>[];
    final header = await (db.select(
      db.transaksis,
    )..where((r) => r.id.equals(id))).getSingle();
    if (await TransactionCloudRepository.localCompletionBlockReason(db, header)
        case final reason?) {
      issues.add(reason);
    }
    if (header.uuid != uuid ||
        header.jenisTransaksi != domain ||
        !{'notaris', 'ppat'}.contains(domain) ||
        !RegExp(r'^[a-fA-F0-9]{8}(-[a-fA-F0-9]{4}){3}-[a-fA-F0-9]{12}$')
            .hasMatch(uuid)) {
      issues.add('Identitas UUID / domain tidak cocok.');
    }
    if (header.deletedAt != null) {
      issues.add('Record terhapus memerlukan pemeriksaan tombstone.');
    }
    final details = await (db.select(
      db.transaksiDetails,
    )..where((r) => r.transaksiId.equals(id) & r.deletedAt.isNull())).get();
    if (details.isEmpty ||
        details.any((r) => r.hargaUuid == null || r.kategoriUuid == null)) {
      issues.add(
        'Provenance harga/kategori belum lengkap; tidak direkonstruksi dari nama atau nominal.',
      );
    }
    if ({'notaris', 'ppat'}.contains(domain)) {
      for (final detail in details) {
        final masterId = domain == 'notaris'
            ? detail.pekerjaanNotarisId
            : detail.pekerjaanPpatId;
        final mapped = await db
            .customSelect(
              'SELECT i.cloud_uuid FROM pekerjaan_$domain p JOIN pekerjaan_${domain}_sync_identity i ON i.local_uuid=p.uuid WHERE p.id=? AND p.deleted_at IS NULL AND p.status=1 AND p.is_sync_dirty=0 AND i.revision>0',
              variables: [Variable(masterId ?? -1)],
            )
            .get();
        if (mapped.length != 1) {
          issues.add(
            'Master pekerjaan belum memiliki identity cloud aktif yang terverifikasi.',
          );
          break;
        }
      }
    }
    final pending = await db
        .customSelect(
          'SELECT * FROM transaction_cloud_pending WHERE local_uuid=?',
          variables: [Variable(uuid)],
        )
        .getSingleOrNull();
    if (pending != null) {
      if (pending.read<String>('state') == 'acked') {
        issues.add('ACK tersimpan; publication belum diverifikasi.');
      }
      try {
        final payload = jsonDecode(pending.read<String>('payload')) as Map;
        if (payload['uuid'] != uuid ||
            payload['domain'] != domain ||
            payload['mutation_id'] != pending.read<String>('mutation_id')) {
          issues.add('Mutation existing membutuhkan pemeriksaan identitas.');
        }
      } catch (_) {
        issues.add('Payload mutation existing tidak dapat diverifikasi.');
      }
    }
    final actor = await db
        .customSelect(
          '''SELECT 1 FROM transaksi_proses p WHERE p.transaksi_id=? AND
      (p.submitted_by_user_id IS NOT NULL OR p.validated_by_user_id IS NOT NULL OR p.submitted_at IS NOT NULL OR p.validated_at IS NOT NULL
       OR EXISTS(SELECT 1 FROM transaksi_proses_riwayat a WHERE a.transaksi_proses_id=p.id)) LIMIT 1''',
          variables: [Variable(id)],
        )
        .get();
    if (actor.isNotEmpty) {
      issues.add('Audit transisi proses membutuhkan provenance actor cloud.');
    }
    if (petugasScope == null || masterScope == null) {
      issues.add('Scope dependency Master/Petugas belum terverifikasi.');
    } else {
      try {
        await TransactionCloudReferences(
          db,
          petugasScope: petugasScope,
          masterScope: masterScope,
        ).prepare(id);
      } on StateError {
        issues.add(
          'Referensi cloud Pemohon/Petugas/Master/harga/kategori belum valid dalam scope ini.',
        );
      }
    }
    return issues;
  });
}
