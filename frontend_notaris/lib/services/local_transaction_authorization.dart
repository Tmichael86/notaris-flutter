import '../database/app_database.dart';
import '../models/auth_session.dart';
import 'local_master_authorization.dart';

enum TransactionAction { read, create, update, delete }

class LocalTransactionDenied extends StateError {
  LocalTransactionDenied([this.code = 'permission'])
    : super(
        'Akses Transaksi ditolak ($code). Sesi, profil, dan izin tindakan harus sesuai; data tidak diubah.',
      );
  final String code;
  @override
  String toString() =>
      'Akses Transaksi ditolak ($code). Sesi, profil, dan izin tindakan harus sesuai; data tidak diubah.';
}

/// One canonical grant: transaksi. No group-name, domain or menu aliases.
/// Reuses H02's identity/profile/offline validation, not its Master grants.
class LocalTransactionAuthorization {
  LocalTransactionAuthorization(this.context);
  final LocalMasterAuthorization context;

  AuthSession require(
    TransactionAction action, {
    AuthSession? expected,
    int? claimedActor,
  }) {
    final AuthSession actor;
    try {
      actor = context.requireContext(
        expected: expected,
        claimedActor: claimedActor,
      );
    } on LocalMasterDenied catch (e) {
      throw LocalTransactionDenied(e.code);
    }
    bool yes(Object? v) => v == 1 || v == true || v == '1';
    final grants = actor.sidebars
        .where(
          (a) =>
              a['sidebar'] is Map &&
              (a['sidebar'] as Map)['sidebar_kode'] == 'transaksi',
        )
        .toList();
    if (grants.length != 1) throw LocalTransactionDenied();
    final grant = grants.single, sidebar = grant['sidebar'] as Map;
    if (!yes(sidebar['status']) ||
        sidebar['sidebar_route'] == '#' ||
        !yes(grant['read']) ||
        !yes(grant[action.name])) {
      throw LocalTransactionDenied();
    }
    return actor;
  }

  bool allows(TransactionAction action, {AuthSession? expected}) {
    try {
      require(action, expected: expected);
      return true;
    } on LocalTransactionDenied {
      return false;
    }
  }

  Future<T> write<T>(
    AppDatabase db,
    TransactionAction action,
    Future<T> Function(AuthSession) operation, {
    AuthSession? expected,
    int? claimedActor,
    Set<TransactionAction> additional = const {},
  }) async {
    if (action == TransactionAction.read) {
      throw LocalTransactionDenied('write_action_required');
    }
    if (!identical(db, context.database)) {
      throw LocalTransactionDenied('profile');
    }
    final actor = require(
      action,
      expected: expected,
      claimedActor: claimedActor,
    );
    void check() {
      require(action, expected: actor, claimedActor: claimedActor);
      for (final extra in additional) {
        require(extra, expected: actor, claimedActor: claimedActor);
      }
    }

    check();
    return db.transaction(() async {
      check();
      final result = await operation(actor);
      check(); // rollback parent/children/payment/ledger/audit if revoked mid-write
      return result;
    });
  }
}
