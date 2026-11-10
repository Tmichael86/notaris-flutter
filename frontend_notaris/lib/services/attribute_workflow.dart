import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../models/auth_session.dart';
import '../providers/auth_provider.dart';

typedef WorkflowTarget = ({String transaction, String detail, String process});

class AttributeDemoConnection {
  const AttributeDemoConnection(this.http, this.scope);
  final Dio http;
  final String scope;
}

final attributeDemoProvider = Provider<AttributeDemoConnection?>((ref) => null);

abstract interface class AttributeDraftStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class SecureAttributeDraftStore implements AttributeDraftStore {
  const SecureAttributeDraftStore();
  static const _storage = FlutterSecureStorage();
  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

final attributeDraftStoreProvider = Provider<AttributeDraftStore>(
  (ref) => const SecureAttributeDraftStore(),
);

bool canReadAttributeWorkflow(AuthSession? session) =>
    session?.sidebars.any((row) {
      final sidebar = row['sidebar'];
      bool enabled(Object? value) =>
          value == true || value == 1 || value == '1';
      return sidebar is Map &&
          sidebar['sidebar_kode'] == 'transaksi' &&
          enabled(sidebar['status']) &&
          enabled(row['read']);
    }) ??
    false;

final attributeWorkflowProvider = Provider<AttributeWorkflowClient?>((ref) {
  final demo = ref.watch(attributeDemoProvider);
  if (demo == null) return null;
  final session = ref.watch(authControllerProvider).session;
  if (!canReadAttributeWorkflow(session)) return null;
  return AttributeWorkflowClient(
    demo,
    session!,
    ref.watch(attributeDraftStoreProvider),
  );
});

class AttributeWorkflowClient {
  AttributeWorkflowClient(this._demo, this.session, this._store);
  final AttributeDemoConnection _demo;
  final AuthSession session;
  final AttributeDraftStore _store;

  static const _base = '/attribute-workflow';
  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );

  String _path(String uuid) {
    if (!_uuid.hasMatch(uuid)) {
      throw const FormatException('Identitas proses tidak valid.');
    }
    return '$_base/processes/$uuid';
  }

  String _key(WorkflowTarget t) =>
      'notaris.attribute.${_demo.scope}.${session.userId}.${t.transaction}.${t.detail}.${t.process}';

  Options get _options =>
      Options(headers: {'Authorization': 'Bearer ${session.token}'});

  Map<String, dynamic> _verify(WorkflowTarget t, Object? value) {
    final view = Map<String, dynamic>.from(value as Map);
    if (view['transaction_uuid'] != t.transaction ||
        view['detail_uuid'] != t.detail ||
        view['process_uuid'] != t.process ||
        !_uuid.hasMatch(view['definition_uuid'] as String? ?? '') ||
        view['value_type'] != 'text' ||
        !const {
          'draft',
          'waiting',
          'revision',
          'valid',
        }.contains(view['status']) ||
        view['revision'] is! int ||
        view['version'] is! int ||
        view['history'] is! List) {
      throw const FormatException(
        'Scope atribut tidak cocok dengan pekerjaan.',
      );
    }
    return view;
  }

