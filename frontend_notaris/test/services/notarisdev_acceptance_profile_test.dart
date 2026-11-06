import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/services/notarisdev_acceptance_profile.dart';
import 'package:frontend_notaris/services/transaction_manual_sync_service.dart';

class Probe implements HttpClientAdapter {
  Map<String, dynamic> evidence = {};
  int calls = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions r,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    calls++;
    expect(r.method, 'GET');
    expect(r.path, '/development/transaction-acceptance');
    return ResponseBody.fromString(
      jsonEncode({'data': evidence}),
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('separate factory binds temp DB scopes and attests every request; original profile rejects live target', () async {
    final folder = await Directory.systemTemp.createTemp(
      'transaction_manual_acceptance_guard_',
    );
    addTearDown(() => folder.delete(recursive: true));
    final file = File('${folder.path}/a.sqlite');
    final db = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();
    final events = [
      for (final kind in ['master', 'transaction'])
        for (final domain in ['notaris', 'ppat'])
          {
            'kind': kind,
            'domain': domain,
            'operation': 'create',
            'revision': 1,
            'uuid':
                '00000000-0000-4000-8000-${kind == 'master' ? '00000000000' : '00000000001'}${domain == 'notaris' ? 1 : 2}',
            'expected_last_seq': kind == 'master'
                ? 5
                : domain == 'notaris'
                ? 6
                : 7,
          },
    ];
    final plan = File('${folder.path}/plan.json');
    await plan.writeAsString(
      jsonEncode({'target': '127.0.0.1:5432/notarisdev', 'events': events}),
    );
    final hash = sha256.convert(await plan.readAsBytes()).toString();
    final manifest = <String, dynamic>{
      'sqlitePath': file.path,
      'baseUrl': 'http://127.0.0.1:8081/api/v1',
      'databaseTarget': '127.0.0.1:5432/notarisdev',
      'deployment': 'NOTARISDEV SYNTHETIC v1',
      'device': 'a',
      'generation': 'reviewed-test',
      'accountId': 2001,
      'groupId': 11,
      'acceptancePlan': plan.path,
      'acceptanceSha256': hash,
    };
    final adapter = Probe()
      ..evidence = {
        'database': 'notarisdev',
        'host': '127.0.0.1',
        'port': 5432,
        'marker': 'NOTARISDEV SYNTHETIC v1',
        'plan_sha256': hash,
        'account_id': 2001,
        'group_id': 11,
      };
    final dio = Dio(BaseOptions(baseUrl: manifest['baseUrl'] as String))
      ..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    final profile = NotarisdevAcceptanceProfile.fromManifest(
      manifest,
      attestationHttp: dio,
    );
    await profile.validate(db);
    expect(
      () => TransactionManualProfile(
        sqlitePath: file.path,
        baseUrl: profile.baseUrl,
        databaseTarget: profile.databaseTarget,
        deployment: profile.deployment,
        device: 'a',
        generation: 'x',
        accountId: 2001,
        groupId: 11,
      ).validateLocation(),
      throwsA(isA<ManualTransactionFailure>()),
    );
    RequestOptions req(String route, {String? uuid}) => RequestOptions(
      baseUrl: profile.baseUrl,
      path: route,
      method: uuid == null ? 'GET' : 'POST',
      headers: {'Authorization': 'Bearer fixture'},
      data: uuid == null ? null : {'uuid': uuid, 'expected_revision': 0},
    );
    final upload = req(
      '/transaksi-notaris/sync/create',
      uuid: events[2]['uuid'] as String,
    );
    await profile.verifyRequest(upload);
    expect(upload.headers['X-Notaris-Acceptance'], hash);
    await expectLater(
      profile.verifyRequest(
        req(
          '/transaksi-notaris/sync/update',
          uuid: events[2]['uuid'] as String,
        ),
      ),
      throwsA(isA<ManualTransactionFailure>()),
    );
    await expectLater(
      profile.verifyRequest(
        req(
          '/transaksi-notaris/sync/create',
          uuid: events[3]['uuid'] as String,
        ),
      ),
      throwsA(isA<ManualTransactionFailure>()),
    );
    adapter.evidence['database'] = 'notarislokal';
    await expectLater(
      profile.verifyRequest(req('/transaksi-notaris/sync/pull')),
      throwsA(isA<ManualTransactionFailure>()),
    );
    expect(
      () => NotarisdevAcceptanceProfile.fromManifest({
        ...manifest,
        'accountId': 1,
      }),
      throwsA(isA<ManualTransactionFailure>()),
    );
    await plan.writeAsString('{}');
    expect(
      () => profile.validateLocation(),
      throwsA(isA<ManualTransactionFailure>()),
    );
    await db.close();
  });
}
