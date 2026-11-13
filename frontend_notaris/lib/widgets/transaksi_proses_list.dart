import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/widgets/transaction_review_dialog.dart';
import '../database/app_database.dart';
import '../providers/auth_provider.dart';
import '../providers/transaksi_proses_provider.dart';
import '../repositories/transaksi_proses_repository.dart';
import '../services/attribute_workflow.dart';
import 'attribute_workflow_dialog.dart';

/// Legacy snapshot item used while a transaction is still a local form draft.
class TransaksiProsesFallbackItem {
  const TransaksiProsesFallbackItem({required this.name, required this.status});

  final String name;
  final String status;
}

/// Shows the selected job's persisted process workflow when the transaction
/// exists, and the form snapshot for a transaction that has not been saved yet.
class TransaksiProsesList extends ConsumerWidget {
  const TransaksiProsesList({
    required this.transactionId,
    required this.detailUuid,
    required this.fallbackProcesses,
    this.embedded = false,
    this.allowDirectValidation = false,
    super.key,
  });

  final int? transactionId;
  final String detailUuid;
  final List<TransaksiProsesFallbackItem> fallbackProcesses;
  final bool embedded;
  final bool allowDirectValidation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = transactionId;
    if (id == null) {
      return _buildFallbackProcesses();
    }

    final provider = transaksiProsesByTransactionProvider(id);
    final processesAsync = ref.watch(provider);
    final canValidate =
        !embedded &&
        allowDirectValidation &&
        TransaksiProsesRepository.canValidate(
          ref.watch(authControllerProvider).session,
        );

    return processesAsync.when(
      loading: () => const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
      error: (error, stackTrace) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: AppColors.textSecondary,
              size: 32,
            ),
            const SizedBox(height: 8),
            const Text(
              'Gagal memuat daftar proses.',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => ref.invalidate(provider),
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
      data: (allProcesses) {
        final workflowEnabled =
            !embedded && ref.watch(attributeWorkflowProvider) != null;
        final processes = allProcesses
            .where((process) => process.transaksiDetailUuid == detailUuid)
            .toList();

        if (processes.isEmpty) {
          return const Center(
            child: Text(
              'Belum ada proses tersimpan untuk pekerjaan ini.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        Widget row(int index) {
          final process = processes[index];
          return _ProcessRow(
            index: index,
            name: process.namaProsesSnapshot,
            status: _statusLabel(process.statusProses),
            embedded: embedded,
            badgeColor: _reviewColor(process.statusProses),
            onValidate: canValidate
                ? () => showDialog<void>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => _ProcessValidationDialog(process: process),
                  )
                : null,
            onWorkflow: workflowEnabled
                ? () => showAttributeWorkflow(context, ref, process.uuid)
                : null,
          );
        }

        if (embedded) {
          return Column(
            children: [
              for (var index = 0; index < processes.length; index++) ...[
                if (index > 0)
                  const Divider(height: 1, color: AppColors.divider),
                row(index),
              ],
            ],
          );
        }
        return ListView.separated(
          itemCount: processes.length,
          separatorBuilder: (_, _) =>
              const Divider(height: 1, color: AppColors.divider),
          itemBuilder: (_, index) => row(index),
        );
      },
    );
  }

  Widget _buildFallbackProcesses() {
    if (fallbackProcesses.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada proses pada pekerjaan ini.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.separated(
      itemCount: fallbackProcesses.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: AppColors.divider),
      itemBuilder: (context, index) {
        final process = fallbackProcesses[index];
        return _ProcessRow(
          index: index,
          name: process.name,
          status: process.status,
        );
      },
    );
  }

  static String _statusLabel(String? status) {
    return switch (status) {
      null => 'Belum Diinisialisasi',
      ProcessValidationStatus.belumValid => 'Belum Valid',
      ProcessValidationStatus.belumDikerjakan => 'Belum Dikerjakan',
      ProcessValidationStatus.dalamPengerjaan => 'Dalam Pengerjaan',
      ProcessValidationStatus.menungguValidasi => 'Menunggu Validasi',
      ProcessValidationStatus.valid => 'Valid',
      ProcessValidationStatus.perluRevisi => 'Perlu Revisi',
      _ => status,
    };
  }

