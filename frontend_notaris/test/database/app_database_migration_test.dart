import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';

const _legacyJenisSchema = '''
  CREATE TABLE pengeluaran_jenis (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    uuid TEXT NOT NULL UNIQUE,
    nama TEXT NOT NULL,
    created_by INTEGER,
    updated_by INTEGER,
    created_at INTEGER,
    updated_at INTEGER,
    status INTEGER NOT NULL DEFAULT 1,
    is_sync_dirty INTEGER NOT NULL DEFAULT 1 CHECK (is_sync_dirty IN (0, 1)),
    last_synced_at INTEGER,
    deleted_at INTEGER
  )
''';

const _deedColumns = ['judul_akta', 'nomor_akta', 'tanggal_akta'];
const _legacyPaymentSchema = '''
  CREATE TABLE transaksi_riwayat_pembayaran (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    uuid TEXT NOT NULL UNIQUE,
    transaksi_id INTEGER NOT NULL REFERENCES transaksis(id),
    nominal REAL NOT NULL,
    urutan_pembayaran INTEGER NOT NULL DEFAULT 1
  )
''';
const _ppatColumns = [
  'status_pekerjaan_ppat',
  'judul_akta_ppat',
  'nomor_akta_ppat',
  'tanggal_akta_ppat',
];

Future<void> stripV23(AppDatabase db) async {
  for (final name in ['order_insert', 'rupiah_insert', 'rupiah_update']) {
    await db.customStatement('DROP TRIGGER transaksi_pembayaran_$name');
  }
  await db.customStatement('DROP INDEX transaksi_pembayaran_order');
  await db.customStatement('DROP TABLE transaksi_pembayaran_audit');
  await db.customStatement(
    'ALTER TABLE transaksi_riwayat_pembayaran DROP COLUMN nominal_rupiah',
  );
}

Future<void> stripV22(AppDatabase db) async {
  await stripV23(db);
  for (final column in _ppatColumns) {
    await db.customStatement(
      'ALTER TABLE transaksi_details DROP COLUMN $column',
    );
  }
}

Future<void> stripV21(AppDatabase db) async {
  await stripV22(db);
  for (final column in _deedColumns) {
    await db.customStatement('ALTER TABLE transaksis DROP COLUMN $column');
  }
}

Future<void> stripV20(AppDatabase db) async {
  await stripV21(db);
  await db.customStatement('DROP TRIGGER pengeluaran_history_delete');
  await db.customStatement('DROP TRIGGER pengeluaran_history_rekey');
  await db.customStatement('DROP TABLE pengeluaran');
}

Future<void> stripV17(AppDatabase db) async {
  await stripV20(db);
  for (final table in [
    'transaction_cloud_pending',
    'transaction_cloud_identity',
    'transaction_cloud_feed',
  ]) {
    await db.customStatement('DROP TABLE $table');
  }
  await db.customStatement(
    'ALTER TABLE transaksi_details DROP COLUMN harga_uuid',
  );
  await db.customStatement(
    'ALTER TABLE transaksi_details DROP COLUMN kategori_uuid',
  );
}

