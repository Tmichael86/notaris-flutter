import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_session.dart';
import '../services/group_api_service.dart';
import 'auth_provider.dart';
import 'pekerjaan_provider.dart' show groupApiServiceProvider;

bool allowsGroups(AuthSession? session, String action) {
  if (session?.canUseOnlineAdministration != true) return false;
  final rows = session!.sidebars
      .where(
        (r) =>
            r['sidebar'] is Map &&
            (r['sidebar'] as Map)['sidebar_kode'] == 'groups' &&
            (r['sidebar'] as Map)['status'] == 1,
      )
      .toList();
  return rows.length == 1 &&
      rows.single['read'] == 1 &&
      rows.single[action] == 1;
}

final groupsPageProvider = FutureProvider.autoDispose
    .family<GroupsPage, GroupsQuery>((ref, q) {
      if (!allowsGroups(ref.watch(authControllerProvider).session, 'read')) {
        throw StateError(
          'Groups memerlukan Superadmin online dengan izin baca.',
        );
      }
      return ref.watch(groupApiServiceProvider).list(q);
    });
