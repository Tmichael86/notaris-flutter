import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/providers/sync_log_provider.dart';
import 'package:frontend_notaris/screens/sync_log_desktop_screen.dart';
import 'package:frontend_notaris/core/widgets/sync_presentation.dart';

void main() {
  for (final width in [1366.0, 700.0]) {
    testWidgets(
      'log detail filters pagination local timestamp and overflow width=$width',
      (t) async {
        t.view.physicalSize = Size(width, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        String? copied;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'Clipboard.setData') {
                copied = (call.arguments as Map)['text'] as String;
              }
              return null;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null),
        );
        final rows = [
          for (var i = 0; i < 25; i++)
            {
              'id': i,
              'module': i == 0 ? 'transaksi_ppat' : 'pemohon',
              'direction': 'push',
              'status': i == 0 ? 'failed' : 'success',
              'record_count': i == 0 ? null : 1,
              'started_at': '2026-11-07T02:06:36.651838Z',
              'finished_at': '2026-11-07T02:06:37Z',
              'error_code': i == 0 ? 'conflict' : null,
              'error_message': i == 0 ? 'Riwayat PPAT tetap tersimpan' : null,
              'attempt_id':
                  'attempt-${List.filled(20, '12345678-abcd-efab-cdef-123456789012').join()}',
              'operation_id': 'operation-$i',
            },
        ];
        await t.pumpWidget(
          ProviderScope(
            overrides: [
              syncLogsProvider.overrideWith(
                (ref, f) async => rows
                    .where(
                      (r) =>
                          (f.module == null || r['module'] == f.module) &&
                          (f.status == null || r['status'] == f.status),
                    )
                    .toList(),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(body: SyncLogDesktopScreen()),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(
          find.text(syncLocalTime('2026-11-07T02:06:36.651838Z')),
          findsWidgets,
        );
        expect(find.text('1–20 dari 25'), findsOneWidget);
        await t.tap(
          find.text(syncLocalTime('2026-11-07T02:06:36.651838Z')).first,
        );
        await t.pumpAndSettle();
        expect(find.byKey(const Key('sync-log-details')), findsOneWidget);
        expect(find.text('conflict'), findsOneWidget);
        expect(find.text('Riwayat PPAT tetap tersimpan'), findsOneWidget);
        expect(find.byTooltip('Salin Attempt ID'), findsOneWidget);
        expect(
          find.text(
            syncLocalTime('2026-11-07T02:06:36.651838Z', precise: true),
          ),
          findsOneWidget,
        );
        await t.ensureVisible(find.byTooltip('Salin Attempt ID'));
        await t.tap(find.byTooltip('Salin Attempt ID'));
        await t.pump();
        expect(copied, rows.first['attempt_id']);
        expect(t.takeException(), isNull);
        await t.tap(find.byTooltip('Tutup detail'));
        await t.pumpAndSettle();
        await t.tap(find.byTooltip('Halaman berikutnya'));
        await t.pumpAndSettle();
        expect(find.text('21–25 dari 25'), findsOneWidget);
        await t.tap(find.text('Semua status'));
        await t.pumpAndSettle();
        await t.tap(find.text('Gagal').last);
        await t.pumpAndSettle();
        expect(find.text('1–1 dari 1'), findsOneWidget);
        expect(find.text('Gagal'), findsWidgets);
        expect(t.takeException(), isNull);
        await t.tap(find.text('Semua modul'));
        await t.pumpAndSettle();
        await t.tap(find.text('transaksi_ppat').last);
        await t.pumpAndSettle();
        expect(find.text('1–1 dari 1'), findsOneWidget);
        expect(rows.first['status'], 'failed');
        await t.pumpWidget(const SizedBox());
      },
    );
  }
}
