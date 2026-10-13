import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../providers/transaksi_proses_provider.dart';
import '../repositories/transaksi_proses_repository.dart';

/// Legacy snapshot item used while a transaction is still a local form draft.
class TransaksiProsesFallbackItem {
  const TransaksiProsesFallbackItem({
    required this.name,
    required this.status,
  });

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
    super.key,
  });

  final int? transactionId;
  final String detailUuid;
  final List<TransaksiProsesFallbackItem> fallbackProcesses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = transactionId;
    if (id == null) {
      return _buildFallbackProcesses();
    }

    final provider = transaksiProsesByTransactionProvider(id);
    final processesAsync = ref.watch(provider);

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

        return ListView.separated(
          itemCount: processes.length,
          separatorBuilder: (_, _) => const Divider(
            height: 1,
            color: AppColors.divider,
          ),
          itemBuilder: (context, index) {
            final process = processes[index];
            return _ProcessRow(
              index: index,
              name: process.namaProsesSnapshot,
              status: _statusLabel(process.statusProses),
            );
          },
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
      separatorBuilder: (_, _) => const Divider(
        height: 1,
        color: AppColors.divider,
      ),
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
      ProcessValidationStatus.belumDikerjakan => 'Belum Dikerjakan',
      ProcessValidationStatus.dalamPengerjaan => 'Dalam Pengerjaan',
      ProcessValidationStatus.menungguValidasi => 'Menunggu Validasi',
      ProcessValidationStatus.valid => 'Valid',
      ProcessValidationStatus.perluRevisi => 'Perlu Revisi',
      _ => status,
    };
  }
}

class _ProcessRow extends StatelessWidget {
  const _ProcessRow({
    required this.index,
    required this.name,
    required this.status,
  });

  final int index;
  final String name;
  final String status;

  @override
  Widget build(BuildContext context) {
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
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13,
        ),
      ),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 160),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.selectedMenuBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              status,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
