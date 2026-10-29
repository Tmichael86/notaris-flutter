import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/widgets/loading_overlay.dart';
import '../core/widgets/searchable_dropdown.dart';
import '../database/app_database.dart';
import '../providers/people_provider.dart';
import '../providers/pekerjaan_provider.dart';

class PemohonDesktopScreen extends ConsumerStatefulWidget {
  const PemohonDesktopScreen({super.key});
  @override
  ConsumerState<PemohonDesktopScreen> createState() =>
      _PemohonDesktopScreenState();
}

class _PemohonDesktopScreenState extends ConsumerState<PemohonDesktopScreen> {
  final _search = TextEditingController();
  final _hScroll = ScrollController();
  final _vScroll = ScrollController();
  final _vScroll = ScrollController();
  static const _pageSize = 10;
  int _page = 1;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(pemohonProvider);
    final genders = ref.watch(jenisKelaminProvider);

    return LoadingOverlay(
      isLoading: _loading,
      message: 'Memproses data...',
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: data.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Gagal memuat data: $e')),
          data: (items) => genders.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('Gagal memuat jenis kelamin: $e')),
            data: (gs) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(),
                const SizedBox(height: 20),
                Expanded(child: _table(items, gs)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pemohon',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Master > Pemohon',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      OutlinedButton.icon(
        onPressed: _loading
            ? null
            : () => _process(
                'Sinkronisasi cloud...',
                () => ref.read(syncCoordinatorProvider).synchronizeNow(),
              ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        icon: const Icon(Icons.sync, size: 18),
        label: const Text('Sinkronkan'),
      ),
      const SizedBox(width: 8),
      FilledButton.icon(
        onPressed: _loading ? null : _showForm,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
    ],
  );
  Widget _table(List<Pemohon> all, List<JenisKelamin> gs) {
    final q = _search.text.trim().toLowerCase();

    final filtered = all.where((x) {
      return q.isEmpty ||
          (x.nik ?? '').toLowerCase().contains(q) ||
          x.nama.toLowerCase().contains(q) ||
          _gender(x.jenisKelamin, gs).toLowerCase().contains(q) ||
          (x.noTelp ?? '').toLowerCase().contains(q);
    }).toList();

    final pageCount = filtered.isEmpty
        ? 1
        : ((filtered.length - 1) ~/ _pageSize) + 1;

    if (_page > pageCount) {
      _page = pageCount;
    }

    final start = (_page - 1) * _pageSize;
    final rows = filtered.skip(start).take(_pageSize).toList();

    return Card(
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    onChanged: (_) {
                      setState(() => _page = 1);
                    },
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Cari NIK, nama, atau no telp...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Text('${filtered.length} data'),
              ],
            ),

            const SizedBox(height: 16),

            Expanded(
              child: Scrollbar(
                controller: _vScroll,
                thumbVisibility: true,
                notificationPredicate: (n) => n.metrics.axis == Axis.vertical,
                child: SingleChildScrollView(
                  controller: _vScroll,
                  child: Scrollbar(
                    controller: _hScroll,
                    thumbVisibility: true,
                    notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
                    child: SingleChildScrollView(
                      controller: _hScroll,
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                  columnSpacing: 28,
                  columns: const [
                    DataColumn(label: Text('No')),
                    DataColumn(label: Text('NIK')),
                    DataColumn(label: Text('Nama')),
                    DataColumn(label: Text('Jenis Kelamin')),
                    DataColumn(label: Text('No Telp')),
                    DataColumn(label: Text('Alamat')),
                    DataColumn(label: Text('Created At')),
                    DataColumn(label: Text('Aksi')),
                  ],
                  rows: [
                    for (var i = 0; i < rows.length; i++)
                      DataRow(
                        cells: [
                          DataCell(Text('${start + i + 1}')),
                          DataCell(Text(rows[i].nik ?? '-')),
                          DataCell(Text(rows[i].nama)),
                          DataCell(Text(_gender(rows[i].jenisKelamin, gs))),
                          DataCell(Text(rows[i].noTelp ?? '-')),
                          DataCell(Text(rows[i].alamat ?? '-')),
                          DataCell(Text(_dateTime(rows[i].createdAt))),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Edit',
                                  onPressed: () {
                                    _showForm(item: rows[i]);
                                  },
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: 'Hapus',
                                  onPressed: () {
                                    _delete(rows[i]);
                                  },
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Belum ada data pemohon.'),
              ),

            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: _page > 1 ? () => setState(() => _page--) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('Halaman $_page / $pageCount'),
                IconButton(
                  onPressed: _page < pageCount
                      ? () => setState(() => _page++)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showForm({Pemohon? item}) {
    String nik = item?.nik ?? '';
    String nama = item?.nama ?? '';
    String telp = item?.noTelp ?? '';
    String alamat = item?.alamat ?? '';

    int? genderId = item?.jenisKelamin;
    final gs = ref.read(jenisKelaminProvider).valueOrNull ?? <JenisKelamin>[];

    String? namaError;
    bool saving = false;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(item == null ? 'Tambah Pemohon' : 'Edit Pemohon'),
          content: SizedBox(
            width: 680,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _row(
                    _field(
                      'NIK',
                      nik,
                      onChanged: (value) => nik = value,
                      type: TextInputType.number,
                      enabled: !saving,
                    ),
                    _field(
                      'Nama *',
                      nama,
                      onChanged: (value) {
                        nama = value;
                        if (namaError != null && value.trim().isNotEmpty) {
                          setDialogState(() => namaError = null);
                        }
                      },
                      errorText: namaError,
                      enabled: !saving,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _row(
                    SearchableDropdown<JenisKelamin>(
                      label: 'Jenis Kelamin',
                      value: _genderObject(genderId, gs),
                      items: gs,
                      itemLabel: (x) => x.nama,
                      onChanged: (value) {
                        if (saving) return;
                        setDialogState(() => genderId = value?.id);
                      },
                      enabled: !saving,
                    ),
                    _field(
                      'Telp',
                      telp,
                      onChanged: (value) => telp = value,
                      type: TextInputType.phone,
                      enabled: !saving,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _field(
                    'Alamat',
                    alamat,
                    onChanged: (value) => alamat = value,
                    maxLines: 4,
                    enabled: !saving,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            FilledButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      if (nama.trim().isEmpty) {
                        setDialogState(() {
                          namaError = 'Nama pemohon wajib diisi.';
                        });
                        return;
                      }

                      setDialogState(() => saving = true);

                      try {
                        final controller = ref.read(
                          pemohonControllerProvider.notifier,
                        );

                        if (item == null) {
                          await controller.create(
                            nama: nama.trim(),
                            nik: nik,
                            jenisKelamin: genderId,
                            noTelp: telp,
                            alamat: alamat,
                          );
                        } else {
                          final ok = await controller.updatePemohon(
                            id: item.id,
                            nama: nama.trim(),
                            nik: nik,
                            jenisKelamin: genderId,
                            noTelp: telp,
                            alamat: alamat,
                          );

                          if (!ok) {
                            throw StateError('Pemohon tidak ditemukan.');
                          }
                        }

                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);

                        _message(
                          item == null
                              ? 'Pemohon berhasil ditambahkan.'
                              : 'Pemohon berhasil diperbarui.',
                        );
                      } catch (error) {
                        if (!dialogContext.mounted) return;

                        setDialogState(() => saving = false);
                        _message('Gagal menyimpan pemohon: $error');
                      }
                    },
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(saving ? 'Menyimpan...' : 'Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(Widget a, Widget b) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(children: [a, const SizedBox(height: 12), b]);
        }
        return Row(
          children: [
            Expanded(child: a),
            const SizedBox(width: 12),
            Expanded(child: b),
          ],
        );
      },
    );
  }

  Widget _field(
    String label,
    String value, {
    required ValueChanged<String> onChanged,
    TextInputType? type,
    int maxLines = 1,
    String? errorText,
    bool enabled = true,
  }) {
    return TextFormField(
      initialValue: value,
      onChanged: onChanged,
      keyboardType: type,
      maxLines: maxLines,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Future<void> _delete(Pemohon item) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Pemohon'),
        content: Text(
          'Hapus pemohon "${item.nama}"? Data akan di-soft delete.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (yes != true) return;

    setState(() => _loading = true);

    try {
      final ok = await ref
          .read(pemohonControllerProvider.notifier)
          .delete(item.id);
      _message(ok ? 'Pemohon berhasil dihapus.' : 'Pemohon tidak ditemukan.');
    } catch (e) {
      _message('Gagal menghapus pemohon: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _process(
    String message,
    Future<void> Function() action,
  ) async {
    if (_loading || !mounted) return;

    setState(() => _loading = true);

    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(message.replaceFirst('...', ' berhasil.')),
            ),
          );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Gagal sinkronisasi: $error'),
              backgroundColor: Colors.red.shade700,
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  static JenisKelamin? _genderObject(int? id, List<JenisKelamin> items) {
    return items.cast<JenisKelamin?>().firstWhere(
      (x) => x?.id == id,
      orElse: () => null,
    );
  }

  static String _gender(int? id, List<JenisKelamin> items) {
    return _genderObject(id, items)?.nama ?? '-';
  }

  static String _dateTime(DateTime? d) {
    if (d == null) return '-';
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return '$day/$month/${d.year} $hour:$minute';
  }

  @override
  void dispose() {
    _search.dispose();
    _hScroll.dispose();
    _vScroll.dispose();
    super.dispose();
  }
}
