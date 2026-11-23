import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/handover_demo_main.dart';
import 'package:frontend_notaris/models/auth_session.dart';
import 'package:frontend_notaris/payment_demo_main.dart';
import 'package:frontend_notaris/repositories/transaction_cloud_repository.dart';
import 'package:frontend_notaris/repositories/transaction_handover_repository.dart';

import '../support/transaction_ui_test_support.dart' show uiSession;
import 'recycle_bin_repository_test.dart'
    show recoverySession, rows, seedTransaction;

const first = '62c86647-a750-47e1-a611-09e87467c4f0';
const second = '62c86647-a750-47e1-a611-09e87467c4f1';
const protected = [
  'transaksis',
  'transaksi_details',
  'transaksi_proses',
  'transaksi_riwayat_pembayaran',
  'transaksi_pembayaran_audit',
  'transaction_cloud_pending',
  'transaction_cloud_identity',
  'transaction_cloud_feed',
];

Future<List<List<Map<String, dynamic>>>> snapshot(AppDatabase db) async => [
  for (final name in protected)
    (await db.customSelect('SELECT * FROM $name ORDER BY rowid').get())
        .map((row) => row.data)
        .toList(),
];

void main() {
  final demo = Platform.environment['NOTARIS_HANDOVER_PREPARE'];
  test('migrates the disposable acceptance clone', () async {
    final db = await openHandoverDemo(demo!, prepare: true);
    addTearDown(db.close);
    expect(
      (await db.customSelect('PRAGMA user_version').getSingle())
          .data
          .values
          .single,
      24,
    );
    expect(await rows(db, TransactionHandoverRepository.table), isEmpty);
  }, skip: demo == null);

  test('v23 to v24 preserves the ledger and completion, and drafts survive restart', () async {
    final directory = await Directory.systemTemp.createTemp(
      'handover-migration-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/fixture.sqlite');
    final old = PaymentDemoDatabase(NativeDatabase(file));
    AppDatabase opened = old;
    addTearDown(() => opened.close());
    final notaris = await seedTransaction(old, 'notaris');
    final ppat = await seedTransaction(old, 'ppat');
    await old.customStatement(
      "UPDATE transaksis SET judul_akta='Akta Fidusia' WHERE id=?",
      [notaris],
    );
    await old.customStatement(
      "UPDATE transaksi_details SET judul_akta_ppat='Akta Jual Beli' WHERE transaksi_id=?",
      [ppat],
    );
    final original = await snapshot(old);
    expect(
      await old
          .customSelect(
            "SELECT 1 FROM sqlite_schema WHERE name='transaksi_serah_terima'",
          )
          .get(),
      isEmpty,
    );
    await old.close();
    final migrated = AppDatabase.forTesting(NativeDatabase(file));
    opened = migrated;
    final repo = TransactionHandoverRepository(migrated);
    final actor = uiSession(userId: 37);
    final reader = recoverySession(update: false, only: 'transaksi');
    expect(await snapshot(migrated), original);
    expect(
      (await migrated.customSelect('PRAGMA user_version').getSingle())
          .data
          .values
          .single,
      24,
    );
    expect((await repo.read(notaris, reader)).records, isEmpty);

    Future<void> add(
      int id,
      String uuid,
      String description,
      AuthSession session,
    ) => repo.save(
      transactionId: id,
      session: session,
      uuid: uuid,
      description: description,
      purpose: '',
    );
    expect(
      () => add(notaris, first, 'Salinan Fidusia', reader),
      throwsA(isA<HandoverRejected>()),
    );
    await expectLater(
      repo.read(notaris, uiSession(permission: false)),
      throwsA(isA<HandoverRejected>()),
    );
    await add(notaris, first, 'Salinan Fidusia', actor);
    await add(notaris, first, 'Salinan Fidusia', actor);
    await add(ppat, second, 'Salinan AJB', actor);
    await expectLater(
      add(ppat, first, 'Salinan Fidusia', actor),
      throwsA(isA<HandoverRejected>()),
    );
    final draft = (await repo.read(notaris, reader)).records.single;
    expect(
      (draft.createdBy, draft.description, draft.purpose, draft.revision),
      (37, 'Salinan Fidusia', null, 1),
    );
    expect((await repo.read(notaris, reader)).staff, 'Officer');
    expect(
      (await repo.read(ppat, reader)).records.single.description,
      'Salinan AJB',
    );

    Future<void> edit(int id, int revision, AuthSession session) => repo.save(
      transactionId: id,
      session: session,
      uuid: first,
      description: 'Fidusia dan lampiran',
      purpose: 'Arsip',
      expectedRevision: revision,
    );
    expect(() => edit(notaris, 1, reader), throwsA(isA<HandoverRejected>()));
    await expectLater(edit(ppat, 1, actor), throwsA(isA<HandoverRejected>()));
    await migrated.customStatement('''
      CREATE TRIGGER fixture_reject_handover BEFORE UPDATE ON transaksi_serah_terima
      BEGIN SELECT RAISE(ABORT,'fixture failure'); END
    ''');
    await expectLater(edit(notaris, 1, actor), throwsA(isA<Exception>()));
    expect((await repo.read(notaris, reader)).records.single.revision, 1);
    await migrated.customStatement('DROP TRIGGER fixture_reject_handover');
    await edit(notaris, 1, uiSession(userId: 42));
    await expectLater(
      edit(notaris, 1, actor),
      throwsA(isA<HandoverRejected>()),
    );
    final dio = Dio();
    addTearDown(dio.close);
    await expectLater(
      TransactionCloudRepository(
        migrated,
        dio,
        scope: 'fixture',
        petugasScope: 'fixture',
        masterScope: 'fixture',
      ).stageCreate(notaris),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          TransactionHandoverRepository.localOnlyMessage,
        ),
      ),
    );
    expect(await snapshot(migrated), original);
    await migrated.close();
    final reopened = AppDatabase.forTesting(NativeDatabase(file));
    opened = reopened;
    final saved = (await TransactionHandoverRepository(
      reopened,
    ).read(notaris, reader)).records.single;
    expect(
      (saved.createdBy, saved.updatedBy, saved.revision, saved.description),
      (37, 42, 2, 'Fidusia dan lampiran'),
    );
    expect(saved.updatedAt, isNotNull);
    expect(await snapshot(reopened), original);
    expect(
      (await reopened.customSelect('PRAGMA integrity_check').getSingle())
          .data
          .values
          .single,
      'ok',
    );
    expect(
      await reopened.customSelect('PRAGMA foreign_key_check').get(),
      isEmpty,
    );
  });
}
