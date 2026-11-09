import 'services/notarisdev_acceptance_profile.dart';
import 'services/development_transaction_pilot_profile.dart';

// Explicit Windows debug entry. Never consumes the normal development profile.
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'main.dart' show MyApp;
import 'providers/isolated_transaction_profile_provider.dart';
import 'services/transaction_manual_sync_service.dart';

Future<IsolatedTransactionSyncConfiguration> loadIsolatedTransactionUiProfile(
  String manifestPath,
) async {
  if (manifestPath.isEmpty) throw const ManualTransactionFailure('scope');
  final manifest = File(manifestPath).resolveSymbolicLinksSync();
  final data =
      jsonDecode(await File(manifest).readAsString()) as Map<String, dynamic>;
  final profile = data['acceptancePlan'] != null
      ? NotarisdevAcceptanceProfile.fromManifest(data)
      : TransactionManualProfile(
          sqlitePath: data['sqlitePath'] as String,
          baseUrl: data['baseUrl'] as String,
          databaseTarget: data['databaseTarget'] as String,
          deployment: data['deployment'] as String,
          device: data['device'] as String,
          generation: data['generation'] as String,
          accountId: data['accountId'] as int,
          groupId: data['groupId'] as int,
        );
  final canonical = profile.validateLocation();
  if (p.dirname(manifest) != p.dirname(canonical)) {
    throw const ManualTransactionFailure('scope');
  }
  final http = Dio(
    BaseOptions(
      baseUrl: profile.baseUrl,
      connectTimeout: const Duration(seconds: 5),
      sendTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );
  final config = IsolatedTransactionSyncConfiguration.open(
    profile: profile,
    http: http,
  );
  try {
    await profile.validate(config.database);
    return config;
  } catch (_) {
    await config.database.close();
    http.close();
    rethrow;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (!kDebugMode || !Platform.isWindows) {
      throw const ManualTransactionFailure('scope');
    }
    const pilotManifest = String.fromEnvironment('DEVELOPMENT_PILOT_MANIFEST');
    final config = pilotManifest.isEmpty
        ? await loadIsolatedTransactionUiProfile(
            const String.fromEnvironment('TRANSACTION_MONITOR_PROFILE'),
          )
        : await _loadDevelopmentPilot(pilotManifest);
    final profile = config.profile;
    runApp(
      ProviderScope(
        overrides: [
          isolatedTransactionSyncConfigurationProvider.overrideWithValue(
            config,
          ),
        ],
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Banner(
            message: profile is DevelopmentTransactionPilotProfile
                ? (profile.downloadOnly
                      ? 'DEV notarisdev DOWNLOAD ONLY'
                      : 'DEV notarisdev ONE CREATE PILOT')
                : config.profile is NotarisdevAcceptanceProfile
                ? 'DEV notarisdev ISOLATED ACCEPTANCE'
                : 'DISPOSABLE MANUAL SYNC',
            location: BannerLocation.topEnd,
            child: const MyApp(),
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
              'Isolated profile tidak valid. Tidak ada sinkronisasi dimulai. Gunakan manifest disposable yang telah diverifikasi.',
            ),
          ),
        ),
      ),
    );
  }
}

Future<IsolatedTransactionSyncConfiguration> _loadDevelopmentPilot(
  String manifest,
) async {
  final profile = DevelopmentTransactionPilotProfile.open(
    manifest,
    const String.fromEnvironment('DEVELOPMENT_PILOT_MANIFEST_SHA256'),
  );
  final http = Dio(
    BaseOptions(
      baseUrl: profile.baseUrl,
      followRedirects: false,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );
  final config = IsolatedTransactionSyncConfiguration.openDevelopmentPilot(
    profile: profile,
    http: http,
  );
  try {
    await profile.validate(config.database);
    return config;
  } catch (_) {
    await config.database.close();
    http.close();
    rethrow;
  }
}
