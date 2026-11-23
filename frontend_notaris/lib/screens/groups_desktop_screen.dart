import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/widgets/edit_dialog.dart';
import '../core/widgets/master_data_viewport.dart';
import '../core/widgets/promotional_preview.dart';
import '../core/widgets/transaction_review_dialog.dart';
import '../providers/auth_provider.dart';
import '../providers/groups_provider.dart';
import '../providers/pekerjaan_provider.dart' show groupApiServiceProvider;
import '../services/group_api_service.dart';
import '../widgets/group_access_dialog.dart';

class GroupsDesktopScreen extends ConsumerStatefulWidget {
  const GroupsDesktopScreen({super.key});
  @override
  ConsumerState<GroupsDesktopScreen> createState() => _GroupsState();
}

class _GroupsState extends ConsumerState<GroupsDesktopScreen> {
  final search = TextEditingController(),
      horizontal = ScrollController(),
      vertical = ScrollController();
  int page = 1;
  int? status = 1;
  String? kind;
  String text = '';
  bool dialog = false, fetching = false;
  GroupsQuery get query =>
      (page: page, search: text, kind: kind, status: status);
  void refresh({bool first = false}) {
    if (first) setState(() => page = 1);
    ref.invalidate(groupsPageProvider(query));
  }

  @override
  void dispose() {
    search.dispose();
    horizontal.dispose();
    vertical.dispose();
    super.dispose();
  }

