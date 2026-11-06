import 'dart:convert';
import 'dart:io';

import 'windows_powershell.dart';

import 'package:drift/drift.dart';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/transaction_monitor_isolated_main.dart';
import 'package:frontend_notaris/repositories/pekerjaan_notaris_cloud_repository.dart';
import 'package:frontend_notaris/repositories/pekerjaan_ppat_cloud_repository.dart';

void main() {
  final env = Platform.environment;
  if (env['NOTARIS_UI_DEPENDENCIES_APPROVED'] !=
      'CREATE_TWO_ALLOWLISTED_MASTERS') {
    test('dependency setup requires reviewed approval', () {}, skip: true);
    return;
  }
  test('create publish and pull only approved Master dependencies', () async {
    final powershell =
        windowsPowerShellExecutable(); // Fail BEFORE first CREATE.
    final folder = env['NOTARIS_UI_PROFILE_DIRECTORY']!;
    final configs = [
      await loadIsolatedTransactionUiProfile('$folder/a.json'),
      await loadIsolatedTransactionUiProfile('$folder/b.json'),
    ];
    final receipt = Directory(env['NOTARIS_UI_RECEIPT']!)
        .resolveSymbolicLinksSync();
    final plan = jsonDecode(
      await File('$receipt/fixture-plan.json').readAsString(),
    ) as Map;
    final resume =
        env['NOTARIS_UI_DEPENDENCIES_RESUME'] ==
        'NOTARIS_ACKED_PENDING_PUBLICATION';
    Map? reviewed;
    if (resume) {
      reviewed = jsonDecode(
        await File('$receipt/resume-review.json').readAsString(),
      ) as Map;
      for (final c in configs) {
        for (final table in [
          'pekerjaan_notaris_sync_feed',
          'pekerjaan_ppat_sync_feed',
        ]) {
          expect(
            (await c.database
                    .customSelect('SELECT cursor FROM $table')
                    .getSingle())
                .read<int>('cursor'),
            5,
          );
        }
        expect(
          (await c.database
                  .customSelect('SELECT cursor FROM transaction_cloud_feed')
                  .getSingle())
              .read<int>('cursor'),
          6,
        );
        expect(
          await c.database
              .customSelect('SELECT * FROM pekerjaan_ppat_sync_identity')
              .get(),
          isEmpty,
        );
        expect(
          await c.database
              .customSelect('SELECT * FROM pekerjaan_ppat_sync_pending')
              .get(),
          isEmpty,
        );
        expect(
          await c.database
              .customSelect('SELECT * FROM transaction_cloud_identity')
              .get(),
          isEmpty,
        );
        expect(
          await c.database
              .customSelect('SELECT * FROM transaction_cloud_pending')
              .get(),
          isEmpty,
        );
      }
      expect(
        await configs.last.database
            .customSelect('SELECT * FROM pekerjaan_notaris_sync_identity')
            .get(),
        isEmpty,
      );
    }
    final dio = Dio(
      BaseOptions(
        baseUrl: 'http://127.0.0.1:8081/api/v1',
        connectTimeout: const Duration(seconds: 5),
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        followRedirects: false,
        headers: {'Authorization': 'Bearer ${env['NOTARIS_UI_TOKEN']}'},
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (r, h) async {
          try {
            await configs.first.profile.verifyRequest(r);
            h.next(r);
          } catch (e) {
            h.reject(DioException(requestOptions: r, error: e));
          }
        },
      ),
    );
    try {
      for (final domain in ['notaris', 'ppat']) {
        final id = plan['entities'][domain]['master_local_id'] as int;
        final uuid = plan['entities'][domain]['master_uuid'] as String;
        final Map<String, dynamic> ack;
        if (resume && domain == 'notaris') {
          ack = Map<String, dynamic>.from(reviewed!['ack'] as Map);
          final db = configs.first.database;
          final identity = await db
              .customSelect(
                'SELECT * FROM pekerjaan_notaris_sync_identity WHERE local_uuid=?',
                variables: [Variable(uuid)],
              )
              .getSingle();
          final pending = await db
              .customSelect(
                'SELECT * FROM pekerjaan_notaris_sync_pending WHERE local_uuid=?',
                variables: [Variable(uuid)],
              )
              .getSingle();
          expect(
            resumeAcknowledgementMatches(identity.data, pending.data, ack),
            isTrue,
          );
          // No HTTP CREATE or mutation replay for already acknowledged Notaris.
        } else {
          ack = domain == 'notaris'
              ? await PekerjaanNotarisCloudRepository(
                  configs.first.database,
                  dio,
                  scope: configs.first.profile.masterScope,
                ).pushCreate(id)
              : await PekerjaanPpatCloudRepository(
                  configs.first.database,
                  dio,
                  scope: configs.first.profile.masterScope,
                ).pushCreate(id);
        }
        expect(ack['uuid'], uuid);
        expect(ack['revision'], 1);
        final publish = await Process.run(powershell, [
          '-NoProfile',
          '-NonInteractive',
          '-File',
          '${Directory.current.parent.path}/scripts/invoke-notarisdev-master-publisher.ps1',
          '-Domain',
          domain,
          '-BatchSize',
          '1',
          '-MaxBatches',
          '1',
          '-Apply',
          '-LiveApproved',
          '-ConfirmTarget',
          '127.0.0.1:5432/notarisdev',
          '-OnlyUuid',
          uuid,
          '-ExpectedRevision',
          '1',
          '-Allowlist',
          '$receipt/ui-publication-allowlist.json',
          '-ConfirmAllowlistSha256',
          env['NOTARIS_UI_PLAN_SHA256']!,
          '-ExpectedLastSeq',
          '5',
        ]);
        final logName = resume
            ? '$domain-resume-publication.log'
            : '$domain-publication.log';
        await File('$receipt/$logName')
            .writeAsString('${publish.stdout}\n${publish.stderr}');
        if (publish.exitCode != 0) {
          throw StateError(
            'Publication failed; stop, inspect receipt, no retry',
          );
        }
        for (final c in configs) {
          final cursor = domain == 'notaris'
              ? await PekerjaanNotarisCloudRepository(
                  c.database,
                  dio,
                  scope: c.profile.masterScope,
                ).pullPage(limit: 1)
              : await PekerjaanPpatCloudRepository(
                  c.database,
                  dio,
                  scope: c.profile.masterScope,
                ).pullPage(limit: 1);
          expect(cursor, 6);
          expect(
            await c.database.customSelect('PRAGMA foreign_key_check').get(),
            isEmpty,
          );
        }
      }
      await File('$receipt/dependencies-ready.json').writeAsString(
        jsonEncode({
          'verified': true,
          'plan_sha256': env['NOTARIS_UI_PLAN_SHA256'],
        }),
      );
    } finally {
      dio.close(force: true);
      for (final c in configs) {
        c.http.close(force: true);
        await c.database.close();
      }
    }
  });
}
