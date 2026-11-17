import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/materai_stock_demo_main.dart';
import 'package:frontend_notaris/repositories/materai_stock_repository.dart';
import 'package:path/path.dart' as p;

import '../support/materai_stock_fixture.dart';
import '../support/penghasilan_fixture.dart';

void main() {
  final id = Platform.environment['NOTARIS_MATERAI_STOCK_PREPARE'];
  test(
    'one fresh profile persists opening and receipt, then reopens read-only',
    () async {
      final profile = id!;
      final root = materaiStockDemoRoot(profile);
      final file = await File(p.join(root.path, 'offline.sqlite'))
          .create(exclusive: true);
      final writer = MateraiProfileDatabase(NativeDatabase(file));
      try {
        await seedPenghasilan(writer);
        final binding = await seedMateraiOpening(writer, id: profile);
        final actor = stockActor(profile);
        final repo = MateraiStockRepository(
          binding,
          () => actor,
          now: () => openingTime.add(const Duration(minutes: 1)),
        );
        final head = await repo.context();
        final fixture = await repo.receive(
          operation: '00000000-0000-4000-8000-111111111111',
          expectedPredecessor: head.predecessor,
          businessDate: '2026-11-10',
          sheets: 5,
          description: 'Penerimaan awal fixture',
        );
        expect(fixture.stock, 25);
      } finally {
        await writer.close();
      }
      final before = sha256.convert(await file.readAsBytes());
      final readOnly = openMateraiStockDemo(profile, writable: false);
      try {
        expect(
          (await readOnly.customSelect('PRAGMA integrity_check').getSingle())
              .data
              .values
              .single,
          'ok',
        );
        expect(
          await readOnly.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        expect(
          (await readOnly.customSelect('PRAGMA query_only').getSingle())
              .data
              .values
              .single,
          1,
        );
        expect(
          await readOnly.customSelect('SELECT id FROM materai_movements').get(),
          hasLength(2),
        );
      } finally {
        await readOnly.close();
      }
      expect(sha256.convert(await file.readAsBytes()), before);
    },
    skip: id == null,
  );
}
