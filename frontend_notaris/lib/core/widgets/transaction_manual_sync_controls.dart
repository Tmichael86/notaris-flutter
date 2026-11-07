import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../../providers/development_smoke_provider.dart';
import '../../providers/transaction_manual_sync_provider.dart';
import '../../services/transaction_manual_sync_service.dart';

/// Presentation-only exclusions; the existing service remains authoritative.
String? manualUploadDisabledReason(TransactionSyncRecord record) {
  if (record.pending == 'acked') {
    return 'ACK tersimpan; tunggu verifikasi publication melalui Download.';
  }
  if (record.deleted) {
    return 'Record terhapus tidak dapat dipilih melalui modal ini.';
  }
  if (!record.dirty && record.childDirty == 0 && record.pending == null) {
    return 'Data bersih; tidak ada perubahan lokal untuk diupload.';
  }
  return null;
}

class TransactionManualSyncControls extends ConsumerStatefulWidget {
  const TransactionManualSyncControls({super.key, this.onClose});
  final VoidCallback? onClose;
  @override
  ConsumerState<TransactionManualSyncControls> createState() =>
      _ControlsState();
}

class _ControlsState extends ConsumerState<TransactionManualSyncControls> {
  String module = 'transaksi_notaris', direction = 'push', query = '';
  TransactionSyncRecord? selected, confirmation;
  bool confirming = false, closing = false;
  final _dialogFocus = FocusNode();
  @override
  void dispose() {
    _dialogFocus.dispose();
    super.dispose();
  }

  void dismiss() {
    if (ref.read(isolatedTransactionSyncControllerProvider).busy) return;
    if (confirming) {
      setState(() => confirming = false);
    } else {
      close();
    }
  }

