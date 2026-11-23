import 'transaction_test_authority.dart';

import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/models/auth_session.dart';
import 'package:frontend_notaris/repositories/piutang_repository.dart';
import 'package:frontend_notaris/repositories/transaction_repository.dart';

import '../repositories/recycle_bin_repository_test.dart' show seedMaster;
import 'transaction_ui_test_support.dart' show uiSession;

const allPiutang = (
  domain: '',
  from: null as DateTime?,
  through: null as DateTime?,
  search: '',
);
const piutangNumber = '000000000000001';
const piutangNik = '0000000000000001';

AuthSession piutangReader({bool allowed = true, int status = 1}) =>
    uiSession(permission: false)
      ..sidebars.add({
        'sidebar': {
          'sidebar_kode': 'piutang',
          'sidebar_nama': 'Piutang',
          'status': status,
        },
        'read': allowed ? 1 : 0,
      });

Future<void> seedPiutang(AppDatabase db) async {
  final masters = {
    'notaris': await seedMaster(db, 'notaris'),
    'ppat': await seedMaster(db, 'ppat'),
  };
  await db.customStatement(
    'INSERT INTO pemohons(id,uuid,nama,nik) VALUES(1,?,?,?)',
    ['applicant', 'Laras Pradépta', piutangNik],
  );
  await db.customStatement(
    "INSERT INTO pemohons(id,uuid,nama) VALUES(2,'no-nik','Bagas Pradipta')",
  );
  await db.customStatement(
    "INSERT INTO petugas(id,uuid,nama,email) VALUES(1,'officer','Dimas Prasetyo','dimas@demo.example.invalid')",
  );
  final actor = uiSession(groupType: 'superadmin');
  final repo = testTransactionRepository(db, session: () => actor);
  for (var id = 1; id <= 16; id++) {
    final domain = id.isOdd ? 'notaris' : 'ppat';
    final master = masters[domain]!;
    TransactionJobInput job(
      int index,
      double cost,
      String name,
      String? category,
    ) => TransactionJobInput(
      detailUuid: 'job-$id-$index',
      jenisPekerjaan: domain,
      namaPekerjaan: name,
      pekerjaanNotarisId: domain == 'notaris' ? master : null,
      pekerjaanPpatId: domain == 'ppat' ? master : null,
      biayaLayanan: cost,
      kategoriSnapshot: category,
    );
    final actual = await repo.save(
      nomorTransaksi: id == 1
          ? piutangNumber
          : 'PIU-${id.toString().padLeft(2, '0')}',
      jenisTransaksi: domain,
      pemohonId: id == 2 ? 2 : 1,
      pemohonUuid: id == 2 ? 'no-nik' : 'applicant',
      petugasId: 1,
      petugasUuid: 'officer',
      status: id == 3 ? 'Selesai' : 'Dalam Proses',
      deed: id == 3
          ? NotarisDeedInput('Akta Kuasa', '25', DateTime(2026, 11, 9))
          : null,
      tanggalTransaksi: DateTime(2026, 11, 9),
      tanggalJatuhTempo: id == 13
          ? null
          : DateTime(2026, 11, id <= 6 ? 10 : 11, 23, 59),
      diskon: id == 1 ? 20000 : 0,
      pembayaranSekarang: switch (id) {
        1 => 30000,
        3 || 15 => 0,
        14 => 100000,
        _ => 25000,
      },
      jobs: id == 1
          ? [
              job(1, 120000, '=Akta Fidusia', 'Kenotariatan'),
              job(2, 80000, '+Salinan Akta', null),
            ]
          : [
              job(
                1,
                100000,
                domain == 'notaris' ? 'Akta Kuasa' : 'Akta Jual Beli',
                domain == 'notaris' ? 'Kenotariatan' : 'Pertanahan',
              ),
            ],
    );
    if (actual != id) throw StateError('PK fixture berbeda.');
  }
  await repo.addPayment(
    session: actor,
    transactionId: 1,
    paymentUuid: '00000000-0000-4000-8000-555555555555',
    paymentDate: DateTime(2026, 11, 10),
    amount: 20000,
  );
  await db.customStatement('UPDATE transaksis SET created_at=1');
  await db.customStatement(
    'UPDATE transaksis SET pembayaran_sekarang=5000 WHERE id=15',
  );
  await repo.delete(16);
  await db.customStatement(
    "INSERT INTO transaction_cloud_feed(scope,cursor) VALUES('piutang-demo',3)",
  );
  await db.customStatement(
    "INSERT INTO transaction_cloud_identity(local_uuid,cloud_uuid,scope,revision,final_number,snapshot) SELECT uuid,uuid,'piutang-demo',1,no_akta,'{}' FROM transaksis WHERE id=2",
  );
  await db.customStatement(
    "INSERT INTO transaction_cloud_pending(local_uuid,mutation_id,payload,state) SELECT uuid,'piutang-demo-ack','{}','acked' FROM transaksis WHERE id=2",
  );
}

PiutangFilter piutangFilter({
  String domain = '',
  DateTime? from,
  DateTime? through,
  String search = '',
}) => (domain: domain, from: from, through: through, search: search);
