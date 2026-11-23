import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/models/auth_session.dart';
import 'package:frontend_notaris/database/daos/pekerjaan_dao.dart';
import 'package:frontend_notaris/models/verified_demo_session.dart';
import 'package:frontend_notaris/repositories/recycle_bin_repository.dart';
import 'package:frontend_notaris/services/kategori_pekerjaan_api_service.dart';
import 'package:frontend_notaris/services/jenis_pengeluaran_api_service.dart';
import 'package:frontend_notaris/services/pemohon_api_service.dart';
import 'package:frontend_notaris/providers/auth_provider.dart';
import 'package:frontend_notaris/providers/database_provider.dart';
import 'package:frontend_notaris/providers/local_master_authorization_provider.dart';
import 'package:frontend_notaris/providers/people_provider.dart';
import 'package:frontend_notaris/providers/pekerjaan_provider.dart';
import 'package:frontend_notaris/repositories/pekerjaan_repository.dart';
import 'package:frontend_notaris/repositories/people_repository.dart';
import 'package:frontend_notaris/repositories/pekerjaan_kategori_repository.dart';
import 'package:frontend_notaris/repositories/pengeluaran_jenis_repository.dart';

import '../support/local_master_test_authority.dart';

Future<String> masterSnapshot(AppDatabase db) async {
  final tables = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
      )
      .get();
  final result = <String, Object?>{};
  for (final t in tables) {
    final name = t.read<String>('name');
    result[name] =
        (await db
                .customSelect('SELECT * FROM "${name.replaceAll('"', '""')}"')
                .get())
            .map((r) => jsonEncode(r.data))
            .toList()
          ..sort();
  }
  return jsonEncode(result);
}

PekerjaanAggregateInput masterInput([String name = 'Changed']) =>
    PekerjaanAggregateInput(
      nama: name,
      harga: const [
        PekerjaanHargaInput(
          harga: '100',
          kategoriPekerjaanId: 1,
          estimasiWaktu: '1 hari',
        ),
      ],
      proses: const [
        PekerjaanProsesInput(
          nama: 'Proses',
          detail: 'Berkas',
          atribut: [PekerjaanAtributInput(atribut: 'KTP')],
        ),
      ],
    );
Future<void> seedMasters(AppDatabase db) async {
  await db.customStatement(
    "INSERT INTO pekerjaan_kategori(id,uuid,nama) VALUES(1,'category','Baseline')",
  );
  await db.customStatement(
    "INSERT INTO pengeluaran_jenis(id,uuid,nama) VALUES(1,'expense','Baseline')",
  );
  await db.customStatement(
    "INSERT INTO petugas(id,uuid,nama,email) VALUES(1,'officer','Baseline','fixture@example.invalid')",
  );
  await db.customStatement(
    "INSERT INTO pemohons(id,uuid,nama) VALUES(1,'applicant','Baseline')",
  );
  for (final d in ['notaris', 'ppat']) {
    await db.customStatement(
      "INSERT INTO pekerjaan_$d(id,uuid,nama) VALUES(1,'job-$d','Baseline')",
    );
    await db.customStatement(
      "INSERT INTO pekerjaan_${d}_harga(uuid,pekerjaan_${d}_id,harga,kategori_pekerjaan_id,estimasi_waktu) VALUES('price-$d',1,'100',1,'1 hari')",
    );
    await db.customStatement(
      "INSERT INTO pekerjaan_${d}_proses(id,uuid,pekerjaan_${d}_id,nama,detail) VALUES(1,'process-$d',1,'Proses','Berkas')",
    );
    await db.customStatement(
      "INSERT INTO pekerjaan_${d}_atributs(uuid,pekerjaan_${d}_id,proses_pekerjaan_${d}_id,atribut) VALUES('attribute-$d',1,1,'KTP')",
    );
  }
  await db.customStatement(
    "INSERT INTO transaksis(uuid,no_akta,total) VALUES('protected-tx','PROTECTED',1000)",
  );
  await db.customStatement(
    "INSERT INTO transaction_cloud_identity VALUES('protected-tx','protected-tx','protected',1,'PROTECTED','{}')",
  );
  await db.customStatement(
    "INSERT INTO transaction_cloud_pending(local_uuid,mutation_id,payload,state) VALUES('protected-tx','protected-mutation','{}','acked')",
  );
  await db.customStatement(
    "INSERT INTO transaction_cloud_feed VALUES('protected',9)",
  );
}

