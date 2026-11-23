import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/providers/auth_provider.dart';
import 'package:frontend_notaris/providers/database_provider.dart';
import 'package:frontend_notaris/screens/pekerjaan_notaris_desktop_screen.dart';
import 'package:frontend_notaris/screens/pekerjaan_ppat_desktop_screen.dart';
import 'package:frontend_notaris/screens/kategori_pekerjaan_desktop_screen.dart';
import 'package:frontend_notaris/screens/jenis_pengeluaran_desktop_screen.dart';
import 'package:frontend_notaris/screens/petugas_desktop_screen.dart';
import 'package:frontend_notaris/screens/pemohon_desktop_screen.dart';

import '../support/local_master_test_authority.dart';
import '../support/transaction_ui_test_support.dart' show cycleUi;
import '../repositories/local_master_authorization_test.dart'
    show seedMasters, masterSnapshot;

void main() {
  final screens = <String, Widget>{
    'notaris': const PekerjaanNotarisDesktopScreen(),
    'ppat': const PekerjaanPPATDesktopScreen(),
    'category': const KategoriPekerjaanDesktopScreen(),
    'expense': const JenisPengeluaranDesktopScreen(),
    'officer': const PetugasDesktopScreen(),
    'applicant': const PemohonDesktopScreen(),
  };
  for (final entry in screens.entries) {
    testWidgets(
      '${entry.key} read-only actions disabled, live grant refresh enables and logout disables',
      (t) async {
        t.view.physicalSize = const Size(1920, 1000);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await t.runAsync(() => seedMasters(db));
        final auth = MasterTestAuth(masterTestSession(actions: []));
        final c = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            authControllerProvider.overrideWith((ref) => auth),
          ],
        );
        await t.pumpWidget(
          UncontrolledProviderScope(
            container: c,
            child: MaterialApp(
              theme: ThemeData(fontFamily: 'Roboto'),
              home: Scaffold(body: entry.value),
            ),
          ),
        );
        await cycleUi(t);
        final edits = find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'Edit',
        );
        final deletes = find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'Hapus',
        );
        expect(edits, findsWidgets);
        expect(deletes, findsWidgets);
        expect(
          t.widgetList<IconButton>(edits).every((b) => b.onPressed == null),
          true,
        );
        expect(
          t.widgetList<IconButton>(deletes).every((b) => b.onPressed == null),
          true,
        );
        auth.replace(masterTestSession());
        await cycleUi(t);
        expect(
          t.widgetList<IconButton>(edits).every((b) => b.onPressed != null),
          true,
        );
        auth.replace(null);
        await cycleUi(t);
        expect(
          t.widgetList<IconButton>(edits).every((b) => b.onPressed == null),
          true,
        );
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        c.dispose();
        await cycleUi(t);
        await t.pump(const Duration(seconds: 1));
      },
    );
  }
  for (final change in ['revocation', 'account', 'profile']) {
    testWidgets('open metadata dialog cannot save after $change change', (
      t,
    ) async {
      t.view.physicalSize = const Size(1500, 950);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await t.runAsync(() => seedMasters(db));
      final before = await t.runAsync(() => masterSnapshot(db));
      final auth = MasterTestAuth();
      final c = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          authControllerProvider.overrideWith((ref) => auth),
        ],
      );
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(
            home: Scaffold(body: KategoriPekerjaanDesktopScreen()),
          ),
        ),
      );
      await cycleUi(t);
      await t.tap(find.byTooltip('Edit').first);
      await cycleUi(t);
      await t.enterText(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextField),
            )
            .first,
        'Changed without approval',
      );
      AppDatabase? switched;
      String? switchedBefore;
      if (change == 'profile') {
        switched = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(switched.close);
        await t.runAsync(() => seedMasters(switched!));
        switchedBefore = await t.runAsync(() => masterSnapshot(switched!));
        c.updateOverrides([
          appDatabaseProvider.overrideWithValue(switched),
          authControllerProvider.overrideWith((ref) => auth),
        ]);
      } else {
        auth.replace(
          masterTestSession(
            uid: change == 'account' ? 2 : 1,
            actions: change == 'account' ? null : [],
          ),
        );
      }
      await cycleUi(t);
      await t.tap(find.text('Simpan Perubahan').last);
      await cycleUi(t);
      expect(await t.runAsync(() => masterSnapshot(db)), before);
      if (switched != null) {
        expect(
          await t.runAsync(() => masterSnapshot(switched!)),
          switchedBefore,
        );
      }
      expect(find.textContaining('Akses Master ditolak'), findsWidgets);
      expect(t.takeException(), isNull);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await cycleUi(t);
      await t.pumpWidget(const SizedBox());
      c.dispose();
      await cycleUi(t);
      await t.pump(const Duration(seconds: 1));
    });
  }
}
