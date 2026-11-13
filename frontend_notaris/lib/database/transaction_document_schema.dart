part of 'app_database.dart';

// The v25 migration is exercised on disposable databases. The application
// remains on v24 until the managed storage and preview gates are validated.
extension _TransactionDocumentSchema on AppDatabase {
  Future<void> _createDocumentLifecycle() async {
    await customStatement(
      'ALTER TABLE transaction_documents ADD COLUMN title TEXT',
    );
    await customStatement(
      'ALTER TABLE transaction_documents ADD COLUMN description TEXT',
    );
    await customStatement(
      'ALTER TABLE transaction_documents ADD COLUMN revision INTEGER NOT NULL DEFAULT 1 CHECK(revision>0)',
    );
    await customStatement(
      'ALTER TABLE transaction_document_operations ADD COLUMN expected_document_revision INTEGER CHECK(expected_document_revision>0)',
    );
    await customStatement(
      '''CREATE TRIGGER transaction_document_expected_revision_immutable
      BEFORE UPDATE OF expected_document_revision ON transaction_document_operations
      WHEN OLD.expected_document_revision IS NOT NEW.expected_document_revision
      BEGIN SELECT RAISE(ABORT,'Immutable expected document revision'); END''',
    );
    await customStatement('''CREATE TABLE transaction_document_audit (
      operation_uuid TEXT NOT NULL PRIMARY KEY CHECK(${_documentUuid('operation_uuid')}),
      document_uuid TEXT NOT NULL REFERENCES transaction_documents(document_uuid),
      action TEXT NOT NULL CHECK(action IN ('edit','replace','archive','restore')),
      actor_user_id INTEGER NOT NULL CHECK(actor_user_id>0),
      actor_group_id INTEGER NOT NULL CHECK(actor_group_id>0),
      occurred_at INTEGER NOT NULL,
      before_state TEXT NOT NULL CHECK(json_valid(before_state)),
      after_state TEXT NOT NULL CHECK(json_valid(after_state)),
      reason TEXT CHECK(reason IS NULL OR length(trim(reason)) BETWEEN 1 AND 500),
      CHECK(action NOT IN ('archive','restore') OR reason IS NOT NULL)
    )''');
    await customStatement('''CREATE TRIGGER transaction_document_audit_insert
      BEFORE INSERT ON transaction_document_audit
      WHEN EXISTS(SELECT 1 FROM transaction_document_audit WHERE operation_uuid=NEW.operation_uuid)
        OR NOT EXISTS(SELECT 1 FROM transaction_documents WHERE document_uuid=NEW.document_uuid)
      BEGIN SELECT RAISE(ABORT,'Invalid document audit'); END''');
    for (final operation in ['UPDATE', 'DELETE']) {
      await customStatement(
        '''CREATE TRIGGER transaction_document_audit_no_${operation.toLowerCase()}
        BEFORE $operation ON transaction_document_audit
        BEGIN SELECT RAISE(ABORT,'Document audit is immutable'); END''',
      );
    }
  }

