import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/models/petugas_sync_contract.dart';
import 'package:frontend_notaris/repositories/people_repository.dart';
import 'package:frontend_notaris/repositories/petugas_identity_map_repository.dart';

void main() {
  late AppDatabase database;
  late PetugasRepository petugas;
  late PetugasIdentityMapRepository mappings;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    petugas = PetugasRepository(database);
    mappings = PetugasIdentityMapRepository(database);
  });

  tearDown(() => database.close());

  Future<String> createPetugas(String suffix) async {
    final id = await petugas.create(
      nama: 'Petugas $suffix',
      email: '$suffix@example.com',
    );
    return (await (database.select(
      database.petugasLocals,
    )..where((row) => row.id.equals(id))).getSingle()).uuid;
  }

  test('records a local-only identity without a cloud identity', () async {
    final localUuid = await createPetugas('local');

    final mapping = await mappings.registerLocalOnly(localUuid: localUuid);

    expect(mapping.localUuid, localUuid);
    expect(mapping.cloudUuid, isNull);
    expect(mapping.serverId, isNull);
    expect(mapping.state, PetugasIdentityState.localOnly.databaseValue);
  });

  test('records a verified local-to-cloud mapping', () async {
    final localUuid = await createPetugas('verified');

    final mapping = await mappings.linkVerified(
      localUuid: localUuid,
      cloudUuid: 'cloud-petugas-1',
      serverId: 91,
      evidence: 'operator verified legacy record',
    );

    expect(mapping.cloudUuid, 'cloud-petugas-1');
    expect(mapping.serverId, 91);
    expect(mapping.state, PetugasIdentityState.verified.databaseValue);
  });

  test(
    'records an ambiguous identity without assuming a cloud match',
    () async {
      final localUuid = await createPetugas('ambiguous');

      final mapping = await mappings.markAmbiguous(
        localUuid: localUuid,
        evidence: 'two server candidates require operator review',
      );

      expect(mapping.cloudUuid, isNull);
      expect(mapping.serverId, isNull);
      expect(mapping.state, PetugasIdentityState.ambiguous.databaseValue);
    },
  );

  test('records a server-only identity after local materialization', () async {
    final localUuid = await createPetugas('server-only');

    final mapping = await mappings.linkServerOnly(
      localUuid: localUuid,
      cloudUuid: 'cloud-petugas-2',
      serverId: 92,
      evidence: 'created by pull from server',
    );

    expect(mapping.state, PetugasIdentityState.serverOnly.databaseValue);
    expect(mapping.cloudUuid, 'cloud-petugas-2');
  });

  test('rejects a duplicate active cloud mapping', () async {
    final firstLocalUuid = await createPetugas('first');
    final secondLocalUuid = await createPetugas('second');
    await mappings.linkVerified(
      localUuid: firstLocalUuid,
      cloudUuid: 'cloud-petugas-shared',
      serverId: 93,
      evidence: 'verified first record',
    );

    await expectLater(
      mappings.linkVerified(
        localUuid: secondLocalUuid,
        cloudUuid: 'cloud-petugas-shared',
        serverId: 93,
        evidence: 'must be rejected',
      ),
      throwsStateError,
    );
  });

  test('rejects a duplicate active server ID mapping', () async {
    final firstLocalUuid = await createPetugas('server-id-first');
    final secondLocalUuid = await createPetugas('server-id-second');
    await mappings.linkVerified(
      localUuid: firstLocalUuid,
      cloudUuid: 'cloud-petugas-server-id-first',
      serverId: 94,
      evidence: 'verified first server identifier',
    );

    await expectLater(
      mappings.linkServerOnly(
        localUuid: secondLocalUuid,
        cloudUuid: 'cloud-petugas-server-id-second',
        serverId: 94,
        evidence: 'must be rejected',
      ),
      throwsStateError,
    );
  });
}
