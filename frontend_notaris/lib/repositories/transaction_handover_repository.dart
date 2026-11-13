import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/auth_session.dart';

class HandoverRejected implements Exception {
  const HandoverRejected(this.message);
  final String message;
}

class HandoverRecord {
  HandoverRecord(QueryRow row)
    : uuid = row.read<String>('uuid'),
      description = row.readNullable<String>('uraian'),
      purpose = row.readNullable<String>('keperluan'),
      createdBy = row.read<int>('created_by'),
      createdAt = DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('created_at'),
      ),
      updatedBy = row.readNullable<int>('updated_by'),
      updatedAt = switch (row.readNullable<int>('updated_at')) {
        final time? => DateTime.fromMillisecondsSinceEpoch(time),
        null => null,
      },
      revision = row.read<int>('revision');

  final String uuid;
  final String? description, purpose;
  final int createdBy, revision;
  final int? updatedBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
}

class TransactionHandoverRepository {
  TransactionHandoverRepository(this.db);
  final AppDatabase db;
  static const table = 'transaksi_serah_terima';
  static const localOnlyMessage =
      'Data cetak Serah Terima hanya tersedia lokal.';

  static Future<String?> cloudBlockReason(AppDatabase db, int id) async {
    if (db.schemaVersion < 24) return null;
    final row = await db
        .customSelect(
          'SELECT 1 FROM $table WHERE transaksi_id=? LIMIT 1',
          variables: [Variable(id)],
        )
        .getSingleOrNull();
    return row == null ? null : localOnlyMessage;
  }

  Future<HandoverView> read(int id, AuthSession? session) async {
    _actor(session);
    final rows = await db
        .customSelect(
          '''
      SELECT t.no_akta, a.nama AS applicant, p.nama AS staff, h.* FROM transaksis t
      LEFT JOIN $table h ON h.transaksi_id=t.id
      LEFT JOIN pemohons a
        ON (a.id=t.pemohon_id OR (t.pemohon_id IS NULL AND a.uuid=t.pemohon_uuid))
        AND (t.pemohon_uuid IS NULL OR a.uuid=t.pemohon_uuid)
      LEFT JOIN petugas p
        ON (p.id=t.petugas_id OR (t.petugas_id IS NULL AND p.uuid=t.petugas_uuid))
        AND (t.petugas_uuid IS NULL OR p.uuid=t.petugas_uuid)
      WHERE t.id=? AND t.deleted_at IS NULL
        AND lower(trim(t.status_transaksi))!='dihapus'
        AND t.jenis_transaksi IN ('notaris','ppat') ORDER BY h.id
      ''',
          variables: [Variable(id)],
        )
        .get();
    if (rows.isEmpty) {
      throw const HandoverRejected('Transaksi aktif tidak ditemukan.');
    }
    return (
      number: rows.first.read<String>('no_akta'),
      applicant: rows.first.readNullable<String>('applicant'),
      staff: rows.first.readNullable<String>('staff'),
      records: [
        for (final row in rows)
          if (row.data['uuid'] != null) HandoverRecord(row),
      ],
    );
  }

  Future<void> save({
    required int transactionId,
    required AuthSession? session,
    required String uuid,
    required String description,
    required String purpose,
    int? expectedRevision,
  }) {
    final editing = expectedRevision != null;
    final actor = _actor(session, create: !editing, update: editing);
    final uraian = _optionalText(description);
    final keperluan = _optionalText(purpose);
    if (!RegExp(r'^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$')
            .hasMatch(uuid) ||
        (uraian == null && keperluan == null)) {
      throw const HandoverRejected(
        'Isi uraian atau keperluan sebelum menyimpan.',
      );
    }
    return db.transaction(() async {
      final transaction =
          await (db.select(db.transaksis)..where(
                (t) => t.id.equals(transactionId) & t.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      if (transaction == null ||
          transaction.statusTransaksi.trim().toLowerCase() == 'dihapus' ||
          !{'notaris', 'ppat'}.contains(transaction.jenisTransaksi)) {
        throw const HandoverRejected('Transaksi aktif tidak ditemukan.');
      }
      final pending = await db
          .customSelect(
            'SELECT 1 FROM transaction_cloud_pending WHERE local_uuid=? LIMIT 1',
            variables: [Variable(transaction.uuid)],
          )
          .getSingleOrNull();
      if (pending != null) {
        throw const HandoverRejected(
          'Selesaikan pemeriksaan jurnal sinkronisasi transaksi dahulu.',
        );
      }
      final existing = await db
          .customSelect(
            'SELECT * FROM $table WHERE uuid=?',
            variables: [Variable(uuid)],
          )
          .getSingleOrNull();
      final now = DateTime.now().millisecondsSinceEpoch;
      if (!editing) {
        if (existing == null) {
          await db.customStatement(
            'INSERT INTO $table(uuid,transaksi_id,uraian,keperluan,created_by,created_at) VALUES(?,?,?,?,?,?)',
            [uuid, transactionId, uraian, keperluan, actor, now],
          );
          return;
        }
        final record = HandoverRecord(existing);
        if (existing.read<int>('transaksi_id') == transactionId &&
            record.createdBy == actor &&
            record.revision == 1 &&
            record.description == uraian &&
            record.purpose == keperluan) {
          return;
        }
        throw const HandoverRejected('Identitas data cetak sudah dipakai.');
      }
      if (existing == null ||
          existing.read<int>('transaksi_id') != transactionId ||
          existing.read<int>('revision') != expectedRevision) {
        throw const HandoverRejected(
          'Data cetak berubah. Muat ulang sebelum mengedit.',
        );
      }
      await db.customStatement(
        'UPDATE $table SET uraian=?,keperluan=?,updated_by=?,updated_at=?,revision=revision+1 WHERE uuid=?',
        [uraian, keperluan, actor, now, uuid],
      );
    });
  }

  static int _actor(
    AuthSession? session, {
    bool create = false,
    bool update = false,
  }) {
    if (session?.hasTransactionAccess(create: create, update: update) != true) {
      throw const HandoverRejected('Izin Transaksi tidak mencukupi.');
    }
    return session!.userId;
  }

  static String? _optionalText(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }
}

typedef HandoverView = ({
  String number,
  String? applicant,
  String? staff,
  List<HandoverRecord> records,
});
