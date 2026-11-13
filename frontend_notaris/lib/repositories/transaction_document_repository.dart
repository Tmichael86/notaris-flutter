import 'dart:ffi';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../models/auth_session.dart';
import '../services/auth_service.dart';
import '../services/transaction_document_preview.dart';
import '../services/windows_transaction_document_store.dart';

typedef DocumentOwner = ({int id, String uuid, String domain});

class TransactionDocument {
  TransactionDocument(QueryRow row)
    : uuid = row.read<String>('document_uuid'),
      versionUuid = row.read<String>('version_uuid'),
      detailUuid = row.readNullable<String>('detail_uuid'),
      displayName = row.read<String>('original_display_name'),
      actor = row.read<int>('created_by'),
      importedAt = DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('created_at'),
        isUtc: true,
      ),
      type = _type(row.read<String>('media_type')),
      digest = (
        length: row.read<int>('byte_size'),
        sha256: row.read<String>('sha256'),
      );

  final String uuid, versionUuid, displayName;
  final String? detailUuid;
  final int actor;
  final DateTime importedAt;
  final DocumentFileType type;
  final DocumentDigest digest;
}

/// Entry points for Phase A. The profile binding comes from application
/// wiring, not from a caller-selected document path or an arbitrary UUID.
class TransactionDocumentRepository {
  TransactionDocumentRepository({
    required this._db,
    required this._session,
    required String verifiedDatabasePath,
    required String verifiedAppDirectory,
    TransactionDocumentPreview? preview,
    this._storageLibrary,
  }) : _databasePath = verifiedDatabasePath,
       _appDirectory = verifiedAppDirectory,
       _preview = preview ?? TransactionDocumentPreview();

  final AppDatabase _db;
  final AuthSession? Function() _session;
  final String _databasePath, _appDirectory;
  final TransactionDocumentPreview _preview;
  final DynamicLibrary? _storageLibrary;

  Future<List<TransactionDocument>> listActive(DocumentOwner owner) async {
    final actor = _actor();
    await _profile();
    await _owner(owner);
    final rows = await _visible(owner);
    _sameActor(actor);
    return rows;
  }

  Future<({TransactionDocument document, Uint8List bytes})> readActive(
    DocumentOwner owner,
    String uuid,
  ) async {
    final actor = _actor();
    final profile = await _profile();
    await _owner(owner);
    final document = await _one(owner, uuid);
    final store = await _store(profile);
    return store.withLease((lease) async {
      final bytes = lease.readBlob(
        document.versionUuid,
        document.type,
        document.digest,
      );
      await _owner(owner, detailUuid: document.detailUuid);
      final current = await _one(owner, uuid);
      _sameActor(actor);
      if (current.versionUuid != document.versionUuid) {
        throw const DocumentFileFailure('document_changed');
      }
      return (document: document, bytes: bytes);
    });
  }

  /// A raster result has no link, form, script, or external-handler actions.
  /// The consumer owns a returned Flutter image and must dispose it.
  Future<({ui.Image? image, DocumentPdfPage? pdf})> previewActive(
    DocumentOwner owner,
    String uuid, {
    int page = 0,
  }) async {
    final actor = _actor();
    final selected = await readActive(owner, uuid);
    ui.Image? image;
    try {
      final pdf = selected.document.type == DocumentFileType.pdf
          ? await _preview.pdfPage(selected.bytes, page)
          : null;
      if (pdf == null) {
        image = await _preview.image(selected.bytes, selected.document.type);
      }
      final current = await _one(owner, uuid);
      _sameActor(actor);
      if (current.versionUuid != selected.document.versionUuid) {
        throw const DocumentFileFailure('document_changed');
      }
      return (image: image, pdf: pdf);
    } catch (_) {
      image?.dispose();
      rethrow;
    }
  }

