import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_session.dart';
import '../services/office_configuration_api_service.dart';
import 'auth_provider.dart';
import 'authenticated_api_provider.dart';

// Navigation is not authorization. The backend verifies signature, current
// membership, security version and exact canonical permission on every GET.
bool allowsOfficeConfiguration(AuthSession? s) {
  if (s == null || s.isOffline || s.userId < 1 || s.groupId < 1) return false;
  try {
    final parts = s.token.split('.');
    if (parts.length != 3 || parts.any((p) => p.isEmpty)) return false;
    final c = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (c is! Map ||
        c['iss'] != 'backend-notaris-go' ||
        c['uid'] != s.userId ||
        c['gid'] != s.groupId ||
        c['sv'] is! int ||
        (c['sv'] as int) < 1 ||
        c['exp'] is! int ||
        (c['exp'] as int) <=
            DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000) {
      return false;
    }
    final grants = s.sidebars
        .where(
          (a) =>
              a['sidebar'] is Map &&
              (a['sidebar'] as Map)['sidebar_kode'] == 'konfigurasi',
        )
        .toList();
    return grants.length == 1 &&
        (grants.single['sidebar'] as Map)['status'] == 1 &&
        grants.single['read'] == 1;
  } catch (_) {
    return false;
  }
}

final officeConfigurationApiProvider = Provider<OfficeConfigurationApiService>(
  (ref) => OfficeConfigurationApiService(ref.watch(authenticatedDioProvider)),
);
final officeConfigurationProvider =
    FutureProvider.autoDispose<OfficeConfiguration>((ref) {
      if (!allowsOfficeConfiguration(
        ref.watch(authControllerProvider).session,
      )) {
        throw StateError(
          'Sesi online dengan izin baca konfigurasi diperlukan.',
        );
      }
      return ref.watch(officeConfigurationApiProvider).read();
    });
