import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/profile_v1_acceptance_main.dart'
    show profileV1AcceptanceRoot;
import 'package:uuid/uuid.dart';

void main() {
  final id = Platform.environment['NOTARIS_H01_PREPARE'];
  test('seed pending/cursor/ACK witnesses only in a new owned H01 profile before baseline', () async {
    final root = profileV1AcceptanceRoot(id!);
    expect(File('${root.path}/h01-owner').readAsStringSync(), id);
    expect(File('${root.path}/h01-baseline.json').existsSync(), false);
    await File('${root.path}/h01-witness-attempted.lock')
        .create(exclusive: true);
    final db = MateraiProfileDatabase(
      NativeDatabase(
        File('${root.path}/offline.sqlite'),
        enableMigrations: false,
        setup: (s) => s.execute('PRAGMA foreign_keys=ON'),
      ),
    );
    try {
      expect(
        (await db.customSelect('PRAGMA user_version').getSingle())
            .data
            .values
            .single,
        27,
      );
      await db.transaction(() async {
        final parents = await db.select(db.transaksis).get();
        expect(parents.length, 2);
        final pending = parents.first, acked = parents.last;
        final scope = 'h01/$id/transactions';
        // Containment witnesses, deliberately not sendable cloud aggregates.
        // No mutation is ever approved; the pending payload remains byte-stable.
        await db.customStatement(
          "INSERT INTO transaction_cloud_pending(local_uuid,mutation_id,payload,state,operation) VALUES(?,?,?,'pending','create')",
          [
            pending.uuid,
            const Uuid().v4(),
            jsonEncode({
              'scope': scope,
              'never_publish': 'H01 containment witness',
            }),
          ],
        );
        await db.customStatement(
          "INSERT INTO transaction_cloud_identity(local_uuid,cloud_uuid,scope,revision,final_number,snapshot) VALUES(?,?,?,1,?,?)",
          [
            acked.uuid,
            acked.uuid,
            scope,
            acked.noAkta,
            jsonEncode({'never_publish': 'H01 ACK preservation witness'}),
          ],
        );
        await db.customStatement(
          "INSERT INTO transaction_cloud_pending(local_uuid,mutation_id,payload,state,operation) VALUES(?,?,?,'acked','create')",
          [acked.uuid, const Uuid().v4(), '{}'],
        );
        await db.customStatement(
          'INSERT INTO transaction_cloud_feed(scope,cursor) VALUES(?,9)',
          [scope],
        );
        await db.customStatement(
          "INSERT INTO pengeluaran_jenis(uuid,nama,is_sync_dirty) VALUES(?,'Jenis pending H01',1)",
          [const Uuid().v4()],
        );
      });
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      expect(
        (await db.customSelect('PRAGMA integrity_check').getSingle())
            .data
            .values
            .single,
        'ok',
      );
    } finally {
      await db.close();
    }
  }, skip: id == null);
}
