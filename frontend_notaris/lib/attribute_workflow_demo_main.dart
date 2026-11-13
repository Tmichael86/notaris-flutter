import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'database/app_database.dart';
import 'main.dart' show MyApp;
import 'providers/app_providers.dart';
import 'providers/auth_provider.dart';
import 'providers/database_provider.dart';
import 'providers/development_smoke_provider.dart';
import 'providers/petugas_manual_sync_provider.dart';
import 'repositories/transaction_repository.dart';
import 'services/attribute_workflow.dart';
import 'services/auth_service.dart';

const _origin = 'http://127.0.0.1:56781';
const _uuid = '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}';

Dio _demoHttp() {
  final workflow = RegExp(
    r'^/api/v1/attribute-workflow/processes/' + _uuid + r'$',
  );
  final mark = RegExp(
    r'^/api/v1/attribute-workflow/inbox/' + _uuid + r'/read$',
  );
  final dio = Dio(
    BaseOptions(
      baseUrl: '$_origin/api/v1',
      followRedirects: false,
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 8),
      sendTimeout: const Duration(seconds: 8),
    ),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (r, h) {
        final path = r.uri.path;
        final allowed = switch (r.method) {
          'GET' =>
            path == '/api/v1/auth/me/sidebar-access' ||
                path == '/api/v1/attribute-workflow/demo-profile' ||
                path == '/api/v1/attribute-workflow/inbox' ||
                workflow.hasMatch(path),
          'POST' =>
            path == '/api/v1/auth/login' ||
                workflow.hasMatch(path) ||
                mark.hasMatch(path),
          _ => false,
        };
        if (r.uri.origin != _origin || !allowed || r.uri.hasQuery) {
          h.reject(
            DioException(
              requestOptions: r,
              error: 'Profil demo dibatasi ke workflow atribut.',
            ),
          );
          return;
        }
        r.followRedirects = false;
        h.next(r);
      },
    ),
  );
  return dio;
}

File demoDatabaseFile(String identity) {
  if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(identity)) {
    throw const FormatException('Identitas demo diperlukan.');
  }
  final root = Directory.systemTemp.resolveSymbolicLinksSync();
  final dir = Directory(p.join(root, 'notaris-attribute-$identity'));
  final file = File(p.join(dir.path, 'workflow-demo.sqlite'));
  final marker = File(p.join(dir.path, 'owner'));
  for (final path in [dir.path, file.path, marker.path]) {
    if (FileSystemEntity.typeSync(path, followLinks: false) ==
        FileSystemEntityType.link) {
      throw StateError('Profil tertaut ditolak.');
    }
  }
  if (!dir.existsSync()) {
    dir.createSync();
    marker.createSync(exclusive: true);
    marker.writeAsStringSync(identity, flush: true);
  }
  if (!p.equals(dir.resolveSymbolicLinksSync(), dir.path) ||
      marker.readAsStringSync() != identity ||
      (file.existsSync() &&
          !p.equals(file.resolveSymbolicLinksSync(), file.path))) {
    throw StateError('Profil demo bukan milik sesi ini.');
  }
  return file;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kDebugMode || !Platform.isWindows) {
    throw StateError('Gunakan Windows debug pada profil demo.');
  }
  const identity = String.fromEnvironment('ATTRIBUTE_DEMO_ID');
  final dio = _demoHttp();
  AppDatabase? opened;
  try {
    if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(identity)) {
      throw const FormatException('Identitas demo diperlukan.');
    }
    final attestation = await dio.get<Map<String, dynamic>>(
      '/attribute-workflow/demo-profile',
    );
    if (attestation.data?['demo_id'] != identity) {
      throw StateError('Identitas backend demo berbeda.');
    }
    final database = AppDatabase.forTesting(
      NativeDatabase(demoDatabaseFile(identity)),
    );
    opened = database;
    await seedAttributeDemo(database);
    runApp(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((ref) {
            ref.onDispose(database.close);
            return database;
          }),
          dioProvider.overrideWith((ref) {
            ref.onDispose(dio.close);
            return dio;
          }),
          authServiceProvider.overrideWith(
            (ref) => AuthService(
              dio: ref.watch(dioProvider),
              cacheKey: 'notaris.auth.attribute-demo.$identity',
            ),
          ),
          developmentUiSmokeProvider.overrideWithValue(true),
          petugasManualEnabledProvider.overrideWithValue(false),
          attributeDemoProvider.overrideWithValue(
            AttributeDemoConnection(dio, identity),
          ),
        ],
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: Banner(
            message: 'PROFIL DEMONSTRASI',
            location: BannerLocation.topEnd,
            child: MyApp(),
          ),
        ),
      ),
    );
  } catch (_) {
    await opened?.close();
    dio.close();
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Profil workflow demo tidak terverifikasi.'),
          ),
        ),
      ),
    );
  }
}

