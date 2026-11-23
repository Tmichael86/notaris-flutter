import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../providers/database_provider.dart';
import '../services/attribute_workflow.dart';

String _failure(Object error) {
  if (error is DioException) {
    return switch (error.response?.statusCode) {
      401 || 403 => 'Sesi atau izin workflow tidak berlaku.',
      409 =>
        'Versi atau status telah berubah. Muat ulang sebelum mencoba lagi.',
      422 => 'Data belum memenuhi aturan workflow.',
      _ => 'Belum terkonfirmasi oleh server. Permintaan yang tertunda dapat dicoba ulang.',
    };
  }
  if (error is StateError) return error.message;
  return 'Workflow tidak dapat diproses. Periksa koneksi dan identitas pekerjaan.';
}

bool _denied(Object error) =>
    error is DioException && [401, 403].contains(error.response?.statusCode);

Future<WorkflowTarget?> _localTarget(WidgetRef ref, String process) async {
  final row = await ref
      .read(appDatabaseProvider)
      .customSelect(
        '''
    SELECT t.uuid AS transaction_uuid,d.uuid AS detail_uuid,p.uuid AS process_uuid
    FROM transaksi_proses p JOIN transaksi_details d ON d.uuid=p.transaksi_detail_uuid
      AND d.transaksi_id=p.transaksi_id AND d.deleted_at IS NULL AND d.status=1
    JOIN transaksis t ON t.id=p.transaksi_id AND t.deleted_at IS NULL
    WHERE p.uuid=? AND p.deleted_at IS NULL AND t.jenis_transaksi='notaris'
    ''',
        variables: [Variable(process)],
      )
      .getSingleOrNull();
  if (row == null) return null;
  return (
    transaction: row.read<String>('transaction_uuid'),
    detail: row.read<String>('detail_uuid'),
    process: row.read<String>('process_uuid'),
  );
}

Future<void> showAttributeWorkflow(
  BuildContext context,
  WidgetRef ref,
  String process, {
  Map<String, dynamic>? event,
  VoidCallback? onNavigate,
}) async {
  final client = ref.read(attributeWorkflowProvider);
  if (client == null) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    final target = await _localTarget(ref, process);
    if (!context.mounted) return;
    if (target == null ||
        (event != null &&
            (target.transaction != event['transaction_uuid'] ||
                target.detail != event['detail_uuid']))) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Pekerjaan belum tersedia pada profil lokal ini.'),
        ),
      );
      return;
    }
    if (event != null) {
      final current = await client.refresh(target);
      if (current['definition_uuid'] != event['definition_uuid']) {
        throw const FormatException('Definisi atribut tidak cocok.');
      }
      if (!context.mounted ||
          ref.read(attributeWorkflowProvider)?.session.userId !=
              client.session.userId) {
        return;
      }
      await client.markRead(event['event_uuid'] as String);
    }
    if (!context.mounted ||
        ref.read(attributeWorkflowProvider)?.session.userId !=
            client.session.userId) {
      return;
    }
    onNavigate?.call();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AttributeDialog(client: client, target: target),
    );
  } catch (error) {
    if (context.mounted) {
      messenger.showSnackBar(SnackBar(content: Text(_failure(error))));
    }
  }
}

Future<void> showAttributeInbox(
  BuildContext context,
  WidgetRef ref,
  VoidCallback onNavigate,
) async {
  final client = ref.read(attributeWorkflowProvider);
  if (client == null) return;
  final event = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => _InboxDialog(client: client),
  );
  if (context.mounted &&
      event != null &&
      ref.read(attributeWorkflowProvider)?.session.userId ==
          client.session.userId) {
    await showAttributeWorkflow(
      context,
      ref,
      event['process_uuid'] as String,
      event: event,
      onNavigate: onNavigate,
    );
  }
}

class _InboxDialog extends ConsumerStatefulWidget {
  const _InboxDialog({required this.client});
  final AttributeWorkflowClient client;
  @override
  ConsumerState<_InboxDialog> createState() => _InboxDialogState();
}

