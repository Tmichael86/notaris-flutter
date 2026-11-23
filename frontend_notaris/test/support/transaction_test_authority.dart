import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/models/auth_session.dart';
import 'package:frontend_notaris/repositories/transaction_repository.dart';
import 'package:frontend_notaris/repositories/transaksi_proses_repository.dart';
import 'package:frontend_notaris/repositories/materai_stock_repository.dart';
import 'package:frontend_notaris/services/local_master_authorization.dart';
import 'package:frontend_notaris/services/local_transaction_authorization.dart';

import 'local_master_test_authority.dart' show masterTestToken;

/// Explicit test-only authority. Production repositories have no default grants.
AuthSession transactionTestSession({
  List<String> actions = const ['read', 'create', 'update', 'delete'],
  int uid = 1,
}) => AuthSession(
  token: masterTestToken(uid: uid),
  userId: uid,
  groupId: 1,
  userName: 'Transaction test',
  groupName: 'Test operators',
  user: const {},
  verifiedAt: DateTime.now(),
  sidebars: [
    {
      'sidebar': {'sidebar_kode': 'transaksi', 'status': 1},
      for (final action in ['read', 'create', 'update', 'delete'])
        action: actions.contains(action) ? 1 : 0,
    },
  ],
);

LocalTransactionAuthorization transactionTestAuthority(
  AppDatabase db, {
  AuthSession? Function()? session,
  AppDatabase? Function()? active,
  String? profileId,
}) {
  final fixture = transactionTestSession();
  return LocalTransactionAuthorization(
    LocalMasterAuthorization(
      database: db,
      currentDatabase: active ?? () => db,
      session: session ?? () => fixture,
      profileId: profileId,
    ),
  );
}

TransactionRepository testTransactionRepository(
  AppDatabase db, {
  MateraiStockRepository? materaiStock,
  AuthSession? Function()? session,
  String? profileId,
}) => TransactionRepository(
  db,
  materaiStock: materaiStock,
  authorization: transactionTestAuthority(
    db,
    session: session,
    profileId: profileId,
  ),
);

TransaksiProsesRepository testProcessRepository(
  AppDatabase db, {
  AuthSession? Function()? session,
}) => TransaksiProsesRepository(
  db,
  authorization: transactionTestAuthority(db, session: session),
);
