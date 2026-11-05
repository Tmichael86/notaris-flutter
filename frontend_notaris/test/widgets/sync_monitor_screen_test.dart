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
  testWidgets(
    'smoke selection cannot execute any module or direction; empty and offline visible',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((ref) => LocalAuth()),
            developmentUiSmokeProvider.overrideWithValue(true),
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
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.tap(find.text('Upload'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Download').last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    },
  );
}
