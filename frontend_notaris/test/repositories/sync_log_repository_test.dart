import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/repositories/sync_log_repository.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());
  test('success failure retry history correlation filters dedup and sanitized errors', () async {
    final log = SyncLogRepository(db);
    var calls = 0;
    Future<void> attempt(String id, {bool fail = false}) => log.track(
      module: 'pemohon',
      direction: 'pull',
      attemptId: id,
      action: () async {
        calls++;
        if (fail) throw StateError('JWT password private payload');
        return 20;
      },
      errorCode: (_) => 'forbidden',
    );
    await expectLater(attempt('first', fail: true), throwsStateError);
    await attempt('second');
    await attempt('second');
    final rows = await log.list();
    expect(calls, 2);
    expect(rows.length, 2);
    expect(rows.first['status'], 'success');
    expect(rows.first['record_count'], 20);
    expect(rows.last['status'], 'failed');
    expect(rows.first['operation_id'], rows.last['operation_id']);
    expect(rows.last['error_message'], 'Akses ditolak');
    expect(rows.toString(), isNot(contains('JWT password')));
    expect((await log.list(status: 'failed')).length, 1);
    expect(await log.list(module: 'kategori'), isEmpty);
  });
  test(
    'network failure is pending not success and future modules absent',
    () async {
      final log = SyncLogRepository(db);
      await expectLater(
        log.track(
          module: 'kategori',
          direction: 'push',
          attemptId: 'network',
          action: () async => throw Exception('secret'),
          errorCode: (_) => 'offline',
        ),
        throwsException,
      );
      final rows = await log.list();
      expect(rows.single['status'], 'pending');
      expect(rows.single['record_count'], isNull);
    },
  );
  test('v13 upgrade preserves business rows identity feed and history survives reopen', () async {
    final temp = await Directory.systemTemp.createTemp('sync-log-migration-');
    final file = File('${temp.path}/fixture.sqlite');
    var fileDb = AppDatabase.forTesting(NativeDatabase(file));
    try {
      await fileDb.customStatement(
        "INSERT INTO pemohons(uuid,nama) VALUES('pemohon-stable','Fixture')",
      );
      await fileDb.customStatement(
        "INSERT INTO petugas(uuid,nama,email) VALUES('local-stable','Fixture','fixture@example.invalid')",
      );
      await fileDb.customStatement(
        "INSERT INTO petugas_identity_map VALUES('local-stable','cloud-stable',101,'server_only','fixture',1,1)",
      );
      await fileDb.customStatement(
        "INSERT INTO petugas_sync_feed VALUES(1,'fixture-scope',4,NULL)",
      );
      await fileDb.customStatement('DROP TABLE sync_logs');
      for (final table in [
        'transaction_cloud_pending',
        'transaction_cloud_identity',
        'transaction_cloud_feed',
      ]) {
        await fileDb.customStatement('DROP TABLE $table');
      }
      await fileDb.customStatement(
        'ALTER TABLE transaksi_details DROP COLUMN harga_uuid',
      );
      await fileDb.customStatement(
        'ALTER TABLE transaksi_details DROP COLUMN kategori_uuid',
      );
      await fileDb.customStatement('PRAGMA user_version=13');
      await fileDb.close();
      fileDb = AppDatabase.forTesting(NativeDatabase(file));
      expect(
        (await fileDb.select(fileDb.pemohons).get()).single.uuid,
        'pemohon-stable',
      );
      expect(
        (await fileDb.select(fileDb.petugasLocals).get()).single.uuid,
        'local-stable',
      );
      expect(
        (await fileDb
                .customSelect('SELECT cursor FROM petugas_sync_feed')
                .getSingle())
            .read<int>('cursor'),
        4,
      );
      final log = SyncLogRepository(fileDb);
      expect(await log.list(), isEmpty);
      await log.track(
        module: 'kategori',
        direction: 'pull',
        attemptId: 'persist',
        action: () async => 2,
        errorCode: (_) => 'unknown',
      );
      await fileDb.close();
      fileDb = AppDatabase.forTesting(NativeDatabase(file));
      expect(
        (await SyncLogRepository(fileDb).list()).single['record_count'],
        2,
      );
      expect(
        (await fileDb.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        17,
      );
      expect(
        await fileDb.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    } finally {
      await fileDb.close();
      await temp.delete(recursive: true);
    }
  });
}
