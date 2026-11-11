import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/widgets/edit_dialog.dart';
import '../database/app_database.dart';
import '../providers/auth_provider.dart';
import '../providers/transaction_provider.dart';
import '../repositories/transaction_repository.dart';

Future<void> showPpatCompletionDialog(
  BuildContext context,
  TransaksiDetail detail,
) async {
  final title = TextEditingController(text: detail.judulAktaPpat);
  final number = TextEditingController(text: detail.nomorAktaPpat);
  final initialDate = detail.tanggalAktaPpat?.toUtc();
  final initialStatus = PpatJobStatus.values.firstWhere(
    (value) => value.name == detail.statusPekerjaanPpat,
    orElse: () => PpatJobStatus.baru,
  );
  var date = initialDate;
  var status = initialStatus;
  var saving = false;
  String? error;

  String formatDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';
  String? optional(String value) => value.trim().isEmpty ? null : value.trim();

  try {
    await showEditDialog<void>(
      context: context,
      saving: () => saving,
      dirty: () =>
          status != initialStatus ||
          title.text != (detail.judulAktaPpat ?? '') ||
          number.text != (detail.nomorAktaPpat ?? '') ||
          date != initialDate,
      builder: (context) => Consumer(
        builder: (context, ref, _) => StatefulBuilder(
          builder: (context, setState) {
            final session = ref.watch(authControllerProvider).session;
            final canEdit = session?.hasTransactionAccess(update: true) == true;
            final canRead = session?.hasTransactionAccess() == true;
            final complete = status == PpatJobStatus.selesai;
            final canEditDeed = canEdit && complete && !saving;

            Future<void> pickDate() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date ?? DateTime.now(),
                firstDate: DateTime(1),
                lastDate: DateTime(9999, 12, 31),
                helpText: 'Pilih tanggal akta',
                cancelText: 'Batal',
                confirmText: 'Pilih',
              );
              if (picked != null && context.mounted) {
                setState(
                  () => date = DateTime.utc(
                    picked.year,
                    picked.month,
                    picked.day,
                  ),
                );
              }
            }

            Future<void> save() async {
              if (saving) return;
              setState(() {
                saving = true;
                error = null;
              });
              try {
                await ref
                    .read(transactionRepositoryProvider)
                    .savePpatJobStatus(
                      session: ref.read(authControllerProvider).session,
                      expected: detail,
                      status: status,
                      title: complete ? optional(title.text) : null,
                      number: complete ? optional(number.text) : null,
                      date: complete ? date : null,
                    );
                if (context.mounted) Navigator.pop(context);
              } catch (failure) {
                if (!context.mounted) return;
                setState(() {
                  saving = false;
                  error = failure is StateError
                      ? failure.message
                      : 'Status pekerjaan gagal disimpan.';
                });
              }
            }

            return AlertDialog(
              scrollable: true,
              title: const Text('Status PPAT'),
              content: SizedBox(
                width: 420,
                child: !canRead
                    ? const Text('Izin baca Transaksi diperlukan.')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(detail.namaPekerjaanSnapshot),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<PpatJobStatus>(
                            initialValue: status,
                            decoration: const InputDecoration(
                              labelText: 'Status Pekerjaan',
                            ),
                            items: [
                              for (final value in PpatJobStatus.values)
                                DropdownMenuItem(
                                  value: value,
                                  child: Text(value.label),
                                ),
                            ],
                            onChanged: !canEdit || saving
                                ? null
                                : (value) =>
                                      setState(() => status = value ?? status),
                          ),
                          if (complete ||
                              detail.judulAktaPpat != null ||
                              detail.nomorAktaPpat != null ||
                              initialDate != null) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: title,
                              readOnly: !canEditDeed,
                              decoration: const InputDecoration(
                                labelText: 'Judul Akta',
                              ),
                            ),
                            TextFormField(
                              controller: number,
                              readOnly: !canEditDeed,
                              decoration: const InputDecoration(
                                labelText: 'Nomor Akta',
                              ),
                            ),
                            InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Tanggal Akta',
                                suffixIcon: canEditDeed
                                    ? IconButton(
                                        tooltip: 'Pilih tanggal akta',
                                        onPressed: pickDate,
                                        icon: const Icon(
                                          Icons.calendar_month_outlined,
                                        ),
                                      )
                                    : null,
                              ),
                              child: Text(
                                date == null ? '—' : formatDate(date!),
                              ),
                            ),
                          ],
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
                if (canEdit)
                  FilledButton(
                    onPressed: saving ? null : save,
                    child: const Text('Simpan'),
                  ),
              ],
            );
          },
        ),
      ),
    );
  } finally {
    title.dispose();
    number.dispose();
  }
}
