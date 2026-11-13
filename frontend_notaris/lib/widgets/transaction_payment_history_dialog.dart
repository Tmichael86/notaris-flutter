import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/widgets/edit_dialog.dart';
import '../database/app_database.dart';
import '../models/transaction_payments.dart';
import '../providers/auth_provider.dart';
import '../providers/transaction_provider.dart';
import 'transaction_dialog_section.dart';

String _amountLabel(TransaksiRiwayatPembayaran row) {
  try {
    return formatPaymentRupiah(paymentRupiah(row));
  } on ArgumentError {
    return 'Rp ${row.nominal} · perlu ditinjau';
  } on StateError {
    return 'Rp ${row.nominal} · perlu ditinjau';
  }
}

class TransactionPaymentHistoryDialog extends ConsumerWidget {
  const TransactionPaymentHistoryDialog({
    super.key,
    required this.transactionNumber,
    required this.transactionId,
  });

  final String transactionNumber;
  final int? transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = transactionId;
    final session = ref.watch(authControllerProvider).session;
    final statement = id == null
        ? null
        : ref.watch(transactionPaymentStatementProvider(id));
    final canAdd = session?.hasTransactionAccess(update: true) == true;
    final canCorrect = session?.canCorrectTransactionPayment == true;
    return AlertDialog(
      title: const Text('Riwayat Pembayaran'),
      content: SizedBox(
        width: 620,
        height: MediaQuery.sizeOf(context).height * .56,
        child:
            statement?.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) =>
                  const Center(child: Text('Gagal memuat riwayat pembayaran.')),
              data: (data) => ListView(
                children: [
                  Text(
                    '${data.transaction.jenisTransaksi.toUpperCase()} · ${data.transaction.noAkta}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 12),
                  TransactionDialogSection(
                    highlight: true,
                    child: Wrap(
                      spacing: 20,
                      runSpacing: 8,
                      children: [
                        if (data.issue case final issue?)
                          Text(issue)
                        else ...[
                          if (data.billed case final billed?)
                            Text(
                              'Total Tagihan  ${formatPaymentRupiah(billed)}',
                            ),
                          if (data.paid case final paid?)
                            Text('Total Dibayar  ${formatPaymentRupiah(paid)}'),
                          if (data.remaining case final remaining?) ...[
                            Text(
                              'Sisa Tagihan  ${formatPaymentRupiah(remaining)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (remaining < 0)
                              const Text(
                                'Pembayaran historis melebihi tagihan.',
                              ),
                          ],
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Rincian cicilan',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  if (data.payments.isEmpty)
                    const TransactionDialogSection(
                      child: Text('Belum ada riwayat pembayaran.'),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: data.payments.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final row = data.payments[index];
                        final active = isActivePayment(row);
                        return ListTile(
                          leading: Icon(
                            active
                                ? Icons.receipt_long_outlined
                                : Icons.history_outlined,
                          ),
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Cicilan ${row.urutanPembayaran} · ${_amountLabel(row)}',
                          ),
                          subtitle: Text(
                            '${formatPaymentDate(row.tanggalPembayaran)} · ${row.metodePembayaran}'
                            '${row.keterangan == null ? '' : ' · ${row.keterangan}'}\n'
                            '${active ? 'Aktif' : 'Dibatalkan'}',
                          ),
                          trailing: active && canCorrect && data.issue == null
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip:
                                          'Edit cicilan ${row.urutanPembayaran}',
                                      onPressed: () =>
                                          _edit(context, ref, id!, row: row),
                                      icon: const Icon(Icons.edit_outlined),
                                    ),
                                    IconButton(
                                      tooltip:
                                          'Batalkan cicilan ${row.urutanPembayaran}',
                                      onPressed: () => _edit(
                                        context,
                                        ref,
                                        id!,
                                        row: row,
                                        cancel: true,
                                      ),
                                      icon: const Icon(Icons.cancel_outlined),
                                    ),
                                  ],
                                )
                              : null,
                        );
                      },
                    ),
                ],
              ),
            ) ??
            const Center(
              child: Text('Simpan transaksi untuk melihat riwayat pembayaran.'),
            ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
        if (id != null && canAdd)
          FilledButton(
            onPressed:
                statement?.valueOrNull == null ||
                    statement?.valueOrNull?.issue != null
                ? null
                : () => _edit(context, ref, id),
            child: const Text('Tambah Pembayaran'),
          ),
      ],
    );
  }
}

