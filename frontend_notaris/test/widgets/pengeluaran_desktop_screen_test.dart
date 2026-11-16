import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/core/theme/app_colors.dart';
import 'package:frontend_notaris/core/widgets/app_shell.dart';
import 'package:frontend_notaris/core/widgets/searchable_dropdown.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/models/auth_session.dart';
import 'package:frontend_notaris/providers/auth_provider.dart';
import 'package:frontend_notaris/providers/database_provider.dart';
import 'package:frontend_notaris/providers/development_smoke_provider.dart';
import 'package:frontend_notaris/providers/pengeluaran_provider.dart';
import 'package:frontend_notaris/repositories/pengeluaran_repository.dart';
import 'package:frontend_notaris/screens/pengeluaran_desktop_screen.dart';
import 'package:frontend_notaris/services/auth_service.dart';
import 'package:frontend_notaris/services/pengeluaran_excel_export.dart';

import '../repositories/pengeluaran_repository_test.dart' show expenseSession;

class _Auth extends AuthController {
  _Auth(AuthSession? session) : super(AuthService(dio: Dio())) {
    setSession(session);
  }

  void setSession(AuthSession? session) => state = session == null
      ? AuthState.unauthenticated()
      : AuthState.authenticated(session);
}

class _SlowRepository extends PengeluaranRepository {
  _SlowRepository(AppDatabase db) : super(db, expenseSession);

  final saveGate = Completer<void>();
  var saves = 0;

  @override
  Future<int> create(PengeluaranInput input) async {
    saves++;
    await saveGate.future;
    return super.create(input);
  }
}

class _RecordingExport extends PengeluaranExcelExport {
  final completion = Completer<int?>();
  final filters = <PengeluaranFilter>[];

  @override
  Future<int?> run({
    required PengeluaranRepository repository,
    required AuthSession? Function() currentSession,
    required PengeluaranFilter filter,
    String? jenisLabel,
  }) {
    expect(allowsPengeluaran(currentSession(), PengeluaranAction.read), isTrue);
    filters.add(filter);
    return completion.future;
  }
}

Future<void> _open(
  WidgetTester tester,
  List<Override> overrides, {
  Size size = const Size(1366, 768),
  PengeluaranExcelExport exporter = const PengeluaranExcelExport(),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PengeluaranDesktopScreen(exporter: exporter),
          ),
        ),
      ),
    ),
  );
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

