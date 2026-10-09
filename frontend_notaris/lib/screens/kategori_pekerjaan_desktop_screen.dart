import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/widgets/loading_overlay.dart';
import '../database/app_database.dart';
import '../providers/pekerjaan_provider.dart';

class KategoriPekerjaanDesktopScreen extends ConsumerStatefulWidget {
  const KategoriPekerjaanDesktopScreen({super.key});

  @override
  ConsumerState<KategoriPekerjaanDesktopScreen> createState() =>
      _KategoriPekerjaanDesktopScreenState();
}

class _KategoriPekerjaanDesktopScreenState
    extends ConsumerState<KategoriPekerjaanDesktopScreen> {
  final _search = TextEditingController();
  final _horizontalScroll = ScrollController();
  final _verticalScroll = ScrollController();
  bool _busy = false;
  String _query = '';
  int _page = 1;
  static const _limit = 10;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(pekerjaanKategoriProvider);
    return LoadingOverlay(
      isLoading: _busy,
      message: 'Memproses data...',
      child: LayoutBuilder(
        builder: (context, c) {
          final mobile = c.maxWidth < 700;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              mobile ? 16 : 28,
              20,
              mobile ? 16 : 28,
              30,
            ),
            child: data.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Gagal memuat data: $e')),
              data: (items) => Column(
                children: [
                  _header(mobile),
                  const SizedBox(height: 18),
                  Expanded(child: _tablePanel(mobile, items)),
                ],
              ),
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
          child: Row(
            children: [
              Text(
                'Kategori Pekerjaan',
                style: TextStyle(
                  fontSize: mobile ? 23 : 26,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (!mobile) ...[
                const SizedBox(width: 14),
                Text(
                  'Master  |  Kategori Pekerjaan',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: _busy ? null : () => _form(),
          icon: const Icon(Icons.add, size: 18),
          label: Text(mobile ? 'Tambah' : 'Tambah Kategori'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryConfirm,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _tablePanel(bool mobile, List<PekerjaanKategori> items) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? items
        : items.where((e) => e.nama.toLowerCase().contains(q)).toList();
    final pages = filtered.isEmpty ? 1 : (filtered.length / _limit).ceil();
    if (_page > pages) _page = pages;

    final start = (_page - 1) * _limit;
    final rows = start >= filtered.length
        ? <PekerjaanKategori>[]
        : filtered.sublist(
            start,
            (start + _limit).clamp(0, filtered.length),
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E5E5)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 8,
            offset: Offset(0, 2),
            color: Color(0x10000000),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: mobile ? double.infinity : 280,
                child: TextField(
                  controller: _search,
                  onChanged: (v) => setState(() {
                    _query = v;
                    _page = 1;
                  }),
                  decoration: InputDecoration(
                    hintText: 'Cari data...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                ),
              ),
              if (!mobile) const Spacer(),
              if (!mobile) Text('${filtered.length} data'),
            ],
          ),
          if (mobile)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('${filtered.length} data'),
              ),
            ),
          const SizedBox(height: 16),
          Expanded(
            child: rows.isEmpty
                ? const Center(child: Text('Belum ada kategori pekerjaan.'))
                : _table(rows),
          ),
          const SizedBox(height: 14),
          _footer(mobile, filtered.length, pages),
        ],
      ),
    );
  }

  Widget _table(List<PekerjaanKategori> rows) {
    return Scrollbar(
      controller: _verticalScroll,
      thumbVisibility: true,
      notificationPredicate: (n) => n.metrics.axis == Axis.vertical,
      child: SingleChildScrollView(
        controller: _verticalScroll,
        child: Scrollbar(
          controller: _horizontalScroll,
          thumbVisibility: true,
          notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
          child: SingleChildScrollView(
            controller: _horizontalScroll,
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 28,
              columns: const [
                DataColumn(label: Text('No')),
                DataColumn(label: Text('Nama')),
                DataColumn(label: Text('Created At')),
                DataColumn(label: Text('Aksi')),
              ],
              rows: List.generate(rows.length, (i) {
                final item = rows[i];
                return DataRow(
                  cells: [
                    DataCell(Text('${(_page - 1) * _limit + i + 1}')),
                    DataCell(
                      SizedBox(
                        width: 300,
                        child: Text(
                          item.nama,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 220,
                        child: Text(_formatDate(item.createdAt)),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edit',
                            onPressed: _busy ? null : () => _form(item: item),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Hapus',
                            onPressed: _busy ? null : () => _delete(item),
                            icon: const Icon(Icons.delete_outline),
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
      ),
    );
  }

  Widget _footer(bool mobile, int total, int pages) {
    final start = total == 0 ? 0 : ((_page - 1) * _limit) + 1;
    final end = total == 0
        ? 0
        : (_page * _limit > total ? total : _page * _limit);
    final text = total == 0
        ? 'Tidak ada data'
        : 'Menampilkan $start-$end dari $total data';

    final buttons = Wrap(
      spacing: 6,
      children: [
        OutlinedButton(
          onPressed: _page > 1 ? () => setState(() => _page--) : null,
          child: const Text('Previous'),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.primaryConfirm,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$_page',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        OutlinedButton(
          onPressed: _page < pages ? () => setState(() => _page++) : null,
          child: const Text('Next'),
        ),
      ],
    );

    return mobile
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text),
              const SizedBox(height: 10),
              buttons,
            ],
          )
        : Row(
            children: [
              Text(text),
              const Spacer(),
              buttons,
            ],
          );
  }

  Future<void> _form({PekerjaanKategori? item}) async {
    final controller = TextEditingController(text: item?.nama ?? '');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          item == null
              ? 'Tambah Kategori Pekerjaan'
              : 'Edit Kategori Pekerjaan',
        ),
        content: SizedBox(
          width: 480,
          child: TextField(
            controller: controller,
            autofocus: true,
            decoration: _decoration('Nama Kategori'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final nama = controller.text.trim();
              if (nama.isEmpty) {
                _validation(dialogContext, 'Nama kategori wajib diisi.');
                return;
              }

              Navigator.pop(dialogContext);

              await _process(
                item == null ? 'Menyimpan data...' : 'Mengubah data...',
                () async {
                  final c =
                      ref.read(pekerjaanKategoriControllerProvider.notifier);
                  if (item == null) {
                    await c.create(nama: nama);
                  } else {
                    final ok = await c.updateCategory(
                      id: item.id,
                      nama: nama,
                    );

                    if (!ok) {
                      throw StateError(
                        'Kategori pekerjaan tidak ditemukan.',
                      );
                    }
                  }
                },
              );
            },
            icon: const Icon(Icons.save_outlined, size: 18),
            label: Text(item == null ? 'Simpan' : 'Simpan Perubahan'),
          ),
        ],
      ),
    );

    controller.dispose();
  }

  Future<void> _delete(PekerjaanKategori item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Peringatan!'),
        content: Text(
          'Apakah Anda yakin ingin menghapus kategori "${item.nama}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tidak'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    await _process('Menghapus data...', () async {
      final deleted = await ref
          .read(pekerjaanKategoriControllerProvider.notifier)
          .delete(item.id);
      if (!deleted) {
        throw StateError('Kategori pekerjaan tidak ditemukan.');
      }
    });
  }

  Future<void> _process(
    String message,
    Future<void> Function() action,
  ) async {
    if (_busy || !mounted) return;

    setState(() => _busy = true);

    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message.replaceFirst('...', ' berhasil.')),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _validation(BuildContext ctx, String message) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '-';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/${value.year} $hour:$minute';
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(7)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    _horizontalScroll.dispose();
    _verticalScroll.dispose();
    super.dispose();
  }
}