import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/repositories/sync_monitor_repository.dart';
import 'package:frontend_notaris/repositories/sync_log_repository.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());
  Future<Map<String, dynamic>> status(String module) async =>
      (await SyncMonitorRepository(
        db,
      ).read()).singleWhere((r) => r['module'] == module);

  test('Petugas dirty/journal pending is deduplicated and conflict overrides success', () async {
    await db.customStatement(
      "INSERT INTO petugas(uuid,nama,email) VALUES('local','Fixture','fixture@example.invalid')",
    );
    await db.customStatement(
      "INSERT INTO petugas_sync_journal(local_uuid,row_version,pending) VALUES('local',1,'{}')",
    );
    var row = await status('petugas');
    expect(row['pending_records'], 1);
    expect(row['color'], 'yellow');
    await db.customStatement(
      "INSERT INTO petugas_sync_conflict(scope,mutation_id,local_uuid,mutation,local_snapshot,observed_local,response,state,updated_at) VALUES('scope','mutation','local','{}','{}','{}','{}','open','2026-11-02')",
    );
    row = await status('petugas');
    expect(row['color'], 'red');
    expect(row['errors'], 1);
  });
  test(
    'neutral success green dirty yellow failure red retry history retained',
    () async {
      final log = SyncLogRepository(db);
      expect((await status('pemohon'))['color'], 'neutral');
      await log.track(
        module: 'pemohon',
        direction: 'pull',
        attemptId: '1',
        action: () async => 20,
        errorCode: (_) => 'unknown',
      );
      expect((await status('pemohon'))['color'], 'green');
      await db.customStatement(
        "INSERT INTO pemohons(uuid,nama) VALUES('local','Fixture')",
      );
      expect((await status('pemohon'))['color'], 'yellow');
      await expectLater(
        log.track(
          module: 'pemohon',
          direction: 'pull',
          attemptId: '2',
          action: () async => throw StateError('private'),
          errorCode: (_) => 'conflict',
        ),
        throwsStateError,
      );
      expect((await status('pemohon'))['color'], 'red');
      await log.track(
        module: 'pemohon',
        direction: 'pull',
        attemptId: '3',
        action: () async => 20,
        errorCode: (_) => 'unknown',
      );
      expect((await status('pemohon'))['color'], 'yellow');
      expect((await log.list()).length, 3);
      await db.customStatement('UPDATE pemohons SET is_sync_dirty=0');
      expect((await status('pemohon'))['color'], 'green');
    },
  );
  test(
    'pending failure yellow with factual progress and no synthetic percentages',
    () async {
      final log = SyncLogRepository(db);
      await expectLater(
        log.track(
          module: 'kategori',
          direction: 'pull',
          attemptId: '1',
          action: () async => throw Exception(),
          errorCode: (_) => 'offline',
        ),
        throwsException,
      );
      final row = await status('kategori');
      expect(row['color'], 'yellow');
      expect(row['pending_operations'], 1);
      expect(row['last_success'], isNull);
      expect(row['progress'].toString(), isNot(contains('%')));
    },
  );
  test('Petugas blocked feed red overrides clean baseline and unsupported actions fail closed', () async {
    await db.customStatement(
      "INSERT INTO petugas_sync_feed VALUES(1,'scope',4,'full_resync_required')",
    );
    expect((await status('petugas'))['color'], 'red');
    for (final module in syncModules.keys) {
      for (final direction in ['push', 'pull']) {
        await expectLater(
          executeSelectedSync(module, direction),
          throwsUnsupportedError,
        );
      }
    }
    expect(await SyncLogRepository(db).list(), isEmpty);
  });
}
