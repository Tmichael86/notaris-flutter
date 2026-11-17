import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/models/verified_demo_session.dart';
import 'package:frontend_notaris/repositories/materai_stock_repository.dart';
import 'package:frontend_notaris/repositories/transaction_repository.dart';

import '../support/materai_stock_fixture.dart';
import '../support/penghasilan_fixture.dart';
import 'materai_transaction_usage_test.dart' show saveUsage, ppatUuid;

Future<int> applyCorrection(
  TransactionRepository repo,
  int id,
  int sheets, {
  MateraiCorrectionIntent? intent,
  String? note,
  String? status,
}) async {
  final parent = (await repo.findById(id))!;
  final details = await repo.watchDetailsOnce(id);
  return repo.save(
    id: id,
    nomorTransaksi: parent.noAkta,
    jenisTransaksi: parent.jenisTransaksi,
    pemohonId: parent.pemohonId!,
    pemohonUuid: parent.pemohonUuid!,
    petugasId: parent.petugasId!,
    petugasUuid: parent.petugasUuid!,
    status: status ?? parent.statusTransaksi,
    tanggalTransaksi: parent.tanggalTransaksi!,
    tanggalJatuhTempo: parent.tanggalJatuhTempo,
    diskon: parent.diskon,
    metodePembayaran: parent.metodePembayaran,
    catatan: note ?? parent.catatan,
    jumlahMaterai: sheets,
    materaiCorrection: intent,
    jobs: [
      for (final detail in details)
        TransactionJobInput(
          detailUuid: detail.uuid,
          jenisPekerjaan: detail.jenisPekerjaan,
          namaPekerjaan: detail.namaPekerjaanSnapshot,
          biayaLayanan: detail.biayaLayanan,
          biayaLainnya: detail.biayaLainnya,
          unchangedDetail: detail,
          pekerjaanNotarisId: detail.pekerjaanNotarisId,
          pekerjaanPpatId: detail.pekerjaanPpatId,
        ),
    ],
  );
}