Future<Object?> repositoryCall(
  AppDatabase db,
  LocalMasterAuthorization? auth,
  MasterModule m,
  MasterAction action,
) async {
  switch (m) {
    case MasterModule.notaris:
      final r = PekerjaanNotarisRepository(
        db.pekerjaanDao,
        authorization: auth,
      );
      return switch (action) {
        MasterAction.create => r.createAggregate(input: masterInput('New')),
        MasterAction.update => r.updateAggregate(id: 1, input: masterInput()),
        MasterAction.delete => r.deleteAggregate(1),
        _ => throw StateError('not write'),
      };
    case MasterModule.ppat:
      final r = PekerjaanPpatRepository(db.pekerjaanDao, authorization: auth);
      return switch (action) {
        MasterAction.create => r.createAggregate(input: masterInput('New')),
        MasterAction.update => r.updateAggregate(id: 1, input: masterInput()),
        MasterAction.delete => r.deleteAggregate(1),
        _ => throw StateError('not write'),
      };
    case MasterModule.category:
      final r = PekerjaanKategoriRepository(db, authorization: auth);
      return switch (action) {
        MasterAction.create => r.create(nama: 'New'),
        MasterAction.update => r.update(id: 1, nama: 'Changed'),
        MasterAction.delete => r.delete(1),
        _ => throw StateError('not write'),
      };
    case MasterModule.expenseType:
      final r = PengeluaranJenisRepository(db, authorization: auth);
      return switch (action) {
        MasterAction.create => r.create(nama: 'New'),
        MasterAction.update => r.update(id: 1, nama: 'Changed'),
        MasterAction.delete => r.delete(1),
        _ => throw StateError('not write'),
      };
    case MasterModule.officer:
      final r = PetugasRepository(db, authorization: auth);
      return switch (action) {
        MasterAction.create => r.create(
          nama: 'New',
          email: 'new@example.invalid',
        ),
        MasterAction.update => r.update(
          id: 1,
          nama: 'Changed',
          email: 'changed@example.invalid',
        ),
        MasterAction.delete => r.delete(1),
        _ => throw StateError('not write'),
      };
    case MasterModule.applicant:
      final r = PemohonRepository(db, authorization: auth);
      return switch (action) {
        MasterAction.create => r.create(nama: 'New'),
        MasterAction.update => r.update(id: 1, nama: 'Changed'),
        MasterAction.delete => r.delete(1),
        _ => throw StateError('not write'),
      };
  }
}

Future<Object?> controllerCall(
  ProviderContainer c,
  MasterModule m,
  MasterAction a,
) async {
  switch (m) {
    case MasterModule.notaris:
      final r = c.read(pekerjaanNotarisControllerProvider.notifier);
      return switch (a) {
        MasterAction.create => r.create(input: masterInput('New')),
        MasterAction.update => r.updateAggregate(id: 1, input: masterInput()),
        _ => r.delete(1),
      };
    case MasterModule.ppat:
      final r = c.read(pekerjaanPpatControllerProvider.notifier);
      return switch (a) {
        MasterAction.create => r.create(input: masterInput('New')),
        MasterAction.update => r.updateAggregate(id: 1, input: masterInput()),
        _ => r.delete(1),
      };
    case MasterModule.category:
      final r = c.read(pekerjaanKategoriControllerProvider.notifier);
      return switch (a) {
        MasterAction.create => r.create(nama: 'New'),
        MasterAction.update => r.updateCategory(id: 1, nama: 'Changed'),
        _ => r.delete(1),
      };
    case MasterModule.expenseType:
      final r = c.read(pengeluaranJenisControllerProvider.notifier);
      return switch (a) {
        MasterAction.create => r.create(nama: 'New'),
        MasterAction.update => r.updateJenis(id: 1, nama: 'Changed'),
        _ => r.delete(1),
      };
    case MasterModule.officer:
      final r = c.read(petugasControllerProvider.notifier);
      return switch (a) {
        MasterAction.create => r.create(
          nama: 'New',
          email: 'new@example.invalid',
        ),
        MasterAction.update => r.updatePetugas(
          id: 1,
          nama: 'Changed',
          email: 'changed@example.invalid',
        ),
        _ => r.delete(1),
      };
    case MasterModule.applicant:
      final r = c.read(pemohonControllerProvider.notifier);
      return switch (a) {
        MasterAction.create => r.create(nama: 'New'),
        MasterAction.update => r.updatePemohon(id: 1, nama: 'Changed'),
        _ => r.delete(1),
      };
  }
}