  Future<void> open(String mode, [GroupApiModel? record]) async {
    final action = mode == 'create'
        ? 'create'
        : mode == 'deactivate'
        ? 'delete'
        : 'update';
    if (dialog ||
        !allowsGroups(ref.read(authControllerProvider).session, action) ||
        (record != null && !record.editable)) {
      return;
    }
    setState(() {
      dialog = true;
      fetching = true;
    });
    try {
      // Always obtain the current revision/member snapshot before confirmation.
      final current = record == null
          ? null
          : await ref.read(groupApiServiceProvider).get(record.id);
      if (!mounted) return;
      if (current != null && !current.editable) {
        refresh();
        return;
      }
      setState(() => fetching = false);
      var dirty = false, busy = false;
      final committed = mode == 'access'
          ? await showGroupAccessDialog(context, current!.id)
          : await showEditDialog<bool>(
              context: context,
              dirty: () => dirty,
              saving: () => busy,
              discardBackgroundColor: Colors.white,
              builder: (_) => _GroupEditor(
                mode: mode,
                record: current,
                activity: (d, b) {
                  dirty = d;
                  busy = b;
                },
              ),
            );
      if (!mounted) return;
      refresh(first: true);
      if (committed == true) {
        if (mode == 'access') {
          try {
            await ref
                .read(authControllerProvider.notifier)
                .refreshCurrentPermissions();
          } catch (_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Akses tersimpan di server; muat ulang izin sesi belum berhasil.',
                ),
              ),
            );
            return;
          }
          if (!mounted) return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perubahan Groups dikonfirmasi oleh server.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(groupsError(e))));
      }
    } finally {
      if (mounted) {
        setState(() {
          dialog = false;
          fetching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (context.dependOnInheritedWidgetOfExactType<PromotionalPreview>() !=
        null) {
      return const Padding(
        padding: EdgeInsets.all(28),
        child: Text(
          'Groups V1 tidak diaktifkan pada profil promosi baca saja.',
        ),
      );
    }
    final session = ref.watch(authControllerProvider).session;
    if (!allowsGroups(session, 'read')) {
      return const Padding(
        padding: EdgeInsets.all(28),
        child: Text(
          'Groups memerlukan sesi Superadmin online yang valid dan izin baca Groups. Administrasi offline tidak tersedia.',
        ),
      );
    }
    final result = ref.watch(groupsPageProvider(query));
    return MasterDataViewport(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Groups',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'System > Groups · Administrasi online',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed:
                    result is AsyncData<GroupsPage> &&
                        allowsGroups(session, 'create') &&
                        !dialog
                    ? () => open('create')
                    : null,
                icon: const Icon(Icons.group_add_outlined),
                label: const Text('Tambah Grup'),
              ),
              OutlinedButton.icon(
                onPressed: dialog ? null : () => refresh(),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
              if (fetching)
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: 280,
                        child: TextField(
                          key: const Key('groups-search'),
                          controller: search,
                          onSubmitted: (s) => setState(() {
                            text = s;
                            page = 1;
                          }),
                          decoration: InputDecoration(
                            labelText: 'Cari nama grup',
                            suffixIcon: IconButton(
                              tooltip: 'Cari Groups',
                              onPressed: () => setState(() {
                                text = search.text;
                                page = 1;
                              }),
                              icon: const Icon(Icons.search),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: DropdownButtonFormField<String>(
                          key: const Key('groups-kind'),
                          initialValue: kind,
                          decoration: const InputDecoration(labelText: 'Jenis'),
                          items: const [
                            DropdownMenuItem<String>(
                              value: null,
                              child: Text('Semua Jenis'),
                            ),
                            DropdownMenuItem(
                              value: 'user',
                              child: Text('Biasa'),
                            ),
                            DropdownMenuItem(
                              value: 'superadmin',
                              child: Text('Superadmin'),
                            ),
                          ],
                          onChanged: dialog
                              ? null
                              : (v) => setState(() {
                                  kind = v;
                                  page = 1;
                                }),
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: DropdownButtonFormField<int>(
                          key: const Key('groups-status'),
                          initialValue: status,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                          ),
                          items: const [
                            DropdownMenuItem<int>(
                              value: null,
                              child: Text('Semua Status'),
                            ),
                            DropdownMenuItem(value: 1, child: Text('Aktif')),
                            DropdownMenuItem(value: 0, child: Text('Nonaktif')),
                          ],
                          onChanged: dialog
                              ? null
                              : (v) => setState(() {
                                  status = v;
                                  page = 1;
                                }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: result.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(
                        child: Text(
                          groupsError(e),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      data: (d) {
                        if (d.items.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.groups_outlined, size: 32),
                                const Text('Tidak ada grup yang cocok.'),
                                if (page > 1)
                                  TextButton(
                                    onPressed: () => setState(() => page = 1),
                                    child: const Text('Halaman pertama'),
                                  ),
                              ],
                            ),
                          );
                        }
                        return MasterDataTableViewport(
                          horizontalController: horizontal,
                          verticalController: vertical,
                          child: DataTable(
                            headingRowColor: const WidgetStatePropertyAll(
                              Color(0xfff2f3f5),
                            ),
                            columnSpacing: 24,
                            columns: [
                              for (final label in [
                                'No.',
                                'Nama Grup',
                                'Jenis',
                                'Jumlah Anggota Aktif',
                                'Status',
                                'Aksi',
                              ])
                                DataColumn(
                                  label: Text(label),
                                  numeric:
                                      label == 'No.' ||
                                      label == 'Jumlah Anggota Aktif',
                                ),
                            ],
                            rows: [
                              for (final (i, r) in d.items.indexed)
                                DataRow(
                                  key: ValueKey('group-${r.id}'),
                                  cells: [
                                    DataCell(
                                      Center(
                                        child: Text(
                                          '${(page - 1) * 10 + i + 1}',
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 210,
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              r.groupNama,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              'ID ${r.id} · revisi ${r.revision}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        r.protected
                                            ? 'Superadmin · Terproteksi'
                                            : 'Biasa',
                                      ),
                                    ),
                                    DataCell(
                                      Center(
                                        child: Tooltip(
                                          message:
                                              '${r.totalMembers} anggota total',
                                          child: Text('${r.activeMembers}'),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Center(
                                        child: TransactionReviewBadge(
                                          r.status == 1 ? 'Aktif' : 'Nonaktif',
                                          color: r.status == 1
                                              ? AppColors.success
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      r.protected
                                          ? const Text('Hanya baca')
                                          : r.status == 0
                                          ? const Text('Nonaktif')
                                          : Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (allowsGroups(
                                                  session,
                                                  'update',
                                                ))
                                                  IconButton(
                                                    tooltip:
                                                        'Atur Akses ${r.groupNama}',
                                                    onPressed: !dialog
                                                        ? () =>
                                                              open('access', r)
                                                        : null,
                                                    icon: const Icon(
                                                      Icons
                                                          .admin_panel_settings_outlined,
                                                    ),
                                                  ),
                                                IconButton(
                                                  tooltip:
                                                      'Ubah nama ${r.groupNama}',
                                                  onPressed:
                                                      !dialog &&
                                                          allowsGroups(
                                                            session,
                                                            'update',
                                                          )
                                                      ? () => open('rename', r)
                                                      : null,
                                                  icon: const Icon(
                                                    Icons.edit_outlined,
                                                  ),
                                                ),
                                                IconButton(
                                                  tooltip:
                                                      'Nonaktifkan ${r.groupNama}',
                                                  onPressed:
                                                      !dialog &&
                                                          allowsGroups(
                                                            session,
                                                            'delete',
                                                          )
                                                      ? () => open(
                                                          'deactivate',
                                                          r,
                                                        )
                                                      : null,
                                                  icon: const Icon(
                                                    Icons.group_off_outlined,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  result.maybeWhen(
                    data: (d) => Wrap(
                      spacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${d.total} grup · Halaman $page / ${d.total == 0 ? 1 : (d.total / 10).ceil()}',
                        ),
                        IconButton(
                          tooltip: 'Halaman sebelumnya',
                          onPressed: page > 1 && !dialog
                              ? () => setState(() => page--)
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        IconButton(
                          tooltip: 'Halaman berikutnya',
                          onPressed: page * 10 < d.total && !dialog
                              ? () => setState(() => page++)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                  const Text(
                    'Izin Sidebar dikelola terpisah. Grup baru tidak otomatis memperoleh akses.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupEditor extends ConsumerStatefulWidget {
  const _GroupEditor({
    required this.mode,
    required this.record,
    required this.activity,
  });
  final String mode;
  final GroupApiModel? record;
  final void Function(bool, bool) activity;
  @override
  ConsumerState<_GroupEditor> createState() => _GroupEditorState();
}

class _GroupEditorState extends ConsumerState<_GroupEditor> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  GroupApiModel? current, latest;
  bool saving = false,
      dirty = false,
      conflict = false,
      uncertain = false,
      confirmed = false;
  String? error;
  @override
  void initState() {
    super.initState();
    current = widget.record;
    name.text = current?.groupNama ?? '';
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  String get action => widget.mode == 'create'
      ? 'create'
      : widget.mode == 'deactivate'
      ? 'delete'
      : 'update';
  String get title => widget.mode == 'create'
      ? 'Tambah Grup'
      : widget.mode == 'deactivate'
      ? 'Nonaktifkan Grup'
      : 'Ubah Nama Grup';
  bool get eligible => current == null || current!.editable;
  void changed() {
    dirty = true;
    widget.activity(true, saving);
  }

  Future<void> save() async {
    if (saving ||
        conflict ||
        uncertain ||
        !eligible ||
        !allowsGroups(ref.read(authControllerProvider).session, action) ||
        !form.currentState!.validate() ||
        (widget.mode == 'deactivate' && !confirmed)) {
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    widget.activity(dirty, true);
    final api = ref.read(groupApiServiceProvider);
    try {
      if (widget.mode == 'create') {
        await api.create(groupNama: name.text);
      } else if (widget.mode == 'rename') {
        await api.rename(current!, name: name.text);
      } else {
        await api.deactivate(current!);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      // A malformed success body is also ambiguous: never offer a blind resubmit.
      uncertain =
          e is! DioException ||
          e.response == null ||
          (e.response?.statusCode ?? 0) >= 500;
      if (e is DioException &&
          e.response?.statusCode == 409 &&
          current != null) {
        conflict = true;
        try {
          latest = await api.get(current!.id);
        } catch (_) {
          /* Remain blocked. */
        }
      }
      if (mounted) setState(() => error = groupsError(e));
    } finally {
      saving = false;
      widget.activity(dirty, false);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final authorized = allowsGroups(
      ref.watch(authControllerProvider).session,
      action,
    );
    return TransactionReviewDialog(
      title: title,
      subtitle: current == null
          ? 'Grup biasa · PostgreSQL online'
          : '${current!.groupNama} · ID ${current!.id} · revisi ${current!.revision}',
      width: 560,
      canClose: !saving,
      onClose: () => cancelEditDialog(context),
      body: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.mode != 'deactivate')
              TextFormField(
                key: const Key('group-name'),
                controller: name,
                enabled: !saving,
                onChanged: (_) => changed(),
                decoration: const InputDecoration(
                  labelText: 'Nama grup',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ||
                        utf8.encode(v!.trim()).length > 160
                    ? 'Wajib diisi, maksimal 160 byte.'
                    : null,
              ),
            const SizedBox(height: 12),
            if (widget.mode == 'create')
              const Text(
                'Jenis: Biasa. Grup baru aktif tanpa anggota dan tanpa izin Sidebar otomatis.',
              ),
            if (widget.mode == 'rename')
              const Text(
                'Hanya nama yang diubah. Keanggotaan, izin dan status tetap.',
              ),
            if (widget.mode == 'deactivate') ...[
              Text(
                'Nonaktifkan ${current!.groupNama} (ID ${current!.id})? ${current!.activeMembers} anggota aktif, ${current!.totalMembers} anggota total.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Menonaktifkan grup akan membuat akun yang tergabung di dalamnya kehilangan akses melalui grup ini. Akun, keanggotaan dan riwayatnya tidak dihapus.',
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Saya mengonfirmasi dampak penonaktifan grup ini.',
                ),
                value: confirmed,
                onChanged: saving
                    ? null
                    : (v) {
                        setState(() => confirmed = v == true);
                        changed();
                      },
              ),
            ],
            if (!authorized || !eligible)
              const Text('Sesi, izin atau target tidak mengizinkan perubahan.'),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  error!,
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            if (uncertain)
              const Text(
                'Hasil operasi belum terkonfirmasi. Tutup form, Refresh dan periksa data server sebelum tindakan baru.',
              ),
            if (conflict) ...[
              const Text(
                'Input tidak dikirim ulang. Tinjau data server sebelum tindakan baru.',
              ),
              if (latest != null)
                TextButton(
                  onPressed: saving
                      ? null
                      : () {
                          setState(() {
                            current = latest;
                            latest = null;
                            name.text = current!.groupNama;
                            confirmed = false;
                            conflict = false;
                            dirty = false;
                            error = null;
                          });
                          widget.activity(false, false);
                        },
                  child: const Text('Gunakan data server terbaru'),
                ),
            ],
          ],
        ),
      ),
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: saving ? null : () => cancelEditDialog(context),
            child: const Text('Batal'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed:
                saving ||
                    conflict ||
                    uncertain ||
                    !authorized ||
                    !eligible ||
                    (widget.mode == 'deactivate' && !confirmed)
                ? null
                : save,
            child: saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    widget.mode == 'deactivate' ? 'Nonaktifkan Grup' : 'Simpan',
                  ),
          ),
        ],
      ),
    );
  }
}
