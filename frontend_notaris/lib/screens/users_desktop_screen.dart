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
import '../providers/pekerjaan_provider.dart' show userApiServiceProvider;
import '../providers/users_provider.dart';
import '../services/user_api_service.dart';

class UsersDesktopScreen extends ConsumerStatefulWidget {
  const UsersDesktopScreen({super.key});
  @override
  ConsumerState<UsersDesktopScreen> createState() => _UsersDesktopScreenState();
}

class _UsersDesktopScreenState extends ConsumerState<UsersDesktopScreen> {
  final _search = TextEditingController();
  final _horizontal = ScrollController(), _vertical = ScrollController();
  int _page = 1;
  int? _group, _status;
  String _query = '';
  bool _dialog = false, _fetching = false;
  List<UserGroupRef> _groups = [];
  UsersQuery get query =>
      (page: _page, search: _query, groupId: _group, status: _status);
  bool allows(String action) =>
      allowsUsers(ref.read(authControllerProvider).session, action);
  void refresh({bool first = false}) {
    if (first) setState(() => _page = 1);
    ref.invalidate(usersPageProvider(query));
  }

  @override
  void dispose() {
    _search.dispose();
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  Future<void> open(_Mode mode, [UserApiModel? row]) async {
    if (_dialog ||
        !allows(
          mode == _Mode.create
              ? 'create'
              : mode == _Mode.deactivate
              ? 'delete'
              : 'update',
        )) {
      return;
    }
    final session = ref.read(authControllerProvider).session;
    if (row != null && (!row.ordinary || row.id == session?.userId)) return;
    setState(() {
      _dialog = true;
      _fetching = true;
    });
    try {
      final api = ref.read(userApiServiceProvider);
      final groups = (mode == _Mode.create || mode == _Mode.edit)
          ? await api.assignableGroups()
          : <UserGroupRef>[];
      if (!mounted) return;
      setState(() => _fetching = false);
      var dirty = false, busy = false;
      final committed = await showEditDialog<bool>(
        context: context,
        dirty: () => dirty,
        saving: () => busy,
        discardBackgroundColor: Colors.white,
        builder: (context) => _UserEditor(
          mode: mode,
          record: row,
          groups: groups,
          activity: (d, b) {
            dirty = d;
            busy = b;
          },
        ),
      );
      if (!mounted) return;
      refresh(first: true);
      if (committed == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perubahan Users dikonfirmasi oleh server.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(usersError(error))));
      }
    } finally {
      if (mounted) {
        setState(() {
          _dialog = false;
          _fetching = false;
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
          'Users V1 tidak diaktifkan pada profil promosi baca saja. Tidak ada mutasi akun.',
        ),
      );
    }
    final session = ref.watch(authControllerProvider).session;
    if (!allowsUsers(session, 'read')) {
      return const Padding(
        padding: EdgeInsets.all(28),
        child: Text(
          'Users memerlukan sesi Superadmin online yang valid dan izin baca Users. Administrasi offline tidak tersedia.',
        ),
      );
    }
    final result = ref.watch(usersPageProvider(query));
    if (result.asData case final value?) {
      _groups = value.value.groups;
    }
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
                    'Users',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'System > Users · Administrasi online',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed:
                    result is AsyncData<UsersPage> &&
                        allows('create') &&
                        !_dialog
                    ? () => open(_Mode.create)
                    : null,
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Tambah User'),
              ),
              OutlinedButton.icon(
                onPressed: _dialog ? null : () => refresh(),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
              if (_fetching)
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(16),
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
                          key: const Key('users-search'),
                          controller: _search,
                          onSubmitted: (s) => setState(() {
                            _query = s;
                            _page = 1;
                          }),
                          decoration: InputDecoration(
                            labelText: 'Cari nama, username, email',
                            suffixIcon: IconButton(
                              tooltip: 'Cari Users',
                              onPressed: () => setState(() {
                                _query = _search.text;
                                _page = 1;
                              }),
                              icon: const Icon(Icons.search),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<int>(
                          key: const Key('users-group-filter'),
                          initialValue: _group,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Group'),
                          items: [
                            const DropdownMenuItem<int>(
                              value: null,
                              child: Text('Semua Group'),
                            ),
                            for (final g in _groups)
                              DropdownMenuItem(
                                value: g.id,
                                child: Text(
                                  g.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (v) => setState(() {
                            _group = v;
                            _page = 1;
                          }),
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: DropdownButtonFormField<int>(
                          initialValue: _status,
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
                          onChanged: (v) => setState(() {
                            _status = v;
                            _page = 1;
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
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(usersError(e), textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: () => refresh(),
                              child: const Text('Coba muat ulang'),
                            ),
                          ],
                        ),
                      ),
                      data: (data) {
                        if (data.items.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.people_outline,
                                  size: 32,
                                  color: AppColors.textSecondary,
                                ),
                                const Text('Tidak ada user yang cocok.'),
                                if (_page > 1)
                                  TextButton(
                                    onPressed: () => setState(() => _page = 1),
                                    child: const Text('Halaman pertama'),
                                  ),
                              ],
                            ),
                          );
                        }
                        return MasterDataTableViewport(
                          horizontalController: _horizontal,
                          verticalController: _vertical,
                          child: DataTable(
                            headingRowColor: const WidgetStatePropertyAll(
                              Color(0xfff2f3f5),
                            ),
                            columnSpacing: 20,
                            columns: [
                              for (final label in [
                                'No.',
                                'Nama',
                                'Username',
                                'Email',
                                'Group',
                                'Status',
                                'Aksi',
                              ])
                                DataColumn(label: Text(label)),
                            ],
                            rows: [
                              for (final (index, row) in data.items.indexed)
                                DataRow(
                                  key: ValueKey('user-${row.id}'),
                                  cells: [
                                    DataCell(
                                      Text('${(_page - 1) * 10 + index + 1}'),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 160,
                                        child: Text(
                                          row.nama,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 140,
                                        child: Text(
                                          row.username,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 200,
                                        child: Text(
                                          row.email,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 150,
                                        child: Text(
                                          row.groupNama ??
                                              'Group #${row.groupId}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      TransactionReviewBadge(
                                        row.status == 1 ? 'Aktif' : 'Nonaktif',
                                        color: row.status == 1
                                            ? AppColors.success
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                    DataCell(
                                      !row.ordinary || row.id == session!.userId
                                          ? const Text('Terproteksi')
                                          : Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  tooltip:
                                                      'Edit ${row.username}',
                                                  onPressed:
                                                      allows('update') &&
                                                          !_dialog
                                                      ? () => open(
                                                          _Mode.edit,
                                                          row,
                                                        )
                                                      : null,
                                                  icon: const Icon(
                                                    Icons.edit_outlined,
                                                  ),
                                                ),
                                                IconButton(
                                                  tooltip:
                                                      'Nonaktifkan ${row.username}',
                                                  onPressed:
                                                      allows('delete') &&
                                                          !_dialog &&
                                                          row.status == 1
                                                      ? () => open(
                                                          _Mode.deactivate,
                                                          row,
                                                        )
                                                      : null,
                                                  icon: const Icon(
                                                    Icons.person_off_outlined,
                                                  ),
                                                ),
                                                IconButton(
                                                  tooltip:
                                                      'Reset password ${row.username}',
                                                  onPressed:
                                                      allows('update') &&
                                                          !_dialog
                                                      ? () => open(
                                                          _Mode.reset,
                                                          row,
                                                        )
                                                      : null,
                                                  icon: const Icon(
                                                    Icons.lock_reset,
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
                  if (result.asData case final value?) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${value.value.total} user · Halaman $_page / ${((value.value.total + 9) ~/ 10).clamp(1, 1000000)}',
                        ),
                        OutlinedButton(
                          onPressed: _page > 1
                              ? () => setState(() => _page--)
                              : null,
                          child: const Text('Sebelumnya'),
                        ),
                        OutlinedButton(
                          onPressed: _page * 10 < value.value.total
                              ? () => setState(() => _page++)
                              : null,
                          child: const Text('Berikutnya'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _Mode { create, edit, deactivate, reset }

class _UserEditor extends ConsumerStatefulWidget {
  const _UserEditor({
    required this.mode,
    required this.record,
    required this.groups,
    required this.activity,
  });
  final _Mode mode;
  final UserApiModel? record;
  final List<UserGroupRef> groups;
  final void Function(bool, bool) activity;
  @override
  ConsumerState<_UserEditor> createState() => _UserEditorState();
}

class _UserEditorState extends ConsumerState<_UserEditor> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      username = TextEditingController(),
      email = TextEditingController(),
      phone = TextEditingController(),
      address = TextEditingController(),
      password = TextEditingController(),
      confirm = TextEditingController();
  UserApiModel? current, server;
  int? group;
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
    populate();
  }

  void populate() {
    name.text = current?.nama ?? '';
    username.text = current?.username ?? '';
    email.text = current?.email ?? '';
    phone.text = current?.noTelp ?? '';
    address.text = current?.alamat ?? '';
    group = widget.groups.any((g) => g.id == current?.groupId)
        ? current!.groupId
        : null;
    password.clear();
    confirm.clear();
  }

  @override
  void dispose() {
    for (final c in [
      name,
      username,
      email,
      phone,
      address,
      password,
      confirm,
    ]) {
      c.clear();
      c.dispose();
    }
    super.dispose();
  }

  void changed() {
    dirty = true;
    widget.activity(dirty, saving);
  }

  String get action => widget.mode == _Mode.create
      ? 'create'
      : widget.mode == _Mode.deactivate
      ? 'delete'
      : 'update';
  String get title => switch (widget.mode) {
    _Mode.create => 'Tambah User',
    _Mode.edit => 'Edit User',
    _Mode.deactivate => 'Nonaktifkan Akun',
    _Mode.reset => 'Reset Password',
  };
  Future<void> save() async {
    if (saving || conflict || uncertain || !form.currentState!.validate()) {
      return;
    }
    if (!allowsUsers(ref.read(authControllerProvider).session, action)) {
      setState(() => error = 'Sesi/izin tidak mengizinkan operasi ini.');
      return;
    }
    if (widget.mode != _Mode.create &&
        (current == null ||
            !current!.ordinary ||
            current!.id == ref.read(authControllerProvider).session?.userId)) {
      setState(() => error = 'Akun ini terproteksi.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    widget.activity(dirty, true);
    final api = ref.read(userApiServiceProvider);
    try {
      switch (widget.mode) {
        case _Mode.create:
          await api.create(
            groupId: group!,
            nama: name.text,
            username: username.text,
            email: email.text,
            noTelp: phone.text,
            alamat: address.text,
            password: password.text,
            passwordConfirm: confirm.text,
          );
        case _Mode.edit:
          await api.update(
            id: current!.id,
            expectedRevision: current!.revision,
            groupId: group!,
            nama: name.text,
            username: username.text,
            email: email.text,
            noTelp: phone.text,
            alamat: address.text,
          );
        case _Mode.deactivate:
          await api.deactivate(
            current!.id,
            expectedRevision: current!.revision,
          );
        case _Mode.reset:
          await api.resetPassword(
            current!.id,
            expectedRevision: current!.revision,
            password: password.text,
            passwordConfirm: confirm.text,
          );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (e is DioException &&
          (e.response == null || (e.response?.statusCode ?? 0) >= 500)) {
        uncertain = true;
      }
      UserApiModel? latest;
      if (e is DioException &&
          e.response?.statusCode == 409 &&
          current != null) {
        conflict = true;
        try {
          latest = await api.get(current!.id);
        } catch (_) {
          /* Keep mutation blocked until an explicit refresh. */
        }
      }
      if (mounted) {
        setState(() {
          error = usersError(e);
          server = latest;
        });
      }
    } finally {
      saving = false;
      widget.activity(dirty, false);
      if (mounted) setState(() {});
    }
  }

  Widget field(
    String label,
    TextEditingController controller, {
    String? Function(String?)? validator,
    bool secret = false,
  }) => TextFormField(
    controller: controller,
    enabled: !saving,
    obscureText: secret,
    autocorrect: !secret,
    enableSuggestions: !secret,
    onChanged: (_) => changed(),
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    validator: validator,
  );
  String? bounded(String? text, int max, {bool required = true}) {
    final value = text?.trim() ?? '';
    return (required && value.isEmpty) || utf8.encode(value).length > max
        ? 'Wajib diisi, maksimal $max byte.'
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final authorized = allowsUsers(
      ref.watch(authControllerProvider).session,
      action,
    );
    final targetAllowed =
        current == null ||
        (current!.ordinary &&
            current!.id != ref.read(authControllerProvider).session?.userId);
    final metadata = widget.mode == _Mode.create || widget.mode == _Mode.edit;
    final secret = widget.mode == _Mode.create || widget.mode == _Mode.reset;
    return TransactionReviewDialog(
      title: title,
      subtitle: current == null
          ? 'Akun biasa · PostgreSQL online'
          : '${current!.username} · ID ${current!.id} · revisi ${current!.revision}',
      canClose: !saving,
      onClose: () => cancelEditDialog(context),
      width: 580,
      body: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (metadata) ...[
              field('Nama', name, validator: (s) => bounded(s, 160)),
              const SizedBox(height: 12),
              field(
                'Username',
                username,
                validator: (s) =>
                    RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$')
                        .hasMatch(s?.trim() ?? '')
                    ? null
                    : 'Gunakan 1–64 huruf/angka, titik, garis atau underscore.',
              ),
              const SizedBox(height: 12),
              field(
                'Email',
                email,
                validator: (s) =>
                    bounded(s, 254) ??
                    (RegExp(r'^[^@\s]+@[^@\s]+$').hasMatch(s?.trim() ?? '')
                        ? null
                        : 'Email tidak valid.'),
              ),
              const SizedBox(height: 12),
              field(
                'Telepon',
                phone,
                validator: (s) => bounded(s, 32, required: false),
              ),
              const SizedBox(height: 12),
              field(
                'Alamat',
                address,
                validator: (s) => bounded(s, 1000, required: false),
              ),
              const SizedBox(height: 12),
              if (current != null)
                Text(
                  'Group saat ini: ${current!.groupNama ?? current!.groupId}. Status akun tetap ${current!.status == 1 ? 'aktif' : 'nonaktif'}.',
                ),
              DropdownButtonFormField<int>(
                key: ValueKey('user-form-group-${current?.revision}'),
                initialValue: group,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Group biasa aktif',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final g in widget.groups)
                    DropdownMenuItem(
                      value: g.id,
                      child: Text(g.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: saving
                    ? null
                    : (v) {
                        setState(() => group = v);
                        changed();
                      },
                validator: (v) =>
                    v == null ? 'Pilih group biasa yang aktif.' : null,
              ),
              const SizedBox(height: 12),
              const Text(
                'Group menentukan izin efektif. Perubahan group mencabut sesi lama; pengguna perlu login kembali.',
              ),
            ],
            if (widget.mode == _Mode.deactivate)
              Text(
                'Nonaktifkan ${current!.nama} (${current!.username})? Login dan permintaan terproteksi akan ditolak. Identitas dan histori dipertahankan; akun tidak dihapus permanen.',
              ),
            if (secret) ...[
              const SizedBox(height: 12),
              field(
                'Password',
                password,
                secret: true,
                validator: (s) {
                  final bytes = utf8.encode(s ?? '').length;
                  return bytes < 12 || bytes > 72
                      ? 'Password harus 12–72 byte.'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              field(
                'Konfirmasi password',
                confirm,
                secret: true,
                validator: (s) => s != password.text
                    ? 'Konfirmasi password harus sama.'
                    : null,
              ),
            ],
            if (widget.mode == _Mode.reset)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Reset password mencabut JWT sebelumnya. Akun harus login kembali. Status aktif/nonaktif tidak berubah.',
                ),
              ),
            if (widget.mode == _Mode.deactivate || widget.mode == _Mode.reset)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Saya mengonfirmasi tindakan untuk akun ini.',
                ),
                value: confirmed,
                onChanged: saving
                    ? null
                    : (v) {
                        setState(() => confirmed = v == true);
                        changed();
                      },
              ),
            if (!authorized || !targetAllowed)
              const Text(
                'Sesi, izin atau kebijakan target tidak mengizinkan penyimpanan.',
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    error!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              ),
            if (uncertain)
              const Text(
                'Belum ada konfirmasi server. Tutup form dan Refresh Users sebelum operasi baru.',
              ),
            if (conflict) ...[
              const Text(
                'Penyimpanan diblokir sampai data server ditinjau. Input belum dikirim ulang.',
              ),
              if (server != null)
                TextButton(
                  onPressed: saving
                      ? null
                      : () {
                          setState(() {
                            current = server;
                            server = null;
                            conflict = false;
                            confirmed = false;
                            populate();
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
                !authorized ||
                    !targetAllowed ||
                    saving ||
                    conflict ||
                    uncertain ||
                    ((widget.mode == _Mode.deactivate ||
                            widget.mode == _Mode.reset) &&
                        !confirmed)
                ? null
                : save,
            child: saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    widget.mode == _Mode.create || widget.mode == _Mode.edit
                        ? 'Simpan'
                        : title,
                  ),
          ),
        ],
      ),
    );
  }
}
