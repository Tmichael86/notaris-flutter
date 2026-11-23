import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/models/auth_session.dart';
import 'package:frontend_notaris/repositories/pengeluaran_repository.dart';

AuthSession expenseSession({
  String code = 'pengeluaran',
  int status = 1,
  bool read = true,
  bool write = true,
}) => AuthSession(
  token: 'test',
  userId: 1,
  groupId: 1,
  userName: 'Operator',
  groupName: 'Kantor',
  user: const {},
  verifiedAt: DateTime.utc(2026),
  isOffline: true,
  sidebars: [
    {
      'sidebar': {'sidebar_kode': code, 'status': status},
      'read': read,
      'create': write,
      'update': write,
      'delete': write,
    },
  ],
);

void main() {
  late AppDatabase db;
  late AuthSession? session;
  late PengeluaranRepository repo;

  PengeluaranInput input({
    String? invoice,
    int jenis = 1,
    int nominal = 120,
    String note = ' Transport ',
    DateTime? date,
  }) => (
    noFaktur: invoice,
    tanggal: date ?? DateTime(2031, 2, 3),
    nominal: nominal,
    jenisId: jenis,
    keterangan: note,
  );

  PengeluaranFilter filter({
    int page = 0,
    String search = '',
    int? jenis,
    DateTime? from,
    DateTime? through,
  }) => (
    from: from,
    through: through,
    jenisId: jenis,
    search: search,
    page: page,
  );

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    session = expenseSession();
    repo = PengeluaranRepository(db, () => session);
    await db
        .into(db.pengeluaranJenis)
        .insert(
          PengeluaranJenisCompanion.insert(uuid: 'jenis-1', nama: 'Perjalanan'),
        );
    await db
        .into(db.pengeluaranJenis)
        .insert(PengeluaranJenisCompanion.insert(uuid: 'jenis-2', nama: 'ATK'));
  });

  test(
    'offline CRUD retains identity and never changes sync storage',
    () async {
      final master = await db.select(db.pengeluaranJenis).get();
      final initial = await repo.watchPage(filter()).first;
      expect(initial.rows, isEmpty);
      expect(initial.total, BigInt.zero);

      final id = await repo.create(input(invoice: '   '));
      final other = await repo.create(input(invoice: 'INV'));
      final third = await repo.create(input(invoice: 'INV'));
      final before = (await repo.detail(id))!;
      expect(before.noFaktur, isNull);
      expect(before.keterangan, 'Transport');
      expect(before.tanggal.toUtc(), DateTime.utc(2031, 2, 3));
      expect(
        (await repo.detail(third))!.uuid,
        isNot((await repo.detail(other))!.uuid),
      );

      await repo.update(id, input(invoice: ' INV ', jenis: 2, nominal: 200));
      final after = (await repo.detail(id))!;
      expect(after.uuid, before.uuid);
      expect(after.createdAt, before.createdAt);
      expect(after.noFaktur, 'INV');
      expect(after.jenisNama, 'ATK');
      expect(after.nominal, 200);

      await repo.delete(id);
      expect(await repo.detail(id), isNull);
      final deleted = await (db.select(
        db.pengeluarans,
      )..where((r) => r.id.equals(id))).getSingle();
      expect(deleted.uuid, before.uuid);
      expect(deleted.deletedAt, isNotNull);
      final active = await repo.watchPage(filter()).first;
      expect(active.count, 2);
      expect(active.total, BigInt.from(240));
      expect(await db.select(db.pengeluaranJenis).get(), master);
      for (final table in [
        'transaction_cloud_pending',
        'transaction_cloud_feed',
        'sync_logs',
      ]) {
        expect(await db.customSelect('SELECT * FROM $table').get(), isEmpty);
      }
    },
  );

  test('validation and action-level denial leave rows unchanged', () async {
    final valid = input();
    for (final invalid in [
      input(nominal: 0),
      input(nominal: -1),
      input(note: '  '),
      input(jenis: 99),
      (
        noFaktur: null,
        tanggal: null,
        nominal: 1,
        jenisId: 1,
        keterangan: 'Valid',
      ),
    ]) {
      await expectLater(
        repo.create(invalid),
        throwsA(isA<PengeluaranFailure>()),
      );
    }
    final id = await repo.create(valid);
    final original = await repo.detail(id);
    session = expenseSession(write: false);
    expect(await repo.detail(id), original);
    await expectLater(repo.create(valid), throwsA(isA<PengeluaranFailure>()));
    await expectLater(
      repo.update(id, input(nominal: 1)),
      throwsA(isA<PengeluaranFailure>()),
    );
    await expectLater(repo.delete(id), throwsA(isA<PengeluaranFailure>()));
    expect(await repo.detail(id), original);
    for (final denied in [
      null,
      expenseSession(code: 'jenis_pengeluaran'),
      expenseSession(status: 0),
      expenseSession(read: false),
    ]) {
      session = denied;
      expect(
        () => repo.watchPage(filter()),
        throwsA(isA<PengeluaranFailure>()),
      );
      expect(() => repo.detail(id), throwsA(isA<PengeluaranFailure>()));
      await expectLater(repo.create(valid), throwsA(isA<PengeluaranFailure>()));
    }
    expect(await db.select(db.pengeluarans).get(), [original]);
  });

  test('historic jenis snapshot survives rename and deactivation', () async {
    final id = await repo.create(input());
    final other = await repo.create(input(jenis: 2));
    await db.customStatement(
      "UPDATE pengeluaran_jenis SET nama = 'Nama baru', status = 0, deleted_at = 1 WHERE id = 1",
    );
    expect(
      (await repo.watchFilterJenis().first).map((row) => row.id),
      contains(1),
    );
    await repo.update(id, input(note: 'Perjalanan diperbarui'));
    expect((await repo.detail(id))!.jenisNama, 'Perjalanan');
    await expectLater(repo.create(input()), throwsA(isA<PengeluaranFailure>()));
    await expectLater(
      repo.update(other, input()),
      throwsA(isA<PengeluaranFailure>()),
    );
    expect((await repo.detail(other))!.jenisId, 2);
    await repo.delete(id);
    expect(
      (await repo.watchFilterJenis().first).map((row) => row.id),
      isNot(contains(1)),
    );
    // Historical references remain protected even after soft delete.
    await expectLater(
      db.customStatement('DELETE FROM pengeluaran_jenis WHERE id = 1'),
      throwsException,
    );
    await expectLater(
      db.customStatement('UPDATE pengeluaran SET jenis_id = 99 WHERE id = $id'),
      throwsException,
    );
    await expectLater(
      db.customStatement('UPDATE pengeluaran SET nominal = 1.5 WHERE id = $id'),
      throwsException,
    );
    await expectLater(
      db.customStatement(
        "UPDATE pengeluaran SET uuid = (SELECT uuid FROM pengeluaran WHERE id = $id) WHERE id = $other",
      ),
      throwsException,
    );
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });

  test(
    'SQL pagination and summary use identical filters and stable order',
    () async {
      final ids = <int>[];
      for (var i = 0; i < 12; i++) {
        ids.add(
          await repo.create(input(invoice: 'SERIE-${i + 1}', nominal: i + 1)),
        );
      }
      await repo.create(input(jenis: 2, note: 'transport'));
      await repo.create(input(date: DateTime(2031, 2, 4), note: 'Transport'));
      final day = DateTime(2031, 2, 3);
      Future<PengeluaranPage> page(int page) => repo
          .watchPage(
            filter(
              page: page,
              search: 'transport',
              jenis: 1,
              from: day,
              through: day,
            ),
          )
          .first;
      final first = await page(0);
      final second = await page(1);
      expect(first.rows.map((row) => row.id), ids.reversed.take(10));
      expect(second.rows.map((row) => row.id), ids.reversed.skip(10));
      expect(first.count, 12);
      expect(second.count, first.count);
      expect(second.total, BigInt.from(78));
      expect(first.total, second.total);
      expect(
        (await repo.watchPage(filter(search: 'serie-12')).first).rows.single.id,
        ids.last,
      );
      expect((await repo.watchPage(filter(search: '%')).first).rows, isEmpty);
      await repo.delete(ids.first);
      await repo.delete(ids[1]);
      expect((await page(1)).page, 0);
    },
  );

  test(
    'Drift stream refreshes on create and delete with exact large totals',
    () async {
      final pages = StreamIterator(repo.watchPage(filter()));
      addTearDown(pages.cancel);
      expect(await pages.moveNext(), isTrue);
      expect(pages.current.count, 0);
      const amount = 9223372036854775807;
      final first = await repo.create(input(nominal: amount));
      expect(await pages.moveNext(), isTrue);
      expect(pages.current.total, BigInt.from(amount));
      await repo.create(input(nominal: amount));
      expect(await pages.moveNext(), isTrue);
      expect(pages.current.total, BigInt.from(amount) * BigInt.two);
      await repo.delete(first);
      expect(await pages.moveNext(), isTrue);
      expect(pages.current.count, 1);
    },
  );
}