  Future<TransactionDocument> importFile({
    required DocumentOwner owner,
    required String operationUuid,
    required String sourcePath,
    String? detailUuid,
  }) async {
    final actor = _actor(update: true);
    final profile = await _profile();
    await _owner(owner, detailUuid: detailUuid);
    final displayName = p.windows.basename(sourcePath);
    if (displayName.trim().isEmpty || displayName.contains('\u0000')) {
      throw const DocumentFileFailure('source_open');
    }
    _sameActor(actor, update: true);
    final store = await _store(profile, create: true);
    return store.withLease((lease) async {
      _sameActor(actor, update: true);
      final prior = await _intent(operationUuid);
      if (prior != null) {
        _match(prior, actor, owner, detailUuid);
        if (prior.read<String>('state') != 'committed' ||
            prior.read<String>('original_display_name') != displayName ||
            lease.digestSource(sourcePath) != _digest(prior)) {
          throw const DocumentFileFailure('operation_exists');
        }
        final document = await _one(owner, prior.read<String>('document_uuid'));
        lease.readBlob(document.versionUuid, document.type, document.digest);
        _sameActor(actor, update: true);
        return document;
      }
      final documentId = const Uuid().v4(), versionId = const Uuid().v4();
      await _db.transaction(() async {
        await _owner(owner, detailUuid: detailUuid);
        _sameActor(actor, update: true);
        await _db.customStatement(
          '''INSERT INTO transaction_document_operations(
          operation_uuid,action,state,actor_user_id,actor_group_id,transaksi_uuid,
          detail_uuid,document_uuid,version_uuid,original_display_name,started_at)
          VALUES (?,'import','staging',?,?,?,?,?,?,?,?)''',
          [
            operationUuid,
            actor.userId,
            actor.groupId,
            owner.uuid,
            detailUuid,
            documentId,
            versionId,
            displayName,
            _now(),
          ],
        );
      });

      final DocumentDigest digest;
      final DocumentFileType type;
      try {
        digest = lease.stageSource(operationUuid, sourcePath);
        type = await _preview.validate(
          displayName,
          lease.readStage(operationUuid, digest),
        );
      } on DocumentFileFailure catch (error) {
        // The new version has not reached publication. Retain any stage, but
        // release the owner's upload guard once failure is durable.
        await _db.customStatement(
          '''UPDATE transaction_document_operations
          SET state='rejected',finished_at=?,error_code=?
          WHERE operation_uuid=? AND state='staging' ''',
          [_now(), error.code, operationUuid],
        );
        rethrow;
      }
      _sameActor(actor, update: true);
      await _db.customStatement(
        '''UPDATE transaction_document_operations
        SET state='verified',byte_size=?,media_type=?,sha256=?
        WHERE operation_uuid=? AND state='staging' ''',
        [digest.length, type.mediaType, digest.sha256, operationUuid],
      );
      final verified = (await _intent(operationUuid))!;
      return _finish(lease, verified, owner, actor);
    });
  }

  /// Explicit reconciliation of a verified operation, with the original actor
  /// and owner. A staging-only or mismatched file remains for review.
  Future<TransactionDocument> resumeVerifiedImport({
    required DocumentOwner owner,
    required String operationUuid,
  }) async {
    final actor = _actor(update: true);
    final profile = await _profile();
    await _owner(owner);
    final store = await _store(profile);
    return store.withLease((lease) async {
      final intent = await _intent(operationUuid);
      if (intent == null) throw const DocumentFileFailure('operation_unknown');
      final detailUuid = intent.readNullable<String>('detail_uuid');
      _match(intent, actor, owner, detailUuid);
      await _owner(owner, detailUuid: detailUuid);
      final state = intent.read<String>('state');
      if (state == 'committed') {
        final document = await _one(
          owner,
          intent.read<String>('document_uuid'),
        );
        lease.readBlob(document.versionUuid, document.type, document.digest);
        _sameActor(actor, update: true);
        return document;
      }
      if (state != 'verified' && state != 'interrupted') {
        throw const DocumentFileFailure('operation_requires_review');
      }
      return _finish(lease, intent, owner, actor);
    });
  }

