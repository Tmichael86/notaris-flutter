import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/materai_demo_main.dart';
import 'package:frontend_notaris/repositories/materai_repository.dart';
import 'package:path/path.dart' as p;

import '../support/materai_fixture.dart';
import '../support/penghasilan_fixture.dart';

void main() {
  final id = Platform.environment['NOTARIS_MATERAI_PREPARE'];
  test('prepare one disposable and verify exact bytes after reading the Materai report', () async {
    final root = materaiDemoRoot(id!);
    final file = await File(p.join(root.path, 'offline.sqlite'))
        .create(exclusive: true);
    NativeDatabase connect() => NativeDatabase(
      file,
      setup: (raw) => raw.execute('PRAGMA foreign_keys=ON'),
    );
    final existing = AppDatabase.forTesting(connect());
    try {
      await seedPenghasilan(existing);
    } finally {
      await existing.close();
    }
    final writer = MateraiProfileDatabase(connect());
    try {
      await seedMaterai(writer);
    } finally {
      await writer.close();
    }
    Future<Digest> hash() async => sha256.convert(await file.readAsBytes());
    final before = await hash();
    final db = await openMateraiDemo(id);
    try {
      final repo = MateraiRepository(db, materaiReader);
      final report = await repo.read();
      expect(report.verified, hasLength(12));
      expect(report.review, hasLength(1));
      expect(
        report.filtered((
          from: '2026-11-10',
          through: '2026-11-10',
          officer: null,
          search: '',
        )).verified,
        hasLength(10),
      );
      expect(
        report.filtered((
          from: null,
          through: null,
          officer: 'synthetic:acceptance:2',
          search: '',
        )).verified,
        hasLength(6),
      );
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      expect(
        (await db.customSelect('PRAGMA integrity_check').getSingle())
            .data
            .values
            .single,
        'ok',
      );
      expect(
        (await db.customSelect('PRAGMA query_only').getSingle())
            .data
            .values
            .single,
        1,
      );
    } finally {
      await db.close();
    }
    expect(await hash(), before);
  }, skip: id == null);
}