class _InboxDialogState extends ConsumerState<_InboxDialog> {
  late Future<List<Map<String, dynamic>>> _items = widget.client.inbox();

  @override
  Widget build(BuildContext context) {
    if (ref.watch(attributeWorkflowProvider)?.session.userId !=
        widget.client.session.userId) {
      return const AlertDialog(
        content: Text('Sesi notifikasi telah berakhir.'),
      );
    }
    return AlertDialog(
      title: const Text('Notifikasi Atribut'),
      content: SizedBox(
        width: 470,
        child: FutureBuilder(
          future: _items,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const LinearProgressIndicator();
            }
            if (snapshot.hasError) return Text(_failure(snapshot.error!));
            final items = snapshot.data ?? [];
            if (items.isEmpty) return const Text('Belum ada notifikasi.');
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final row in items)
                    ListTile(
                      leading: Icon(
                        row['read_at'] == null
                            ? Icons.mark_email_unread_outlined
                            : Icons.mark_email_read_outlined,
                      ),
                      title: Text(
                        '${_eventLabel(row['action'])} · ${row['transaction_number']}',
                      ),
                      subtitle: Text(
                        '${row['attribute_name']} · Versi ${row['version']}\n'
                        '${_localTime(row['occurred_at'])}'
                        '${row['reason'] == null ? '' : '\n${row['reason']}'}',
                      ),
                      onTap: () => Navigator.pop(context, row),
                    ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() => _items = widget.client.inbox()),
          child: const Text('Muat ulang'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
      ],
    );
  }
}

class _AttributeDialog extends ConsumerStatefulWidget {
  const _AttributeDialog({required this.client, required this.target});
  final AttributeWorkflowClient client;
  final WorkflowTarget target;
  @override
  ConsumerState<_AttributeDialog> createState() => _AttributeDialogState();
}

class _AttributeDialogState extends ConsumerState<_AttributeDialog> {
  final _draft = TextEditingController();
  final _reason = TextEditingController();
  Map<String, dynamic> _local = {};
  Map<String, dynamic>? _view;
  String? _message;
  bool _busy = true;
  bool _online = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _readLocal() async {
    final state = await widget.client.local(widget.target);
    if (!mounted) return;
    _local = state;
    _view = (state['view'] as Map?)?.cast<String, dynamic>();
    _draft.text = state['draft'] as String? ?? '';
  }

