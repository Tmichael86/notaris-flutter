import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// Read-only preparation, never a push authorization or an acknowledged mutation.
/// The server must revalidate these UUIDs inside its aggregate transaction.
class TransactionCloudReferences {
  TransactionCloudReferences(
    this.db, {
    required this.petugasScope,
    required this.masterScope,
  });
  final AppDatabase db;
  final String petugasScope;
  final String masterScope;
  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Price UUIDs must come from explicit selection provenance. Existing labels,
  /// prices and integer IDs cannot reconstruct a lost historical selection.
  Future<Map<String, dynamic>> prepare(
    int transactionId, {
    Map<String, String> selectedPriceUuids = const {},
  }) => db.transaction(() async {
    if (petugasScope.isEmpty || masterScope.isEmpty) {
      throw StateError('Reference scopes required');
    }
    final header =
        await (db.select(db.transaksis)
              ..where((t) => t.id.equals(transactionId) & t.deletedAt.isNull()))
            .getSingle();
    final domain = header.jenisTransaksi;
    if (!{'notaris', 'ppat'}.contains(domain)) {
      throw StateError('Invalid transaction domain');
    }
    final applicant = await (db.select(
      db.pemohons,
    )..where((t) => t.id.equals(header.pemohonId ?? -1))).getSingle();
    if (applicant.uuid != header.pemohonUuid ||
        applicant.isSyncDirty ||
        applicant.deletedAt != null ||
        applicant.status != 1 ||
        applicant.lastSyncedAt == null ||
        !_uuid.hasMatch(applicant.uuid)) {
      throw StateError('Pemohon cloud identity unresolved');
    }
    final officer = await (db.select(
      db.petugasLocals,
    )..where((t) => t.id.equals(header.petugasId ?? -1))).getSingle();
    final mappings = await (db.select(
      db.petugasIdentityMaps,
    )..where((t) => t.localUuid.equals(officer.uuid))).get();
    final feed = await db
        .customSelect('SELECT scope,blocked FROM petugas_sync_feed WHERE id=1')
        .getSingleOrNull();
    final journal = await db
        .customSelect(
          'SELECT row_version,pending FROM petugas_sync_journal WHERE local_uuid=?',
          variables: [Variable(officer.uuid)],
        )
        .getSingleOrNull();
    if (officer.uuid != header.petugasUuid ||
        officer.isSyncDirty ||
        officer.deletedAt != null ||
        officer.status != 1 ||
        mappings.length != 1 ||
        !{'verified', 'server_only'}.contains(mappings.single.state) ||
        mappings.single.evidence?.trim().isNotEmpty != true ||
        mappings.single.serverId == null ||
        mappings.single.serverId! < 1 ||
        !_uuid.hasMatch(mappings.single.cloudUuid ?? '') ||
        feed?.read<String>('scope') != petugasScope ||
        feed?.readNullable<String>('blocked') != null ||
        journal == null ||
        (journal.readNullable<int>('row_version') ?? 0) < 1 ||
        journal.readNullable<String>('pending') != null) {
      throw StateError('Petugas cloud mapping unresolved');
    }
    final applicantDuplicates = await (db.select(
      db.pemohons,
    )..where((t) => t.uuid.equals(applicant.uuid))).get();
    final officerDuplicates = await (db.select(
      db.petugasIdentityMaps,
    )..where((t) => t.cloudUuid.equals(mappings.single.cloudUuid!))).get();
    if (applicantDuplicates.length != 1 || officerDuplicates.length != 1) {
      throw StateError('Ambiguous cloud reference');
    }
    final details =
        await (db.select(db.transaksiDetails)..where(
              (t) =>
                  t.transaksiId.equals(transactionId) &
                  t.deletedAt.isNull() &
                  t.status.equals(1),
            ))
            .get();
    if (details.isEmpty ||
        details.any((d) => d.hargaUuid == null || d.kategoriUuid == null) ||
        selectedPriceUuids.entries.any(
          (e) => !details.any((d) => d.uuid == e.key && d.hargaUuid == e.value),
        )) {
      throw StateError(
        'Explicit price/category provenance required for every detail',
      );
    }
    final jobs = <Map<String, dynamic>>[];
    for (final detail in details) {
      final id = domain == 'notaris'
          ? detail.pekerjaanNotarisId
          : detail.pekerjaanPpatId;
      if (detail.jenisPekerjaan != domain ||
          id == null ||
          (domain == 'notaris'
                  ? detail.pekerjaanPpatId
                  : detail.pekerjaanNotarisId) !=
              null) {
        throw StateError('Job domain mismatch');
      }
      final rows = await db
          .customSelect(
            'SELECT p.uuid,i.cloud_uuid,i.revision FROM pekerjaan_$domain p JOIN pekerjaan_${domain}_sync_identity i ON i.local_uuid=p.uuid WHERE p.id=? AND p.status=1 AND p.deleted_at IS NULL AND p.is_sync_dirty=0 AND i.scope=? AND NOT EXISTS(SELECT 1 FROM pekerjaan_${domain}_sync_pending m WHERE m.local_uuid=p.uuid AND m.state=\'pending\')',
            variables: [Variable(id), Variable(masterScope)],
          )
          .get();
      if (rows.length != 1 ||
          rows.single.read<int>('revision') < 1 ||
          !_uuid.hasMatch(rows.single.read<String>('cloud_uuid'))) {
        throw StateError('Job cloud identity unresolved');
      }
      final priceUuid = detail.hargaUuid!;
      if (!_uuid.hasMatch(priceUuid)) {
        throw StateError('Invalid selected price UUID');
      }
      final price = await db
          .customSelect(
            'SELECT c.uuid AS category_uuid FROM pekerjaan_${domain}_harga h JOIN pekerjaan_kategori c ON c.id=h.kategori_pekerjaan_id WHERE h.uuid=? AND h.pekerjaan_${domain}_id=? AND h.status=1 AND h.deleted_at IS NULL AND h.is_sync_dirty=0 AND c.status=1 AND c.deleted_at IS NULL AND c.is_sync_dirty=0',
            variables: [Variable(priceUuid), Variable(id)],
          )
          .get();
      if (price.length != 1 ||
          !_uuid.hasMatch(price.single.read<String>('category_uuid')) ||
          price.single.read<String>('category_uuid') != detail.kategoriUuid) {
        throw StateError('Price/category reference unresolved');
      }
      jobs.add({
        'detail_uuid': detail.uuid,
        'job_uuid': rows.single.read<String>('cloud_uuid'),
        'price_uuid': priceUuid,
        'category_uuid': price.single.read<String>('category_uuid'),
      });
    }
    return {
      'pemohon_uuid': applicant.uuid,
      'petugas_uuid': mappings.single.cloudUuid,
      'domain': domain,
      'jobs': jobs,
    };
  });
}
