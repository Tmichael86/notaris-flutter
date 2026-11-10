import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/core/widgets/searchable_dropdown.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/models/auth_session.dart';
import 'package:frontend_notaris/providers/auth_provider.dart';
import 'package:frontend_notaris/providers/database_provider.dart';
import 'package:frontend_notaris/providers/pengeluaran_provider.dart';
import 'package:frontend_notaris/repositories/pengeluaran_repository.dart';
import 'package:frontend_notaris/screens/pengeluaran_desktop_screen.dart';
import 'package:frontend_notaris/services/auth_service.dart';

import '../repositories/pengeluaran_repository_test.dart' show expenseSession;

class _Auth extends AuthController {
  _Auth(AuthSession? session) : super(AuthService(dio: Dio())) {
    setSession(session);
  }

  void setSession(AuthSession? session) => state = session == null
      ? AuthState.unauthenticated()
      : AuthState.authenticated(session);
}

Future<void> _open(
  WidgetTester tester,
  List<Override> overrides, {
  Size size = const Size(1366, 768),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: PengeluaranDesktopScreen()),
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
    expect(find.textContaining('Total Pengeluaran:'), findsNothing);
    await _unmount(tester);
  });

  testWidgets(
    'read-only desktop shows real totals, search and page navigation',
    (tester) async {
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
      ]);
      await tester.pumpAndSettle();
      expect(find.text('11 data'), findsOneWidget);
      expect(find.text('Total Pengeluaran: Rp 1.100'), findsOneWidget);
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
      expect(find.text('FA-1'), findsOneWidget);
      expect(find.text('FA-2'), findsNothing);
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
      expect(find.text('Total Pengeluaran: Rp 100'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    },
  );

  testWidgets(
    'compact form validates, saves and can be deleted with confirmation',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.runAsync(
        () => db
            .into(db.pengeluaranJenis)
            .insert(PengeluaranJenisCompanion.insert(uuid: 'at', nama: 'ATK')),
      );
      await _open(tester, [
        authControllerProvider.overrideWith((_) => _Auth(expenseSession())),
        appDatabaseProvider.overrideWithValue(db),
      ], size: const Size(360, 800));
      await tester.pumpAndSettle();
      expect(find.text('Belum ada pengeluaran.'), findsOneWidget);
      await tester.tap(find.text('Tambah Pengeluaran'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(
        find.text('Masukkan nominal Rupiah bulat positif.'),
        findsOneWidget,
      );
      expect(find.text('Keterangan wajib diisi.'), findsOneWidget);
      final dialog = find.byType(AlertDialog);
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
      await tester.pumpAndSettle();
      expect(find.text('Pulpen sintetis'), findsOneWidget);
      expect(find.text('Total Pengeluaran: Rp 1.500'), findsOneWidget);

      final edit = find.widgetWithIcon(IconButton, Icons.edit_outlined);
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      expect(find.text('Edit Pengeluaran'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Jumlah (Rp)'),
        '2000',
      );
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(find.text('Total Pengeluaran: Rp 2.000'), findsOneWidget);

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
}
