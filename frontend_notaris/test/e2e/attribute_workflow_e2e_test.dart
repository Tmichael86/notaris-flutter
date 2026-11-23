import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/attribute_workflow_demo_main.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/services/attribute_workflow.dart';
import 'package:frontend_notaris/services/auth_service.dart';

class _DisposableHttp extends HttpOverrides {}

class _FileDraft implements AttributeDraftStore {
  _FileDraft(this.root);
  final Directory root;
  File _file(String key) =>
      File('${root.path}/${sha256.convert(utf8.encode(key))}.draft');
  @override
  Future<String?> read(String key) async =>
      await _file(key).exists() ? await _file(key).readAsString() : null;
  @override
  Future<void> write(String key, String value) async {
    await _file(key).writeAsString(value, flush: true);
  }
}

const target = (
  transaction: demoTransaction,
  detail: demoDetail,
  process: demoProcess,
);

Future<String> snapshot(AppDatabase db) async {
  final tables = await db
      .customSelect(
        "SELECT name FROM sqlite_schema WHERE type='table' ORDER BY name",
      )
      .get();
  final data = <String, Object?>{};
  for (final table in tables) {
    final name = table.read<String>('name');
    data[name] =
        (await db.customSelect('SELECT * FROM "$name" ORDER BY rowid').get())
            .map((r) => r.data)
            .toList();
  }
  return jsonEncode(data);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'disposable v20 fixture uses Master, real identities and idempotent seed',
    () async {
      final dir = await Directory.systemTemp.createTemp('attribute-fixture-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/fixture.sqlite');
      final initial = AppDatabase.forTesting(NativeDatabase(file));
      late final String before;
      try {
        final version =
            (await initial.customSelect('PRAGMA user_version').getSingle())
                .read<int>('user_version');
        expect(version, 20);
        await seedAttributeDemo(initial);
        before = await snapshot(initial);
        expect(
          (await initial.select(initial.pemohons).getSingle()).nama,
          'Bagas Pradipta',
        );
        expect(
          (await initial.select(initial.pekerjaanNotarisLocals).getSingle())
              .nama,
          'Legalisasi Dokumen',
        );
        final process = await initial
            .select(initial.transaksiProses)
            .getSingle();
        expect(process.uuid, demoProcess);
        expect(process.transaksiDetailUuid, demoDetail);
        expect(process.statusProses, isNull);
      } finally {
        await initial.close();
      }
      final db = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(db.close);
      await seedAttributeDemo(db);
      expect(await snapshot(db), before);
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      expect(
        await db.customSelect('SELECT * FROM transaction_cloud_pending').get(),
        isEmpty,
      );
    },
  );

  final base = Platform.environment['ATTRIBUTE_TEST_URL'];
  test('two authenticated accounts, offline draft and retry against disposable Go', () async {
    final targetUri = Uri.parse(base!);
    expect(targetUri.host, '127.0.0.1');
    expect(targetUri.port, isNot(anyOf(8080, 8081, 5432)));
    expect(targetUri.path, '/api/v1');
    final dir = await Directory.systemTemp.createTemp('attribute-http-');
    addTearDown(() => dir.delete(recursive: true));
    final db = AppDatabase.forTesting(
      NativeDatabase(File('${dir.path}/workflow.sqlite')),
    );
    addTearDown(db.close);
    await seedAttributeDemo(db);
    final before = await snapshot(db);
    final http = Dio(BaseOptions(baseUrl: base, followRedirects: false));
    http.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => _DisposableHttp().createHttpClient(null),
    );
    addTearDown(http.close);
    FlutterSecureStorage.setMockInitialValues({});
    final auth = AuthService(dio: http, cacheKey: 'disposable-attribute-test');
    final worker = await auth.login(
      username: 'demo.dimas',
      password: 'disposable-dimas',
      rememberMe: false,
    );
    final reviewer = await auth.login(
      username: 'demo.nabila',
      password: 'disposable-nabila',
      rememberMe: false,
    );
    final demo = AttributeDemoConnection(http, 'isolated-e2e');
    var dimas = AttributeWorkflowClient(demo, worker, _FileDraft(dir));
    final nabila = AttributeWorkflowClient(demo, reviewer, _FileDraft(dir));
    final empty = await dimas.refresh(target);
    expect(empty['revision'], 0);
    expect(empty['history'], isEmpty);
    await dimas.stage(target, 'initialize');
    await dimas.sendPending(target);
    await dimas.refresh(target);

    await dimas.saveDraft(target, 'Identitas telah diperiksa');
    expect((await nabila.local(target))['draft'], isNull);
    // Restore the draft from disk through a new client, then persist the exact
    // command before sending it. No fake server acknowledgement.
    dimas = AttributeWorkflowClient(demo, worker, _FileDraft(dir));
    expect((await dimas.local(target))['draft'], 'Identitas telah diperiksa');
    await dimas.stage(target, 'submit');
    final staged = (await dimas.local(target))['pending'];
    final unavailable = Dio(BaseOptions(baseUrl: base));
    addTearDown(unavailable.close);
    unavailable.interceptors.add(
      InterceptorsWrapper(
        onRequest: (r, h) {
          h.reject(
            DioException(
              requestOptions: r,
              type: DioExceptionType.connectionError,
            ),
          );
        },
      ),
    );
    final offline = AttributeWorkflowClient(
      AttributeDemoConnection(unavailable, 'isolated-e2e'),
      worker,
      _FileDraft(dir),
    );
    await expectLater(
      offline.sendPending(target),
      throwsA(isA<DioException>()),
    );
    expect((await offline.local(target))['pending'], staged);
    expect(await nabila.inbox(), isEmpty);

    dimas = AttributeWorkflowClient(demo, worker, _FileDraft(dir));
    await dimas.sendPending(target);
    final first = (await nabila.inbox()).single;
    expect(first['read_at'], isNull);
    await nabila.markRead(first['event_uuid'] as String);
    expect((await nabila.inbox()).single['read_at'], isNotNull);
    expect((await nabila.refresh(target))['can_decide'], isTrue);
    await nabila.stage(target, 'revise', reason: 'Tambahkan pemeriksaan ejaan');
    await nabila.sendPending(target);
    expect(
      (await dimas.inbox()).single['reason'],
      'Tambahkan pemeriksaan ejaan',
    );
    expect((await dimas.refresh(target))['status'], 'revision');
    await dimas.saveDraft(target, 'Identitas dan ejaan diperiksa');
    await dimas.stage(target, 'submit');
    await dimas.sendPending(target);
    expect((await nabila.refresh(target))['version'], 2);
    await nabila.stage(target, 'approve');
    await nabila.sendPending(target);

    dimas = AttributeWorkflowClient(demo, worker, _FileDraft(dir));
    final finalView = await dimas.refresh(target);
    expect(finalView['status'], 'valid');
    expect(finalView['revision'], 5);
    final history = finalView['history'] as List;
    expect(history.map((e) => (e as Map)['actor_id']), [71, 71, 72, 71, 72]);
    expect(history[1]['value'], 'Identitas telah diperiksa');
    expect(history[3]['value'], 'Identitas dan ejaan diperiksa');
    expect((await dimas.inbox()).map((e) => e['action']), [
      'approve',
      'revise',
    ]);
    expect(await snapshot(db), before);
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  }, skip: base == null ? 'owned PostgreSQL integration URL not set' : false);
}
