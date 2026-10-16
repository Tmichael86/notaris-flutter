import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/repositories/pengeluaran_jenis_repository.dart';

void main() {
  late AppDatabase database;
  late PengeluaranJenisRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = PengeluaranJenisRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('trims name when creating', () async {
    await repository.create(nama: '  ATK  ');

    final items = await repository.watchAll().first;

    expect(items.single.nama, 'ATK');
  });

  test('rejects empty name', () async {
    await expectLater(repository.create(nama: '   '), throwsArgumentError);
  });

  test('rejects duplicate names ignoring case and whitespace', () async {
    await repository.create(nama: 'ATK');

    await expectLater(repository.create(nama: '  atk  '), throwsArgumentError);
  });

  test('allows updating an item without changing its name', () async {
    final id = await repository.create(nama: 'ATK');

    expect(await repository.update(id: id, nama: 'ATK'), isTrue);
  });

  test('rejects updating to another active item name', () async {
    final firstId = await repository.create(nama: 'ATK');
    await repository.create(nama: 'Transportasi');

    await expectLater(
      repository.update(id: firstId, nama: 'TRANSPORTASI'),
      throwsArgumentError,
    );
  });

  test('allows reusing a name after soft delete', () async {
    final id = await repository.create(nama: 'ATK');

    expect(await repository.delete(id), isTrue);

    await repository.create(nama: 'ATK');

    final items = await repository.watchAll().first;
    expect(items, hasLength(1));
    expect(items.single.nama, 'ATK');
  });

  test('soft delete preserves row and marks it dirty', () async {
    final id = await repository.create(nama: 'ATK');

    expect(await repository.delete(id), isTrue);

    final row = await (database.select(
      database.pengeluaranJenis,
    )..where((t) => t.id.equals(id))).getSingle();

    expect(row.status, 0);
    expect(row.deletedAt, isNotNull);
    expect(row.isSyncDirty, isTrue);
  });
}
