import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/models/transaction_invoice.dart';
import 'package:frontend_notaris/models/transaction_payments.dart';
import 'package:frontend_notaris/notaris_completion_demo_main.dart';
import 'package:frontend_notaris/repositories/transaction_repository.dart';
import 'package:frontend_notaris/services/transaction_invoice_pdf.dart';

import '../support/transaction_ui_test_support.dart' show uiSession;
import 'recycle_bin_repository_test.dart' show recoverySession, seedTransaction;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late TransactionRepository repo;
  late int notaris;
  late int ppat;
  final reader = recoverySession(update: false, only: 'transaksi');
  final admin = uiSession(groupType: 'superadmin');
  final date = DateTime(2026, 11, 11);
  const installmentUuid = '44000000-0000-4000-8000-000000000001';

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TransactionRepository(db);
    final notarisTemplate = await seedTransaction(db, 'notaris');
    final ppatTemplate = await seedTransaction(db, 'ppat');
    final notarisJob = (await repo.watchDetailsOnce(notarisTemplate)).single;
    final ppatJob = (await repo.watchDetailsOnce(ppatTemplate)).single;
    await db.customStatement(
      "UPDATE pemohons SET nama='Bagas Pradipta',alamat='Talun, Blitar' WHERE id=1",
    );
    await db.customStatement(
      "INSERT INTO pemohons(id,uuid,nama) VALUES(2,'ppat-applicant','Laras Mahendra')",
    );
    await db.customStatement(
      "UPDATE petugas SET nama='Dimas Prasetyo', no_telp='081234567890' WHERE id=1",
    );
    await db.customStatement(
      "INSERT INTO petugas(id,uuid,nama,email,user_id) VALUES"
      "(2,'officer-ppat','Sinta Permata','sinta@example.invalid',NULL),"
      "(3,'print-user','Operator Pencetak','print@example.invalid',1)",
    );
    notaris = await repo.save(
      nomorTransaksi: '1001111260001',
      jenisTransaksi: 'notaris',
      pemohonId: 1,
      pemohonUuid: 'applicant',
      petugasId: 1,
      petugasUuid: 'officer',
      status: 'Dalam Proses',
      tanggalTransaksi: date,
      diskon: 200000,
      pembayaranSekarang: 500000,
      jobs: [
        TransactionJobInput(
          jenisPekerjaan: 'notaris',
          namaPekerjaan: 'Pembuatan Akta Fidusia',
          detailUuid: 'invoice-notaris-1',
          pekerjaanNotarisId: notarisJob.pekerjaanNotarisId,
          biayaLayanan: 1800000,
          biayaLainnya: 200000,
        ),
        TransactionJobInput(
          jenisPekerjaan: 'notaris',
          namaPekerjaan: 'Perubahan Perjanjian',
          detailUuid: 'invoice-notaris-2',
          pekerjaanNotarisId: notarisJob.pekerjaanNotarisId,
          biayaLayanan: 1200000,
        ),
      ],
    );
    ppat = await repo.save(
      nomorTransaksi: '2001111260001',
      jenisTransaksi: 'ppat',
      pemohonId: 2,
      pemohonUuid: 'ppat-applicant',
      petugasId: 2,
      petugasUuid: 'officer-ppat',
      status: 'Dalam Proses',
      tanggalTransaksi: date,
      pembayaranSekarang: 300000,
      jobs: [
        TransactionJobInput(
          jenisPekerjaan: 'ppat',
          namaPekerjaan: 'Akta Jual Beli',
          detailUuid: 'invoice-ppat-1',
          pekerjaanPpatId: ppatJob.pekerjaanPpatId,
          biayaLayanan: 300000,
        ),
      ],
    );
  });
  tearDown(() => db.close());

  Future<TransactionInvoice> read(int id) =>
      repo.readInvoice(transactionId: id, session: reader);

  test(
    'Notaris and PPAT use isolated saved work, applicants and ledger',
    () async {
      final n = await read(notaris);
      expect(
        (n.number, n.domain, n.applicant, n.address),
        ('1001111260001', 'notaris', 'Bagas Pradipta', 'Talun, Blitar'),
      );
      expect(n.responsibleStaffName, 'Dimas Prasetyo');
      expect(n.jobs.map((row) => row.name), [
        'Pembuatan Akta Fidusia',
        'Perubahan Perjanjian',
      ]);
      expect(
        (
          n.jobs.first.serviceFee,
          n.jobs.first.additionalFee,
          n.jobs.first.total,
        ),
        (1800000, 200000, 2000000),
      );
      expect(
        (n.subtotal, n.discount, n.billed, n.paid, n.remaining, n.isPaid),
        (3200000, 200000, 3000000, 500000, 2500000, false),
      );

      await db.customStatement(
        'UPDATE transaksis SET tanggal_transaksi=NULL WHERE id=?',
        [ppat],
      );
      final p = await read(ppat);
      expect(p.responsibleStaffName, 'Sinta Permata');
      expect(
        (p.number, p.domain, p.applicant, p.address, p.transactionDate),
        ('2001111260001', 'ppat', 'Laras Mahendra', null, null),
      );
      expect(p.jobs.single.name, 'Akta Jual Beli');
      expect(
        (p.billed, p.paid, p.remaining, p.isPaid),
        (300000, 300000, 0, true),
      );
      expect(p.payments.single.amount, 300000);
    },
  );

  test('PIC uses the saved local reference and rejects a missing or mismatched assignment', () async {
    Future<TransactionInvoice> assignment(int? id, String? uuid) async {
      await db.customStatement(
        'UPDATE transaksis SET petugas_id=?, petugas_uuid=? WHERE id=?',
        [id, uuid, notaris],
      );
      return read(notaris);
    }

    final original = await read(notaris);
    expect(original.responsibleStaffName, 'Dimas Prasetyo');
    expect((await assignment(1, null)).responsibleStaffName, 'Dimas Prasetyo');
    expect(
      (await assignment(null, 'officer')).responsibleStaffName,
      'Dimas Prasetyo',
    );
    expect((await assignment(1, 'officer-ppat')).responsibleStaffName, isNull);
    expect((await assignment(999, 'officer')).responsibleStaffName, isNull);
    final unassigned = await assignment(null, null);
    expect(unassigned.responsibleStaffName, isNull);
    expect(
      (unassigned.billed, unassigned.paid, unassigned.remaining),
      (original.billed, original.paid, original.remaining),
    );
    expect(
      latin1.decode(
        (await renderTransactionInvoice(unassigned)).take(5).toList(),
      ),
      '%PDF-',
    );
    expect(original.responsibleStaffName, 'Dimas Prasetyo');
  });

  test(
    'active add, correction and cancellation produce independent snapshots',
    () async {
      final before = await read(notaris);
      await repo.addPayment(
        session: admin,
        transactionId: notaris,
        paymentUuid: installmentUuid,
        paymentDate: date,
        amount: 750000,
      );
      expect((await read(notaris)).paid, 1250000);
      Future<TransaksiRiwayatPembayaran> installment() async =>
          (await repo.getPaymentHistory(notaris))
              .singleWhere((payment) => payment.uuid == installmentUuid);
      await repo.editPayment(
        session: admin,
        transactionId: notaris,
        expected: await installment(),
        paymentDate: date,
        amount: 800000,
        method: 'Cash',
        reason: 'Koreksi',
      );
      final corrected = await read(notaris);
      expect((corrected.paid, corrected.remaining), (1300000, 1700000));
      await repo.cancelPayment(
        session: admin,
        transactionId: notaris,
        expected: await installment(),
        reason: 'Dibatalkan',
      );
      final after = await read(notaris);
      expect(
        (after.paid, after.remaining, after.payments.length),
        (500000, 2500000, 1),
      );
      expect(corrected.payments.map((payment) => payment.amount), [
        500000,
        800000,
      ]);
      expect(before.paid, 500000);
      expect((await read(ppat)).paid, 300000);
    },
  );

  test(
    'read is permission-checked and fails closed for inconsistent records',
    () async {
      expect(
        () => repo.readInvoice(
          transactionId: notaris,
          session: uiSession(permission: false),
        ),
        throwsA(isA<TransactionInvoiceUnavailable>()),
      );
      await expectLater(
        read(9999),
        throwsA(isA<TransactionInvoiceUnavailable>()),
      );
      await db.customStatement('UPDATE transaksis SET total=3.25 WHERE id=?', [
        notaris,
      ]);
      await expectLater(
        read(notaris),
        throwsA(isA<TransactionInvoiceUnavailable>()),
      );
      await db.customStatement(
        'UPDATE transaksis SET total=3000001 WHERE id=?',
        [notaris],
      );
      await expectLater(
        read(notaris),
        throwsA(isA<TransactionInvoiceUnavailable>()),
      );
      await db.customStatement(
        "UPDATE transaksis SET pemohon_uuid='wrong-identity' WHERE id=?",
        [ppat],
      );
      await expectLater(
        read(ppat),
        throwsA(isA<TransactionInvoiceUnavailable>()),
      );
      expect(await repo.delete(ppat), isTrue);
      await expectLater(
        read(ppat),
        throwsA(isA<TransactionInvoiceUnavailable>()),
      );
    },
  );

  test('read and PDF generation are offline and do not write SQLite', () async {
    Future<int> changes() async =>
        (await db.customSelect('SELECT total_changes() AS n').getSingle())
            .read<int>('n');
    final before = await changes();
    await HttpOverrides.runWithHttpOverrides(() async {
      final n = await read(notaris);
      final p = await read(ppat);
      final normal = await renderTransactionInvoice(n);
      final ppatPdf = await renderTransactionInvoice(p);
      expect(latin1.decode(normal.take(5).toList()), '%PDF-');
      expect(latin1.decode(ppatPdf.take(5).toList()), '%PDF-');
      final long = await renderTransactionInvoice(
        TransactionInvoice(
          number: n.number,
          domain: n.domain,
          applicant: n.applicant,
          address: n.address,
          responsibleStaffName: n.responsibleStaffName,
          transactionDate: n.transactionDate,
          printDate: n.printDate,
          subtotal: 8500000,
          discount: 0,
          billed: 8500000,
          paid: 500000,
          jobs: [
            for (var i = 1; i <= 85; i++)
              InvoiceJob(
                'Pekerjaan $i - Penelaahan dokumen dan kelengkapan perjanjian',
                100000,
                0,
                100000,
              ),
          ],
          payments: n.payments,
        ),
      );
      expect(
        RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(long)).length,
        greaterThan(1),
      );
      if (Platform.environment['NOTARIS_INVOICE_PDF_SMOKE'] == '1') {
        final out = await Directory.systemTemp.createTemp(
          'notaris-invoice-pdf-',
        );
        await File('${out.path}/notaris.pdf').writeAsBytes(normal);
        await File('${out.path}/ppat.pdf').writeAsBytes(ppatPdf);
        await File('${out.path}/multi-page.pdf').writeAsBytes(long);
        stdout.writeln('Invoice PDF smoke: ${out.path}');
      }
    }, CompletionDemoNoHttp());
    expect(await changes(), before);
    expect(formatPaymentRupiah(2500000), 'Rp 2.500.000');
    expect(formatPaymentDate(date), '11/11/2026');
  });
}
