part of 'materai_stock_repository.dart';

typedef MateraiCorrectionIntent = ({
  String operation,
  String revision,
  int predecessor,
});
typedef MateraiCorrectionPreview = ({
  String revision,
  int predecessor,
  int stock,
  int sheets,
});

String materaiEditRevision(
  Transaksi header,
  Iterable<TransaksiDetail> details,
) {
  final ordered = details.toList()..sort((a, b) => a.id.compareTo(b.id));
  return materaiProvenanceHash(
    jsonEncode([
      header.toJson(),
      for (final detail in ordered) detail.toJson(),
    ]),
  );
}

const _reloadMaterai = MateraiStockException(
  'Transaksi atau saldo meterai berubah. Muat ulang transaksi sebelum mengoreksi.',
);
const _missingUsage = MateraiStockException(
  'Perlu Ditinjau: pemakaian awal transaksi belum terverifikasi pada profil ini.',
);

extension MateraiTransactionCorrection on MateraiStockRepository {
  Future<MateraiCorrectionPreview?> correctionPreview(int id) async {
    final parent = await _correctionParent(id);
    if (!await hasInitialMateraiUsage(_db, parent.uuid)) return null;
    final actor = _actor(correction: true);
    await _writable();
    final officer = await _officer(actor.userId);
    final head = await _head(officer, transactionUsage: true, correction: true);
    await _originalUsage(parent);
    final revision = await _revision(parent);
    _verifySession(actor, correction: true);
    return (
      revision: revision,
      predecessor: head.predecessor,
      stock: head.stock,
      sheets: parent.jumlahMaterai,
    );
  }

