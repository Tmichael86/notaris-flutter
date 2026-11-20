import 'package:dio/dio.dart';

class GroupSidebarAccessApiService {
  GroupSidebarAccessApiService(this._dio);
  final Dio _dio;
  Future<GroupAccessSnapshot> getByGroup(int groupId) async {
    final data = _envelope(
      (await _dio.get<Object?>('/groups/$groupId/sidebar-access')).data,
    );
    final snapshot = GroupAccessSnapshot.fromJson(_map(data));
    if (snapshot.id != groupId) {
      throw const FormatException('Identitas grup tidak cocok.');
    }
    return snapshot;
  }

  Future<void> replaceForGroup({
    required GroupAccessSnapshot snapshot,
    required List<GroupSidebarAccessInput> access,
  }) async {
    if (!snapshot.editable) throw StateError('Grup terproteksi atau nonaktif.');
    final expected = snapshot.entries
        .where((r) => r.editable)
        .map((r) => r.id)
        .toSet();
    final seen = <int>{};
    for (final r in access) {
      if (!expected.contains(r.sidebarId) ||
          !seen.add(r.sidebarId) ||
          ![
            r.read,
            r.create,
            r.update,
            r.delete,
          ].every((v) => v == 0 || v == 1) ||
          (r.read == 0 && [r.create, r.update, r.delete].contains(1))) {
        throw ArgumentError('Snapshot akses tidak lengkap atau tidak sah.');
      }
    }
    if (seen.length != expected.length) {
      throw ArgumentError('Setiap menu editable wajib dikirim eksplisit.');
    }
    _envelope(
      (await _dio.put<Object?>(
        '/groups/${snapshot.id}/sidebar-access',
        data: {
          'expected_revision': snapshot.revision,
          'catalog_fingerprint': snapshot.catalog,
          'access': access.map((r) => r.toJson()).toList(),
        },
      )).data,
    );
  }

  Object? _envelope(Object? raw) {
    final e = _map(raw);
    if (e['success'] != true) {
      throw const FormatException(
        'Server belum mengonfirmasi perubahan akses.',
      );
    }
    return e['data'];
  }
}

Map<String, dynamic> _map(Object? raw) {
  if (raw is! Map) throw const FormatException('Snapshot akses tidak valid.');
  return Map<String, dynamic>.from(raw);
}

int _integer(Map<String, dynamic> m, String key, {int min = 0}) {
  final v = m[key];
  if (v is! int || v < min) {
    throw const FormatException('Identitas/flag akses tidak valid.');
  }
  return v;
}

String _text(Map<String, dynamic> m, String key, {bool empty = false}) {
  final v = m[key];
  if (v is! String || (!empty && v.trim().isEmpty)) {
    throw const FormatException('Metadata akses tidak valid.');
  }
  return v;
}

class GroupAccessSnapshot {
  const GroupAccessSnapshot({
    required this.id,
    required this.name,
    required this.kind,
    required this.status,
    required this.revision,
    required this.activeMembers,
    required this.catalog,
    required this.entries,
  });
  final int id, status, revision, activeMembers;
  final String name, kind, catalog;
  final List<GroupAccessEntry> entries;
  bool get editable => status == 1 && kind == 'user';
  factory GroupAccessSnapshot.fromJson(Map<String, dynamic> m) {
    final g = _map(m['group']), rows = m['entries'];
    final kind = _text(g, 'group_jenis'),
        status = _integer(g, 'status'),
        catalog = _text(m, 'catalog_fingerprint');
    if (!['user', 'superadmin'].contains(kind) ||
        ![0, 1].contains(status) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(catalog) ||
        rows is! List ||
        rows.length > 1000) {
      throw const FormatException('Katalog akses tidak valid.');
    }
    final entries = rows
        .map((v) => GroupAccessEntry.fromJson(_map(v)))
        .toList();
    if (entries.map((r) => r.id).toSet().length != entries.length ||
        entries.map((r) => r.code).toSet().length != entries.length) {
      throw const FormatException('Katalog akses ambigu.');
    }
    return GroupAccessSnapshot(
      id: _integer(g, 'id', min: 1),
      name: _text(g, 'group_nama'),
      kind: kind,
      status: status,
      revision: _integer(g, 'revision', min: 1),
      activeMembers: _integer(g, 'active_members'),
      catalog: catalog,
      entries: entries,
    );
  }
}

class GroupAccessEntry {
  const GroupAccessEntry({
    required this.id,
    required this.parent,
    required this.name,
    required this.code,
    required this.route,
    required this.icon,
    required this.order,
    required this.status,
    required this.editable,
    required this.reason,
    required this.flags,
  });
  final int id, order, status;
  final int? parent;
  final String name, code, route, icon, reason;
  final bool editable;
  final List<int> flags;
  factory GroupAccessEntry.fromJson(Map<String, dynamic> m) {
    final s = _map(m['sidebar']),
        p = s['sidebar_parent_id'],
        status = _integer(s, 'status');
    final flags = [
      for (final k in ['read', 'create', 'update', 'delete']) _integer(m, k),
    ];
    if ((p != null && (p is! int || p < 0)) ||
        ![0, 1].contains(status) ||
        !flags.every((v) => v == 0 || v == 1) ||
        m['editable'] is! bool ||
        (m['editable'] == true && status != 1) ||
        s['sidebar_index'] is! int) {
      throw const FormatException('Baris akses tidak valid.');
    }
    return GroupAccessEntry(
      id: _integer(s, 'id', min: 1),
      parent: p as int?,
      name: _text(s, 'sidebar_nama'),
      code: _text(s, 'sidebar_kode'),
      route: _text(s, 'sidebar_route', empty: true),
      icon: _text(s, 'sidebar_icon', empty: true),
      order: s['sidebar_index'] as int,
      status: status,
      editable: m['editable'] as bool,
      reason: _text(m, 'reason', empty: true),
      flags: flags,
    );
  }
}

class GroupSidebarAccessInput {
  const GroupSidebarAccessInput({
    required this.sidebarId,
    this.read = 0,
    this.create = 0,
    this.update = 0,
    this.delete = 0,
  });
  final int sidebarId, read, create, update, delete;
  Map<String, dynamic> toJson() => {
    'sidebar_id': sidebarId,
    'read': read,
    'create': create,
    'update': update,
    'delete': delete,
  };
}
