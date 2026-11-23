import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/repositories/materai_repository.dart';
import 'package:path/path.dart' as p;

import '../support/materai_fixture.dart';
import '../support/penghasilan_fixture.dart';

void main() {
  for (final version in [24, 25, 26]) {
    test(
      'v$version → v27 preserves existing objects and rows and reopens',
      () async {
        final temp = await Directory.systemTemp.createTemp(
          'materai-migration-',
        );
        addTearDown(() => temp.delete(recursive: true));
        final file = File(p.join(temp.path, 'offline.sqlite'));
        NativeDatabase open() => NativeDatabase(
          file,
          setup: (raw) => raw.execute('PRAGMA foreign_keys=ON'),
        );
        final old = version == 24
            ? AppDatabase.forTesting(open())
            : DocumentProfileDatabase(open(), lifecycle: version == 26);
        late final Map<String, String> objects;
        late final Map<String, String> columns;
        late final Map<String, List<String>> data;
        try {
          await seedPenghasilan(old);
          if (version >= 25) {
            await old.customStatement('''
              INSERT INTO transaction_documents(document_uuid,transaksi_uuid,created_by,created_at)
              SELECT '8dae4f25-005a-471f-917f-0f6966072de8',uuid,100,1000
              FROM transaksis WHERE id=1
            ''');
          }
          expect(
            (await old.customSelect('PRAGMA user_version').getSingle())
                .data
                .values
                .single,
            version,
          );
          objects = await _objects(old);
          expect(objects.containsKey('materai_movements'), isFalse);
          columns = await _columns(old);
          data = await _rows(old, columns);
        } finally {
          await old.close();
        }

        Future<void> verify({required bool prepare}) async {
          final db = MateraiProfileDatabase(open());
          try {
            expect(
              (await db.customSelect('PRAGMA user_version').getSingle())
                  .data
                  .values
                  .single,
              27,
            );
            final after = await _objects(db);
            for (final entry in objects.entries) {
              final expectedEvolution =
                  version == 25 &&
                  {
                    'transaction_documents',
                    'transaction_document_operations',
                  }.contains(entry.key);
              if (expectedEvolution) {
                expect(
                  after[entry.key],
                  contains(
                    entry.key == 'transaction_documents'
                        ? 'revision INTEGER NOT NULL DEFAULT 1'
                        : 'expected_document_revision INTEGER',
                  ),
                );
              } else {
                expect(after[entry.key], entry.value, reason: entry.key);
              }
            }
            expect(await _rows(db, columns), data);
            expect(
              after.keys,
              containsAll([
                'materai_movements',
                'transaction_documents',
                'transaction_document_audit',
              ]),
            );
            final repo = MateraiRepository(db, materaiReader);
            if (prepare) {
              expect((await repo.read()).imported, isFalse);
              await seedMaterai(db);
            }
            expect((await repo.read()).verified, hasLength(12));
            expect(
              (await db.customSelect('PRAGMA integrity_check').getSingle())
                  .data
                  .values
                  .single,
              'ok',
            );
            expect(
              await db.customSelect('PRAGMA foreign_key_check').get(),
              isEmpty,
            );
          } finally {
            await db.close();
          }
        }

        await verify(prepare: true);
        await verify(prepare: false);
      },
    );
  }
}

Future<Map<String, String>> _objects(AppDatabase db) async => {
  for (final row
      in await db
          .customSelect(
            "SELECT name,sql FROM sqlite_master WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%'",
          )
          .get())
    row.read<String>('name'): row.read<String>('sql'),
};

Future<Map<String, String>> _columns(AppDatabase db) async {
  final tables = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
      )
      .get();
  return {
    for (final table in tables.map((row) => row.read<String>('name')))
      table: (await db.customSelect('PRAGMA table_info("$table")').get())
          .map((row) => '"${row.read<String>('name')}"')
          .join(','),
  };
}

Future<Map<String, List<String>>> _rows(
  AppDatabase db,
  Map<String, String> columns,
) async => {
  for (final MapEntry(key: table, value: fields) in columns.entries)
    table:
        (await db.customSelect('SELECT $fields FROM "$table"').get())
            .map((row) => jsonEncode(row.data))
            .toList()
          ..sort(),
};