  Future<TransactionDocument> _finish(
    DocumentStoreLease lease,
    QueryRow intent,
    DocumentOwner owner,
    AuthSession actor,
  ) async {
    final operation = intent.read<String>('operation_uuid');
    final version = intent.read<String>('version_uuid');
    final document = intent.read<String>('document_uuid');
    final detail = intent.readNullable<String>('detail_uuid');
    final type = _type(intent.read<String>('media_type'));
    final digest = _digest(intent);
    await _owner(owner, detailUuid: detail);
    _sameActor(actor, update: true);
    try {
      lease.readBlob(version, type, digest);
    } on DocumentFileFailure catch (error) {
      if (error.code != 'blob_open' || error.nativeCode != 2) rethrow;
      lease.publish(operation, version, type, digest);
    }
    await _db.transaction(() async {
      await _owner(owner, detailUuid: detail);
      _sameActor(actor, update: true);
      final now = _now();
      await _db.customStatement(
        '''INSERT INTO transaction_documents(
        document_uuid,transaksi_uuid,detail_uuid,created_by,created_at) VALUES (?,?,?,?,?)''',
        [document, owner.uuid, detail, actor.userId, now],
      );
      await _db.customStatement(
        '''INSERT INTO transaction_document_versions(
        version_uuid,document_uuid,version_number,original_display_name,byte_size,media_type,sha256,created_by,created_at)
        VALUES (?,?,1,?,?,?,?,?,?)''',
        [
          version,
          document,
          intent.read<String>('original_display_name'),
          digest.length,
          type.mediaType,
          digest.sha256,
          actor.userId,
          now,
        ],
      );
      await _db.customStatement(
        '''UPDATE transaction_document_operations
        SET state='committed',finished_at=? WHERE operation_uuid=?''',
        [now, operation],
      );
    });
    _sameActor(actor, update: true);
    return _one(owner, document);
  }

  AuthSession _actor({bool update = false}) {
    final actor = _session();
    if (actor == null ||
        actor.groupId <= 0 ||
        !actor.hasTransactionAccess(update: update) ||
        (actor.isOffline &&
            DateTime.now().difference(actor.verifiedAt) >
                AuthService.offlineGracePeriod)) {
      throw const DocumentFileFailure('permission');
    }
    return actor;
  }

  void _sameActor(AuthSession original, {bool update = false}) {
    if (!identical(original, _actor(update: update))) {
      throw const DocumentFileFailure('session_changed');
    }
  }

  Future<String> _profile() async {
    if (!Platform.isWindows ||
        _db.schemaVersion != 25 ||
        !p.windows.isAbsolute(_databasePath)) {
      throw const DocumentFileFailure('invalid_profile');
    }
    final database = (await _db.customSelect('PRAGMA database_list').get())
        .singleWhere((row) => row.read<String>('name') == 'main')
        .read<String>('file');
    if (database.isEmpty ||
        !p.windows.equals(database, _databasePath) ||
        (await _db.customSelect('PRAGMA user_version').getSingle()).read<int>(
              'user_version',
            ) !=
            25) {
      throw const DocumentFileFailure('invalid_profile');
    }
    return p.windows.normalize(database).toLowerCase();
  }

  Future<WindowsTransactionDocumentStore> _store(
    String profile, {
    bool create = false,
  }) async {
    if (create) {
      await _db.customStatement(
        'INSERT OR IGNORE INTO transaction_document_store VALUES (1,?)',
        [const Uuid().v4()],
      );
    }
    final row = await _db
        .customSelect(
          'SELECT store_uuid FROM transaction_document_store WHERE id=1',
        )
        .getSingleOrNull();
    if (row == null) throw const DocumentFileFailure('store_unbound');
    return WindowsTransactionDocumentStore(
      verifiedAppDirectory: _appDirectory,
      verifiedProfileIdentity: profile,
      storeUuid: row.read<String>('store_uuid'),
      library: _storageLibrary,
    );
  }

