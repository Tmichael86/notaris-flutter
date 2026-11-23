part of 'transaction_document_repository.dart';

enum DocumentCorrection { edit, archive, restore }

extension TransactionDocumentLifecycle on TransactionDocumentRepository {
  bool get canCorrect {
    try {
      _admin();
      return true;
    } on DocumentFileFailure {
      return false;
    }
  }

  AuthSession _admin() {
    final actor = _actor(update: true);
    final now = DateTime.now();
    if (_db.schemaVersion != 26 ||
        !actor.canCorrectTransactionPayment ||
        actor.token.trim().isEmpty ||
        now.isBefore(actor.verifiedAt) ||
        now.difference(actor.verifiedAt) > AuthService.offlineGracePeriod) {
      throw const DocumentFileFailure('permission');
    }
    return actor;
  }

  void _sameAdmin(AuthSession actor) {
    if (!identical(actor, _admin())) {
      throw const DocumentFileFailure('session_changed');
    }
  }

  Future<List<TransactionDocument>> listArchived(DocumentOwner owner) async {
    final actor = _admin();
    await _profile();
    await _owner(owner);
    final result = await _visible(owner, archived: true);
    _sameAdmin(actor);
    return result;
  }

  Future<List<TransactionDocument>> history(
    DocumentOwner owner,
    String uuid,
  ) async {
    final actor = _admin();
    await _profile();
    await _owner(owner);
    final result = await _visible(
      owner,
      uuid: uuid,
      archived: null,
      history: true,
    );
    _sameAdmin(actor);
    if (result.isEmpty) throw const DocumentFileFailure('document_not_found');
    return result;
  }

  Future<({ui.Image? image, DocumentPdfPage? pdf})> previewVersion(
    DocumentOwner owner,
    String uuid,
    String versionUuid, {
    int page = 0,
  }) async {
    final actor = _admin();
    final profile = await _profile();
    Future<TransactionDocument> selected() async {
      final rows = await _visible(
        owner,
        uuid: uuid,
        archived: null,
        history: true,
      );
      final version = rows
          .where((row) => row.versionUuid == versionUuid)
          .singleOrNull;
      _sameAdmin(actor);
      if (version == null) {
        throw const DocumentFileFailure('document_not_found');
      }
      return version;
    }

    final version = await selected();
    final store = await _store(profile);
    final bytes = await store.withLease(
      (lease) async =>
          lease.readBlob(versionUuid, version.type, version.digest),
    );
    ui.Image? image;
    try {
      final pdf = version.type == DocumentFileType.pdf
          ? await _preview.pdfPage(bytes, page)
          : null;
      if (pdf == null) image = await _preview.image(bytes, version.type);
      await selected();
      return (image: image, pdf: pdf);
    } catch (_) {
      image?.dispose();
      rethrow;
    }
  }

  Future<TransactionDocument> _logical(DocumentOwner owner, String uuid) async {
    final rows = await _visible(owner, uuid: uuid, archived: null);
    if (rows.length != 1) throw const DocumentFileFailure('document_not_found');
    return rows.single;
  }

  Future<void> correct({
    required DocumentOwner owner,
    required String uuid,
    required int expectedRevision,
    required String operationUuid,
    required DocumentCorrection action,
    String? title,
    String? description,
    String? reason,
  }) async {
    final actor = _admin();
    await _profile();
    final editing = action == DocumentCorrection.edit;
    final restoring = action == DocumentCorrection.restore;
    final name = editing ? _cleanText(title, 255) : null;
    final notes = editing ? _cleanText(description, 1000) : null;
    final why = editing ? null : _cleanText(reason, 500);
    if (!editing && why == null) {
      throw const DocumentFileFailure('reason_required');
    }
    await _db.transaction(() async {
      final doc = await _logical(owner, uuid);
      _sameAdmin(actor);
      final old = await _auditRow(operationUuid);
      if (old != null) {
        final before = jsonDecode(old.read<String>('before_state')) as Map;
        final after = jsonDecode(old.read<String>('after_state')) as Map;
        if (old.read<String>('document_uuid') != uuid ||
            old.read<String>('action') != action.name ||
            old.read<int>('actor_user_id') != actor.userId ||
            old.read<int>('actor_group_id') != actor.groupId ||
            old.readNullable<String>('reason') != why ||
            before['revision'] != expectedRevision ||
            (editing &&
                (after['title'] != name || after['description'] != notes))) {
          throw const DocumentFileFailure('operation_mismatch');
        }
        return;
      }
      if (await _intent(operationUuid) != null) {
        throw const DocumentFileFailure('operation_mismatch');
      }
      _sameAdmin(actor);
      if (doc.revision != expectedRevision) {
        throw const DocumentFileFailure('document_changed');
      }
      if (doc.archived != restoring) {
        throw DocumentFileFailure(
          doc.archived ? 'already_archived' : 'already_restored',
        );
      }
      final now = _now();
      if (editing) {
        await _db.customStatement(
          'UPDATE transaction_documents SET title=?,description=?,updated_at=?,updated_by=?,revision=revision+1 WHERE document_uuid=?',
          [name, notes, now, actor.userId, uuid],
        );
      } else {
        await _db.customStatement(
          'UPDATE transaction_documents SET archived_at=?,archived_by=?,updated_at=?,updated_by=?,revision=revision+1 WHERE document_uuid=?',
          [
            restoring ? null : now,
            restoring ? null : actor.userId,
            now,
            actor.userId,
            uuid,
          ],
        );
      }
      final updated = await _logical(owner, uuid);
      _sameAdmin(actor);
      await _writeAudit(
        operationUuid,
        action.name,
        actor,
        doc,
        updated,
        now,
        why,
      );
    });
  }

