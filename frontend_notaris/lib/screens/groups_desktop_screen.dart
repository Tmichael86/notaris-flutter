import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/loading_overlay.dart';

class GroupsDesktopScreen extends StatefulWidget {
  const GroupsDesktopScreen({super.key});

  @override
  State<GroupsDesktopScreen> createState() => _GroupsDesktopScreenState();
}

class _GroupsDesktopScreenState extends State<GroupsDesktopScreen> {
  bool _isLoading = false;
  String _searchQuery = '';

  final List<GroupDummy> _groups = [
    GroupDummy(
      id: 1,
      nama: 'Super Admin',
      jenis: 'superadmin',
      permissions: {
        1: PermissionSet.fullAccess(),
        2: PermissionSet.fullAccess(),
        3: PermissionSet.fullAccess(),
        4: PermissionSet.fullAccess(),
        5: PermissionSet.fullAccess(),
        6: PermissionSet.fullAccess(),
      },
    ),
    GroupDummy(
      id: 2,
      nama: 'Administrator',
      jenis: 'user',
      permissions: {
        1: PermissionSet(read: true, create: true, update: true, delete: true),
        2: PermissionSet(read: true, create: true, update: true, delete: true),
        3: PermissionSet(read: true),
        4: PermissionSet(read: true, create: true, update: true),
        5: PermissionSet(read: true, create: true, update: true),
        6: PermissionSet(read: true, create: true),
      },
    ),
    GroupDummy(
      id: 3,
      nama: 'Staff',
      jenis: 'user',
      permissions: {
        1: PermissionSet(read: true),
        2: PermissionSet(read: true, create: true, update: true),
        3: PermissionSet(read: true),
        4: PermissionSet(read: true, create: true),
        5: PermissionSet(read: true),
        6: PermissionSet(read: true),
      },
    ),
    GroupDummy(
      id: 4,
      nama: 'Finance',
      jenis: 'user',
      permissions: {
        1: PermissionSet(read: true),
        4: PermissionSet(read: true, create: true, update: true, delete: true),
        5: PermissionSet(read: true),
      },
    ),
  ];

