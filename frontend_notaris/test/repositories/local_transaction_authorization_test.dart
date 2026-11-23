import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/models/auth_session.dart';
import 'package:frontend_notaris/models/verified_demo_session.dart';
import 'package:frontend_notaris/providers/auth_provider.dart';
import 'package:frontend_notaris/providers/database_provider.dart';
import 'package:frontend_notaris/providers/transaction_provider.dart';
import 'package:frontend_notaris/repositories/recycle_bin_repository.dart';
import 'package:frontend_notaris/repositories/transaction_repository.dart';
import 'package:frontend_notaris/repositories/transaksi_proses_repository.dart';
import 'package:frontend_notaris/repositories/materai_stock_repository.dart';
import 'package:frontend_notaris/services/local_master_authorization.dart';
import 'package:frontend_notaris/services/local_transaction_authorization.dart';
import 'package:frontend_notaris/services/release_qa_profile.dart';
import 'package:sqlite3/sqlite3.dart' as native;

import '../support/local_master_test_authority.dart';
import '../support/transaction_test_authority.dart';
import '../support/materai_stock_fixture.dart';
import '../support/penghasilan_fixture.dart';
import 'local_master_authorization_test.dart' show masterSnapshot;
import 'recycle_bin_repository_test.dart' show seedTransaction;

