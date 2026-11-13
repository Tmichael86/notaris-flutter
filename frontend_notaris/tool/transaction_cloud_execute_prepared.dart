import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/repositories/pekerjaan_repository.dart';
import 'package:frontend_notaris/repositories/pekerjaan_notaris_cloud_repository.dart';
import 'package:frontend_notaris/repositories/pekerjaan_ppat_cloud_repository.dart';
import 'package:frontend_notaris/repositories/transaction_repository.dart';
import 'package:frontend_notaris/repositories/transaction_cloud_repository.dart';

void main() {
  final env = Platform.environment,
      rootPath = Platform.environment['TRANSACTION_CONTROLLED_ROOT'];
  if (env['TRANSACTION_CONTROLLED_AUTHORIZED'] != 'APPLY_APPROVED_PLAN' ||
      rootPath == null) {
    test(
      'prepared live execution requires separate explicit approval',
      () {},
      skip: true,
    );
    return;
  }
  test('execute reviewed synthetic lifecycle only', () async {
    final root = Directory(rootPath).resolveSymbolicLinksSync();
    if (!root.startsWith(
          '${Directory.current.parent.path}${Platform.pathSeparator}.local${Platform.pathSeparator}',
        ) ||
        root.contains('AppData')) {
      throw StateError('Owned disposable root required');
    }
    final manifest = jsonDecode(
      await File('$root/prepared.json').readAsString(),
    ) as Map<String, dynamic>;
    for (final name in [
      'fixture-plan.json',
      'publication-allowlist.json',
      'device-a.sqlite',
      'device-b.sqlite',
    ]) {
      final hash = sha256
          .convert(await File('$root/$name').readAsBytes())
          .toString()
          .toUpperCase();
      if (hash != manifest['hashes'][name]) {
        throw StateError('Prepared artifact changed: $name');
      }
    }
    if (env['TRANSACTION_EXECUTE_PLAN_SHA256'] !=
            manifest['hashes']['fixture-plan.json'] ||
        !File('$root/live-attempted.lock').existsSync()) {
      throw StateError('Approved plan hash and one-attempt lock required');
    }
    final plan = jsonDecode(
      await File('$root/fixture-plan.json').readAsString(),
    ) as Map<String, dynamic>;
    final live = plan['target'] == '127.0.0.1:5432/notarisdev';
    final baseUrl = env['TRANSACTION_CONTROLLED_URL'];
    if ((live && baseUrl != 'http://127.0.0.1:8081/api/v1') ||
        (!live &&
            (!RegExp(r'^127\.0\.0\.1:55[4-9]\d\d/notaris_publish_test')
                    .hasMatch(plan['target'] as String) ||
                baseUrl != 'http://127.0.0.1:18081/api/v1')) ||
        env['TRANSACTION_CONTROLLED_TOKEN'] == null ||
        env['TRANSACTION_PUBLISH_EXE'] == null) {
      throw StateError('HTTP/DB/credential target mismatch');
    }
    final allow = jsonDecode(
      await File('$root/publication-allowlist.json').readAsString(),
    ) as Map<String, dynamic>;
    final state = <String, dynamic>{
      'target': plan['target'],
      'phase': 'starting',
      'acknowledgements': <dynamic>[],
    };
    Future<void> record(String phase) async {
      state['phase'] = phase;
      await File('$root/live-result.json')
          .writeAsString(const JsonEncoder.withIndent('  ').convert(state));
    }

    final a = AppDatabase.forTesting(
          NativeDatabase(File('$root/device-a.sqlite')),
        ),
        b = AppDatabase.forTesting(
          NativeDatabase(File('$root/device-b.sqlite')),
        );
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl!,
        headers: {
          'Authorization': 'Bearer ${env['TRANSACTION_CONTROLLED_TOKEN']}',
        },
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    String scope(String d) => plan['devices'][d]['scope'] as String;
    TransactionCloudRepository tx(
      AppDatabase db,
      String device,
      String domain,
    ) => TransactionCloudRepository(
      db,
      dio,
      domain: domain,
      scope: '${scope(device)}/transactions',
      petugasScope: '${scope(device)}/petugas',
      masterScope: '${scope(device)}/masters',
    );
    Future<Map<String, dynamic>> masterPush(
      String domain,
      String op,
      int id,
    ) async {
      await record('$domain-master-$op-http-started');
      final Map<String, dynamic> ack;
      if (domain == 'notaris') {
        final r = PekerjaanNotarisCloudRepository(
          a,
          dio,
          scope: '${scope('a')}/masters',
        );
        ack = op == 'create' ? await r.pushCreate(id) : await r.pushDelete(id);
      } else {
        final r = PekerjaanPpatCloudRepository(
          a,
          dio,
          scope: '${scope('a')}/masters',
        );
        ack = op == 'create' ? await r.pushCreate(id) : await r.pushDelete(id);
      }
      (state['acknowledgements'] as List).add({
        'kind': 'master',
        'domain': domain,
        'operation': op,
        ...ack,
      });
      await record('$domain-master-$op-acknowledged');
      return ack;
    }

    Future<void> publish(
      String kind,
      String domain,
      String uuid,
      String op,
      int revision,
    ) async {
      final event = (allow['events'] as List)
          .cast<Map<String, dynamic>>()
          .singleWhere(
            (e) =>
                e['kind'] == kind &&
                e['domain'] == domain &&
                e['uuid'] == uuid &&
                e['operation'] == op &&
                e['revision'] == revision,
          );
      await record('$domain-$kind-$op-publication-started');
      final result = await Process.run(env['TRANSACTION_PUBLISH_EXE']!, [
        '--apply',
        '--live-approved',
        '--confirm-target',
        plan['target'] as String,
        '--domain',
        domain,
        '--batch-size',
        '1',
        '--max-batches',
        '1',
        '--timeout',
        '60s',
        '--only-uuid',
        uuid,
        '--expected-operation',
        op,
        '--expected-revision',
        '$revision',
        '--expected-last-seq',
        '${event['expected_last_seq']}',
        '--allowlist',
        '$root/publication-allowlist.json',
        '--allowlist-sha256',
        manifest['hashes']['publication-allowlist.json'] as String,
        if (kind == 'transaction') '--transaction',
      ]);
      if (result.exitCode != 0) {
        throw StateError(
          'Publisher stopped; inspect database read-only, never retry automatically',
        );
      }
      final receipt =
          jsonDecode((result.stdout as String).trim()) as Map<String, dynamic>;
      if (receipt['published'] != 1 ||
          receipt['last_seq'] != (event['expected_last_seq'] as int) + 1 ||
          receipt['aggregate_uuid'] != uuid) {
        throw StateError('Publication receipt ambiguous');
      }
      await File('$root/$domain-$kind-$op-publication.json')
          .writeAsString(jsonEncode(receipt));
    }

    Future<void> masterPull(String domain, int expected) async {
      for (final item in {'a': a, 'b': b}.entries) {
        final got = domain == 'notaris'
            ? await PekerjaanNotarisCloudRepository(
                item.value,
                dio,
                scope: '${scope(item.key)}/masters',
              ).pullPage(limit: 1)
            : await PekerjaanPpatCloudRepository(
                item.value,
                dio,
                scope: '${scope(item.key)}/masters',
              ).pullPage(limit: 1);
        if (got != expected) throw StateError('Master cursor mismatch');
      }
    }

    var cursor = plan['baseline']['transactions']['last_seq'] as int;
    try {
      // New Master references are created/published explicitly; legacy records untouched.
      for (final domain in ['notaris', 'ppat']) {
        final e = plan['entities'][domain];
        final ack = await masterPush(
          domain,
          'create',
          e['master_local_id'] as int,
        );
        if (ack['uuid'] != e['master_uuid'] || ack['revision'] != 1) {
          throw StateError('Master identity mismatch');
        }
        await publish(
          'master',
          domain,
          e['master_uuid'] as String,
          'create',
          1,
        );
        await masterPull(
          domain,
          (plan['baseline']['masters'][domain]['last_seq'] as int) + 1,
        );
      }
      for (final domain in ['notaris', 'ppat']) {
        final e = plan['entities'][domain];
        final id = e['transaction_local_id'] as int;
        final sender = tx(a, 'a', domain), receiver = tx(b, 'b', domain);
        await record('$domain-transaction-create-http-started');
        final created = await sender.pushCreate(id);
        if (created['uuid'] != e['transaction_uuid'] ||
            created['revision'] != 1) {
          throw StateError('Transaction CREATE identity mismatch');
        }
        (state['acknowledgements'] as List).add({
          'kind': 'transaction',
          'domain': domain,
          'operation': 'create',
          ...created,
        });
        await record('$domain-transaction-create-acknowledged');
        final pending =
            (await a
                    .customSelect(
                      "SELECT payload FROM transaction_cloud_pending WHERE local_uuid='${e['transaction_uuid']}'",
                    )
                    .getSingle())
                .read<String>('payload');
        final replay = await dio.post<Map<String, dynamic>>(
          '/transaksi-$domain/sync/create',
          data: jsonDecode(pending),
        );
        if (jsonEncode(replay.data!['acknowledgement']) !=
            jsonEncode(created)) {
          throw StateError('Mutation retry receipt mismatch');
        }
        await publish(
          'transaction',
          domain,
          e['transaction_uuid'] as String,
          'create',
          1,
        );
        cursor++;
        if (await sender.pullPage(limit: 1) != cursor ||
            await receiver.pullPage(limit: 1) != cursor) {
          throw StateError('CREATE cursor mismatch');
        }
        final rows = await b.select(b.transaksis).get();
        final target = rows.singleWhere((t) => t.uuid == e['transaction_uuid']);
        final payment = (await TransactionRepository(
          b,
        ).getPaymentHistory(target.id)).single;
        if (payment.uuid != e['payment_uuid'] ||
            payment.nominal != 25000 ||
            target.noAkta != created['final_number']) {
          throw StateError('Initial payment/number mismatch');
        }
        final process = (await b.select(b.transaksiProses).get()).singleWhere(
          (p) => p.transaksiId == target.id,
        );
        if (process.uuid != e['transaction_process_uuid']) {
          throw StateError('Process identity mismatch');
        }
        await TransactionRepository(a).save(
          id: id,
          nomorTransaksi: created['final_number'] as String,
          jenisTransaksi: domain,
          pemohonId: 1,
          pemohonUuid: plan['baseline']['pemohon']['uuid'] as String,
          petugasId: 1,
          petugasUuid: plan['devices']['a']['officer_local_uuid'] as String,
          status: 'Baru',
          tanggalTransaksi: DateTime.utc(2020, 1, 1),
          jobs: [
            TransactionJobInput(
              jenisPekerjaan: domain,
              namaPekerjaan: '${e['name']} updated',
              pekerjaanNotarisId: domain == 'notaris'
                  ? e['master_local_id'] as int
                  : null,
              pekerjaanPpatId: domain == 'ppat'
                  ? e['master_local_id'] as int
                  : null,
              hargaUuid: e['price_uuid'] as String,
              kategoriUuid: plan['baseline']['category']['uuid'] as String,
              detailUuid: e['detail_uuid'] as String,
              biayaLayanan: 150000,
              kategoriSnapshot: 'Reviewed cloud category',
              estimasiWaktuSnapshot: '2 hari',
              prosesSnapshot: jsonEncode([
                {
                  'id': e['process_uuid'],
                  'name': 'Periksa sintetis',
                  'status': 'Belum Valid',
                  'attributes': ['KTP sintetis', 'Updated synthetic snapshot'],
                },
              ]),
            ),
          ],
        );
        await record('$domain-transaction-update-http-started');
        final updated = await sender.pushUpdate(id);
        if (updated['revision'] != 2 ||
            updated['final_number'] != created['final_number']) {
          throw StateError('UPDATE revision/number mismatch');
        }
        (state['acknowledgements'] as List).add({
          'kind': 'transaction',
          'domain': domain,
          'operation': 'update',
          ...updated,
        });
        await record('$domain-transaction-update-acknowledged');
        await publish(
          'transaction',
          domain,
          e['transaction_uuid'] as String,
          'update',
          2,
        );
        cursor++;
        await b.customStatement(
          "UPDATE transaksis SET catatan='Synthetic local review',is_sync_dirty=1 WHERE id=${target.id}",
        );
        await expectLater(receiver.pullPage(limit: 1), throwsStateError);
        await b.customStatement(
          'UPDATE transaksis SET catatan=NULL,is_sync_dirty=0 WHERE id=${target.id}',
        );
        if (await sender.pullPage(limit: 1) != cursor ||
            await receiver.pullPage(limit: 1) != cursor) {
          throw StateError('UPDATE cursor mismatch');
        }
        final detail = (await b.select(b.transaksiDetails).get()).singleWhere(
          (d) => d.transaksiId == target.id,
        );
        if (detail.uuid != e['detail_uuid'] ||
            detail.hargaUuid != e['price_uuid'] ||
            detail.kategoriUuid != plan['baseline']['category']['uuid'] ||
            detail.biayaLayanan != 150000) {
          throw StateError('Detail/provenance mismatch');
        }
        if ((jsonDecode(
              detail.prosesSnapshot!,
            ) as List).single['attributes'].last !=
            'Updated synthetic snapshot') {
          throw StateError('Attribute snapshot mismatch');
        }
        if (jsonEncode(
              (await TransactionRepository(b).getPaymentHistory(target.id))
                  .single
                  .toJson(),
            ) !=
            jsonEncode(payment.toJson())) {
          throw StateError('Committed payment changed');
        }
        await TransactionRepository(a).delete(id);
        await record('$domain-transaction-delete-http-started');
        final deleted = await sender.pushDelete(id);
        if (deleted['revision'] != 3 ||
            deleted['final_number'] != created['final_number']) {
          throw StateError('DELETE receipt mismatch');
        }
        (state['acknowledgements'] as List).add({
          'kind': 'transaction',
          'domain': domain,
          'operation': 'delete',
          ...deleted,
        });
        await record('$domain-transaction-delete-acknowledged');
        await publish(
          'transaction',
          domain,
          e['transaction_uuid'] as String,
          'delete',
          3,
        );
        cursor++;
        if (await sender.pullPage(limit: 1) != cursor ||
            await receiver.pullPage(limit: 1) != cursor) {
          throw StateError('DELETE cursor mismatch');
        }
        if ((await b.select(b.transaksis).get())
                .singleWhere((t) => t.uuid == e['transaction_uuid'])
                .deletedAt ==
            null) {
          throw StateError('Tombstone missing');
        }
      }
      // Explicitly approved cleanup retains Master tombstones and historical snapshots.
      for (final domain in ['notaris', 'ppat']) {
        final e = plan['entities'][domain];
        if (domain == 'notaris') {
          await PekerjaanNotarisRepository(a.pekerjaanDao)
              .deleteAggregate(e['master_local_id'] as int);
        } else {
          await PekerjaanPpatRepository(a.pekerjaanDao)
              .deleteAggregate(e['master_local_id'] as int);
        }
        await masterPush(domain, 'delete', e['master_local_id'] as int);
        await publish(
          'master',
          domain,
          e['master_uuid'] as String,
          'delete',
          2,
        );
        await masterPull(
          domain,
          (plan['baseline']['masters'][domain]['last_seq'] as int) + 2,
        );
      }
      await b.customStatement('UPDATE transaction_cloud_feed SET cursor=?', [
        plan['baseline']['transactions']['last_seq'],
      ]);
      for (var n = 0; n < 6; n++) {
        await tx(b, 'b', 'notaris').pullPage(limit: 1);
      }
      if (await tx(b, 'b', 'ppat').pullPage() != cursor) {
        throw StateError('Replay/latest cursor mismatch');
      }
      for (final db in [a, b]) {
        if ((await db.select(db.transaksis).get()).length != 2 ||
            (await db.select(db.transaksiRiwayatPembayarans).get()).length !=
                2) {
          throw StateError('Duplicate records after replay');
        }
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
      await a.close();
      await b.close();
      for (final device in ['a', 'b']) {
        final reopened = AppDatabase.forTesting(
          NativeDatabase(File('$root/device-$device.sqlite')),
        );
        try {
          if (await tx(reopened, device, 'notaris').pullPage() != cursor) {
            throw StateError('Restart lost cursor');
          }
        } finally {
          await reopened.close();
        }
      }
      state['cursor'] = cursor;
      state['integrity'] = 'ok';
      state['fk_violations'] = 0;
      await record('verified');
    } finally {
      await a.close();
      await b.close();
      dio.close();
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
