import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/searchable_dropdown.dart';
import 'login_desktop_screen.dart';
import 'transaction_desktop_screen.dart';
import 'monitoring_desktop_screen.dart';
import 'pengeluaran_desktop_screen.dart';
import 'piutang_desktop_screen.dart';
import 'penghasilan_desktop_screen.dart';
import 'pekerjaan_notaris_desktop_screen.dart';
import 'pekerjaan_ppat_desktop_screen.dart';
import 'kategori_pekerjaan_desktop_screen.dart';
import 'jenis_pengeluaran_desktop_screen.dart';
import 'petugas_desktop_screen.dart';
import 'pemohon_desktop_screen.dart';
import 'laporan_materai_desktop_screen.dart';
import 'laporan_pendapatan_desktop_screen.dart';
import 'users_desktop_screen.dart';
import 'groups_desktop_screen.dart';
import 'sidebar_desktop_screen.dart';
import 'konfigurasi_umum_desktop_screen.dart';

class DashboardStat {
  final String title;
  final int value;
  final IconData icon;

  const DashboardStat(this.title, this.value, this.icon);
}

class DashboardDesktopScreen extends StatefulWidget {
  const DashboardDesktopScreen({super.key});

  @override
  State<DashboardDesktopScreen> createState() => _DashboardDesktopScreenState();
}

