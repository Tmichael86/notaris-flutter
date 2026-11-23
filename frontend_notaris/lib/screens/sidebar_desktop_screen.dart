import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/widgets/sync_presentation.dart' show syncLocalTime;

import '../core/theme/app_colors.dart';
import '../core/widgets/master_data_viewport.dart';
import '../core/widgets/promotional_preview.dart';
import '../providers/auth_provider.dart';
import '../providers/sidebar_catalog_provider.dart';
import '../services/sidebar_api_service.dart';

class SidebarDesktopScreen extends ConsumerStatefulWidget {
  const SidebarDesktopScreen({super.key});
  @override
  ConsumerState<SidebarDesktopScreen> createState() => _SidebarState();
}

class _SidebarState extends ConsumerState<SidebarDesktopScreen> {
  final search = TextEditingController(),
      horizontal = ScrollController(),
      vertical = ScrollController();
  int page = 1;
  String status = 'all', text = '';
  SidebarCatalogQuery get query => (page: page, search: text, status: status);
  void submit(String value) => setState(() {
    text = value.trim();
    page = 1;
  });
  @override
  void dispose() {
    search.dispose();
    horizontal.dispose();
    vertical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider).session;
    if (context.dependOnInheritedWidgetOfExactType<PromotionalPreview>() !=
            null ||
        !allowsSidebarCatalog(session)) {
      return const Padding(
        padding: EdgeInsets.all(28),
        child: Text(
          'Sidebars memerlukan sesi online yang valid dan izin baca Sidebars. Katalog offline tidak tersedia.',
        ),
      );
    }
    final result = ref.watch(sidebarCatalogProvider(query));
    return MasterDataViewport(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sidebars',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'System > Sidebars · Katalog online baca saja',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
              OutlinedButton.icon(
                key: const Key('sidebars-refresh'),
                onPressed: () => ref.invalidate(sidebarCatalogProvider(query)),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
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
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 300,
                        child: TextField(
                          key: const Key('sidebars-search'),
                          controller: search,
                          onSubmitted: submit,
                          decoration: InputDecoration(
                            labelText:
                                'Cari nama, kode, route, parent, ikon atau ID',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: IconButton(
                              tooltip: 'Cari',
                              onPressed: () => submit(search.text),
                              icon: const Icon(Icons.arrow_forward),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 175,
                        child: DropdownButtonFormField<String>(
                          key: const Key('sidebars-status'),
                          initialValue: status,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'all',
                              child: Text('Semua'),
                            ),
                            DropdownMenuItem(
                              value: 'active',
                              child: Text('Aktif'),
                            ),
                            DropdownMenuItem(
                              value: 'inactive',
                              child: Text('Nonaktif'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() {
                                status = v;
                                page = 1;
                              });
                            }
                          },
                        ),
                      ),
                      Text(
                        result.asData == null
                            ? 'Jumlah belum tersedia'
                            : '${result.asData!.value.total} definisi',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: result.when(
                      skipLoadingOnRefresh: false,
                      skipLoadingOnReload: false,
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(
                        child: Text(
                          sidebarCatalogError(e),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      data: (d) => d.items.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.menu_book_outlined,
                                    size: 32,
                                  ),
                                  const Text(
                                    'Tidak ada definisi Sidebars yang cocok.',
                                  ),
                                  if (page > 1)
                                    TextButton(
                                      onPressed: () => setState(() => page = 1),
                                      child: const Text('Halaman pertama'),
                                    ),
                                ],
                              ),
                            )
                          : MasterDataTableViewport(
                              horizontalController: horizontal,
                              verticalController: vertical,
                              child: DataTable(
                                headingRowColor: const WidgetStatePropertyAll(
                                  Color(0xfff2f3f5),
                                ),
                                columnSpacing: 24,
                                dataRowMinHeight: 56,
                                dataRowMaxHeight: 66,
                                columns: [
                                  for (final label in [
                                    'No.',
                                    'Nama Menu',
                                    'Parent',
                                    'Route',
                                    'Kode',
                                    'Urutan',
                                    'Ikon',
                                    'Status',
                                    'Dibuat Pada',
                                  ])
                                    DataColumn(label: Text(label)),
                                ],
                                rows: [
                                  for (final (i, r) in d.items.indexed)
                                    DataRow(
                                      key: ValueKey('sidebar-${r.id}'),
                                      cells: [
                                        DataCell(
                                          Text(
                                            '${(d.page - 1) * d.pageSize + i + 1}',
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: 180,
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                _text(r.name),
                                                Text(
                                                  'ID ${r.id}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: 210,
                                            child: _text(r.parentLabel),
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: 190,
                                            child: _text(r.route),
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: 185,
                                            child: _text(r.code),
                                          ),
                                        ),
                                        DataCell(
                                          Text(r.order?.toString() ?? '—'),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: 170,
                                            child: Row(
                                              children: [
                                                Icon(
                                                  sidebarReferenceIcon(r.icon),
                                                  size: 18,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(child: _text(r.icon)),
                                              ],
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            r.statusLabel,
                                            style: TextStyle(
                                              color: r.status == 1
                                                  ? AppColors.success
                                                  : AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: 215,
                                            child: _text(
                                              sidebarCatalogTimestamp(r),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          result.asData == null
                              ? 'Halaman belum tersedia'
                              : 'Halaman ${result.asData!.value.page} / ${result.asData!.value.totalPages} · ${result.asData!.value.total} definisi',
                        ),
                      ),
                      IconButton(
                        key: const Key('sidebars-previous'),
                        tooltip: 'Halaman sebelumnya',
                        onPressed:
                            !result.isLoading &&
                                result.asData != null &&
                                page > 1
                            ? () => setState(() => page--)
                            : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      IconButton(
                        key: const Key('sidebars-next'),
                        tooltip: 'Halaman berikutnya',
                        onPressed:
                            !result.isLoading &&
                                result.asData != null &&
                                page < result.asData!.value.totalPages
                            ? () => setState(() => page++)
                            : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _text(String? raw) {
    final value = raw == null || raw.isEmpty ? '—' : raw;
    return Tooltip(
      message: value,
      child: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }
}

// Display-only references; unknown values retain their exact raw label.
String sidebarCatalogTimestamp(SidebarCatalogItem r) {
  if (r.createdAtRaw == null) {
    return 'Belum tersedia';
  }
  if (RegExp(r'(Z|[+-][0-9]{2}:[0-9]{2})$').hasMatch(r.createdAtRaw!)) {
    return syncLocalTime(r.createdAt);
  }
  return '${r.createdAtRaw!.replaceFirst('T', ' ')} · tanpa zona waktu';
}

IconData sidebarReferenceIcon(String? name) => switch (name) {
  'folder' || 'fa-folder' => Icons.folder_outlined,
  'people' || 'fa-users' => Icons.people_outline,
  'groups' => Icons.groups_outlined,
  'menu' || 'fa-bars' => Icons.menu,
  'badge' => Icons.badge_outlined,
  'person' || 'fa-user' => Icons.person_outline,
  'archive' => Icons.archive_outlined,
  _ => Icons.help_outline,
};
