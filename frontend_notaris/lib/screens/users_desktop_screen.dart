import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/loading_overlay.dart';
import '../../core/widgets/searchable_dropdown.dart';

class UsersDesktopScreen extends StatefulWidget {
  const UsersDesktopScreen({super.key});

  @override
  State<UsersDesktopScreen> createState() => _UsersDesktopScreenState();
}

class _UsersDesktopScreenState extends State<UsersDesktopScreen> {
  final _searchController = TextEditingController();

  String _searchQuery = '';
  String? _selectedGroup = 'Semua Group';
  bool _isLoading = false;

  final List<String> _groups = const [
    'Semua Group',
    'Super Admin',
    'Administrator',
    'Notaris',
    'PPAT',
    'Staff',
    'Finance',
  ];

  final List<UserDummy> _data = [
    UserDummy(
      'Tegar',
      'Super Admin',
      'tegar',
      'tegar@example.com',
      '081234567890',
      '20/09/2026',
      'Admin',
    ),
    UserDummy(
      'Budi Santoso',
      'Staff',
      'budi.santoso',
      'budi@example.com',
      '081234567891',
      '19/09/2026',
      'Admin',
    ),
    UserDummy(
      'Siti Aminah',
      'Notaris',
      'siti.aminah',
      'siti@example.com',
      '081234567892',
      '18/09/2026',
      'Admin',
    ),
    UserDummy(
      'Rina Wulandari',
      'PPAT',
      'rina.wulandari',
      'rina@example.com',
      '081234567893',
      '17/09/2026',
      'Admin',
    ),
    UserDummy(
      'Andi Pratama',
      'Finance',
      'andi.pratama',
      'andi@example.com',
      '081234567894',
      '16/09/2026',
      'Admin',
    ),
  ];

  List<UserDummy> get _filteredData {
    final query = _searchQuery.trim().toLowerCase();

    return _data.where((item) {
      final matchesGroup = _selectedGroup == 'Semua Group' ||
          item.group == _selectedGroup;

      final matchesSearch = query.isEmpty ||
          item.nama.toLowerCase().contains(query) ||
          item.username.toLowerCase().contains(query) ||
          item.email.toLowerCase().contains(query) ||
          item.group.toLowerCase().contains(query);

      return matchesGroup && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      message: 'Memproses data pengguna...',
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
                _filters(mobile),
                const SizedBox(height: 16),
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
                'Pengguna',
                style: TextStyle(
                  fontSize: mobile ? 22 : 25,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'System > Pengguna',
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

  Widget _filters(bool mobile) {
    final search = TextField(
      controller: _searchController,
      onChanged: (value) {
        setState(() => _searchQuery = value);
      },
      decoration: InputDecoration(
        hintText: 'Cari nama, username, email...',
        prefixIcon: const Icon(Icons.search, size: 19),
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                icon: const Icon(Icons.close, size: 18),
              ),
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: AppColors.card,
      ),
    );

    final group = SearchableDropdown<String>(
      value: _selectedGroup,
      items: _groups,
      label: 'Group',
      itemLabel: (item) => item,
      onChanged: (value) => setState(() => _selectedGroup = value),
    );

    final reset = OutlinedButton.icon(
      onPressed: _reset,
      icon: const Icon(Icons.refresh, size: 17),
      label: const Text('Reset'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
      ),
    );

    return Card(
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: mobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  search,
                  const SizedBox(height: 12),
                  group,
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: reset,
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(child: search),
                  const SizedBox(width: 12),
                  SizedBox(width: 230, child: group),
                  const SizedBox(width: 12),
                  reset,
                ],
              ),
      ),
    );
  }

