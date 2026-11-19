import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/core/widgets/app_shell.dart';
import 'package:frontend_notaris/core/widgets/promotional_preview.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/models/auth_session.dart';
import 'package:frontend_notaris/models/verified_demo_session.dart';
import 'package:frontend_notaris/promotional_demo_main.dart';
import 'package:frontend_notaris/providers/auth_provider.dart';
import 'package:frontend_notaris/providers/database_provider.dart';
import 'package:frontend_notaris/providers/development_smoke_provider.dart';
import 'package:frontend_notaris/repositories/pekerjaan_repository.dart';
import 'package:frontend_notaris/repositories/pengeluaran_repository.dart';
import 'package:frontend_notaris/repositories/penghasilan_repository.dart';
import 'package:frontend_notaris/repositories/piutang_repository.dart';
import 'package:frontend_notaris/repositories/pendapatan_repository.dart';
import 'package:frontend_notaris/repositories/materai_repository.dart';
import 'package:frontend_notaris/repositories/materai_stock_repository.dart';
import 'package:frontend_notaris/repositories/transaction_repository.dart';
import 'package:uuid/uuid.dart';

import '../support/transaction_ui_test_support.dart';

Future<ExpiringPaymentDemoSession> contextSession(String id) async {
  final root = promotionalRoot(id);
  final result = await Process.run('${root.path}/session.exe', [
    'promo-fixture-context',
    id,
  ]);
  expect(result.exitCode, 0);
  final raw = jsonDecode(result.stdout as String) as Map<String, dynamic>;
  expect(raw['profile'], id);
  expect(raw['username'], 'superadmin.promo');
  expect(raw['groupType'], 'superadmin');
  return ExpiringPaymentDemoSession(
    AuthSession.fromJson({
      ...raw,
      'token': 'verified-go-promo-fixture-context',
    }),
    DateTime.parse(raw['expiresAt'] as String),
    profileId: id,
    expireSidebarAccess: true,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final id = Platform.environment['NOTARIS_PROMOTIONAL_PREPARE'];
  final verifyOnly = Platform.environment['NOTARIS_PROMOTIONAL_VERIFY'] == '1';
  test('provision reconciled v27 fictional local-first data using existing repositories', () async {
    final root = promotionalRoot(id!);
    final session = await contextSession(id);
    final file = await File('${root.path}/offline.sqlite')
        .create(exclusive: true);
    final db = MateraiProfileDatabase(
      NativeDatabase(file, setup: (d) => d.execute('PRAGMA foreign_keys=ON')),
    );
    const uuid = Uuid();
    final tx = TransactionRepository(db);
    try {
      final officerUuid = uuid.v4();
      final officer = await db
          .into(db.petugasLocals)
          .insert(
            PetugasLocalsCompanion.insert(
              uuid: officerUuid,
              nama: 'Rani Wulandari',
              email: 'promo-officer@example.invalid',
            ),
          );
      await db.customStatement('UPDATE petugas SET user_id=104 WHERE id=?', [
        officer,
      ]);
      for (final (index, domain) in ['notaris', 'ppat'].indexed) {
        final notaris = domain == 'notaris';
        final applicantUuid = uuid.v4();
        final applicant = await db
            .into(db.pemohons)
            .insert(
              PemohonsCompanion.insert(
                uuid: applicantUuid,
                nama: notaris ? 'Bagas Pradipta' : 'Laras Mahendra',
              ),
            );
        final categoryUuid = uuid.v4();
        final categoryName = notaris ? 'Kenotariatan' : 'Pertanahan';
        final category = await db
            .into(db.pekerjaanKategoris)
            .insert(
              PekerjaanKategorisCompanion.insert(
                uuid: categoryUuid,
                nama: categoryName,
              ),
            );
        final jobName = notaris ? 'Pembuatan Akta Fidusia' : 'Akta Jual Beli';
        final input = PekerjaanAggregateInput(
          nama: jobName,
          harga: [
            PekerjaanHargaInput(
              harga: '2500000',
              kategoriPekerjaanId: category,
              estimasiWaktu: '3 hari',
            ),
          ],
          proses: const [
            PekerjaanProsesInput(
              nama: 'Verifikasi berkas',
              detail: 'Periksa kelengkapan berkas',
            ),
          ],
        );
        final job = notaris
            ? await PekerjaanNotarisRepository(db.pekerjaanDao)
                  .createAggregate(input: input)
            : await PekerjaanPpatRepository(db.pekerjaanDao)
                  .createAggregate(input: input);
        final transaction = await tx.save(
          nomorTransaksi: '${index + 1}001911260001',
          jenisTransaksi: domain,
          pemohonId: applicant,
          pemohonUuid: applicantUuid,
          petugasId: officer,
          petugasUuid: officerUuid,
          status: 'Dalam Proses',
          tanggalTransaksi: DateTime(2026, 11, 19),
          tanggalJatuhTempo: DateTime(2026, 11, 22),
          pembayaranSekarang: 500000,
          catatan: 'Data fiktif untuk demonstrasi promosi',
          jobs: [
            TransactionJobInput(
              detailUuid: uuid.v4(),
              jenisPekerjaan: domain,
              pekerjaanNotarisId: notaris ? job : null,
              pekerjaanPpatId: notaris ? null : job,
              namaPekerjaan: jobName,
              kategoriSnapshot: categoryName,
              biayaLayanan: 2500000,
              estimasiWaktuSnapshot: '3 hari',
              prosesSnapshot: '[{"id":"1","name":"Verifikasi berkas","attributes":["Kelengkapan dokumen"]}]',
            ),
          ],
        );
        final invoice = await tx.readInvoice(
          transactionId: transaction,
          session: session,
        );
        expect(invoice.paid, 500000);
        expect(invoice.responsibleStaffName, 'Rani Wulandari');
      }
      final jenis = await db
          .into(db.pengeluaranJenis)
          .insert(
            PengeluaranJenisCompanion.insert(uuid: uuid.v4(), nama: 'ATK'),
          );
      await PengeluaranRepository(db, () => session).create((
        noFaktur: 'PROMO-ATK-01',
        tanggal: DateTime(2026, 11, 19),
        nominal: 85000,
        jenisId: jenis,
        keterangan: 'Map dan kertas demonstrasi',
      ));
      // Explicit fictional opening, with the accepted ledger proof format. No
      // inventory valuation/tax or linkage to customer payments is invented.
      final opening = DateTime.utc(2026, 11, 19, 0);
      final proof = jsonEncode({
        'kind': 'synthetic_verified_opening',
        'profile': id,
        'opening': 20,
        'date': '2026-11-19',
        'recorded_ms': opening.millisecondsSinceEpoch,
        'officer_id': officer,
        'officer': 'Rani Wulandari',
        'description': 'Saldo pembuka fiktif demonstrasi',
      });
      final hash = materaiProvenanceHash(proof);
      final binding = MateraiStockBinding(db, id, hash);
      await db.customStatement(
        '''INSERT INTO materai_movements(source_namespace,source_id,business_date,source_created_ms,stock_in,stock_out,recorded_stock,description,source_officer_id,officer_snapshot,source_status,provenance_json,payload_sha256)
      VALUES(?,1,'2026-11-19',?,0,0,20,'Saldo pembuka fiktif demonstrasi',?,'Rani Wulandari',1,?,?)''',
        [
          '${binding.namespace}:opening',
          opening.millisecondsSinceEpoch,
          officer,
          proof,
          hash,
        ],
      );
      final stock = MateraiStockRepository(binding, () => session);
      await stock.receive(
        operation: uuid.v4(),
        expectedPredecessor: 1,
        businessDate: '2026-11-19',
        sheets: 5,
        description: 'Penerimaan fiktif demonstrasi',
      );
      expect((await stock.context()).stock, 25);
      final income = await PenghasilanRepository(db, () => session).read();
      expect(income.total, BigInt.from(1000000));
      expect(income.reviews, isEmpty);
      final debt = await PiutangRepository(
        db,
        () => session,
      ).read((domain: '', from: null, through: null, search: ''));
      expect(debt.total, BigInt.from(4000000));
      expect(debt.reviews, isEmpty);
      final report = await PendapatanRepository(db, () => session).read((
        from: DateTime.utc(2026, 11, 1),
        through: DateTime.utc(2026, 11, 30),
      ));
      expect(report.total.receipts, BigInt.from(1000000));
      expect(report.total.expenses, BigInt.from(85000));
      expect(report.total.difference, BigInt.from(915000));
      expect(report.reviews, isEmpty);
      expect(
        (await MateraiRepository(db, () => session).read()).verified.length,
        2,
      );
      expect(
        (await db.customSelect('PRAGMA integrity_check').getSingle())
            .read<String>('integrity_check'),
        'ok',
      );
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      await db.customStatement('PRAGMA query_only=ON');
      await expectLater(
        db.customStatement('DELETE FROM transaksis'),
        throwsA(anything),
      );
      await File('${root.path}/fixture-summary.json').writeAsString(
        jsonEncode({
          'schema': 27,
          'transactions': 2,
          'payments': 2,
          'billed': 5000000,
          'paid': 1000000,
          'remaining': 4000000,
          'expenses': 85000,
          'receipts_minus_expenses': 915000,
          'materai_opening': 20,
          'materai_in': 5,
          'materai_out': 0,
          'materai_balance': 25,
        }),
      );
    } finally {
      await db.close();
    }
  }, skip: id == null || verifyOnly);

  test('existing promotional fixture reconciles without writes', () async {
    final session = await contextSession(id!);
    final root = promotionalRoot(id);
    final db = MateraiProfileDatabase(
      NativeDatabase(
        File('${root.path}/offline.sqlite'),
        enableMigrations: false,
        setup: (d) {
          d.execute('PRAGMA query_only=ON');
          d.execute('PRAGMA foreign_keys=ON');
        },
      ),
    );
    try {
      final income = await PenghasilanRepository(db, () => session).read();
      expect(income.total, BigInt.from(1000000));
      expect(income.reviews, isEmpty);
      final debt = await PiutangRepository(
        db,
        () => session,
      ).read((domain: '', from: null, through: null, search: ''));
      expect(debt.total, BigInt.from(4000000));
      expect(debt.reviews, isEmpty);
      final report = await PendapatanRepository(db, () => session).read((
        from: DateTime.utc(2026, 11, 1),
        through: DateTime.utc(2026, 11, 30),
      ));
      expect(report.total.difference, BigInt.from(915000));
      expect(report.reviews, isEmpty);
      expect(
        (await db
                .customSelect(
                  'SELECT recorded_stock FROM materai_movements ORDER BY id DESC LIMIT 1',
                )
                .getSingle())
            .read<int>('recorded_stock'),
        25,
      );
      expect(
        (await db.customSelect('PRAGMA integrity_check').getSingle())
            .read<String>('integrity_check'),
        'ok',
      );
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    } finally {
      await db.close();
    }
  }, skip: id == null);

  for (final size in [
    const Size(1920, 1080),
    const Size(1728, 900),
    const Size(1366, 768),
  ]) {
    testWidgets('all 21 routes preserve shell without overflow at $size', (
      tester,
    ) async {
      final session = (await tester.runAsync(() async {
        final font = FontLoader('PromoSans')
          ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
        await font.load();
        return contextSession(id!);
      }))!;
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final root = promotionalRoot(id!);
      final db = MateraiProfileDatabase(
        NativeDatabase(
          File('${root.path}/offline.sqlite'),
          enableMigrations: false,
          setup: (d) {
            d.execute('PRAGMA query_only=ON');
            d.execute('PRAGMA foreign_keys=ON');
          },
        ),
      );
      addTearDown(db.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            developmentUiSmokeProvider.overrideWithValue(true),
            authControllerProvider.overrideWith(
              (_) => TransactionUiAuth(session),
            ),
          ],
          child: PromotionalPreview(
            child: MaterialApp(
              theme: ThemeData(fontFamily: 'PromoSans'),
              home: AppShell(session: session),
            ),
          ),
        ),
      );
      await cycleUi(tester);
      var opened = 0;
      for (final (section, menus) in [
        (
          null,
          [
            'Dashboard',
            'Transaksi',
            'Monitoring',
            'Pengeluaran',
            'Piutang',
            'Penghasilan',
          ],
        ),
        (
          'Master',
          [
            'Pekerjaan Notaris',
            'Pekerjaan PPAT',
            'Kategori Pekerjaan',
            'Jenis Pengeluaran',
            'Petugas',
            'Pemohon',
          ],
        ),
        ('Laporan', ['Materai', 'Pendapatan']),
        (
          'System',
          [
            'Users',
            'Groups',
            'Sidebars',
            'Konfigurasi Umum',
            'Log Sinkronisasi',
            'Monitoring Sinkronisasi',
            'Recycle Bin',
          ],
        ),
      ]) {
        if (section != null) {
          final label = find.text(section).first;
          await tester.ensureVisible(label);
          await tester.tap(label);
          await tester.pumpAndSettle();
        }
        for (final name in menus) {
          final label = find.text(name).first;
          await tester.ensureVisible(label);
          await tester.tap(label);
          await cycleUi(tester);
          expect(find.byKey(ValueKey(name)), findsOneWidget, reason: name);
          expect(tester.takeException(), isNull, reason: name);
          opened++;
          if ([
            'Users',
            'Groups',
            'Sidebars',
            'Konfigurasi Umum',
          ].contains(name)) {
            expect(find.textContaining('PRATINJAU PROTOTIPE'), findsOneWidget);
          }
        }
      }
      expect(opened, 21);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }, skip: id == null);
  }
}