void main() {
  testWidgets('missing read permission never resolves the database', (
    tester,
  ) async {
    await _open(tester, [
      authControllerProvider.overrideWith((_) => _Auth(null)),
      appDatabaseProvider.overrideWith(
        (_) => throw StateError('Opened database'),
      ),
    ]);
    expect(
      find.text('Anda tidak memiliki izin membaca Pengeluaran.'),
      findsOneWidget,
    );
    expect(find.text('Tambah Pengeluaran'), findsNothing);
    expect(find.text('Excel'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading and error states do not show empty or fake totals', (
    tester,
  ) async {
    final pages = StreamController<PengeluaranPage>();
    addTearDown(() => unawaited(pages.close()));
    await _open(tester, [
      authControllerProvider.overrideWith((_) => _Auth(expenseSession())),
      pengeluaranFilterJenisProvider.overrideWith((_) => Stream.value([])),
      pengeluaranPageProvider.overrideWith((_, _) => pages.stream),
    ]);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Belum ada pengeluaran.'), findsNothing);
    pages.addError(StateError('test'));
    await tester.pumpAndSettle();
    expect(find.text('Daftar Pengeluaran gagal dimuat.'), findsOneWidget);
    expect(find.text('Total Pengeluaran'), findsNothing);
    await _unmount(tester);
  });

  testWidgets('date pickers include both bounds and combine with Jenis', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    await tester.runAsync(() async {
      for (final name in ['ATK', 'Transport']) {
        await db
            .into(db.pengeluaranJenis)
            .insert(PengeluaranJenisCompanion.insert(uuid: name, nama: name));
      }
      final repo = PengeluaranRepository(db, expenseSession);
      for (final (dayOffset, kind, amount) in [
        (-1, 1, 20),
        (0, 1, 100),
        (0, 2, 200),
        (1, 1, 30),
      ]) {
        await repo.create((
          noFaktur: null,
          tanggal: DateTime(today.year, today.month, today.day + dayOffset),
          nominal: amount,
          jenisId: kind,
          keterangan: 'Biaya $amount',
        ));
      }
    });
    await _open(tester, [
      authControllerProvider.overrideWith((_) => _Auth(expenseSession())),
      appDatabaseProvider.overrideWithValue(db),
    ]);
    await tester.pumpAndSettle();
    for (final label in ['Dari Tanggal', 'Sampai Tanggal']) {
      await tester.tap(find.widgetWithText(InkWell, label));
      await tester.pumpAndSettle();
      final picker = find.byType(DatePickerDialog);
      expect(picker, findsOneWidget);
      await tester.tap(
        find.descendant(of: picker, matching: find.text('${today.day}')).last,
      );
      await tester.tap(find.descendant(of: picker, matching: find.text('OK')));
      await tester.pumpAndSettle();
    }
    expect(find.text('2 data'), findsOneWidget);
    expect(find.text('Rp 300'), findsOneWidget);
    await tester.tap(find.byType(SearchableDropdown<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InkWell, 'ATK'));
    await tester.pumpAndSettle();
    expect(find.text('1 data'), findsOneWidget);
    expect(find.text('Rp 100'), findsNWidgets(2));
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(find.text('4 data'), findsOneWidget);
    expect(find.text('Rp 350'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets('AppShell table fills its card and keeps matching column centers', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final font = FontLoader('ExpenseTestSans')
        ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
      await font.load();
    });
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = expenseSession();
    (session.sidebars.single['sidebar'] as Map)['sidebar_nama'] = 'Pengeluaran';
    const note =
        'Pembelian perlengkapan administrasi untuk seluruh ruang rapat dan meja pelayanan kantor';
    await tester.runAsync(() async {
      await db
          .into(db.pengeluaranJenis)
          .insert(
            PengeluaranJenisCompanion.insert(uuid: 'at', nama: 'Perlengkapan'),
          );
      await PengeluaranRepository(db, expenseSession).create((
        noFaktur: 'FA-01',
        tanggal: DateTime(2026, 11, 16),
        nominal: 12500,
        jenisId: 1,
        keterangan: note,
      ));
    });
    await tester.binding.setSurfaceSize(const Size(1728, 900));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((_) => _Auth(session)),
          appDatabaseProvider.overrideWithValue(db),
          developmentUiSmokeProvider.overrideWithValue(true),
        ],
        child: MaterialApp(
          theme: ThemeData(fontFamily: 'ExpenseTestSans'),
          home: AppShell(session: session),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pengeluaran').first);
    await tester.pumpAndSettle();

    final table = find.byType(DataTable);
    final scroll = find.byKey(const Key('pengeluaran-table-scroll'));
    Finder inTable(String value) =>
        find.descendant(of: table, matching: find.text(value));
    for (final size in [
      const Size(1728, 900),
      const Size(1366, 768),
      const Size(1080, 640),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpAndSettle();
      final viewport = tester.getSize(scroll).width;
      expect(tester.getSize(table).width, greaterThanOrEqualTo(viewport));
      final horizontal = tester
          .widget<SingleChildScrollView>(scroll)
          .controller!;
      if (size.width > 1080) {
        expect(horizontal.position.maxScrollExtent, closeTo(0, 0.01));
        expect(tester.getSize(table).width, closeTo(viewport, 0.01));
        final screen = find.byType(PengeluaranDesktopScreen);
        final add = find.widgetWithText(ElevatedButton, 'Tambah Pengeluaran');
        expect(
          tester.getTopRight(add).dx,
          closeTo(tester.getTopRight(screen).dx - 28, 1),
        );
        expect(
          tester.getCenter(find.text('Reset')).dy,
          closeTo(tester.getCenter(find.byType(SearchableDropdown<int>)).dy, 4),
        );
      } else {
        expect(horizontal.position.maxScrollExtent, greaterThan(0));
        await tester.drag(scroll, const Offset(-350, 0));
        await tester.pumpAndSettle();
        expect(horizontal.offset, greaterThan(0));
      }
      for (final (header, value) in [
        ('#', '1'),
        ('No. Faktur', 'FA-01'),
        ('Keterangan', note),
        ('Jenis Pengeluaran', 'Perlengkapan'),
        ('Jumlah', 'Rp 12.500'),
        ('Tanggal Pengeluaran', '16/11/2026'),
      ]) {
        expect(
          tester.getCenter(inTable(header)).dx,
          closeTo(tester.getCenter(inTable(value)).dx, 1),
          reason: header,
        );
      }
      final edit = tester.getCenter(find.byTooltip('Edit')).dx;
      final delete = tester.getCenter(find.byTooltip('Hapus')).dx;
      expect(
        tester.getCenter(inTable('Aksi')).dx,
        closeTo((edit + delete) / 2, 1),
      );
      expect(tester.widget<Text>(inTable(note)).maxLines, 2);
      expect(find.byTooltip(note), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await _unmount(tester);
  });

  testWidgets(
    'read-only desktop shows real totals, search and page navigation',
    (tester) async {
      final exporter = _RecordingExport();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.runAsync(() async {
        await db
            .into(db.pengeluaranJenis)
            .insert(PengeluaranJenisCompanion.insert(uuid: 'at', nama: 'ATK'));
        final repo = PengeluaranRepository(db, expenseSession);
        for (var i = 1; i <= 11; i++) {
          await repo.create((
            noFaktur: 'FA-$i',
            tanggal: DateTime(2026),
            nominal: 100,
            jenisId: 1,
            keterangan: 'Buku $i',
          ));
        }
      });
      await _open(tester, [
        authControllerProvider.overrideWith(
          (_) => _Auth(expenseSession(write: false)),
        ),
        appDatabaseProvider.overrideWithValue(db),
      ], exporter: exporter);
      await tester.pumpAndSettle();
      expect(find.text('11 data'), findsOneWidget);
      expect(find.text('Rp 1.100'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(
              find.ancestor(
                of: find.text('Tambah Pengeluaran'),
                matching: find.byWidgetPredicate(
                  (widget) => widget is ElevatedButton,
                ),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widgetList<IconButton>(
              find.widgetWithIcon(IconButton, Icons.edit_outlined),
            )
            .every((button) => button.onPressed == null),
        isTrue,
      );
      expect(
        tester
            .widgetList<IconButton>(
              find.widgetWithIcon(IconButton, Icons.delete_outline),
            )
            .every((button) => button.onPressed == null),
        isTrue,
      );
      await tester.ensureVisible(find.text('Next'));
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);
      expect(find.text('Rp 1.100'), findsOneWidget);
      expect(find.text('FA-1'), findsOneWidget);
      expect(find.text('FA-2'), findsNothing);
      if (Platform.isWindows) {
        final excel = find.widgetWithText(OutlinedButton, 'Excel');
        await tester.ensureVisible(excel);
        await tester.tap(excel);
        await tester.pump();
        final exporting = find.widgetWithText(OutlinedButton, 'Mengekspor…');
        expect(tester.widget<OutlinedButton>(exporting).onPressed, isNull);
        await tester.tap(exporting);
        expect(exporter.filters.single.page, 1);
        exporter.completion.complete(null);
        await tester.pumpAndSettle();
        expect(find.textContaining('Excel tersimpan'), findsNothing);
      }
      expect(
        tester
            .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Next'))
            .onPressed,
        isNull,
      );
      final search = find.widgetWithText(
        TextField,
        'Cari faktur atau keterangan',
      );
      await tester.ensureVisible(search);
      await tester.enterText(search, 'Buku 11');
      await tester.pumpAndSettle();
      expect(find.text('FA-11'), findsOneWidget);
      expect(find.text('1 / 1'), findsOneWidget);
      expect(find.text('Rp 100'), findsWidgets);
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    },
  );

  testWidgets(
    'compact form validates, saves and can be deleted with confirmation',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = _SlowRepository(db);
      addTearDown(db.close);
      await tester.runAsync(
        () => db
            .into(db.pengeluaranJenis)
            .insert(PengeluaranJenisCompanion.insert(uuid: 'at', nama: 'ATK')),
      );
      await _open(tester, [
        authControllerProvider.overrideWith((_) => _Auth(expenseSession())),
        appDatabaseProvider.overrideWithValue(db),
        pengeluaranRepositoryProvider.overrideWithValue(repository),
      ], size: const Size(360, 800));
      await tester.pumpAndSettle();
      expect(find.text('Belum ada pengeluaran.'), findsOneWidget);
      expect(find.text('Rp 0'), findsOneWidget);
      await tester.tap(find.text('Tambah Pengeluaran'));
      await tester.pumpAndSettle();
      final dialog = find.byType(Dialog);
      expect(tester.widget<Dialog>(dialog).backgroundColor, AppColors.card);
      expect(
        tester.widget<Dialog>(dialog).surfaceTintColor,
        Colors.transparent,
      );
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Simpan'),
            )
            .style
            ?.backgroundColor
            ?.resolve({}),
        AppColors.primaryConfirm,
      );
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(
        find.text('Masukkan nominal Rupiah bulat positif.'),
        findsOneWidget,
      );
      expect(find.text('Keterangan wajib diisi.'), findsOneWidget);
      final dropdown = find.descendant(
        of: dialog,
        matching: find.byType(SearchableDropdown<int>),
      );
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('ATK').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Jumlah (Rp)'),
        '1500',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Keterangan'),
        'Pulpen sintetis',
      );
      await tester.tap(find.text('Simpan'));
      await tester.pump();
      await tester.tap(find.text('Simpan'));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(repository.saves, 1);
      expect(
        tester
            .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.close))
            .onPressed,
        isNull,
      );
      expect(find.byType(Dialog), findsOneWidget);
      repository.saveGate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Pulpen sintetis'), findsOneWidget);
      expect(find.text('Rp 1.500'), findsWidgets);

      final edit = find.widgetWithIcon(IconButton, Icons.edit_outlined);
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      expect(find.text('Edit Pengeluaran'), findsOneWidget);
      expect(find.text('1500'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Keterangan'),
            )
            .controller
            ?.text,
        'Pulpen sintetis',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Jumlah (Rp)'),
        '3000',
      );
      await tester.tap(find.byTooltip('Tutup'));
      await tester.pumpAndSettle();
      expect(find.text('Rp 1.500'), findsWidgets);
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      expect(find.text('1500'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Jumlah (Rp)'),
        '2000',
      );
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(find.text('Rp 2.000'), findsWidgets);

      final delete = find.widgetWithIcon(IconButton, Icons.delete_outline);
      await tester.ensureVisible(delete);
      await tester.tap(delete);
      await tester.pumpAndSettle();
      expect(find.text('Hapus pengeluaran Pulpen sintetis?'), findsOneWidget);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(find.text('Pulpen sintetis'), findsOneWidget);
      await tester.ensureVisible(delete);
      await tester.tap(delete);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
      await tester.pumpAndSettle();
      expect(find.text('Belum ada pengeluaran.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    },
  );

  testWidgets(
    'short form keeps footer and searchable dropdown keyboard-accessible',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.runAsync(() async {
        for (var i = 1; i <= 8; i++) {
          await db
              .into(db.pengeluaranJenis)
              .insert(
                PengeluaranJenisCompanion.insert(
                  uuid: 'jenis-$i',
                  nama: 'Jenis $i',
                ),
              );
        }
      });
      await _open(tester, [
        authControllerProvider.overrideWith((_) => _Auth(expenseSession())),
        appDatabaseProvider.overrideWithValue(db),
      ], size: const Size(900, 430));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tambah Pengeluaran'));
      await tester.pumpAndSettle();
      final form = find.byKey(const Key('pengeluaran-form-scroll'));
      final footer = tester.getCenter(find.text('Simpan'));
      final trigger = find.descendant(
        of: form,
        matching: find.byType(SearchableDropdown<int>),
      );
      final ink = find.descendant(of: trigger, matching: find.byType(InkWell));
      tester.widget<InkWell>(ink).focusNode!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      final search = find.widgetWithText(TextField, 'Cari...');
      expect(search, findsOneWidget);
      await tester.enterText(search, 'Jenis 8');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(InkWell, 'Jenis 8'));
      await tester.pumpAndSettle();
      expect(find.text('Jenis 8'), findsOneWidget);
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(search, findsNothing);
      expect(find.byType(Dialog), findsOneWidget);
      await tester.drag(form, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(tester.getCenter(find.text('Simpan')), footer);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Belum ada pengeluaran.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    },
  );
}