void main() {
  late AppDatabase db;
  late AuthSession? session;
  late AppDatabase? active;
  late LocalMasterAuthorization auth;
  setUp(() async {
    db = AppDatabase.forTesting(
      NativeDatabase.memory(setup: (s) => s.execute('PRAGMA foreign_keys=ON')),
    );
    active = db;
    session = masterTestSession();
    auth = masterTestAuthority(
      db,
      session: () => session,
      active: () => active,
    );
    await seedMasters(db);
  });
  tearDown(() => db.close());
  for (final module in MasterModule.values) {
    for (final grants in [
      <String>[],
      ['create'],
      ['update'],
      ['delete'],
      ['create', 'update', 'delete'],
    ]) {
      test('${module.code} direct controller action matrix $grants', () async {
        final actor = MasterTestAuth(masterTestSession(actions: grants));
        final c = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            authControllerProvider.overrideWith((ref) => actor),
          ],
        );
        addTearDown(c.dispose);
        for (final action in [
          MasterAction.create,
          MasterAction.update,
          MasterAction.delete,
        ]) {
          final before = await masterSnapshot(db);
          if (grants.contains(action.name)) {
            await controllerCall(c, module, action);
          } else {
            await expectLater(
              controllerCall(c, module, action),
              throwsA(isA<LocalMasterDenied>()),
            );
            expect(await masterSnapshot(db), before);
          }
        }
      });
      test('${module.code} direct repository action matrix $grants', () async {
        session = masterTestSession(actions: grants);
        for (final action in [
          MasterAction.create,
          MasterAction.update,
          MasterAction.delete,
        ]) {
          final before = await masterSnapshot(db);
          if (grants.contains(action.name)) {
            await repositoryCall(db, auth, module, action);
          } else {
            await expectLater(
              repositoryCall(db, auth, module, action),
              throwsA(isA<LocalMasterDenied>()),
            );
            expect(await masterSnapshot(db), before);
          }
        }
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      });
    }
    test(
      '${module.code} absent/malformed/mismatched/expired/no grants deny every mutation unchanged',
      () async {
        final bad = [
          null,
          AuthSession(
            token: 'invalid',
            userId: 1,
            groupId: 1,
            userName: 'x',
            groupName: 'x',
            user: const {},
            sidebars: masterTestSession().sidebars,
            verifiedAt: DateTime.now(),
          ),
          AuthSession(
            token: masterTestToken(expired: true),
            userId: 1,
            groupId: 1,
            userName: 'x',
            groupName: 'x',
            user: const {},
            sidebars: masterTestSession().sidebars,
            verifiedAt: DateTime.now(),
          ),
          AuthSession(
            token: masterTestToken(uid: 2),
            userId: 1,
            groupId: 1,
            userName: 'x',
            groupName: 'x',
            user: const {},
            sidebars: masterTestSession().sidebars,
            verifiedAt: DateTime.now(),
          ),
          AuthSession(
            token: masterTestToken(),
            userId: 1,
            groupId: 1,
            userName: 'x',
            groupName: 'x',
            user: const {},
            sidebars: const [],
            verifiedAt: DateTime.now(),
          ),
        ];
        final before = await masterSnapshot(db);
        for (final value in bad) {
          session = value;
          for (final a in [
            MasterAction.create,
            MasterAction.update,
            MasterAction.delete,
          ]) {
            await expectLater(
              repositoryCall(db, auth, module, a),
              throwsA(isA<LocalMasterDenied>()),
            );
            expect(await masterSnapshot(db), before);
          }
        }
        session = masterTestSession();
        active = null;
        await expectLater(
          repositoryCall(db, auth, module, MasterAction.create),
          throwsA(isA<LocalMasterDenied>()),
        );
        expect(await masterSnapshot(db), before);
        await expectLater(
          repositoryCall(db, null, module, MasterAction.delete),
          throwsA(isA<LocalMasterDenied>()),
        );
        expect(await masterSnapshot(db), before);
      },
    );
    test(
      '${module.code} direct controller read-only denied, editor allowed, logout denied',
      () async {
        final actor = MasterTestAuth(masterTestSession(actions: []));
        final c = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            authControllerProvider.overrideWith((ref) => actor),
          ],
        );
        addTearDown(c.dispose);
        final before = await masterSnapshot(db);
        for (final a in [
          MasterAction.create,
          MasterAction.update,
          MasterAction.delete,
        ]) {
          await expectLater(
            controllerCall(c, module, a),
            throwsA(isA<LocalMasterDenied>()),
          );
          expect(await masterSnapshot(db), before);
        }
        actor.replace(masterTestSession());
        await controllerCall(c, module, MasterAction.create);
        await controllerCall(c, module, MasterAction.update);
        actor.replace(null);
        final after = await masterSnapshot(db);
        await expectLater(
          controllerCall(c, module, MasterAction.delete),
          throwsA(isA<LocalMasterDenied>()),
        );
        expect(await masterSnapshot(db), after);
      },
    );
    test(
      '${module.code} queued logout/revocation/profile switch rolls back and valid offline allowed',
      () async {
        final before = await masterSnapshot(db);
        final entered = Completer<void>(), release = Completer<void>();
        final holder = db.transaction(() async {
          entered.complete();
          await release.future;
        });
        await entered.future;
        final attempt = repositoryCall(db, auth, module, MasterAction.update);
        final expectation = expectLater(
          attempt,
          throwsA(isA<LocalMasterDenied>()),
        );
        session = masterTestSession(uid: 2, actions: []);
        release.complete();
        await holder;
        await expectation;
        expect(await masterSnapshot(db), before);
        session = masterTestSession(offline: true);
        await repositoryCall(db, auth, module, MasterAction.update);
      },
    );
  }
  test('legacy parent entrypoints cannot bypass aggregate auth; create UUID collision cannot overwrite', () async {
    session = masterTestSession(actions: []);
    final before = await masterSnapshot(db);
    for (final d in [false, true]) {
      final dynamic r = d
          ? PekerjaanPpatRepository(db.pekerjaanDao, authorization: auth)
          : PekerjaanNotarisRepository(db.pekerjaanDao, authorization: auth);
      await expectLater(
        r.create(uuid: const Uuid().v4(), nama: 'x') as Future,
        throwsA(isA<LocalMasterDenied>()),
      );
      await expectLater(
        r.updateNama(id: 1, nama: 'x') as Future,
        throwsA(isA<LocalMasterDenied>()),
      );
    }
    expect(await masterSnapshot(db), before);
    session = masterTestSession(actions: ['create']);
    await expectLater(
      PekerjaanNotarisRepository(
        db.pekerjaanDao,
        authorization: auth,
      ).create(uuid: 'job-notaris', nama: 'overwrite'),
      throwsA(anything),
    );
    expect(await masterSnapshot(db), before);
  });
  test(
    'business validation and concurrent duplicate create remain atomic',
    () async {
      final r = PekerjaanKategoriRepository(db, authorization: auth);
      final results = await Future.wait([
        for (var i = 0; i < 2; i++)
          r
              .create(nama: 'Concurrent')
              .then<Object>((id) => id, onError: (Object e) => e),
      ]);
      expect(results.whereType<int>().length, 1);
      expect(results.whereType<ArgumentError>().length, 1);
      final before = await masterSnapshot(db);
      await expectLater(
        PekerjaanNotarisRepository(
          db.pekerjaanDao,
          authorization: auth,
        ).createAggregate(
          input: const PekerjaanAggregateInput(
            nama: 'Invalid',
            harga: [],
            proses: [],
          ),
        ),
        throwsArgumentError,
      );
      expect(await masterSnapshot(db), before);
    },
  );
  for (final module in MasterModule.values) {
    test(
      '${module.code} parent/name/role/duplicate/inactive grants are not authority',
      () async {
        final source = masterTestSession();
        AuthSession withGrants(
          List<Map<String, dynamic>> grants, {
          Map<String, dynamic>? user,
        }) => AuthSession(
          token: source.token,
          userId: 1,
          groupId: 1,
          userName: 'Admin',
          groupName: 'Superadmin',
          groupType: 'superadmin',
          user: user ?? {},
          sidebars: grants,
          verifiedAt: source.verifiedAt,
        );
        final grant = source.sidebars.firstWhere(
          (g) => (g['sidebar'] as Map)['sidebar_kode'] == module.code,
        );
        final variants = [
          withGrants([]),
          withGrants([
            {
              ...grant,
              'sidebar': {'sidebar_kode': 'master', 'status': 1},
            },
          ]),
          withGrants([
            {
              ...grant,
              'sidebar': {'sidebar_nama': module.code, 'status': 1},
            },
          ]),
          withGrants([grant, grant]),
          withGrants([
            {
              ...grant,
              'sidebar': {'sidebar_kode': module.code, 'status': 0},
            },
          ]),
          withGrants([
            {
              ...grant,
              'sidebar': {
                'sidebar_kode': module.code,
                'status': 1,
                'sidebar_route': '#',
              },
            },
          ]),
          withGrants([grant], user: {'status': 0}),
          withGrants([grant], user: {'group_status': 0}),
          withGrants([grant], user: {'group_id': 2}),
          withGrants([
            {...grant, 'read': 0},
          ]),
        ];
        final before = await masterSnapshot(db);
        for (final variant in variants) {
          session = variant;
          for (final action in [
            MasterAction.create,
            MasterAction.update,
            MasterAction.delete,
          ]) {
            await expectLater(
              repositoryCall(db, auth, module, action),
              throwsA(isA<LocalMasterDenied>()),
            );
            expect(await masterSnapshot(db), before);
          }
        }
      },
    );
    test(
      '${module.code} queued profile switch and logout leave all tables unchanged',
      () async {
        for (final profileChange in [true, false]) {
          active = db;
          session = masterTestSession();
          final before = await masterSnapshot(db);
          final entered = Completer<void>(), release = Completer<void>();
          final holder = db.transaction(() async {
            entered.complete();
            await release.future;
          });
          await entered.future;
          final attempt = expectLater(
            repositoryCall(db, auth, module, MasterAction.update),
            throwsA(isA<LocalMasterDenied>()),
          );
          if (profileChange) {
            active = null;
          } else {
            session = null;
          }
          release.complete();
          await holder;
          await attempt;
          expect(await masterSnapshot(db), before);
        }
      },
    );
  }
  for (final ppat in [false, true]) {
    for (final cause in ['grant', 'account', 'profile']) {
      test(
        '${ppat ? "PPAT" : "Notaris"} mid-aggregate $cause change rolls back parent and child',
        () async {
          final before = await masterSnapshot(db);
          final original = session!;
          final dao = _RevokingDao(db, () {
            if (cause == 'grant') {
              original.sidebars.firstWhere(
                (g) =>
                    (g['sidebar'] as Map)['sidebar_kode'] ==
                    (ppat ? 'pekerjaan_ppat' : 'pekerjaan_notaris'),
              )['create'] = 0;
            } else if (cause == 'account') {
              session = masterTestSession(uid: 2);
            } else {
              active = null;
            }
          });
          final attempt = ppat
              ? PekerjaanPpatRepository(
                  dao,
                  authorization: auth,
                ).createAggregate(input: masterInput('Never committed'))
              : PekerjaanNotarisRepository(
                  dao,
                  authorization: auth,
                ).createAggregate(input: masterInput('Never committed'));
          await expectLater(attempt, throwsA(isA<LocalMasterDenied>()));
          expect(await masterSnapshot(db), before);
          expect(
            (await db.customSelect('PRAGMA integrity_check').getSingle())
                .data
                .values
                .single,
            'ok',
          );
        },
      );
    }
    test(
      '${ppat ? "PPAT" : "Notaris"} Master Restore requires UPDATE and denied call writes no history',
      () async {
        final module = ppat ? MasterModule.ppat : MasterModule.notaris;
        await repositoryCall(db, auth, module, MasterAction.delete);
        final r = RecycleBinRepository(
          db,
          () => session,
          masterAuthorization: auth,
        );
        final record = (await r.list(
          module: ppat ? RecycleModule.ppat : RecycleModule.notaris,
        )).single;
        session = masterTestSession(actions: []);
        final before = await masterSnapshot(db);
        await expectLater(r.restore(record), throwsA(isA<RestoreFailure>()));
        expect(await masterSnapshot(db), before);
        session = masterTestSession(actions: ['update']);
        await r.restore(record);
        final row = await db
            .customSelect(
              'SELECT status,deleted_at FROM pekerjaan_${ppat ? "ppat" : "notaris"} WHERE id=1',
            )
            .getSingle();
        expect(row.data['status'], 1);
        expect(row.data['deleted_at'], isNull);
      },
    );
  }
  test(
    'verified demo sessions require exact profile and live expiry',
    () async {
      final original = masterTestSession();
      final before = await masterSnapshot(db);
      for (final variant in [
        ExpiringPaymentDemoSession(
          original,
          DateTime.now().add(const Duration(hours: 1)),
          profileId: 'other',
        ),
        ExpiringPaymentDemoSession(
          original,
          DateTime.now().subtract(const Duration(seconds: 1)),
          profileId: 'owned',
        ),
      ]) {
        session = variant;
        final bound = LocalMasterAuthorization(
          database: db,
          currentDatabase: () => active,
          session: () => session,
          profileId: 'owned',
        );
        await expectLater(
          repositoryCall(db, bound, MasterModule.category, MasterAction.create),
          throwsA(isA<LocalMasterDenied>()),
        );
        expect(await masterSnapshot(db), before);
      }
      session = ExpiringPaymentDemoSession(
        original,
        DateTime.now().add(const Duration(hours: 1)),
        profileId: 'owned',
      );
      final bound = LocalMasterAuthorization(
        database: db,
        currentDatabase: () => active,
        session: () => session,
        profileId: 'owned',
      );
      await repositoryCall(
        db,
        bound,
        MasterModule.category,
        MasterAction.create,
      );
    },
  );
  test('untrusted cache upserts classify actual CREATE UPDATE DELETE and rollback whole batch', () async {
    Future<void> merge(String kind, String uuid, {int status = 1}) =>
        switch (kind) {
          'category' =>
            PekerjaanKategoriRepository(db, authorization: auth).syncFromCloud([
              KategoriPekerjaanApiModel(
                id: 1,
                uuid: uuid,
                nama: 'Cache',
                status: status,
              ),
            ]),
          'expense' =>
            PengeluaranJenisRepository(db, authorization: auth).syncFromCloud([
              JenisPengeluaranApiModel(
                id: 1,
                uuid: uuid,
                nama: 'Cache',
                status: status,
              ),
            ]),
          _ => PemohonRepository(db, authorization: auth).syncFromCloud([
            PemohonApiModel(id: 1, uuid: uuid, nama: 'Cache', status: status),
          ]),
        };
    for (final kind in ['category', 'expense', 'applicant']) {
      session = masterTestSession(actions: ['delete']);
      var before = await masterSnapshot(db);
      await expectLater(
        merge(kind, 'new-deleted-$kind', status: 0),
        throwsA(isA<LocalMasterDenied>()),
      );
      expect(await masterSnapshot(db), before);
      session = masterTestSession(actions: ['update']);
      before = await masterSnapshot(db);
      await expectLater(
        merge(kind, 'new-$kind'),
        throwsA(isA<LocalMasterDenied>()),
      );
      expect(await masterSnapshot(db), before);
      session = masterTestSession(actions: ['create']);
      await merge(kind, 'new-$kind');
      before = await masterSnapshot(db);
      await expectLater(
        merge(kind, 'new-$kind'),
        throwsA(isA<LocalMasterDenied>()),
      );
      expect(await masterSnapshot(db), before);
      session = masterTestSession(actions: ['update']);
      await merge(kind, 'new-$kind');
      before = await masterSnapshot(db);
      await expectLater(
        merge(kind, 'new-$kind', status: 0),
        throwsA(isA<LocalMasterDenied>()),
      );
      expect(await masterSnapshot(db), before);
      session = masterTestSession(actions: ['delete']);
      await merge(kind, 'new-$kind', status: 0);
    }
    session = masterTestSession(actions: ['create']);
    final before = await masterSnapshot(db);
    await expectLater(
      PekerjaanKategoriRepository(db, authorization: auth).syncFromCloud(const [
        KategoriPekerjaanApiModel(
          id: 9,
          uuid: 'partial-new',
          nama: 'Never committed',
        ),
        KategoriPekerjaanApiModel(
          id: 10,
          uuid: 'partial-new',
          nama: 'Overwrite requires UPDATE',
        ),
      ]),
      throwsA(isA<LocalMasterDenied>()),
    );
    expect(await masterSnapshot(db), before);
  });
  test(
    'READ-only empty or dirty-skipped Pemohon cache cannot seed reference data',
    () async {
      session = masterTestSession(actions: []);
      final r = PemohonRepository(db, authorization: auth);
      final before = await masterSnapshot(db);
      await r.syncFromCloud([]);
      await r.syncFromCloud(const [
        PemohonApiModel(id: 1, uuid: 'applicant', nama: 'Ignored dirty'),
      ]);
      expect(await masterSnapshot(db), before);
    },
  );
  test('denied mutation survives database reopening without writes', () async {
    final folder = await Directory.systemTemp.createTemp('h02-denied-reopen-');
    final file = File('${folder.path}/owned.sqlite');
    var disk = AppDatabase.forTesting(NativeDatabase(file));
    try {
      await seedMasters(disk);
      final before = await masterSnapshot(disk);
      final denied = masterTestAuthority(
        disk,
        session: () => masterTestSession(actions: []),
      );
      await expectLater(
        PekerjaanKategoriRepository(
          disk,
          authorization: denied,
        ).create(nama: 'Rejected'),
        throwsA(isA<LocalMasterDenied>()),
      );
      await disk.close();
      disk = AppDatabase.forTesting(NativeDatabase(file));
      expect(await masterSnapshot(disk), before);
    } finally {
      await disk.close();
      await folder.delete(recursive: true);
    }
  });
  for (final kind in ['category', 'expense', 'applicant']) {
    test(
      '$kind legacy ACK cannot clear dirty after in-place CREATE revocation',
      () async {
        session = masterTestSession(actions: ['create']);
        final actor = session!;
        final module = switch (kind) {
          'category' => MasterModule.category,
          'expense' => MasterModule.expenseType,
          _ => MasterModule.applicant,
        };
        var calls = 0;
        void revoke() {
          calls++;
          actor.sidebars.firstWhere(
            (g) => (g['sidebar'] as Map)['sidebar_kode'] == module.code,
          )['create'] = 0;
        }

        final before = await masterSnapshot(db);
        final Future<Object?> pending = switch (kind) {
          'category' => PekerjaanKategoriRepository(
            db,
            authorization: auth,
          ).syncToCloud(_CategoryAck(revoke)),
          'expense' => PengeluaranJenisRepository(
            db,
            authorization: auth,
          ).syncToCloud(_ExpenseAck(revoke)),
          _ => PemohonRepository(
            db,
            authorization: auth,
          ).syncToCloud(_ApplicantAck(revoke)),
        };
        await expectLater(pending, throwsA(isA<LocalMasterDenied>()));
        expect(calls, 1);
        expect(await masterSnapshot(db), before);
      },
    );
  }
}

