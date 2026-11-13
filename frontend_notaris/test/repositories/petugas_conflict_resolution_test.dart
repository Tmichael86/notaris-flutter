import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart' hide Fake;
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/repositories/people_repository.dart';
import 'package:frontend_notaris/repositories/petugas_identity_reconciliation.dart';
import 'package:frontend_notaris/repositories/petugas_sync_repository.dart';
import 'package:frontend_notaris/services/petugas_sync_api.dart';

import 'petugas_local_sync_test.dart' show Fake, Refs, reply;

void main() {
  late Directory temp;
  late AppDatabase db;
  late PetugasRepository people;
  late int id;
  late String uuid;
  const scope = 'deployment/account';
  const cloud = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  Map<String, dynamic> server([int version = 2]) => {
    'id': 91,
    'uuid': cloud,
    'row_version': version,
    'status': 1,
    'deleted_at': null,
    'nama': 'Server $version',
    'email': 'server@example.com',
    'jenis_kelamin_id': null,
    'user_id': null,
  };
  ResponseBody conflict([int version = 2]) => reply({
    'success': false,
    'message': 'Versi Petugas berbeda',
    'errors': {'code': 'version_conflict', 'current': server(version)},
  }, 409);
  PetugasLocalSyncRepository repo(
    Future<ResponseBody> Function(RequestOptions) callback,
  ) {
    final dio = Dio(BaseOptions(baseUrl: 'https://test/api/v1'))
      ..httpClientAdapter = Fake(callback);
    return PetugasLocalSyncRepository(
      db,
      PetugasSyncApi(dio),
      Refs(),
      scope: scope,
    );
  }

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('petugas-conflict-');
    db = AppDatabase(NativeDatabase(File('${temp.path}/db.sqlite')));
    people = PetugasRepository(db);
    id = await people.create(
      nama: 'Local original',
      email: 'local@example.com',
    );
    uuid = (await db.select(db.petugasLocals).getSingle()).uuid;
    await PetugasIdentityReconciliation(db, scope: scope).confirmVerified(
      localUuid: uuid,
      server: PetugasServerIdentity.fromRecord(server(1), scope: scope),
      evidence: 'operator confirmed pair',
    );
    await db
        .into(db.transaksis)
        .insert(
          TransaksisCompanion.insert(
            uuid: 'transaction-ref',
            noAkta: '1000000000001',
            total: 0,
            petugasId: Value(id),
            petugasUuid: Value(uuid),
          ),
        );
  });
  tearDown(() async {
    await db.close();
    await temp.delete(recursive: true);
  });
  Future<void> openConflict(PetugasLocalSyncRepository r) async {
    await expectLater(
      r.push(uuid),
      throwsA(
        isA<PetugasSyncFailure>().having(
          (e) => e.kind,
          'kind',
          PetugasSyncFailureKind.conflict,
        ),
      ),
    );
  }

  test(
    'new local decision can conflict again without losing original archive',
    () async {
      final r = repo((_) async => conflict());
      await openConflict(r);
      await r.chooseLocal(
        uuid,
        reviewedServerVersion: 2,
        reviewedLocalSnapshot: await r.currentLocalSnapshot(uuid),
        confirmed: true,
      );
      await openConflict(repo((_) async => conflict(3)));
      final rows = await db
          .customSelect('SELECT state FROM petugas_sync_conflict')
          .get();
      expect(rows.length, 2);
      expect(
        rows.map((r) => r.read<String>('state')),
        containsAll(['resolved_local', 'open']),
      );
      expect((await r.listConflicts()).single.baseVersion, 2);
      expect((await db.select(db.petugasLocals).get()).length, 1);
    },
  );
  test(
    'server tombstone blocks resurrection and can be chosen explicitly',
    () async {
      final canonical = {
        ...server(),
        'status': 0,
        'deleted_at': '2026-10-30T00:00:00Z',
      };
      final r = repo(
        (_) async => reply({
          'success': false,
          'errors': {'code': 'version_conflict', 'current': canonical},
        }, 409),
      );
      await openConflict(r);
      final snapshot = await r.currentLocalSnapshot(uuid);
      await expectLater(
        r.chooseLocal(
          uuid,
          reviewedServerVersion: 2,
          reviewedLocalSnapshot: snapshot,
          confirmed: true,
        ),
        throwsA(isA<PetugasSyncFailure>()),
      );
      await r.chooseServer(
        uuid,
        reviewedServerVersion: 2,
        reviewedLocalSnapshot: snapshot,
        confirmed: true,
      );
      final row = await db.select(db.petugasLocals).getSingle();
      expect(row.status, 0);
      expect(row.uuid, uuid);
      expect(row.isSyncDirty, false);
      expect((await db.select(db.transaksis).getSingle()).petugasUuid, uuid);
    },
  );
  test(
    'pull 410 preserves local data and nonzero cursor after restart',
    () async {
      await db.customStatement('UPDATE petugas_sync_feed SET cursor=29');
      final r = repo(
        (_) async => reply({
          'success': false,
          'errors': {'code': 'cursor_expired'},
        }, 410),
      );
      await expectLater(
        r.pull(),
        throwsA(
          isA<PetugasSyncFailure>().having(
            (e) => e.kind,
            'kind',
            PetugasSyncFailureKind.expired,
          ),
        ),
      );
      await db.close();
      db = AppDatabase(NativeDatabase(File('${temp.path}/db.sqlite')));
      final restarted = repo((_) async => throw StateError('no HTTP allowed'));
      expect(await restarted.recoveryStatus(), 'full_resync_required');
      expect(
        (await db
                .customSelect('SELECT cursor FROM petugas_sync_feed')
                .getSingle())
            .read<int>('cursor'),
        29,
      );
      expect((await db.select(db.petugasLocals).getSingle()).uuid, uuid);
      expect((await db.select(db.transaksis).getSingle()).petugasUuid, uuid);
      expect((await db.select(db.petugasIdentityMaps).get()).length, 1);
      await expectLater(restarted.pull(), throwsA(isA<PetugasSyncFailure>()));
    },
  );
  test('409 preserves mutation and dirty local record; conflict and snapshots survive restart', () async {
    final r = repo((_) async => conflict());
    await openConflict(r);
    final before = await db
        .customSelect('SELECT pending FROM petugas_sync_journal')
        .getSingle();
    expect((await db.select(db.petugasLocals).getSingle()).isSyncDirty, true);
    await db.close();
    db = AppDatabase(NativeDatabase(File('${temp.path}/db.sqlite')));
    final restarted = repo((_) async => throw StateError('no HTTP to inspect'));
    final c = (await restarted.listConflicts()).single;
    expect(c.serverRecord!['row_version'], 2);
    expect(c.localSnapshot['nama'], 'Local original');
    expect(c.baseVersion, 1);
    expect(
      (await db
              .customSelect('SELECT pending FROM petugas_sync_journal')
              .getSingle())
          .read<String>('pending'),
      before.read<String>('pending'),
    );
    await restarted.holdConflict(uuid, 'operator needs review');
    expect((await restarted.listConflicts()).single.state, 'held');
  });
  test(
    'choose server is explicit, preserves IDs and transaction and archive',
    () async {
      final r = repo((_) async => conflict());
      await openConflict(r);
      final local = await r.currentLocalSnapshot(uuid);
      await expectLater(
        r.chooseServer(
          uuid,
          reviewedServerVersion: 2,
          reviewedLocalSnapshot: local,
          confirmed: false,
        ),
        throwsArgumentError,
      );
      await r.chooseServer(
        uuid,
        reviewedServerVersion: 2,
        reviewedLocalSnapshot: local,
        confirmed: true,
      );
      final row = await db.select(db.petugasLocals).getSingle();
      expect(row.id, id);
      expect(row.uuid, uuid);
      expect(row.nama, 'Server 2');
      expect(row.isSyncDirty, false);
      final tx = await db.select(db.transaksis).getSingle();
      expect(tx.petugasId, id);
      expect(tx.petugasUuid, uuid);
      expect(await r.listConflicts(), isEmpty);
      final archived = await db
          .customSelect('SELECT local_snapshot FROM petugas_sync_conflict')
          .getSingle();
      expect(
        jsonDecode(archived.read<String>('local_snapshot'))['nama'],
        'Local original',
      );
    },
  );
  test('choose local creates new mutation at server version; timeout retry reuses it', () async {
    final r = repo((_) async => conflict());
    await openConflict(r);
    final old = (await r.listConflicts()).single.mutationId;
    await people.update(
      id: id,
      nama: 'Additional local edit',
      email: 'local@example.com',
    );
    await r.chooseLocal(
      uuid,
      reviewedServerVersion: 2,
      reviewedLocalSnapshot: await r.currentLocalSnapshot(uuid),
      confirmed: true,
    );
    final stored = await db
        .customSelect('SELECT pending FROM petugas_sync_journal')
        .getSingle();
    final mutation = jsonDecode(stored.read<String>('pending')) as Map;
    expect(mutation['mutation_id'], isNot(old));
    expect(mutation['expected_row_version'], 2);
    expect(mutation['payload']['nama'], 'Additional local edit');
    final timeout = repo((req) async {
      expect(req.data, mutation);
      throw DioException(
        requestOptions: req,
        type: DioExceptionType.receiveTimeout,
      );
    });
    await expectLater(timeout.push(uuid), throwsA(isA<PetugasSyncFailure>()));
    await repo((req) async {
      expect(req.data, mutation);
      return reply({
        'success': true,
        'data': {
          'acknowledgement': {
            'mutation_id': mutation['mutation_id'],
            'petugas_uuid': cloud,
            'server_id': 91,
            'row_version': 3,
            'tombstone': false,
          },
          'record': {'id': 91, 'uuid': cloud, 'row_version': 3},
        },
      });
    }).push(uuid);
    expect(
      (await db.select(db.petugasLocals).getSingle()).nama,
      'Additional local edit',
    );
    expect((await db.select(db.petugasLocals).get()).length, 1);
  });
  test('server changes during revalidation: refresh conflict and require new review', () async {
    final r = repo((_) async => conflict());
    await openConflict(r);
    final latest = repo((_) async => conflict(3));
    await expectLater(
      latest.chooseServer(
        uuid,
        reviewedServerVersion: 2,
        reviewedLocalSnapshot: await latest.currentLocalSnapshot(uuid),
        confirmed: true,
      ),
      throwsA(isA<PetugasSyncFailure>()),
    );
    expect(
      (await latest.listConflicts()).single.serverRecord!['row_version'],
      3,
    );
    expect(
      (await db.select(db.petugasLocals).getSingle()).nama,
      'Local original',
    );
  });
  test(
    'additional edit while revalidation request runs prevents overwrite',
    () async {
      await openConflict(repo((_) async => conflict()));
      final reviewed = (await db.select(db.petugasLocals).getSingle()).toJson();
      final r = repo((_) async {
        await people.update(
          id: id,
          nama: 'Changed during request',
          email: 'local@example.com',
        );
        return conflict();
      });
      await expectLater(
        r.chooseServer(
          uuid,
          reviewedServerVersion: 2,
          reviewedLocalSnapshot: reviewed,
          confirmed: true,
        ),
        throwsA(isA<PetugasSyncFailure>()),
      );
      expect(
        (await db.select(db.petugasLocals).getSingle()).nama,
        'Changed during request',
      );
      expect((await db.select(db.petugasLocals).getSingle()).isSyncDirty, true);
    },
  );
  test('410 persists blocked status and preserves nonzero cursor, mutation and transactions', () async {
    await openConflict(repo((_) async => conflict()));
    await db.customStatement('UPDATE petugas_sync_feed SET cursor=19');
    final pending =
        (await db
                .customSelect('SELECT pending FROM petugas_sync_journal')
                .getSingle())
            .read<String>('pending');
    // Revalidation is itself subject to a recovery block; never discard conflict.
    final r = repo(
      (_) async => reply({
        'success': false,
        'errors': {'code': 'cursor_expired'},
      }, 410),
    );
    await expectLater(
      r.chooseLocal(
        uuid,
        reviewedServerVersion: 2,
        reviewedLocalSnapshot: await r.currentLocalSnapshot(uuid),
        confirmed: true,
      ),
      throwsA(isA<PetugasSyncFailure>()),
    );
    await db.close();
    db = AppDatabase(NativeDatabase(File('${temp.path}/db.sqlite')));
    final restarted = repo(
      (_) async => throw StateError('blocked must avoid HTTP'),
    );
    expect(await restarted.recoveryStatus(), 'full_resync_required');
    expect((await restarted.listConflicts()).length, 1);
    final journal = await db
        .customSelect('SELECT pending FROM petugas_sync_journal')
        .getSingle();
    expect(journal.read<String>('pending'), pending);
    expect(
      (await db
              .customSelect('SELECT cursor FROM petugas_sync_feed')
              .getSingle())
          .read<int>('cursor'),
      19,
    );
    expect((await db.select(db.transaksis).get()).length, 1);
    await expectLater(restarted.push(uuid), throwsA(isA<PetugasSyncFailure>()));
  });
}
