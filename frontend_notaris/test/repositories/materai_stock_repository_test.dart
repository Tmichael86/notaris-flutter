import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/models/auth_session.dart';
import 'package:frontend_notaris/repositories/materai_repository.dart';
import 'package:frontend_notaris/repositories/materai_stock_repository.dart';

import '../support/materai_stock_fixture.dart';

const op = 'a0000000-0000-4000-8000-000000000001';
const other = 'a0000000-0000-4000-8000-000000000002';

void main() {
  late Directory temp;
  late File file;
  late MateraiProfileDatabase db;
  late DateTime now;
  late AuthSession session;
  NativeDatabase connect() => NativeDatabase(file);
  MateraiStockRepository repository(MateraiStockBinding binding) =>
      MateraiStockRepository(binding, () => session, now: () => now);
  Future<MateraiStockResult> submit(
    MateraiStockRepository repo, {
    String operation = op,
    int previous = 1,
    Object? sheets = 7,
    String date = '2026-11-10',
  }) => repo.receive(
    operation: operation,
    expectedPredecessor: previous,
    businessDate: date,
    sheets: sheets,
    description: 'Kotak baru',
  );

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('materai-stock-test-');
    file = File('${temp.path}${Platform.pathSeparator}offline.sqlite');
    db = MateraiProfileDatabase(connect());
    now = openingTime.add(const Duration(hours: 1));
    session = stockActor(demoStockProfile);
  });
  tearDown(() async {
    await db.close();
    await temp.delete(recursive: true);
  });

  test('empty or unbound opening, contradictions and query_only fail closed', () async {
    final missing = MateraiStockBinding(
      db,
      demoStockProfile,
      List.filled(64, '0').join(),
    );
    await expectLater(
      repository(missing).context(),
      throwsA(isA<MateraiStockException>()),
    );
    final binding = await seedMateraiOpening(db);
    expect((await repository(binding).context()).stock, 20);
    await expectLater(
      repository(missing).context(),
      throwsA(isA<MateraiStockException>()),
    );
    await db.customStatement(
      "UPDATE materai_movements SET recorded_stock=21,review_reason='konflik'",
    );
    await expectLater(
      submit(repository(binding)),
      throwsA(isA<MateraiStockException>()),
    );
    await db.customStatement(
      'UPDATE materai_movements SET recorded_stock=20,review_reason=NULL',
    );
    await db.customStatement('PRAGMA query_only=ON');
    await expectLater(
      submit(repository(binding)),
      throwsA(isA<MateraiStockException>()),
    );
    expect(
      (await MateraiRepository(
        db,
        () => session,
      ).read()).verified.single.recordedStock,
      20,
    );
  });

  test('receipt preserves snapshots and provenance, same-day retry is idempotent after restart', () async {
    final binding = await seedMateraiOpening(db);
    final repo = repository(binding);
    final result = await submit(repo);
    expect(result.stock, 27);
    expect((await submit(repo)).replayed, isTrue);
    await expectLater(
      submit(repo, sheets: 8),
      throwsA(isA<MateraiStockException>()),
    );
    now = now.add(const Duration(seconds: 1));
    final sameDay = await submit(
      repo,
      operation: other,
      previous: result.id,
      sheets: 2,
    );
    expect(sameDay.stock, 29);
    final row = await db
        .customSelect('SELECT * FROM materai_movements WHERE id=2')
        .getSingle();
    final proof = jsonDecode(row.read<String>('provenance_json')) as Map;
    expect(proof['user_id'], 102);
    expect(proof['group_id'], 102);
    expect(proof['officer_uuid'], 'e0c928a2-c304-437e-8bf5-7a81bd5e0eae');
    expect(
      row.read<int>('source_created_ms'),
      openingTime.add(const Duration(hours: 1)).millisecondsSinceEpoch,
    );
    final reopened = MateraiProfileDatabase(connect());
    try {
      final reopenedRepo = repository(
        MateraiStockBinding(reopened, binding.profileId, binding.openingSha256),
      );
      expect((await reopenedRepo.context()).stock, 29);
      expect((await submit(reopenedRepo)).id, result.id);
      final report = await MateraiRepository(reopened, () => session).read();
      expect(report.verified.map((row) => row.recordedStock), [29, 27, 20]);
      expect(report.verified.map((row) => row.stockOut), [0, 0, 0]);
      expect(report.verified.map((row) => row.stockIn), [2, 7, 0]);
      expect(report.officers.values, [fixtureOfficer]);
    } finally {
      await reopened.close();
    }
  });

  test(
    'invalid counts, overflow and historical dates are rejected unchanged',
    () async {
      final repo = repository(
        await seedMateraiOpening(db, stock: materaiStockLimit),
      );
      for (final invalid in [
        0,
        -1,
        1.5,
        5.0,
        '7',
        'x',
        10001,
        9223372036854775807,
      ]) {
        await expectLater(
          submit(repo, sheets: invalid),
          throwsA(isA<MateraiStockException>()),
        );
      }
      for (final date in ['2026-11-09', '2026-02-30', '10/11/2026']) {
        await expectLater(
          submit(repo, date: date),
          throwsA(isA<MateraiStockException>()),
        );
      }
      await expectLater(
        submit(repo, sheets: 1),
        throwsA(isA<MateraiStockException>()),
      );
      expect((await repo.context()).stock, materaiStockLimit);
    },
  );

  test('distinct concurrent requests conflict, retry refreshes predecessor and failed insert rolls back', () async {
    final binding = await seedMateraiOpening(db);
    final second = MateraiProfileDatabase(connect());
    addTearDown(second.close);
    final repo = repository(binding);
    final secondRepo = repository(
      MateraiStockBinding(second, binding.profileId, binding.openingSha256),
    );
    Future<Object> outcome(Future<MateraiStockResult> work) =>
        work.then<Object>((result) => result, onError: (Object error) => error);
    final results = await Future.wait([
      outcome(submit(repo)),
      outcome(submit(secondRepo, operation: other)),
    ]);
    expect(results.whereType<MateraiStockResult>(), hasLength(1));
    expect(results.whereType<MateraiStockException>(), hasLength(1));
    final current = await repo.context();
    expect(current.stock, 27);
    now = now.add(const Duration(seconds: 1));
    final failed = results.first is MateraiStockException ? op : other;
    await db.customStatement(
      "CREATE TRIGGER fail_receipt AFTER INSERT ON materai_movements BEGIN SELECT RAISE(ABORT, 'test rollback'); END",
    );
    await expectLater(
      submit(repo, operation: failed, previous: current.predecessor),
      throwsA(anything),
    );
    expect((await repo.context()).stock, 27);
    await db.customStatement('DROP TRIGGER fail_receipt');
    expect(
      (await submit(
        repo,
        operation: failed,
        previous: current.predecessor,
      )).stock,
      34,
    );
  });

  test('read-only, denied, expired, unverified, cross-profile and unmapped actors cannot receive', () async {
    final binding = await seedMateraiOpening(db);
    final repo = repository(binding);
    for (final denied in [
      stockActor(demoStockProfile, create: 0),
      stockActor(demoStockProfile, read: 0),
      stockActor(demoStockProfile, expired: true),
      stockActor('0' * 32),
      stockActor(demoStockProfile, userId: 103),
      AuthSession.fromJson(stockActor(demoStockProfile).toJson()),
    ]) {
      session = denied;
      await expectLater(submit(repo), throwsA(isA<MateraiStockException>()));
    }
    session = stockActor(demoStockProfile);
    expect((await repo.context()).stock, 20);
  });
}
