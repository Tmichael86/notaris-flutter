import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/repositories/people_repository.dart';
import 'package:frontend_notaris/repositories/petugas_reference_resolver.dart';
import 'package:frontend_notaris/repositories/petugas_identity_reconciliation.dart';
import 'package:frontend_notaris/repositories/petugas_sync_repository.dart';
import 'package:frontend_notaris/services/petugas_sync_api.dart';
import 'package:frontend_notaris/services/petugas_reference_api.dart';

void main() {
  test(
    'isolated Flutter HTTP Go PostgreSQL push/pull roundtrip',
    () async {
      final url = Platform.environment['NOTARIS_E2E_URL']!;
      final token = Platform.environment['NOTARIS_E2E_TOKEN']!;
      final uri = Uri.parse(url);
      if (!{'127.0.0.1', 'localhost', '::1'}.contains(uri.host)) {
        throw StateError('E2E requires loopback test server');
      }
      final dio = Dio(
        BaseOptions(
          baseUrl: url,
          headers: {'Authorization': 'Bearer $token'},
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      addTearDown(dio.close);
      final temp = await Directory.systemTemp.createTemp('notaris-device-e2e-');
      var db = AppDatabase(
        NativeDatabase(File('${temp.path}/isolated.sqlite')),
      );
      addTearDown(() async {
        await db.close();
        await temp.delete(recursive: true);
      });
      final catalog = await PetugasReferenceApi(dio).genders();
      expect(catalog.single.serverId, 2);
      final localGender = await db
          .into(db.jenisKelamins)
          .insert(
            JenisKelaminsCompanion.insert(
              uuid: 'local-e2e-gender',
              nama: 'Operator selected reference',
            ),
          );
      expect(localGender, isNot(catalog.single.serverId));
      const scope = 'isolated-e2e/server-account';
      var refs = VerifiedPetugasReferences(db, scope: scope);
      // Fixture manifest explicitly pairs local-e2e-gender with server row 2. This
      // confirmation is never inferred from the label or equality of integer IDs.
      await refs.confirmGender(
        localUuid: 'local-e2e-gender',
        serverId: catalog.single.serverId,
        evidence: 'controlled fixture manifest selection confirmed',
      );
      final people = PetugasRepository(db);
      final id = await people.create(
        nama: 'E2E device',
        email: 'device@e2e.invalid',
        jenisKelamin: localGender,
      );
      final uuid = (await db.select(db.petugasLocals).getSingle()).uuid;
      await PetugasIdentityReconciliation(
        db,
        scope: scope,
      ).confirmLocalOnly(uuid, 'fixture created on this isolated device');
      var sync = PetugasLocalSyncRepository(
        db,
        PetugasSyncApi(dio),
        refs,
        scope: scope,
      );
      await sync.push(uuid);
      expect(
        (await (db.select(
          db.petugasLocals,
        )..where((r) => r.id.equals(id))).getSingle()).isSyncDirty,
        false,
      );
      expect(
        (await db
                .customSelect('SELECT pending FROM petugas_sync_journal')
                .getSingle())
            .readNullable<String>('pending'),
        isNull,
      );
      for (var i = 0; i < 50; i++) {
        await sync.pull();
        if ((await db.select(db.petugasLocals).get()).length == 2) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect((await db.select(db.petugasLocals).get()).length, 2);
      final cursor =
          (await db
                  .customSelect('SELECT cursor FROM petugas_sync_feed')
                  .getSingle())
              .read<int>('cursor');
      expect(cursor, greaterThan(0));
      await db.close();
      db = AppDatabase(NativeDatabase(File('${temp.path}/isolated.sqlite')));
      refs = VerifiedPetugasReferences(db, scope: scope);
      sync = PetugasLocalSyncRepository(
        db,
        PetugasSyncApi(dio),
        refs,
        scope: scope,
      );
      await sync.pull();
      expect(
        (await (db.select(
          db.petugasLocals,
        )..where((r) => r.id.equals(id))).getSingle()).uuid,
        uuid,
      );
      expect((await db.select(db.petugasLocals).get()).length, 2);
      expect(
        (await db
                .customSelect('SELECT cursor FROM petugas_sync_feed')
                .getSingle())
            .read<int>('cursor'),
        greaterThanOrEqualTo(cursor),
      );
    },
    skip: Platform.environment['NOTARIS_E2E_URL'] == null
        ? 'explicit isolated Go harness required'
        : false,
  );
}