  void close() {
    if (closing ||
        ref.read(isolatedTransactionSyncControllerProvider).busy ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    closing = true;
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> execute(TransactionSyncRecord? record) async {
    if (ref.read(isolatedTransactionSyncControllerProvider).busy) return;
    try {
      await ref
          .read(isolatedTransactionSyncControllerProvider.notifier)
          .execute(
            module: module,
            direction: direction == 'push'
                ? ManualSyncDirection.upload
                : ManualSyncDirection.download,
            record: record,
          );
    } finally {
      if (mounted) setState(() => confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(isolatedTransactionSyncConfigurationProvider);
    final smoke = ref.watch(developmentUiSmokeProvider);
    final outcome = ref.watch(isolatedTransactionSyncControllerProvider);
    final upload = direction == 'push';
    final choice = (
      module: module,
      direction: upload
          ? ManualSyncDirection.upload
          : ManualSyncDirection.download,
    );
    final eligibility = config != null && !smoke
        ? ref.watch(isolatedTransactionSyncEligibilityProvider(choice))
        : null;
    final records = config != null && !smoke && upload
        ? ref.watch(isolatedTransactionSyncRecordsProvider(module))
        : null;
    final rows = records?.asData?.value ?? <TransactionSyncRecord>[];
    final current = rows
        .where((r) => r.id == selected?.id && r.uuid == selected?.uuid)
        .firstOrNull;
    final locked = confirming || outcome.busy;
    final confirmingAtBuild = confirming;
    final ready =
        eligibility?.asData != null &&
        (!upload ||
            current != null && manualUploadDisabledReason(current) == null);
    final rejection = eligibility?.hasError == true
        ? transactionSyncUiMessage(
            eligibility!.error is ManualTransactionFailure
                ? (eligibility.error as ManualTransactionFailure).code
                : 'unknown',
          )
        : null;
    final visible = rows
        .where(
          (r) => '${r.number} ${r.uuid} ${r.summary}'.toLowerCase().contains(
            query.toLowerCase().trim(),
          ),
        )
        .toList();

    final disabledReason = smoke
        ? 'UI Smoke: seluruh sinkronisasi manual dinonaktifkan.'
        : config == null
        ? 'Profil normal: eksekusi manual tetap dinonaktifkan.'
        : rejection ??
              (eligibility?.isLoading == true
                  ? 'Memverifikasi profil, scope dan permission…'
                  : upload && current == null
                  ? 'Pilih satu transaksi lokal untuk melanjutkan.'
                  : current != null
                  ? manualUploadDisabledReason(current)
                  : null);
    final record = confirming ? confirmation : current;
    final selection = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('TINDAKAN'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                key: const Key('manual-sync-upload'),
                label: 'Upload',
                caption: 'Satu transaksi lokal',
                icon: Icons.upload_file_outlined,
                selected: upload,
                onTap: locked
                    ? null
                    : () => setState(() {
                        direction = 'push';
                        module = 'transaksi_notaris';
                        selected = null;
                        query = '';
                      }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionCard(
                key: const Key('manual-sync-download'),
                label: 'Download',
                caption: 'Feed gabungan',
                icon: Icons.download_outlined,
                selected: !upload,
                onTap: locked
                    ? null
                    : () => setState(() {
                        direction = 'pull';
                        module = 'transaksi';
                        selected = null;
                        query = '';
                      }),
              ),
            ),
          ],
        ),
        if (upload) ...[
          const SizedBox(height: 16),
          SegmentedButton<String>(
            key: const Key('manual-sync-module'),
            segments: const [
              ButtonSegment(value: 'transaksi_notaris', label: Text('Notaris')),
              ButtonSegment(value: 'transaksi_ppat', label: Text('PPAT')),
            ],
            selected: {module},
            onSelectionChanged: locked
                ? null
                : (v) => setState(() {
                    module = v.single;
                    selected = null;
                    query = '';
                  }),
          ),
          const SizedBox(height: 12),
          TextField(
            key: ValueKey('manual-sync-search-$module'),
            enabled: !locked,
            onChanged: (v) => setState(() => query = v),
            decoration: const InputDecoration(
              hintText: 'Cari nomor / identitas',
              prefixIcon: Icon(Icons.search, size: 20),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          if (config == null || smoke)
            const _Notice(
              icon: Icons.lock_outline,
              text: 'Pemilihan record dinonaktifkan pada profil ini.',
            )
          else
            records!.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _Notice(
                icon: Icons.error_outline,
                text: transactionSyncUiMessage(
                  e is ManualTransactionFailure ? e.code : 'unknown',
                ),
              ),
              data: (data) {
                if (data.isEmpty) {
                  return const _Notice(
                    icon: Icons.inventory_2_outlined,
                    text: 'Belum ada transaksi lokal untuk jenis ini. Tidak ada upload yang dijalankan.',
                  );
                }
                if (visible.isEmpty) {
                  return const _Notice(
                    icon: Icons.search_off,
                    text: 'Tidak ada transaksi sesuai pencarian.',
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${visible.length} dari ${data.length} record dimuat',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 210),
                      child: SingleChildScrollView(
                        child: RadioGroup<int>(
                          groupValue: current?.id,
                          onChanged: (id) {
                            if (locked || eligibility?.asData == null) return;
                            final r = rows.singleWhere((r) => r.id == id);
                            if (manualUploadDisabledReason(r) == null) {
                              setState(() => selected = r);
                            }
                          },
                          child: Column(
                            key: ValueKey('manual-sync-record-$module'),
                            children: [
                              for (final r in visible)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: current?.id == r.id
                                          ? AppColors.primaryDark
                                          : AppColors.border,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Material(
                                    color: current?.id == r.id
                                        ? AppColors.selectedMenuBg
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    child: RadioListTile<int>(
                                      key: ValueKey(
                                        'manual-sync-choice-${r.id}',
                                      ),
                                      value: r.id,
                                      enabled:
                                          !locked &&
                                          eligibility?.asData != null &&
                                          manualUploadDisabledReason(r) == null,
                                      dense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                      title: Text(
                                        r.number,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Text(
                                        manualUploadDisabledReason(r) ??
                                            r.summary,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color:
                                              manualUploadDisabledReason(r) ==
                                                  null
                                              ? AppColors.textSecondary
                                              : AppColors.warning,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ] else ...[
          const SizedBox(height: 16),
          const _Notice(
            icon: Icons.layers_outlined,
            text: 'Notaris + PPAT\nSeluruh event dibaca berurutan. Tidak ada pemilihan transaksi atau domain.',
          ),
        ],
      ],
    );
    final summary = Container(
      key: const Key('manual-sync-summary'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionLabel(confirming ? 'KONFIRMASI UPLOAD' : 'RINGKASAN OPERASI'),
          const SizedBox(height: 12),
          Icon(
            upload ? Icons.description_outlined : Icons.cloud_download_outlined,
            color: AppColors.primaryDark,
            size: 26,
          ),
          const SizedBox(height: 10),
          Text(
            upload
                ? record?.number ?? 'Belum ada transaksi dipilih'
                : 'Feed gabungan Notaris + PPAT',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 8),
          if (upload && record != null) ...[
            Text(record.summary, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            SelectableText(
              'UUID: ${record.uuid} • Local PK: ${record.id}',
              key: const Key('manual-sync-record-identity'),
              style: const TextStyle(fontSize: 11),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            upload
                ? confirming
                      ? 'Hanya record ini yang dikirim. Konfirmasi untuk melanjutkan upload.'
                      : 'Referensi, identitas dan izin diperiksa ulang sebelum pengiriman.'
                : 'Download menerima Transaksi Notaris dan PPAT; satu cursor bersama. Halaman feed dan cursor diterapkan atomik. Tidak ada upload record lokal.',
            style: const TextStyle(fontSize: 12, height: 1.5),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: _gold),
          ),
          Text(
            upload
                ? 'ACK belum membuktikan publication. Verifikasi melalui Download.'
                : 'Cursor hanya maju setelah seluruh halaman berhasil diterapkan.',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          if (disabledReason != null) ...[
            const SizedBox(height: 12),
            Text(
              disabledReason,
              key: const Key('manual-sync-guard-reason'),
              style: TextStyle(
                fontSize: 12,
                color: rejection == null
                    ? AppColors.textSecondary
                    : AppColors.error,
              ),
            ),
          ],
          if (confirming)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: outcome.busy
                    ? null
                    : () => setState(() => confirming = false),
                child: const Text('Batal'),
              ),
            ),
        ],
      ),
    );
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme
            .copyWith(primary: AppColors.primaryDark),
      ),
      child: PopScope(
        canPop: !outcome.busy,
        child: CallbackShortcuts(
          bindings: {const SingleActivator(LogicalKeyboardKey.escape): dismiss},
          child: Focus(
            focusNode: _dialogFocus,
            autofocus: true,
            child: Dialog(
              key: const Key('manual-sync-dialog'),
              insetPadding: const EdgeInsets.all(24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              backgroundColor: AppColors.card,
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                key: const Key('manual-sync-surface'),
                width: 720,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: math.max(
                      0,
                      MediaQuery.sizeOf(context).height - 48,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 12, 16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.selectedMenuBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.inventory_2_outlined,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Pusat Sinkronisasi',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'MY NOTARIS · Administrasi Notaris & PPAT',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              key: const Key('close-manual-sync'),
                              tooltip: 'Tutup',
                              onPressed: outcome.busy ? null : close,
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: _gold),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const _ConnectionFlow(),
                              const SizedBox(height: 18),
                              if (outcome.message.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      '${outcome.operationLabel}: ${outcome.message}',
                                      key: const Key('manual-sync-feedback'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: outcome.errorCode == null
                                            ? AppColors.textPrimary
                                            : AppColors.error,
                                      ),
                                    ),
                                  ),
                                ),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final left = Visibility(
                                    visible: !confirming,
                                    maintainState: true,
                                    child: selection,
                                  );
                                  final wide =
                                      constraints.maxWidth >= 600 &&
                                      !confirming;
                                  final leftWidth = wide
                                      ? (constraints.maxWidth - 20) * 6 / 11
                                      : constraints.maxWidth;
                                  return Wrap(
                                    key: const Key('manual-sync-columns'),
                                    spacing: confirming ? 0 : 20,
                                    runSpacing: 16,
                                    children: [
                                      SizedBox(
                                        width: confirming ? 0 : leftWidth,
                                        child: left,
                                      ),
                                      SizedBox(
                                        width: wide
                                            ? constraints.maxWidth -
                                                  leftWidth -
                                                  20
                                            : constraints.maxWidth,
                                        child: summary,
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 16,
                          runSpacing: 8,
                          children: [
                            const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.shield_outlined,
                                  size: 15,
                                  color: AppColors.textSecondary,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Sinkronisasi terkontrol',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            FilledButton(
                              key: const Key('manual-sync-execute'),
                              onPressed:
                                  outcome.busy ||
                                      smoke ||
                                      config == null ||
                                      (!confirming && !ready)
                                  ? null
                                  : () {
                                      if (ref
                                              .read(
                                                isolatedTransactionSyncControllerProvider,
                                              )
                                              .busy ||
                                          confirming != confirmingAtBuild) {
                                        return;
                                      }
                                      if (confirming) {
                                        execute(confirmation);
                                      } else if (upload) {
                                        setState(() {
                                          confirmation = current;
                                          confirming = true;
                                        });
                                        _dialogFocus.requestFocus();
                                      } else {
                                        execute(null);
                                      }
                                    },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                child: outcome.busy
                                    ? const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Text('Menyinkronkan…'),
                                        ],
                                      )
                                    : confirming
                                    ? const Text(
                                        'Konfirmasi upload',
                                        key: Key('confirm-transaction-upload'),
                                      )
                                    : Text(
                                        upload
                                            ? 'Mulai Upload'
                                            : 'Mulai Download',
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _gold = Color(0xFFE3D9C3);

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 10,
      letterSpacing: 1,
      fontWeight: FontWeight.w700,
      color: AppColors.textSecondary,
    ),
  );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    super.key,
    required this.label,
    required this.caption,
    required this.icon,
    required this.selected,
    this.onTap,
  });
  final String label, caption;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: selected ? AppColors.selectedMenuBg : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected ? AppColors.primaryDark : AppColors.border,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: selected
                    ? AppColors.primaryDark
                    : AppColors.textSecondary,
                size: 22,
              ),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(
                caption,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      children: [
        Icon(icon, color: AppColors.textMuted, size: 22),
        const SizedBox(height: 8),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    ),
  );
}

class _ConnectionFlow extends StatelessWidget {
  const _ConnectionFlow();
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          for (final step in [
            (Icons.computer_outlined, 'Perangkat'),
            (Icons.dns_outlined, 'Server'),
            (Icons.fact_check_outlined, 'Verifikasi'),
          ]) ...[
            if (step.$2 != 'Perangkat')
              const Icon(Icons.arrow_forward, size: 14, color: _gold),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(step.$1, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      step.$2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: 6),
      const Text(
        'Alur operasi · bukan indikator koneksi online',
        style: TextStyle(fontSize: 10, color: AppColors.textMuted),
      ),
    ],
  );
}
