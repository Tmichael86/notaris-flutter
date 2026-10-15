import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/loading_overlay.dart';
import '../core/widgets/searchable_dropdown.dart';
import '../database/app_database.dart';
import '../providers/people_provider.dart';

class PemohonDesktopScreen extends ConsumerStatefulWidget{
  const PemohonDesktopScreen({super.key});
  @override ConsumerState<PemohonDesktopScreen> createState()=>_PemohonDesktopScreenState();
}
class _PemohonDesktopScreenState extends ConsumerState<PemohonDesktopScreen>{
  final _search=TextEditingController(),_hScroll=ScrollController();
  static const _pageSize=5;int _page=1;bool _loading=false;

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
                _table(items, gs),
              ],
            ),
          ),
        ),
      ),
    );
  }
  Widget _header()=>Row(children:[
    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Pemohon',style:TextStyle(fontSize:24,fontWeight:FontWeight.w700)),const SizedBox(height:4),Text('Master > Pemohon',style:TextStyle(color:AppColors.textSecondary))])),
    FilledButton.icon(onPressed:_showForm,style:FilledButton.styleFrom(backgroundColor:AppColors.primary,foregroundColor:Colors.white),icon:const Icon(Icons.add),label:const Text('Tambah'))
  ]);
  Widget _table(List<Pemohon> all, List<JenisKelamin> gs) {
  final q = _search.text.trim().toLowerCase();

  final filtered = all.where((x) {
    return q.isEmpty ||
        (x.nik ?? '').toLowerCase().contains(q) ||
        x.nama.toLowerCase().contains(q) ||
        _gender(x.jenisKelamin, gs).toLowerCase().contains(q) ||
        (x.noTelp ?? '').toLowerCase().contains(q);
  }).toList();

  final pageCount =
      filtered.isEmpty ? 1 : ((filtered.length - 1) ~/ _pageSize) + 1;

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

          Scrollbar(
            controller: _hScroll,
            thumbVisibility: true,
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
                        DataCell(
                          Text('${start + i + 1}'),
                        ),
                        DataCell(
                          Text(rows[i].nik ?? '-'),
                        ),
                        DataCell(
                          Text(rows[i].nama),
                        ),
                        DataCell(
                          Text(_gender(rows[i].jenisKelamin, gs)),
                        ),
                        DataCell(
                          Text(rows[i].noTelp ?? '-'),
                        ),
                        DataCell(
                          Text(rows[i].alamat ?? '-'),
                        ),
                        DataCell(
                          Text(_dateTime(rows[i].createdAt)),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Edit',
                                onPressed: () {
                                  _showForm(item: rows[i]);
                                },
                                icon: const Icon(
                                  Icons.edit_outlined,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Hapus',
                                onPressed: () {
                                  _delete(rows[i]);
                                },
                                icon: const Icon(
                                  Icons.delete_outline,
                                ),
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
                onPressed: _page > 1
                    ? () => setState(() => _page--)
                    : null,
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
    final nik = TextEditingController(text: item?.nik ?? '');
    final nama = TextEditingController(text: item?.nama ?? '');
    final telp = TextEditingController(text: item?.noTelp ?? '');
    final alamat = TextEditingController(text: item?.alamat ?? '');

    int? genderId = item?.jenisKelamin;
    final gs = ref.read(jenisKelaminProvider).valueOrNull ?? <JenisKelamin>[];

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
                    _field('NIK', nik, type: TextInputType.number),
                    _field('Nama *', nama),
                  ),
                  const SizedBox(height: 12),
                  _row(
                    SearchableDropdown<JenisKelamin>(
                      label: 'Jenis Kelamin',
                      hint: 'Pilih jenis kelamin',
                      value: _genderObject(genderId, gs),
                      items: gs,
                      itemLabel: (x) => x.nama,
                      onChanged: (v) => setDialogState(() => genderId = v?.id),
                    ),
                    _field('Telp', telp, type: TextInputType.phone),
                  ),
                  const SizedBox(height: 12),
                  _field('Alamat', alamat, maxLines: 4),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            FilledButton.icon(
              onPressed: () async {
                if (nama.text.trim().isEmpty) {
                  _message('Nama pemohon wajib diisi.');
                  return;
                }

                setState(() => _loading = true);

                try {
                  final c = ref.read(pemohonControllerProvider.notifier);

                  if (item == null) {
                    await c.create(
                      nama: nama.text,
                      nik: nik.text,
                      jenisKelamin: genderId,
                      noTelp: telp.text,
                      alamat: alamat.text,
                    );
                  } else {
                    final ok = await c.updatePemohon(
                      id: item.id,
                      nama: nama.text,
                      nik: nik.text,
                      jenisKelamin: genderId,
                      noTelp: telp.text,
                      alamat: alamat.text,
                    );
                    if (!ok) throw StateError('Pemohon tidak ditemukan.');
                  }

                  if (dialogContext.mounted) Navigator.pop(dialogContext);

                  _message(
                    item == null
                        ? 'Pemohon berhasil ditambahkan.'
                        : 'Pemohon berhasil diperbarui.',
                  );
                } catch (e) {
                  _message('Gagal menyimpan pemohon: $e');
                } finally {
                  if (mounted) setState(() => _loading = false);
                }
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Simpan'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      for (final controller in [nik, nama, telp, alamat]) {
        controller.dispose();
      }
    });
  }

  Widget _row(Widget a, Widget b) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            children: [
              a,
              const SizedBox(height: 12),
              b,
            ],
          );
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
    TextEditingController controller, {
    TextInputType? type,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: type,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Future<void> _delete(Pemohon item) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Pemohon'),
        content: Text('Hapus pemohon "${item.nama}"? Data akan di-soft delete.'),
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
      final ok = await ref.read(pemohonControllerProvider.notifier).delete(item.id);
      _message(
        ok ? 'Pemohon berhasil dihapus.' : 'Pemohon tidak ditemukan.',
      );
    } catch (e) {
      _message('Gagal menghapus pemohon: $e');
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
    super.dispose();
  }
}