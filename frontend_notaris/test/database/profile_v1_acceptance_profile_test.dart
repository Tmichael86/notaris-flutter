import '../support/local_master_test_authority.dart';

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/repositories/pekerjaan_repository.dart';
import 'package:frontend_notaris/repositories/transaction_repository.dart';
import 'package:frontend_notaris/profile_v1_acceptance_main.dart';
import 'package:uuid/uuid.dart';

import '../support/materai_stock_fixture.dart' show seedMateraiOpening;

void main() {
  final id = Platform.environment['NOTARIS_PROFILE_V1_PREPARE'];
  test('fresh v27 Profile acceptance protects operational fixture with no SQLite Users', () async {
    final root = profileV1AcceptanceRoot(id!);
    final file = await File('${root.path}/offline.sqlite')
        .create(exclusive: true);
    final db = MateraiProfileDatabase(
      NativeDatabase(file, setup: (d) => d.execute('PRAGMA foreign_keys=ON')),
    );
    const uuid = Uuid();
    try {
      await seedMateraiOpening(db, id: id);
      final officerUuid = uuid.v4();
      final officer = await db
          .into(db.petugasLocals)
          .insert(
            PetugasLocalsCompanion.insert(
              uuid: officerUuid,
              nama: 'Rani Uji',
              email: 'officer@example.invalid',
            ),
          );
      for (final (index, domain) in ['notaris', 'ppat'].indexed) {
        final applicantUuid = uuid.v4();
        final applicant = await db
            .into(db.pemohons)
            .insert(
              PemohonsCompanion.insert(
                uuid: applicantUuid,
                nama: index == 0 ? 'Bagas Uji' : 'Laras Uji',
              ),
            );
        final category = await db
            .into(db.pekerjaanKategoris)
            .insert(
              PekerjaanKategorisCompanion.insert(
                uuid: uuid.v4(),
                nama: 'Kategori Uji $domain',
              ),
            );
        final input = PekerjaanAggregateInput(
          nama: 'Pekerjaan Uji $domain',
          harga: [
            PekerjaanHargaInput(
              harga: '2500000',
              kategoriPekerjaanId: category,
              estimasiWaktu: '3 hari',
            ),
          ],
          proses: const [
            PekerjaanProsesInput(nama: 'Pemeriksaan', detail: 'Berkas fiktif'),
          ],
        );
        final notaris = domain == 'notaris';
        final job = notaris
            ? await PekerjaanNotarisRepository(
                db.pekerjaanDao,
                authorization: masterTestAuthority(db),
              ).createAggregate(input: input)
            : await PekerjaanPpatRepository(
                db.pekerjaanDao,
                authorization: masterTestAuthority(db),
              ).createAggregate(input: input);
        await TransactionRepository(db).save(
          nomorTransaksi: '${index + 1}001911260001',
          jenisTransaksi: domain,
          pemohonId: applicant,
          pemohonUuid: applicantUuid,
          petugasId: officer,
          petugasUuid: officerUuid,
          status: 'Dalam Proses',
          tanggalTransaksi: DateTime(2026, 11, 19),
          pembayaranSekarang: 500000,
          jobs: [
            TransactionJobInput(
              detailUuid: uuid.v4(),
              jenisPekerjaan: domain,
              pekerjaanNotarisId: notaris ? job : null,
              pekerjaanPpatId: notaris ? null : job,
              namaPekerjaan: input.nama,
              kategoriSnapshot: 'Kategori Uji $domain',
              biayaLayanan: 2500000,
              prosesSnapshot:
                  '[{"id":"1","name":"Pemeriksaan","attributes":[]}]',
            ),
          ],
        );
      }
      expect(
        (await db.customSelect('PRAGMA user_version').getSingle())
            .data
            .values
            .single,
        27,
      );
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      expect(
        (await db.customSelect('PRAGMA integrity_check').getSingle())
            .data
            .values
            .single,
        'ok',
      );
      expect(
        (await db
                .customSelect(
                  "SELECT count(*) AS n FROM sqlite_master WHERE type='table' AND name='users'",
                )
                .getSingle())
            .read<int>('n'),
        0,
      );
    } finally {
      await db.close();
    }
  }, skip: id == null);
}