  Future<void> _owner(DocumentOwner owner, {String? detailUuid}) async {
    final row = await _db
        .customSelect(
          '''SELECT 1 FROM transaksis t
      WHERE t.id=? AND t.uuid=? AND t.jenis_transaksi=? AND t.jenis_transaksi IN ('notaris','ppat')
        AND t.deleted_at IS NULL AND lower(trim(t.status_transaksi))<>'dihapus'
        AND (? IS NULL OR EXISTS (SELECT 1 FROM transaksi_details d WHERE d.uuid=?
          AND d.transaksi_id=t.id AND d.jenis_pekerjaan=t.jenis_transaksi AND d.status=1 AND d.deleted_at IS NULL))''',
          variables: [
            Variable(owner.id),
            Variable(owner.uuid),
            Variable(owner.domain),
            Variable(detailUuid),
            Variable(detailUuid),
          ],
        )
        .getSingleOrNull();
    if (row == null) throw const DocumentFileFailure('invalid_owner');
  }

  Future<List<TransactionDocument>> _visible(
    DocumentOwner owner, {
    String? uuid,
  }) async =>
      (await _db
              .customSelect(
                '''SELECT d.document_uuid,d.detail_uuid,v.version_uuid,
          v.original_display_name,v.byte_size,v.media_type,v.sha256,v.created_by,v.created_at
        FROM transaction_documents d JOIN transaksis t ON t.uuid=d.transaksi_uuid
        JOIN transaction_document_versions v ON v.document_uuid=d.document_uuid
        WHERE t.id=? AND t.uuid=? AND t.jenis_transaksi=? AND d.archived_at IS NULL
          AND t.deleted_at IS NULL AND lower(trim(t.status_transaksi))<>'dihapus'
          AND (? IS NULL OR d.document_uuid=?)
          AND (d.detail_uuid IS NULL OR EXISTS (SELECT 1 FROM transaksi_details j WHERE j.uuid=d.detail_uuid
            AND j.transaksi_id=t.id AND j.jenis_pekerjaan=t.jenis_transaksi AND j.status=1 AND j.deleted_at IS NULL))
          AND NOT EXISTS (SELECT 1 FROM transaction_document_versions newer
            WHERE newer.document_uuid=d.document_uuid AND newer.version_number>v.version_number)
        ORDER BY v.created_at DESC,d.document_uuid''',
                variables: [
                  Variable(owner.id),
                  Variable(owner.uuid),
                  Variable(owner.domain),
                  Variable(uuid),
                  Variable(uuid),
                ],
              )
              .get())
          .map(TransactionDocument.new)
          .toList();

  Future<TransactionDocument> _one(DocumentOwner owner, String uuid) async {
    final rows = await _visible(owner, uuid: uuid);
    if (rows.length != 1) throw const DocumentFileFailure('document_not_found');
    return rows.single;
  }

  Future<QueryRow?> _intent(String uuid) => _db
      .customSelect(
        'SELECT * FROM transaction_document_operations WHERE operation_uuid=?',
        variables: [Variable(uuid)],
      )
      .getSingleOrNull();

  void _match(
    QueryRow intent,
    AuthSession actor,
    DocumentOwner owner,
    String? detail,
  ) {
    if (intent.read<String>('action') != 'import' ||
        intent.read<String>('transaksi_uuid') != owner.uuid ||
        intent.readNullable<String>('detail_uuid') != detail ||
        intent.read<int>('actor_user_id') != actor.userId ||
        intent.read<int>('actor_group_id') != actor.groupId) {
      throw const DocumentFileFailure('operation_mismatch');
    }
  }
}

DocumentDigest _digest(QueryRow row) =>
    (length: row.read<int>('byte_size'), sha256: row.read<String>('sha256'));
DocumentFileType _type(String mime) => DocumentFileType.values.firstWhere(
  (type) => type.mediaType == mime,
  orElse: () => throw const DocumentFileFailure('unsupported_content'),
);
int _now() => DateTime.now().millisecondsSinceEpoch;
