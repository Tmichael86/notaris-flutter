import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/repositories/people_repository.dart';

void main() {
  late AppDatabase database;
  late PetugasRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = PetugasRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('trims required name and email when creating', () async {
    await repository.create(
      nama: '  Budi Santoso  ',
      email: '  budi@example.com  ',
    );

    final items = await repository.watchAll().first;

    expect(items.single.nama, 'Budi Santoso');
    expect(items.single.email, 'budi@example.com');
  });

  test('rejects empty name', () async {
    await expectLater(
      repository.create(nama: '  ', email: 'budi@example.com'),
      throwsArgumentError,
    );
  });

  test('rejects empty email', () async {
    await expectLater(
      repository.create(nama: 'Budi Santoso', email: '  '),
      throwsArgumentError,
    );
  });

  test('normalizes optional blank fields to null', () async {
    await repository.create(
      nama: 'Budi Santoso',
      email: 'budi@example.com',
      nik: '  ',
      alamat: '  ',
      tempatLahir: '  ',
      noTelp: '  ',
    );

    final items = await repository.watchAll().first;
    final item = items.single;

    expect(item.nik, isNull);
    expect(item.alamat, isNull);
    expect(item.tempatLahir, isNull);
    expect(item.noTelp, isNull);
  });

  test('rejects empty name during update', () async {
    final id = await repository.create(
      nama: 'Budi Santoso',
      email: 'budi@example.com',
    );

    await expectLater(
      repository.update(id: id, nama: ' ', email: 'budi@example.com'),
      throwsArgumentError,
    );
  });

  test('soft delete preserves row and marks it dirty', () async {
    final id = await repository.create(
      nama: 'Budi Santoso',
      email: 'budi@example.com',
    );

    expect(await repository.delete(id), isTrue);

    final row = await (database.select(
      database.petugasLocals,
    )..where((t) => t.id.equals(id))).getSingle();

    expect(row.status, 0);
    expect(row.deletedAt, isNotNull);
    expect(row.updatedAt, row.deletedAt);
    expect(row.isSyncDirty, isTrue);

    final activeItems = await repository.watchAll().first;
    expect(activeItems, isEmpty);
  });

  test('cannot update or delete an already deleted petugas', () async {
    final id = await repository.create(
      nama: 'Budi Santoso',
      email: 'budi@example.com',
    );

    await repository.delete(id);

    expect(
      await repository.update(
        id: id,
        nama: 'Budi Baru',
        email: 'budi@example.com',
      ),
      isFalse,
    );

    expect(await repository.delete(id), isFalse);
  });
}
