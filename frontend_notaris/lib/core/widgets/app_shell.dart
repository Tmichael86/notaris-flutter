import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../screens/dashboard_desktop_screen.dart';
import '../../screens/groups_desktop_screen.dart';
import '../../screens/jenis_pengeluaran_desktop_screen.dart';
import '../../screens/kategori_pekerjaan_desktop_screen.dart';
import '../../screens/konfigurasi_umum_desktop_screen.dart';
import '../../screens/laporan_materai_desktop_screen.dart';
import '../../screens/laporan_pendapatan_desktop_screen.dart';
import '../../screens/login_desktop_screen.dart';
import '../../screens/monitoring_desktop_screen.dart';
import '../../screens/pekerjaan_notaris_desktop_screen.dart';
import '../../screens/pekerjaan_ppat_desktop_screen.dart';
import '../../screens/pemohon_desktop_screen.dart';
import '../../screens/pengeluaran_desktop_screen.dart';
import '../../screens/penghasilan_desktop_screen.dart';
import '../../screens/petugas_desktop_screen.dart';
import '../../screens/piutang_desktop_screen.dart';
import '../../screens/sidebar_desktop_screen.dart';
import '../../screens/transaction_desktop_screen.dart';
import '../../screens/users_desktop_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const double desktopBreakpoint = 1000;
  static const String logoImage = 'assets/images/logo_notaris_ppat.png';

  String selectedMenu = 'Dashboard';
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final masterMenus = const [
    'Pekerjaan Notaris',
    'Pekerjaan PPAT',
    'Kategori Pekerjaan',
    'Jenis Pengeluaran',
    'Petugas',
    'Pemohon',
  ];

  final laporanMenus = const ['Materai', 'Pendapatan'];

  final systemMenus = const [
    'Users',
    'Groups',
    'Sidebars',
    'Konfigurasi Umum',
  ];

  int get _mobileNavIndex {
    switch (selectedMenu) {
      case 'Transaksi':
        return 1;
      case 'Monitoring':
        return 2;
      default:
        return 0;
    }
  }

  void _selectMenu(String title) {
    setState(() => selectedMenu = title);
    _scaffoldKey.currentState?.closeDrawer();
  }

  Widget _buildHeader({bool mobile = false}) {
    return Container(
      height: mobile ? 58 : 68,
      padding: EdgeInsets.symmetric(horizontal: mobile ? 12 : 24),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (mobile) ...[
            IconButton(
              tooltip: 'Menu',
              icon: const Icon(Icons.menu),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            const SizedBox(width: 4),
            const Text(
              'BLITARIS',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: .5,
                color: AppColors.primary,
              ),
            ),
            const Spacer(),
          ] else ...[
            const Text(
              'Sistem Administrasi Notaris & PPAT',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
          ],
          IconButton(
            tooltip: 'Notifikasi',
            icon: const Icon(
              Icons.notifications_none_outlined,
              color: AppColors.textSecondary,
            ),
            onPressed: () {},
          ),
          const SizedBox(width: 4),
          if (!mobile)
            const Text(
              'SUPER ADMIN',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: .5,
                color: AppColors.textSecondary,
              ),
            ),
          const SizedBox(width: 10),
          PopupMenuButton<String>(
            offset: const Offset(0, 48),
            tooltip: 'Akun',
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.selectedMenuBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            onSelected: (value) {
              if (value == 'logout') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LoginDesktopScreen(),
                  ),
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'profile', child: Text('Profile')),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: Text(
                  'Keluar',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(
    String title,
    IconData icon, {
    VoidCallback? onTap,
    bool dense = false,
  }) {
    final selected = selectedMenu == title;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: dense ? 2 : 3),
      child: Material(
        color: selected ? AppColors.selectedMenuBg : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: dense ? 12 : 13,
              vertical: dense ? 9 : 11,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: dense ? 18 : 20,
                  color: selected
                      ? AppColors.selectedMenuText
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: dense ? 13 : 14,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? AppColors.selectedMenuText
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sidebarExpansion(String title, IconData icon, List<String> items) {
    final selected = items.contains(selectedMenu);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: AppColors.selectedMenuBg,
          highlightColor: AppColors.selectedMenuBg,
        ),
        child: ExpansionTile(
          key: ValueKey('$title-$selected'),
          initiallyExpanded: selected,
          tilePadding: const EdgeInsets.symmetric(horizontal: 13),
          childrenPadding: EdgeInsets.zero,
          leading: Icon(
            icon,
            size: 20,
            color: selected
                ? AppColors.selectedMenuText
                : AppColors.textSecondary,
          ),
          iconColor: AppColors.primary,
          collapsedIconColor: AppColors.textSecondary,
          textColor: AppColors.textPrimary,
          collapsedTextColor: AppColors.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          children: items
              .map(
                (item) => _sidebarItem(
                  item,
                  Icons.chevron_right,
                  onTap: () => _selectMenu(item),
                  dense: true,
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildDesktopSidebar() {
    return Container(
      width: 248,
      color: AppColors.sidebarBg,
      child: Column(
        children: [
          Container(
            height: 88,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: AppColors.border),
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
            child: Row(
              children: [
                Image.asset(
                  logoImage,
                  width: 75,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 10),
                const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MY NOTARIS',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .7,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      'Notaris & PPAT',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              physics: const ClampingScrollPhysics(),
              children: [
                _sidebarItem(
                  'Dashboard',
                  Icons.dashboard_outlined,
                  onTap: () => _selectMenu('Dashboard'),
                ),
                _sidebarItem(
                  'Transaksi',
                  Icons.receipt_long_outlined,
                  onTap: () => _selectMenu('Transaksi'),
                ),
                _sidebarItem(
                  'Monitoring',
                  Icons.monitor_outlined,
                  onTap: () => _selectMenu('Monitoring'),
                ),
                _sidebarItem(
                  'Pengeluaran',
                  Icons.payments_outlined,
                  onTap: () => _selectMenu('Pengeluaran'),
                ),
                _sidebarItem(
                  'Piutang',
                  Icons.account_balance_wallet_outlined,
                  onTap: () => _selectMenu('Piutang'),
                ),
                _sidebarItem(
                  'Penghasilan',
                  Icons.trending_up_outlined,
                  onTap: () => _selectMenu('Penghasilan'),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(22, 14, 22, 8),
                  child: Text(
                    'MENU UTAMA',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                _sidebarExpansion('Master', Icons.folder_outlined, masterMenus),
                _sidebarExpansion(
                  'Laporan',
                  Icons.assessment_outlined,
                  laporanMenus,
                ),
                _sidebarExpansion(
                  'System',
                  Icons.settings_outlined,
                  systemMenus,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.border),
                right: BorderSide(color: AppColors.border),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Sistem Administrasi\nNotaris & PPAT',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileItem(String title, IconData icon) {
    final selected = selectedMenu == title;

    return ListTile(
      selected: selected,
      selectedTileColor: AppColors.selectedMenuBg,
      leading: Icon(
        icon,
        color: selected ? AppColors.selectedMenuText : AppColors.textPrimary,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: selected ? AppColors.selectedMenuText : AppColors.textPrimary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      onTap: () => _selectMenu(title),
    );
  }

  Widget _mobileExpansion(String title, IconData icon, List<String> items) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 20, color: AppColors.textPrimary),
      iconColor: AppColors.textPrimary,
      collapsedIconColor: AppColors.textPrimary,
      textColor: AppColors.textPrimary,
      collapsedTextColor: AppColors.textPrimary,
      shape: const Border(),
      collapsedShape: const Border(),
      title: Text(title),
      children: items
          .map(
            (item) => ListTile(
              contentPadding: const EdgeInsets.only(left: 56, right: 16),
              selected: selectedMenu == item,
              selectedTileColor: AppColors.selectedMenuBg,
              title: Text(
                item,
                style: TextStyle(
                  color: selectedMenu == item
                      ? AppColors.selectedMenuText
                      : AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: selectedMenu == item
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
              onTap: () => _selectMenu(item),
            ),
          )
          .toList(),
    );
  }

  Widget _buildMobileDrawer() {
    return Drawer(
      backgroundColor: AppColors.card,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              height: 72,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.centerLeft,
              color: AppColors.primary,
              child: const Text(
                'BLITARIS',
                style: TextStyle(
                  color: AppColors.card,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .5,
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _mobileItem('Dashboard', Icons.home_outlined),
                  _mobileItem('Transaksi', Icons.receipt_long_outlined),
                  _mobileItem('Monitoring', Icons.monitor_outlined),
                  _mobileItem('Pengeluaran', Icons.payments_outlined),
                  _mobileItem('Piutang', Icons.account_balance_wallet_outlined),
                  _mobileItem('Penghasilan', Icons.trending_up_outlined),
                  const Divider(height: 1, color: AppColors.divider),
                  _mobileExpansion('Master', Icons.folder_outlined, masterMenus),
                  _mobileExpansion('Laporan', Icons.assessment_outlined, laporanMenus),
                  _mobileExpansion('System', Icons.settings_outlined, systemMenus),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(28, 0, 28, 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/images/logoblitaris.png',
            width: 42,
            height: 42,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 12),
          const Text(
            '© Copyright Blitaris Tekno  •  All rights reserved',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }



  Widget _buildContent() {
    switch (selectedMenu) {
      case 'Dashboard':
        return const DashboardDesktopScreen();
      case 'Transaksi':
        return const TransactionDesktopScreen();
      case 'Monitoring':
        return const MonitoringDesktopScreen();
      case 'Pengeluaran':
        return const PengeluaranDesktopScreen();
      case 'Piutang':
        return const PiutangDesktopScreen();
      case 'Penghasilan':
        return const PenghasilanDesktopScreen();
      case 'Pekerjaan Notaris':
        return const PekerjaanNotarisDesktopScreen();
      case 'Pekerjaan PPAT':
        return const PekerjaanPPATDesktopScreen();
      case 'Kategori Pekerjaan':
        return const KategoriPekerjaanDesktopScreen();
      case 'Jenis Pengeluaran':
        return const JenisPengeluaranDesktopScreen();
      case 'Petugas':
        return const PetugasDesktopScreen();
      case 'Pemohon':
        return const PemohonDesktopScreen();
      case 'Materai':
        return const LaporanMateraiDesktopScreen();
      case 'Pendapatan':
        return const LaporanPendapatanDesktopScreen();
      case 'Users':
        return const UsersDesktopScreen();
      case 'Groups':
        return const GroupsDesktopScreen();
      case 'Sidebars':
        return const SidebarDesktopScreen();
      case 'Konfigurasi Umum':
        return const KonfigurasiUmumDesktopScreen();
      default:
        return Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            'Halaman $selectedMenu',
            style: const TextStyle(fontSize: 22),
          ),
        );
    }
  }

  Widget _buildScrollableContent() {
    return Container(
      color: AppColors.bgLight,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        child: Column(
          children: [
            _buildContent(),
            const SizedBox(height: 20),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      body: Row(
        children: [
          _buildDesktopSidebar(),
          Expanded(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildScrollableContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildMobileDrawer(),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: Column(
          children: [
            Container(
              color: AppColors.card,
              child: SafeArea(
                bottom: false,
                child: _buildHeader(mobile: true),
              ),
            ),
            Expanded(child: _buildScrollableContent()),
          ],
        ),
      ),
      bottomNavigationBar: _buildMobileBottomNavigation(),
    );
  }

  Widget _buildMobileBottomNavigation() {
    const items = [
      (Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
      (Icons.point_of_sale_outlined, Icons.point_of_sale, 'Transaksi'),
      (Icons.monitor_outlined, Icons.monitor, 'Monitoring'),
    ];

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .05),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            for (int i = 0; i < items.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () => _selectMenu(items[i].$3),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _mobileNavIndex == i ? items[i].$2 : items[i].$1,
                          size: 22,
                          color: _mobileNavIndex == i
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          items[i].$3,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: _mobileNavIndex == i
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: _mobileNavIndex == i
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= desktopBreakpoint) {
          return _buildDesktopLayout();
        }
        return _buildMobileLayout();
      },
    );
  }
}
