import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../services/development_transaction_pilot_profile.dart';
import '../services/transaction_manual_sync_service.dart';

/// Cannot inject an arbitrary/lazy AppDatabase or enable a normal profile with
/// a bool. Only this factory can construct the isolated configuration.
class IsolatedTransactionSyncConfiguration {
  IsolatedTransactionSyncConfiguration._(
    this.profile,
    this.http,
    this.database,
  );
  factory IsolatedTransactionSyncConfiguration.open({
    required TransactionManualProfile profile,
    required Dio http,
  }) {
    if (profile is DevelopmentTransactionPilotProfile) {
      throw const ManualTransactionFailure('scope');
    }
    final canonical = profile.validateLocation(); // rejects daily/normal paths BEFORE any SQLite open
    if (http.options.baseUrl != profile.baseUrl) {
      throw const ManualTransactionFailure('scope');
    }
    return IsolatedTransactionSyncConfiguration._(
      profile,
      http,
      AppDatabase.forTesting(NativeDatabase(File(canonical))),
    );
  }
  factory IsolatedTransactionSyncConfiguration.openDevelopmentPilot({
    required DevelopmentTransactionPilotProfile profile,
    required Dio http,
  }) {
    if (!profile.upload || http.options.baseUrl != profile.baseUrl) {
      throw const ManualTransactionFailure('scope');
    }
    return IsolatedTransactionSyncConfiguration._(
      profile,
      http,
      profile.openDatabase(),
    );
  }
  final TransactionManualProfile profile;
  final Dio http;
  final AppDatabase database;
}

// Normal production/notarisdev entry points never override this provider.
final isolatedTransactionSyncConfigurationProvider =
    Provider<IsolatedTransactionSyncConfiguration?>((ref) => null);
