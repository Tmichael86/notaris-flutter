import '../support/transaction_test_authority.dart';

import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/core/widgets/app_shell.dart';
import 'package:frontend_notaris/core/widgets/searchable_dropdown.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/models/auth_session.dart';
import 'package:frontend_notaris/models/transaction_monitoring.dart';
import 'package:frontend_notaris/providers/auth_provider.dart';
import 'package:frontend_notaris/providers/database_provider.dart';
import 'package:frontend_notaris/providers/transaction_provider.dart';
import 'package:frontend_notaris/repositories/transaction_repository.dart';
import 'package:frontend_notaris/screens/monitoring_desktop_screen.dart';
import 'package:frontend_notaris/services/monitoring_excel_export.dart';

import '../support/transaction_ui_test_support.dart';

void main() {
  late AppDatabase db;
  final date = DateTime(2026, 10, 9, 14);
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> header(
    String number, {
    String domain = 'notaris',
    String status = 'Baru',
    bool deleted = false,
    bool dated = true,
  }) => db
      .into(db.transaksis)
      .insert(
        TransaksisCompanion.insert(
          uuid: 'tx-$number',
          noAkta: number,
          total: 250000,
          jenisTransaksi: Value(domain),
          statusTransaksi: Value(status),
          tanggalTransaksi: Value(dated ? date : null),
          tanggalJatuhTempo: Value(date.add(const Duration(days: 5))),
          deletedAt: Value(deleted ? date : null),
        ),
      );

  Future<void> detail(
    int id,
    String uuid,
    String name,
    String category, {
    bool active = true,
  }) async {
    await db
        .into(db.transaksiDetails)
        .insert(
          TransaksiDetailsCompanion.insert(
            uuid: uuid,
            transaksiId: id,
            jenisPekerjaan: 'notaris',
            namaPekerjaanSnapshot: name,
            kategoriSnapshot: Value(category),
            status: Value(active ? 1 : 0),
          ),
        );
  }

  MonitoringFilter filter({
    String domain = '',
    String status = '',
    String search = '',
    String job = '',
    String category = '',
    int officerId = 0,
    DateTime? from,
    DateTime? until,
    int index = 0,
  }) => (
    domain: domain,
    status: status,
    search: search,
    job: job,
    category: category,
    officerId: officerId,
    from: from,
    until: until,
    index: index,
  );

  test('Monitoring SQL pages share filters, preserve snapshots and have stable ties', () async {
    for (var i = 1; i <= 12; i++) {
      await header('LOOK-$i', domain: 'ppat', status: 'Dalam Proses');
    }
    await header('LOOK-other-domain', status: 'Dalam Proses');
    await header('LOOK-complete', domain: 'ppat', status: 'Selesai');
    await header(
      'LOOK-tombstone',
      domain: 'ppat',
      status: 'Dalam Proses',
      deleted: true,
    );
    await header('LOOK-legacy-tombstone', domain: 'ppat', status: 'Dihapus');
    await header(
      'LOOK-undated',
      domain: 'ppat',
      status: 'Dalam Proses',
      dated: false,
    );
    final repo = testTransactionRepository(db);
    Future<MonitoringPage> page(int index) => repo
        .watchMonitoringPage(
          filter(
            domain: 'ppat',
            status: 'Dalam Proses',
            search: 'look',
            from: DateTime(2026, 10, 9),
            until: DateTime(2026, 10, 9),
            index: index,
          ),
        )
        .first;
    final first = await page(0);
    final tail = await page(1);
    expect(first.total, 12);
    expect(tail.total, 12);
    expect(
      first.rows.map((r) => r.transaction.noAkta),
      List.generate(10, (i) => 'LOOK-${12 - i}'),
    );
    expect(tail.rows.map((r) => r.transaction.noAkta), ['LOOK-2', 'LOOK-1']);
    final transaction = first.rows.first.transaction;
    await detail(transaction.id, 'job-1', 'Akta historis', 'Kategori lama');
    await detail(transaction.id, 'job-2', 'Pekerjaan kedua', 'Kategori lain');
    await detail(
      transaction.id,
      'job-inactive',
      'Tersembunyi',
      'Kategori tersembunyi',
      active: false,
    );
    final matched = await repo
        .watchMonitoringPage(
          filter(
            search: 'historis',
            job: 'Akta historis',
            category: 'Kategori lama',
          ),
        )
        .first;
    expect(matched.total, 1);
    expect(matched.rows.single.transaction.total, 250000);
    expect(
      matched.rows.single.jobs,
      allOf(
        contains('Akta historis'),
        contains('Pekerjaan kedua'),
        isNot(contains('Tersembunyi')),
      ),
    );
    expect(matched.rows.single.applicant, isNull);
    expect(matched.rows.single.officer, isNull);
    expect(
      (await repo
              .watchMonitoringPage(
                filter(job: 'Akta historis', category: 'Kategori lain'),
              )
              .first)
          .total,
      0,
    );
    final options = await repo.watchMonitoringOptions('ppat').first;
    expect(options.jobs, ['Akta historis', 'Pekerjaan kedua']);
    expect(options.categories, ['Kategori lain', 'Kategori lama']);
  });

  test(
    'Monitoring resolves active contact identity and searches literal NIK',
    () async {
      final id = await header('Contact');
      final applicant = await db
          .into(db.pemohons)
          .insert(
            PemohonsCompanion.insert(
              uuid: 'a',
              nama: 'Pemohon nyata',
              nik: const Value('123%456'),
            ),
          );
      final officer = await db
          .into(db.petugasLocals)
          .insert(
            PetugasLocalsCompanion.insert(
              uuid: 'o',
              nama: 'Petugas nyata',
              email: 'fixture@example.invalid',
            ),
          );
      final update = db.update(db.transaksis)..where((t) => t.id.equals(id));
      await update.write(
        TransaksisCompanion(
          pemohonId: Value(applicant),
          pemohonUuid: const Value('a'),
          petugasId: Value(officer),
          petugasUuid: const Value('o'),
        ),
      );
      final repo = testTransactionRepository(db);
      final page = await repo.watchMonitoringPage(filter(search: '3%4')).first;
      expect(page.rows.single.nik, '123%456');
      expect(page.rows.single.applicant, 'Pemohon nyata');
      expect(page.rows.single.officer, 'Petugas nyata');
      expect((await repo.watchMonitoringOptions('').first).officers, {
        officer: 'Petugas nyata',
      });
      expect(
        (await repo
                .watchMonitoringPage(
                  filter(officerId: officer, search: 'contact'),
                )
                .first)
            .rows
            .single
            .transaction
            .id,
        id,
      );
      expect(
        (await repo.watchMonitoringPage(filter(officerId: officer + 1)).first)
            .total,
        0,
      );
      await update.write(
        const TransaksisCompanion(pemohonUuid: Value('unmatched')),
      );
      expect(
        (await repo.watchMonitoringPage(filter(search: '3%4')).first).total,
        0,
      );
      expect(
        (await repo.watchMonitoringTransaction(id).first)!.applicant,
        isNull,
      );
    },
  );

  test('Monitoring stream reacts to local header and detail changes', () async {
    final repo = testTransactionRepository(db);
    final stream = StreamIterator(
      repo.watchMonitoringPage(filter(search: 'cari')),
    );
    addTearDown(stream.cancel);
    expect(await stream.moveNext(), isTrue);
    expect(stream.current.total, 0);
    final id = await header('T-1');
    expect(await stream.moveNext(), isTrue);
    expect(stream.current.total, 0);
    await detail(id, 'd1', 'Cari saya', 'Kategori');
    expect(await stream.moveNext(), isTrue);
    expect(stream.current.rows.single.transaction.id, id);
    await (db.update(db.transaksis)..where((t) => t.id.equals(id))).write(
      TransaksisCompanion(deletedAt: Value(date)),
    );
    expect(await stream.moveNext(), isTrue);
    expect(stream.current.total, 0);
    await stream.cancel();
  });

  Future<void> mount(
    WidgetTester tester, {
    bool allowed = true,
    bool rejectDatabase = false,
    List<Override> overrides = const [],
    bool canExport = false,
    MonitoringExcelExport exporter = const MonitoringExcelExport(),
  }) async {
    final session = uiSession(permission: allowed);
    if (canExport) {
      session.sidebars.add({
        'sidebar': {'sidebar_nama': 'Monitoring', 'status': 1},
        'read': 1,
      });
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            (_) => TransactionUiAuth(session),
          ),
          appDatabaseProvider.overrideWith(
            (_) => rejectDatabase ? throw StateError('Query tanpa izin') : db,
          ),
          ...overrides,
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MonitoringDesktopScreen(exporter: exporter),
            ),
          ),
        ),
      ),
    );
    await cycleUi(tester);
  }

  testWidgets('Monitoring denies access before resolving SQLite', (
    tester,
  ) async {
    await mount(tester, allowed: false, rejectDatabase: true);
    expect(
      find.textContaining('Izin baca Transaksi diperlukan'),
      findsOneWidget,
    );
    expect(find.byType(DataTable), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppShell requires Monitoring menu access and Transaksi read', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final loader = FontLoader('MonitoringTestSans')
        ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
      await loader.load();
    });
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final (menu, read) in [(false, true), (true, false), (true, true)]) {
      final session = uiSession(permission: read);
      if (menu) {
        session.sidebars.add({
          'sidebar': {
            'sidebar_nama': 'Monitoring',
            'sidebar_kode': 'monitoring',
          },
          'read': 1,
        });
      }
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey((menu, read)),
          overrides: [
            authControllerProvider.overrideWith(
              (_) => TransactionUiAuth(session),
            ),
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            theme: ThemeData(fontFamily: 'MonitoringTestSans'),
            home: AppShell(session: session),
          ),
        ),
      );
      await cycleUi(tester);
      expect(find.text('Monitoring'), menu ? findsOneWidget : findsNothing);
      if (menu) {
        await tester.tap(find.text('Monitoring'));
        await cycleUi(tester);
        expect(find.byType(MonitoringDesktopScreen), findsOneWidget);
        expect(
          find.text('Data Monitoring'),
          read ? findsOneWidget : findsNothing,
        );
        expect(
          find.textContaining('Izin baca Transaksi diperlukan'),
          read ? findsNothing : findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
    'page navigation, Petugas, combined filters and Reset use the full result set',
    (tester) async {
      final exporter = _RecordingExporter();
      tester.view.physicalSize = const Size(1366, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        final officer = await db
            .into(db.petugasLocals)
            .insert(
              PetugasLocalsCompanion.insert(
                uuid: 'scoped-officer',
                nama: 'Nadia Pertiwi',
                email: 'nadia@example.invalid',
              ),
            );
        for (var i = 1; i <= 25; i++) {
          final id = await header(
            'MON-${i.toString().padLeft(2, '0')}',
            domain: i.isEven ? 'ppat' : 'notaris',
          );
          if (i <= 2) {
            await (db.update(
              db.transaksis,
            )..where((t) => t.id.equals(id))).write(
              TransaksisCompanion(
                petugasId: Value(officer),
                petugasUuid: const Value('scoped-officer'),
              ),
            );
          }
        }
      });
      await mount(tester, canExport: true, exporter: exporter);
      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await cycleUi(tester);
      }

      expect(find.text('Halaman 1 / 3'), findsOneWidget);
      await tap(find.text('Next'));
      expect(find.text('Halaman 2 / 3'), findsOneWidget);
      expect(find.text('MON-15'), findsOneWidget);
      expect(find.text('MON-25'), findsNothing);
      if (Platform.isWindows) {
        await tester.ensureVisible(find.text('Excel'));
        await tester.tap(find.text('Excel'));
        await tester.pump();
        expect(find.text('Mengekspor…'), findsOneWidget);
        expect(exporter.filter?.index, 1);
        exporter.outcome.complete(25);
        await cycleUi(tester);
        expect(find.textContaining('25 transaksi diekspor'), findsOneWidget);
        expect(find.text('Halaman 2 / 3'), findsOneWidget);
      }
      await tap(find.text('Previous'));
      expect(find.text('MON-25'), findsOneWidget);
      await tap(find.text('Next'));
      await tap(
        find.byWidgetPredicate(
          (w) => w is SearchableDropdown<int> && w.label == 'Petugas',
        ),
      );
      await tap(find.text('Nadia Pertiwi').last);
      expect(find.text('Halaman 1 / 1'), findsOneWidget);
      expect(find.text('MON-01'), findsOneWidget);
      expect(find.text('MON-02'), findsOneWidget);
      expect(find.text('MON-15'), findsNothing);

      final search = find.byType(TextField);
      await tester.ensureVisible(search);
      await tester.enterText(search, 'MON-02');
      await tester.pump(const Duration(milliseconds: 500));
      await cycleUi(tester);
      expect(find.text('MON-02'), findsWidgets);
      expect(find.text('Menampilkan 1 dari 1 transaksi'), findsOneWidget);
      expect(find.text('MON-01'), findsNothing);
      await tap(find.text('Reset'));
      expect(find.text('Halaman 1 / 3'), findsOneWidget);
      expect(find.text('MON-25'), findsOneWidget);
      expect(tester.widget<TextField>(search).controller?.text, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  for (final domain in ['notaris', 'ppat']) {
    testWidgets(
      'compact $domain Monitoring scrolls to Detail, shows active scoped processes and writes nothing',
      (tester) async {
        tester.view.physicalSize = const Size(420, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final id = await tester.runAsync(() async {
          final selected = await header('Detail-Test', domain: domain);
          final other = await header('Other-Transaction', deleted: true);
          await detail(selected, 'd-selected', 'Snapshot A', 'Kategori asli');
          await detail(selected, 'd-second', 'Snapshot B', 'Kategori kedua');
          await detail(
            selected,
            'd-inactive',
            'Snapshot nonaktif',
            'Kategori asli',
            active: false,
          );
          Future<void> process(
            String name,
            String detailUuid,
            int transactionId,
          ) => db
              .into(db.transaksiProses)
              .insert(
                TransaksiProsesCompanion.insert(
                  uuid: name,
                  transaksiId: transactionId,
                  transaksiDetailUuid: detailUuid,
                  namaProsesSnapshot: name,
                ),
              );
          await process('Proses legacy', 'd-selected', selected);
          for (var i = 1; i <= 12; i++) {
            await process('Langkah $i', 'd-second', selected);
          }
          await process('Proses salah induk', 'd-second', other);
          await process('Proses detail nonaktif', 'd-inactive', selected);
          await detail(other, 'd-foreign', 'Pekerjaan asing', 'Kategori asing');
          await process('UUID detail transaksi lain', 'd-foreign', selected);
          await db.customStatement(
            "UPDATE transaksi_details SET jenis_pekerjaan=? WHERE transaksi_id=?",
            [domain, selected],
          );
          await db.customStatement(
            "INSERT INTO transaction_cloud_feed(scope,cursor) VALUES('fixture',9)",
          );
          return selected;
        });
        const tables = [
          'transaksis',
          'transaksi_details',
          'transaksi_proses',
          'transaksi_proses_riwayat',
          'transaksi_riwayat_pembayaran',
          'transaksi_pembayaran_audit',
          'transaction_cloud_pending',
          'transaction_cloud_identity',
          'transaction_cloud_feed',
        ];
        Future<List<List<Map<String, dynamic>>>> snapshot() async => [
          for (final table in tables)
            (await db.customSelect('SELECT * FROM $table ORDER BY rowid').get())
                .map((row) => row.data)
                .toList(),
        ];
        final baseline = await tester.runAsync(snapshot);
        await mount(tester);
        expect(find.text('Halaman 1 / 1'), findsOneWidget);
        final horizontal = find.byWidgetPredicate(
          (w) =>
              w is SingleChildScrollView &&
              w.scrollDirection == Axis.horizontal,
        );
        await tester.ensureVisible(horizontal);
        final scroll = tester
            .widget<SingleChildScrollView>(horizontal)
            .controller!;
        expect(scroll.position.maxScrollExtent, greaterThan(0));
        scroll.jumpTo(scroll.position.maxScrollExtent);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Detail'));
        await cycleUi(tester);
        expect(find.text('Detail Monitoring'), findsOneWidget);
        Finder inDialog(String text) =>
            find.descendant(of: find.byType(Dialog), matching: find.text(text));
        expect(
          inDialog(domain == 'notaris' ? 'Notaris' : 'PPAT'),
          findsOneWidget,
        );
        expect(inDialog('Detail-Test'), findsNWidgets(2));
        expect(inDialog('Snapshot B'), findsOneWidget);
        expect(
          tester.getTopLeft(inDialog('Jenis')).dx,
          tester.getTopLeft(inDialog('No. Transaksi')).dx,
        );
        tester.view.physicalSize = const Size(1280, 800);
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(inDialog('Jenis')).dx,
          greaterThan(tester.getTopLeft(inDialog('No. Transaksi')).dx),
        );
        expect(
          tester
              .getSize(find.byKey(const Key('transaction-review-surface')))
              .width,
          closeTo(860, 1),
        );
        tester.view.physicalSize = const Size(420, 650);
        await tester.pumpAndSettle();
        final body = find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(Scrollable),
        );
        expect(
          tester.state<ScrollableState>(body).position.maxScrollExtent,
          greaterThan(0),
        );
        await tester.ensureVisible(inDialog('Langkah 12'));
        await tester.pumpAndSettle();
        expect(inDialog('Langkah 12').hitTestable(), findsOneWidget);
        expect(find.byTooltip('Tutup').hitTestable(), findsOneWidget);
        expect(find.text('Proses legacy'), findsOneWidget);
        expect(inDialog('Belum Diinisialisasi'), findsNWidgets(13));
        expect(find.text('Proses salah induk'), findsNothing);
        expect(find.text('Proses detail nonaktif'), findsNothing);
        expect(find.text('UUID detail transaksi lain'), findsNothing);
        await tester.tap(find.byTooltip('Tutup'));
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsNothing);
        expect(await tester.runAsync(snapshot), baseline);
        expect(id, isNotNull);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 1));
      },
    );
  }

  testWidgets('Monitoring distinguishes loading, error and empty states', (
    tester,
  ) async {
    final pages = StreamController<MonitoringPage>.broadcast();
    await mount(
      tester,
      overrides: [
        monitoringPageProvider.overrideWith((_, _) => pages.stream),
        monitoringOptionsProvider.overrideWith(
          (_, _) => Stream.value((jobs: [], categories: [], officers: {})),
        ),
      ],
    );
    expect(find.text('Memuat data Monitoring…'), findsOneWidget);
    pages.addError(StateError('fixture read error'));
    await tester.pumpAndSettle();
    expect(find.text('Data Monitoring gagal dimuat.'), findsOneWidget);
    pages.add((index: 0, total: 0, rows: []));
    await tester.pumpAndSettle();
    expect(find.text('Tidak ada transaksi yang sesuai.'), findsOneWidget);
    expect(find.text('Halaman 0 / 0'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Next'))
          .onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    unawaited(pages.close());
    await tester.pump();
  });
}

class _RecordingExporter extends MonitoringExcelExport {
  final outcome = Completer<int?>();
  MonitoringFilter? filter;

  @override
  Future<int?> run({
    required TransactionRepository repository,
    required AuthSession? Function() currentSession,
    required MonitoringFilter filter,
    String? officerLabel,
  }) {
    this.filter = filter;
    return outcome.future;
  }
}
