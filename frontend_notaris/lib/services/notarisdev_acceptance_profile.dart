import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import 'transaction_manual_sync_service.dart';

/// Separate acceptance factory. The original disposable profile stays strict.
class NotarisdevAcceptanceProfile extends TransactionManualProfile {
  NotarisdevAcceptanceProfile._(Map<String, dynamic> m, this.attestationHttp)
    : planPath = m['acceptancePlan'] as String,
      planHash = (m['acceptanceSha256'] as String).toLowerCase(),
      super(
        sqlitePath: m['sqlitePath'] as String,
        baseUrl: m['baseUrl'] as String,
        databaseTarget: m['databaseTarget'] as String,
        deployment: m['deployment'] as String,
        device: m['device'] as String,
        generation: m['generation'] as String,
        accountId: m['accountId'] as int,
        groupId: m['groupId'] as int,
      );
  factory NotarisdevAcceptanceProfile.fromManifest(
    Map<String, dynamic> m, {
    Dio? attestationHttp,
  }) {
    final profile = NotarisdevAcceptanceProfile._(m, attestationHttp);
    profile.validateLocation();
    return profile;
  }
  final String planPath, planHash;
  final Dio? attestationHttp;
  List<Map> get events {
    final bytes = File(planPath).readAsBytesSync();
    if (sha256.convert(bytes).toString() != planHash) {
      throw const ManualTransactionFailure('scope');
    }
    final p = jsonDecode(utf8.decode(bytes)) as Map;
    final list = (p['events'] as List).cast<Map>();
    final keys = list.map((e) => '${e['kind']}/${e['domain']}').toSet();
    if (p['target'] != '127.0.0.1:5432/notarisdev' ||
        list.length != 4 ||
        keys.length != 4 ||
        !keys.containsAll([
          'master/notaris',
          'master/ppat',
          'transaction/notaris',
          'transaction/ppat',
        ]) ||
        list.map((e) => e['uuid']).toSet().length != 4 ||
        list.any(
          (e) =>
              e['operation'] != 'create' ||
              e['revision'] != 1 ||
              e['expected_last_seq'] !=
                  (e['kind'] == 'master'
                      ? 5
                      : e['domain'] == 'notaris'
                      ? 6
                      : 7) ||
              !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(e['uuid'] as String),
        )) {
      throw const ManualTransactionFailure('scope');
    }
    return list;
  }

  @override
  String validateLocation() {
    if (baseUrl != 'http://127.0.0.1:8081/api/v1' ||
        databaseTarget != '127.0.0.1:5432/notarisdev' ||
        accountId != 2001 ||
        groupId != 11 ||
        deployment != 'NOTARISDEV SYNTHETIC v1' ||
        generation.isEmpty ||
        device.isEmpty) {
      throw const ManualTransactionFailure('scope');
    }
    events;
    return validateTemporaryLocation();
  }

  @override
  Future<void> verifyRequest(RequestOptions request) async {
    final r = request;
    validateLocation();
    if (r.uri.origin != 'http://127.0.0.1:8081') {
      throw const ManualTransactionFailure('scope');
    }
    if (r.method == 'POST') {
      final body = r.data is String ? jsonDecode(r.data as String) : r.data;
      if (body is! Map ||
          !events.any(
            (e) =>
                r.uri.path ==
                    '/api/v1/${e['kind'] == 'master' ? 'pekerjaan' : 'transaksi'}-${e['domain']}/sync/create' &&
                body['uuid'] == e['uuid'],
          ) ||
          ((body['expected_revision'] ?? 0) != 0)) {
        throw const ManualTransactionFailure('scope');
      }
    } else if (r.method != 'GET' || !r.uri.path.endsWith('/sync/pull')) {
      throw const ManualTransactionFailure('scope');
    }
    final probe =
        attestationHttp ??
        Dio(
          BaseOptions(
            baseUrl: baseUrl,
            followRedirects: false,
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
          ),
        );
    try {
      final result = await probe.get(
        '/development/transaction-acceptance',
        options: Options(
          headers: {'Authorization': r.headers['Authorization']},
        ),
      );
      final d = result.data['data'] as Map;
      if (d['database'] != 'notarisdev' ||
          d['host'] != '127.0.0.1' ||
          d['port'] != 5432 ||
          d['marker'] != deployment ||
          d['plan_sha256'] != planHash ||
          d['account_id'] != accountId ||
          d['group_id'] != groupId) {
        throw const ManualTransactionFailure('scope');
      }
      r.headers['X-Notaris-Acceptance'] = planHash;
    } finally {
      if (attestationHttp == null) probe.close(force: true);
    }
  }
}