class _DashboardDesktopScreenState extends State<DashboardDesktopScreen>
    with SingleTickerProviderStateMixin {
  static const double desktopBreakpoint = 1000;

  String selectedMenu = 'Dashboard';
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String _selectedYear = DateTime.now().year.toString();

  /// Prototype source for the year selector.
  /// When the API is connected, this can be replaced by years returned by the backend.
  List<String> get _availableYears {
    final currentYear = DateTime.now().year;
    return List.generate(5, (index) => (currentYear - index).toString());
  }
  late final AnimationController _dashboardController;

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

  @override
  void initState() {
    super.initState();
    _dashboardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _dashboardController.dispose();
    super.dispose();
  }

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

  void _selectMenu(String title) {
    setState(() => selectedMenu = title);
    _scaffoldKey.currentState?.closeDrawer();

    if (title == 'Dashboard') {
      _dashboardController
        ..reset()
        ..forward();
    }
  }

  Widget _buildHeader({bool mobile = false}) {
    return Container(
      height: mobile ? 58 : 60,
      padding: EdgeInsets.symmetric(horizontal: mobile ? 12 : 24),
      color: AppColors.card,
      child: Row(
        children: [
          if (mobile) ...[
            IconButton(
              tooltip: 'Menu',
              icon: const Icon(Icons.menu),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            const SizedBox(width: 2),
            const Text(
              'Mikro Notaris',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
          ] else
            const Spacer(),
          const Text(
            'SUPER ADMIN',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: .5,
            ),
          ),
          const SizedBox(width: 8),
          if (!mobile)
            IconButton(
              tooltip: 'Fullscreen',
              icon: const Icon(
                Icons.open_in_full,
                size: 18,
                color: Colors.black54,
              ),
              onPressed: () {},
            ),
          PopupMenuButton<String>(
            offset: const Offset(0, 50),
            child: const CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFFE0E0E0),
              child: Icon(Icons.person, color: AppColors.textSecondary),
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
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _desktopItem(
    String title,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    final selected = selectedMenu == title;

    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor:
            selected ? AppColors.primary : Colors.black87,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
      ),
      icon: Icon(icon, size: 16),
      label: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }

  Widget _desktopDropdown(
    String title,
    IconData icon,
    List<String> items,
  ) {
    final selected = items.contains(selectedMenu);

    return PopupMenuButton<String>(
      offset: const Offset(0, 42),
      onSelected: _selectMenu,
      itemBuilder: (_) => items
          .map(
            (item) => PopupMenuItem<String>(
              value: item,
              child: Text(item),
            ),
          )
          .toList(),
      child: TextButton.icon(
        onPressed: null,
        style: TextButton.styleFrom(
          foregroundColor:
              selected ? AppColors.primary : Colors.black87,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
        ),
        icon: Icon(icon, size: 16),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.keyboard_arrow_down, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopNavigation() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(
          top: BorderSide(color: AppColors.border),
          bottom: BorderSide(color: AppColors.border),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .03),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _desktopItem(
                'Dashboard',
                Icons.home,
                onTap: () => _selectMenu('Dashboard'),
              ),
              _desktopItem(
                'Transaksi',
                Icons.point_of_sale,
                onTap: () => _selectMenu('Transaksi'),
              ),
              _desktopItem(
                'Monitoring',
                Icons.desktop_windows,
                onTap: () => _selectMenu('Monitoring'),
              ),
              _desktopItem(
                'Pengeluaran',
                Icons.request_quote,
                onTap: () => _selectMenu('Pengeluaran'),
              ),
              _desktopItem(
                'Piutang',
                Icons.description,
                onTap: () => _selectMenu('Piutang'),
              ),
              _desktopItem(
                'Penghasilan',
                Icons.attach_money,
                onTap: () => _selectMenu('Penghasilan'),
              ),
              _desktopDropdown('Master', Icons.view_list, masterMenus),
              _desktopDropdown('Laporan', Icons.flag, laporanMenus),
              _desktopDropdown('System', Icons.settings, systemMenus),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobileItem(String title, IconData icon) {
    final selected = selectedMenu == title;

    return ListTile(
      dense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
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

  Widget _mobileExpansion(
    String title,
    IconData icon,
    List<String> items,
  ) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: EdgeInsets.zero,
      leading: Icon(
        icon,
        size: 20,
        color: AppColors.textPrimary,
      ),
      iconColor: AppColors.textPrimary,
      collapsedIconColor: AppColors.textPrimary,
      textColor: AppColors.textPrimary,
      collapsedTextColor: AppColors.textPrimary,
      backgroundColor: Colors.transparent,
      collapsedBackgroundColor: Colors.transparent,
      shape: const Border(),
      collapsedShape: const Border(),
      maintainState: true,
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w400,
        ),
      ),
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
                'Mikro Notaris',
                style: TextStyle(
                  color: AppColors.card,
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                physics: const ClampingScrollPhysics(),
                children: [
                  _mobileItem('Dashboard', Icons.home),
                  _mobileItem('Transaksi', Icons.point_of_sale),
                  _mobileItem('Monitoring', Icons.desktop_windows),
                  _mobileItem('Pengeluaran', Icons.request_quote),
                  _mobileItem('Piutang', Icons.description),
                  _mobileItem('Penghasilan', Icons.attach_money),
                  const Divider(height: 1, color: AppColors.divider),
                  _mobileExpansion('Master', Icons.view_list, masterMenus),
                  _mobileExpansion('Laporan', Icons.flag, laporanMenus),
                  _mobileExpansion('System', Icons.settings, systemMenus),
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F1F1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/images/logoblitaris.png',
            width: 52,
            height: 52,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '© Copyright Blitaris Tekno',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              SizedBox(height: 4),
              Text(
                'All rights reserved',
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    int value,
    IconData icon, {
    int animationIndex = 0,
  }) {
    final endValue = value;
    final start = (animationIndex * 0.08).clamp(0.0, 0.24);
    final end = (start + 0.65).clamp(0.0, 1.0);

    final animation = CurvedAnimation(
      parent: _dashboardController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final offset = 18 * (1 - animation.value);
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, offset),
            child: child,
          ),
        );
      },
      child: Container(
        height: 158,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 44, color: AppColors.primary),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.primary,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                final currentValue = (endValue * animation.value).round();
                return Text(
                  currentValue.toString(),
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w300,
                    color: AppColors.primary,
                    height: 1,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(String title, Widget chart) {
    return Container(
      height: 185,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Expanded(child: chart),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < desktopBreakpoint;
        final padding = mobile ? 16.0 : 28.0;

        // Mock data only. Keep this shape identical to the future API response.
        final stats = const [
          DashboardStat('Pemohon', 2038, Icons.people_outline),
          DashboardStat('Total Transaksi', 1, Icons.receipt_long_outlined),
          DashboardStat('Transaksi Belum Selesai', 0, Icons.pending_actions_outlined),
          DashboardStat('Transaksi Selesai', 1, Icons.task_alt_outlined),
        ];

        return Padding(
          padding: EdgeInsets.fromLTRB(padding, 22, padding, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flex(
                direction: mobile ? Axis.vertical : Axis.horizontal,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dashboard',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Dashboard  |  Page',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  if (mobile) const SizedBox(height: 14),
                  SizedBox(
                    width: mobile ? double.infinity : 120,
                    height: 36,
                    child: SearchableDropdown<String>(
                      value: _selectedYear,
                      items: _availableYears,
                      label: 'Tahun',
                      hint: 'Pilih tahun',
                      itemLabel: (year) => year,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedYear = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 28),
              if (mobile)
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final data in stats)
                      SizedBox(
                        width: (constraints.maxWidth - (padding * 2) - 16) / 2,
                        child: _buildStatCard(
                          data.title,
                          data.value,
                          data.icon,
                          animationIndex: stats.indexOf(data),
                        ),
                      ),
                  ],
                )
              else
                Row(
                  children: [
                    for (int i = 0; i < stats.length; i++) ...[
                      if (i > 0) const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          stats[i].title,
                          stats[i].value,
                          stats[i].icon,
                        ),
                      ),
                    ],
                  ],
                ),
              const SizedBox(height: 24),
              if (mobile) ...[
                _buildChartCard('Grafik Transaksi', const _LineChart()),
                const SizedBox(height: 16),
                _buildChartCard('Grafik Pemohon', const _ApplicantChart()),
                const SizedBox(height: 16),
                _buildLargeComparisonCard(),
                const SizedBox(height: 16),
                _buildDonutCard(),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildChartCard(
                        'Grafik Transaksi',
                        const _LineChart(),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _buildChartCard(
                        'Grafik Pemohon',
                        const _ApplicantChart(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildLargeComparisonCard(),
                    ),
                    const SizedBox(width: 24),
                    Expanded(child: _buildDonutCard()),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildLargeComparisonCard() {
    return Container(
      height: 330,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Grafik Perbandingan Transaksi',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: CustomPaint(
              painter: _BarChartPainter(),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonutCard() {
    return Container(
      height: 330,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Perbandingan Pemohon Dan Transaksi',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 15),
          Expanded(
            child: Center(
              child: CustomPaint(
                size: Size(220, 220),
                painter: _DonutPainter(),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildContent() {
    switch (selectedMenu) {
      case 'Dashboard':
        return _buildDashboard();
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
          child: SizedBox(
            width: double.infinity,
            child: Text(
              'Halaman $selectedMenu',
              style: const TextStyle(fontSize: 22),
            ),
          ),
        );
    }
  }

  Widget _buildScrollableContent() {
    return Container(
      color: AppColors.bgLight,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
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
      body: Column(
        children: [
          _buildHeader(),
          _buildDesktopNavigation(),
          Expanded(child: _buildScrollableContent()),
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
                child: Column(
                  children: [
                    _buildHeader(mobile: true),
                    const Divider(height: 1, color: AppColors.divider),
                  ],
                ),
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
          border: Border(
            top: BorderSide(color: AppColors.border),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .06),
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
                          _mobileNavIndex == i
                              ? items[i].$2
                              : items[i].$1,
                          size: 22,
                          color: _mobileNavIndex == i
                              ? AppColors.primary
                              : Colors.black54,
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
                                ? AppColors.selectedMenuText
                                : Colors.black54,
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


class _LineChart extends StatelessWidget {
  const _LineChart();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _LineChartPainter(), child: const SizedBox.expand());
}

class _ApplicantChart extends StatelessWidget {
  const _ApplicantChart();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _ApplicantChartPainter(), child: const SizedBox.expand());
}

class _LineChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()..color = AppColors.primary..strokeWidth = 2..style = PaintingStyle.stroke;
    final fillPaint = Paint()..color = AppColors.primary.withValues(alpha: 0.08)..style = PaintingStyle.fill;
    final path = Path();
    final points = [
      Offset(0, size.height * .90), Offset(size.width * .10, size.height * .90),
      Offset(size.width * .25, size.height * .90), Offset(size.width * .40, size.height * .90),
      Offset(size.width * .55, size.height * .90), Offset(size.width * .70, size.height * .90),
      Offset(size.width * .82, size.height * .90), Offset(size.width, size.height * .15),
    ];
    path.moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) path.lineTo(point.dx, point.dy);
    final fillPath = Path.from(path)..lineTo(size.width, size.height)..lineTo(0, size.height)..close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ApplicantChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.primary..strokeWidth = 2..style = PaintingStyle.stroke;
    final path = Path()..moveTo(0, size.height * .92);
    for (int i = 1; i <= 10; i++) path.lineTo(size.width * (i / 10), size.height * .92);
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BarChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()..color = Colors.grey.withValues(alpha: .25)..strokeWidth = 1;
    final barPaint = Paint()..color = AppColors.primary..style = PaintingStyle.fill;
    for (int i = 0; i <= 5; i++) {
      final y = size.height * (i / 5);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    const values = [.18, .28, .42, .30, .55, .40, .68, .48, .75, .62, .82, .70];
    final barWidth = size.width / 20;
    for (int i = 0; i < values.length; i++) {
      final x = i * (size.width / values.length) + 10;
      final height = size.height * values[i];
      canvas.drawRect(Rect.fromLTWH(x, size.height - height, barWidth, height), barPaint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 10;
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 28;
    const segments = [.55, .20, .15, .10];
    final colors = [
      AppColors.primary,
      AppColors.primaryDark,
      AppColors.textSecondary,
      AppColors.border,
    ];
    double startAngle = -1.5708;
    for (int i = 0; i < segments.length; i++) {
      paint.color = colors[i];
      final sweep = segments[i] * 6.28318;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweep, false, paint);
      startAngle += sweep;
    }
    final centerPaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 30, centerPaint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
