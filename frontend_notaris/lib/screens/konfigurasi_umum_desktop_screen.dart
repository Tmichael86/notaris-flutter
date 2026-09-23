import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/loading_overlay.dart';

class KonfigurasiUmumDesktopScreen extends StatefulWidget {
  const KonfigurasiUmumDesktopScreen({super.key});

  @override
  State<KonfigurasiUmumDesktopScreen> createState() =>
      _KonfigurasiUmumDesktopScreenState();
}

class _KonfigurasiUmumDesktopScreenState
    extends State<KonfigurasiUmumDesktopScreen> {
  bool _isLoading = false;

  final Map<String, TextEditingController> _controllers = {};

  final List<_ConfigItem> _configItems = const [
    _ConfigItem('Alamat', 'alamat', 'Jl. Contoh No. 123, Kota Blitar', false),
    _ConfigItem('Telepon Rumah', 'telp_rumah', '0342-123456', false),
    _ConfigItem('Telepon Pertama', 'telp_pertama', '081234567890', false),
    _ConfigItem('Telepon Kedua', 'telp_kedua', '081298765432', false),
    _ConfigItem('Email', 'email', 'info@blitaris.id', false),
    _ConfigItem(
      'Cetak: Dari Notaris Bersangkutan',
      'notaris_bersangkutan',
      'Ya',
      false,
    ),
    _ConfigItem(
      'Cetak: Dari PPAT Bersangkutan',
      'ppat_bersangkutan',
      'Ya',
      false,
    ),
    _ConfigItem(
      'Nilai Besaran Tidak Kena Pajak',
      'besaran_nilai_tidak_kena_pajak',
      '60000000',
      true,
    ),
    _ConfigItem(
      'Nilai Pajak Pengecekan',
      'pengecekan',
      '100000',
      true,
    ),
    _ConfigItem(
      'Nilai Pajak SKMHT',
      'surat_kuasa_membebankan_hak_tanggungan',
      '150000',
      true,
    ),
    _ConfigItem(
      'Ploting Validasi',
      'ploting_validasi',
      '50000',
      true,
    ),
    _ConfigItem(
      'Harga Beli Materai',
      'harga_beli_materai',
      '10000',
      true,
    ),
    _ConfigItem(
      'Harga Jual Materai',
      'harga_jual_materai',
      '10000',
      true,
    ),
  ];

  @override
  void initState() {
    super.initState();

    for (final item in _configItems) {
      _controllers[item.key] = TextEditingController(text: item.value);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _showEditDialog() async {
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final width = MediaQuery.sizeOf(dialogContext).width;
        final isMobile = width < 650;

        return AlertDialog(
          title: const Text(
            'Ubah Nilai Konfigurasi',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          content: SizedBox(
            width: isMobile ? width * 0.9 : 700,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  children: _configItems.map((item) {
                    final controller = _controllers[item.key]!;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: TextFormField(
                        controller: controller,
                        keyboardType: item.isMoney
                            ? TextInputType.number
                            : TextInputType.text,
                        maxLines: item.key == 'alamat' ? 2 : 1,
                        decoration: InputDecoration(
                          labelText: item.label,
                          hintText: 'Masukkan ${item.label.toLowerCase()}',
                          prefixText: item.isMoney ? 'Rp ' : null,
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: AppColors.primary),
                          ),
                        ),
                        validator: (value) {
                          if (item.isMoney &&
                              value != null &&
                              value.trim().isNotEmpty &&
                              double.tryParse(value.trim()) == null) {
                            return 'Nilai harus berupa angka';
                          }
                          return null;
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'Batal',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(dialogContext, true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );

    if (result == true && mounted) {
      setState(() => _isLoading = true);

      await Future.delayed(const Duration(milliseconds: 700));

      if (mounted) {
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Konfigurasi berhasil diperbarui.'),
          ),
        );
      }
    }
  }

  String _displayValue(_ConfigItem item) {
    final value = _controllers[item.key]?.text.trim() ?? '';

    if (value.isEmpty) {
      return '-';
    }

    if (item.isMoney) {
      return 'Rp ${_formatNumber(value)}';
    }

    return value;
  }

  String _formatNumber(String value) {
    final number = int.tryParse(value.replaceAll('.', ''));
    if (number == null) return value;

    final digits = number.toString();
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[i]);
    }

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      message: 'Menyimpan konfigurasi...',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 700;

          return SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isMobile),
                const SizedBox(height: 20),
                _buildCard(isMobile),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Konfigurasi Umum',
          style: TextStyle(
            fontSize: isMobile ? 22 : 26,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'System  >  Konfigurasi Umum',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildCard(bool isMobile) {
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
          if (isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nilai Konfigurasi',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _editButton(),
              ],
            )
          else
            Row(
              children: [
                const Text(
                  'Nilai Konfigurasi',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                _editButton(),
              ],
            ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 8),
          _buildConfigTable(isMobile),
        ],
      ),
    );
  }

  Widget _editButton() {
    return ElevatedButton.icon(
      onPressed: _showEditDialog,
      icon: const Icon(Icons.edit_outlined, size: 18),
      label: const Text('Ubah Nilai'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildConfigTable(bool isMobile) {
    if (isMobile) {
      return Column(
        children: _configItems.map((item) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.divider),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _displayValue(item),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(1.2),
        1: FlexColumnWidth(2.2),
      },
      children: _configItems.map((item) {
        return TableRow(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.divider),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 15,
              ),
              child: Text(
                item.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 15,
              ),
              child: Text(
                _displayValue(item),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _ConfigItem {
  final String label;
  final String key;
  final String value;
  final bool isMoney;

  const _ConfigItem(
    this.label,
    this.key,
    this.value,
    this.isMoney,
  );
}