  /// Runs the existing Transaksi update via the same Drift transaction as the
  /// compensation. A retried operation skips the update callback entirely.
  Future<int> correctTransactionUsage(
    AppDatabase db, {
    required int id,
    required int newQuantity,
    required MateraiCorrectionIntent intent,
    required String requestHash,
    required Future<int> Function() persist,
  }) async {
    if (!identical(db, _db) ||
        !_operationPattern.hasMatch(intent.operation) ||
        newQuantity < 0 ||
        newQuantity > materaiReceiptLimit) {
      throw const MateraiStockException(
        'Identitas koreksi tidak sah atau jumlah di luar 0–10.000 lembar.',
      );
    }
    final actor = _actor(correction: true);
    await _writable();
    try {
      return await _db.transaction(() async {
        await _writable();
        final officer = await _officer(actor.userId);
        final parent = await _correctionParent(id);
        final head = await _head(
          officer,
          transactionUsage: true,
          correction: true,
        );
        final original = await _originalUsage(parent);
        final namespace =
            '${binding.namespace}:transaction:${parent.uuid}:adjustment:${intent.operation}';
        final prior = await _db
            .customSelect(
              '''
          SELECT source_namespace, provenance_json FROM materai_movements
          WHERE source_namespace LIKE ? AND substr(source_namespace, -36)=?
          ''',
              variables: [
                Variable('${binding.namespace}:transaction:%:adjustment:%'),
                Variable(intent.operation),
              ],
            )
            .get();
        _verifySession(actor, correction: true);
        if (prior.isNotEmpty) {
          final proof =
              jsonDecode(prior.first.read<String>('provenance_json')) as Map;
          if (prior.length != 1 ||
              prior.first.read<String>('source_namespace') != namespace ||
              proof['request_sha256'] != requestHash ||
              proof['expected_revision'] != intent.revision ||
              proof['previous'] != intent.predecessor ||
              proof['new_quantity'] != newQuantity ||
              proof['user_id'] != actor.userId ||
              proof['group_id'] != actor.groupId) {
            throw const MateraiStockException(
              'UUID koreksi sudah dipakai untuk permintaan berbeda.',
            );
          }
          return id;
        }
        if (head.predecessor != intent.predecessor ||
            await _revision(parent) != intent.revision) {
          throw _reloadMaterai;
        }
        final cloud = await _db
            .customSelect(
              '''
          SELECT 1 FROM transaction_cloud_identity WHERE local_uuid=?
          UNION ALL SELECT 1 FROM transaction_cloud_pending WHERE local_uuid=?
          LIMIT 1
          ''',
              variables: [Variable(parent.uuid), Variable(parent.uuid)],
            )
            .getSingleOrNull();
        if (cloud != null) {
          throw const MateraiStockException(
            'Transaksi memiliki identitas atau mutasi cloud. Koreksi meterai diblokir.',
          );
        }
        final old = parent.jumlahMaterai;
        final delta = newQuantity - old;
        if (delta == 0) return persist();
        if (delta > head.stock) {
          throw MateraiStockException(
            'Stok meterai tidak cukup untuk tambahan $delta lembar. Tersedia ${head.stock} lembar.',
          );
        }
        if (delta < 0 && head.stock > materaiStockLimit + delta) {
          throw const MateraiStockException(
            'Stok hasil pengembalian melebihi batas yang didukung.',
          );
        }

        final result = await persist();
        final updated = await _correctionParent(id);
        if (result != id ||
            updated.uuid != parent.uuid ||
            updated.jenisTransaksi != parent.jenisTransaksi ||
            updated.jumlahMaterai != newQuantity) {
          throw _reloadMaterai;
        }
        final posting = _now().toLocal();
        final date = materaiCalendarDate(posting);
        final recorded = posting.millisecondsSinceEpoch;
        final last = await _db
            .customSelect(
              'SELECT source_created_ms FROM materai_movements WHERE id=?',
              variables: [Variable(head.predecessor)],
            )
            .getSingle();
        if (date.compareTo(head.date) < 0 ||
            recorded <= last.read<int>('source_created_ms')) {
          throw const MateraiStockException(
            'Waktu posting belum melewati mutasi terakhir. Periksa jam perangkat.',
          );
        }
        final stock = head.stock - delta;
        final returning = delta < 0;
        final notes =
            '${returning ? 'Pengembalian' : 'Tambahan pemakaian'} meterai · ${parent.jenisTransaksi.toUpperCase()} ${updated.noAkta}';
        final proof = jsonEncode({
          'kind': returning
              ? 'transaction_usage_return'
              : 'transaction_usage_increase',
          'profile': binding.profileId,
          'operation': intent.operation,
          'transaction_uuid': parent.uuid,
          'transaction_id': id,
          'domain': parent.jenisTransaksi,
          'original_movement': original,
          'request_sha256': requestHash,
          'expected_revision': intent.revision,
          'previous': head.predecessor,
          'date': date,
          'recorded_ms': recorded,
          'quantity': delta.abs(),
          'old_quantity': old,
          'new_quantity': newQuantity,
          'delta': delta,
          'stock': stock,
          'description': notes,
          'user_id': actor.userId,
          'group_id': actor.groupId,
          'actor_verified_at': actor.verifiedAt.toUtc().toIso8601String(),
          'officer_id': officer.id,
          'officer_uuid': officer.uuid,
          'officer': officer.nama,
        });
        _verifySession(actor, correction: true);
        await _db.customInsert(
          '''
          INSERT INTO materai_movements
          (source_namespace, source_id, business_date, source_created_ms, stock_in, stock_out,
           recorded_stock, description, source_officer_id, officer_snapshot, source_status, provenance_json, payload_sha256)
          VALUES (?,1,?,?,?,?,?,?,?,?,1,?,?)
          ''',
          variables: [
            Variable(namespace),
            Variable(date),
            Variable(recorded),
            Variable(returning ? -delta : 0),
            Variable(returning ? 0 : delta),
            Variable(stock),
            Variable(notes),
            Variable(officer.id),
            Variable(officer.nama),
            Variable(proof),
            Variable(materaiProvenanceHash(proof)),
          ],
        );
        return id;
      });
    } on SqliteException catch (error) {
      if ({5, 6, 8}.contains(error.resultCode)) throw _reloadMaterai;
      rethrow;
    }
  }

  Future<Transaksi> _correctionParent(int id) async {
    final row =
        await (_db.select(
              _db.transaksis,
            )..where((table) => table.id.equals(id) & table.deletedAt.isNull()))
            .getSingleOrNull();
    if (row == null || isMateraiCancellation(row.statusTransaksi)) {
      throw _missingUsage;
    }
    return row;
  }

  Future<int> _originalUsage(Transaksi parent) async {
    final row = await _db
        .customSelect(
          '''
      SELECT id FROM materai_movements WHERE source_namespace=? AND source_id=1
      ''',
          variables: [
            Variable('${binding.namespace}:transaction:${parent.uuid}'),
          ],
        )
        .getSingleOrNull();
    if (row == null) throw _missingUsage;
    return row.read<int>('id');
  }

  Future<String> _revision(Transaksi parent) async {
    final details =
        await (_db.select(_db.transaksiDetails)..where(
              (table) =>
                  table.transaksiId.equals(parent.id) &
                  table.deletedAt.isNull() &
                  table.status.equals(1),
            ))
            .get();
    return materaiEditRevision(parent, details);
  }
}
