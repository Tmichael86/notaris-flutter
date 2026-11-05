import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/petugas_manual_sync_provider.dart';

class PetugasManualSyncPanel extends ConsumerWidget {
  const PetugasManualSyncPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(petugasManualEnabledProvider)) {
      return const SizedBox.shrink();
    }
    final state = ref.watch(petugasManualControllerProvider);
    final busy = state.status == PetugasManualStatus.syncing;
    final ready = ref.watch(petugasManualReadyProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('DEV Petugas: ${state.status.name} — ${state.message}'),
          OutlinedButton(
            onPressed: busy
                ? null
                : () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Konfirmasi fixture testing'),
                        content: const Text(
                          'Hanya profil PostgreSQL/SQLite terisolasi. Konfirmasi pasangan fixture lokal dengan jenis kelamin server ID 2 dari manifest harness. Tidak mencocokkan nama atau ID lokal. Tidak berlaku untuk record lain.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('Batal'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Konfirmasi fixture'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await ref
                          .read(petugasManualControllerProvider.notifier)
                          .run(prepare: true);
                    }
                  },
            child: const Text('Siapkan fixture'),
          ),
          OutlinedButton.icon(
            key: const Key('petugas-manual-sync'),
            onPressed: busy || !ready
                ? null
                : () =>
                      ref.read(petugasManualControllerProvider.notifier).run(),
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(),
                  )
                : const Icon(Icons.sync),
            label: const Text('Sync Petugas manual'),
          ),
        ],
      ),
    );
  }
}
