import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/repositories/people_repository.dart';

void main() {
  late AppDatabase database;
  late PemohonRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = PemohonRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('trims name when creating', () async {
    await repository.create(nama: '  Budi Santoso  ');

    final items = await repository.watchAll().first;

    expect(items.single.nama, 'Budi Santoso');
  });

  test('rejects empty name', () {
    expect(() => repository.create(nama: '   '), throwsArgumentError);
  });

  test('normalizes optional blank fields to null', () async {
    await repository.create(
      nama: 'Budi Santoso',
      alamat: '  ',
      noTelp: '  ',
      nik: '  ',
    );

    final item = (await repository.watchAll().first).single;

    expect(item.alamat, isNull);
    expect(item.noTelp, isNull);
    expect(item.nik, isNull);
  });

  test('trims name during update and marks row dirty', () async {
    final id = await repository.create(nama: 'Budi Santoso');

    expect(await repository.update(id: id, nama: '  Budi Baru  '), isTrue);

    final item = (await repository.watchAll().first).single;

    expect(item.nama, 'Budi Baru');
    expect(item.isSyncDirty, isTrue);
  });

  test('rejects empty name during update', () async {
    final id = await repository.create(nama: 'Budi Santoso');

    await expectLater(
      repository.update(id: id, nama: '  '),
      throwsArgumentError,
    );
  });

  test('soft delete preserves row and marks it dirty', () async {
    final id = await repository.create(nama: 'Budi Santoso');

    expect(await repository.delete(id), isTrue);

    final row = await (database.select(
      database.pemohons,
    )..where((t) => t.id.equals(id))).getSingle();

    expect(row.status, 0);
    expect(row.deletedAt, isNotNull);
    expect(row.updatedAt, row.deletedAt);
    expect(row.isSyncDirty, isTrue);

    expect(await repository.watchAll().first, isEmpty);
  });

  test('cannot update or delete an already deleted pemohon', () async {
    final id = await repository.create(nama: 'Budi Santoso');

    await repository.delete(id);

    expect(await repository.update(id: id, nama: 'Budi Baru'), isFalse);
    expect(await repository.delete(id), isFalse);
  });

  test('cannot update or delete a row marked inactive', () async {
    final id = await repository.create(nama: 'Budi Santoso');

    await (database.update(database.pemohons)..where((t) => t.id.equals(id)))
        .write(const PemohonsCompanion(status: Value(0)));

    expect(await repository.update(id: id, nama: 'Budi Baru'), isFalse);
    expect(await repository.delete(id), isFalse);
  });
}
