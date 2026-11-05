import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/providers/database_provider.dart';
import 'package:frontend_notaris/providers/petugas_manual_sync_provider.dart';
import 'package:frontend_notaris/providers/pekerjaan_provider.dart';
import 'package:frontend_notaris/repositories/people_repository.dart';
import 'package:frontend_notaris/core/widgets/petugas_manual_sync_panel.dart';
import 'package:frontend_notaris/screens/petugas_desktop_screen.dart';
import 'package:frontend_notaris/services/petugas_sync_api.dart';

void main() {
  test(
    'manual feature default OFF; absent harness blocks invocation',
    () async {
      expect(petugasManualBuildEnabled, false);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(petugasManualEnabledProvider), false);
      await container.read(petugasManualControllerProvider.notifier).run();
      expect(
        container.read(petugasManualControllerProvider).status,
        PetugasManualStatus.blocked,
      );
    },
  );
  testWidgets(
    'OFF hides controls; enabled without ready profile disables sync',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: PetugasManualSyncPanel())),
        ),
      );
      expect(find.text('Sync Petugas manual'), findsNothing);
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [petugasManualEnabledProvider.overrideWithValue(true)],
          child: const MaterialApp(
            home: Scaffold(body: PetugasManualSyncPanel()),
          ),
        ),
      );
      final button = tester.widget<OutlinedButton>(
        find.byKey(const Key('petugas-manual-sync')),
      );
      expect(button.onPressed, isNull);
    },
  );
  testWidgets(
    'valid prepared profile shows loading then success without global coordinator',
    (tester) async {
      final done = Completer<void>();
      final container = ProviderContainer(
        overrides: [
          petugasManualEnabledProvider.overrideWithValue(true),
          petugasManualActionProvider.overrideWithValue(() => done.future),
          syncCoordinatorProvider.overrideWith(
            (ref) =>
                throw StateError('global coordinator must remain untouched'),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(petugasManualReadyProvider.notifier).state = true;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: PetugasManualSyncPanel()),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('petugas-manual-sync')));
      await tester.pump();
      expect(
        container.read(petugasManualControllerProvider).status,
        PetugasManualStatus.syncing,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('petugas-manual-sync')),
            )
            .onPressed,
        isNull,
      );
      done.complete();
      await tester.pumpAndSettle();
      expect(
        container.read(petugasManualControllerProvider).status,
        PetugasManualStatus.success,
      );
    },
  );
  for (final entry in {
    PetugasSyncFailureKind.timeout: 'pending',
    PetugasSyncFailureKind.network: 'pending',
    PetugasSyncFailureKind.blockedReference: 'blocked_reference',
    PetugasSyncFailureKind.blocked: 'identity ambiguous',
    PetugasSyncFailureKind.conflict: '409 conflict',
    PetugasSyncFailureKind.expired: '410 full_resync_required',
    PetugasSyncFailureKind.server: 'failed',
  }.entries) {
    test(
      'manual status ${entry.key.name} preserves explicit blocker',
      () async {
        final c = ProviderContainer(
          overrides: [
            petugasManualEnabledProvider.overrideWithValue(true),
            petugasManualActionProvider.overrideWithValue(
              () async => throw PetugasSyncFailure(entry.key),
            ),
          ],
        );
        addTearDown(c.dispose);
        c.read(petugasManualReadyProvider.notifier).state = true;
        await c.read(petugasManualControllerProvider.notifier).run();
        expect(
          c.read(petugasManualControllerProvider).message,
          contains(entry.value),
        );
      },
    );
  }
  testWidgets(
    'Petugas keeps 10 rows per page and scrollable table with manual panel',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      for (var i = 0; i < 11; i++) {
        await PetugasRepository(db)
            .create(nama: 'Fixture $i', email: 'fixture$i@e2e.invalid');
      }
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            petugasManualEnabledProvider.overrideWithValue(true),
            syncCoordinatorProvider.overrideWith(
              (ref) => throw StateError('not global sync'),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: PetugasDesktopScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<DataTable>(find.byType(DataTable)).rows.length, 10);
      expect(find.text('Halaman 1 / 2'), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsWidgets);
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(tester.widget<DataTable>(find.byType(DataTable)).rows.length, 1);
      expect(find.text('Halaman 2 / 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
