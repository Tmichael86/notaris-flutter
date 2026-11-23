import 'dart:convert';

import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/models/auth_session.dart';
import 'package:frontend_notaris/models/verified_demo_session.dart';
import 'package:frontend_notaris/repositories/materai_repository.dart';
import 'package:frontend_notaris/repositories/materai_stock_repository.dart';

const demoStockProfile = '0123456789abcdef0123456789abcdef';
const fixtureOfficer = 'Rani Wulandari';
final openingTime = DateTime.utc(2026, 11, 10, 1);

ExpiringPaymentDemoSession stockActor(
  String id, {
  int read = 1,
  int create = 1,
  int userId = 102,
  bool expired = false,
  bool? transactionCreate,
  bool transactionUpdate = true,
}) => ExpiringPaymentDemoSession(
  AuthSession(
    token: 'fixture',
    userId: userId,
    groupId: userId,
    userName: fixtureOfficer,
    groupName: 'Admin fixture',
    groupType: 'superadmin',
    user: const {},
    sidebars: [
      {
        'sidebar': {
          'sidebar_kode': materaiPermissionCode,
          'sidebar_nama': 'Materai',
          'status': 1,
        },
        'read': read,
        'create': create,
      },
      if (transactionCreate != null)
        {
          'sidebar': {'sidebar_kode': 'transaksi', 'status': 1},
          'read': 1,
          'create': transactionCreate ? 1 : 0,
          'update': transactionUpdate ? 1 : 0,
        },
    ],
    verifiedAt: openingTime.subtract(const Duration(days: 1)),
  ),
  expired ? openingTime : DateTime.now().add(const Duration(days: 1)),
  expireSidebarAccess: true,
  profileId: id,
);

ExpiringPaymentDemoSession usageActor(
  String profile, {
  bool grant = true,
  bool expired = false,
  int user = 102,
}) => stockActor(
  profile,
  create: 0,
  expired: expired,
  userId: user,
  transactionCreate: grant,
);

Future<MateraiStockBinding> seedMateraiOpening(
  MateraiProfileDatabase db, {
  String id = demoStockProfile,
  int stock = 20,
  bool transactionUsage = false,
  bool transactionCorrection = false,
}) async {
  await db.customStatement(
    "INSERT INTO petugas(id,uuid,nama,email,user_id,status) VALUES(100,'e0c928a2-c304-437e-8bf5-7a81bd5e0eae',?,'materai@example.invalid',102,1)",
    [fixtureOfficer],
  );
  final payload = jsonEncode({
    'kind': 'synthetic_verified_opening',
    if (transactionUsage) 'transaction_usage': true,
    if (transactionCorrection) 'transaction_correction': true,
    'profile': id,
    'opening': stock,
    'date': '2026-11-10',
    'recorded_ms': openingTime.millisecondsSinceEpoch,
    'officer_id': 100,
    'officer': fixtureOfficer,
    'description': 'Saldo pembuka terverifikasi',
  });
  final hash = materaiProvenanceHash(payload);
  final binding = MateraiStockBinding(db, id, hash);
  await db.customStatement(
    '''INSERT INTO materai_movements
    (source_namespace,source_id,business_date,source_created_ms,stock_in,stock_out,recorded_stock,
     description,source_officer_id,officer_snapshot,source_status,provenance_json,payload_sha256)
    VALUES (?,1,'2026-11-10',?,0,0,?,'Saldo pembuka terverifikasi',100,?,1,?,?)''',
    [
      '${binding.namespace}:opening',
      openingTime.millisecondsSinceEpoch,
      stock,
      fixtureOfficer,
      payload,
      hash,
    ],
  );
  return binding;
}
