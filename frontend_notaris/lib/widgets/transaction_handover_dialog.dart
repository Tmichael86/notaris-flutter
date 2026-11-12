import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/auth_session.dart';
import '../models/transaction_payments.dart';
import '../providers/auth_provider.dart';
import '../providers/database_provider.dart';
import '../repositories/transaction_handover_repository.dart';

class TransactionHandoverDialog extends ConsumerStatefulWidget {
  const TransactionHandoverDialog({super.key, required this.transactionId});
  final int transactionId;

  @override
  ConsumerState<TransactionHandoverDialog> createState() =>
      _HandoverDialogState();
}

class _HandoverDialogState extends ConsumerState<TransactionHandoverDialog> {
  final _description = TextEditingController();
  final _purpose = TextEditingController();
  late final TransactionHandoverRepository _repo;
  late final AuthSession? _openedFor;
  late Future<HandoverView> _records;
  String? _draftUuid, _error, _notice;
  HandoverRecord? _editing;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _repo = TransactionHandoverRepository(ref.read(appDatabaseProvider));
    _openedFor = ref.read(authControllerProvider).session;
    _records = _repo.read(widget.transactionId, _openedFor);
  }

  @override
  void dispose() {
    _description.dispose();
    _purpose.dispose();
    super.dispose();
  }

  bool _allowed(AuthSession? session) =>
      session?.hasTransactionAccess() == true &&
      session!.userId == _openedFor?.userId &&
      session.groupId == _openedFor?.groupId;

  void _edit([HandoverRecord? record]) {
    setState(() {
      _editing = record;
      _draftUuid = record?.uuid ?? const Uuid().v4();
      _description.text = record?.description ?? '';
      _purpose.text = record?.purpose ?? '';
      _error = _notice = null;
    });
  }

  Future<void> _save() async {
    final session = ref.read(authControllerProvider).session;
    if (_saving || !_allowed(session)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _repo.save(
        transactionId: widget.transactionId,
        session: session,
        uuid: _draftUuid!,
        description: _description.text,
        purpose: _purpose.text,
        expectedRevision: _editing?.revision,
      );
      if (!mounted) return;
      setState(() {
        _draftUuid = null;
        _records = _repo.read(widget.transactionId, session);
        _notice = 'Data cetak tersimpan di perangkat ini.';
      });
    } on HandoverRejected catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Data cetak tidak dapat disimpan.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider).session;
    final allowed = _allowed(session);
    final editing = _draftUuid != null && allowed;
    return PopScope(
      canPop: !_saving,
      child: FutureBuilder(
        future: _records,
        builder: (context, snapshot) {
          final data = allowed ? snapshot.data : null;
          return AlertDialog(
            title: Text(
              data == null
                  ? 'Serah Terima Dokumen'
                  : 'Serah Terima • ${data.number}',
            ),
            content: SizedBox(
              width: 540,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!allowed)
                      const Text('Izin baca Transaksi diperlukan.')
                    else if (data == null)
                      Text(
                        snapshot.hasError
                            ? 'Data cetak tidak dapat dimuat.'
                            : 'Memuat data cetak…',
                      )
                    else ...[
                      const Text(
                        'Data persiapan surat. Bukti resmi belum dapat dicetak karena identitas kantor dan pihak penyerah belum terverifikasi.',
                      ),
                      if (data.applicant case final applicant?)
                        Text('Pemohon: $applicant'),
                      if (data.staff case final staff?)
                        Text('Petugas penanggung jawab: $staff'),
                      if (_notice case final notice?) Text(notice),
                      const SizedBox(height: 12),
                      if (editing) ...[
                        TextField(
                          controller: _description,
                          enabled: !_saving,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Uraian',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _purpose,
                          enabled: !_saving,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Keperluan',
                          ),
                        ),
                        if (_error case final error?)
                          Text(
                            error,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                      ] else if (data.records.isEmpty)
                        const Text('Belum ada data cetak.')
                      else
                        for (final record in data.records)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(record.description ?? 'Uraian kosong'),
                            subtitle: Text(
                              [
                                if (record.purpose case final purpose?)
                                  'Keperluan: $purpose',
                                'Dibuat ${formatPaymentDate(record.createdAt)} oleh akun #${record.createdBy}',
                                if (record.updatedBy case final actor?)
                                  'Diubah ${formatPaymentDate(record.updatedAt!)} oleh akun #$actor',
                              ].join('\n'),
                            ),
                            trailing:
                                session?.hasTransactionAccess(update: true) ==
                                    true
                                ? IconButton(
                                    tooltip: 'Edit data cetak',
                                    onPressed: () => _edit(record),
                                    icon: const Icon(Icons.edit_outlined),
                                  )
                                : null,
                          ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: _saving
                    ? null
                    : editing
                    ? () => setState(() => _draftUuid = null)
                    : () => Navigator.of(context).pop(),
                child: Text(editing ? 'Batal' : 'Tutup'),
              ),
              if (editing)
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Menyimpan…' : 'Simpan'),
                )
              else if (data != null &&
                  session?.hasTransactionAccess(create: true) == true)
                FilledButton(
                  onPressed: _edit,
                  child: const Text('Tambah Data'),
                ),
            ],
          );
        },
      ),
    );
  }
}