  Future<TransactionDocument> replace({
    required DocumentOwner owner,
    required String uuid,
    required int expectedRevision,
    required String operationUuid,
    required String sourcePath,
  }) async {
    final actor = _admin();
    final profile = await _profile();
    final store = await _store(profile);
    return store.withLease((lease) async {
      final doc = await _logical(owner, uuid);
      final original = p.windows.basename(sourcePath);
      final prior = await _intent(operationUuid);
      _sameAdmin(actor);
      if (prior != null) {
        _replacementMatches(prior, owner, actor, uuid, expectedRevision);
        if (prior.readNullable<String>('original_display_name') != original ||
            prior.readNullable<String>('sha256') == null ||
            lease.digestSource(sourcePath) != _digest(prior)) {
          throw const DocumentFileFailure('operation_mismatch');
        }
        return _finishReplacement(lease, owner, actor, prior);
      }
      _requireReplacementTarget(doc, expectedRevision);
      final next = const Uuid().v4();
      await _db.transaction(() async {
        _requireReplacementTarget(
          await _logical(owner, uuid),
          expectedRevision,
        );
        if (await _auditRow(operationUuid) != null) {
          throw const DocumentFileFailure('operation_mismatch');
        }
        _sameAdmin(actor);
        await _db.customStatement(
          '''INSERT INTO transaction_document_operations(
          operation_uuid,action,state,actor_user_id,actor_group_id,transaksi_uuid,detail_uuid,
          document_uuid,version_uuid,original_display_name,started_at,expected_version,expected_document_revision)
          VALUES (?,'replace','staging',?,?,?,?,?,?,?,?,?,?)''',
          [
            operationUuid,
            actor.userId,
            actor.groupId,
            owner.uuid,
            doc.detailUuid,
            uuid,
            next,
            original,
            _now(),
            doc.versionNumber,
            expectedRevision,
          ],
        );
      });
      final DocumentDigest digest;
      final DocumentFileType type;
      try {
        digest = lease.stageSource(operationUuid, sourcePath);
        type = await _preview.validate(
          original,
          lease.readStage(operationUuid, digest),
        );
      } on DocumentFileFailure catch (error) {
        await _db.customStatement(
          "UPDATE transaction_document_operations SET state='rejected',finished_at=?,error_code=? WHERE operation_uuid=? AND state='staging'",
          [_now(), error.code, operationUuid],
        );
        rethrow;
      }
      _sameAdmin(actor);
      await _db.customStatement(
        "UPDATE transaction_document_operations SET state='verified',byte_size=?,media_type=?,sha256=? WHERE operation_uuid=? AND state='staging'",
        [digest.length, type.mediaType, digest.sha256, operationUuid],
      );
      return _finishReplacement(
        lease,
        owner,
        actor,
        (await _intent(operationUuid))!,
      );
    });
  }

  Future<TransactionDocument> resumeReplacement({
    required DocumentOwner owner,
    required String uuid,
    required int expectedRevision,
    required String operationUuid,
  }) async {
    final actor = _admin();
    final profile = await _profile();
    final store = await _store(profile);
    return store.withLease((lease) async {
      final intent = await _intent(operationUuid);
      if (intent == null) throw const DocumentFileFailure('operation_unknown');
      _replacementMatches(intent, owner, actor, uuid, expectedRevision);
      return _finishReplacement(lease, owner, actor, intent);
    });
  }

  Future<({String operationUuid, int revision})?> pendingReplacement(
    DocumentOwner owner,
    String uuid,
  ) async {
    final actor = _admin();
    await _profile();
    final doc = await _logical(owner, uuid);
    final row = await _db
        .customSelect(
          '''SELECT operation_uuid,expected_document_revision
      FROM transaction_document_operations WHERE document_uuid=? AND transaksi_uuid=?
      AND actor_user_id=? AND actor_group_id=? AND expected_document_revision=?
      AND action='replace' AND state IN ('verified','interrupted') ORDER BY started_at DESC,operation_uuid LIMIT 1''',
          variables: [
            Variable(uuid),
            Variable(owner.uuid),
            Variable(actor.userId),
            Variable(actor.groupId),
            Variable(doc.revision),
          ],
        )
        .getSingleOrNull();
    _sameAdmin(actor);
    if (row == null || doc.archived) return null;
    return (
      operationUuid: row.read<String>('operation_uuid'),
      revision: row.read<int>('expected_document_revision'),
    );
  }

