import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/widgets/loading_overlay.dart';
import '../core/widgets/searchable_dropdown.dart';
import '../database/app_database.dart';
import '../providers/people_provider.dart';
import '../core/widgets/petugas_manual_sync_panel.dart';

class PetugasDesktopScreen extends ConsumerStatefulWidget {
  const PetugasDesktopScreen({super.key});

  @override
  ConsumerState<PetugasDesktopScreen> createState() =>
      _PetugasDesktopScreenState();
}

class _PetugasDesktopScreenState extends ConsumerState<PetugasDesktopScreen> {
  final _search = TextEditingController();
  final _hScroll = ScrollController();
  final _vScroll = ScrollController();
  static const _pageSize = 10;
  int _page = 1;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(petugasProvider);
    final genders = ref.watch(jenisKelaminProvider);

    return LoadingOverlay(
      isLoading: _loading,
      message: 'Memproses data...',
      child: SizedBox(
        height: (MediaQuery.sizeOf(context).height - 210).clamp(360.0, double.infinity),
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
                const PetugasManualSyncPanel(),
                const SizedBox(height: 20),
                Expanded(child: _table(items, gs)),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Petugas',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Master > Petugas',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: _showForm,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.add),
          label: const Text('Tambah'),
        ),
      ],
    );
  }

  Widget _table(List<PetugasLocal> all, List<JenisKelamin> gs) {
    final q = _search.text.trim().toLowerCase();
    final filtered = all.where((x) {
      return q.isEmpty ||
          (x.nik ?? '').toLowerCase().contains(q) ||
          x.nama.toLowerCase().contains(q) ||
          _gender(x.jenisKelamin, gs).toLowerCase().contains(q) ||
          x.email.toLowerCase().contains(q) ||
          (x.noTelp ?? '').toLowerCase().contains(q);
    }).toList();

    final pageCount = filtered.isEmpty
        ? 1
        : ((filtered.length - 1) ~/ _pageSize) + 1;
    if (_page > pageCount) _page = pageCount;

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
                    onChanged: (_) => setState(() => _page = 1),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Cari NIK, nama, email, atau no telp...',
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
                    DataColumn(label: Text('Email')),
                    DataColumn(label: Text('No Telp')),
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
                          DataCell(Text(rows[i].email)),
                          DataCell(Text(rows[i].noTelp ?? '-')),
                          DataCell(Text(_dateTime(rows[i].createdAt))),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Edit',
                                  onPressed: () => _showForm(item: rows[i]),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: 'Hapus',
                                  onPressed: () => _delete(rows[i]),
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
                child: Text('Belum ada data petugas.'),
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

  Future<void> _showForm({PetugasLocal? item}) async {
    String nik = item?.nik ?? '';
    String nama = item?.nama ?? '';
    String tempat = item?.tempatLahir ?? '';
    String telp = item?.noTelp ?? '';
    String email = item?.email ?? '';
    String alamat = item?.alamat ?? '';
    String userId = item?.userId?.toString() ?? '';

    DateTime? tanggal = item?.tanggalLahir;
    int? genderId = item?.jenisKelamin;
    final gs = ref.read(jenisKelaminProvider).valueOrNull ?? <JenisKelamin>[];

    String? namaError;
    String? emailError;
    String? userIdError;
    bool saving = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> savePetugas() async {
            final normalizedNama = nama.trim();
            final normalizedEmail = email.trim();
            final normalizedUserId = userId.trim();

            setDialogState(() {
              namaError = normalizedNama.isEmpty
                  ? 'Nama petugas wajib diisi.'
                  : null;
              emailError = normalizedEmail.isEmpty
                  ? 'Email wajib diisi.'
                  : null;
              userIdError =
                  normalizedUserId.isNotEmpty &&
                      int.tryParse(normalizedUserId) == null
                  ? 'User ID harus berupa angka.'
                  : null;
            });

            if (namaError != null ||
                emailError != null ||
                userIdError != null) {
              return;
            }

            setDialogState(() => saving = true);

            try {
              final c = ref.read(petugasControllerProvider.notifier);
              final uid = normalizedUserId.isEmpty
                  ? null
                  : int.parse(normalizedUserId);

              if (item == null) {
                await c.create(
                  nama: normalizedNama,
                  nik: nik,
                  alamat: alamat,
                  tempatLahir: tempat,
                  tanggalLahir: tanggal,
                  jenisKelamin: genderId,
                  noTelp: telp,
                  email: normalizedEmail,
                  userId: uid,
                );
              } else {
                final ok = await c.updatePetugas(
                  id: item.id,
                  nama: normalizedNama,
                  nik: nik,
                  alamat: alamat,
                  tempatLahir: tempat,
                  tanggalLahir: tanggal,
                  jenisKelamin: genderId,
                  noTelp: telp,
                  email: normalizedEmail,
                  userId: uid,
                );

                if (!ok) {
                  throw StateError('Petugas tidak ditemukan.');
                }
              }

              if (dialogContext.mounted) {
                Navigator.pop(dialogContext, true);
              }
            } catch (error) {
              if (dialogContext.mounted) {
                setDialogState(() => saving = false);
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text('Gagal menyimpan petugas: $error')),
                );
              }
            }
          }

          return AlertDialog(
            title: Text(item == null ? 'Tambah Petugas' : 'Edit Petugas'),
            content: SizedBox(
              width: 760,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _row(
                      _textField(
                        'NIK',
                        nik,
                        onChanged: (v) => nik = v,
                        type: TextInputType.number,
                        enabled: !saving,
                      ),
                      _textField(
                        'Nama *',
                        nama,
                        onChanged: (v) {
                          nama = v;
                          if (namaError != null) {
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
                        onChanged: (v) {
                          if (saving) return;
                          setDialogState(() {
                            genderId = v?.id;
                          });
                        },
                      ),
                      _textField(
                        'Tempat Lahir',
                        tempat,
                        onChanged: (v) => tempat = v,
                        enabled: !saving,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _row(
                      _dateField(
                        tanggal,
                        (v) => setDialogState(() => tanggal = v),
                      ),
                      _textField(
                        'Telp',
                        telp,
                        onChanged: (v) => telp = v,
                        type: TextInputType.phone,
                        enabled: !saving,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _row(
                      _textField(
                        'Email *',
                        email,
                        onChanged: (v) {
                          email = v;
                          if (emailError != null) {
                            setDialogState(() => emailError = null);
                          }
                        },
                        errorText: emailError,
                        type: TextInputType.emailAddress,
                        enabled: !saving,
                      ),
                      _textField(
                        'User ID',
                        userId,
                        onChanged: (v) {
                          userId = v;
                          if (userIdError != null) {
                            setDialogState(() => userIdError = null);
                          }
                        },
                        errorText: userIdError,
                        type: TextInputType.number,
                        helper:
                            'Opsional. Master User belum tersedia di SQLite.',
                        enabled: !saving,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _textField(
                      'Alamat',
                      alamat,
                      onChanged: (v) => alamat = v,
                      maxLines: 4,
                      enabled: !saving,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving
                    ? null
                    : () => Navigator.pop(dialogContext, false),
                child: const Text('Batal'),
              ),
              FilledButton.icon(
                onPressed: saving ? null : savePetugas,
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
          );
        },
      ),
    );

    if (saved != true || !mounted) return;

    _message(
      item == null
          ? 'Petugas berhasil ditambahkan.'
          : 'Petugas berhasil diperbarui.',
    );
  }

  Widget _textField(
    String label,
    String value, {
    required ValueChanged<String> onChanged,
    TextInputType? type,
    int maxLines = 1,
    String? helper,
    String? errorText,
    bool enabled = true,
  }) {
    return TextFormField(
      key: ValueKey('petugas-$label'),
      initialValue: value,
      onChanged: onChanged,
      keyboardType: type,
      maxLines: maxLines,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        errorText: errorText,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _row(Widget a, Widget b) {
    return LayoutBuilder(
      builder: (context, c) => c.maxWidth < 560
          ? Column(children: [a, const SizedBox(height: 12), b])
          : Row(
              children: [
                Expanded(child: a),
                const SizedBox(width: 12),
                Expanded(child: b),
              ],
            ),
    );
  }

  Widget _dateField(DateTime? value, ValueChanged<DateTime?> onChanged) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime(2000),
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Tanggal Lahir',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.calendar_today_outlined),
        ),
        child: Text(value == null ? 'Pilih tanggal' : _date(value)),
      ),
    );
  }

  Future<void> _delete(PetugasLocal item) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Petugas'),
        content: Text(
          'Hapus petugas "${item.nama}"? Data akan di-soft delete.',
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
          .read(petugasControllerProvider.notifier)
          .delete(item.id);
      _message(ok ? 'Petugas berhasil dihapus.' : 'Petugas tidak ditemukan.');
    } catch (e) {
      _message('Gagal menghapus petugas: $e');
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

  static String _gender(int? id, List<JenisKelamin> items) =>
      _genderObject(id, items)?.nama ?? '-';

  static String _date(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '$day/$month/${d.year}';
  }

  static String _dateTime(DateTime? d) {
    if (d == null) return '-';
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return '${_date(d)} $hour:$minute';
  }

  @override
  void dispose() {
    _search.dispose();
    _hScroll.dispose();
    _vScroll.dispose();
    super.dispose();
  }
}