  Future<void> _load() async {
    try {
      await _readLocal();
      await widget.client.refresh(widget.target);
      if (!mounted) return;
      _online = true;
      await _readLocal();
    } catch (error) {
      _online = false;
      _message = _failure(error);
      if (_denied(error) || error is FormatException) _view = null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _run(Future<void> Function() run, {bool refresh = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await run();
      if (!mounted) return;
      if (refresh) {
        await _load();
      } else {
        await _readLocal();
        _message = 'Draft tersimpan di perangkat.';
      }
    } catch (error) {
      if (!mounted) return;
      await _readLocal();
      if (!mounted) return;
      _message = _failure(error);
      if (error is DioException) _online = false;
      if (_denied(error) || error is FormatException) _view = null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _command(String action) => _run(() async {
    await widget.client.stage(widget.target, action, reason: _reason.text);
    await widget.client.sendPending(widget.target);
    if (mounted) _reason.clear();
  }, refresh: true);

  @override
  void dispose() {
    _draft.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sameAccount =
        ref.watch(attributeWorkflowProvider)?.session.userId ==
        widget.client.session.userId;
    final view = sameAccount ? _view : null;
    final pending = sameAccount && _local['pending'] != null;
    final canAct = !_busy && !pending && _local['requires_refresh'] != true;
    final canFill = canAct && view?['can_fill'] == true;
    final canDecide = canAct && _online && view?['can_decide'] == true;
    final status = view?['status'];
    final history = view?['history'] as List? ?? [];
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(view?['name'] as String? ?? 'Validasi Atribut'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_busy) const LinearProgressIndicator(),
                if (!sameAccount) const Text('Sesi workflow telah berakhir.'),
                if (sameAccount && _message != null) Text(_message!),
                if (pending)
                  const Text('Permintaan menunggu konfirmasi server.'),
                if (view != null) ...[
                  const SizedBox(height: 8),
                  Chip(
                    label: Text(switch (status) {
                      'waiting' => 'Menunggu Konfirmasi',
                      'revision' => 'Perlu Revisi',
                      'valid' => 'Valid',
                      _ => 'Belum Diajukan',
                    }),
                    backgroundColor: switch (status) {
                      'waiting' => Colors.amber.shade100,
                      'revision' => Colors.red.shade100,
                      'valid' => Colors.green.shade100,
                      _ => AppColors.bgLight,
                    },
                  ),
                  Text(
                    _online
                        ? 'Status terkonfirmasi server'
                        : 'Salinan terakhir, belum diperbarui',
                  ),
                  Text(
                    view['initialized_at'] == null
                        ? 'Workflow proses belum diinisialisasi.'
                        : 'Workflow proses diinisialisasi ${_localTime(view['initialized_at'])}.',
                  ),
                  if (view['role'] == 'worker' &&
                      view['initialized_at'] == null)
                    TextButton(
                      onPressed: canAct && _online
                          ? () => _command('initialize')
                          : null,
                      child: const Text('Inisialisasi workflow'),
                    ),
                  if (view['can_fill'] == true) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _draft,
                      enabled: canFill,
                      maxLength: 2000,
                      maxLines: 3,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Nilai teks',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: canFill
                              ? () => _run(
                                  () => widget.client.saveDraft(
                                    widget.target,
                                    _draft.text,
                                  ),
                                )
                              : null,
                          child: const Text('Simpan draft lokal'),
                        ),
                        FilledButton(
                          onPressed:
                              canFill &&
                                  _draft.text.trim().isNotEmpty &&
                                  _local['draft'] == _draft.text
                              ? () => _command('submit')
                              : null,
                          child: const Text('Ajukan validasi'),
                        ),
                      ],
                    ),
                  ],
                  if (view['can_decide'] == true) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _reason,
                      enabled: canDecide,
                      maxLength: 1000,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Alasan revisi',
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton(
                          onPressed: canDecide
                              ? () => _command('approve')
                              : null,
                          child: const Text('Nyatakan Valid'),
                        ),
                        OutlinedButton(
                          onPressed: canDecide && _reason.text.trim().isNotEmpty
                              ? () => _command('revise')
                              : null,
                          child: const Text('Minta revisi'),
                        ),
                      ],
                    ),
                  ],
                  const Divider(),
                  const Text('Histori'),
                  if (history.isEmpty) const Text('Belum ada tindakan.'),
                  for (final event in history.cast<Map>())
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${_eventLabel(event['action'])} · Versi ${event['version']}',
                      ),
                      subtitle: Text(
                        '${event['actor_name'] ?? 'Akun ${event['actor_id']}'} · ${_localTime(event['occurred_at'])}'
                        '${event['value'] == null ? '' : '\n${event['value']}'}'
                        '${event['reason'] == null ? '' : '\n${event['reason']}'}',
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (pending)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => _run(
                      () => widget.client.sendPending(widget.target),
                      refresh: true,
                    ),
              child: const Text('Coba kirim lagi'),
            ),
          if (sameAccount)
            TextButton(
              onPressed: _busy ? null : () => _run(() async {}, refresh: true),
              child: const Text('Muat ulang'),
            ),
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
}

String _eventLabel(Object? action) => switch (action) {
  'initialize' => 'Inisialisasi',
  'submit' => 'Pengajuan atribut',
  'approve' => 'Atribut Valid',
  'revise' => 'Perlu Revisi',
  _ => 'Aktivitas atribut',
};

String _localTime(Object? time) =>
    DateTime.tryParse(time?.toString() ?? '')
        ?.toLocal()
        .toString()
        .split('.')
        .first ??
    '—';