  Future<TransactionDocument> _finishReplacement(
    DocumentStoreLease lease,
    DocumentOwner owner,
    AuthSession actor,
    QueryRow intent,
  ) async {
    final operation = intent.read<String>('operation_uuid');
    final uuid = intent.read<String>('document_uuid');
    final version = intent.read<String>('version_uuid');
    final revision = intent.read<int>('expected_document_revision');
    final state = intent.read<String>('state');
    final doc = await _logical(owner, uuid);
    if (doc.detailUuid != intent.readNullable<String>('detail_uuid')) {
      throw const DocumentFileFailure('operation_mismatch');
    }
    _sameAdmin(actor);
    if (state == 'committed') {
      final result = (await history(
        owner,
        uuid,
      )).singleWhere((item) => item.versionUuid == version);
      lease.readBlob(version, result.type, result.digest);
      _sameAdmin(actor);
      return result;
    }
    if (state != 'verified' && state != 'interrupted') {
      throw const DocumentFileFailure('operation_requires_review');
    }
    _requireReplacementTarget(doc, revision);
    final digest = _digest(intent);
    final type = _type(intent.read<String>('media_type'));
    _publishVerified(lease, operation, version, type, digest);
    return _db.transaction(() async {
      final before = await _logical(owner, uuid);
      _requireReplacementTarget(before, revision);
      _sameAdmin(actor);
      final now = _now();
      await _db.customStatement(
        '''INSERT INTO transaction_document_versions(
        version_uuid,document_uuid,version_number,original_display_name,byte_size,media_type,sha256,created_by,created_at)
        VALUES (?,?,?,?,?,?,?,?,?)''',
        [
          version,
          uuid,
          before.versionNumber + 1,
          intent.read<String>('original_display_name'),
          digest.length,
          type.mediaType,
          digest.sha256,
          actor.userId,
          now,
        ],
      );
      await _db.customStatement(
        'UPDATE transaction_documents SET revision=revision+1,updated_at=?,updated_by=? WHERE document_uuid=?',
        [now, actor.userId, uuid],
      );
      final after = await _logical(owner, uuid);
      _sameAdmin(actor);
      await _writeAudit(operation, 'replace', actor, before, after, now, null);
      await _db.customStatement(
        "UPDATE transaction_document_operations SET state='committed',finished_at=? WHERE operation_uuid=?",
        [now, operation],
      );
      _sameAdmin(actor);
      return after;
    });
  }

  void _replacementMatches(
    QueryRow row,
    DocumentOwner owner,
    AuthSession actor,
    String uuid,
    int revision,
  ) {
    if (row.read<String>('action') != 'replace' ||
        row.read<String>('document_uuid') != uuid ||
        row.read<String>('transaksi_uuid') != owner.uuid ||
        row.read<int>('actor_user_id') != actor.userId ||
        row.read<int>('actor_group_id') != actor.groupId ||
        row.readNullable<int>('expected_document_revision') != revision) {
      throw const DocumentFileFailure('operation_mismatch');
    }
  }

  void _requireReplacementTarget(TransactionDocument doc, int revision) {
    if (doc.revision != revision) {
      throw const DocumentFileFailure('document_changed');
    }
    if (doc.archived) throw const DocumentFileFailure('already_archived');
  }

  Future<QueryRow?> _auditRow(String operation) => _db
      .customSelect(
        'SELECT * FROM transaction_document_audit WHERE operation_uuid=?',
        variables: [Variable(operation)],
      )
      .getSingleOrNull();

  Future<void> _writeAudit(
    String operation,
    String action,
    AuthSession actor,
    TransactionDocument before,
    TransactionDocument after,
    int now,
    String? reason,
  ) => _db.customStatement(
    'INSERT INTO transaction_document_audit VALUES(?,?,?,?,?,?,?,?,?)',
    [
      operation,
      before.uuid,
      action,
      actor.userId,
      actor.groupId,
      now,
      _auditState(before),
      _auditState(after),
      reason,
    ],
  );
}

String _auditState(TransactionDocument doc) => jsonEncode({
  'revision': doc.revision,
  'title': doc.title,
  'description': doc.description,
  'archived': doc.archived,
  'version_uuid': doc.versionUuid,
  'sha256': doc.digest.sha256,
  'byte_size': doc.digest.length,
  'original_filename': doc.originalName,
});

String? _cleanText(String? value, int limit) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;
  if (text.length > limit || text.contains('\u0000')) {
    throw const DocumentFileFailure('invalid_metadata');
  }
  return text;
}
