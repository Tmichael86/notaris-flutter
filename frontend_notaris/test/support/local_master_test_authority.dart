import 'dart:convert';

import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/models/auth_session.dart';
import 'package:frontend_notaris/providers/auth_provider.dart';
import 'package:frontend_notaris/services/auth_service.dart';
import 'package:frontend_notaris/services/local_master_authorization.dart';

String masterTestToken({int uid = 1, int gid = 1, bool expired = false}) =>
    'header.${base64Url.encode(utf8.encode(jsonEncode({'uid': uid, 'gid': gid, 'iss': 'backend-notaris-go', 'sv': 1, 'exp': DateTime.now().add(Duration(hours: expired ? -1 : 2)).millisecondsSinceEpoch ~/ 1000})))}.fixture';
AuthSession masterTestSession({
  int uid = 1,
  List<String>? actions,
  bool offline = false,
}) => AuthSession(
  token: masterTestToken(uid: uid),
  userId: uid,
  groupId: 1,
  userName: 'Master fixture',
  groupName: 'fixture',
  user: const {},
  verifiedAt: DateTime.now(),
  isOffline: offline,
  sidebars: [
    for (final module in MasterModule.values)
      {
        'sidebar': {'sidebar_kode': module.code, 'status': 1},
        'read': 1,
        for (final action in ['create', 'update', 'delete'])
          action: actions == null || actions.contains(action) ? 1 : 0,
      },
  ],
);
LocalMasterAuthorization masterTestAuthority(
  AppDatabase db, {
  AuthSession? Function()? session,
  AppDatabase? Function()? active,
}) => LocalMasterAuthorization(
  database: db,
  currentDatabase: active ?? () => db,
  session: session ?? () => _fixture,
);
final _fixture = masterTestSession();

class MasterTestAuth extends AuthController {
  MasterTestAuth([AuthSession? initial]) : super(AuthService()) {
    state = AuthState.authenticated(initial ?? masterTestSession());
  }
  void replace(AuthSession? next) {
    state = next == null
        ? AuthState.unauthenticated()
        : AuthState.authenticated(next);
  }
}
