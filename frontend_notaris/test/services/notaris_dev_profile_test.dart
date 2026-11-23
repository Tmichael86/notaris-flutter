import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/notaris_dev_main.dart';
import 'package:frontend_notaris/services/auth_service.dart';

import 'dart:io';

import 'package:drift/native.dart';
import 'package:frontend_notaris/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'separate SQLite keeps daily rows and cursor out of development',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'notaris-profile-test-',
      );
      final normal = AppDatabase(
        NativeDatabase(File('${temp.path}/notaris_offline.sqlite')),
      );
      final path = developmentDatabasePath(temp.path, 'b' * 32);
      await File(path).parent.create(recursive: true);
      final dev = AppDatabase(NativeDatabase(File(path)));
      try {
        await normal
            .into(normal.petugasLocals)
            .insert(
              PetugasLocalsCompanion.insert(
                uuid: 'daily-local-uuid',
                nama: 'Daily fixture',
                email: 'daily@example.invalid',
              ),
            );
        await normal.customStatement(
          "INSERT INTO petugas_sync_feed(id,scope,cursor) VALUES(1,'old-server',17)",
        );
        expect(await dev.select(dev.petugasLocals).get(), isEmpty);
        expect(
          await dev.customSelect('SELECT * FROM petugas_sync_feed').get(),
          isEmpty,
        );
        expect(await dev.select(dev.petugasIdentityMaps).get(), isEmpty);
        expect(
          (await normal.select(normal.petugasLocals).getSingle()).isSyncDirty,
          isTrue,
        );
        expect(
          (await normal
                  .customSelect('SELECT cursor FROM petugas_sync_feed')
                  .getSingle())
              .read<int>('cursor'),
          17,
        );
      } finally {
        await dev.close();
        await normal.close();
        await temp.delete(recursive: true);
      }
    },
  );
  test('development generation is explicit and rejects path traversal', () {
    expect(() => developmentGeneration({}), throwsStateError);
    expect(
      () => developmentGeneration({'NOTARIS_DEV_GENERATION': '../daily'}),
      throwsStateError,
    );
    expect(
      developmentGeneration({'NOTARIS_DEV_GENERATION': 'a' * 32}),
      'a' * 32,
    );
  });
  test(
    'development auth cannot restore or delete normal cached session',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'notaris.auth.session.v1': 'daily-private-cache',
      });
      final dev = AuthService(cacheKey: 'notaris.auth.notarisdev.test');
      expect(await dev.restoreSession(), isNull);
      await dev.clearPersistedSession();
      expect(
        await const FlutterSecureStorage().read(key: 'notaris.auth.session.v1'),
        'daily-private-cache',
      );
    },
  );
  test('normal auth cache key stays backward compatible', () async {
    FlutterSecureStorage.setMockInitialValues({
      'notaris.auth.session.v1': 'daily',
      'notaris.auth.notarisdev.test': 'dev',
    });
    await AuthService().clearPersistedSession();
    expect(
      await const FlutterSecureStorage().read(key: 'notaris.auth.session.v1'),
      isNull,
    );
    expect(
      await const FlutterSecureStorage().read(
        key: 'notaris.auth.notarisdev.test',
      ),
      'dev',
    );
  });
}
