import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/core/widgets/master_data_viewport.dart';
import 'package:frontend_notaris/providers/sync_log_provider.dart';
import 'package:frontend_notaris/providers/sync_monitor_provider.dart';
import 'package:frontend_notaris/providers/development_smoke_provider.dart';
import 'package:frontend_notaris/providers/auth_provider.dart';
import 'package:frontend_notaris/screens/sync_log_desktop_screen.dart';
import 'package:frontend_notaris/screens/sync_monitor_desktop_screen.dart';

import 'sync_monitor_screen_test.dart' show LocalAuth;

void main() {
  for (final size in [
    const Size(980, 600),
    const Size(1280, 720),
    const Size(1920, 1080),
  ]) {
    for (final monitor in [false, true]) {
      testWidgets(
        '${monitor ? 'Monitoring' : 'Log'} card and single scrollbar per axis at $size',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final longText = List.filled(
            12,
            'Keterangan panjang perlu tetap terbaca.',
          ).join(' ');
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authControllerProvider.overrideWith((ref) => LocalAuth()),
                developmentUiSmokeProvider.overrideWithValue(true),
                syncLogsProvider.overrideWith(
                  (ref, arg) async => [
                    for (var i = 0; i < 12; i++)
                      {
                        'started_at': '2026-11-02T00:00:00Z',
                        'module': 'pemohon',
                        'direction': 'pull',
                        'status': 'success',
                        'record_count': 20,
                        'error_code': null,
                        'error_message': null,
                        'operation_id': 'operation-$i',
                        'attempt_id': 'attempt-$i',
                      },
                  ],
                ),
                syncMonitorProvider.overrideWith(
                  (ref) async => [
                    for (var i = 0; i < 12; i++)
                      {
                        'label': 'Pemohon $i',
                        'color': 'yellow',
                        'last_attempt': null,
                        'last_success': null,
                        'pending_records': 2,
                        'pending_operations': 1,
                        'errors': 0,
                        'progress': longText,
                      },
                  ],
                ),
              ],
              child: MaterialApp(
                theme: ThemeData(platform: TargetPlatform.windows),
                home: Scaffold(
                  body: monitor
                      ? const SyncMonitorDesktopScreen()
                      : const SyncLogDesktopScreen(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            find.text(
              'System > ${monitor ? 'Monitoring Sinkronisasi' : 'Log Sinkronisasi'}',
            ),
            findsOneWidget,
          );
          expect(find.byType(Card), findsOneWidget);
          expect(
            find.ancestor(
              of: find.byType(DataTable),
              matching: find.byType(Card),
            ),
            findsOneWidget,
          );
          expect(find.byType(Scrollbar), findsNWidgets(2));
          final viewport = tester.widget<MasterDataTableViewport>(
            find.byType(MasterDataTableViewport),
          );
          viewport.horizontalController.jumpTo(
            viewport.horizontalController.position.maxScrollExtent,
          );
          await tester.pumpAndSettle();
          if (monitor) {
            expect(find.byKey(const Key('open-manual-sync')), findsOneWidget);
            await tester.tap(find.text('Lihat detail').first);
            await tester.pumpAndSettle();
            final text = find.textContaining(longText).first;
            expect(
              tester.getRect(text).right,
              lessThanOrEqualTo(tester.getRect(find.byType(Card)).right),
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('empty log remains inside proportional card', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [syncLogsProvider.overrideWith((ref, arg) async => [])],
        child: MaterialApp(home: Scaffold(body: SyncLogDesktopScreen())),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.ancestor(
        of: find.text('Belum ada aktivitas sinkronisasi untuk filter ini.'),
        matching: find.byType(Card),
      ),
      findsOneWidget,
    );
    expect(tester.getSize(find.byType(Card)).height, greaterThan(300));
  });
}
