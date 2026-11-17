import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/models/verified_demo_session.dart';
import 'package:frontend_notaris/repositories/materai_repository.dart';
import 'package:frontend_notaris/repositories/materai_stock_repository.dart';
import 'package:frontend_notaris/repositories/transaction_cloud_repository.dart';
import 'package:frontend_notaris/repositories/transaction_repository.dart';

import '../support/materai_stock_fixture.dart';
import '../support/penghasilan_fixture.dart';

const notarisUuid = 'e0000000-0000-4000-8000-000000000001';
const ppatUuid = 'e0000000-0000-4000-8000-000000000002';

Future<int> saveUsage(
  TransactionRepository repo, {
  String uuid = notarisUuid,
  String domain = 'notaris',
  int sheets = 3,
  int? editing,
  String status = 'Baru',
  bool duplicateDetail = false,
  bool requireUsage = true,
  String description = '',
  DateTime? deadline,
}) => repo.save(
  id: editing,
  createUuid: editing == null ? uuid : null,
  requireMateraiStockOut: requireUsage,
  nomorTransaksi: 'UJI-$domain-$uuid',
  jenisTransaksi: domain,
  pemohonId: 1,
  pemohonUuid: 'applicant',
  petugasId: 100,
  petugasUuid: 'e0c928a2-c304-437e-8bf5-7a81bd5e0eae',
  status: status,
  tanggalTransaksi: DateTime(2026, 11, 17),
  tanggalJatuhTempo: deadline,
  jumlahMaterai: sheets,
  pembayaranSekarang: editing == null ? 25000 : 0,
  catatan: description,
  jobs: [
    for (var i = 0; i < (domain == 'ppat' ? 2 : 1); i++)
      TransactionJobInput(
        jenisPekerjaan: domain,
        namaPekerjaan: 'Uji $i',
        biayaLayanan: 100000,
        pekerjaanNotarisId: domain == 'notaris' ? 1 : null,
        pekerjaanPpatId: domain == 'ppat' ? 1 : null,
        detailUuid: '$uuid-${duplicateDetail ? 0 : i}',
      ),
  ],
);

