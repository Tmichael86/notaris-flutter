import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/providers/sync_log_provider.dart';
import 'package:frontend_notaris/screens/sync_log_desktop_screen.dart';

void main() {
  testWidgets('loading empty error states and local reload', (tester) async {
    final pending = Completer<List<Map<String, dynamic>>>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncLogsProvider.overrideWith((ref, arg) => pending.future),
        ],
        child: const MaterialApp(home: Scaffold(body: SyncLogDesktopScreen())),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete([]);
    await tester.pumpAndSettle();
    expect(
      find.text('Belum ada aktivitas sinkronisasi untuk filter ini.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncLogsProvider.overrideWith(
            (ref, arg) => Future.error(StateError('private')),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: SyncLogDesktopScreen())),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Histori tidak dapat dimuat. Data tidak dihapus.'),
      findsOneWidget,
    );
    expect(find.textContaining('private'), findsNothing);
  });
}