Future<void> _edit(
  BuildContext context,
  WidgetRef ref,
  int id, {
  TransaksiRiwayatPembayaran? row,
  bool cancel = false,
}) async {
  final requestId = const Uuid().v4();
  final amount = TextEditingController(
    text: row == null ? '' : paymentRupiah(row).toString(),
  );
  final note = TextEditingController(text: row?.keterangan);
  final reason = TextEditingController();
  final initialDate = row?.tanggalPembayaran ?? DateTime.now();
  final initialMethod = row?.metodePembayaran ?? 'Cash';
  var date = initialDate;
  var method = initialMethod;
  var saving = false;
  String? error;

  try {
    final result = await showEditDialog<bool>(
      context: context,
      saving: () => saving,
      dirty: () =>
          reason.text.isNotEmpty ||
          amount.text != (row == null ? '' : paymentRupiah(row).toString()) ||
          note.text != (row?.keterangan ?? '') ||
          method != initialMethod ||
          date != initialDate,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          Future<void> save() async {
            if (saving) return;
            setState(() {
              saving = true;
              error = null;
            });
            try {
              final repository = ref.read(transactionRepositoryProvider);
              final session = ref.read(authControllerProvider).session;
              final parsed = int.tryParse(amount.text.trim());
              if (!cancel &&
                  (parsed == null ||
                      !RegExp(r'^\d+$').hasMatch(amount.text.trim()))) {
                throw ArgumentError('Masukkan nominal rupiah bulat.');
              }
              final bool changed;
              if (cancel) {
                changed = await repository.cancelPayment(
                  session: session,
                  transactionId: id,
                  expected: row!,
                  reason: reason.text,
                );
              } else if (row == null) {
                await repository.addPayment(
                  session: session,
                  transactionId: id,
                  paymentUuid: requestId,
                  paymentDate: date,
                  amount: parsed!,
                  method: method,
                  note: note.text,
                );
                changed = true;
              } else {
                changed = await repository.editPayment(
                  session: session,
                  transactionId: id,
                  expected: row,
                  paymentDate: date,
                  amount: parsed!,
                  method: method,
                  note: note.text,
                  reason: reason.text,
                );
              }
              if (context.mounted) Navigator.pop(context, changed);
            } catch (failure) {
              if (!context.mounted) return;
              setState(() {
                saving = false;
                error = switch (failure) {
                  ArgumentError() =>
                    failure.message?.toString() ??
                        'Input pembayaran tidak valid.',
                  StateError() => failure.message,
                  _ => 'Pembayaran gagal disimpan.',
                };
              });
            }
          }

          return AlertDialog(
            scrollable: true,
            title: Text(
              cancel
                  ? 'Batalkan Pembayaran'
                  : row == null
                  ? 'Tambah Pembayaran'
                  : 'Edit Pembayaran',
            ),
            content: SizedBox(
              width: 390,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (cancel)
                    TransactionDialogSection(
                      child: Text(
                        'Batalkan cicilan ${row!.urutanPembayaran} sebesar ${_amountLabel(row)}? Riwayat tetap tersimpan.',
                      ),
                    )
                  else ...[
                    TextField(
                      controller: amount,
                      enabled: !saving,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Nominal (Rp)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: method,
                      decoration: const InputDecoration(
                        labelText: 'Metode Pembayaran',
                      ),
                      items: [
                        for (final item in {
                          'Cash',
                          'Transfer',
                          'Debit',
                          'Kredit',
                          'QRIS',
                          'Lainnya',
                          initialMethod,
                        })
                          DropdownMenuItem(value: item, child: Text(item)),
                      ],
                      onChanged: saving
                          ? null
                          : (value) => setState(() => method = value ?? method),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: saving
                          ? null
                          : () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: date,
                                firstDate: DateTime(1),
                                lastDate: DateTime(9999, 12, 31),
                                helpText: 'Tanggal Pembayaran',
                                cancelText: 'Batal',
                                confirmText: 'Pilih',
                              );
                              if (picked != null && context.mounted) {
                                setState(() => date = picked);
                              }
                            },
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(formatPaymentDate(date)),
                    ),
                    TextField(
                      controller: note,
                      enabled: !saving,
                      decoration: const InputDecoration(
                        labelText: 'Keterangan',
                      ),
                    ),
                  ],
                  if (row != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TextField(
                        controller: reason,
                        enabled: !saving,
                        decoration: const InputDecoration(labelText: 'Alasan'),
                      ),
                    ),
                  if (error case final message?)
                    Text(
                      message,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.maybePop(context),
                child: const Text('Tutup'),
              ),
              FilledButton(
                onPressed: saving ? null : save,
                style: cancel
                    ? FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                      )
                    : null,
                child: Text(cancel ? 'Konfirmasi Pembatalan' : 'Simpan'),
              ),
            ],
          );
        },
      ),
    );
    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cancel ? 'Pembayaran dibatalkan.' : 'Pembayaran disimpan.',
          ),
        ),
      );
    }
  } finally {
    amount.dispose();
    note.dispose();
    reason.dispose();
  }
}
