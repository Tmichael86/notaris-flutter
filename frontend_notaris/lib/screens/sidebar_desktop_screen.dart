import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class SidebarDesktopScreen extends StatefulWidget {
  const SidebarDesktopScreen({super.key});

  @override
  State<SidebarDesktopScreen> createState() => _SidebarDesktopScreenState();
}

class _SidebarDesktopScreenState extends State<SidebarDesktopScreen> {
  final TextEditingController _searchController = TextEditingController();

  int _currentPage = 1;
  final int _itemsPerPage = 8;
  String _searchQuery = '';

  final List<_SidebarItem> _items = [
    _SidebarItem(
      id: 1,
      nama: 'Dashboard',
      parent: '-',
      route: '/dashboard',
      kode: 'dashboard',
      index: 1,
      icon: 'dashboard',
      createdAt: '29/06/2026',
    ),
    _SidebarItem(
      id: 2,
      nama: 'Transaksi',
      parent: '-',
      route: '#',
      kode: 'transaksi',
      index: 2,
      icon: 'swap_horiz',
      createdAt: '29/06/2026',
    ),
    _SidebarItem(
      id: 3,
      nama: 'Transaksi Notaris',
      parent: 'Transaksi',
      route: '/transaksi/notaris',
      kode: 'transaksi-notaris',
      index: 1,
      icon: 'description',
      createdAt: '29/06/2026',
    ),
    _SidebarItem(
      id: 4,
      nama: 'Transaksi PPAT',
      parent: 'Transaksi',
      route: '/transaksi/ppat',
      kode: 'transaksi-ppat',
      index: 2,
      icon: 'description',
      createdAt: '29/06/2026',
    ),
    _SidebarItem(
      id: 5,
      nama: 'Monitoring',
      parent: '-',
      route: '/monitoring',
      kode: 'monitoring',
      index: 3,
      icon: 'monitor',
      createdAt: '29/06/2026',
    ),
    _SidebarItem(
      id: 6,
      nama: 'Master',
      parent: '-',
      route: '#',
      kode: 'master',
      index: 4,
      icon: 'folder',
      createdAt: '29/06/2026',
    ),
    _SidebarItem(
      id: 7,
      nama: 'Pekerjaan Notaris',
      parent: 'Master',
      route: '/master/pekerjaan-notaris',
      kode: 'pekerjaan-notaris',
      index: 1,
      icon: 'work',
      createdAt: '29/06/2026',
    ),
    _SidebarItem(
      id: 8,
      nama: 'Pekerjaan PPAT',
      parent: 'Master',
      route: '/master/pekerjaan-ppat',
      kode: 'pekerjaan-ppat',
      index: 2,
      icon: 'work',
      createdAt: '29/06/2026',
    ),
    _SidebarItem(
      id: 9,
      nama: 'Kategori Pekerjaan',
      parent: 'Master',
      route: '/master/kategori-pekerjaan',
      kode: 'kategori-pekerjaan',
      index: 3,
      icon: 'category',
      createdAt: '29/06/2026',
    ),
    _SidebarItem(
      id: 10,
      nama: 'Jenis Pengeluaran',
      parent: 'Master',
      route: '/master/jenis-pengeluaran',
      kode: 'jenis-pengeluaran',
      index: 4,
      icon: 'payments',
      createdAt: '29/06/2026',
    ),
    _SidebarItem(
      id: 11,
      nama: 'Petugas',
      parent: 'Master',
      route: '/master/petugas',
      kode: 'petugas',
      index: 5,
      icon: 'badge',
      createdAt: '29/06/2026',
    ),
    _SidebarItem(
      id: 12,
      nama: 'Pemohon',
      parent: 'Master',
      route: '/master/pemohon',
      kode: 'pemohon',
      index: 6,
      icon: 'person',
      createdAt: '29/06/2026',
    ),
    _SidebarItem(
      id: 13,
      nama: 'Laporan',
      parent: '-',
      route: '#',
      kode: 'laporan',
      index: 5,
      icon: 'assessment',
      createdAt: '29/06/2026',
    ),
    _SidebarItem(
      id: 14,
      nama: 'Materai',
      parent: 'Laporan',
      route: '/laporan/materai',
      kode: 'laporan-materai',
      index: 1,
      icon: 'receipt_long',
      createdAt: '29/06/2026',
    ),
    _SidebarItem(
      id: 15,
      nama: 'Pendapatan',
      parent: 'Laporan',
      route: '/laporan/pendapatan',
      kode: 'laporan-pendapatan',
      index: 2,
      icon: 'bar_chart',
      createdAt: '29/06/2026',
    ),
    _SidebarItem(
      id: 16,
      nama: 'System',
      parent: '-',
      route: '#',
      kode: 'system',
      index: 6,
      icon: 'settings',
      createdAt: '29/06/2026',
    ),
    _SidebarItem(
      id: 17,
      nama: 'Pengguna',
      parent: 'System',
      route: '/system/users',
      kode: 'users',
      index: 1,
      icon: 'people',
      createdAt: '29/06/2026',
    ),
    _SidebarItem(
      id: 18,
      nama: 'Groups',
      parent: 'System',
      route: '/system/groups',
      kode: 'groups',
      index: 2,
      icon: 'groups',
      createdAt: '29/06/2026',
    ),
    _SidebarItem(
      id: 19,
      nama: 'Sidebar',
      parent: 'System',
      route: '/system/sidebars',
      kode: 'sidebars',
      index: 3,
      icon: 'menu',
      createdAt: '29/06/2026',
    ),
    _SidebarItem(
      id: 20,
      nama: 'Konfigurasi Umum',
      parent: 'System',
      route: '/system/konfigurasi',
      kode: 'konfigurasi',
      index: 4,
      icon: 'tune',
      createdAt: '29/06/2026',
    ),
  ];