class _RevokingDao extends PekerjaanDao {
  _RevokingDao(super.db, this.revoke);
  final void Function() revoke;
  @override
  Future<int> insertHargaNotaris(
    PekerjaanNotarisHargaLocalsCompanion entry,
  ) async {
    final id = await super.insertHargaNotaris(entry);
    revoke();
    return id;
  }

  @override
  Future<int> insertHargaPpat(PekerjaanPpatHargaLocalsCompanion entry) async {
    final id = await super.insertHargaPpat(entry);
    revoke();
    return id;
  }
}

// API doubles acknowledge a request; no real transport or publication is used.
class _CategoryAck extends KategoriPekerjaanApiService {
  _CategoryAck(this.revoke) : super(Dio());
  final void Function() revoke;
  @override
  Future<KategoriPekerjaanApiModel> syncUpsert({
    required String uuid,
    required String nama,
  }) async {
    revoke();
    return KategoriPekerjaanApiModel(id: 1, uuid: uuid, nama: nama);
  }
}

class _ExpenseAck extends JenisPengeluaranApiService {
  _ExpenseAck(this.revoke) : super(Dio());
  final void Function() revoke;
  @override
  Future<JenisPengeluaranApiModel> syncUpsert({
    required String uuid,
    required String nama,
  }) async {
    revoke();
    return JenisPengeluaranApiModel(id: 1, uuid: uuid, nama: nama);
  }
}

class _ApplicantAck extends PemohonApiService {
  _ApplicantAck(this.revoke) : super(Dio());
  final void Function() revoke;
  @override
  Future<PemohonApiModel> syncUpsert({
    required String uuid,
    required String nama,
    String? alamat,
    String? jenisKelaminNama,
    int? jenisKelamin,
    String? noTelp,
    String? nik,
  }) async {
    revoke();
    return PemohonApiModel(id: 1, uuid: uuid, nama: nama);
  }
}
