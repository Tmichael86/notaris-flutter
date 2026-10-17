import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/repositories/pekerjaan_kategori_repository.dart';
import 'package:frontend_notaris/repositories/pekerjaan_repository.dart';

void main() {
  late AppDatabase database;
  late PekerjaanPpatRepository repository;
  late PekerjaanKategoriRepository kategoriRepository;
  late int kategoriId;

  PekerjaanAggregateInput validInput({
    String nama = 'Akta Jual Beli PPAT',
    int? categoryId,
    String harga = '1500000',
  }) {
    return PekerjaanAggregateInput(
      nama: nama,
      harga: [
        PekerjaanHargaInput(
          harga: harga,
          kategoriPekerjaanId: categoryId ?? kategoriId,
          estimasiWaktu: '7 hari kerja',
        ),
      ],
      proses: const [
        PekerjaanProsesInput(
          nama: 'Pemeriksaan Dokumen',
          detail: 'Memeriksa kelengkapan dokumen pemohon',
          atribut: [
            PekerjaanAtributInput(atribut: 'KTP'),
            PekerjaanAtributInput(atribut: 'Sertifikat'),
          ],
        ),
      ],
    );
  }

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = PekerjaanPpatRepository(database.pekerjaanDao);
    kategoriRepository = PekerjaanKategoriRepository(database);
    kategoriId = await kategoriRepository.create(nama: 'Jual Beli');
  });

  tearDown(() async {
    await database.close();
  });

  test('creates aggregate with price, process, and attributes', () async {
    final id = await repository.createAggregate(input: validInput());
    final aggregate = await repository.getAggregate(id);

    expect(aggregate, isNotNull);
    expect(aggregate!.nama, 'Akta Jual Beli PPAT');
    expect(aggregate.harga, hasLength(1));
    expect(aggregate.harga.single.harga, '1500000');
    expect(aggregate.proses, hasLength(1));
    expect(aggregate.proses.single.atribut, hasLength(2));
  });

  test('trims the work name when creating', () async {
    final id = await repository.createAggregate(
      input: validInput(nama: '  Akta Jual Beli PPAT  '),
    );
    final aggregate = await repository.getAggregate(id);

    expect(aggregate!.nama, 'Akta Jual Beli PPAT');
  });

  test('rejects an empty work name', () async {
    await expectLater(
      repository.createAggregate(input: validInput(nama: '   ')),
      throwsArgumentError,
    );
  });

  test('rejects an empty price list', () async {
    await expectLater(
      repository.createAggregate(
        input: PekerjaanAggregateInput(
          nama: 'Akta Jual Beli PPAT',
          proses: validInput().proses,
        ),
      ),
      throwsArgumentError,
    );
  });

  test('rejects a non-positive price', () async {
    await expectLater(
      repository.createAggregate(input: validInput(harga: '0')),
      throwsArgumentError,
    );
  });

  test('rejects duplicate categories in the same aggregate', () async {
    await expectLater(
      repository.createAggregate(
        input: PekerjaanAggregateInput(
          nama: 'Akta Jual Beli PPAT',
          harga: [
            PekerjaanHargaInput(
              harga: '1000000',
              kategoriPekerjaanId: kategoriId,
              estimasiWaktu: '5 hari',
            ),
            PekerjaanHargaInput(
              harga: '2000000',
              kategoriPekerjaanId: kategoriId,
              estimasiWaktu: '7 hari',
            ),
          ],
          proses: validInput().proses,
        ),
      ),
      throwsArgumentError,
    );
  });

  test('rejects a process with an empty name', () async {
    await expectLater(
      repository.createAggregate(
        input: PekerjaanAggregateInput(
          nama: 'Akta Jual Beli PPAT',
          harga: validInput().harga,
          proses: const [
            PekerjaanProsesInput(nama: '   ', detail: 'Detail proses'),
          ],
        ),
      ),
      throwsArgumentError,
    );
  });

  test('rejects a process with empty detail', () async {
    await expectLater(
      repository.createAggregate(
        input: PekerjaanAggregateInput(
          nama: 'Akta Jual Beli PPAT',
          harga: validInput().harga,
          proses: const [
            PekerjaanProsesInput(
              nama: 'Pemeriksaan Dokumen',
              detail: '   ',
            ),
          ],
        ),
      ),
      throwsArgumentError,
    );
  });

  test('updates aggregate while preserving existing child IDs', () async {
    final id = await repository.createAggregate(input: validInput());
    final before = (await repository.getAggregate(id))!;

    final updated = await repository.updateAggregate(
      id: id,
      input: PekerjaanAggregateInput(
        nama: 'Akta Jual Beli PPAT Revisi',
        harga: [
          PekerjaanHargaInput(
            id: before.harga.single.id,
            harga: '1750000',
            kategoriPekerjaanId: kategoriId,
            estimasiWaktu: '8 hari kerja',
          ),
        ],
        proses: [
          PekerjaanProsesInput(
            id: before.proses.single.id,
            nama: 'Pemeriksaan Dokumen Revisi',
            detail: 'Pemeriksaan dokumen yang diperbarui',
            atribut: [
              PekerjaanAtributInput(
                id: before.proses.single.atribut.first.id,
                atribut: 'KTP terbaru',
              ),
            ],
          ),
        ],
      ),
    );

    expect(updated, isTrue);

    final after = (await repository.getAggregate(id))!;
    expect(after.nama, 'Akta Jual Beli PPAT Revisi');
    expect(after.harga.single.id, before.harga.single.id);
    expect(after.harga.single.harga, '1750000');
    expect(after.proses.single.id, before.proses.single.id);
    expect(
      after.proses.single.atribut.single.id,
      before.proses.single.atribut.first.id,
    );
    expect(after.proses.single.atribut.single.atribut, 'KTP terbaru');
  });

  test('rejects updating with another work item price ID', () async {
    final firstId = await repository.createAggregate(
      input: validInput(nama: 'Pekerjaan PPAT Pertama'),
    );
    final secondId = await repository.createAggregate(
      input: validInput(
        nama: 'Pekerjaan PPAT Kedua',
        harga: '2500000',
      ),
    );
    final second = (await repository.getAggregate(secondId))!;

    await expectLater(
      repository.updateAggregate(
        id: firstId,
        input: PekerjaanAggregateInput(
          nama: 'Pekerjaan PPAT Pertama',
          harga: [
            PekerjaanHargaInput(
              id: second.harga.single.id,
              harga: '9999999',
              kategoriPekerjaanId: kategoriId,
              estimasiWaktu: '1 hari',
            ),
          ],
          proses: validInput().proses,
        ),
      ),
      throwsArgumentError,
    );

    final unchanged = (await repository.getAggregate(secondId))!;
    expect(unchanged.harga.single.harga, '2500000');
  });

  test('rejects updating with another work item process ID', () async {
    final firstId = await repository.createAggregate(
      input: validInput(nama: 'Pekerjaan PPAT Pertama'),
    );
    final secondId = await repository.createAggregate(
      input: validInput(nama: 'Pekerjaan PPAT Kedua'),
    );
    final second = (await repository.getAggregate(secondId))!;

    await expectLater(
      repository.updateAggregate(
        id: firstId,
        input: PekerjaanAggregateInput(
          nama: 'Pekerjaan PPAT Pertama',
          harga: validInput().harga,
          proses: [
            PekerjaanProsesInput(
              id: second.proses.single.id,
              nama: 'Proses asing',
              detail: 'Tidak boleh dipakai pada pekerjaan pertama',
            ),
          ],
        ),
      ),
      throwsArgumentError,
    );

    final unchanged = (await repository.getAggregate(secondId))!;
    expect(unchanged.proses.single.nama, 'Pemeriksaan Dokumen');
  });

  test('rejects an attribute ID owned by another process', () async {
    final firstId = await repository.createAggregate(
      input: validInput(nama: 'Pekerjaan PPAT Pertama'),
    );
    final secondId = await repository.createAggregate(
      input: validInput(nama: 'Pekerjaan PPAT Kedua'),
    );
    final first = (await repository.getAggregate(firstId))!;
    final second = (await repository.getAggregate(secondId))!;

    await expectLater(
      repository.updateAggregate(
        id: firstId,
        input: PekerjaanAggregateInput(
          nama: 'Pekerjaan PPAT Pertama',
          harga: validInput().harga,
          proses: [
            PekerjaanProsesInput(
              id: first.proses.single.id,
              nama: first.proses.single.nama,
              detail: first.proses.single.detail,
              atribut: [
                PekerjaanAtributInput(
                  id: second.proses.single.atribut.first.id,
                  atribut: 'Atribut asing',
                ),
              ],
            ),
          ],
        ),
      ),
      throwsArgumentError,
    );

    final unchanged = (await repository.getAggregate(secondId))!;
    expect(unchanged.proses.single.atribut.first.atribut, 'KTP');
  });

  test('soft-deletes the aggregate and its active children', () async {
    final id = await repository.createAggregate(input: validInput());
    final before = (await repository.getAggregate(id))!;

    expect(await repository.deleteAggregate(id), isTrue);
    expect(await repository.getAggregate(id), isNull);

    final parent = await (database.select(
      database.pekerjaanPpatLocals,
    )..where((t) => t.id.equals(id))).getSingle();
    final price = await (database.select(
      database.pekerjaanPpatHargaLocals,
    )..where((t) => t.id.equals(before.harga.single.id))).getSingle();
    final process = await (database.select(
      database.pekerjaanPpatProsesLocals,
    )..where((t) => t.id.equals(before.proses.single.id))).getSingle();
    final attributeId = before.proses.single.atribut.first.id;
    final attribute = await (database.select(
      database.pekerjaanPpatAtributLocals,
    )..where((t) => t.id.equals(attributeId))).getSingle();

    expect(parent.status, 0);
    expect(parent.deletedAt, isNotNull);
    expect(parent.isSyncDirty, isTrue);
    expect(price.status, 0);
    expect(price.deletedAt, isNotNull);
    expect(price.isSyncDirty, isTrue);
    expect(process.status, 0);
    expect(process.deletedAt, isNotNull);
    expect(process.isSyncDirty, isTrue);
    expect(attribute.status, 0);
    expect(attribute.deletedAt, isNotNull);
    expect(attribute.isSyncDirty, isTrue);
  });
}
