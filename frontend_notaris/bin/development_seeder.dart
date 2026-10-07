import 'package:flutter/widgets.dart';

import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/database/development_seeder.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = AppDatabase();

  try {
    await DevelopmentSeeder.seedIfEmpty(database);
    print('Development SQLite seed completed successfully.');
  } catch (error, stackTrace) {
    print('Development SQLite seed failed: $error');
    print(stackTrace);
    rethrow;
  } finally {
    await database.close();
  }
}
