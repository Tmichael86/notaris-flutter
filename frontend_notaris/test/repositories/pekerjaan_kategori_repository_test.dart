import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/repositories/pekerjaan_kategori_repository.dart';
import 'package:frontend_notaris/services/kategori_pekerjaan_api_service.dart';

void main() {
  late AppDatabase database;
  late PekerjaanKategoriRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = PekerjaanKategoriRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('syncs cloud categories into the local cache by UUID', () async {
    await repository.syncFromCloud([
      const KategoriPekerjaanApiModel(
        id: 101,
        uuid: '11111111-1111-4111-8111-111111111111',
        nama: 'Akta Cloud',
      ),
    ]);

    final categories = await repository.watchAll().first;
    expect(categories, hasLength(1));
    expect(categories.single.uuid, '11111111-1111-4111-8111-111111111111');
    expect(categories.single.nama, 'Akta Cloud');
    expect(categories.single.isSyncDirty, isFalse);
    expect(categories.single.lastSyncedAt, isNotNull);
  });

  test('cloud refresh does not overwrite a locally dirty category', () async {
    const sharedUuid = '11111111-1111-4111-8111-111111111111';
    final id = await database.into(database.pekerjaanKategoris).insert(
      PekerjaanKategorisCompanion.insert(
        uuid: sharedUuid,
        nama: 'Nama Lokal',
        isSyncDirty: Value(true),
      ),
    );

    await repository.syncFromCloud([
      const KategoriPekerjaanApiModel(
        id: 102,
        uuid: sharedUuid,
        nama: 'Nama Cloud',
      ),
      const KategoriPekerjaanApiModel(
        id: 103,
        uuid: '22222222-2222-4222-8222-222222222222',
        nama: 'Kategori Baru',
      ),
    ]);

    final local = await (database.select(database.pekerjaanKategoris)
      ..where((t) => t.id.equals(id))).getSingle();
    final categories = await repository.watchAll().first;

    expect(local.nama, 'Nama Lokal');
    expect(local.isSyncDirty, isTrue);
    expect(categories.map((item) => item.nama), contains('Kategori Baru'));
    expect(categories.map((item) => item.nama), isNot(contains('Nama Cloud')));
  });

  test('rejects cloud categories without a UUID', () async {
    await expectLater(
      repository.syncFromCloud([
        const KategoriPekerjaanApiModel(id: 104, nama: 'No UUID'),
      ]),
      throwsA(isA<FormatException>()),
    );
  });

  test('trims category name when creating', () async {
    final id = await repository.create(nama: '  Akta Tanah  ');

    final categories = await repository.watchAll().first;

    expect(id, greaterThan(0));
    expect(categories.single.nama, 'Akta Tanah');
  });

  test('rejects an empty category name', () async {
    await expectLater(repository.create(nama: '   '), throwsArgumentError);
  });

  test('rejects duplicate names ignoring case and outer whitespace', () async {
    await repository.create(nama: 'Akta Tanah');

    await expectLater(
      repository.create(nama: '  AKTA TANAH  '),
      throwsArgumentError,
    );
  });

  test('allows updating a category without changing its name', () async {
    final id = await repository.create(nama: 'Akta Tanah');

    final updated = await repository.update(id: id, nama: 'Akta Tanah');

    expect(updated, isTrue);

    final categories = await repository.watchAll().first;
    expect(categories.single.nama, 'Akta Tanah');
  });

  test('rejects updating to another active category name', () async {
    final firstId = await repository.create(nama: 'Akta Tanah');
    await repository.create(nama: 'Surat Kuasa');

    await expectLater(
      repository.update(id: firstId, nama: 'SURAT KUASA'),
      throwsArgumentError,
    );
  });

  test('allows reusing a name after soft delete', () async {
    final id = await repository.create(nama: 'Akta Tanah');

    expect(await repository.delete(id), isTrue);

    await repository.create(nama: 'Akta Tanah');

    final categories = await repository.watchAll().first;
    expect(categories, hasLength(1));
    expect(categories.single.nama, 'Akta Tanah');
  });

  test('soft delete preserves the row and marks it dirty', () async {
    final id = await repository.create(nama: 'Akta Tanah');

    expect(await repository.delete(id), isTrue);

    final row = await (database.select(
      database.pekerjaanKategoris,
    )..where((t) => t.id.equals(id))).getSingle();

    expect(row.status, 0);
    expect(row.deletedAt, isNotNull);
    expect(row.isSyncDirty, isTrue);
  });
}