  Future<Map<String, dynamic>> local(WorkflowTarget t) async {
    final raw = await _store.read(_key(t));
    return raw == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<Map<String, dynamic>> refresh(WorkflowTarget t) async {
    final Response<Map<String, dynamic>> response;
    try {
      response = await _demo.http.get<Map<String, dynamic>>(
        _path(t.process),
        options: _options,
      );
    } on DioException catch (error) {
      if ([401, 403].contains(error.response?.statusCode)) {
        final current = await local(t);
        current.remove('view');
        current['requires_refresh'] = true;
        await _store.write(_key(t), jsonEncode(current));
      }
      rethrow;
    }
    final view = _verify(t, response.data?['data']);
    final current = await local(t);
    if (current['definition_uuid'] != null &&
        current['definition_uuid'] != view['definition_uuid']) {
      throw const FormatException(
        'Definisi atribut berubah. Draft ditahan untuk review.',
      );
    }
    current['view'] = view;
    current['definition_uuid'] = view['definition_uuid'];
    current.remove('requires_refresh');
    await _store.write(_key(t), jsonEncode(current));
    return view;
  }

  Future<void> saveDraft(WorkflowTarget t, String text) async {
    final current = await local(t);
    final view = _verify(t, current['view']);
    if (view['can_fill'] != true ||
        current['pending'] != null ||
        current['requires_refresh'] == true) {
      throw StateError(
        'Draft sedang terkunci atau izin pengisian tidak tersedia.',
      );
    }
    current['draft'] = text;
    await _store.write(_key(t), jsonEncode(current));
  }

  Future<void> stage(WorkflowTarget t, String action, {String? reason}) async {
    if (!const {'initialize', 'submit', 'approve', 'revise'}.contains(action)) {
      throw const FormatException('Aksi workflow tidak dikenal.');
    }
    final current = await local(t);
    if (current['pending'] != null || current['requires_refresh'] == true) {
      throw StateError('Selesaikan permintaan atau muat ulang status server.');
    }
    final view = _verify(t, current['view']);
    final value = (current['draft'] as String? ?? '').trim();
    if (action == 'submit' && (view['can_fill'] != true || value.isEmpty)) {
      throw StateError('Simpan draft teks sebelum mengajukan.');
    }
    if (action == 'initialize' &&
        (view['role'] != 'worker' || view['initialized_at'] != null)) {
      throw StateError('Inisialisasi tidak tersedia.');
    }
    if ((action == 'approve' || action == 'revise') &&
        view['can_decide'] != true) {
      throw StateError('Izin keputusan tidak tersedia.');
    }
    if (action == 'revise' && (reason?.trim().isEmpty ?? true)) {
      throw StateError('Alasan revisi wajib diisi.');
    }
    current['pending'] = {
      'mutation_id': const Uuid().v4(),
      'definition_uuid': view['definition_uuid'],
      'expected_revision': view['revision'],
      'action': action,
      if (action == 'submit') 'value': value,
      if (action == 'revise') 'reason': reason!.trim(),
    };
    await _store.write(_key(t), jsonEncode(current));
  }

  Future<void> sendPending(WorkflowTarget t) async {
    final current = await local(t);
    final pending = current['pending'] as Map?;
    if (pending == null) return;
    try {
      final reply = await _demo.http.post<Map<String, dynamic>>(
        _path(t.process),
        data: pending,
        options: _options,
      );
      if ((reply.data?['data'] as Map?)?['revision'] is! int) {
        throw const FormatException(
          'Receipt server tidak lengkap. Permintaan dipertahankan.',
        );
      }
    } on DioException catch (e) {
      if ([401, 403, 409, 422].contains(e.response?.statusCode)) {
        // These responses are definitive. Preserve the draft and refresh the
        // authority snapshot before allowing a new command.
        current.remove('pending');
        if ([401, 403].contains(e.response?.statusCode)) current.remove('view');
        current['requires_refresh'] = true;
        await _store.write(_key(t), jsonEncode(current));
      }
      rethrow;
    }
    current.remove('pending');
    if (pending['action'] == 'submit') current.remove('draft');
    current['requires_refresh'] = true;
    await _store.write(_key(t), jsonEncode(current));
  }

  Future<List<Map<String, dynamic>>> inbox() async {
    final result = await _demo.http.get<Map<String, dynamic>>(
      '$_base/inbox',
      options: _options,
    );
    return [
      for (final row in result.data!['data'] as List)
        Map<String, dynamic>.from(row as Map),
    ];
  }

  Future<void> markRead(String event) async {
    if (!_uuid.hasMatch(event)) {
      throw const FormatException('Identitas notifikasi tidak valid.');
    }
    await _demo.http.post<Map<String, dynamic>>(
      '$_base/inbox/$event/read',
      options: _options,
    );
  }
}
