import '../support/transaction_test_authority.dart';
import '../support/local_master_test_authority.dart';

import 'dart:convert';
import 'dart:ffi' show DynamicLibrary;
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/core/widgets/app_shell.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/models/auth_session.dart';
import 'package:frontend_notaris/presentation_demo_main.dart';
import 'package:frontend_notaris/providers/auth_provider.dart';
import 'package:frontend_notaris/providers/database_provider.dart';
import 'package:frontend_notaris/providers/development_smoke_provider.dart';
import 'package:frontend_notaris/repositories/pekerjaan_repository.dart';
import 'package:frontend_notaris/repositories/pengeluaran_repository.dart';
import 'package:frontend_notaris/repositories/transaction_document_repository.dart';
import 'package:frontend_notaris/repositories/transaction_handover_repository.dart';
import 'package:frontend_notaris/repositories/transaction_repository.dart';
import 'package:frontend_notaris/services/transaction_document_preview.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../services/transaction_document_preview_test.dart'
    show sampleJpeg, samplePdf;
import '../support/transaction_ui_test_support.dart';

Future<AuthSession> verifiedDemoSession(String id) async {
  final root = presentationDemoRoot(id);
  final verification = await Process.run(p.join(root.path, 'session.exe'), [
    'verify',
    id,
  ]);
  expect(verification.exitCode, 0);
  final verified =
      (jsonDecode(verification.stdout as String) as List).single
          as Map<String, dynamic>;
  return AuthSession.fromJson({
    ...verified,
    'userId': verified['id'],
    'groupType': verified['role'],
    'token': 'offline-presentation-fixture',
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final id = Platform.environment['NOTARIS_PRESENTATION_PREPARE'];
  test(
    'seed and verify presentation data through local repositories',
    () async {
      final root = presentationDemoRoot(id!);
      final session = await verifiedDemoSession(id);
      expect(session.canCorrectTransactionPayment, isTrue);
      final file = await File(p.join(root.path, 'offline.sqlite'))
          .create(exclusive: true);
      final db = DocumentProfileDatabase(
        NativeDatabase(
          file,
          setup: (sqlite) => sqlite.execute('PRAGMA foreign_keys = ON'),
        ),
        lifecycle: true,
      );
      const uuid = Uuid();
      final repo = testTransactionRepository(db);
      final windowsBuild = p.absolute(
        'build',
        'windows',
        'x64',
        'runner',
        'Debug',
      );
      final documents = TransactionDocumentRepository(
        db: db,
        session: () => session,
        verifiedDatabasePath: file.path,
        verifiedAppDirectory: root.path,
        storageLibrary: DynamicLibrary.open(
          p.join(windowsBuild, 'notaris_document_store.dll'),
        ),
        preview: TransactionDocumentPreview(
          pdfWorker: p.join(windowsBuild, 'notaris_document_pdf.exe'),
        ),
      );
      try {
        final officerUuid = uuid.v4();
        final gender = await db
            .into(db.jenisKelamins)
            .insert(
              JenisKelaminsCompanion.insert(uuid: uuid.v4(), nama: 'Laki-laki'),
            );
        final officer = await db
            .into(db.petugasLocals)
            .insert(
              PetugasLocalsCompanion.insert(
                uuid: officerUuid,
                nama: 'Dimas Prasetyo',
                email: 'dimas@demo.example.invalid',
              ),
            );
        final samples = await Directory(p.join(root.path, 'sampel')).create();
        await File(p.join(samples.path, 'Salinan Fidusia.pdf'))
            .writeAsBytes(await samplePdf(595, 842));
        await File(p.join(samples.path, 'Foto Berkas AJB.jpg'))
            .writeAsBytes(sampleJpeg());
        for (final (index, domain) in ['notaris', 'ppat'].indexed) {
          final notaris = domain == 'notaris';
          final applicantUuid = uuid.v4();
          final applicant = await db
              .into(db.pemohons)
              .insert(
                PemohonsCompanion.insert(
                  uuid: applicantUuid,
                  nama: notaris ? 'Bagas Pradipta' : 'Laras Mahendra',
                ),
              );
          await db.customStatement(
            'UPDATE pemohons SET jenis_kelamin=? WHERE id=?',
            [gender, applicant],
          );
          final categoryName = notaris ? 'Kenotariatan' : 'Pertanahan';
          final category = await db
              .into(db.pekerjaanKategoris)
              .insert(
                PekerjaanKategorisCompanion.insert(
                  uuid: uuid.v4(),
                  nama: categoryName,
                ),
              );
          final jobName = notaris ? 'Pembuatan Akta Fidusia' : 'Akta Jual Beli';
          const cost = 2500000;
          final master = PekerjaanAggregateInput(
            nama: jobName,
            harga: [
              PekerjaanHargaInput(
                harga: '$cost',
                kategoriPekerjaanId: category,
                estimasiWaktu: '3 hari',
              ),
            ],
            proses: const [
              PekerjaanProsesInput(
                nama: 'Verifikasi dokumen',
                detail: 'Periksa berkas pemohon',
              ),
            ],
          );
          final jobId = notaris
              ? await PekerjaanNotarisRepository(
                  db.pekerjaanDao,
                  authorization: masterTestAuthority(db),
                ).createAggregate(input: master)
              : await PekerjaanPpatRepository(
                  db.pekerjaanDao,
                  authorization: masterTestAuthority(db),
                ).createAggregate(input: master);
          final txId = await repo.save(
            nomorTransaksi: '${index + 1}001611260001',
            jenisTransaksi: domain,
            pemohonId: applicant,
            pemohonUuid: applicantUuid,
            petugasId: officer,
            petugasUuid: officerUuid,
            status: 'Dalam Proses',
            tanggalTransaksi: DateTime(2026, 11, 16),
            tanggalJatuhTempo: DateTime(2026, 11, 19),
            pembayaranSekarang: 500000,
            jobs: [
              TransactionJobInput(
                detailUuid: uuid.v4(),
                jenisPekerjaan: domain,
                pekerjaanNotarisId: notaris ? jobId : null,
                pekerjaanPpatId: notaris ? null : jobId,
                namaPekerjaan: jobName,
                kategoriSnapshot: categoryName,
                biayaLayanan: cost.toDouble(),
                estimasiWaktuSnapshot: '3 hari',
                prosesSnapshot: '[{"id":"1","name":"Verifikasi dokumen","attributes":["Berkas identitas"]}]',
              ),
            ],
          );
          final tx = await (db.select(
            db.transaksis,
          )..where((row) => row.id.equals(txId))).getSingle();
          final invoice = await repo.readInvoice(
            transactionId: txId,
            session: session,
          );
          expect(invoice.paid, 500000);
          expect(invoice.responsibleStaffName, 'Dimas Prasetyo');
          await TransactionHandoverRepository(db).save(
            transactionId: txId,
            session: session,
            uuid: uuid.v4(),
            description: 'Salinan berkas demonstrasi',
            purpose: 'Contoh administrasi magang',
          );
          final owner = (id: txId, uuid: tx.uuid, domain: domain);
          final document = await documents.importFile(
            owner: owner,
            operationUuid: uuid.v4(),
            sourcePath: p.join(
              samples.path,
              notaris ? 'Salinan Fidusia.pdf' : 'Foto Berkas AJB.jpg',
            ),
          );
          expect(
            (await documents.readActive(owner, document.uuid)).bytes,
            isNotEmpty,
          );
        }
        final jenis = await db
            .into(db.pengeluaranJenis)
            .insert(
              PengeluaranJenisCompanion.insert(uuid: uuid.v4(), nama: 'ATK'),
            );
        await PengeluaranRepository(db, () => session).create((
          noFaktur: 'ATK-DEMO-01',
          tanggal: DateTime(2026, 11, 16),
          nominal: 85000,
          jenisId: jenis,
          keterangan: 'Map dan kertas kantor',
        ));
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        expect(
          (await db.customSelect('PRAGMA integrity_check').getSingle())
              .read<String>('integrity_check'),
          'ok',
        );
      } finally {
        await db.close();
      }
    },
    skip: id == null,
  );
  testWidgets('verified presentation account opens every AppShell route', (
    tester,
  ) async {
    final session = (await tester.runAsync(() async {
      final loader = FontLoader('PresentationTestSans')
        ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
      await loader.load();
      return verifiedDemoSession(id!);
    }))!;
    tester.view.physicalSize = const Size(1920, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = DocumentProfileDatabase(
      NativeDatabase.memory(),
      lifecycle: true,
    );
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          developmentUiSmokeProvider.overrideWithValue(true),
          authControllerProvider.overrideWith(
            (_) => TransactionUiAuth(session),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(fontFamily: 'PresentationTestSans'),
          home: AppShell(session: session),
        ),
      ),
    );
    await cycleUi(tester);
    var opened = 0;
    for (final (section, menus) in [
      (
        null,
        [
          'Dashboard',
          'Transaksi',
          'Monitoring',
          'Pengeluaran',
          'Piutang',
          'Penghasilan',
        ],
      ),
      (
        'Master',
        [
          'Pekerjaan Notaris',
          'Pekerjaan PPAT',
          'Kategori Pekerjaan',
          'Jenis Pengeluaran',
          'Petugas',
          'Pemohon',
        ],
      ),
      ('Laporan', ['Materai', 'Pendapatan']),
      (
        'System',
        [
          'Users',
          'Groups',
          'Sidebars',
          'Konfigurasi Umum',
          'Log Sinkronisasi',
          'Monitoring Sinkronisasi',
          'Recycle Bin',
        ],
      ),
    ]) {
      if (section != null) {
        final label = find.text(section).first;
        await tester.ensureVisible(label);
        await tester.tap(label);
        await tester.pumpAndSettle();
      }
      for (final name in menus) {
        final label = find.text(name).first;
        await tester.ensureVisible(label);
        await tester.tap(label);
        await cycleUi(tester);
        expect(find.byKey(ValueKey(name)), findsOneWidget, reason: name);
        expect(tester.takeException(), isNull, reason: name);
        opened++;
      }
    }
    expect(opened, session.sidebars.length);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }, skip: id == null);
}
