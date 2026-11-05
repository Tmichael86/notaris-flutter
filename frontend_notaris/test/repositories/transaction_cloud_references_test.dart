import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/repositories/transaction_cloud_references.dart';
import 'package:frontend_notaris/repositories/transaction_repository.dart';

const applicant = '00000000-0000-4000-8000-000000000001';
const officer = '00000000-0000-4000-8000-000000000002';
const cloudOfficer = '00000000-0000-4000-8000-000000000003';
const job = '00000000-0000-4000-8000-000000000004';
const price = '00000000-0000-4000-8000-000000000005';
const category = '00000000-0000-4000-8000-000000000006';
const detail = '00000000-0000-4000-8000-000000000007';

void main() {
  for (final domain in ['notaris', 'ppat']) {
    group(domain, () {
      late AppDatabase db;
      late TransactionCloudReferences references;
      late int transactionId;
      setUp(() async {
        db = AppDatabase.forTesting(NativeDatabase.memory());
        references = TransactionCloudReferences(
          db,
          petugasScope: 'officer-scope',
          masterScope: 'master-scope',
        );
        await db.customStatement(
          'INSERT INTO pemohons(id,uuid,nama,is_sync_dirty,last_synced_at) VALUES(10,?,\'A\',0,1)',
          [applicant],
        );
        await db.customStatement(
          'INSERT INTO petugas(id,uuid,nama,email,is_sync_dirty) VALUES(20,?,\'O\',\'test@example.invalid\',0)',
          [officer],
        );
        await db.customStatement(
          "INSERT INTO petugas_identity_map(local_uuid,cloud_uuid,server_id,state,evidence,created_at,updated_at) VALUES(?,?,104,'server_only','authenticated baseline',1,1)",
          [officer, cloudOfficer],
        );
        await db.customStatement(
          "INSERT INTO petugas_sync_feed(id,scope,cursor) VALUES(1,'officer-scope',4)",
        );
        await db.customStatement(
          'INSERT INTO petugas_sync_journal(local_uuid,row_version) VALUES(?,1)',
          [officer],
        );
        await db.customStatement(
          "INSERT INTO pekerjaan_kategori(id,uuid,nama,is_sync_dirty) VALUES(30,?,'K',0)",
          [category],
        );
        await db.customStatement(
          "INSERT INTO pekerjaan_$domain(id,uuid,nama,is_sync_dirty) VALUES(40,?,'same name',0)",
          [job],
        );
        await db.customStatement(
          "INSERT INTO pekerjaan_${domain}_sync_identity(local_uuid,cloud_uuid,scope,revision) VALUES(?,?,'master-scope',1)",
          [job, job],
        );
        await db.customStatement(
          "INSERT INTO pekerjaan_${domain}_harga(id,uuid,pekerjaan_${domain}_id,kategori_pekerjaan_id,harga,estimasi_waktu,is_sync_dirty) VALUES(50,?,40,30,'100','1 hari',0)",
          [price],
        );
        transactionId = await TransactionRepository(db).save(
          nomorTransaksi: 'OFFLINE-ONLY',
          jenisTransaksi: domain,
          pemohonId: 10,
          pemohonUuid: applicant,
          petugasId: 20,
          petugasUuid: officer,
          status: 'Baru',
          tanggalTransaksi: DateTime(2026, 11, 5),
          pembayaranSekarang: 25,
          jobs: [
            TransactionJobInput(
              jenisPekerjaan: domain,
              namaPekerjaan: 'snapshot',
              pekerjaanNotarisId: domain == 'notaris' ? 40 : null,
              pekerjaanPpatId: domain == 'ppat' ? 40 : null,
              biayaLayanan: 100,
              detailUuid: detail,
              kategoriSnapshot: 'historical label',
              hargaUuid: price,
              kategoriUuid: category,
            ),
          ],
        );
      });
      tearDown(() async => db.close());
      Future<Map<String, dynamic>> prepare() => references.prepare(
        transactionId,
        selectedPriceUuids: {detail: price},
      );
      test('uses explicit cloud mapping and preserves local IDs, dirty state and payment', () async {
        final result = await prepare();
        expect(result['pemohon_uuid'], applicant);
        expect(result['petugas_uuid'], cloudOfficer);
        expect(result['jobs'], [
          {
            'detail_uuid': detail,
            'job_uuid': job,
            'price_uuid': price,
            'category_uuid': category,
          },
        ]);
        await prepare();
        final header = await TransactionRepository(db).findById(transactionId);
        expect(header!.petugasId, 20);
        expect(header.petugasUuid, officer);
        expect(header.isSyncDirty, true);
        expect(header.noAkta, 'OFFLINE-ONLY');
        expect(
          await TransactionRepository(db).getPaymentHistory(transactionId),
          hasLength(1),
        );
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        expect(
          (await db.customSelect('PRAGMA integrity_check').getSingle())
              .read<String>('integrity_check'),
          'ok',
        );
      });
      test('does not infer category from historical labels', () async {
        await db.customStatement(
          'UPDATE transaksi_details SET harga_uuid=NULL,kategori_uuid=NULL',
        );
        await expectLater(
          references.prepare(transactionId, selectedPriceUuids: {}),
          throwsStateError,
        );
        await expectLater(
          references.prepare(
            transactionId,
            selectedPriceUuids: {detail: category},
          ),
          throwsStateError,
        );
      });
      test('edit retains original price provenance and historical snapshot after Master changes', () async {
        await db.customStatement(
          "UPDATE pekerjaan_${domain}_harga SET harga='900',estimasi_waktu='changed'",
        );
        await TransactionRepository(db).save(
          id: transactionId,
          nomorTransaksi: 'OFFLINE-ONLY',
          jenisTransaksi: domain,
          pemohonId: 10,
          pemohonUuid: applicant,
          petugasId: 20,
          petugasUuid: officer,
          status: 'Baru',
          tanggalTransaksi: DateTime(2026, 11, 5),
          jobs: [
            TransactionJobInput(
              jenisPekerjaan: domain,
              namaPekerjaan: 'snapshot',
              pekerjaanNotarisId: domain == 'notaris' ? 40 : null,
              pekerjaanPpatId: domain == 'ppat' ? 40 : null,
              biayaLayanan: 100,
              detailUuid: detail,
              kategoriSnapshot: 'historical label',
            ),
          ],
        );
        final saved = await db.select(db.transaksiDetails).getSingle();
        expect(saved.hargaUuid, price);
        expect(saved.kategoriUuid, category);
        expect(saved.biayaLayanan, 100);
        expect(saved.kategoriSnapshot, 'historical label');
        expect(
          await TransactionRepository(db).getPaymentHistory(transactionId),
          hasLength(1),
        );
      });
      test(
        'wrong price/category provenance rolls back header and children',
        () async {
          await expectLater(
            TransactionRepository(db).save(
              id: transactionId,
              nomorTransaksi: 'MUST-ROLLBACK',
              jenisTransaksi: domain,
              pemohonId: 10,
              pemohonUuid: applicant,
              petugasId: 20,
              petugasUuid: officer,
              status: 'Baru',
              tanggalTransaksi: DateTime(2026, 11, 5),
              jobs: [
                TransactionJobInput(
                  jenisPekerjaan: domain,
                  namaPekerjaan: 'wrong',
                  pekerjaanNotarisId: domain == 'notaris' ? 40 : null,
                  pekerjaanPpatId: domain == 'ppat' ? 40 : null,
                  biayaLayanan: 100,
                  detailUuid: detail,
                  hargaUuid: price,
                  kategoriUuid: applicant,
                ),
              ],
            ),
            throwsStateError,
          );
          expect(
            (await TransactionRepository(db).findById(transactionId))!.noAkta,
            'OFFLINE-ONLY',
          );
          expect(
            (await db.select(db.transaksiDetails).getSingle()).kategoriUuid,
            category,
          );
        },
      );
      test('rejects dirty master or pending mutation', () async {
        await db.customStatement(
          'UPDATE pekerjaan_$domain SET is_sync_dirty=1',
        );
        await expectLater(prepare(), throwsStateError);
        await db.customStatement(
          'UPDATE pekerjaan_$domain SET is_sync_dirty=0',
        );
        await db.customStatement(
          "INSERT INTO pekerjaan_${domain}_sync_pending(local_uuid,mutation_id,payload,state) VALUES(?,'mutation','{}','pending')",
          [job],
        );
        await expectLater(prepare(), throwsStateError);
      });
      test('rejects wrong scope and unresolved officer journal', () async {
        await db.customStatement(
          "UPDATE petugas_sync_feed SET scope='other-device'",
        );
        await expectLater(prepare(), throwsStateError);
        await db.customStatement(
          "UPDATE petugas_sync_feed SET scope='officer-scope'",
        );
        await db.customStatement(
          "UPDATE petugas_sync_journal SET pending='{}'",
        );
        await expectLater(prepare(), throwsStateError);
      });
      test('rejects inactive category and unsynced applicant', () async {
        await db.customStatement('UPDATE pekerjaan_kategori SET status=0');
        await expectLater(prepare(), throwsStateError);
        await db.customStatement('UPDATE pekerjaan_kategori SET status=1');
        await db.customStatement('UPDATE pemohons SET is_sync_dirty=1');
        await expectLater(prepare(), throwsStateError);
      });
    });
  }
}
