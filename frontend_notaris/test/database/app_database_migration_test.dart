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

  Future<File> createV6Fixture({required String filename}) async {
    final file = File('${tempDirectory.path}/$filename');

    final executor = NativeDatabase(
      file,
      setup: (database) {
        // Migration-relevant tables as they existed at schema V6.
        // V7 adds the normalized process tables and backfills them from
        // transaksi_details.proses_snapshot.
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

  test('V6 to V7 backfills only valid processes from active details', () async {
    final file = await createV6Fixture(filename: 'valid_v6.sqlite');
    final db = AppDatabase(NativeDatabase(file));

    try {
      final processes = await db.select(db.transaksiProses).get();

      expect(processes, hasLength(2));
      expect(
        processes.map((process) => process.sourceProcessId).toSet(),
        {'process-1', '22'},
      );
      expect(
        processes.map((process) => process.namaProsesSnapshot).toSet(),
        {'Pemeriksaan dokumen', 'Penandatanganan'},
      );
      expect(processes.every((process) => process.statusProses == null), isTrue);
      expect(
        processes.every((process) => process.legacyData != null),
        isTrue,
      );
      expect(processes.map((process) => process.uuid).toSet(), hasLength(2));

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
      final version = await inspectionDb.customSelect(
        'PRAGMA user_version',
      ).getSingle();
      expect(version.read<int>('user_version'), 7);
    } finally {
      await inspectionDb.close();
    }
  });

  test(
    'failed V6 to V7 migration keeps the old version and reveals partial DDL',
    () async {
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
      await expectLater(
        db.customSelect('SELECT 1').get(),
        throwsA(anything),
      );
      await db.close();

      final inspectionDb = AppDatabase(
        NativeDatabase(file, enableMigrations: false),
      );
      try {
        final version = await inspectionDb.customSelect(
          'PRAGMA user_version',
        ).getSingle();
        expect(version.read<int>('user_version'), 6);

        final tables = await inspectionDb.customSelect('''
          SELECT name FROM sqlite_master
          WHERE type = 'table'
            AND name IN ('transaksi_proses', 'transaksi_proses_riwayat')
        ''').get();
        expect(
          tables.map((row) => row.read<String>('name')).toSet(),
          {'transaksi_proses', 'transaksi_proses_riwayat'},
          reason:
              'This captures whether DDL is rolled back when the migration '
              'callback fails. If this expectation changes, revisit the '
              'atomicity decision and update the test accordingly.',
        );
      } finally {
        await inspectionDb.close();
      }
    },
  );
}
