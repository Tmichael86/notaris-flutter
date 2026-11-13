import 'package:drift/drift.dart';

import '../database/app_database.dart';

const transactionDocumentUploadBlock =
    'Lampiran transaksi hanya tersedia lokal dan tidak dapat diunggah.';

/// Applies only to the owning transaction, including an unfinished local
/// import that may already have staged or published managed bytes.
Future<String?> transactionDocumentUploadBlockReason(
  AppDatabase db,
  String transactionUuid,
) async {
  if (db.schemaVersion < 25) return null;
  final match = await db
      .customSelect(
        '''SELECT 1 FROM transaction_documents WHERE transaksi_uuid=?
    UNION ALL
    SELECT 1 FROM transaction_document_operations WHERE transaksi_uuid=?
      AND state IN ('staging','verified','interrupted')
    LIMIT 1''',
        variables: [Variable(transactionUuid), Variable(transactionUuid)],
      )
      .getSingleOrNull();
  return match == null ? null : transactionDocumentUploadBlock;
}
