import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/providers/database_provider.dart';
import 'package:frontend_notaris/providers/transaksi_proses_provider.dart';
import 'package:frontend_notaris/repositories/transaksi_proses_repository.dart';

void main() {
  late AppDatabase database;
  late ProviderContainer container;
  late int transactionId;
  late int processId;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );

    transactionId = await database
        .into(database.transaksis)
        .insert(
          TransaksisCompanion.insert(
            uuid: 'provider-transaction-uuid',
            noAkta: '2000000000001',
            total: 250000,
          ),
        );

    await database
        .into(database.transaksiDetails)
        .insert(
          TransaksiDetailsCompanion.insert(
            uuid: 'provider-detail-uuid',
            transaksiId: transactionId,
            jenisPekerjaan: 'notaris',
            namaPekerjaanSnapshot: 'Akta Provider Test',
          ),
        );

    processId = await database
        .into(database.transaksiProses)
        .insert(
          TransaksiProsesCompanion.insert(
            uuid: 'provider-process-uuid',
            transaksiId: transactionId,
            transaksiDetailUuid: 'provider-detail-uuid',
            namaProsesSnapshot: 'Pemeriksaan dokumen',
            statusProses: const Value(null),
          ),
        );
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  test('providers expose process state and updated audit history', () async {
    await container
        .read(transaksiProsesControllerProvider.notifier)
        .initializeLegacyProcess(
          transactionId: transactionId,
          processId: processId,
          actorUserId: 10,
          note: 'Mulai memakai alur validasi',
        );

    var processes = await container.read(
      transaksiProsesByTransactionProvider(transactionId).future,
    );
    expect(processes, hasLength(1));
    expect(
      processes.single.statusProses,
      ProcessValidationStatus.belumDikerjakan,
    );

    await container
        .read(transaksiProsesControllerProvider.notifier)
        .transition(
          transactionId: transactionId,
          processId: processId,
          nextStatus: ProcessValidationStatus.dalamPengerjaan,
          actorUserId: 10,
        );
    await container
        .read(transaksiProsesControllerProvider.notifier)
        .transition(
          transactionId: transactionId,
          processId: processId,
          nextStatus: ProcessValidationStatus.menungguValidasi,
          actorUserId: 10,
          note: 'Dokumen siap diperiksa',
        );

    processes = await container.read(
      transaksiProsesByTransactionProvider(transactionId).future,
    );
    expect(
      processes.single.statusProses,
      ProcessValidationStatus.menungguValidasi,
    );

    final history = await container.read(
      transaksiProsesHistoryProvider(processId).future,
    );
    expect(history, hasLength(3));
    expect(history.last.statusBaru, ProcessValidationStatus.menungguValidasi);
    expect(history.last.actorUserId, 10);
  });

  test('process provider excludes a soft-deleted transaction detail', () async {
    await container
        .read(transaksiProsesControllerProvider.notifier)
        .initializeLegacyProcess(
          transactionId: transactionId,
          processId: processId,
          actorUserId: 10,
        );

    final provider = transaksiProsesByTransactionProvider(transactionId);
    final beforeDelete = await container.read(provider.future);
    expect(beforeDelete, hasLength(1));

    final removed = Completer<void>();
    final subscription = container.listen(provider, (previous, next) {
      if ((next.asData?.value.isEmpty ?? false) && !removed.isCompleted) {
        removed.complete();
      }
    });

    try {
      await (database.update(
        database.transaksiDetails,
      )..where((detail) => detail.uuid.equals('provider-detail-uuid'))).write(
        TransaksiDetailsCompanion(
          status: const Value(0),
          deletedAt: Value(DateTime.now()),
        ),
      );

      await removed.future.timeout(const Duration(seconds: 2));

      final afterDelete = container.read(provider).requireValue;
      expect(afterDelete, isEmpty);
    } finally {
      subscription.close();
    }
  });
}