void main() {
  late AppDatabase db;
  late native.Database raw;
  AppDatabase? active;
  AuthSession? session;
  late LocalTransactionAuthorization authority;
  late TransactionRepository repo;
  late Map<String, int> ids;
  String? revokeAfterSql;
  void Function()? revoke;

  setUp(() async {
    db = ReleaseQaDatabase(
      NativeDatabase.memory(
        setup: (connection) {
          raw = connection;
          raw.execute('PRAGMA foreign_keys=ON');
        },
      ),
    );
    active = db;
    session = transactionTestSession();
    authority = LocalTransactionAuthorization(
      LocalMasterAuthorization(
        database: db,
        currentDatabase: () => active,
        session: () {
          if (revokeAfterSql != null &&
              raw.select(revokeAfterSql!).isNotEmpty) {
            revokeAfterSql = null;
            revoke!();
          }
          return session;
        },
      ),
    );
    repo = TransactionRepository(db, authorization: authority);
    ids = {
      for (final domain in ['notaris', 'ppat'])
        domain: await seedTransaction(db, domain),
    };
    await db.customStatement(
      "INSERT INTO transaction_cloud_feed(scope,cursor) VALUES('protected',9)",
    );
    revokeAfterSql = null;
  });
  tearDown(() => db.close());

  Future<int> save(
    String domain, {
    int? id,
    String? note,
    TransactionRepository? via,
    AuthSession? expected,
  }) => (via ?? repo).save(
    id: id,
    nomorTransaksi: id == ids[domain]
        ? '${domain == 'notaris' ? 1 : 2}000611260001'
        : 'H03-NEW-$domain',
    jenisTransaksi: domain,
    pemohonId: 1,
    pemohonUuid: 'applicant',
    petugasId: 1,
    petugasUuid: 'officer',
    status: 'Dalam Proses',
    tanggalTransaksi: DateTime(2026, 11, 6),
    pembayaranSekarang: id == null ? 25 : 0,
    catatan: note,
    expectedSession: expected,
    jobs: [
      TransactionJobInput(
        jenisPekerjaan: domain,
        namaPekerjaan: 'Same label',
        biayaLayanan: 100,
        pekerjaanNotarisId: domain == 'notaris' ? 1 : null,
        pekerjaanPpatId: domain == 'ppat' ? 1 : null,
        detailUuid: id == ids[domain]
            ? 'detail-$domain'
            : 'h03-new-detail-$domain',
        prosesSnapshot: jsonEncode([
          {
            'id': 'h03',
            'name': 'Periksa',
            'attributes': ['KTP'],
          },
        ]),
      ),
    ],
  );
  Future<void> unchanged(Future<Object?> Function() call) async {
    final before = await masterSnapshot(db);
    await expectLater(
      Future.sync(call),
      throwsA(isA<LocalTransactionDenied>()),
    );
    expect(await masterSnapshot(db), before);
  }

  for (final domain in ['notaris', 'ppat']) {
    for (final action in ['create', 'update', 'delete']) {
      test(
        'direct $domain $action without context is denied, all SQLite rows preserved',
        () async {
          final unbound = TransactionRepository(db);
          await unchanged(
            () => action == 'delete'
                ? unbound.delete(ids[domain]!)
                : save(
                    domain,
                    via: unbound,
                    id: action == 'update' ? ids[domain] : null,
                  ),
          );
        },
      );
      for (final role in ['read', 'create', 'update', 'delete']) {
        test(
          '$domain $role-only grants enforce actual $action operation',
          () async {
            session = transactionTestSession(
              actions: ['read', if (role != 'read') role],
            );
            Future<Object?> call() => action == 'delete'
                ? repo.delete(ids[domain]!)
                : save(domain, id: action == 'update' ? ids[domain] : null);
            if (role == action) {
              await call();
            } else {
              await unchanged(call);
            }
          },
        );
      }
      for (final cause in ['grant', 'account', 'profile']) {
        test(
          '$domain $action $cause change after SQL rolls back aggregate and audit',
          () async {
            final original = session!;
            final field = action == 'create'
                ? "no_akta='H03-NEW-$domain'"
                : action == 'delete'
                ? 'id=${ids[domain]} AND deleted_at IS NOT NULL'
                : "id=${ids[domain]} AND catatan='revocation marker'";
            revokeAfterSql = 'SELECT 1 FROM transaksis WHERE $field';
            revoke = () {
              if (cause == 'grant') {
                original.sidebars.single[action] = 0;
              } else if (cause == 'account') {
                session = transactionTestSession(uid: 2);
              } else {
                active = null;
              }
            };
            await unchanged(
              () => action == 'delete'
                  ? repo.delete(ids[domain]!)
                  : save(
                      domain,
                      id: action == 'update' ? ids[domain] : null,
                      note: 'revocation marker',
                    ),
            );
          },
        );
      }
    }
    test(
      '$domain authorized CRUD/restore keeps child UUIDs, process and payment history',
      () async {
        final id = await save(domain);
        final parent = (await repo.findById(id))!;
        final detail = (await repo.watchDetailsOnce(id)).single;
        final payments = await repo.getPaymentHistory(id);
        await save(domain, id: id, note: 'authorized edit');
        expect((await repo.watchDetailsOnce(id)).single.uuid, detail.uuid);
        await repo.delete(id);
        final bin = RecycleBinRepository(
          db,
          () => session,
          transactionAuthorization: authority,
        );
        final record = (await bin.list()).singleWhere(
          (r) => r.uuid == parent.uuid,
        );
        session = transactionTestSession(actions: ['read']);
        final before = await masterSnapshot(db);
        await expectLater(bin.restore(record), throwsA(isA<RestoreFailure>()));
        expect(await masterSnapshot(db), before);
        session = transactionTestSession(actions: ['read', 'update']);
        await bin.restore(record);
        expect((await repo.findById(id))!.uuid, parent.uuid);
        expect((await repo.watchDetailsOnce(id)).single.id, detail.id);
        expect(await repo.getPaymentHistory(id), payments);
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      },
    );
  }

  test('missing/malformed session or canonical grant, aliases and superadmin labels fail closed', () async {
    final valid = session!;
    final variants = <AuthSession?>[
      null,
      transactionTestSession(actions: []),
      AuthSession(
        token: 'malformed',
        userId: 1,
        groupId: 1,
        userName: 'Superadmin',
        groupName: 'Superadmin',
        groupType: 'superadmin',
        user: const {},
        sidebars: valid.sidebars,
        verifiedAt: DateTime.now(),
      ),
      AuthSession(
        token: valid.token,
        userId: 1,
        groupId: 1,
        userName: 'Superadmin',
        groupName: 'Superadmin',
        groupType: 'superadmin',
        user: const {},
        sidebars: const [],
        verifiedAt: DateTime.now(),
      ),
      for (final code in ['transaksi_notaris', 'transaksi_ppat', 'Transaksi'])
        AuthSession(
          token: valid.token,
          userId: 1,
          groupId: 1,
          userName: 'Test',
          groupName: 'Test',
          user: const {},
          verifiedAt: DateTime.now(),
          sidebars: [
            {
              ...valid.sidebars.single,
              'sidebar': {'sidebar_kode': code, 'status': 1},
            },
          ],
        ),
      AuthSession(
        token: valid.token,
        userId: 1,
        groupId: 1,
        userName: 'Test',
        groupName: 'Test',
        user: const {},
        verifiedAt: DateTime.now(),
        sidebars: [valid.sidebars.single, valid.sidebars.single],
      ),
    ];
    for (final variant in variants) {
      session = variant;
      await unchanged(() => save('ppat'));
      await unchanged(() => save('notaris', id: ids['notaris']));
      await unchanged(() => repo.delete(ids['notaris']!));
    }
  });

  test(
    'PPAT CREATE with Materai binding disabled is denied through controller',
    () async {
      final actor = MasterTestAuth(transactionTestSession(actions: ['read']));
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          authControllerProvider.overrideWith((_) => actor),
        ],
      );
      addTearDown(container.dispose);
      final before = await masterSnapshot(db);
      await expectLater(
        container
            .read(transactionControllerProvider.notifier)
            .save(
              nomorTransaksi: 'BLOCKED-PPAT',
              jenisTransaksi: 'ppat',
              pemohonId: 1,
              pemohonUuid: 'applicant',
              petugasId: 1,
              petugasUuid: 'officer',
              status: 'Baru',
              tanggalTransaksi: DateTime.now(),
              jobs: const [],
            ),
        throwsA(isA<StateError>()),
      );
      expect(await masterSnapshot(db), before);
    },
  );

  test('stale captured session and wrong live database cannot authorize direct save', () async {
    final old = session!;
    session = transactionTestSession(uid: 2);
    await unchanged(() => save('notaris', expected: old));
    active = null;
    await unchanged(() => save('ppat'));
  });

  test(
    'process integer actor claims cannot bypass live UPDATE authorization',
    () async {
      final processes = TransaksiProsesRepository(db, authorization: authority);
      final process = (await processes.getByTransactionId(ids['notaris']!))
          .single;
      await unchanged(
        () => processes.initializeLegacyProcess(
          processId: process.id,
          actorUserId: 2,
        ),
      );
      session = transactionTestSession(actions: ['read']);
      await unchanged(
        () => processes.initializeLegacyProcess(
          processId: process.id,
          actorUserId: 1,
        ),
      );
    },
  );

  test('PPAT status and payment direct mutations require current context, not supplied actor alone', () async {
    final original = session!;
    final detail = (await repo.watchDetailsOnce(ids['ppat']!)).single;
    session = transactionTestSession(uid: 2);
    await unchanged(
      () => repo.savePpatJobStatus(
        session: original,
        expected: detail,
        status: PpatJobStatus.dalamProses,
      ),
    );
    await unchanged(
      () => repo.addPayment(
        session: original,
        transactionId: ids['ppat']!,
        paymentUuid: 'e0000000-0000-4000-8000-000000000099',
        paymentDate: DateTime.now(),
        amount: 1,
      ),
    );
  });

  test('demo context requires correct bound profile and live expiry', () async {
    final source = session!;
    for (final expiry in [
      DateTime.now().subtract(const Duration(seconds: 1)),
      DateTime.now().add(const Duration(hours: 1)),
    ]) {
      session = ExpiringPaymentDemoSession(
        source,
        expiry,
        profileId: 'demo-profile',
      );
      await unchanged(() => save('ppat'));
    }
  });

  test('missing update ID never falls back to CREATE or an upsert', () async {
    session = transactionTestSession(actions: ['read', 'create']);
    await unchanged(() => save('ppat', id: 99999));
    session = transactionTestSession(actions: ['read', 'update']);
    final before = await masterSnapshot(db);
    await expectLater(save('ppat', id: 99999), throwsStateError);
    expect(await masterSnapshot(db), before);
  });

  test(
    'READ cannot be used as an authorization action for the mutation wrapper',
    () async {
      session = transactionTestSession(actions: ['read']);
      await unchanged(
        () => authority.write(db, TransactionAction.read, (_) async {
          await db.customStatement(
            "UPDATE transaksis SET catatan='must not run'",
          );
          return null;
        }),
      );
    },
  );

  test('payment audit and balance rollback when UPDATE is revoked after payment insert', () async {
    final actor = session!;
    revokeAfterSql = "SELECT 1 FROM transaksi_pembayaran_audit WHERE payment_uuid='e0000000-0000-4000-8000-000000000098'";
    revoke = () => actor.sidebars.single['update'] = 0;
    await unchanged(
      () => repo.addPayment(
        session: actor,
        transactionId: ids['notaris']!,
        paymentUuid: 'e0000000-0000-4000-8000-000000000098',
        paymentDate: DateTime.now(),
        amount: 1,
      ),
    );
  });

  test('restore audit uses the verified authority, not an independent caller actor label', () async {
    await repo.delete(ids['notaris']!);
    final bin = RecycleBinRepository(
      db,
      () => transactionTestSession(uid: 999),
      transactionAuthorization: authority,
    );
    final record = (await bin.list(module: RecycleModule.transactionNotaris))
        .single;
    await bin.restore(record);
    final audit = await db
        .customSelect(
          "SELECT actor_id FROM recycle_bin_events WHERE action='restore' AND outcome='success'",
        )
        .getSingle();
    expect(audit.read<int>('actor_id'), 1);
  });

  test('revocation after stock-out rolls back parent, child, payment and Materai ledger together', () async {
    late native.Database stockRaw;
    final local = MateraiProfileDatabase(
      NativeDatabase.memory(
        setup: (r) {
          stockRaw = r;
          r.execute('PRAGMA foreign_keys=ON');
        },
      ),
    );
    addTearDown(local.close);
    await seedPenghasilan(local);
    final opening = await seedMateraiOpening(local, transactionUsage: true);
    final binding = MateraiStockBinding(
      local,
      opening.profileId,
      opening.openingSha256,
      transactionUsageEnabled: true,
    );
    final actor = usageActor(binding.profileId);
    var armed = false;
    final auth = transactionTestAuthority(
      local,
      profileId: binding.profileId,
      session: () {
        if (armed &&
            stockRaw
                .select('SELECT 1 FROM materai_movements WHERE stock_out>0')
                .isNotEmpty) {
          armed = false;
          actor.sidebars.firstWhere(
            (g) => (g['sidebar'] as Map)['sidebar_kode'] == 'transaksi',
          )['create'] = 0;
        }
        return actor;
      },
    );
    final inventory = MateraiStockRepository(binding, () => actor);
    final writer = TransactionRepository(
      local,
      authorization: auth,
      materaiStock: inventory,
    );
    final before = await masterSnapshot(local);
    armed = true;
    await expectLater(
      writer.save(
        createUuid: 'e0000000-0000-4000-8000-000000000097',
        nomorTransaksi: 'H03-STOCK',
        jenisTransaksi: 'notaris',
        pemohonId: 1,
        pemohonUuid: 'applicant',
        petugasId: 100,
        petugasUuid: 'e0c928a2-c304-437e-8bf5-7a81bd5e0eae',
        status: 'Baru',
        tanggalTransaksi: DateTime(2026, 11, 17),
        jumlahMaterai: 3,
        pembayaranSekarang: 25,
        jobs: const [
          TransactionJobInput(
            jenisPekerjaan: 'notaris',
            namaPekerjaan: 'Akta',
            pekerjaanNotarisId: 1,
            detailUuid: 'h03-stock-detail',
            biayaLayanan: 100,
          ),
        ],
      ),
      throwsA(isA<LocalTransactionDenied>()),
    );
    expect(
      armed,
      false,
      reason: 'The guard must observe the actual uncommitted ledger write',
    );
    expect(await masterSnapshot(local), before);
    expect(await local.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });
}
