import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/repositories/pekerjaan_repository.dart';
import 'package:frontend_notaris/repositories/transaction_repository.dart';

/// Offline preparation only. No Dio, HTTP client, publisher or coordinator.
void main() {
  final rootPath = Platform.environment['TRANSACTION_CONTROLLED_ROOT'];
  if (rootPath == null) {
    test(
      'controlled transaction preparation requires explicit receipt',
      () {},
      skip: true,
    );
    return;
  }
  if (Platform.environment['TRANSACTION_CONTROLLED_MODE'] != 'prepare') {
    throw StateError(
      'This entry only prepares disposable fixtures; live execution requires separate approval',
    );
  }
  final root = Directory(rootPath).resolveSymbolicLinksSync();
  if (!root.startsWith(
        '${Directory.current.parent.path}${Platform.pathSeparator}.local${Platform.pathSeparator}',
      ) ||
      root.contains('AppData')) {
    throw StateError('Owned disposable receipt required');
  }
  test('prepare two new disposable devices and exact fixture allowlist', () async {
    final refs = jsonDecode(
      await File('$root/references.json').readAsString(),
    ) as Map<String, dynamic>;
    final aFile = File('$root/device-a.sqlite'),
        bFile = File('$root/device-b.sqlite');
    if (aFile.existsSync() || bFile.existsSync()) {
      throw StateError('Never reuse existing device files');
    }
    final a = AppDatabase.forTesting(NativeDatabase(aFile)),
        b = AppDatabase.forTesting(NativeDatabase(bFile));
    const uuid = Uuid();
    final label = 'E2E-TX-${uuid.v4().substring(0, 8)}';
    final devices = <String, Map<String, dynamic>>{};
    try {
      for (final entry in {'a': a, 'b': b}.entries) {
        final db = entry.value;
        final scope = jsonEncode([
          'http://127.0.0.1:8081/api/v1',
          'notarisdev',
          2001,
          label,
          entry.key,
          entry.key == 'a' ? aFile.path : bFile.path,
        ]);
        final officerUuid = uuid.v4();
        await db.customStatement(
          "INSERT INTO pemohons(id,uuid,nama,status,is_sync_dirty,last_synced_at) VALUES(1,?,'Reviewed server UUID',1,0,1)",
          [refs['pemohon']['uuid']],
        );
        await db.customStatement(
          "INSERT INTO petugas(id,uuid,nama,email,status,is_sync_dirty) VALUES(1,?,'Reviewed officer UUID','synthetic@example.invalid',1,0)",
          [officerUuid],
        );
        await db.customStatement(
          "INSERT INTO petugas_identity_map(local_uuid,cloud_uuid,server_id,state,evidence,created_at,updated_at) VALUES(?,?,?,'server_only','reviewed read-only development catalog',1,1)",
          [officerUuid, refs['petugas']['uuid'], refs['petugas']['id']],
        );
        await db.customStatement(
          'INSERT INTO petugas_sync_feed(id,scope,cursor) VALUES(1,?,0)',
          ['$scope/petugas'],
        );
        await db.customStatement(
          'INSERT INTO petugas_sync_journal(local_uuid,row_version) VALUES(?,?)',
          [officerUuid, refs['petugas']['row_version']],
        );
        await db.customStatement(
          "INSERT INTO pekerjaan_kategori(id,uuid,nama,status,is_sync_dirty,last_synced_at) VALUES(1,?,'Reviewed cloud category',1,0,1)",
          [refs['category']['uuid']],
        );
        for (final domain in ['notaris', 'ppat']) {
          await db.customStatement(
            'INSERT INTO pekerjaan_${domain}_sync_feed(scope,cursor) VALUES(?,?)',
            ['$scope/masters', refs['masters'][domain]['last_seq']],
          );
        }
        await db.customStatement(
          'INSERT INTO transaction_cloud_feed(scope,cursor) VALUES(?,?)',
          ['$scope/transactions', refs['transactions']['last_seq']],
        );
        devices[entry.key] = {
          'path': entry.key == 'a' ? aFile.path : bFile.path,
          'scope': scope,
          'officer_local_uuid': officerUuid,
        };
      }
      final entities = <String, dynamic>{};
      final events = <Map<String, dynamic>>[];
      var txCursor = refs['transactions']['last_seq'] as int;
      for (final domain in ['notaris', 'ppat']) {
        final input = PekerjaanAggregateInput(
          nama: '$label-${domain.toUpperCase()}',
          harga: const [
            PekerjaanHargaInput(
              harga: '100000',
              kategoriPekerjaanId: 1,
              estimasiWaktu: '2 hari',
            ),
          ],
          proses: const [
            PekerjaanProsesInput(
              nama: 'Periksa sintetis',
              detail: 'Controlled fixture',
              atribut: [PekerjaanAtributInput(atribut: 'KTP sintetis')],
            ),
          ],
        );
        final masterId = domain == 'notaris'
            ? await PekerjaanNotarisRepository(a.pekerjaanDao)
                  .createAggregate(input: input)
            : await PekerjaanPpatRepository(a.pekerjaanDao)
                  .createAggregate(input: input);
        final parent =
            (await a
                    .customSelect(
                      'SELECT uuid FROM pekerjaan_$domain WHERE id=$masterId',
                    )
                    .getSingle())
                .read<String>('uuid');
        final price =
            (await a
                    .customSelect(
                      'SELECT uuid FROM pekerjaan_${domain}_harga WHERE pekerjaan_${domain}_id=$masterId',
                    )
                    .getSingle())
                .read<String>('uuid');
        final process =
            (await a
                    .customSelect(
                      'SELECT uuid FROM pekerjaan_${domain}_proses WHERE pekerjaan_${domain}_id=$masterId',
                    )
                    .getSingle())
                .read<String>('uuid');
        final attribute =
            (await a
                    .customSelect(
                      'SELECT uuid FROM pekerjaan_${domain}_atributs WHERE pekerjaan_${domain}_id=$masterId',
                    )
                    .getSingle())
                .read<String>('uuid');
        final detail = uuid.v4();
        final txId = await TransactionRepository(a).save(
          nomorTransaksi: 'OFFLINE-$label-$domain',
          jenisTransaksi: domain,
          pemohonId: 1,
          pemohonUuid: refs['pemohon']['uuid'] as String,
          petugasId: 1,
          petugasUuid: devices['a']!['officer_local_uuid'] as String,
          status: 'Baru',
          tanggalTransaksi: DateTime.utc(2020, 1, 1),
          pembayaranSekarang: 25000,
          jobs: [
            TransactionJobInput(
              jenisPekerjaan: domain,
              namaPekerjaan: input.nama,
              pekerjaanNotarisId: domain == 'notaris' ? masterId : null,
              pekerjaanPpatId: domain == 'ppat' ? masterId : null,
              hargaUuid: price,
              kategoriUuid: refs['category']['uuid'] as String,
              detailUuid: detail,
              biayaLayanan: 100000,
              kategoriSnapshot: 'Reviewed cloud category',
              estimasiWaktuSnapshot: '2 hari',
              prosesSnapshot: jsonEncode([
                {
                  'id': process,
                  'name': 'Periksa sintetis',
                  'status': 'Belum Valid',
                  'attributes': ['KTP sintetis'],
                },
              ]),
            ),
          ],
        );
        final tx = (await TransactionRepository(a).findById(txId))!;
        final txProcess =
            (await a
                    .customSelect(
                      'SELECT uuid FROM transaksi_proses WHERE transaksi_id=$txId',
                    )
                    .getSingle())
                .read<String>('uuid');
        final payment = (await TransactionRepository(a).getPaymentHistory(txId))
            .single;
        entities[domain] = {
          'master_local_id': masterId,
          'master_uuid': parent,
          'price_uuid': price,
          'process_uuid': process,
          'attribute_uuid': attribute,
          'transaction_local_id': txId,
          'transaction_uuid': tx.uuid,
          'detail_uuid': detail,
          'transaction_process_uuid': txProcess,
          'payment_uuid': payment.uuid,
          'name': input.nama,
        };
        final masterCursor = refs['masters'][domain]['last_seq'] as int;
        events.add({
          'kind': 'master',
          'domain': domain,
          'uuid': parent,
          'operation': 'create',
          'revision': 1,
          'expected_last_seq': masterCursor,
        });
        for (final operation in ['create', 'update', 'delete']) {
          events.add({
            'kind': 'transaction',
            'domain': domain,
            'uuid': tx.uuid,
            'operation': operation,
            'revision': ['create', 'update', 'delete'].indexOf(operation) + 1,
            'expected_last_seq': txCursor++,
          });
        }
        events.add({
          'kind': 'master',
          'domain': domain,
          'uuid': parent,
          'operation': 'delete',
          'revision': 2,
          'expected_last_seq': masterCursor + 1,
        });
      }
      for (final db in [a, b]) {
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        expect(
          (await db.customSelect('PRAGMA integrity_check').getSingle())
              .read<String>('integrity_check'),
          'ok',
        );
      }
      await File('$root/fixture-plan.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'target': '127.0.0.1:5432/notarisdev',
          'account_id': 2001,
          'group_id': 11,
          'label': label,
          'devices': devices,
          'entities': entities,
          'baseline': refs,
          'cleanup_masters': true,
          'max_master_mutations': 4,
          'max_transaction_mutations': 6,
          'max_transaction_payments': 2,
          'max_number_allocations': 2,
          'max_publications': 10,
        }),
      );
      await File('$root/publication-allowlist.json').writeAsString(
        const JsonEncoder.withIndent('  ')
            .convert({'target': '127.0.0.1:5432/notarisdev', 'events': events}),
      );
    } finally {
      await a.close();
      await b.close();
    }
  });
}
