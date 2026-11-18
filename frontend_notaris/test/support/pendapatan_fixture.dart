import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/models/auth_session.dart';
import 'package:frontend_notaris/models/verified_demo_session.dart';
import 'package:frontend_notaris/repositories/pendapatan_repository.dart';
import 'package:frontend_notaris/repositories/pengeluaran_repository.dart';
import 'package:frontend_notaris/repositories/transaction_repository.dart';

import '../repositories/recycle_bin_repository_test.dart' show seedMaster;

final pendapatanNovember = (
  from: DateTime.utc(2026, 11),
  through: DateTime.utc(2026, 11, 30),
);

AuthSession pendapatanActor({String? without, DateTime? expiry}) {
  final now = DateTime.now();
  return ExpiringPaymentDemoSession(
    AuthSession(
      token: 'local-test-only',
      userId: 104,
      groupId: 104,
      userName: 'Operator Uji',
      groupName: 'Demo',
      groupType: 'superadmin',
      user: const {},
      verifiedAt: now.subtract(const Duration(seconds: 1)),
      sidebars: [
        for (final (code, name) in [
          (pendapatanPermission, 'Pendapatan'),
          ('penghasilan', 'Penghasilan'),
          ('pengeluaran', 'Pengeluaran'),
          ('transaksi', 'Transaksi'),
        ])
          if (code != without)
            {
              'sidebar': {
                'sidebar_kode': code,
                'sidebar_nama': name,
                'status': 1,
              },
              'read': 1,
              'create': 1,
              'update': 1,
              'delete': 1,
            },
      ],
    ),
    expiry ?? now.add(const Duration(hours: 2)),
  );
}

PengeluaranInput pendapatanExpense(int day, int amount) => (
  noFaktur: null,
  tanggal: DateTime.utc(2026, 11, day),
  nominal: amount,
  jenisId: 1,
  keterangan: 'Perlengkapan kantor',
);

Future<void> seedPendapatan(AppDatabase db) async {
  final notaris = await seedMaster(db, 'notaris');
  final ppat = await seedMaster(db, 'ppat');
  await db.customStatement(
    "INSERT INTO pemohons(id,uuid,nama) VALUES(1,'pendapatan-pemohon','Ratna Wulandari')",
  );
  await db.customStatement(
    "INSERT INTO petugas(id,uuid,nama,email) VALUES(1,'pendapatan-petugas','Arif Prasetyo','arif@example.invalid')",
  );
  await db.customStatement(
    "INSERT INTO pengeluaran_jenis(id,uuid,nama) VALUES(1,'pendapatan-jenis','Perlengkapan Kantor')",
  );
  final transactions = TransactionRepository(db);
  final actor = pendapatanActor();
  Future<int> create(
    int index,
    DateTime date,
    int amount, {
    bool isPpat = false,
  }) {
    final domain = isPpat ? 'ppat' : 'notaris';
    return transactions.save(
      nomorTransaksi: 'PD-0$index',
      jenisTransaksi: domain,
      pemohonId: 1,
      pemohonUuid: 'pendapatan-pemohon',
      petugasId: 1,
      petugasUuid: 'pendapatan-petugas',
      status: 'Dalam Proses',
      tanggalTransaksi: date,
      pembayaranSekarang: amount.toDouble(),
      jobs: [
        for (var i = 0; i < (isPpat ? 2 : 1); i++)
          TransactionJobInput(
            jenisPekerjaan: domain,
            namaPekerjaan: isPpat ? 'Layanan Akta $i' : 'Akta Fidusia',
            pekerjaanPpatId: isPpat ? ppat : null,
            pekerjaanNotarisId: isPpat ? null : notaris,
            detailUuid: 'pendapatan-detail-$index-$i',
            biayaLayanan: isPpat ? 50000 : 100000,
          ),
      ],
    );
  }

  final first = await create(1, DateTime.utc(2026, 11, 1, 16, 59, 59), 20000);
  await create(2, DateTime.utc(2026, 11, 13), 30000, isPpat: true);
  final anomaly = await create(3, DateTime.utc(2026, 11, 4), 9000);
  const ids = [
    'f0000000-0000-4000-8000-000000000001',
    'f0000000-0000-4000-8000-000000000002',
    'f0000000-0000-4000-8000-000000000003',
    'f0000000-0000-4000-8000-000000000004',
  ];
  for (var i = 0; i < ids.length; i++) {
    await transactions.addPayment(
      session: actor,
      transactionId: first,
      paymentUuid: ids[i],
      paymentDate: DateTime.utc(2026, 11, 1, 17),
      amount: [10000, 10000, 7000, 4000][i],
    );
  }
  final payments = await transactions.getPaymentHistory(first);
  await transactions.editPayment(
    session: actor,
    transactionId: first,
    expected: payments.singleWhere((row) => row.uuid == ids[2]),
    paymentDate: DateTime.utc(2026, 11, 3),
    amount: 8000,
    method: 'Cash',
    reason: 'Koreksi tanggal dan nominal fixture',
  );
  await transactions.cancelPayment(
    session: actor,
    transactionId: first,
    expected: payments.singleWhere((row) => row.uuid == ids[3]),
    reason: 'Pembayaran fixture dibatalkan',
  );
  await db.customStatement(
    'UPDATE transaksi_riwayat_pembayaran SET nominal=2.5, nominal_rupiah=NULL WHERE transaksi_id=?',
    [anomaly],
  );
  final expenses = PengeluaranRepository(db, () => actor);
  for (var day = 1; day <= 13; day++) {
    await expenses.create(pendapatanExpense(day, day * 1000));
  }
  await expenses.create(pendapatanExpense(13, 2000));
  final deleted = await expenses.create(pendapatanExpense(5, 9000));
  await expenses.delete(deleted);
}
