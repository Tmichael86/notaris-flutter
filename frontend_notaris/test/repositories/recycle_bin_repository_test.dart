import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/models/auth_session.dart';
import 'package:frontend_notaris/repositories/pekerjaan_repository.dart';
import 'package:frontend_notaris/repositories/recycle_bin_repository.dart';
import 'package:frontend_notaris/repositories/transaction_repository.dart';

AuthSession recoverySession({bool update = true, String? only}) => AuthSession(
  token: 'fixture',
  userId: 1,
  groupId: 1,
  userName: 'fixture',
  groupName: 'fixture',
  user: const {},
  verifiedAt: DateTime(2026),
  sidebars: [
    for (final code in ['pekerjaan_notaris', 'pekerjaan_ppat', 'transaksi'])
      if (only == null || code == only)
        {
          'sidebar': {'sidebar_kode': code, 'status': 1},
          'read': 1,
          'update': update ? 1 : 0,
        },
  ],
);

Future<int> seedMaster(AppDatabase db, String domain) async {
  await db.customStatement(
    "INSERT OR IGNORE INTO pekerjaan_kategori(id,uuid,nama) VALUES(1,'category','Category')",
  );
  final input = PekerjaanAggregateInput(
    nama: 'Same label',
    harga: const [
      PekerjaanHargaInput(
        harga: '100',
        kategoriPekerjaanId: 1,
        estimasiWaktu: '1 day',
      ),
    ],
    proses: const [
      PekerjaanProsesInput(
        nama: 'Process',
        detail: 'Detail',
        atribut: [PekerjaanAtributInput(atribut: 'Document')],
      ),
    ],
  );
  return domain == 'notaris'
      ? PekerjaanNotarisRepository(db.pekerjaanDao)
            .createAggregate(input: input)
      : PekerjaanPpatRepository(db.pekerjaanDao).createAggregate(input: input);
}

Future<int> seedTransaction(AppDatabase db, String domain) async {
  final job = await seedMaster(db, domain);
  await db.customStatement(
    "INSERT OR IGNORE INTO pemohons(id,uuid,nama) VALUES(1,'applicant','Applicant')",
  );
  await db.customStatement(
    "INSERT OR IGNORE INTO petugas(id,uuid,nama,email) VALUES(1,'officer','Officer','fixture@example.invalid')",
  );
  return TransactionRepository(db).save(
    nomorTransaksi: '${domain == 'notaris' ? 1 : 2}000611260001',
    jenisTransaksi: domain,
    pemohonId: 1,
    pemohonUuid: 'applicant',
    petugasId: 1,
    petugasUuid: 'officer',
    status: 'Dalam Proses',
    tanggalTransaksi: DateTime(2026, 11, 6),
    pembayaranSekarang: 20,
    jobs: [
      TransactionJobInput(
        jenisPekerjaan: domain,
        namaPekerjaan: 'Historical job',
        pekerjaanNotarisId: domain == 'notaris' ? job : null,
        pekerjaanPpatId: domain == 'ppat' ? job : null,
        detailUuid: 'detail-$domain',
        biayaLayanan: 100,
        kategoriSnapshot: 'Historical category',
        prosesSnapshot: '[{"id":"1","name":"Historical process","status":"Belum Valid","attributes":["Document"]}]',
      ),
    ],
  );
}

Future<List<Map<String, dynamic>>> rows(AppDatabase db, String table) async =>
    (await db.customSelect('SELECT * FROM $table ORDER BY id').get())
        .map((r) => r.data)
        .toList();

