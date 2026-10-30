// Debug-only normal application bootstrap. No test JWT or harness session.
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'database/app_database.dart';
import 'main.dart' show MyApp;
import 'providers/app_providers.dart';
import 'providers/auth_provider.dart';
import 'providers/database_provider.dart';
import 'services/auth_service.dart';

String developmentGeneration(Map<String, String> environment) {
  final generation = environment['NOTARIS_DEV_GENERATION'] ?? '';
  if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(generation)) {
    throw StateError(
      'Use run-notarisdev-flutter.ps1 after approved provisioning',
    );
  }
  return generation;
}

String developmentDatabasePath(String supportPath, String generation) {
  developmentGeneration({'NOTARIS_DEV_GENERATION': generation});
  return p.join(supportPath, 'notarisdev', generation, 'offline.sqlite');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (!kDebugMode || !Platform.isWindows) {
      throw StateError('Windows debug only');
    }
    final generation = developmentGeneration(Platform.environment);
    final support = await getApplicationSupportDirectory();
    final file = File(developmentDatabasePath(support.path, generation));
    final folder = file.parent;
    await folder.create(recursive: true);
    final db = AppDatabase(NativeDatabase(file));
    runApp(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((ref) {
            ref.onDispose(db.close);
            return db;
          }),
          dioProvider.overrideWith(
            (ref) => Dio(
              BaseOptions(
                baseUrl: 'http://127.0.0.1:8081/api/v1',
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
                sendTimeout: const Duration(seconds: 10),
              ),
            ),
          ),
          authServiceProvider.overrideWith(
            (ref) => AuthService(
              dio: ref.watch(dioProvider),
              cacheKey: 'notaris.auth.notarisdev.$generation',
            ),
          ),
        ],
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: Banner(
            message: 'DEV notarisdev',
            location: BannerLocation.topEnd,
            child: MyApp(),
          ),
        ),
      ),
    );
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Development profile blocked. Use run-notarisdev-flutter.ps1. Normal SQLite and auth cache were not opened.',
            ),
          ),
        ),
      ),
    );
  }
}