void main() {
  for (final version in [20, 21, 22]) {
    test('V$version upgrades additively to V23 and preserves historical storage', () async {
      final folder = await Directory.systemTemp.createTemp('notaris_deed_v20_');
      addTearDown(() => folder.delete(recursive: true));
      final file = File('${folder.path}/fixture.sqlite');
      var db = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(() => db.close());
      if (version == 20) {
        await stripV21(db);
      } else if (version == 21) {
        await stripV22(db);
      } else {
        await stripV23(db);
      }
      for (final statement in [
        "INSERT INTO transaksis(uuid,no_akta,total,status_transaksi,is_sync_dirty) VALUES ('legacy-notaris','10020',100,'Selesai',0),('dirty-notaris','10021',200,'Dalam Proses',1),('legacy-ppat','20020',100,'Selesai',1)",
        "UPDATE transaksis SET jenis_transaksi='ppat' WHERE uuid='legacy-ppat'",
        "INSERT INTO transaksi_details(uuid,transaksi_id,jenis_pekerjaan,nama_pekerjaan_snapshot) VALUES ('detail-v20',1,'notaris','Jasa')",
        "INSERT INTO transaksi_details(uuid,transaksi_id,jenis_pekerjaan,nama_pekerjaan_snapshot) VALUES ('detail-ppat',3,'ppat','Jual Beli')",
        "INSERT INTO transaksi_proses(uuid,transaksi_id,transaksi_detail_uuid,nama_proses_snapshot) VALUES ('proses-v20',1,'detail-v20','Review')",
        "INSERT INTO transaksi_proses_riwayat(uuid,transaksi_proses_id,status_baru,created_at) VALUES ('audit-v20',1,'valid',1)",
        "INSERT INTO transaksi_riwayat_pembayaran(uuid,transaksi_id,tanggal_pembayaran,nominal) VALUES ('pay-v20',1,1,50)",
        "INSERT INTO transaction_cloud_pending VALUES ('dirty-notaris','mutation-v20','{}','pending','create')",
        "INSERT INTO transaction_cloud_feed VALUES ('scope',9)",
        "INSERT INTO petugas_sync_feed(id,scope,cursor) VALUES (1,'scope',4)",
        if (version >= 21) "UPDATE transaksis SET judul_akta='Fidusia',nomor_akta='25211',tanggal_akta=1794355200 WHERE id=1",
        if (version == 22) "UPDATE transaksi_details SET status_pekerjaan_ppat='selesai',judul_akta_ppat='Akta Jual Beli',nomor_akta_ppat='00125',tanggal_akta_ppat=1794355200 WHERE uuid='detail-ppat'",
        "INSERT INTO transaksi_riwayat_pembayaran(uuid,transaksi_id,tanggal_pembayaran,nominal,status,deleted_at) VALUES ('legacy-duplicate-order',1,1,1.25,0,2)",
        'PRAGMA user_version=$version',
      ]) {
        await db.customStatement(statement);
      }
      final schema =
          '''
      SELECT type, name, sql FROM sqlite_schema
      WHERE name NOT LIKE 'sqlite_%' AND name NOT LIKE 'transaksi_pembayaran_%'
      AND name <> 'transaksi_riwayat_pembayaran'
      ${version < 22 ? "AND name <> 'transaksi_details'" : ''}
      ${version == 20 ? "AND name <> 'transaksis'" : ''}
      ORDER BY type, name
    ''';
      Future<List<Map<String, Object?>>> query(String sql) async =>
          (await db.customSelect(sql).get()).map((row) => row.data).toList();
      final beforeSchema = await query(schema);
      final headerColumns = await query('PRAGMA table_info(transaksis)');
      final detailColumns = await query('PRAGMA table_info(transaksi_details)');
      final paymentColumns = await query(
        'PRAGMA table_info(transaksi_riwayat_pembayaran)',
      );
      final tables = [
        if (version == 20) 'transaksis',
        if (version < 22) 'transaksi_details',
        'transaksi_riwayat_pembayaran',
        'sqlite_sequence',
        for (final row in beforeSchema)
          if (row['type'] == 'table') row['name'] as String,
      ];
      Future<Map<String, Object?>> rows() async => {
        for (final table in tables)
          table: [
            for (final row in await query(
              'SELECT * FROM "$table" ORDER BY rowid',
            ))
              {...row}..removeWhere(
                (key, _) =>
                    (table == 'transaksis' &&
                        version == 20 &&
                        _deedColumns.contains(key)) ||
                    (table == 'transaksi_details' &&
                        version < 22 &&
                        _ppatColumns.contains(key)) ||
                    (table == 'transaksi_riwayat_pembayaran' &&
                        key == 'nominal_rupiah'),
              ),
          ],
      };
      final beforeRows = await rows();
      await db.close();
      db = AppDatabase.forTesting(NativeDatabase(file));
      for (var opening = 0; opening < 2; opening++) {
        expect(await query('PRAGMA user_version'), [
          {'user_version': 23},
        ]);
        expect(await query(schema), beforeSchema);
        expect(await rows(), beforeRows);
        final columns = await query('PRAGMA table_info(transaksis)');
        expect(columns.take(headerColumns.length), headerColumns);
        expect(
          columns.skip(headerColumns.length).map((row) => row['name']),
          version == 20 ? _deedColumns : isEmpty,
        );
        final details = await query('PRAGMA table_info(transaksi_details)');
        expect(details.take(detailColumns.length), detailColumns);
        expect(
          details.skip(detailColumns.length).map((row) => row['name']),
          version < 22 ? _ppatColumns : isEmpty,
        );
        final payments = await query(
          'PRAGMA table_info(transaksi_riwayat_pembayaran)',
        );
        expect(payments.take(paymentColumns.length), paymentColumns);
        expect(payments.last['name'], 'nominal_rupiah');
        expect(
          await query(
            'SELECT nominal_rupiah FROM transaksi_riwayat_pembayaran',
          ),
          everyElement({'nominal_rupiah': null}),
        );
        expect(
          await query('SELECT * FROM transaksi_pembayaran_audit'),
          isEmpty,
        );
        if (version < 22) {
          expect(
            await query(
              'SELECT ${_ppatColumns.join(', ')} FROM transaksi_details',
            ),
            everyElement({for (final key in _ppatColumns) key: null}),
          );
        }
        expect(await query('PRAGMA foreign_key_check'), isEmpty);
        expect(await query('PRAGMA integrity_check'), [
          {'integrity_check': 'ok'},
        ]);
        if (opening == 0) {
          await db.close();
          db = AppDatabase.forTesting(NativeDatabase(file));
        }
      }
    });
  }

  test('V19 copy upgrades through V20 and preserves existing rows', () async {
    final folder = await Directory.systemTemp.createTemp('pengeluaran_v19_');
    addTearDown(() => folder.delete(recursive: true));
    final baseline = File('${folder.path}/v19.sqlite');
    final setup = AppDatabase.forTesting(NativeDatabase(baseline));
    await stripV20(setup);
    for (final statement in [
      "INSERT INTO pengeluaran_jenis(uuid,nama) VALUES ('jenis-v19','ATK')",
      "INSERT INTO pekerjaan_kategori(uuid,nama) VALUES ('kategori-v19','Master')",
      "INSERT INTO transaksis(uuid,no_akta,total,is_sync_dirty) VALUES ('tx-v19','00019',100,1)",
      "INSERT INTO transaksi_details(uuid,transaksi_id,jenis_pekerjaan,nama_pekerjaan_snapshot) VALUES ('detail-v19',1,'notaris','Jasa')",
      "INSERT INTO transaksi_proses(uuid,transaksi_id,transaksi_detail_uuid,nama_proses_snapshot) VALUES ('proses-v19',1,'detail-v19','Review')",
      "INSERT INTO transaksi_proses_riwayat(uuid,transaksi_proses_id,status_baru,created_at) VALUES ('audit-v19',1,'submitted',1)",
      "INSERT INTO transaksi_riwayat_pembayaran(uuid,transaksi_id,tanggal_pembayaran,nominal) VALUES ('pay-v19',1,1,50)",
      "INSERT INTO transaction_cloud_pending VALUES ('tx-v19','mutation-v19','{}','pending','create')",
      "INSERT INTO transaction_cloud_feed VALUES ('scope',9)",
      "INSERT INTO petugas_sync_feed(id,scope,cursor) VALUES (1,'scope',4)",
      'PRAGMA user_version=19',
    ]) {
      await setup.customStatement(statement);
    }
    final tables = await setup.customSelect('''
      SELECT name, sql FROM sqlite_schema
      WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name
      ''').get();
    Future<Map<String, Object?>> contents(AppDatabase db) async => {
      for (final table in tables)
        table.read<String>('name'): (
          (await db
                  .customSelect(
                    'SELECT sql FROM sqlite_schema WHERE name = ?',
                    variables: [Variable(table.read<String>('name'))],
                  )
                  .getSingle())
              .data,
          [
            for (final row
                in await db
                    .customSelect(
                      'SELECT * FROM "${table.read<String>('name')}" ORDER BY rowid',
                    )
                    .get())
              row.data,
          ],
        ),
    };
    // Use deep collection comparison across the file reopen.
    final before = await contents(setup);
    await setup.close();
    final copy = await baseline.copy('${folder.path}/upgraded.sqlite');
    final upgraded = AppDatabase.forTesting(NativeDatabase(copy));
    addTearDown(upgraded.close);
    expect(
      (await upgraded.customSelect('PRAGMA user_version').getSingle()).data,
      {'user_version': 23},
    );
    final after = await contents(upgraded);
    for (final name in before.keys) {
      final expected =
          before[name] as (Map<String, dynamic>, List<Map<String, dynamic>>);
      final actual =
          after[name] as (Map<String, dynamic>, List<Map<String, dynamic>>);
      if (name != 'transaksis' &&
          name != 'transaksi_details' &&
          name != 'transaksi_riwayat_pembayaran') {
        expect(actual.$1, expected.$1, reason: '$name schema');
      }
      expect(
        actual.$2.map(
          (row) => {...row}
            ..removeWhere(
              (key, _) =>
                  (name == 'transaksis' && _deedColumns.contains(key)) ||
                  (name == 'transaksi_details' && _ppatColumns.contains(key)) ||
                  (name == 'transaksi_riwayat_pembayaran' &&
                      key == 'nominal_rupiah'),
            ),
        ),
        expected.$2,
        reason: '$name rows',
      );
    }
    expect(await upgraded.select(upgraded.pengeluarans).get(), isEmpty);
    expect(
      await upgraded.customSelect('PRAGMA foreign_key_check').get(),
      isEmpty,
    );
    expect(
      (await upgraded.customSelect('PRAGMA integrity_check').getSingle()).data,
      {'integrity_check': 'ok'},
    );
    expect(
      await upgraded
          .customSelect(
            "SELECT name FROM sqlite_schema WHERE type='index' AND name LIKE 'pengeluaran_by_%'",
          )
          .get(),
      hasLength(2),
    );
  });

  test(
    'V17 to V18 preserves identity pending intent cursor and final number',
    () async {
      final folder = await Directory.systemTemp.createTemp('transaction_v17_');
      addTearDown(() => folder.delete(recursive: true));
      final file = File('${folder.path}/fixture.sqlite');
      final before = AppDatabase.forTesting(NativeDatabase(file));
      await before.customStatement(
        "INSERT INTO transaksis(uuid,no_akta,total,is_sync_dirty) VALUES('stable-tx','1000511260001',100,1)",
      );
      await before.customStatement('DROP TABLE transaction_cloud_identity');
      await before.customStatement(
        'CREATE TABLE transaction_cloud_identity (local_uuid TEXT PRIMARY KEY REFERENCES transaksis(uuid),cloud_uuid TEXT NOT NULL UNIQUE,scope TEXT NOT NULL,revision INTEGER NOT NULL CHECK(revision=1),final_number TEXT NOT NULL UNIQUE,snapshot TEXT NOT NULL)',
      );
      await before.customStatement(
        "INSERT INTO transaction_cloud_identity VALUES('stable-tx','stable-tx','scope',1,'1000511260001','{}')",
      );
      await before.customStatement(
        'ALTER TABLE transaction_cloud_pending DROP COLUMN operation',
      );
      await before.customStatement(
        "INSERT INTO transaction_cloud_pending VALUES('stable-tx','immutable-mutation','immutable-payload','pending')",
      );
      await before.customStatement(
        "INSERT INTO transaction_cloud_feed VALUES('scope',2)",
      );
      await stripV20(before);
      await before.customStatement('PRAGMA user_version=17');
      await before.close();
      final after = AppDatabase.forTesting(NativeDatabase(file));
      try {
        expect(
          (await after
                  .customSelect('SELECT payload FROM transaction_cloud_pending')
                  .getSingle())
              .read<String>('payload'),
          'immutable-payload',
        );
        expect(
          (await after
                  .customSelect(
                    'SELECT operation FROM transaction_cloud_pending',
                  )
                  .getSingle())
              .read<String>('operation'),
          'create',
        );
        expect(
          (await after.select(after.transaksis).getSingle()).isSyncDirty,
          true,
        );
        expect(
          (await after
                  .customSelect('SELECT cursor FROM transaction_cloud_feed')
                  .getSingle())
              .read<int>('cursor'),
          2,
        );
        await after.customStatement(
          'UPDATE transaction_cloud_identity SET revision=2',
        );
        expect(
          (await after
                  .customSelect(
                    'SELECT final_number FROM transaction_cloud_identity',
                  )
                  .getSingle())
              .read<String>('final_number'),
          '1000511260001',
        );
        expect(
          await after.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        expect(
          (await after.customSelect('PRAGMA integrity_check').getSingle())
              .read<String>('integrity_check'),
          'ok',
        );
      } finally {
        await after.close();
      }
    },
  );
  test(
    'V16 to V17 preserves legacy unresolved provenance and local data',
    () async {
      final folder = await Directory.systemTemp.createTemp('transaction_v16_');
      addTearDown(() => folder.delete(recursive: true));
      final file = File('${folder.path}/fixture.sqlite');
      final before = AppDatabase.forTesting(NativeDatabase(file));
      await before.customStatement(
        "INSERT INTO transaksis(id,uuid,no_akta,total) VALUES(1,'legacy-tx','LEGACY-1',100)",
      );
      await before.customStatement(
        "INSERT INTO transaksi_details(uuid,transaksi_id,jenis_pekerjaan,nama_pekerjaan_snapshot,kategori_snapshot,biaya_layanan,total_snapshot) VALUES('legacy-detail',1,'notaris','historical job','historical category',100,100)",
      );
      await before.customStatement(
        "INSERT INTO transaksi_riwayat_pembayaran(uuid,transaksi_id,tanggal_pembayaran,nominal) VALUES('legacy-payment',1,1,25)",
      );
      await stripV17(before);
      await before.customStatement('PRAGMA user_version=16');
      await before.close();
      final after = AppDatabase.forTesting(NativeDatabase(file));
      try {
        final detail = await after.select(after.transaksiDetails).getSingle();
        expect(detail.hargaUuid, isNull);
        expect(detail.kategoriUuid, isNull);
        expect(detail.kategoriSnapshot, 'historical category');
        expect(detail.isSyncDirty, true);
        expect(
          (await after.select(after.transaksis).getSingle()).noAkta,
          'LEGACY-1',
        );
        expect(
          await after.select(after.transaksiRiwayatPembayarans).get(),
          hasLength(1),
        );
        expect(
          await after
              .customSelect('SELECT * FROM transaction_cloud_pending')
              .get(),
          isEmpty,
        );
        expect(
          await after.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        expect(
          (await after.customSelect('PRAGMA integrity_check').getSingle())
              .read<String>('integrity_check'),
          'ok',
        );
      } finally {
        await after.close();
      }
    },
  );
  test(
    'V15 to V16 preserves Notaris and PPAT rows and separates PPAT feed',
    () async {
      final folder = await Directory.systemTemp.createTemp('ppat_cloud_v15_');
      addTearDown(() => folder.delete(recursive: true));
      final file = File('${folder.path}/offline.sqlite');
      final before = AppDatabase.forTesting(NativeDatabase(file));
      await before.customStatement(
        "INSERT INTO pekerjaan_notaris(uuid,nama) VALUES('notaris-uuid','Notaris')",
      );
      await before.customStatement(
        "INSERT INTO pekerjaan_ppat(uuid,nama) VALUES('ppat-uuid','PPAT')",
      );
      await before.customStatement(
        "INSERT INTO pekerjaan_notaris_sync_feed(scope,cursor) VALUES('shared',3)",
      );
      for (final table in [
        'pekerjaan_ppat_sync_pending',
        'pekerjaan_ppat_sync_identity',
        'pekerjaan_ppat_sync_feed',
      ]) {
        await before.customStatement('DROP TABLE $table');
      }
      await stripV17(before);
      await before.customStatement('PRAGMA user_version=15');
      await before.close();
      final after = AppDatabase.forTesting(NativeDatabase(file));
      expect(
        (await after.pekerjaanDao.getPekerjaanNotaris()).single.uuid,
        'notaris-uuid',
      );
      expect(
        (await after.pekerjaanDao.getPekerjaanPpat()).single.uuid,
        'ppat-uuid',
      );
      expect(
        (await after
                .customSelect('SELECT cursor FROM pekerjaan_notaris_sync_feed')
                .getSingle())
            .read<int>('cursor'),
        3,
      );
      expect(
        await after
            .customSelect('SELECT * FROM pekerjaan_ppat_sync_feed')
            .get(),
        isEmpty,
      );
      expect(
        (await after.customSelect('PRAGMA user_version').getSingle()).read<int>(
          'user_version',
        ),
        23,
      );
      expect(
        await after.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
      await after.close();
    },
  );
  test(
    'V14 to V16 preserves existing masters and adds isolated cloud states',
    () async {
      final folder = await Directory.systemTemp.createTemp(
        'notaris_cloud_v14_',
      );
      addTearDown(() => folder.delete(recursive: true));
      final file = File('${folder.path}/offline.sqlite');
      final before = AppDatabase.forTesting(NativeDatabase(file));
      await before.customStatement(
        "INSERT INTO pekerjaan_notaris(uuid,nama) VALUES('local-stable','Existing')",
      );
      await before.customStatement(
        "INSERT INTO pemohons(uuid,nama) VALUES('pemohon-stable','Existing')",
      );
      await before.customStatement('DROP TABLE pekerjaan_notaris_sync_pending');
      await before.customStatement(
        'DROP TABLE pekerjaan_notaris_sync_identity',
      );
      await before.customStatement('DROP TABLE pekerjaan_notaris_sync_feed');
      await stripV17(before);
      await before.customStatement('PRAGMA user_version=14');
      await before.close();
      final after = AppDatabase.forTesting(NativeDatabase(file));
      expect(
        (await after.pekerjaanDao.getPekerjaanNotaris()).single.uuid,
        'local-stable',
      );
      expect(
        (await after.select(after.pemohons).get()).single.uuid,
        'pemohon-stable',
      );
      expect(
        await after
            .customSelect('SELECT * FROM pekerjaan_notaris_sync_feed')
            .get(),
        isEmpty,
      );
      expect(
        (await after.customSelect('PRAGMA user_version').getSingle()).read<int>(
          'user_version',
        ),
        23,
      );
      expect(
        await after.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
      await after.close();
    },
  );
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
    await setup.customStatement('DROP TABLE petugas_sync_conflict');
    await stripV17(setup);
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
    await setup.customStatement('DROP TABLE petugas_sync_conflict');
    await stripV17(setup);
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

  test(
    'V12 to V13 preserves pending work, reference provenance and cursor',
    () async {
      final file = File('${tempDirectory.path}/conflict_v12.sqlite');
      final setup = AppDatabase(NativeDatabase(file));
      await setup.customStatement(
        "INSERT INTO petugas(id,uuid,nama,email) VALUES(55,'conflict-local','Legacy','legacy@example.com')",
      );
      await setup.customStatement(
        "INSERT INTO petugas_sync_feed(id,scope,cursor) VALUES(1,'deployment/account',42)",
      );
      await setup.customStatement(
        "INSERT INTO petugas_sync_journal(local_uuid,row_version,pending,snapshot) VALUES('conflict-local',8,'unchanged-pending','unchanged-snapshot')",
      );
      await setup.customStatement(
        "INSERT INTO petugas_user_reference(scope,server_id,evidence) VALUES('deployment/account',20,'authenticated selection')",
      );
      await setup.customStatement('DROP TABLE petugas_sync_conflict');
      await stripV17(setup);
      await setup.customStatement('PRAGMA user_version=12');
      await setup.close();
      final db = AppDatabase(NativeDatabase(file));
      try {
        final row = await db.select(db.petugasLocals).getSingle();
        expect(row.id, 55);
        expect(row.uuid, 'conflict-local');
        final journal = await db
            .customSelect('SELECT * FROM petugas_sync_journal')
            .getSingle();
        expect(journal.read<String>('pending'), 'unchanged-pending');
        expect(journal.read<int>('row_version'), 8);
        expect(
          (await db
                  .customSelect('SELECT cursor FROM petugas_sync_feed')
                  .getSingle())
              .read<int>('cursor'),
          42,
        );
        expect(
          (await db
                  .customSelect('SELECT server_id FROM petugas_user_reference')
                  .getSingle())
              .read<int>('server_id'),
          20,
        );
        expect(
          await db.customSelect('SELECT * FROM petugas_sync_conflict').get(),
          isEmpty,
        );
      } finally {
        await db.close();
      }
    },
  );

  Future<File> createV6Fixture({required String filename}) async {
    final file = File('${tempDirectory.path}/$filename');

    final executor = NativeDatabase(
      file,
      setup: (database) {
        // Migration-relevant tables as they existed at schema V6.
        // V7 adds the normalized process tables and backfills them from
        // transaksi_details.proses_snapshot.
        database.execute(_legacyJenisSchema);
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

        database.execute(_legacyPaymentSchema);
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
      expect(version.read<int>('user_version'), 23);
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
          database.execute(_legacyJenisSchema);
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
          database.execute(
            'CREATE TABLE transaksi_details (uuid TEXT PRIMARY KEY, transaksi_id INTEGER REFERENCES transaksis(id))',
          );
          database.execute(_legacyPaymentSchema);
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
          database.execute(_legacyJenisSchema);
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
              petugas_uuid TEXT,
              uuid TEXT NOT NULL UNIQUE DEFAULT 'transaction-11'
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
          database.execute(
            'CREATE TABLE transaksi_details (uuid TEXT PRIMARY KEY, transaksi_id INTEGER REFERENCES transaksis(id))',
          );
          database.execute(_legacyPaymentSchema);
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
