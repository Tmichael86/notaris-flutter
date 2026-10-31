// Explicit debug-only entry point. Never opens the daily application database,
// auth secure storage or AuthStartupGate's automatic global session sync.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

import 'core/widgets/app_shell.dart';
import 'database/app_database.dart';
import 'models/auth_session.dart';
import 'providers/database_provider.dart';
import 'providers/app_providers.dart';
import 'providers/authenticated_api_provider.dart';
import 'providers/petugas_manual_sync_provider.dart';
import 'repositories/people_repository.dart';
import 'repositories/petugas_reference_resolver.dart';
import 'repositories/petugas_identity_reconciliation.dart';
import 'repositories/petugas_identity_map_repository.dart';
import 'repositories/petugas_sync_repository.dart';
import 'services/petugas_sync_api.dart';
import 'services/petugas_reference_api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await _startManual();
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Manual Petugas sync blocked: gunakan debug opt-in dan session file dari harness testing yang masih aktif. Profil aplikasi harian tidak dibuka.',
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _startManual() async {
  if (!kDebugMode || !petugasManualBuildEnabled) {
    throw StateError('Debug opt-in PETUGAS_MANUAL_SYNC=true required');
  }
  final path = Platform.environment['NOTARIS_MANUAL_SESSION'];
  if (path == null) {
    throw StateError('Start isolated Go manual harness first');
  }
  final sessionFile = File(path).resolveSymbolicLinksSync();
  final dir = p.dirname(sessionFile);
  if (!p.isWithin(Directory.systemTemp.resolveSymbolicLinksSync(), dir) ||
      !p.basename(dir).startsWith('petugas-manual-')) {
    throw StateError('Session must belong to temporary harness directory');
  }
  final config = syncMap(jsonDecode(await File(sessionFile).readAsString()));
  final url = config['url'] as String;
  final token = config['token'] as String;
  final nonce = config['nonce'] as String;
  if (!{'127.0.0.1', 'localhost', '::1'}.contains(Uri.parse(url).host)) {
    throw StateError('Testing backend must be loopback');
  }
  final dio = Dio(
    BaseOptions(
      baseUrl: url,
      headers: {'Authorization': 'Bearer $token'},
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      followRedirects: false,
    ),
  );
  Future<void> verify() async {
    try {
      final reply = syncMap(
        (await dio.get<Object?>('/petugas/testing/status')).data,
      );
      if (syncMap(reply['data'])['nonce'] != nonce) {
        throw const PetugasSyncFailure(
          PetugasSyncFailureKind.blocked,
          'backend is not this isolated harness',
        );
      }
    } on DioException catch (e) {
      final timeout = {
        DioExceptionType.connectionTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.sendTimeout,
      }.contains(e.type);
      throw PetugasSyncFailure(switch (e.response?.statusCode) {
        401 => PetugasSyncFailureKind.unauthorized,
        403 => PetugasSyncFailureKind.forbidden,
        404 => PetugasSyncFailureKind.blocked,
        _ =>
          e.response != null
              ? PetugasSyncFailureKind.server
              : (timeout
                    ? PetugasSyncFailureKind.timeout
                    : PetugasSyncFailureKind.network),
      });
    }
  }

  await verify();
  final db = AppDatabase(
    NativeDatabase(File(p.join(dir, 'petugas-manual.sqlite'))),
  );
  final scope = 'manual/$nonce/account-1';
  final refs = VerifiedPetugasReferences(db, scope: scope);
  final sync = PetugasLocalSyncRepository(
    db,
    PetugasSyncApi(dio),
    refs,
    scope: scope,
  );
  Future<void> prepare() async {
    await verify();
    final catalog = await PetugasReferenceApi(dio).genders();
    if (catalog.where((g) => g.serverId == 2).length != 1) {
      throw const PetugasSyncFailure(PetugasSyncFailureKind.blockedReference);
    }
    await db.transaction(() async {
      const genderUuid = 'manual-fixture-local-gender';
      final exists = await (db.select(
        db.jenisKelamins,
      )..where((r) => r.uuid.equals(genderUuid))).getSingleOrNull();
      final gender =
          exists?.id ??
          await db
              .into(db.jenisKelamins)
              .insert(
                JenisKelaminsCompanion.insert(
                  uuid: genderUuid,
                  nama: 'Manual fixture (local)',
                ),
              );
      await refs.confirmGender(
        localUuid: genderUuid,
        serverId: 2,
        evidence: 'operator confirmed isolated fixture manifest $nonce',
      );
      final rows = await db.select(db.petugasLocals).get();
      // Only create the dedicated fixture on an empty profile. Existing records
      // remain unclassified and cannot be bulk-promoted into synchronization.
      if (rows.isEmpty) {
        final id = await PetugasRepository(db).create(
          nama: 'Manual E2E Petugas',
          email: 'manual@e2e.invalid',
          jenisKelamin: gender,
        );
        final row = await (db.select(
          db.petugasLocals,
        )..where((r) => r.id.equals(id))).getSingle();
        await PetugasIdentityReconciliation(db, scope: scope).confirmLocalOnly(
          row.uuid,
          'operator confirmed newly created manual fixture',
        );
      }
    });
  }

  Future<void> synchronize() async {
    await verify();
    final dirty = await (db.select(
      db.petugasLocals,
    )..where((r) => r.isSyncDirty.equals(true))).get();
    for (final row in dirty) {
      final map = await PetugasIdentityMapRepository(db)
          .findByLocalUuid(row.uuid);
      if (map == null ||
          !{'local_only', 'verified', 'server_only'}.contains(map.state)) {
        throw const PetugasSyncFailure(PetugasSyncFailureKind.blocked);
      }
    }
    for (final row in dirty) {
      await sync.push(row.uuid);
    }
    await sync.pull();
  }

  final session = AuthSession(
    token: token,
    userId: 1,
    groupId: 1,
    userName: 'Isolated manual test',
    groupName: 'Testing',
    user: const {},
    sidebars: const [
      {
        'read': 1,
        'sidebar': {'sidebar_nama': 'Petugas'},
      },
    ],
    verifiedAt: DateTime.now(),
  );
  runApp(
    ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(dio),
        authenticatedDioProvider.overrideWithValue(dio),
        appDatabaseProvider.overrideWith((ref) {
          ref.onDispose(db.close);
          ref.onDispose(dio.close);
          return db;
        }),
        petugasManualPrepareProvider.overrideWithValue(prepare),
        petugasManualActionProvider.overrideWithValue(synchronize),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: AppShell(session: session, onLogout: () => exit(0)),
      ),
    ),
  );
}
