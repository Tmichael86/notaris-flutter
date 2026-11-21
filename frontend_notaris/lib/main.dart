import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/auth_startup_gate.dart';
import 'h01_acceptance_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const h01 = String.fromEnvironment('NOTARIS_H01_ID');
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
