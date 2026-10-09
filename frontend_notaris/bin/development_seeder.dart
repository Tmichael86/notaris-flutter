import 'dart:developer' as developer;
import 'package:flutter/widgets.dart';

import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/database/development_seeder.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = AppDatabase();

  try {
    await DevelopmentSeeder.seedIfEmpty(database);
    developer.log(
      'Development SQLite seed completed successfully.',
      name: 'DevelopmentSeeder',
    );
  } catch (error, stackTrace) {
    developer.log(
      'Development SQLite seed failed',
      name: 'DevelopmentSeeder',
      error: error,
      stackTrace: stackTrace,
    );
    rethrow;
  } finally {
    await database.close();
  }
}