  Future<void> _createTransactionDocumentStorage() async {
    await customStatement('''
      CREATE TABLE transaction_document_store (
        id INTEGER NOT NULL PRIMARY KEY CHECK (id=1),
        store_uuid TEXT NOT NULL UNIQUE CHECK (${_documentUuid('store_uuid')})
      )
    ''');
    await customStatement('''
      CREATE TABLE transaction_documents (
        document_uuid TEXT NOT NULL PRIMARY KEY CHECK (${_documentUuid('document_uuid')}),
        transaksi_uuid TEXT NOT NULL REFERENCES transaksis(uuid) ON DELETE RESTRICT,
        detail_uuid TEXT REFERENCES transaksi_details(uuid) ON DELETE RESTRICT,
        created_by INTEGER NOT NULL CHECK (created_by>0),
        created_at INTEGER NOT NULL,
        updated_by INTEGER CHECK (updated_by>0),
        updated_at INTEGER,
        archived_by INTEGER CHECK (archived_by>0),
        archived_at INTEGER,
        CHECK ((updated_at IS NULL) = (updated_by IS NULL)),
        CHECK ((archived_at IS NULL) = (archived_by IS NULL))
      )
    ''');
    await customStatement('''
      CREATE INDEX transaction_documents_owner
      ON transaction_documents(transaksi_uuid, archived_at, created_at, document_uuid)
    ''');
    await customStatement('''
      CREATE INDEX transaction_documents_detail ON transaction_documents(detail_uuid)
    ''');
    await customStatement('''
      CREATE TABLE transaction_document_versions (
        version_uuid TEXT NOT NULL PRIMARY KEY CHECK (${_documentUuid('version_uuid')}),
        document_uuid TEXT NOT NULL REFERENCES transaction_documents(document_uuid) ON DELETE RESTRICT,
        version_number INTEGER NOT NULL CHECK (typeof(version_number)='integer' AND version_number>=1),
        original_display_name TEXT NOT NULL CHECK (length(trim(original_display_name))>0),
        byte_size INTEGER NOT NULL CHECK (typeof(byte_size)='integer' AND byte_size BETWEEN 1 AND 20971520),
        media_type TEXT NOT NULL CHECK (media_type IN ('application/pdf','image/jpeg','image/png')),
        sha256 TEXT NOT NULL CHECK (length(sha256)=64 AND sha256 NOT GLOB '*[^0-9a-f]*'),
        created_by INTEGER NOT NULL CHECK (created_by>0),
        created_at INTEGER NOT NULL,
        UNIQUE (document_uuid, version_number)
      )
    ''');
    await customStatement('''
      CREATE TABLE transaction_document_operations (
        operation_uuid TEXT NOT NULL PRIMARY KEY CHECK (${_documentUuid('operation_uuid')}),
        action TEXT NOT NULL CHECK (action IN ('import','replace','archive','restore')),
        state TEXT NOT NULL CHECK (state IN ('staging','verified','interrupted','committed','rejected')),
        actor_user_id INTEGER NOT NULL CHECK (actor_user_id>0),
        actor_group_id INTEGER NOT NULL CHECK (actor_group_id>0),
        transaksi_uuid TEXT NOT NULL,
        detail_uuid TEXT,
        document_uuid TEXT NOT NULL CHECK (${_documentUuid('document_uuid')}),
        version_uuid TEXT UNIQUE CHECK (${_documentUuid('version_uuid')}),
        expected_version INTEGER CHECK (expected_version>=1),
        original_display_name TEXT,
        byte_size INTEGER CHECK (byte_size IS NULL OR (typeof(byte_size)='integer' AND byte_size BETWEEN 1 AND 20971520)),
        media_type TEXT CHECK (media_type IN ('application/pdf','image/jpeg','image/png')),
        sha256 TEXT CHECK (length(sha256)=64 AND sha256 NOT GLOB '*[^0-9a-f]*'),
        started_at INTEGER NOT NULL,
        finished_at INTEGER,
        error_code TEXT,
        CHECK ((state IN ('committed','rejected')) = (finished_at IS NOT NULL)),
        CHECK ((action IN ('import','replace')) = (version_uuid IS NOT NULL)),
        CHECK ((action='import') = (expected_version IS NULL)),
        CHECK (action NOT IN ('import','replace') OR state NOT IN ('verified','committed') OR
          (byte_size IS NOT NULL AND media_type IS NOT NULL AND sha256 IS NOT NULL AND
            original_display_name IS NOT NULL AND length(trim(original_display_name))>0))
      )
    ''');
    await customStatement('''
      CREATE INDEX transaction_document_operations_owner
      ON transaction_document_operations(transaksi_uuid, state)
    ''');
    await customStatement('''
      CREATE INDEX transaction_document_operations_recovery
      ON transaction_document_operations(state, started_at)
    ''');

    // Existing SQLite connections may have foreign_keys off. Protect ownership
    // at the write boundary without changing behavior for unrelated records.
    for (final table in [
      'transaction_documents',
      'transaction_document_operations',
    ]) {
      final alreadyExists = table == 'transaction_documents'
          ? 'document_uuid=NEW.document_uuid'
          : 'operation_uuid=NEW.operation_uuid OR version_uuid=NEW.version_uuid';
      await customStatement('''
        CREATE TRIGGER ${table}_check_owner BEFORE INSERT ON $table
        WHEN EXISTS (SELECT 1 FROM $table WHERE $alreadyExists) OR NOT EXISTS (
          SELECT 1 FROM transaksis t WHERE t.uuid=NEW.transaksi_uuid
            AND t.jenis_transaksi IN ('notaris','ppat') AND t.deleted_at IS NULL
            AND lower(trim(t.status_transaksi))<>'dihapus'
            AND (NEW.detail_uuid IS NULL OR EXISTS (
              SELECT 1 FROM transaksi_details d WHERE d.uuid=NEW.detail_uuid
                AND d.transaksi_id=t.id AND d.jenis_pekerjaan=t.jenis_transaksi
                AND d.status=1 AND d.deleted_at IS NULL
            ))
        )
        BEGIN SELECT RAISE(ABORT,'Duplicate document identity or invalid owner'); END
      ''');
    }
    await customStatement('''
      CREATE TRIGGER transaction_documents_no_reassign
      BEFORE UPDATE OF document_uuid,transaksi_uuid,detail_uuid ON transaction_documents
      WHEN NEW.document_uuid IS NOT OLD.document_uuid OR
        NEW.transaksi_uuid IS NOT OLD.transaksi_uuid OR NEW.detail_uuid IS NOT OLD.detail_uuid
      BEGIN SELECT RAISE(ABORT,'Document ownership is immutable'); END
    ''');
    await customStatement('''
      CREATE TRIGGER transaction_document_versions_check_document
      BEFORE INSERT ON transaction_document_versions
      WHEN NOT EXISTS (SELECT 1 FROM transaction_documents WHERE document_uuid=NEW.document_uuid)
        OR EXISTS (SELECT 1 FROM transaction_document_versions WHERE version_uuid=NEW.version_uuid
          OR (document_uuid=NEW.document_uuid AND version_number=NEW.version_number))
      BEGIN SELECT RAISE(ABORT,'Missing document or immutable version already exists'); END
    ''');
    for (final (table, operation) in [
      ('transaction_documents', 'DELETE'),
      ('transaction_document_versions', 'DELETE'),
      ('transaction_document_versions', 'UPDATE'),
      ('transaction_document_store', 'DELETE'),
      ('transaction_document_store', 'UPDATE'),
      ('transaction_document_operations', 'DELETE'),
    ]) {
      await customStatement('''
        CREATE TRIGGER ${table}_no_${operation.toLowerCase()} BEFORE $operation ON $table
        BEGIN SELECT RAISE(ABORT,'Document history must be retained'); END
      ''');
    }
    await customStatement('''
      CREATE TRIGGER transaction_document_operations_protect_receipt
      BEFORE UPDATE ON transaction_document_operations
      WHEN OLD.state IN ('committed','rejected') OR
        OLD.operation_uuid IS NOT NEW.operation_uuid OR OLD.action IS NOT NEW.action OR
        OLD.actor_user_id IS NOT NEW.actor_user_id OR OLD.actor_group_id IS NOT NEW.actor_group_id OR
        OLD.transaksi_uuid IS NOT NEW.transaksi_uuid OR OLD.detail_uuid IS NOT NEW.detail_uuid OR
        OLD.document_uuid IS NOT NEW.document_uuid OR OLD.version_uuid IS NOT NEW.version_uuid OR
        OLD.expected_version IS NOT NEW.expected_version OR OLD.started_at IS NOT NEW.started_at OR
        (OLD.sha256 IS NOT NULL AND (OLD.sha256 IS NOT NEW.sha256 OR OLD.byte_size IS NOT NEW.byte_size OR
          OLD.media_type IS NOT NEW.media_type OR OLD.original_display_name IS NOT NEW.original_display_name))
      BEGIN SELECT RAISE(ABORT,'Document operation receipt is immutable'); END
    ''');
    for (final (table, operation) in [
      ('transaction_documents', 'INSERT'),
      ('transaction_document_operations', 'INSERT'),
      ('transaction_document_operations', 'UPDATE'),
    ]) {
      await customStatement('''
        CREATE TRIGGER ${table}_no_cloud_${operation.toLowerCase()} BEFORE $operation ON $table
        WHEN EXISTS (SELECT 1 FROM transaction_cloud_pending WHERE local_uuid=NEW.transaksi_uuid)
        BEGIN SELECT RAISE(ABORT,'Unresolved cloud mutation'); END
      ''');
    }
    for (final operation in ['INSERT', 'UPDATE']) {
      await customStatement('''
        CREATE TRIGGER transaction_document_no_pending_${operation.toLowerCase()}
        BEFORE $operation ON transaction_cloud_pending
        WHEN NEW.state='pending' AND (
          EXISTS (SELECT 1 FROM transaction_documents WHERE transaksi_uuid=NEW.local_uuid)
          OR EXISTS (SELECT 1 FROM transaction_document_operations WHERE transaksi_uuid=NEW.local_uuid
            AND state IN ('staging','verified','interrupted'))
        )
        BEGIN SELECT RAISE(ABORT,'Local documents cannot enter the cloud journal'); END
      ''');
    }
    for (final (table, reference, rekeyColumns, changed) in [
      (
        'transaksis',
        'transaksi_uuid',
        'id,uuid,jenis_transaksi',
        'OLD.id IS NOT NEW.id OR OLD.uuid IS NOT NEW.uuid OR OLD.jenis_transaksi IS NOT NEW.jenis_transaksi',
      ),
      (
        'transaksi_details',
        'detail_uuid',
        'id,uuid,transaksi_id,jenis_pekerjaan',
        'OLD.id IS NOT NEW.id OR OLD.uuid IS NOT NEW.uuid OR OLD.transaksi_id IS NOT NEW.transaksi_id OR OLD.jenis_pekerjaan IS NOT NEW.jenis_pekerjaan',
      ),
    ]) {
      final hasDocument =
          '''EXISTS (SELECT 1 FROM transaction_documents WHERE $reference=OLD.uuid)
        OR EXISTS (SELECT 1 FROM transaction_document_operations WHERE $reference=OLD.uuid
          AND state IN ('staging','verified','interrupted'))''';
      for (final (suffix, operation, condition) in [
        ('delete', 'DELETE', hasDocument),
        ('rekey', 'UPDATE OF $rekeyColumns', '($changed) AND ($hasDocument)'),
      ]) {
        await customStatement('''
          CREATE TRIGGER transaction_document_${table}_$suffix BEFORE $operation ON $table
          WHEN $condition
          BEGIN SELECT RAISE(ABORT,'Document owner or detail is retained'); END
        ''');
      }
    }
  }
}

String _documentUuid(String column) =>
    "$column GLOB '????????-????-????-????-????????????' AND "
    "length(replace($column,'-',''))=32 AND "
    "replace($column,'-','') NOT GLOB '*[^0-9a-f]*'";