void main() {
  late Directory temp;
  late File path;
  late MateraiProfileDatabase db;
  late MateraiStockBinding opening;
  late MateraiStockRepository inventory;
  late TransactionRepository repo;
  late ExpiringPaymentDemoSession actor;
  late int notaris, ppat;
  late DateTime clock;
  NativeDatabase connect() => NativeDatabase(
    path,
    setup: (raw) => raw.execute('PRAGMA foreign_keys=ON'),
  );
  MateraiStockRepository on(MateraiProfileDatabase db) =>
      MateraiStockRepository(
        MateraiStockBinding(
          db,
          opening.profileId,
          opening.openingSha256,
          transactionUsageEnabled: true,
          transactionCorrectionsEnabled: true,
        ),
        () => actor,
        now: () => clock = clock.add(const Duration(milliseconds: 10)),
      );
  Future<MateraiCorrectionIntent> intent(int id, int op) async {
    final preview = (await inventory.correctionPreview(id))!;
    return (
      operation: 'f0000000-0000-4000-8000-${op.toString().padLeft(12, '0')}',
      revision: preview.revision,
      predecessor: preview.predecessor,
    );
  }

  Future<List<Map<String, Object?>>> ledger() async =>
      (await db
              .customSelect('SELECT * FROM materai_movements ORDER BY id')
              .get())
          .map((row) => row.data)
          .toList();
  final denied = throwsA(isA<MateraiStockException>());

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('materai-correction-test-');
    path = File('${temp.path}${Platform.pathSeparator}offline.sqlite');
    db = MateraiProfileDatabase(connect());
    await seedPenghasilan(db);
    opening = await seedMateraiOpening(
      db,
      transactionUsage: true,
      transactionCorrection: true,
    );
    actor = usageActor(opening.profileId);
    clock = DateTime.now();
    inventory = on(db);
    repo = TransactionRepository(db, materaiStock: inventory);
    notaris = await saveUsage(repo);
    ppat = await saveUsage(repo, uuid: ppatUuid, domain: 'ppat', sheets: 4);
  });
  tearDown(() async {
    await db.close();
    await temp.delete(recursive: true);
  });

  test('Notaris return, increase, zero and PPAT multi-work correction preserve history', () async {
    final initial = await ledger();
    final detail = await repo.watchDetailsOnce(ppat);
    final payments = await repo.getPaymentHistory(notaris);
    final ppatPayments = await repo.getPaymentHistory(ppat);
    await applyCorrection(repo, notaris, 1, intent: await intent(notaris, 1));
    await applyCorrection(repo, notaris, 4, intent: await intent(notaris, 2));
    await applyCorrection(repo, ppat, 2, intent: await intent(ppat, 3));
    await applyCorrection(repo, notaris, 4, note: 'Info lokal');
    expect(await ledger(), hasLength(6));
    await applyCorrection(repo, notaris, 0, intent: await intent(notaris, 4));
    final after = await ledger();
    expect(after.take(3), initial);
    expect(after.map((row) => row['recorded_stock']), [
      20,
      17,
      13,
      15,
      12,
      14,
      18,
    ]);
    expect(after.map((row) => row['stock_in']), [0, 0, 0, 2, 0, 2, 4]);
    expect(after.map((row) => row['stock_out']), [0, 3, 4, 0, 3, 0, 0]);
    expect((await repo.findById(notaris))!.jumlahMaterai, 0);
    final proofs = after
        .skip(3)
        .map((row) => jsonDecode(row['provenance_json'] as String) as Map)
        .toList();
    expect(proofs.map((p) => p['kind']), [
      'transaction_usage_return',
      'transaction_usage_increase',
      'transaction_usage_return',
      'transaction_usage_return',
    ]);
    expect(proofs.map((p) => p['original_movement']), [2, 2, 3, 2]);
    expect(proofs.map((p) => p['delta']), [-2, 3, -2, -4]);
    expect(proofs.map((p) => p['user_id']), [102, 102, 102, 102]);
    expect(await repo.getPaymentHistory(notaris), payments);
    expect(await repo.getPaymentHistory(ppat), ppatPayments);
    expect(await repo.watchDetailsOnce(ppat), detail);
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    expect(
      (await db.customSelect('PRAGMA integrity_check').getSingle())
          .data
          .values
          .single,
      'ok',
    );
    await expectLater(repo.delete(notaris), denied);
    await expectLater(
      applyCorrection(
        repo,
        ppat,
        0,
        intent: await intent(ppat, 5),
        status: 'Dibatalkan',
      ),
      denied,
    );
  });

  test('stable UUID replay after reopen and changed payload reject', () async {
    final operation = await intent(notaris, 1);
    final results = await Future.wait([
      applyCorrection(repo, notaris, 1, intent: operation),
      applyCorrection(repo, notaris, 1, intent: operation),
    ]);
    expect(results, [notaris, notaris]);
    final original = await ledger();
    final reopened = MateraiProfileDatabase(connect());
    try {
      final next = TransactionRepository(reopened, materaiStock: on(reopened));
      expect(
        await applyCorrection(next, notaris, 1, intent: operation),
        notaris,
      );
      await expectLater(
        applyCorrection(next, notaris, 2, intent: operation),
        denied,
      );
      await expectLater(
        applyCorrection(next, ppat, 1, intent: operation),
        denied,
      );
    } finally {
      await reopened.close();
    }
    expect(await ledger(), original);
  });

  test('insufficient, stale header, update failure and ledger failure leave no partial write', () async {
    final original = await ledger();
    final row = (await repo.findById(notaris))!;
    final payments = await repo.getPaymentHistory(notaris);
    final details = await repo.watchDetailsOnce(notaris);
    final operation = await intent(notaris, 1);
    await expectLater(
      applyCorrection(repo, notaris, 17, intent: operation),
      denied,
    );
    await db.customStatement(
      "CREATE TRIGGER reject_edit AFTER UPDATE ON transaksis BEGIN SELECT RAISE(ABORT,'test edit'); END",
    );
    await expectLater(
      applyCorrection(repo, notaris, 1, intent: operation),
      throwsA(anything),
    );
    await db.customStatement('DROP TRIGGER reject_edit');
    await db.customStatement(
      "CREATE TRIGGER reject_move AFTER INSERT ON materai_movements BEGIN SELECT RAISE(ABORT,'test movement'); END",
    );
    await expectLater(
      applyCorrection(repo, notaris, 1, intent: operation),
      throwsA(anything),
    );
    await db.customStatement('DROP TRIGGER reject_move');
    expect(await repo.findById(notaris), row);
    expect(await repo.getPaymentHistory(notaris), payments);
    expect(await repo.watchDetailsOnce(notaris), details);
    expect(await ledger(), original);
    await applyCorrection(repo, notaris, 3, note: 'Edits from second workflow');
    await expectLater(
      applyCorrection(repo, notaris, 1, intent: operation),
      denied,
    );
  });

  test('concurrent edits and manual receipt invalidate stale predecessor without overspending', () async {
    final first = await intent(notaris, 1);
    final second = await intent(notaris, 2);
    final competing = await intent(ppat, 3);
    Future<Object> outcome(Future<int> f) =>
        f.then<Object>((id) => id, onError: (Object error) => error);
    final results = await Future.wait([
      outcome(applyCorrection(repo, notaris, 13, intent: first)),
      outcome(applyCorrection(repo, notaris, 14, intent: second)),
      outcome(applyCorrection(repo, ppat, 14, intent: competing)),
    ]);
    expect(results.whereType<int>(), hasLength(1));
    expect(results.whereType<MateraiStockException>(), hasLength(2));
    final latest = await intent(ppat, 4);
    actor = stockActor(opening.profileId);
    final stock = await inventory.context();
    await inventory.receive(
      operation: 'a0000000-0000-4000-8000-000000000999',
      expectedPredecessor: stock.predecessor,
      businessDate: stock.date,
      sheets: 10,
    );
    actor = usageActor(opening.profileId);
    await expectLater(applyCorrection(repo, ppat, 2, intent: latest), denied);
    expect(await ledger(), hasLength(5));
  });

  test('missing link, untrusted history, expired/read-only/unmapped/wrong-scope are blocked', () async {
    final operation = await intent(notaris, 1);
    for (final invalid in [
      stockActor(
        opening.profileId,
        transactionCreate: false,
        transactionUpdate: false,
      ),
      usageActor(opening.profileId, expired: true),
      usageActor(opening.profileId, user: 103),
      usageActor('0' * 32),
    ]) {
      actor = invalid;
      await expectLater(
        applyCorrection(repo, notaris, 1, intent: operation),
        denied,
      );
    }
    actor = usageActor(opening.profileId);
    await expectLater(applyCorrection(repo, 1, 1, intent: operation), denied);
    await db.customStatement(
      'UPDATE transaksis SET jumlah_materai=2 WHERE id=?',
      [notaris],
    );
    await expectLater(
      applyCorrection(repo, notaris, 1, intent: operation),
      denied,
    );
    await db.customStatement(
      'UPDATE transaksis SET jumlah_materai=3 WHERE id=?',
      [notaris],
    );
    await db.customStatement('PRAGMA query_only=ON');
    await expectLater(
      applyCorrection(repo, notaris, 1, intent: operation),
      denied,
    );
    expect(await ledger(), hasLength(3));
  });
}