  Widget _table() {
    final rows = _filteredData;

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Data Pengguna',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
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
                  headingRowColor:
                      const WidgetStatePropertyAll(AppColors.card),
                  columnSpacing: 36,
                  dividerThickness: 1,
                  headingTextStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                  dataTextStyle: const TextStyle(
                    color: AppColors.textPrimary,
                  ),
                  columns: const [
                    DataColumn(label: Text('#')),
                    DataColumn(label: Text('Nama')),
                    DataColumn(label: Text('Group')),
                    DataColumn(label: Text('Username')),
                    DataColumn(label: Text('Email')),
                    DataColumn(label: Text('No Telp')),
                    DataColumn(label: Text('Created At')),
                    DataColumn(label: Text('Aksi')),
                  ],
                  rows: List.generate(rows.length, (index) {
                    final item = rows[index];

                    return DataRow(
                      cells: [
                        DataCell(Text('${index + 1}')),
                        DataCell(Text(item.nama)),
                        DataCell(
                          Text(
                            item.group.toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        DataCell(Text(item.username)),
                        DataCell(Text(item.email)),
                        DataCell(Text(item.noTelp)),
                        DataCell(Text(item.createdAt)),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Edit',
                                onPressed: () => _showForm(item: item),
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 19,
                                ),
                                color: AppColors.primary,
                              ),
                              IconButton(
                                tooltip: 'Hapus',
                                onPressed: () => _delete(item),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 19,
                                ),
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
                child: Center(
                  child: Text('Tidak ada data pengguna.'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showForm({UserDummy? item}) async {
    final isEdit = item != null;

    final nama = TextEditingController(text: item?.nama ?? '');
    final telp = TextEditingController(text: item?.noTelp ?? '');
    final email = TextEditingController(text: item?.email ?? '');
    final username = TextEditingController(text: item?.username ?? '');
    final alamat = TextEditingController();
    final password = TextEditingController();
    final passwordConfirm = TextEditingController();

    String? selectedGroup = item?.group;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isEdit ? 'Edit Pengguna' : 'Pengguna'),
          content: SizedBox(
            width: 760,
            child: SingleChildScrollView(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final mobile = constraints.maxWidth < 600;

                  final profile = Column(
                    children: [
                      Container(
                        width: 120,
                        height: 140,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.person_outline,
                          size: 54,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Foto profil',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'JPG, JPEG, PNG',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  );

                  final form = Column(
                    children: [
                      _field(
                        nama,
                        'Nama',
                        required: true,
                      ),
                      const SizedBox(height: 12),
                      SearchableDropdown<String>(
                        value: selectedGroup,
                        items: _groups.where((e) => e != 'Semua Group').toList(),
                        label: 'Group',
                        itemLabel: (value) => value,
                        onChanged: (value) {
                          selectedGroup = value;
                        },
                      ),
                      const SizedBox(height: 12),
                      _field(telp, 'Telp'),
                      const SizedBox(height: 12),
                      _field(email, 'Email', required: true),
                      const SizedBox(height: 12),
                      _field(username, 'Username', required: true),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _field(
                              password,
                              'Password',
                              obscure: true,
                              required: !isEdit,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _field(
                              passwordConfirm,
                              'Password Konfirmasi',
                              obscure: true,
                              required: !isEdit,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );

                  return mobile
                      ? Column(
                          children: [
                            profile,
                            const SizedBox(height: 18),
                            form,
                            const SizedBox(height: 12),
                            _field(
                              alamat,
                              'Alamat',
                              maxLines: 4,
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(width: 150, child: profile),
                                const SizedBox(width: 20),
                                Expanded(child: form),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _field(
                              alamat,
                              'Alamat',
                              maxLines: 4,
                            ),
                          ],
                        );
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Tutup'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              onPressed: () async {
                if (nama.text.trim().isEmpty ||
                    email.text.trim().isEmpty ||
                    username.text.trim().isEmpty ||
                    selectedGroup == null) {
                  return;
                }

                if (!isEdit &&
                    (password.text.isEmpty ||
                        password.text != passwordConfirm.text)) {
                  return;
                }

                Navigator.pop(dialogContext);
                setState(() => _isLoading = true);
                await Future.delayed(const Duration(milliseconds: 700));

                setState(() {
                  if (isEdit) {
                    item.nama = nama.text.trim();
                    item.group = selectedGroup!;
                    item.noTelp = telp.text.trim();
                    item.email = email.text.trim();
                    item.username = username.text.trim();
                  } else {
                    _data.insert(
                      0,
                      UserDummy(
                        nama.text.trim(),
                        selectedGroup!,
                        username.text.trim(),
                        email.text.trim(),
                        telp.text.trim(),
                        _today(),
                        'Admin',
                      ),
                    );
                  }

                  _isLoading = false;
                });
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );

    nama.dispose();
    telp.dispose();
    email.dispose();
    username.dispose();
    alamat.dispose();
    password.dispose();
    passwordConfirm.dispose();
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    bool obscure = false,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      maxLines: obscure ? 1 : maxLines,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: AppColors.card,
      ),
    );
  }

  Future<void> _delete(UserDummy item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Pengguna'),
        content: Text('Hapus pengguna "${item.nama}"?'),
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
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 700));

    setState(() {
      _data.remove(item);
      _isLoading = false;
    });
  }

  void _reset() {
    _searchController.clear();

    setState(() {
      _searchQuery = '';
      _selectedGroup = 'Semua Group';
    });
  }

  static String _today() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/${now.year}';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class UserDummy {
  String nama;
  String group;
  String username;
  String email;
  String noTelp;
  String createdAt;
  String createdBy;

  UserDummy(
    this.nama,
    this.group,
    this.username,
    this.email,
    this.noTelp,
    this.createdAt,
    this.createdBy,
  );
}
