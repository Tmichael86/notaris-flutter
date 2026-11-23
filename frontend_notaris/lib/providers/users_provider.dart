import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_session.dart';
import '../services/user_api_service.dart';
import 'auth_provider.dart';
import 'pekerjaan_provider.dart' show userApiServiceProvider;

bool allowsUsers(AuthSession? session, String action) {
  if (session?.canUseOnlineAdministration != true) return false;
  final rows = session!.sidebars
      .where(
        (r) =>
            r['sidebar'] is Map &&
            (r['sidebar'] as Map)['sidebar_kode'] == 'users' &&
            (r['sidebar'] as Map)['status'] == 1,
      )
      .toList();
  return rows.length == 1 &&
      rows.single['read'] == 1 &&
      rows.single[action] == 1;
}

final usersPageProvider = FutureProvider.autoDispose
    .family<UsersPage, UsersQuery>((ref, query) {
      if (!allowsUsers(ref.watch(authControllerProvider).session, 'read')) {
        throw StateError(
          'Users membutuhkan Superadmin online dengan izin baca.',
        );
      }
      return ref.watch(userApiServiceProvider).list(query);
    });
