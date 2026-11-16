import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/models/auth_session.dart';
import 'package:frontend_notaris/repositories/penghasilan_repository.dart';
import 'package:frontend_notaris/repositories/transaction_repository.dart';

import '../repositories/recycle_bin_repository_test.dart' show seedMaster;
import 'transaction_ui_test_support.dart' show uiSession;

PenghasilanFilter receiptFilter({
  DateTime? from,
  DateTime? through,
  String domain = '',
  String job = '',
  String category = '',
  String status = '',
  int? officer,
  String search = '',
}) => (
  from: from,
  through: through,
  domain: domain,
  job: job,
  category: category,
  status: status,
  officer: officer,
  search: search,
);

AuthSession penghasilanReader({bool allowed = true, int status = 1}) =>
    uiSession(permission: false)
      ..sidebars.add({
        'sidebar': {
          'sidebar_kode': 'penghasilan',
          'sidebar_nama': 'Penghasilan',
          'status': status,
        },
        'read': allowed ? 1 : 0,
      });

Future<void> seedPenghasilan(AppDatabase db) async {
  final masters = {
    'notaris': await seedMaster(db, 'notaris'),
    'ppat': await seedMaster(db, 'ppat'),
  };
  await db.customStatement(
    'INSERT INTO pemohons(id,uuid,nama,nik) VALUES(1,?,?,?)',
    ['applicant', 'Laras Pradépta', '0000000000000001'],
  );
  await db.customStatement(
    "INSERT INTO petugas(id,uuid,nama,email) VALUES(1,'officer','Dimas Prasetyo','dimas@demo.example.invalid'),(2,'officer-2','Nadia Pertiwi','nadia@demo.example.invalid')",
  );
  final repo = TransactionRepository(db);
  final actor = uiSession(groupType: 'superadmin');
  final sharedDate = DateTime(2026, 11, 10, 23, 59, 59);
  for (var i = 1; i <= 16; i++) {
    final domain = i.isOdd ? 'notaris' : 'ppat';
    TransactionJobInput job(int index, String name, String category) =>
        TransactionJobInput(
          detailUuid: 'receipt-job-$i-$index',
          jenisPekerjaan: domain,
          namaPekerjaan: name,
          pekerjaanNotarisId: domain == 'notaris' ? masters[domain] : null,
          pekerjaanPpatId: domain == 'ppat' ? masters[domain] : null,
          biayaLayanan: 150000,
          kategoriSnapshot: category,
        );
    final id = await repo.save(
      nomorTransaksi: 'PEN-${i.toString().padLeft(2, '0')}',
      jenisTransaksi: domain,
      pemohonId: 1,
      pemohonUuid: 'applicant',
      petugasId: i == 2 ? 2 : 1,
      petugasUuid: i == 2 ? 'officer-2' : 'officer',
      status: i == 13 ? 'Selesai' : 'Dalam Proses',
      deed: i == 13
          ? NotarisDeedInput('Akta Kuasa', '25', DateTime(2026, 11, 9))
          : null,
      tanggalTransaksi: i == 2 ? sharedDate : DateTime(2026, 11, 9),
      pembayaranSekarang: switch (i) {
        1 => 100000,
        2 => 60000,
        13 || 14 => 0,
        _ => 25000,
      },
      jobs: i == 1
          ? [
              job(1, 'Akta Fidusia', 'Kenotariatan'),
              job(2, 'Salinan Berkas', 'Administrasi'),
            ]
          : [
              job(
                1,
                i.isOdd ? 'Akta Kuasa' : 'Akta Jual Beli',
                i.isOdd ? 'Kenotariatan' : 'Pertanahan',
              ),
            ],
    );
    if (id != i) throw StateError('PK fixture berubah.');
  }
  await repo.addPayment(
    session: actor,
    transactionId: 1,
    paymentUuid: '00000000-0000-4000-8000-111111111111',
    paymentDate: sharedDate,
    amount: 50000,
  );
  await repo.addPayment(
    session: actor,
    transactionId: 1,
    paymentUuid: '00000000-0000-4000-8000-222222222222',
    paymentDate: sharedDate,
    amount: 30000,
  );
  final payments = await repo.getPaymentHistory(1);
  await repo.editPayment(
    session: actor,
    transactionId: 1,
    expected: payments.first,
    paymentDate: DateTime(2026, 11, 11),
    amount: 120000,
    method: 'Cash',
    reason: 'Koreksi fixture',
  );
  await repo.cancelPayment(
    session: actor,
    transactionId: 1,
    expected: payments.last,
    reason: 'Batal fixture',
  );
  await repo.delete(15);
  await db.customStatement(
    'UPDATE transaksi_riwayat_pembayaran SET nominal=2.5, nominal_rupiah=NULL WHERE transaksi_id=16',
  );
  await db.customStatement(
    "INSERT INTO transaction_cloud_feed(scope,cursor) VALUES('penghasilan-demo',3)",
  );
  await db.customStatement(
    "INSERT INTO transaction_cloud_identity(local_uuid,cloud_uuid,scope,revision,final_number,snapshot) SELECT uuid,uuid,'penghasilan-demo',1,no_akta,'{}' FROM transaksis WHERE id=2",
  );
  await db.customStatement(
    "INSERT INTO transaction_cloud_pending(local_uuid,mutation_id,payload,state) SELECT uuid,'penghasilan-demo-ack','{}','acked' FROM transaksis WHERE id=2",
  );
}
