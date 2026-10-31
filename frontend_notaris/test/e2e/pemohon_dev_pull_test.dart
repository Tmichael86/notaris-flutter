// Opt-in GET-only smoke against the approved synthetic development database.
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/providers/database_provider.dart';
import 'package:frontend_notaris/providers/authenticated_api_provider.dart';
import 'package:frontend_notaris/providers/app_providers.dart';
import 'package:frontend_notaris/providers/pekerjaan_provider.dart';
import 'package:frontend_notaris/repositories/pemohon_gender_references.dart';

void main() {
  test('development initial and manual coordinator pull 20 Pemohon with verified fixture references', () async {
    final root = Platform.environment['NOTARIS_DEV_SMOKE_ROOT']!;
    final profile = jsonDecode(
      await File('$root/.local/notarisdev-profile.json').readAsString(),
    ) as Map;
    expect(profile['database'], 'notarisdev');
    expect(profile['fixture'], 'smoke-v1');
    final generation = profile['generation'] as String;
    expect(RegExp(r'^[a-f0-9]{32}$').hasMatch(generation), isTrue);
    final credentials = jsonDecode(
      await File('$root/.local/notarisdev-$generation/login.private.json')
          .readAsString(),
    ) as Map;
    final manifest = jsonDecode(
      Platform.environment['NOTARIS_DEV_REFERENCE_MANIFEST']!,
    ) as Map<String, dynamic>;
    final dio = Dio(
      BaseOptions(
        baseUrl: 'http://127.0.0.1:8081/api/v1',
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.method != 'GET' &&
              !(options.method == 'POST' && options.path == '/auth/login')) {
            return handler.reject(
              DioException(
                requestOptions: options,
                error: 'Live smoke forbids server mutations',
              ),
            );
          }
          handler.next(options);
        },
      ),
    );
    final response = await dio.post(
      '/auth/login',
      data: {
        'username': credentials['username'],
        'password': credentials['password'],
      },
    );
    final token = response.data['data']['token'];
    expect(token, isA<String>());
    dio.options.headers['Authorization'] = 'Bearer $token';
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final refs = DevelopmentPemohonGenderReferences(db, dio, manifest);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        authenticatedDioProvider.overrideWithValue(dio),
        pemohonGenderReferencesProvider.overrideWithValue(refs),
      ],
    );
    try {
      await container.read(syncCoordinatorProvider).synchronizeNow();
      expect(container.read(syncStatusProvider), SyncStatus.success);
      final initial = await db.select(db.pemohons).get();
      expect(initial.length, 20);
      expect(
        initial.every((r) => r.uuid.startsWith('fa000001-') && !r.isSyncDirty),
        isTrue,
      );
      expect(
        initial.every((r) => r.jenisKelamin == initial.first.jenisKelamin),
        isTrue,
      );
      expect(initial.first.jenisKelamin, await refs.toLocal(29));
      expect(initial.first.jenisKelamin, isNot(29));
      await container.read(syncCoordinatorProvider).synchronizeNow();
      expect((await db.select(db.pemohons).get()).length, 20);
      expect(container.read(syncStatusProvider), SyncStatus.success);
    } finally {
      container.dispose();
      await db.close();
      dio.close();
    }
  }, skip: Platform.environment['NOTARIS_PEMOHON_DEV_SMOKE'] != '1');
}
