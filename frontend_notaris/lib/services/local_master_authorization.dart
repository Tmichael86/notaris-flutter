import 'dart:convert';

import '../database/app_database.dart';
import '../models/auth_session.dart';
import '../models/verified_demo_session.dart';
import 'auth_service.dart';

enum MasterModule {
  notaris('pekerjaan_notaris'),
  ppat('pekerjaan_ppat'),
  category('kategori_pekerjaan'),
  expenseType('jenis_pengeluaran'),
  officer('petugas'),
  applicant('pemohon');

  const MasterModule(this.code);
  final String code;
}

enum MasterAction { read, create, update, delete }

class LocalMasterDenied implements Exception {
  const LocalMasterDenied([this.code = 'permission']);
  final String code;
  @override
  String toString() =>
      'Akses Master ditolak ($code). Sesi, profil, dan izin tindakan harus sesuai; data tidak diubah.';
}

/// Application authority, not a bypass capability. Always re-resolves the
/// current session and database; no role/name/parent-menu grants are inferred.
class LocalMasterAuthorization {
  LocalMasterAuthorization({
    required this.database,
    required this.currentDatabase,
    required this.session,
    this.profileId,
  });
  final AppDatabase database;
  final AppDatabase? Function() currentDatabase;
  final AuthSession? Function() session;
  final String? profileId;

  AuthSession require(
    MasterModule module,
    MasterAction action, {
    AuthSession? expected,
    int? claimedActor,
  }) {
    AuthSession? s;
    AppDatabase? active;
    try {
      s = session();
      active = currentDatabase();
    } catch (_) {
      throw const LocalMasterDenied("inactive_context");
    }
    final now = DateTime.now();
    if (!identical(database, active) ||
        s == null ||
        (expected != null && !identical(s, expected)) ||
        s.userId <= 0 ||
        s.groupId <= 0 ||
        s.token.trim().isEmpty ||
        s.verifiedAt.isAfter(now) ||
        (claimedActor != null && claimedActor != s.userId)) {
      throw const LocalMasterDenied('session_or_profile');
    }
    if (s is ExpiringPaymentDemoSession) {
      if (profileId == null ||
          s.profileId != profileId ||
          !now.isBefore(s.expiresAt)) {
        throw const LocalMasterDenied('demo_session');
      }
    } else {
      try {
        final parts = s.token.split('.');
        if (parts.length != 3) throw const FormatException();
        final claims = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
        );
        if (claims is! Map ||
            claims['iss'] != 'backend-notaris-go' ||
            claims['uid'] != s.userId ||
            claims['gid'] != s.groupId ||
            claims['exp'] is! int ||
            claims['exp'] <= now.millisecondsSinceEpoch ~/ 1000) {
          throw const FormatException();
        }
      } catch (_) {
        throw const LocalMasterDenied('invalid_or_expired_session');
      }
      // Existing AuthService offline grace, not a new revocation policy.
      if (s.isOffline &&
          now.difference(s.verifiedAt) > AuthService.offlineGracePeriod) {
        throw const LocalMasterDenied('offline_session');
      }
    }
    if ((s.user['id'] != null &&
            s.user['id'].toString() != s.userId.toString()) ||
        (s.user['group_id'] != null &&
            s.user['group_id'].toString() != s.groupId.toString())) {
      throw const LocalMasterDenied('identity_mismatch');
    }
    bool yes(Object? v) => v == true || v == 1 || v == '1';
    if ((s.user.containsKey('status') && !yes(s.user['status'])) ||
        (s.user.containsKey('group_status') && !yes(s.user['group_status']))) {
      throw const LocalMasterDenied('inactive_identity');
    }
    final grants = s.sidebars
        .where(
          (a) =>
              a['sidebar'] is Map &&
              (a['sidebar'] as Map)['sidebar_kode'] == module.code,
        )
        .toList();
    if (grants.length != 1) throw const LocalMasterDenied();
    final g = grants.single, sidebar = g['sidebar'] as Map;
    if (!yes(sidebar['status']) ||
        sidebar['sidebar_route'] == '#' ||
        !yes(g['read']) ||
        !yes(g[action.name])) {
      throw const LocalMasterDenied();
    }
    return s;
  }

  bool allows(MasterModule module, MasterAction action) {
    try {
      require(module, action);
      return true;
    } on LocalMasterDenied {
      return false;
    }
  }

  Future<T> write<T>(
    AppDatabase db,
    MasterModule module,
    MasterAction action,
    Future<T> Function(AuthSession) operation, {
    int? claimedActor,
  }) async {
    if (!identical(db, database)) throw const LocalMasterDenied('profile');
    final actor = require(module, action, claimedActor: claimedActor);
    return db.transaction(() async {
      require(module, action, expected: actor, claimedActor: claimedActor);
      final value = await operation(actor);
      require(module, action, expected: actor, claimedActor: claimedActor);
      return value;
    });
  }
}
