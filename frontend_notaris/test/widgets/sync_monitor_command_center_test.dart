import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/core/theme/app_colors.dart';
import 'package:frontend_notaris/core/widgets/sync_page_frame.dart';
import 'package:frontend_notaris/core/widgets/sync_presentation.dart';
import 'package:frontend_notaris/providers/auth_provider.dart';
import 'package:frontend_notaris/providers/development_smoke_provider.dart';
import 'package:frontend_notaris/providers/sync_monitor_provider.dart';
import 'package:frontend_notaris/screens/sync_monitor_desktop_screen.dart';

import 'sync_monitor_screen_test.dart' show LocalAuth;

Map<String, dynamic> snapshot(String module, String label, String color) => {
  'module': module,
  'label': label,
  'color': color,
  'pending_records': color == 'yellow' ? 3 : 0,
  'pending_operations': 0,
  'errors': color == 'red' ? 1 : 0,
  'last_attempt': module == 'transaksi_ppat' ? '2026-11-08T10:00:00Z' : null,
  'last_success': color == 'green' ? '2026-11-07T10:00:00Z' : null,
  'progress': color == 'yellow'
      ? 'Upload diakui; publication/download belum diverifikasi'
      : 'Tidak ada operasi berjalan yang tercatat',
  'reason': 'Read-only: aksi belum didukung.',
  'snapshot_at': '2026-11-08T11:00:00Z',
  'cursor': 8,
};

Future<void> mount(
  WidgetTester t,
  Future<List<Map<String, dynamic>>> Function() read, {
  Size size = const Size(1366, 768),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith((_) => LocalAuth()),
        developmentUiSmokeProvider.overrideWithValue(true),
        syncMonitorProvider.overrideWith((_) => read()),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SyncMonitorDesktopScreen()),
      ),
    ),
  );
  await t.pump();
}

void main() {
  testWidgets(
    'summary counts entries, groups shared feed separately, preserves statuses and detail metadata',
    (t) async {
      await mount(
        t,
        () async => [
          snapshot('transaksi', 'Transaksi (feed gabungan)', 'yellow'),
          snapshot('transaksi_notaris', 'Transaksi Notaris', 'green'),
          snapshot('transaksi_ppat', 'Transaksi PPAT', 'red'),
          snapshot('petugas', 'Petugas', 'neutral'),
          snapshot('future_master', 'Master read-only', 'unknown'),
        ],
      );
      await t.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('summary-attention')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('summary-unknown')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('summary-activity')),
          matching: find.text(syncLocalTime('2026-11-08T10:00:00Z')),
        ),
        findsOneWidget,
      );
      expect(find.text('Transaksi'), findsOneWidget);
      expect(find.text('Data Master'), findsOneWidget);
      expect(find.byKey(const Key('monitor-detail-transaksi')), findsOneWidget);
      expect(
        find.byKey(const Key('monitor-detail-transaksi_notaris')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('monitor-detail-transaksi_ppat')),
        findsOneWidget,
      );
      final badges = t
          .widgetList<SyncStatusBadge>(find.byType(SyncStatusBadge))
          .toList();
      expect(badges.map((b) => b.color), [
        AppColors.warning,
        AppColors.success,
        AppColors.error,
        AppColors.textSecondary,
        AppColors.textSecondary,
      ]);
      final feed = find.byKey(const Key('monitor-detail-transaksi'));
      await t.ensureVisible(feed);
      await t.tap(feed);
      await t.pumpAndSettle();
      expect(
        find.textContaining(
          'Upload diakui; publication/download belum diverifikasi',
        ),
        findsOneWidget,
      );
      expect(find.text('cursor: 8'), findsOneWidget);
      expect(find.textContaining('Error diketahui: 0'), findsOneWidget);
      expect(find.textContaining('Waktu snapshot:'), findsOneWidget);
      expect(
        find.textContaining('bukan penjumlahan record atau outbox server'),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'refresh reads fresh snapshot without executing sync; empty activity is honest',
    (t) async {
      var reads = 0;
      await mount(t, () async {
        reads++;
        return reads == 1 ? [] : [snapshot('pemohon', 'Pemohon', 'neutral')];
      });
      await t.pumpAndSettle();
      expect(find.text('Belum ada modul untuk ditampilkan.'), findsOneWidget);
      expect(find.text('Belum ada aktivitas'), findsOneWidget);
      expect(find.byType(DataTable), findsNothing);
      await t.tap(find.byKey(const Key('refresh-monitor')));
      await t.pumpAndSettle();
      expect(reads, 2);
      expect(find.text('Pemohon'), findsOneWidget);
      expect(find.text('Belum ada modul untuk ditampilkan.'), findsNothing);
    },
  );

  testWidgets('loading and safe error state retry retain read-only controls', (
    t,
  ) async {
    final pending = Completer<List<Map<String, dynamic>>>();
    var reads = 0;
    await mount(t, () {
      reads++;
      return reads == 1 ? pending.future : Future.value([]);
    });
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.completeError(StateError('private error not shown'));
    await t.pumpAndSettle();
    expect(find.textContaining('Snapshot tidak dapat dimuat'), findsOneWidget);
    expect(find.textContaining('private error'), findsNothing);
    await t.tap(find.text('Coba lagi'));
    await t.pumpAndSettle();
    expect(reads, 2);
    expect(find.text('Belum ada aktivitas'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  for (final size in [
    const Size(1366, 768),
    const Size(1920, 1080),
    const Size(600, 650),
  ]) {
    testWidgets(
      'command center responsive list has one vertical scrollbar at $size',
      (t) async {
        await mount(
          t,
          () async => [
            for (var i = 0; i < 9; i++)
              snapshot(
                'master_$i',
                'Master $i dengan nama yang panjang',
                'neutral',
              ),
          ],
          size: size,
        );
        await t.pumpAndSettle();
        expect(find.byType(Scrollbar), findsOneWidget);
        expect(find.byType(DataTable), findsNothing);
        final last = find.byKey(const Key('monitor-detail-master_8'));
        await t.ensureVisible(last);
        await t.tap(last);
        await t.pumpAndSettle();
        expect(
          find.textContaining('Read-only: aksi belum didukung'),
          findsOneWidget,
        );
        expect(t.takeException(), isNull);
      },
    );
  }
}