  static Color _reviewColor(String? status) => switch (status) {
    ProcessValidationStatus.valid => Colors.green.shade800,
    ProcessValidationStatus.belumValid => Colors.amber.shade900,
    ProcessValidationStatus.dalamPengerjaan ||
    ProcessValidationStatus.menungguValidasi => Colors.orange.shade900,
    ProcessValidationStatus.perluRevisi => AppColors.primaryDark,
    _ => AppColors.textSecondary,
  };
}

class _ProcessRow extends StatelessWidget {
  const _ProcessRow({
    required this.index,
    required this.name,
    required this.status,
    this.embedded = false,
    this.badgeColor = AppColors.textSecondary,
    this.onValidate,
    this.onWorkflow,
  });

  final int index;
  final String name;
  final String status;
  final bool embedded;
  final Color badgeColor;
  final VoidCallback? onValidate;
  final VoidCallback? onWorkflow;

  @override
  Widget build(BuildContext context) {
    if (embedded) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: AppColors.bgLight,
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(name),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              flex: 2,
              child: TransactionReviewBadge(status, color: badgeColor),
            ),
          ],
        ),
      );
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 15,
        backgroundColor: AppColors.selectedMenuBg,
        child: Text(
          '${index + 1}',
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      title: Text(
        name,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
      ),
      subtitle: onValidate == null && onWorkflow == null
          ? null
          : Wrap(
              children: [
                if (onValidate != null)
                  TextButton(
                    onPressed: onValidate,
                    child: const Text('Detail Proses'),
                  ),
                if (onWorkflow != null)
                  TextButton(
                    onPressed: onWorkflow,
                    child: const Text('Validasi atribut'),
                  ),
              ],
            ),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 160),
        child: TransactionReviewBadge(status, color: badgeColor),
      ),
    );
  }
}

class _ProcessValidationDialog extends ConsumerStatefulWidget {
  const _ProcessValidationDialog({required this.process});

  final TransaksiProse process;

  @override
  ConsumerState<_ProcessValidationDialog> createState() =>
      _ProcessValidationDialogState();
}

class _ProcessValidationDialogState
    extends ConsumerState<_ProcessValidationDialog> {
  late TransaksiProse _process = widget.process;
  late String? _note = _process.catatan;
  late bool _valid = _process.statusProses == ProcessValidationStatus.valid;
  bool _saving = false;
  String? _error;

  Future<void> _save({required bool initialize}) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(transaksiProsesRepositoryProvider)
          .saveDirectValidation(
            session: ref.read(authControllerProvider).session,
            expected: _process,
            valid: initialize ? null : _valid,
            note: _note,
          );
      if (!mounted) return;
      if (initialize) {
        setState(() => _process = result);
      } else {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is StateError
              ? error.message
              : 'Gagal menyimpan validasi proses.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canValidate = TransaksiProsesRepository.canValidate(
      ref.watch(authControllerProvider).session,
    );
    final initialized = _process.statusProses != null;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        scrollable: true,
        backgroundColor: AppColors.card,
        title: const Text('Detail Proses'),
        content: SizedBox(
          width: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_process.namaProsesSnapshot),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _note,
                readOnly: !initialized || !canValidate || _saving,
                decoration: const InputDecoration(labelText: 'Catatan'),
                minLines: 2,
                maxLines: 4,
                onChanged: (value) => _note = value,
              ),
              const SizedBox(height: 8),
              if (initialized)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Validasi Proses'),
                  subtitle: Text(_valid ? 'Valid' : 'Belum Valid'),
                  value: _valid,
                  onChanged: _saving || !canValidate
                      ? null
                      : (value) => setState(() => _valid = value),
                )
              else
                const Text(
                  'Belum Diinisialisasi. Inisialisasi sebelum mengubah validasi.',
                ),
              if (_error case final error?)
                Text(
                  error,
                  style: const TextStyle(color: AppColors.primaryDark),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: _saving || !canValidate
                ? null
                : () => _save(initialize: !initialized),
            child: Text(initialized ? 'Simpan' : 'Inisialisasi proses'),
          ),
        ],
      ),
    );
  }
}
