import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'notaris_migration_v6_',
    );
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('V10 to V11 preserves Petugas and transaction identities', () async {
    final file = File('${tempDirectory.path}/sync_v10.sqlite');
    final setup = AppDatabase(NativeDatabase(file));
    await setup.customSelect('SELECT 1').get();
    await setup.customStatement(
      "INSERT INTO petugas(id,uuid,nama,email) VALUES(9,'stable-local','Legacy','legacy@example.com')",
    );
    await setup.customStatement(
      "INSERT INTO transaksis(uuid,no_akta,total,petugas_id,petugas_uuid) VALUES('stable-tx','1000000000001',0,9,'stable-local')",
    );
    // Reconstruct the V10 checkpoint: only the new private journals are absent.
    await setup.customStatement('DROP TABLE petugas_sync_journal');
    await setup.customStatement('DROP TABLE petugas_sync_feed');
    await setup.customStatement('DROP TABLE petugas_gender_reference');
    await setup.customStatement('DROP TABLE petugas_user_reference');
    await setup.customStatement('PRAGMA user_version=10');
    await setup.close();
    final db = AppDatabase(NativeDatabase(file));
    try {
      final row = await db.select(db.petugasLocals).getSingle();
      expect(row.id, 9);
      expect(row.uuid, 'stable-local');
      final tx = await db.select(db.transaksis).getSingle();
      expect(tx.petugasId, 9);
      expect(tx.petugasUuid, 'stable-local');
      expect(
        await db.customSelect('SELECT * FROM petugas_sync_journal').get(),
        isEmpty,
      );
      expect(
        await db.customSelect('SELECT * FROM petugas_sync_feed').get(),
        isEmpty,
      );
    } finally {
      await db.close();
    }
  });

  test('V11 to V12 preserves pending mutation, version and cursor', () async {
    final file = File('${tempDirectory.path}/references_v11.sqlite');
    final setup = AppDatabase(NativeDatabase(file));
    await setup.customStatement(
      "INSERT INTO petugas(id,uuid,nama,email) VALUES(41,'legacy-ref','Keep','keep@example.com')",
    );
    await setup.customStatement(
      "INSERT INTO petugas_sync_feed(id,scope,cursor) VALUES(1,'deployment/account',42)",
    );
    await setup.customStatement(
      "INSERT INTO petugas_sync_journal(local_uuid,row_version,pending,snapshot) VALUES('legacy-ref',7,'persisted-mutation','persisted-snapshot')",
    );
    await setup.customStatement('DROP TABLE petugas_gender_reference');
    await setup.customStatement('DROP TABLE petugas_user_reference');
    await setup.customStatement('PRAGMA user_version=11');
    await setup.close();
    final db = AppDatabase(NativeDatabase(file));
    try {
      final row = await db.select(db.petugasLocals).getSingle();
      expect(row.id, 41);
      expect(row.uuid, 'legacy-ref');
      final journal = await db
          .customSelect('SELECT * FROM petugas_sync_journal')
          .getSingle();
      expect(journal.read<String>('pending'), 'persisted-mutation');
      expect(journal.read<int>('row_version'), 7);
      expect(
        (await db
                .customSelect('SELECT cursor FROM petugas_sync_feed')
                .getSingle())
            .read<int>('cursor'),
        42,
      );
      expect(
        await db.customSelect('SELECT * FROM petugas_gender_reference').get(),
        isEmpty,
      );
      expect(
        await db.customSelect('SELECT * FROM petugas_user_reference').get(),
        isEmpty,
      );
    } finally {
      await db.close();
    }
  });

  Future<File> createV6Fixture({required String filename}) async {
    final file = File('${tempDirectory.path}/$filename');

    final executor = NativeDatabase(
      file,
      setup: (database) {
        // Migration-relevant tables as they existed at schema V6.
        // V7 adds the normalized process tables and backfills them from
        // transaksi_details.proses_snapshot.
        database.execute('''
          CREATE TABLE pemohons (
            id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
            uuid TEXT NOT NULL
          )
        ''');

        database.execute('''
          CREATE TABLE transaksis (
            id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
            uuid TEXT NOT NULL,
            no_akta TEXT NOT NULL,
            total REAL NOT NULL,
            pemohon_id INTEGER,
            pemohon_uuid TEXT,
            petugas_id INTEGER,
            petugas_uuid TEXT,
            jenis_transaksi TEXT NOT NULL DEFAULT 'notaris',
            status_transaksi TEXT NOT NULL DEFAULT 'Baru',
            tanggal_transaksi INTEGER,
            tanggal_jatuh_tempo INTEGER,
            diskon REAL NOT NULL DEFAULT 0,
            pembayaran_sekarang REAL NOT NULL DEFAULT 0,
            metode_pembayaran TEXT NOT NULL DEFAULT 'Cash',
            jumlah_materai INTEGER NOT NULL DEFAULT 0,
            catatan TEXT,
            created_at INTEGER,
            is_sync_dirty INTEGER NOT NULL DEFAULT 1,
            last_synced_at INTEGER,
            updated_at INTEGER,
            deleted_at INTEGER
          )
        ''');

        database.execute('''
          CREATE TABLE transaksi_details (
            id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
            uuid TEXT NOT NULL UNIQUE,
            transaksi_id INTEGER NOT NULL REFERENCES transaksis(id),
            jenis_pekerjaan TEXT NOT NULL,
            pekerjaan_notaris_id INTEGER,
            pekerjaan_ppat_id INTEGER,
            nama_pekerjaan_snapshot TEXT NOT NULL,
            kategori_snapshot TEXT,
            estimasi_waktu_snapshot TEXT,
            proses_snapshot TEXT,
            biaya_layanan REAL NOT NULL DEFAULT 0,
            biaya_lainnya REAL NOT NULL DEFAULT 0,
            total_snapshot REAL NOT NULL DEFAULT 0,
            created_at INTEGER,
            updated_at INTEGER,
            status INTEGER NOT NULL DEFAULT 1,
            is_sync_dirty INTEGER NOT NULL DEFAULT 1,
            last_synced_at INTEGER,
            deleted_at INTEGER
          )
        ''');

        database.execute('''
          INSERT INTO transaksis (id, uuid, no_akta, total)
          VALUES (1, 'transaction-uuid', '1001210260001', 100000)
        ''');

        database.execute('''
          INSERT INTO transaksi_details
            (id, uuid, transaksi_id, jenis_pekerjaan,
             nama_pekerjaan_snapshot, proses_snapshot, status, deleted_at)
          VALUES
            (1, 'detail-valid', 1, 'notaris', 'Akta Valid',
             '[{"id":"process-1","name":"Pemeriksaan dokumen","status":"Belum Valid"},{"id":22,"name":"Penandatanganan","status":"Selesai"},{"id":"blank","name":"   "},"not-a-map"]',
             1, NULL),
            (2, 'detail-malformed', 1, 'notaris', 'Akta Malformed',
             '[invalid json', 1, NULL),
            (3, 'detail-object', 1, 'notaris', 'Akta Object',
             '{"name":"Not a list"}', 1, NULL),
            (4, 'detail-inactive', 1, 'notaris', 'Akta Inactive',
             '[{"id":"inactive","name":"Jangan dimigrasikan"}]', 0, NULL),
            (5, 'detail-deleted', 1, 'notaris', 'Akta Deleted',
             '[{"id":"deleted","name":"Jangan dimigrasikan"}]', 1, 123456)
        ''');

        database.execute('PRAGMA user_version = 6');
      },
    );

    // Opening the database runs the actual AppDatabase migration callback.
    final database = AppDatabase(executor);
    try {
      await database.customSelect('SELECT 1').get();
    } finally {
      await database.close();
    }

    return file;
  }

  test('V6 to V10 backfills processes and creates UUID and transaction-number indexes', () async {
    final file = await createV6Fixture(filename: 'valid_v6.sqlite');
    final db = AppDatabase(NativeDatabase(file));

    try {
      final processes = await db.select(db.transaksiProses).get();

      expect(processes, hasLength(2));
      expect(processes.map((process) => process.sourceProcessId).toSet(), {
        'process-1',
        '22',
      });
      expect(processes.map((process) => process.namaProsesSnapshot).toSet(), {
        'Pemeriksaan dokumen',
        'Penandatanganan',
      });
      expect(
        processes.every((process) => process.statusProses == null),
        isTrue,
      );
      expect(processes.every((process) => process.legacyData != null), isTrue);
      expect(processes.map((process) => process.uuid).toSet(), hasLength(2));

      final uuidIndexes = await db.customSelect('''
        SELECT name FROM sqlite_master
        WHERE type = 'index'
          AND name IN ('idx_pemohons_uuid_unique', 'idx_transaksis_uuid_unique', 'idx_transaksis_no_akta_unique')
      ''').get();
      expect(uuidIndexes.map((row) => row.read<String>('name')).toSet(), {
        'idx_pemohons_uuid_unique',
        'idx_transaksis_uuid_unique',
        'idx_transaksis_no_akta_unique',
      });

      final details = await db.select(db.transaksiDetails).get();
      final snapshots = {
        for (final detail in details) detail.uuid: detail.prosesSnapshot,
      };

      expect(snapshots['detail-malformed'], '[invalid json');
      expect(snapshots['detail-object'], '{"name":"Not a list"}');
      expect(
        processes.every(
          (process) =>
              process.transaksiDetailUuid == 'detail-valid' &&
              process.transaksiId == 1,
        ),
        isTrue,
      );
    } finally {
      await db.close();
    }

    // Reopen without executing migrations and inspect SQLite's stored version.
    final inspectionDb = AppDatabase(
      NativeDatabase(file, enableMigrations: false),
    );
    try {
      final version = await inspectionDb
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.read<int>('user_version'), 12);
    } finally {
      await inspectionDb.close();
    }
  });

  Future<File> createV7Fixture({
    required String filename,
    String? duplicateTable,
    bool blankUuid = false,
  }) async {
    final file = File('${tempDirectory.path}/$filename');
    final setupDb = AppDatabase(
      NativeDatabase(
        file,
        enableMigrations: false,
        setup: (database) {
          database.execute('''
            CREATE TABLE pemohons (
              id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
              uuid TEXT NOT NULL
            )
          ''');
          database.execute('''
            CREATE TABLE transaksis (
              id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
              uuid TEXT NOT NULL,
              no_akta TEXT NOT NULL DEFAULT '',
              total REAL NOT NULL DEFAULT 0
            )
          ''');
          database.execute(
            "INSERT INTO pemohons (uuid) VALUES ('${blankUuid ? '' : 'pemohon-1'}')",
          );
          database.execute(
            "INSERT INTO transaksis (uuid) VALUES ('transaksi-1')",
          );
          if (duplicateTable != null) {
            database.execute(
              "INSERT INTO $duplicateTable (uuid) VALUES ('${blankUuid
                  ? ''
                  : duplicateTable == 'pemohons'
                  ? 'pemohon-1'
                  : 'transaksi-1'}')",
            );
          }
          database.execute('PRAGMA user_version = 7');
        },
      ),
    );
    await setupDb.customSelect('SELECT 1').get();
    await setupDb.close();
    return file;
  }

  test('V7 upgrade enforces unique UUIDs on Pemohons and Transaksis', () async {
    final file = await createV7Fixture(filename: 'valid_v7.sqlite');
    final db = AppDatabase(NativeDatabase(file));

    try {
      await db.customSelect('SELECT 1').get();
      await expectLater(
        db.customStatement("INSERT INTO pemohons (uuid) VALUES ('pemohon-1')"),
        throwsA(anything),
      );
      await expectLater(
        db.customStatement(
          "INSERT INTO transaksis (uuid) VALUES ('transaksi-1')",
        ),
        throwsA(anything),
      );
    } finally {
      await db.close();
    }
  });

  for (final table in ['pemohons', 'transaksis']) {
    test(
      'V7 to V8 rejects duplicate UUIDs in $table without partial migration',
      () async {
        final file = await createV7Fixture(
          filename: 'duplicate_$table.sqlite',
          duplicateTable: table,
        );
        final db = AppDatabase(NativeDatabase(file));
        await expectLater(db.customSelect('SELECT 1').get(), throwsA(anything));
        await db.close();

        final inspectionDb = AppDatabase(
          NativeDatabase(file, enableMigrations: false),
        );
        try {
          final version = await inspectionDb
              .customSelect('PRAGMA user_version')
              .getSingle();
          expect(version.read<int>('user_version'), 7);

          final indexes = await inspectionDb.customSelect('''
          SELECT name FROM sqlite_master
          WHERE type = 'index'
            AND name IN ('idx_pemohons_uuid_unique', 'idx_transaksis_uuid_unique')
        ''').get();
          expect(indexes, isEmpty);
        } finally {
          await inspectionDb.close();
        }
      },
    );
  }

  test('V7 upgrade rejects blank UUIDs without partial migration', () async {
    final file = await createV7Fixture(
      filename: 'blank_uuid.sqlite',
      duplicateTable: 'pemohons',
      blankUuid: true,
    );
    final db = AppDatabase(NativeDatabase(file));
    await expectLater(db.customSelect('SELECT 1').get(), throwsA(anything));
    await db.close();

    final inspectionDb = AppDatabase(
      NativeDatabase(file, enableMigrations: false),
    );
    try {
      final version = await inspectionDb
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.read<int>('user_version'), 7);
    } finally {
      await inspectionDb.close();
    }
  });

  test(
    'V8 to V9 rejects duplicate transaction numbers without partial migration',
    () async {
      final file = File(
        '${tempDirectory.path}/duplicate_transaction_numbers_v8.sqlite',
      );
      final setupDb = AppDatabase(
        NativeDatabase(
          file,
          enableMigrations: false,
          setup: (database) {
            database.execute('''
            CREATE TABLE pemohons (
              id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
              uuid TEXT NOT NULL
            )
          ''');
            database.execute('''
            CREATE TABLE transaksis (
              id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
              uuid TEXT NOT NULL,
              no_akta TEXT NOT NULL,
              total REAL NOT NULL
            )
          ''');
            database.execute(
              "INSERT INTO transaksis (uuid, no_akta, total) VALUES ('tx-1', '1001410260001', 0)",
            );
            database.execute(
              "INSERT INTO transaksis (uuid, no_akta, total) VALUES ('tx-2', ' 1001410260001 ', 0)",
            );
            database.execute('PRAGMA user_version = 8');
          },
        ),
      );
      await setupDb.customSelect('SELECT 1').get();
      await setupDb.close();

      final db = AppDatabase(NativeDatabase(file));
      await expectLater(db.customSelect('SELECT 1').get(), throwsA(anything));
      await db.close();

      final inspectionDb = AppDatabase(
        NativeDatabase(file, enableMigrations: false),
      );
      try {
        final version = await inspectionDb
            .customSelect('PRAGMA user_version')
            .getSingle();
        expect(version.read<int>('user_version'), 8);
        final rows = await inspectionDb
            .customSelect('SELECT id, no_akta FROM transaksis ORDER BY id')
            .get();
        expect(rows, hasLength(2));
        final indexes = await inspectionDb
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'index' AND name = 'idx_transaksis_no_akta_unique'",
            )
            .get();
        expect(indexes, isEmpty);
      } finally {
        await inspectionDb.close();
      }
    },
  );

  test('V9 to V10 adds identity mapping without changing Petugas identities or transaction references', () async {
    final file = File('${tempDirectory.path}/petugas_identity_v9.sqlite');
    final setupDb = AppDatabase(
      NativeDatabase(
        file,
        enableMigrations: false,
        setup: (database) {
          database.execute('''
            CREATE TABLE petugas (
              id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
              uuid TEXT NOT NULL UNIQUE
            )
          ''');
          database.execute('''
            CREATE TABLE transaksis (
              id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
              petugas_id INTEGER,
              petugas_uuid TEXT
            )
          ''');
          database.execute(
            "INSERT INTO petugas (id, uuid) VALUES (7, 'local-petugas-uuid')",
          );
          database.execute(
            "INSERT INTO petugas (id, uuid) VALUES (8, 'second-local-petugas-uuid')",
          );
          database.execute('''
            INSERT INTO transaksis (id, petugas_id, petugas_uuid)
            VALUES (11, 7, 'local-petugas-uuid')
          ''');
          database.execute('PRAGMA user_version = 9');
        },
      ),
    );
    await setupDb.customSelect('SELECT 1').get();
    await setupDb.close();

    final db = AppDatabase(NativeDatabase(file));
    try {
      await db.customSelect('SELECT 1').get();

      final petugas = await db
          .customSelect('SELECT id, uuid FROM petugas WHERE id = 7')
          .getSingle();
      expect(petugas.read<int>('id'), 7);
      expect(petugas.read<String>('uuid'), 'local-petugas-uuid');

      final transaction = await db
          .customSelect(
            'SELECT petugas_id, petugas_uuid FROM transaksis WHERE id = 11',
          )
          .getSingle();
      expect(transaction.read<int>('petugas_id'), 7);
      expect(transaction.read<String>('petugas_uuid'), 'local-petugas-uuid');

      final mappingTable = await db.customSelect('''
        SELECT name FROM sqlite_master
        WHERE type = 'table' AND name = 'petugas_identity_map'
      ''').get();
      expect(mappingTable, hasLength(1));

      final mappings = await db
          .customSelect('SELECT * FROM petugas_identity_map')
          .get();
      expect(mappings, isEmpty);

      final indexes = await db.customSelect('''
        SELECT name FROM sqlite_master
        WHERE type = 'index' AND name IN (
          'idx_petugas_identity_map_active_cloud_uuid',
          'idx_petugas_identity_map_active_server_id'
        )
      ''').get();
      expect(indexes.map((row) => row.read<String>('name')).toSet(), {
        'idx_petugas_identity_map_active_cloud_uuid',
        'idx_petugas_identity_map_active_server_id',
      });

      await db.customStatement('''
        INSERT INTO petugas_identity_map
          (local_uuid, cloud_uuid, server_id, state, created_at, updated_at)
        VALUES
          ('local-petugas-uuid', 'cloud-petugas-uuid', 101, 'verified', 0, 0)
      ''');
      await expectLater(
        db.customStatement('''
          INSERT INTO petugas_identity_map
            (local_uuid, cloud_uuid, server_id, state, created_at, updated_at)
          VALUES
            ('second-local-petugas-uuid', 'cloud-petugas-uuid', 102, 'verified', 0, 0)
        '''),
        throwsA(anything),
      );
      await expectLater(
        db.customStatement('''
          INSERT INTO petugas_identity_map
            (local_uuid, cloud_uuid, server_id, state, created_at, updated_at)
          VALUES
            ('second-local-petugas-uuid', 'another-cloud-petugas-uuid', 101, 'verified', 0, 0)
        '''),
        throwsA(anything),
      );
    } finally {
      await db.close();
    }
  });

  test('failed V6 to V7 migration rolls back V7 DDL and keeps the old version', () async {
    // This deliberately damaged V6 fixture omits deleted_at. The migration
    // creates the two V7 tables, then fails when its backfill query references
    // the missing legacy column. This is a diagnostic test for atomicity.
    final file = File('${tempDirectory.path}/broken_v6.sqlite');
    final executor = NativeDatabase(
      file,
      setup: (database) {
        database.execute('''
            CREATE TABLE transaksis (
              id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
              uuid TEXT NOT NULL,
              no_akta TEXT NOT NULL,
              total REAL NOT NULL
            )
          ''');
        database.execute('''
            CREATE TABLE transaksi_details (
              id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
              uuid TEXT NOT NULL UNIQUE,
              transaksi_id INTEGER NOT NULL REFERENCES transaksis(id),
              jenis_pekerjaan TEXT NOT NULL,
              nama_pekerjaan_snapshot TEXT NOT NULL,
              proses_snapshot TEXT,
              status INTEGER NOT NULL DEFAULT 1,
              created_at INTEGER,
              updated_at INTEGER
            )
          ''');
        database.execute('PRAGMA user_version = 6');
      },
    );

    final db = AppDatabase(executor);
    await expectLater(db.customSelect('SELECT 1').get(), throwsA(anything));
    await db.close();

    final inspectionDb = AppDatabase(
      NativeDatabase(file, enableMigrations: false),
    );
    try {
      final version = await inspectionDb
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.read<int>('user_version'), 6);

      final tables = await inspectionDb.customSelect('''
          SELECT name FROM sqlite_master
          WHERE type = 'table'
            AND name IN ('transaksi_proses', 'transaksi_proses_riwayat')
        ''').get();
      expect(
        tables.map((row) => row.read<String>('name')).toSet(),
        isEmpty,
        reason:
            'V7 tables must not remain when the migration transaction fails.',
      );
    } finally {
      await inspectionDb.close();
    }
  });
}