  final List<SidebarDummy> _sidebars = const [
    SidebarDummy(
      id: 1,
      nama: 'Dashboard',
      icon: Icons.dashboard_outlined,
      children: [],
    ),
    SidebarDummy(
      id: 2,
      nama: 'Transaksi',
      icon: Icons.receipt_long_outlined,
      children: [
        SidebarChildDummy(id: 21, nama: 'Transaksi Notaris'),
        SidebarChildDummy(id: 22, nama: 'Transaksi PPAT'),
      ],
    ),
    SidebarDummy(
      id: 3,
      nama: 'Monitoring',
      icon: Icons.monitor_outlined,
      children: [],
    ),
    SidebarDummy(
      id: 4,
      nama: 'Master',
      icon: Icons.grid_view_outlined,
      children: [
        SidebarChildDummy(id: 41, nama: 'Pekerjaan Notaris'),
        SidebarChildDummy(id: 42, nama: 'Pekerjaan PPAT'),
        SidebarChildDummy(id: 43, nama: 'Kategori Pekerjaan'),
        SidebarChildDummy(id: 44, nama: 'Jenis Pengeluaran'),
        SidebarChildDummy(id: 45, nama: 'Petugas'),
        SidebarChildDummy(id: 46, nama: 'Pemohon'),
      ],
    ),
    SidebarDummy(
      id: 5,
      nama: 'Laporan',
      icon: Icons.assessment_outlined,
      children: [
        SidebarChildDummy(id: 51, nama: 'Materai'),
        SidebarChildDummy(id: 52, nama: 'Pendapatan'),
      ],
    ),
    SidebarDummy(
      id: 6,
      nama: 'System',
      icon: Icons.settings_outlined,
      children: [
        SidebarChildDummy(id: 61, nama: 'Pengguna'),
        SidebarChildDummy(id: 62, nama: 'Groups'),
        SidebarChildDummy(id: 63, nama: 'Sidebar'),
        SidebarChildDummy(id: 64, nama: 'Konfigurasi Umum'),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      message: 'Menyimpan group...',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 700;

          return Padding(
            padding: EdgeInsets.all(mobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(mobile),
                const SizedBox(height: 18),
                _table(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _header(bool mobile) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Groups',
                style: TextStyle(
                  fontSize: mobile ? 22 : 25,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'System > Groups',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: () => _showForm(),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Tambah'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _table() {
    final query = _searchQuery.trim().toLowerCase();

    final rows = _groups.where((group) {
      return query.isEmpty || group.nama.toLowerCase().contains(query);
    }).toList();

    return Card(
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                    decoration: const InputDecoration(
                      hintText: 'Cari group...',
                      prefixIcon: Icon(Icons.search, size: 19),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: AppColors.card,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${rows.length} data',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 42,
                  dividerThickness: 1,
                  columns: const [
                    DataColumn(label: Text('#')),
                    DataColumn(label: Text('Nama')),
                    DataColumn(label: Text('Aksi')),
                  ],
                  rows: List.generate(rows.length, (index) {
                    final item = rows[index];

                    return DataRow(
                      cells: [
                        DataCell(Text('${index + 1}')),
                        DataCell(
                          Text(
                            item.nama,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Edit',
                                onPressed: () => _showForm(group: item),
                                icon: const Icon(Icons.edit_outlined),
                                color: AppColors.primary,
                              ),
                              IconButton(
                                tooltip: 'Hapus',
                                onPressed: () => _delete(item),
                                icon: const Icon(Icons.delete_outline),
                                color: AppColors.error,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Tidak ada data group.'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showForm({GroupDummy? group}) async {
    final isEdit = group != null;

    final namaController = TextEditingController(
      text: group?.nama ?? '',
    );

    String jenis = group?.jenis ?? 'user';

    final permissions = <int, PermissionSet>{};

    for (final sidebar in _sidebars) {
      final existing = group?.permissions[sidebar.id];
      permissions[sidebar.id] = existing?.copy() ?? PermissionSet();
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Group' : 'Group'),
              content: SizedBox(
                width: 900,
                height: MediaQuery.of(context).size.height * .78,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: namaController,
                            decoration: const InputDecoration(
                              labelText: 'Nama Grup *',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 220,
                          child: DropdownButtonFormField<String>(
                            initialValue: jenis,
                            decoration: const InputDecoration(
                              labelText: 'Jenis Grup',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'superadmin',
                                child: Text('Super Admin'),
                              ),
                              DropdownMenuItem(
                                value: 'user',
                                child: Text('User'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setDialogState(() => jenis = value);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Akses Halaman',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.separated(
                        itemCount: _sidebars.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final sidebar = _sidebars[index];
                          final permission = permissions[sidebar.id]!;

                          return _permissionCard(
                            sidebar,
                            permission,
                            permissions,
                            setDialogState,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Tutup'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  onPressed: () {
                    if (namaController.text.trim().isEmpty) return;

                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true || !mounted) {
      namaController.dispose();
      return;
    }

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 700));

    setState(() {
      if (isEdit) {
        group.nama = namaController.text.trim();
        group.jenis = jenis;
        group.permissions
          ..clear()
          ..addAll(
            permissions.map(
              (key, value) => MapEntry(key, value.copy()),
            ),
          );
      } else {
        _groups.insert(
          0,
          GroupDummy(
            id: DateTime.now().millisecondsSinceEpoch,
            nama: namaController.text.trim(),
            jenis: jenis,
            permissions: permissions.map(
              (key, value) => MapEntry(key, value.copy()),
            ),
          ),
        );
      }

      _isLoading = false;
    });

    namaController.dispose();
  }

  Widget _permissionCard(
    SidebarDummy sidebar,
    PermissionSet permission,
    Map<int, PermissionSet> permissions,
    void Function(void Function()) setDialogState,
  ) {
    final allChildrenEnabled = sidebar.children.isNotEmpty &&
        sidebar.children.every((child) {
          return _hasPermissionForChild(
            child.id,
            sidebar,
            permissions,
          );
        });

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 14),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: Icon(
          sidebar.icon,
          color: AppColors.primary,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                sidebar.nama,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            _permissionCheckbox(
              label: 'Semua',
              value: sidebar.children.isEmpty
                  ? permission.all
                  : permission.all && allChildrenEnabled,
              onChanged: (value) {
                _setSidebarAll(
                  sidebar,
                  value,
                  permissions,
                  setDialogState,
                );
              },
            ),
          ],
        ),
        children: [
          _permissionRow(
            sidebar.nama,
            permission,
            onChanged: setDialogState,
          ),
          ...sidebar.children.map(
            (child) {
              final childPermission =
                  permissions[child.id] ?? PermissionSet();

              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _permissionRow(
                  child.nama,
                  childPermission,
                  child: true,
                  onChanged: setDialogState,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  bool _hasPermissionForChild(
    int childId,
    SidebarDummy parent,
    Map<int, PermissionSet> permissions,
  ) {
    return permissions[childId]?.all ?? false;
  }

  void _setSidebarAll(
    SidebarDummy sidebar,
    bool value,
    Map<int, PermissionSet> permissions,
    void Function(void Function()) setDialogState,
  ) {
    setDialogState(() {
      final parent = permissions[sidebar.id]!;
      parent.setAll(value);

      for (final child in sidebar.children) {
        final childPermission =
            permissions[child.id] ?? PermissionSet();
        childPermission.setAll(value);
        permissions[child.id] = childPermission;
      }
    });
  }

  Widget _permissionRow(
    String label,
    PermissionSet permission, {
    bool child = false,
    required void Function(void Function()) onChanged,
  }) {
    return Container(
      padding: EdgeInsets.only(
        left: child ? 30 : 8,
        top: 8,
        bottom: 8,
        right: 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: child ? FontWeight.w400 : FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: _permissionCheckbox(
              label: 'Lihat',
              value: permission.read,
              onChanged: (value) {
                onChanged(() {
                  permission.read = value;
                });
              },
            ),
          ),
          Expanded(
            child: _permissionCheckbox(
              label: 'Buat',
              value: permission.create,
              onChanged: (value) {
                onChanged(() {
                  permission.create = value;
                  if (value) permission.read = true;
                });
              },
            ),
          ),
          Expanded(
            child: _permissionCheckbox(
              label: 'Perbarui',
              value: permission.update,
              onChanged: (value) {
                onChanged(() {
                  permission.update = value;
                  if (value) permission.read = true;
                });
              },
            ),
          ),
          Expanded(
            child: _permissionCheckbox(
              label: 'Hapus',
              value: permission.delete,
              onChanged: (value) {
                onChanged(() {
                  permission.delete = value;
                  if (value) permission.read = true;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _permissionCheckbox({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: value,
          activeColor: AppColors.primary,
          onChanged: (checked) => onChanged(checked ?? false),
        ),
        Flexible(child: Text(label)),
      ],
    );
  }

  Future<void> _delete(GroupDummy group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hapus Group'),
          content: Text('Hapus group "${group.nama}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Tidak'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 700));

    setState(() {
      _groups.remove(group);
      _isLoading = false;
    });
  }
}

class PermissionSet {
  bool read;
  bool create;
  bool update;
  bool delete;

  PermissionSet({
    this.read = false,
    this.create = false,
    this.update = false,
    this.delete = false,
  });

  bool get all => read && create && update && delete;

  void setAll(bool value) {
    read = value;
    create = value;
    update = value;
    delete = value;
  }

  PermissionSet copy() {
    return PermissionSet(
      read: read,
      create: create,
      update: update,
      delete: delete,
    );
  }

  static PermissionSet fullAccess() => PermissionSet(
        read: true,
        create: true,
        update: true,
        delete: true,
      );
}

class GroupDummy {
  int id;
  String nama;
  String jenis;
  Map<int, PermissionSet> permissions;

  GroupDummy({
    required this.id,
    required this.nama,
    required this.jenis,
    required this.permissions,
  });
}

class SidebarDummy {
  final int id;
  final String nama;
  final IconData icon;
  final List<SidebarChildDummy> children;

  const SidebarDummy({
    required this.id,
    required this.nama,
    required this.icon,
    required this.children,
  });
}

class SidebarChildDummy {
  final int id;
  final String nama;

  const SidebarChildDummy({
    required this.id,
    required this.nama,
  });
}
