import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/widgets/edit_dialog.dart';
import '../core/widgets/transaction_review_dialog.dart';
import '../providers/auth_provider.dart';
import '../providers/groups_provider.dart';
import '../providers/pekerjaan_provider.dart'
    show groupSidebarAccessApiServiceProvider;
import '../services/group_api_service.dart' show groupsError;
import '../services/group_sidebar_access_api_service.dart';

Future<bool?> showGroupAccessDialog(BuildContext context, int id) {
  bool dirty = false, saving = false;
  return showEditDialog<bool>(
    context: context,
    dirty: () => dirty,
    saving: () => saving,
    discardBackgroundColor: Colors.white,
    builder: (_) => GroupAccessDialog(
      groupId: id,
      activity: (d, s) {
        dirty = d;
        saving = s;
      },
    ),
  );
}

class GroupAccessDialog extends ConsumerStatefulWidget {
  const GroupAccessDialog({
    super.key,
    required this.groupId,
    required this.activity,
  });
  final int groupId;
  final void Function(bool, bool) activity;
  @override
  ConsumerState<GroupAccessDialog> createState() => _AccessState();
}

class _AccessState extends ConsumerState<GroupAccessDialog> {
  GroupAccessSnapshot? snapshot;
  final flags = <int, List<int>>{}, expanded = <int>{};
  bool loading = true,
      saving = false,
      dirty = false,
      conflict = false,
      uncertain = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final s = await ref
          .read(groupSidebarAccessApiServiceProvider)
          .getByGroup(widget.groupId);
      if (!mounted) return;
      setState(() {
        snapshot = s;
        flags.clear();
        expanded.clear();
        for (final r in s.entries) {
          flags[r.id] = List.of(r.flags);
          expanded.add(r.id);
        }
        dirty = false;
        conflict = false;
        uncertain = false;
      });
      widget.activity(false, false);
    } catch (e) {
      if (mounted) setState(() => error = groupsError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  bool get allowed =>
      allowsGroups(ref.read(authControllerProvider).session, 'update') &&
      snapshot?.editable == true &&
      !loading &&
      !saving &&
      !conflict &&
      !uncertain;
  void change(GroupAccessEntry row, int col, bool value) {
    if (!allowed || !row.editable) return;
    setState(() {
      flags[row.id]![col] = value ? 1 : 0;
      if (col > 0 && value) flags[row.id]![0] = 1;
      if (col == 0 && !value) flags[row.id] = [0, 0, 0, 0];
      dirty = true;
    });
    widget.activity(true, false);
  }

  List<(GroupAccessEntry, int)> visible() {
    final all = List<GroupAccessEntry>.of(snapshot!.entries)
      ..sort((a, b) {
        final n = a.order.compareTo(b.order);
        return n == 0 ? a.id.compareTo(b.id) : n;
      });
    final ids = all.map((r) => r.id).toSet(),
        visited = <int>{},
        hidden = <int>{};
    final out = <(GroupAccessEntry, int)>[];
    void walk(GroupAccessEntry row, int depth, bool shown) {
      final stack = [(row, depth, shown)];
      while (stack.isNotEmpty) {
        final (item, level, visible) = stack.removeLast();
        if (!visited.add(item.id)) continue;
        if (visible) {
          out.add((item, level));
        } else {
          hidden.add(item.id);
        }
        for (final child
            in all.where((r) => r.parent == item.id).toList().reversed) {
          stack.add((child, level + 1, visible && expanded.contains(item.id)));
        }
      }
    }

    for (final r in all.where(
      (r) => r.parent == null || r.parent == 0 || !ids.contains(r.parent),
    )) {
      walk(r, 0, true);
    }
    // Corrupt/cyclic/deep definitions are never silently dropped. Server marks
    // unsupported hierarchy read-only; flat fallback avoids recursive UI loops.
    for (final r in all) {
      if (!visited.contains(r.id) && !hidden.contains(r.id)) walk(r, 0, true);
    }
    return out;
  }

  bool descendant(GroupAccessEntry row, int parent) {
    final byId = {for (final r in snapshot!.entries) r.id: r};
    final seen = <int>{};
    var current = row;
    while (seen.add(current.id)) {
      if (current.id == parent) return true;
      final p = byId[current.parent];
      if (p == null) return false;
      current = p;
    }
    return false;
  }

  Future<void> save() async {
    if (!allowed || !dirty) return;
    setState(() {
      saving = true;
      error = null;
    });
    widget.activity(dirty, true);
    try {
      final s = snapshot!;
      await ref
          .read(groupSidebarAccessApiServiceProvider)
          .replaceForGroup(
            snapshot: s,
            access: [
              for (final r in s.entries.where((r) => r.editable))
                GroupSidebarAccessInput(
                  sidebarId: r.id,
                  read: flags[r.id]![0],
                  create: flags[r.id]![1],
                  update: flags[r.id]![2],
                  delete: flags[r.id]![3],
                ),
            ],
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          conflict =
              e is DioException && [404, 409].contains(e.response?.statusCode);
          uncertain =
              e is! DioException ||
              e.response == null ||
              (e.response?.statusCode ?? 0) >= 500;
          error = conflict
              ? 'Data grup atau katalog berubah di server. Edit lokal belum dikirim ulang.'
              : groupsError(e);
        });
      }
    } finally {
      saving = false;
      widget.activity(dirty, false);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authControllerProvider);
    final s = snapshot;
    final rows = s == null ? <(GroupAccessEntry, int)>[] : visible();
    return TransactionReviewDialog(
      title: s == null ? 'Atur Akses' : 'Atur Akses — ${s.name}',
      subtitle: s == null
          ? 'Memuat snapshot PostgreSQL'
          : 'ID ${s.id} · revisi ${s.revision} · ${s.activeMembers} anggota aktif · ${s.status == 1 ? 'Aktif' : 'Nonaktif'}',
      width: 920,
      canClose: !saving,
      onClose: () => cancelEditDialog(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Izin berlaku per menu. Parent hanya membantu pemilihan; tidak ada pewarisan izin. Melepas READ juga melepas CREATE/UPDATE/DELETE pada menu itu. Administrasi tetap memerlukan peran Superadmin. Navigasi perangkat lain memerlukan Muat Ulang Izin.',
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                error!,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          if (conflict)
            TextButton(
              onPressed: saving || loading ? null : load,
              child: const Text('Muat ulang dari server (buang edit lokal)'),
            ),
          if (uncertain)
            const Text(
              'Hasil belum terkonfirmasi. Tutup dan periksa data server sebelum tindakan baru. Tidak ada retry otomatis.',
            ),
          if (!loading && s != null) ...[
            if (!s.editable)
              const Text('Grup Superadmin atau nonaktif hanya dapat dibaca.'),
            if (dirty)
              const Text(
                'Perubahan belum disimpan',
                style: TextStyle(color: AppColors.warning),
              ),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Katalog belum memiliki menu. Tidak ada akses yang dapat diubah.',
                ),
              ),
            if (rows.isNotEmpty)
              LayoutBuilder(
                builder: (context, c) => Column(
                  children: [
                    Container(
                      color: const Color(0xfff2f3f5),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(left: 12),
                              child: Text('Menu'),
                            ),
                          ),
                          for (final label in [
                            'READ',
                            'CREATE',
                            'UPDATE',
                            'DELETE',
                          ])
                            SizedBox(
                              width: 72,
                              child: Center(
                                child: Text(
                                  label,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    for (final (r, depth) in rows)
                      Builder(
                        builder: (context) {
                          final children = s.entries.any(
                            (child) => child.parent == r.id && child.id != r.id,
                          );
                          final targets = rows
                              .map((v) => v.$1)
                              .where((v) => v.editable && descendant(v, r.id))
                              .toList();
                          final values = [
                            for (final v in targets) ...flags[v.id]!,
                          ];
                          final bool? selected =
                              values.isEmpty || values.every((v) => v == 0)
                              ? false
                              : values.every((v) => v == 1)
                              ? true
                              : null;
                          return Container(
                            key: ValueKey('access-row-${r.id}'),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: AppColors.border),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      left: (depth.clamp(0, 3) * 12).toDouble(),
                                    ),
                                    child: Row(
                                      children: [
                                        if (children)
                                          IconButton(
                                            tooltip: 'Buka/tutup ${r.name}',
                                            onPressed: saving
                                                ? null
                                                : () => setState(() {
                                                    if (!expanded.remove(
                                                      r.id,
                                                    )) {
                                                      expanded.add(r.id);
                                                    }
                                                  }),
                                            icon: Icon(
                                              expanded.contains(r.id)
                                                  ? Icons.expand_more
                                                  : Icons.chevron_right,
                                              size: 18,
                                            ),
                                          )
                                        else
                                          const SizedBox(width: 20),
                                        if (children)
                                          Checkbox(
                                            key: ValueKey(
                                              'access-bulk-${r.id}',
                                            ),
                                            tristate: true,
                                            semanticLabel:
                                                'Pilih semua izin pada baris terlihat di ${r.name}',
                                            value: selected,
                                            onChanged:
                                                allowed && targets.isNotEmpty
                                                ? (v) {
                                                    setState(() {
                                                      for (final t in targets) {
                                                        flags[t.id] =
                                                            List.filled(
                                                              4,
                                                              selected != true
                                                                  ? 1
                                                                  : 0,
                                                            );
                                                      }
                                                      dirty = true;
                                                    });
                                                    widget.activity(
                                                      true,
                                                      false,
                                                    );
                                                  }
                                                : null,
                                          ),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  r.name,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  '${r.code} · ID ${r.id}${r.route == '#' ? ' · wadah menu' : ''}',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                                ),
                                                if (!r.editable)
                                                  Text(
                                                    r.reason,
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      color: AppColors
                                                          .textSecondary,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                for (var col = 0; col < 4; col++)
                                  SizedBox(
                                    width: 72,
                                    child: Center(
                                      child: Checkbox(
                                        key: ValueKey('access-${r.id}-$col'),
                                        semanticLabel:
                                            '${['READ', 'CREATE', 'UPDATE', 'DELETE'][col]} ${r.name}',
                                        value: flags[r.id]![col] == 1,
                                        onChanged: allowed && r.editable
                                            ? (v) => change(r, col, v == true)
                                            : null,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              'Pemilihan semua hanya memengaruhi baris editable yang sedang terlihat pada cabang ini. Baris nonaktif/hanya baca dipertahankan server.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (s == null && !loading)
            TextButton(onPressed: load, child: const Text('Coba Muat Ulang')),
          TextButton(
            onPressed: saving ? null : () => cancelEditDialog(context),
            child: const Text('Batal'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: allowed && dirty ? save : null,
            child: saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Simpan Perubahan'),
          ),
        ],
      ),
    );
  }
}