void main() {
  test('quantity input accepts decimal digits only and rejects fractions and overflow', () {
    expect(parseMateraiSheets(' 0 '), 0);
    expect(parseMateraiSheets('3'), 3);
    for (final input in [
      '3.0',
      '3,5',
      '0x12',
      '',
      '-1',
      '9223372036854775808',
    ]) {
      expect(parseMateraiSheets(input), isNull);
    }
  });
  late Directory temp;
  late File file;
  late MateraiProfileDatabase db;
  late MateraiStockBinding binding;
  late MateraiStockRepository inventory;
  late TransactionRepository repo;
  late ExpiringPaymentDemoSession session;
  NativeDatabase connect() => NativeDatabase(
    file,
    setup: (raw) => raw.execute('PRAGMA foreign_keys=ON'),
  );
  MateraiStockRepository stock(MateraiProfileDatabase database) =>
      MateraiStockRepository(
        MateraiStockBinding(
          database,
          binding.profileId,
          binding.openingSha256,
          transactionUsageEnabled: true,
        ),
        () => session,
      );
  final rejected = throwsA(isA<MateraiStockException>());
  Future<List<int>> counts() async => [
    for (final name in [
      'transaksis',
      'transaksi_details',
      'transaksi_riwayat_pembayaran',
      'transaksi_pembayaran_audit',
      'materai_movements',
      'transaction_cloud_identity',
      'transaction_cloud_pending',
    ])
      (await db.customSelect('SELECT COUNT(*) AS n FROM $name').getSingle())
          .read<int>('n'),
  ];

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('materai-usage-test-');
    file = File('${temp.path}${Platform.pathSeparator}offline.sqlite');
    db = MateraiProfileDatabase(connect());
    await seedPenghasilan(db);
    binding = await seedMateraiOpening(db, transactionUsage: true);
    session = usageActor(binding.profileId);
    inventory = stock(db);
    repo = TransactionRepository(db, materaiStock: inventory);
  });
  tearDown(() async {
    await db.close();
    await temp.delete(recursive: true);
  });

  test('Notaris and multi-job PPAT each consume once, retain payment and block cloud', () async {
    final before = await counts();
    final n = await saveUsage(repo);
    expect((await inventory.context(transactionUsage: true)).stock, 17);
    // The ledger uses real millisecond recording times.
    await Future<void>.delayed(const Duration(milliseconds: 2));
    final p = await saveUsage(repo, uuid: ppatUuid, domain: 'ppat', sheets: 4);
    expect(await counts(), [
      before[0] + 2,
      before[1] + 3,
      before[2] + 2,
      before[3],
      before[4] + 2,
      before[5],
      before[6],
    ]);
    final row = await repo.findById(p);
    expect(row!.uuid, ppatUuid);
    expect(row.jumlahMaterai, 4);
    expect((await repo.watchDetailsOnce(p)).length, 2);
    expect((await repo.getPaymentHistory(n)).single.nominalRupiah, 25000);
    expect(
      await TransactionCloudRepository.localCompletionBlockReason(db, row),
      contains('meterai'),
    );
    final report = await MateraiRepository(db, () => session).read();
    expect(report.verified.map((r) => r.stockOut), [4, 3, 0]);
    expect(report.verified.map((r) => r.recordedStock), [13, 17, 20]);
    final result = await db
        .customSelect('SELECT * FROM materai_movements WHERE stock_out=4')
        .getSingle();
    final proof = jsonDecode(result.read<String>('provenance_json')) as Map;
    expect(proof['transaction_id'], p);
    expect(proof['transaction_uuid'], ppatUuid);
    expect(proof['kind'], 'transaction_stock_out');
    expect(proof['user_id'], 102);
    expect(proof['officer_id'], 100);
    expect(proof['date'], '2026-11-17');
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    expect(
      (await db.customSelect('PRAGMA integrity_check').getSingle())
          .data
          .values
          .single,
      'ok',
    );
  });

  test('retry across reopen preserves identity and rejects changed contents including zero', () async {
    final saved = await saveUsage(repo);
    final committed = await counts();
    expect(await saveUsage(repo), saved);
    final second = MateraiProfileDatabase(connect());
    try {
      final reopened = TransactionRepository(
        second,
        materaiStock: stock(second),
      );
      expect(await saveUsage(reopened), saved);
      for (final sheets in [0, 4]) {
        await expectLater(saveUsage(reopened, sheets: sheets), rejected);
      }
      await expectLater(
        saveUsage(reopened, description: 'different'),
        rejected,
      );
    } finally {
      await second.close();
    }
    expect(await counts(), committed);
  });

  test('insufficient and invalid quantities, detail failure and movement failure roll back', () async {
    final start = await counts();
    for (final sheets in [21, 10001, 9223372036854775807]) {
      await expectLater(saveUsage(repo, sheets: sheets), rejected);
    }
    await expectLater(saveUsage(repo, sheets: -1), throwsArgumentError);
    await expectLater(
      saveUsage(repo, uuid: ppatUuid, domain: 'ppat', duplicateDetail: true),
      throwsA(anything),
    );
    await db.customStatement(
      "CREATE TRIGGER fail_usage AFTER INSERT ON materai_movements BEGIN SELECT RAISE(ABORT,'test failure'); END",
    );
    await expectLater(saveUsage(repo), throwsA(anything));
    expect(await counts(), start);
    expect((await inventory.context(transactionUsage: true)).stock, 20);
  });

  test('concurrent transaction creates cannot overspend stock', () async {
    final otherDb = MateraiProfileDatabase(connect());
    try {
      final other = TransactionRepository(
        otherDb,
        materaiStock: stock(otherDb),
      );
      Future<Object> outcome(Future<int> operation) =>
          operation.then<Object>((id) => id, onError: (Object e) => e);
      final result = await Future.wait([
        outcome(saveUsage(repo, sheets: 12)),
        outcome(saveUsage(other, uuid: ppatUuid, domain: 'ppat', sheets: 11)),
      ]);
      expect(result.whereType<int>(), hasLength(1));
      expect(result.whereType<MateraiStockException>(), hasLength(1));
      expect([
        8,
        9,
      ], contains((await inventory.context(transactionUsage: true)).stock));
      expect(
        (await db
                .customSelect(
                  'SELECT COUNT(*) AS n FROM materai_movements WHERE stock_out>0',
                )
                .getSingle())
            .read<int>('n'),
        1,
      );
    } finally {
      await otherDb.close();
    }
  });

  test('old and zero-usage transactions remain ordinary; linked edits and deletes are protected', () async {
    await expectLater(
      saveUsage(TransactionRepository(db), requireUsage: false),
      rejected,
    );
    final legacy = await saveUsage(
      TransactionRepository(db),
      sheets: 0,
      requireUsage: false,
    );
    await db.customStatement(
      'UPDATE transaksis SET jumlah_materai=3 WHERE id=?',
      [legacy],
    );
    expect(await hasInitialMateraiUsage(db, notarisUuid), isFalse);
    expect(await repo.findById(legacy), isNotNull);
    expect(await repo.delete(legacy), isTrue);
    final zero = await saveUsage(repo, uuid: ppatUuid, sheets: 0);
    expect(await hasInitialMateraiUsage(db, ppatUuid), isFalse);
    final fresh = await saveUsage(
      repo,
      uuid: 'e0000000-0000-4000-8000-000000000003',
    );
    final actualUuid = (await repo.findById(fresh))!.uuid;
    final committed = await counts();
    expect(
      await saveUsage(
        repo,
        uuid: actualUuid,
        editing: fresh,
        description: 'edit',
      ),
      fresh,
    );
    await expectLater(
      saveUsage(repo, uuid: actualUuid, editing: fresh, sheets: 5),
      rejected,
    );
    await expectLater(
      saveUsage(repo, uuid: actualUuid, editing: fresh, status: 'Dibatalkan'),
      rejected,
    );
    await expectLater(TransactionRepository(db).delete(fresh), rejected);
    expect(await counts(), committed);
    expect((await repo.findById(zero))!.jumlahMaterai, 0);
  });

  test('binding, reconciled baseline, writable DB and explicit transaction create required', () async {
    final before = await counts();
    await expectLater(saveUsage(TransactionRepository(db)), rejected);
    for (final invalid in [
      usageActor(binding.profileId, grant: false),
      usageActor(binding.profileId, expired: true),
      usageActor('0' * 32),
      usageActor(binding.profileId, user: 103),
    ]) {
      session = invalid;
      await expectLater(saveUsage(repo), rejected);
    }
    session = usageActor(binding.profileId);
    final notBound = MateraiStockRepository(binding, () => session);
    await expectLater(
      saveUsage(TransactionRepository(db, materaiStock: notBound)),
      rejected,
    );
    await db.customStatement(
      "UPDATE materai_movements SET review_reason='test conflict'",
    );
    await expectLater(saveUsage(repo), rejected);
    await db.customStatement('UPDATE materai_movements SET review_reason=NULL');
    await db.customStatement('PRAGMA query_only=ON');
    await expectLater(saveUsage(repo), rejected);
    expect(await counts(), before);
  });
}