const demoTransaction = '74100000-0000-4000-8000-000000000003';
const demoDetail = '74100000-0000-4000-8000-000000000004';
const demoProcess = '74100000-0000-4000-8000-000000000005';
const _definition = '74100000-0000-4000-8000-000000000006';
const _applicant = '74100000-0000-4000-8000-000000000001';
const _officer = '74100000-0000-4000-8000-000000000002';

Future<void> seedAttributeDemo(AppDatabase db) => db.transaction(() async {
  final existing = await db.select(db.transaksis).get();
  if (existing.isNotEmpty) {
    if (existing.length != 1 || existing.single.uuid != demoTransaction) {
      throw StateError(
        'Profil SQLite demo berisi transaksi yang tidak dikenal.',
      );
    }
    return;
  }
  for (final sql in [
    "INSERT INTO pemohons(id,uuid,nama,nik) VALUES(1,'$_applicant','Bagas Pradipta','NIK TIDAK VALID — DEMO')",
    "INSERT INTO petugas(id,uuid,nama,email) VALUES(1,'$_officer','Dimas Prasetyo','dimas@example.invalid')",
    "INSERT INTO pekerjaan_kategori(id,uuid,nama) VALUES(1,'74100000-0000-4000-8000-000000000007','Legalisasi')",
    "INSERT INTO pekerjaan_notaris(id,uuid,nama) VALUES(1,'74100000-0000-4000-8000-000000000008','Legalisasi Dokumen')",
    "INSERT INTO pekerjaan_notaris_harga(id,uuid,pekerjaan_notaris_id,kategori_pekerjaan_id,harga,estimasi_waktu) VALUES(1,'74100000-0000-4000-8000-000000000009',1,1,'150000','2 hari')",
    "INSERT INTO pekerjaan_notaris_proses(id,uuid,pekerjaan_notaris_id,nama,detail) VALUES(1,'74100000-0000-4000-8000-000000000010',1,'Pemeriksaan Berkas','Periksa identitas dan ejaan')",
    "INSERT INTO pekerjaan_notaris_atributs(id,uuid,pekerjaan_notaris_id,proses_pekerjaan_notaris_id,atribut) VALUES(1,'$_definition',1,1,'Catatan Pemeriksaan Identitas')",
  ]) {
    await db.customStatement(sql);
  }
  final process = await db.select(db.pekerjaanNotarisProsesLocals).getSingle();
  final definition = await db
      .select(db.pekerjaanNotarisAtributLocals)
      .getSingle();
  final id = await TransactionRepository(db).save(
    nomorTransaksi: '1001011260001',
    jenisTransaksi: 'notaris',
    pemohonId: 1,
    pemohonUuid: _applicant,
    petugasId: 1,
    petugasUuid: _officer,
    status: 'Baru',
    tanggalTransaksi: DateTime(2026, 11, 10),
    tanggalJatuhTempo: DateTime(2026, 11, 12),
    jobs: [
      TransactionJobInput(
        jenisPekerjaan: 'notaris',
        pekerjaanNotarisId: 1,
        namaPekerjaan: 'Legalisasi Dokumen',
        kategoriSnapshot: 'Legalisasi',
        detailUuid: demoDetail,
        biayaLayanan: 150000,
        biayaLainnya: 0,
        hargaUuid: '74100000-0000-4000-8000-000000000009',
        kategoriUuid: '74100000-0000-4000-8000-000000000007',
        prosesSnapshot: jsonEncode([
          {
            'id': process.id.toString(),
            'name': process.nama,
            'attributes': [definition.atribut],
          },
        ]),
      ),
    ],
  );
  // The disposable fixture binds to the pre-provisioned server IDs in the
  // same seed transaction. It creates no sync receipt, mapping or cursor.
  await db.customStatement('UPDATE transaksis SET uuid=? WHERE id=?', [
    demoTransaction,
    id,
  ]);
  await db.customStatement(
    'UPDATE transaksi_proses SET uuid=? WHERE transaksi_id=?',
    [demoProcess, id],
  );
  if ((await db.customSelect('PRAGMA foreign_key_check').get()).isNotEmpty) {
    throw StateError('Referensi fixture demo tidak konsisten.');
  }
});
