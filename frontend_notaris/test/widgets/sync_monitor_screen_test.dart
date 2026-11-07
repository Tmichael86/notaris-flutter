import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:frontend_notaris/providers/auth_provider.dart';
import 'package:frontend_notaris/providers/development_smoke_provider.dart';
import 'package:frontend_notaris/providers/sync_monitor_provider.dart';
import 'package:frontend_notaris/services/auth_service.dart';
import 'package:frontend_notaris/screens/sync_monitor_desktop_screen.dart';

class LocalAuth extends AuthController {
  LocalAuth() : super(AuthService(dio: Dio()));
}

void main() {
  for (final smoke in [true, false]) {
    testWidgets(
      'smoke=$smoke: selection stays disabled including Notaris bridge; empty and offline visible',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authControllerProvider.overrideWith((ref) => LocalAuth()),
              developmentUiSmokeProvider.overrideWithValue(smoke),
              syncMonitorProvider.overrideWith((ref) async => []),
            ],
            child: const MaterialApp(
              home: Scaffold(body: SyncMonitorDesktopScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Belum ada modul untuk ditampilkan.'), findsOneWidget);
        expect(find.textContaining('Offline /'), findsOneWidget);
        expect(find.byKey(const Key('manual-sync-module')), findsNothing);
        await tester.tap(find.byKey(const Key('open-manual-sync')));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(Dialog),
            matching: find.text('Pusat Sinkronisasi'),
          ),
          findsOneWidget,
        );
        expect(
          find.text('MY NOTARIS · Administrasi Notaris & PPAT'),
          findsOneWidget,
        );
        expect(
          find.text('Alur operasi · bukan indikator koneksi online'),
          findsOneWidget,
        );
        expect(
          tester.getSize(find.byKey(const Key('manual-sync-surface'))).height,
          lessThan(650),
        );
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('manual-sync-execute')),
              )
              .onPressed,
          isNull,
        );
        final module = tester.widget<SegmentedButton<String>>(
          find.byKey(const Key('manual-sync-module')),
        );
        expect(module.segments.map((e) => e.value), [
          'transaksi_notaris',
          'transaksi_ppat',
        ]);
        expect(find.text('Kategori Pekerjaan'), findsNothing);
        await tester.tap(find.text('Download').first);
        await tester.pumpAndSettle();
        expect(find.textContaining('satu cursor bersama'), findsOneWidget);
        expect(find.byKey(const Key('manual-sync-module')), findsNothing);
        expect(find.byType(TextField), findsNothing);
        expect(
          find.byKey(const Key('manual-sync-record-transaksi_notaris')),
          findsNothing,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('manual-sync-execute')),
              )
              .onPressed,
          isNull,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('manual-sync-module')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
