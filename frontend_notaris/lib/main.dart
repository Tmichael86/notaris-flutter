import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import 'screens/auth_startup_gate.dart';
import 'h01_acceptance_bootstrap.dart';
import 'h02_acceptance_bootstrap.dart';
import 'release_qa_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const h01 = String.fromEnvironment('NOTARIS_H01_ID');
  const h02 = String.fromEnvironment('NOTARIS_H02_ID');
  if (kReleaseMode) {
    try {
      if (h01.isNotEmpty || h02.isNotEmpty) {
        throw StateError('qa_acceptance_configuration_rejected');
      }
      runApp(
        await releaseQaApplication(
          const ReleaseQaConfiguration(
            environment: String.fromEnvironment('NOTARIS_RELEASE_ENV'),
            deployment: String.fromEnvironment('NOTARIS_RELEASE_DEPLOYMENT'),
            endpoint: String.fromEnvironment('API_BASE_URL'),
            schema: String.fromEnvironment('NOTARIS_RELEASE_SCHEMA'),
          ),
          const MyApp(),
        ),
      );
    } catch (_) {
      runApp(const ReleaseQaBlocked());
    }
    return;
  }
  if (h01.isNotEmpty && h02.isNotEmpty) {
    throw StateError('Ambiguous acceptance profile.');
  }
  if (h02.isNotEmpty) {
    runApp(
      await h02AcceptanceApplication(
        h02,
        const String.fromEnvironment('NOTARIS_H02_HELPER_SHA256'),
        const MyApp(),
      ),
    );
    return;
  }

  if (h01.isNotEmpty) {
    runApp(
      await h01AcceptanceApplication(
        h01,
        const String.fromEnvironment('NOTARIS_H01_HELPER_SHA256'),
        const MyApp(),
      ),
    );
    return;
  }
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SIM Notaris PPAT - Desktop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFF7F7F7),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB71C1C),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const AuthStartupGate(),
    );
  }
}