  List<_SidebarItem> get _filteredItems {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return _items;
    }

    return _items.where((item) {
      return item.nama.toLowerCase().contains(query) ||
          item.parent.toLowerCase().contains(query) ||
          item.route.toLowerCase().contains(query) ||
          item.kode.toLowerCase().contains(query) ||
          item.icon.toLowerCase().contains(query);
    }).toList();
  }

  int get _totalPages {
    final total = _filteredItems.length;
    return total == 0 ? 1 : (total / _itemsPerPage).ceil();
  }

  List<_SidebarItem> get _pagedItems {
    final items = _filteredItems;
    final start = (_currentPage - 1) * _itemsPerPage;

    if (start >= items.length) {
      return [];
    }

    final end = (start + _itemsPerPage).clamp(0, items.length);
    return items.sublist(start, end);
  }

  void _onSearch(String value) {
    setState(() {
      _searchQuery = value;
      _currentPage = 1;
    });
  }

  void _resetSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _currentPage = 1;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isMobile),
              const SizedBox(height: 20),
              _buildTableCard(isMobile),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sidebar',
          style: TextStyle(
            fontSize: isMobile ? 22 : 26,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'System  >  Sidebar',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildTableCard(bool isMobile) {
    final rows = _pagedItems;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildToolbar(isMobile),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            _buildEmptyState()
          else
            _buildTable(),
          const SizedBox(height: 16),
          _buildFooter(rows.length, isMobile),
        ],
      ),
    );
  }

  Widget _buildToolbar(bool isMobile) {
    final searchField = SizedBox(
      width: isMobile ? double.infinity : 360,
      child: TextField(
        controller: _searchController,
        onChanged: _onSearch,
        decoration: InputDecoration(
          hintText: 'Cari sidebar...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Reset',
                  onPressed: _resetSearch,
                  icon: const Icon(Icons.close, size: 19),
                ),
          filled: true,
          fillColor: AppColors.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
      ),
    );

    final count = Text(
      '${_filteredItems.length} data',
      style: const TextStyle(
        fontSize: 13,
        color: AppColors.textSecondary,
      ),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          searchField,
          const SizedBox(height: 12),
          count,
        ],
      );
    }

    return Row(
      children: [
        searchField,
        const Spacer(),
        count,
      ],
    );
  }

  Widget _buildTable() {
    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 46,
          dataRowMinHeight: 54,
          dataRowMaxHeight: 62,
          columnSpacing: 24,
          horizontalMargin: 8,
          headingTextStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          dataTextStyle: const TextStyle(
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
          columns: const [
            DataColumn(label: Text('#')),
            DataColumn(label: Text('Nama')),
            DataColumn(label: Text('Parent')),
            DataColumn(label: Text('Route')),
            DataColumn(label: Text('Kode')),
            DataColumn(label: Text('Index')),
            DataColumn(label: Text('Icon')),
            DataColumn(label: Text('Created At')),
          ],
          rows: _pagedItems.map((item) {
            return DataRow(
              cells: [
                DataCell(Text(item.id.toString())),
                DataCell(
                  Text(
                    item.nama,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataCell(_parentBadge(item.parent)),
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 210),
                    child: Text(
                      item.route,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(_codeBadge(item.kode)),
                DataCell(Text(item.index.toString())),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _iconFromName(item.icon),
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(item.icon),
                    ],
                  ),
                ),
                DataCell(Text(item.createdAt)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _parentBadge(String parent) {
    final isRoot = parent == '-';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: isRoot
            ? AppColors.selectedMenuBg
            : AppColors.background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        parent,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isRoot
              ? AppColors.primary
              : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _codeBadge(String code) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        code,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 50),
      child: Center(
        child: Column(
          children: const [
            Icon(
              Icons.search_off,
              size: 42,
              color: AppColors.textMuted,
            ),
            SizedBox(height: 10),
            Text(
              'Data sidebar tidak ditemukan',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(int visibleCount, bool isMobile) {
    final start = _filteredItems.isEmpty
        ? 0
        : ((_currentPage - 1) * _itemsPerPage) + 1;
    final end = _filteredItems.isEmpty
        ? 0
        : start + visibleCount - 1;

    return isMobile
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Menampilkan $start-$end dari ${_filteredItems.length} data',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              _buildPagination(),
            ],
          )
        : Row(
            children: [
              Text(
                'Menampilkan $start-$end dari ${_filteredItems.length} data',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              _buildPagination(),
            ],
          );
  }

  Widget _buildPagination() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _pageButton(
          icon: Icons.chevron_left,
          enabled: _currentPage > 1,
          onPressed: () {
            if (_currentPage > 1) {
              setState(() => _currentPage--);
            }
          },
        ),
        const SizedBox(width: 6),
        Container(
          height: 36,
          width: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            '$_currentPage',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 6),
        _pageButton(
          icon: Icons.chevron_right,
          enabled: _currentPage < _totalPages,
          onPressed: () {
            if (_currentPage < _totalPages) {
              setState(() => _currentPage++);
            }
          },
        ),
      ],
    );
  }

  Widget _pageButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 36,
      width: 36,
      child: OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(7),
          ),
        ),
        child: Icon(
          icon,
          size: 19,
          color: enabled
              ? AppColors.textPrimary
              : AppColors.textMuted,
        ),
      ),
    );
  }

  IconData _iconFromName(String name) {
    const icons = <String, IconData>{
      'dashboard': Icons.dashboard_outlined,
      'swap_horiz': Icons.swap_horiz,
      'description': Icons.description_outlined,
      'monitor': Icons.monitor_outlined,
      'folder': Icons.folder_outlined,
      'work': Icons.work_outline,
      'category': Icons.category_outlined,
      'payments': Icons.payments_outlined,
      'badge': Icons.badge_outlined,
      'person': Icons.person_outline,
      'assessment': Icons.assessment_outlined,
      'receipt_long': Icons.receipt_long_outlined,
      'bar_chart': Icons.bar_chart_outlined,
      'settings': Icons.settings_outlined,
      'people': Icons.people_outline,
      'groups': Icons.groups_outlined,
      'menu': Icons.menu,
      'tune': Icons.tune,
    };

    return icons[name] ?? Icons.circle_outlined;
  }
}

class _SidebarItem {
  final int id;
  final String nama;
  final String parent;
  final String route;
  final String kode;
  final int index;
  final String icon;
  final String createdAt;

  const _SidebarItem({
    required this.id,
    required this.nama,
    required this.parent,
    required this.route,
    required this.kode,
    required this.index,
    required this.icon,
    required this.createdAt,
  });
}