void main() {
  late AppDatabase db;
  late RecycleBinRepository bin;
  AuthSession? session;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    session = recoverySession();
    bin = RecycleBinRepository(db, () => session);
  });
  tearDown(() => db.close());

  for (final domain in ['notaris', 'ppat']) {
    final masterModule = domain == 'notaris'
        ? RecycleModule.notaris
        : RecycleModule.ppat;
    final transactionModule = domain == 'notaris'
        ? RecycleModule.transactionNotaris
        : RecycleModule.transactionPpat;
    test(
      'restore $domain master preserves PK UUID and untouched aggregate including old child tombstones',
      () async {
        final id = await seedMaster(db, domain);
        final table = 'pekerjaan_$domain';
        final original = (await rows(db, table)).single;
        await db.customStatement(
          'UPDATE ${table}_atributs SET deleted_at=10,status=0',
        );
        final children = [
          for (final suffix in ['harga', 'proses', 'atributs'])
            await rows(db, '${table}_$suffix'),
        ];
        if (domain == 'notaris') {
          await PekerjaanNotarisRepository(db.pekerjaanDao).delete(id);
        } else {
          await PekerjaanPpatRepository(db.pekerjaanDao).delete(id);
        }
        final record = (await bin.list(module: masterModule)).single;
        expect(record.blocked, isNull);
        await bin.restore(record);
        final restored = (await rows(db, table)).single;
        expect(restored['uuid'], original['uuid']);
        expect(restored['id'], id);
        expect(restored['deleted_at'], isNull);
        expect(restored['status'], 1);
        expect(restored['is_sync_dirty'], 1);
        for (var i = 0; i < 3; i++) {
          expect(
            await rows(db, '${table}_${['harga', 'proses', 'atributs'][i]}'),
            children[i],
          );
        }
        expect(await bin.list(module: masterModule), isEmpty);
        expect((await bin.history()).single['outcome'], 'success');
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      },
    );

    test(
      'restore $domain transaction preserves status number child identities snapshots payments and audit',
      () async {
        final id = await seedTransaction(db, domain);
        final original = (await rows(db, 'transaksis')).single;
        final details = await rows(db, 'transaksi_details');
        final processes = await rows(db, 'transaksi_proses');
        await db.customStatement(
          "INSERT INTO transaksi_proses_riwayat(uuid,transaksi_proses_id,status_baru,actor_user_id,created_at) VALUES('audit',1,'menunggu_validasi',1,10)",
        );
        final audit = await rows(db, 'transaksi_proses_riwayat');
        final payments = await rows(db, 'transaksi_riwayat_pembayaran');
        // A previously removed detail is not part of this delete cascade.
        await db.customStatement(
          "INSERT INTO transaksi_details(uuid,transaksi_id,jenis_pekerjaan,nama_pekerjaan_snapshot,deleted_at,status) VALUES('old-detail',1,?,'Removed earlier',10,0)",
          [domain],
        );
        await TransactionRepository(db).delete(id);
        final record = (await bin.list(module: transactionModule)).single;
        expect(record.blocked, isNull);
        await bin.restore(record);
        final restored = (await rows(db, 'transaksis')).single;
        for (final key in [
          'id',
          'uuid',
          'no_akta',
          'status_transaksi',
          'pembayaran_sekarang',
          'total',
        ]) {
          expect(restored[key], original[key]);
        }
        final restoredDetail = (await rows(db, 'transaksi_details')).first;
        for (final key in [
          'id',
          'uuid',
          'nama_pekerjaan_snapshot',
          'kategori_snapshot',
          'proses_snapshot',
          'total_snapshot',
          'status',
          'deleted_at',
        ]) {
          expect(restoredDetail[key], details.single[key]);
        }
        expect((await rows(db, 'transaksi_details')).last['deleted_at'], 10);
        expect(await rows(db, 'transaksi_proses'), processes);
        expect(await rows(db, 'transaksi_proses_riwayat'), audit);
        expect(await rows(db, 'transaksi_riwayat_pembayaran'), payments);
        await expectLater(
          bin.restore(record),
          throwsA(isA<RestoreFailure>().having((e) => e.code, 'code', 'stale')),
        );
        expect((await bin.history()).map((e) => e['outcome']), [
          'failed',
          'success',
        ]);
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        expect(
          (await db.customSelect('PRAGMA integrity_check').getSingle())
              .read<String>('integrity_check'),
          'ok',
        );
      },
    );
  }

  test('permission/reference revalidation rejects with no partial write and sanitized failure audit', () async {
    await seedTransaction(db, 'notaris');
    await TransactionRepository(db).delete(1);
    final record = (await bin.list()).single;
    final parent = await rows(db, 'transaksis'),
        child = await rows(db, 'transaksi_details');
    session = recoverySession(update: false);
    await expectLater(
      bin.restore(record),
      throwsA(
        isA<RestoreFailure>().having((e) => e.code, 'code', 'permission'),
      ),
    );
    session = recoverySession();
    await db.customStatement('UPDATE petugas SET status=0');
    await expectLater(
      bin.restore(record),
      throwsA(isA<RestoreFailure>().having((e) => e.code, 'code', 'reference')),
    );
    expect(await rows(db, 'transaksis'), parent);
    expect(await rows(db, 'transaksi_details'), child);
    expect((await bin.history()).map((e) => e['error_code']), [
      'reference',
      'permission',
    ]);
    session = null;
    expect(await bin.list(), isEmpty);
    expect(await bin.history(), isEmpty);
  });

  test(
    'master invalid category and mismatched attribute relation block restore',
    () async {
      await seedMaster(db, 'ppat');
      await PekerjaanPpatRepository(db.pekerjaanDao).delete(1);
      await db.customStatement('UPDATE pekerjaan_kategori SET status=0');
      expect((await bin.list()).single.blocked?.code, 'reference');
      await db.customStatement('UPDATE pekerjaan_kategori SET status=1');
      await db.customStatement('UPDATE pekerjaan_ppat_proses SET status=0');
      expect((await bin.list()).single.blocked?.code, 'reference');
    },
  );

  test('cloud identity and pending receipt in either state never permit local restore', () async {
    await seedMaster(db, 'notaris');
    await PekerjaanNotarisRepository(db.pekerjaanDao).delete(1);
    final uuid = (await rows(db, 'pekerjaan_notaris')).single['uuid'];
    await db.customStatement(
      "INSERT INTO pekerjaan_notaris_sync_identity VALUES(?,?,'scope',3)",
      [uuid, uuid],
    );
    final record = (await bin.list()).single;
    expect(record.blocked?.code, 'cloud');
    await expectLater(
      bin.restore(record),
      throwsA(isA<RestoreFailure>().having((e) => e.code, 'code', 'cloud')),
    );
    await db.customStatement('DELETE FROM pekerjaan_notaris_sync_identity');
    for (final state in ['pending', 'acked']) {
      await db.customStatement(
        'INSERT OR REPLACE INTO pekerjaan_notaris_sync_pending VALUES(?,?,?,?)',
        [uuid, 'mutation', '{}', state],
      );
      expect((await bin.list()).single.blocked?.code, 'cloud');
    }
    await seedTransaction(db, 'ppat');
    await TransactionRepository(db).delete(1);
    final tx = (await rows(db, 'transaksis')).single;
    await db.customStatement(
      "INSERT INTO transaction_cloud_identity VALUES(?,?,'scope',3,?,'{}')",
      [tx['uuid'], tx['uuid'], tx['no_akta']],
    );
    expect(
      (await bin.list(module: RecycleModule.transactionPpat))
          .single
          .blocked
          ?.code,
      'cloud',
    );
    expect((await rows(db, 'transaksis')).single['deleted_at'], isNotNull);
  });

  test(
    'failure after child update rolls back parent children and success audit',
    () async {
      await seedTransaction(db, 'notaris');
      await TransactionRepository(db).delete(1);
      final record = (await bin.list()).single;
      final parent = await rows(db, 'transaksis'),
          child = await rows(db, 'transaksi_details');
      await db.customStatement(
        "CREATE TRIGGER reject_restore BEFORE UPDATE ON transaksis WHEN NEW.deleted_at IS NULL BEGIN SELECT RAISE(ABORT,'private fixture error'); END",
      );
      await expectLater(
        bin.restore(record),
        throwsA(isA<RestoreFailure>().having((e) => e.code, 'code', 'storage')),
      );
      expect(await rows(db, 'transaksis'), parent);
      expect(await rows(db, 'transaksi_details'), child);
      final log = (await bin.history()).single;
      expect(log['outcome'], 'failed');
      expect(log['error_code'], 'storage');
      expect(log.toString(), isNot(contains('private fixture')));
    },
  );

  test(
    'legacy transaction without original status evidence is blocked',
    () async {
      await seedTransaction(db, 'notaris');
      await db.customStatement(
        "UPDATE transaksis SET deleted_at=10,status_transaksi='Dihapus'",
      );
      expect((await bin.list()).single.blocked?.code, 'history');
    },
  );

  test('v18 upgrade and restart preserve existing data and durable restore history', () async {
    await db.close();
    final folder = await Directory.systemTemp.createTemp('recycle_bin_');
    addTearDown(() async {
      await db.close();
      await folder.delete(recursive: true);
    });
    final file = File('${folder.path}/fixture.sqlite');
    db = AppDatabase.forTesting(NativeDatabase(file));
    await seedTransaction(db, 'ppat');
    final original = await rows(db, 'transaksis');
    await db.customStatement('DROP TABLE recycle_bin_events');
    await db.customStatement('PRAGMA user_version=18');
    await db.close();
    db = AppDatabase.forTesting(NativeDatabase(file));
    bin = RecycleBinRepository(db, () => session);
    expect(await rows(db, 'transaksis'), original);
    expect(
      (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
        'user_version',
      ),
      19,
    );
    await TransactionRepository(db).delete(1);
    await bin.restore((await bin.list()).single);
    await db.close();
    db = AppDatabase.forTesting(NativeDatabase(file));
    bin = RecycleBinRepository(db, () => session);
    expect(
      (await rows(db, 'transaksis')).single['uuid'],
      original.single['uuid'],
    );
    expect(
      (await rows(db, 'transaksis')).single['status_transaksi'],
      'Dalam Proses',
    );
    expect((await rows(db, 'transaksi_riwayat_pembayaran')), hasLength(1));
    expect((await bin.history()).single['outcome'], 'success');
    expect(await bin.list(), isEmpty);
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });
}
