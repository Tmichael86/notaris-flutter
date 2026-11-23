import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/repositories/transaction_document_cloud_guard.dart';

import '../repositories/recycle_bin_repository_test.dart' show seedTransaction;

const document = '1bde7502-4d2a-4a09-af07-0d8d54fbb401';
const version = '1bde7502-4d2a-4a09-af07-0d8d54fbb402';

Future<void> seedDocument(AppDatabase db, String owner, String? detail) =>
    db.transaction(() async {
      await db.customStatement(
        'INSERT INTO transaction_documents(document_uuid,transaksi_uuid,detail_uuid,created_by,created_at) VALUES(?,?,?,1,1)',
        [document, owner, detail],
      );
      await db.customStatement(
        '''INSERT INTO transaction_document_versions(version_uuid,document_uuid,version_number,
          original_display_name,byte_size,media_type,sha256,created_by,created_at)
          VALUES(?,?,1,'Akta 名.pdf',15,'application/pdf',?,1,1)''',
        [version, document, 'a' * 64],
      );
    });

void main() {
  test(
    'unfinished local intent blocks upload and survives failed metadata commit',
    () async {
      final db = DocumentProfileDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final id = await seedTransaction(db, 'notaris');
      final owner =
          (await db
                  .customSelect('SELECT uuid FROM transaksis WHERE id=$id')
                  .getSingle())
              .read<String>('uuid');
      const operation = '1bde7502-4d2a-4a09-af07-0d8d54fbb403';
      await db.customStatement(
        '''
      INSERT INTO transaction_document_operations(operation_uuid,action,state,
        actor_user_id,actor_group_id,transaksi_uuid,document_uuid,version_uuid,started_at)
        VALUES(?,'import','staging',1,1,?,?,?,1)
    ''',
        [operation, owner, document, version],
      );
      expect(
        await transactionDocumentUploadBlockReason(db, owner),
        transactionDocumentUploadBlock,
      );
      await expectLater(
        db.customStatement(
          '''
      INSERT INTO transaction_cloud_pending(local_uuid,mutation_id,payload,state)
      VALUES(?,'fixture-mutation','{}','pending')
    ''',
          [owner],
        ),
        throwsException,
      );

      await db.customStatement(
        '''
      UPDATE transaction_document_operations SET state='verified',original_display_name='Akta.pdf',
        byte_size=15,media_type='application/pdf',sha256=? WHERE operation_uuid=?
    ''',
        ['a' * 64, operation],
      );
      await expectLater(
        db.customStatement(
          'UPDATE transaction_document_operations SET byte_size=16',
        ),
        throwsException,
      );
      await db.customStatement('''
      CREATE TRIGGER fixture_reject_version BEFORE INSERT ON transaction_document_versions
      BEGIN SELECT RAISE(ABORT,'fixture commit failure'); END
    ''');
      await expectLater(seedDocument(db, owner, null), throwsException);
      expect(
        await db.customSelect('SELECT * FROM transaction_documents').get(),
        isEmpty,
      );
      expect(
        (await db
                .customSelect(
                  'SELECT state FROM transaction_document_operations',
                )
                .getSingle())
            .read<String>('state'),
        'verified',
      );
      expect(
        await db.customSelect('SELECT * FROM transaction_cloud_pending').get(),
        isEmpty,
      );
    },
  );

  test(
    'disposable v24 to v25 preserves all existing schema and rows',
    () async {
      final folder = await Directory.systemTemp.createTemp(
        'document-migration-',
      );
      addTearDown(() => folder.delete(recursive: true));
      final file = File('${folder.path}/offline.sqlite');
      AppDatabase db = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(() => db.close());
      await seedTransaction(db, 'notaris');
      await seedTransaction(db, 'ppat');
      await db.customStatement('''
      INSERT INTO transaksi_serah_terima(uuid,transaksi_id,uraian,created_by,created_at)
      SELECT 'fixture-handover',id,'Catatan berkas',1,1 FROM transaksis WHERE jenis_transaksi='notaris'
    ''');
      await db.customStatement(
        "INSERT INTO transaction_cloud_feed VALUES ('fixture',9)",
      );

      Future<List<Map<String, Object?>>> query(String sql) async => [
        for (final row in await db.customSelect(sql).get()) row.data,
      ];
      const schema = '''SELECT type,name,sql FROM sqlite_schema
      WHERE name NOT LIKE 'transaction_document%'
        AND tbl_name NOT LIKE 'transaction_document%' ORDER BY type,name''';
      expect(await query('PRAGMA user_version'), [
        {'user_version': 24},
      ]);
      final beforeSchema = await query(schema);
      final tables = beforeSchema.where((row) => row['type'] == 'table');
      Future<Map<String, Object?>> snapshot() async => {
        for (final row in tables)
          row['name'] as String: await query(
            'SELECT * FROM "${row['name']}" ORDER BY rowid',
          ),
      };
      final before = await snapshot();
      await db.close();

      for (var opening = 0; opening < 2; opening++) {
        db = DocumentProfileDatabase(NativeDatabase(file));
        expect(await query('PRAGMA user_version'), [
          {'user_version': 25},
        ]);
        expect(await query(schema), beforeSchema);
        expect(await snapshot(), before);
        for (final table in [
          'transaction_document_store',
          'transaction_documents',
          'transaction_document_versions',
          'transaction_document_operations',
        ]) {
          expect(await query('SELECT * FROM $table'), isEmpty);
        }
        expect(await query('PRAGMA integrity_check'), [
          {'integrity_check': 'ok'},
        ]);
        expect(await query('PRAGMA foreign_key_check'), isEmpty);
        if (opening == 0) await db.close();
      }
    },
  );

  test('rejects cross-transaction ownership and retains detail and version with FK off', () async {
    final db = DocumentProfileDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final notaris = await seedTransaction(db, 'notaris');
    final ppat = await seedTransaction(db, 'ppat');
    await db.customStatement('PRAGMA foreign_keys=OFF');
    final owner =
        (await db
                .customSelect('SELECT uuid FROM transaksis WHERE id=$notaris')
                .getSingle())
            .read<String>('uuid');
    final detail =
        (await db
                .customSelect(
                  'SELECT uuid FROM transaksi_details WHERE transaksi_id=$notaris',
                )
                .getSingle())
            .read<String>('uuid');
    final other =
        (await db
                .customSelect(
                  'SELECT uuid FROM transaksi_details WHERE transaksi_id=$ppat',
                )
                .getSingle())
            .read<String>('uuid');
    await expectLater(seedDocument(db, owner, other), throwsException);
    await seedDocument(db, owner, detail);

    for (final sql in [
      'DELETE FROM transaksis WHERE id=$notaris',
      'DELETE FROM transaksi_details WHERE transaksi_id=$notaris',
      'UPDATE transaksi_details SET transaksi_id=$ppat WHERE transaksi_id=$notaris',
      "UPDATE transaksi_details SET jenis_pekerjaan='ppat' WHERE transaksi_id=$notaris",
      'UPDATE transaction_documents SET detail_uuid=NULL',
      'DELETE FROM transaction_documents',
      'INSERT OR REPLACE INTO transaction_documents SELECT * FROM transaction_documents',
      'UPDATE transaction_document_versions SET version_number=2',
      'DELETE FROM transaction_document_versions',
      'INSERT OR REPLACE INTO transaction_document_versions SELECT * FROM transaction_document_versions',
    ]) {
      await expectLater(db.customStatement(sql), throwsException, reason: sql);
    }
    await db.customStatement(
      'UPDATE transaksi_details SET deleted_at=1,status=0 WHERE transaksi_id=$notaris',
    );
    await db.customStatement(
      "UPDATE transaksis SET deleted_at=1,status_transaksi='Dihapus' WHERE id=$notaris",
    );
    expect(
      (await db
              .customSelect('SELECT detail_uuid FROM transaction_documents')
              .getSingle())
          .read<String>('detail_uuid'),
      detail,
    );
    expect(
      (await db
              .customSelect(
                'SELECT version_uuid FROM transaction_document_versions',
              )
              .getSingle())
          .read<String>('version_uuid'),
      version,
    );
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });
}
