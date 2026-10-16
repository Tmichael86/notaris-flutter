import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/repositories/pekerjaan_kategori_repository.dart';

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
