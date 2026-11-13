import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/providers/recycle_bin_provider.dart';
import 'package:frontend_notaris/providers/development_smoke_provider.dart';
import 'package:frontend_notaris/repositories/pekerjaan_repository.dart';
import 'package:frontend_notaris/repositories/recycle_bin_repository.dart';
import 'package:frontend_notaris/screens/recycle_bin_desktop_screen.dart';

import '../repositories/recycle_bin_repository_test.dart'
    show recoverySession, seedMaster;

void main() {
  late AppDatabase db;
  late RecycleBinRepository repo;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = RecycleBinRepository(db, () => recoverySession());
  });
  tearDown(() => db.close());

  testWidgets(
    'revoked read permission on selected module hides records without dropdown assertion',
    (tester) async {
      var allowed = true;
      repo = RecycleBinRepository(db, () => allowed ? recoverySession() : null);
      await seedMaster(db, 'ppat');
      await PekerjaanPpatRepository(db.pekerjaanDao).delete(1);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            recycleBinRepositoryProvider.overrideWithValue(repo),
            recycleBinRecordsProvider.overrideWith(
              (ref, module) => repo.list(module: module),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: RecycleBinDesktopScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButton<RecycleModule?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pekerjaan PPAT').last);
      await tester.pumpAndSettle();
      allowed = false;
      await tester.tap(find.byTooltip('Muat ulang Recycle Bin'));
      await tester.pumpAndSettle();
      expect(find.text('Same label'), findsNothing);
      expect(
        find.text('Tidak ada data terhapus untuk modul yang dapat Anda akses.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  Future<void> show(
    WidgetTester tester, {
    Future<List<RecycleRecord>> Function(RecycleModule?)? load,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recycleBinRepositoryProvider.overrideWithValue(repo),
          recycleBinRecordsProvider.overrideWith(
            (ref, module) => load?.call(module) ?? repo.list(module: module),
          ),
          developmentUiSmokeProvider.overrideWithValue(true),
        ],
        child: const MaterialApp(
          home: Scaffold(body: RecycleBinDesktopScreen()),
        ),
      ),
    );
  }

  testWidgets(
    'local restore confirms cancels and commits in UI Smoke; refresh and history show real outcome',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await seedMaster(db, 'notaris');
      await PekerjaanNotarisRepository(db.pekerjaanDao).delete(1);
      await show(tester);
      await tester.pumpAndSettle();
      expect(find.text('Same label'), findsOneWidget);
      final click = tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Restore'))
          .onPressed!;
      click();
      click(); // Two callbacks still produce exactly one confirmation.
      await tester.pumpAndSettle();
      expect(find.text('Pulihkan data lokal?'), findsOneWidget);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(await repo.list(), hasLength(1));
      expect(await repo.history(), isEmpty);
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pulihkan'));
      await tester.pumpAndSettle();
      expect(
        find.text('Tidak ada data terhapus untuk modul yang dapat Anda akses.'),
        findsOneWidget,
      );
      expect(
        find.text('Data berhasil dipulihkan secara lokal.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Histori pemulihan'));
      await tester.pumpAndSettle();
      expect(find.text('pekerjaan_notaris • Berhasil'), findsOneWidget);
      expect((await repo.history()), hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'module filter and narrow desktop do not overflow; cloud restore disabled with reason',
    (tester) async {
      tester.view.physicalSize = const Size(600, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await seedMaster(db, 'notaris');
      await seedMaster(db, 'ppat');
      await PekerjaanNotarisRepository(db.pekerjaanDao).delete(1);
      await PekerjaanPpatRepository(db.pekerjaanDao).delete(1);
      await db.customStatement('UPDATE pekerjaan_ppat SET last_synced_at=10');
      await show(tester);
      await tester.pumpAndSettle();
      final dropdown = find.byType(DropdownButton<RecycleModule?>);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pekerjaan PPAT').last);
      await tester.pumpAndSettle();
      expect(find.text('Same label'), findsOneWidget);
      expect(
        find.textContaining('Restore cloud belum didukung'),
        findsOneWidget,
      );
      final restore = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Restore'),
      );
      expect(restore.onPressed, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('loading error retry and empty states do not invent data', (
    tester,
  ) async {
    final pending = Completer<List<RecycleRecord>>();
    var call = 0;
    await show(
      tester,
      load: (_) {
        call++;
        if (call == 1) return pending.future;
        return Future.value([]);
      },
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.completeError(StateError('private error'));
    await tester.pumpAndSettle();
    expect(
      find.text('Recycle Bin tidak dapat dimuat. Data tidak diubah.'),
      findsOneWidget,
    );
    expect(find.textContaining('private error'), findsNothing);
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(
      find.text('Tidak ada data terhapus untuk modul yang dapat Anda akses.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'permission revoked after confirmation yields failure without restore',
    (tester) async {
      var allowed = true;
      repo = RecycleBinRepository(db, () => recoverySession(update: allowed));
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await seedMaster(db, 'ppat');
      await PekerjaanPpatRepository(db.pekerjaanDao).delete(1);
      await show(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();
      allowed = false;
      await tester.tap(find.text('Pulihkan'));
      await tester.pumpAndSettle();
      expect(
        find.text('Izin baca dan ubah modul diperlukan untuk memulihkan.'),
        findsWidgets,
      );
      expect((await repo.history()).single['outcome'], 'failed');
      expect(await repo.list(), hasLength(1));
      await tester.pumpWidget(const SizedBox());
    },
  );
}
