import '../support/transaction_test_authority.dart';

import 'dart:io';

import 'package:drift/native.dart';
import 'package:excel_plus/excel_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/models/transaction_monitoring.dart';
import 'package:frontend_notaris/repositories/transaction_repository.dart';
import 'package:frontend_notaris/services/monitoring_excel_export.dart';
import 'package:path/path.dart' as p;

import '../support/transaction_ui_test_support.dart';

void main() {
  late AppDatabase db;
  late TransactionRepository repo;
  late Directory folder;
  final authorized = uiSession()
    ..sidebars.add({
      'read': 1,
      'sidebar': {'sidebar_nama': 'Monitoring', 'status': 1},
    });
  final from = DateTime(2026, 11, 8);
  final until = DateTime(2026, 11, 10);
  MonitoringFilter filter({
    String domain = '',
    String search = '',
    bool combined = false,
    int page = 1,
  }) => (
    domain: domain,
    status: combined ? 'Dalam Proses' : '',
    search: search,
    job: combined ? 'Pembuatan Akta' : '',
    category: combined ? 'Kenotariatan' : '',
    officerId: combined ? 1 : 0,
    from: combined ? from : null,
    until: combined ? until : null,
    index: page,
  );

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('monitoring-xlsx-');
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = testTransactionRepository(db);
    await db.customStatement(
      "INSERT INTO pemohons(id,uuid,nama,nik) VALUES(1,'applicant','=HYPERLINK(é)','0000000000000001')",
    );
    await db.customStatement(
      "INSERT INTO petugas(id,uuid,nama,email) VALUES(1,'officer','@Nadia','test@example.invalid')",
    );
    for (var i = 1; i <= 17; i++) {
      final dated = DateTime(2026, 11, i == 16 ? 15 : i, 23, 59);
      await db.customStatement(
        '''INSERT INTO transaksis(id,uuid,no_akta,total,jenis_transaksi,status_transaksi,
          tanggal_transaksi,pemohon_id,pemohon_uuid,petugas_id,petugas_uuid,deleted_at)
          VALUES(?,?,?,?,?,'Dalam Proses',?,?,?,?,?,?)''',
        [
          i,
          'tx-$i',
          i.toString().padLeft(16, '0'),
          125000,
          i.isOdd ? 'ppat' : 'notaris',
          dated.millisecondsSinceEpoch ~/ 1000,
          i == 16 ? null : 1,
          'applicant',
          1,
          'officer',
          i == 17 ? 10 : null,
        ],
      );
    }
    await db.customStatement("""
      INSERT INTO transaksi_details(uuid,transaksi_id,jenis_pekerjaan,nama_pekerjaan_snapshot,
        kategori_snapshot,estimasi_waktu_snapshot) VALUES
        ('d8',8,'notaris','Pembuatan Akta','Kenotariatan','2 hari'),
        ('d10',10,'notaris','Pembuatan Akta','Kenotariatan','2 hari'),
        ('d10b',10,'notaris','+Verifikasi','Administrasi','1 hari')
      """);
    await db.customStatement("""
      INSERT INTO transaksi_proses(uuid,transaksi_id,transaksi_detail_uuid,nama_proses_snapshot)
      VALUES ('p10',10,'d10','Periksa draf'),('p10b',10,'d10b','-Periksa berkas')
      """);
    await db.customStatement("""
      INSERT INTO transaksi_riwayat_pembayaran(uuid,transaksi_id,tanggal_pembayaran,
        nominal,nominal_rupiah,metode_pembayaran,urutan_pembayaran,status) VALUES
        ('pay',10,1,25000,25000,'Cash',1,1),
        ('void',10,1,30000,30000,'Cash',2,0)
      """);
    await db.customStatement(
      "INSERT INTO transaction_cloud_feed(scope,cursor) VALUES('fixture',3)",
    );
    await db.customStatement("""
      INSERT INTO transaction_cloud_pending(local_uuid,mutation_id,payload,state)
      VALUES ('tx-10','mutation-10','{}','acked')
      """);
    await db.customStatement('PRAGMA query_only = ON');
  });
  tearDown(() async {
    await db.close();
    await folder.delete(recursive: true);
  });

  Future<Sheet> export(String name, MonitoringFilter query, int count) async {
    final path = p.join(folder.path, '$name.xlsx');
    final exporter = MonitoringExcelExport(
      chooseDestination: (_) async => path,
    );
    expect(
      await exporter.run(
        repository: repo,
        currentSession: () => authorized,
        filter: query,
        officerLabel: '@Nadia',
      ),
      count,
    );
    final bytes = await File(path).readAsBytes();
    expect(bytes.take(2), [0x50, 0x4b]);
    final excel = Excel.decodeBytes(bytes);
    expect(excel.tables.keys, ['Monitoring Transaksi']);
    final sheet = excel['Monitoring Transaksi'];
    expect(
      sheet.cell(CellIndex.indexByString('B11')).value,
      IntCellValue(count),
    );
    expect(sheet.maxRows, 13 + count);
    expect(
      sheet.rows
          .expand((row) => row)
          .map((cell) => cell?.value)
          .whereType<FormulaCellValue>(),
      isEmpty,
    );
    return sheet;
  }

  test('full XLSX export ignores page and preserves ordering, types and empty references', () async {
    final before = await db
        .customSelect('SELECT total_changes() AS n')
        .getSingle();
    final sheet = await export('semua', filter(), 16);
    CellValue? value(String address) =>
        sheet.cell(CellIndex.indexByString(address)).value;
    expect(value('D14').toString(), '0000000000000016');
    expect(value('D15').toString(), '0000000000000015');
    expect(value('D29').toString(), '0000000000000001');
    expect(value('D14'), isA<TextCellValue>());
    expect(value('E14').toString(), '—');
    expect(value('E15').toString(), '0000000000000001');
    expect(value('E15'), isA<TextCellValue>());
    expect(value('F15').toString(), '=HYPERLINK(é)');
    expect(value('N15').toString(), '@Nadia');
    expect(value('B14'), DateCellValue(year: 2026, month: 11, day: 15));
    expect(value('C14'), isNull);
    expect(value('L14'), anyOf(IntCellValue(125000), DoubleCellValue(125000)));
    expect(
      (await db.customSelect('SELECT total_changes() AS n').getSingle()).data,
      before.data,
    );
    expect(
      (await db.customSelect('PRAGMA integrity_check').getSingle())
          .data
          .values
          .single,
      'ok',
    );
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  }, skip: !Platform.isWindows);

  test('domain, search, and inclusive date filters round trip through the workbook', () async {
    await export('notaris', filter(domain: 'notaris'), 8);
    await export('ppat', filter(domain: 'ppat'), 8);
    await export('empty', filter(search: 'missing'), 0);
    final filtered = await export(
      'combined',
      filter(domain: 'notaris', search: 'é', combined: true),
      2,
    );
    final first = filtered.rows[13];
    expect(
      first[7]?.value.toString(),
      allOf(contains('Pembuatan Akta'), contains('+Verifikasi')),
    );
    expect(first[8]?.value.toString(), contains('Administrasi'));
    expect(first[9]?.value.toString(), contains('2 hari'));
    expect(first[10]?.value.toString(), contains('-Periksa berkas'));
    expect(first[12]?.value, IntCellValue(100000));
    expect(first[1]?.value, DateCellValue(year: 2026, month: 11, day: 10));
    expect(
      filtered.rows[14][1]?.value,
      DateCellValue(year: 2026, month: 11, day: 8),
    );
  }, skip: !Platform.isWindows);

  test('denial, permission revocation and cancellation occur before a query or write', () async {
    var opened = false;
    final exporter = MonitoringExcelExport(
      chooseDestination: (_) async {
        opened = true;
        return null;
      },
    );
    final denied = uiSession();
    await expectLater(
      repo.readMonitoringExport(filter(), denied),
      throwsStateError,
    );
    await expectLater(
      exporter.run(
        repository: repo,
        currentSession: () => denied,
        filter: filter(),
      ),
      throwsStateError,
    );
    expect(opened, isFalse);
    expect(
      await exporter.run(
        repository: repo,
        currentSession: () => authorized,
        filter: filter(),
      ),
      isNull,
    );
    expect(opened, isTrue);
    var current = authorized;
    final switched = MonitoringExcelExport(
      chooseDestination: (_) async {
        current = denied;
        return p.join(folder.path, 'blocked.xlsx');
      },
    );
    await expectLater(
      switched.run(
        repository: repo,
        currentSession: () => current,
        filter: filter(),
      ),
      throwsStateError,
    );
    expect(await folder.list().toList(), isEmpty);
  });

  test(
    'save errors preserve the existing destination and remove staging',
    () async {
      final existing = File(p.join(folder.path, 'exists.xlsx'));
      await existing.writeAsString('keep me');
      for (final path in [
        existing.path,
        p.join(folder.path, 'missing', 'out.xlsx'),
      ]) {
        final exporter = MonitoringExcelExport(
          chooseDestination: (_) async => path,
        );
        await expectLater(
          exporter.run(
            repository: repo,
            currentSession: () => authorized,
            filter: filter(),
          ),
          throwsA(isA<FileSystemException>()),
        );
      }
      expect(await existing.readAsString(), 'keep me');
      expect((await folder.list().toList()).single.path, existing.path);
    },
    skip: !Platform.isWindows,
  );
}
