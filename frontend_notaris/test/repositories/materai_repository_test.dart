import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/repositories/materai_repository.dart';

import '../support/materai_fixture.dart';

const noFilter = (
  from: null as String?,
  through: null as String?,
  officer: null as String?,
  search: '',
);

void main() {
  late MateraiProfileDatabase db;
  late MateraiRepository repo;

  setUp(() {
    db = MateraiProfileDatabase(NativeDatabase.memory());
    repo = MateraiRepository(db, materaiReader);
  });
  tearDown(() async => db.close());

  test(
    'unimported profiles are empty, including profiles predating v27',
    () async {
      final ordinary = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(ordinary.close);
      for (final reader in [repo, MateraiRepository(ordinary, materaiReader)]) {
        final report = await reader.read();
        expect(report.imported, isFalse);
        expect(report.movements, isEmpty);
      }
    },
  );

  test(
    'query_only, idempotency, provenance, inactive and shared PPAT movement',
    () async {
      await seedMaterai(db);
      await db.customStatement('PRAGMA query_only=ON');
      final changes = await db
          .customSelect('SELECT total_changes() AS n')
          .getSingle();
      final report = await repo.read();
      expect(
        report.verified.map((row) => row.sourceId),
        List.generate(12, (i) => 12 - i),
      );
      expect(report.review.single.sourceId, 13);
      expect(
        report.review.single.review,
        contains('Saldo tercatat tidak cocok'),
      );
      expect(report.verified.first.recordedStock, 8);
      expect(report.verified.last.stockIn, 20);
      expect(report.verified.fold(0, (sum, row) => sum + row.stockOut!), 12);
      expect(
        report.verified.where((row) => row.sourceId == 2).single.stockOut,
        2,
      );
      final row = await db
          .customSelect(
            'SELECT provenance_json,payload_sha256 FROM materai_movements WHERE source_id=2',
          )
          .getSingle();
      final provenance = jsonDecode(row.read<String>('provenance_json')) as Map;
      expect(provenance['kind'], 'synthetic_fixture');
      expect(provenance['transaksi_materai.transaksi_id'], [51, 52]);
      expect(
        row.read<String>('payload_sha256'),
        matches(RegExp(r'^[a-f0-9]{64}$')),
      );
      expect(
        (await db.customSelect('SELECT total_changes() AS n').getSingle()).data,
        changes.data,
      );
    },
  );

  test('baseline stock and ordering must be proven and bad source data stays review-only', () async {
    await loadSyntheticMaterai(db, 'opening', [movement(1)]);
    await loadSyntheticMaterai(db, 'problem', [
      movement(1, stockIn: 20),
      movement(
        2,
        previousId: 1,
        date: '2026-11-07',
        createdAt: '2026-11-16T08:00:00Z',
      ),
      movement(
        3,
        previousId: 12,
        date: '2026-02-30',
        stockIn: 1.5,
        stock: -1,
        officer: 99,
        transactions: [1, 1],
      ),
      movement(4, previousId: 3, date: null, createdAt: null, status: null),
      movement(5, previousId: 4, status: 0),
      movement(6, previousId: 5),
    ], opening: 0);
    final report = await repo.read();
    expect(report.verified.single.sourceId, 1);
    final review = [for (final row in report.review) row.review!].join('\n');
    for (final reason in [
      'Saldo pembuka',
      'Tanggal mundur',
      'Celah urutan',
      'Kuantitas atau stok',
      'Referensi Petugas',
      'Urutan pencatatan',
      'Tanggal bisnis',
      'Referensi transaksi',
      'Status sumber',
    ]) {
      expect(review, contains(reason));
    }
    expect(report.movements.any((row) => row.sourceId == 5), isFalse);
    expect(
      report.review.where((row) => row.businessDate == null),
      hasLength(2),
    );
  });

  test(
    'missing/duplicate source IDs and changed snapshots abort without writes',
    () async {
      for (final rows in [
        [movement(null)],
        [movement(1), movement(1)],
      ]) {
        await expectLater(
          loadSyntheticMaterai(db, 'bad', rows),
          throwsStateError,
        );
      }
      expect((await repo.read()).movements, isEmpty);
      await loadSyntheticMaterai(db, 'same', [
        movement(1, stockIn: 20),
      ], opening: 0);
      await expectLater(
        loadSyntheticMaterai(db, 'same', [
          movement(1, stockIn: 20, description: 'Changed'),
        ], opening: 0),
        throwsStateError,
      );
      await expectLater(
        loadSyntheticMaterai(db, 'same', [
          movement(1, stockIn: 20, status: 0),
        ], opening: 0),
        throwsStateError,
      );
      expect((await repo.read()).verified.single.description, 'Mutasi uji');
    },
  );

  test(
    'inclusive business dates, officer identity, search, stable page and reset',
    () async {
      await seedMaterai(db);
      final report = await repo.read();
      final single = report.filtered((
        from: '2026-11-09',
        through: '2026-11-09',
        officer: 'synthetic:acceptance:2',
        search: 'ppat',
      ));
      expect(single.verified.single.sourceId, 2);
      expect(
        report
            .filtered((
              from: '2026-11-08',
              through: '2026-11-09',
              officer: null,
              search: '',
            ))
            .verified
            .map((row) => row.sourceId),
        [2, 1],
      );
      expect(report.officers.values, unorderedEquals(demoOfficers.values));
      expect(
        report
            .filtered(noFilter)
            .verified
            .skip(MateraiReport.pageSize)
            .map((row) => row.sourceId),
        [2, 1],
      );
    },
  );

  test(
    'wrong code, inactive access and missing read denied with no role bypass',
    () async {
      for (final denied in [
        null,
        materaiReader(code: 'materai'),
        materaiReader(code: 'laporan-materai'),
        materaiReader(active: 0),
        materaiReader(read: 0),
      ]) {
        await expectLater(
          MateraiRepository(db, () => denied).read(),
          throwsStateError,
        );
      }
    },
  );
}
