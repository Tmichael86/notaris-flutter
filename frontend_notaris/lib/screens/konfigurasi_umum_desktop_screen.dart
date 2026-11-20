import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/widgets/master_data_viewport.dart';
import '../core/widgets/promotional_preview.dart';
import '../providers/auth_provider.dart';
import '../providers/office_configuration_provider.dart';
import '../services/office_configuration_api_service.dart';

class KonfigurasiUmumDesktopScreen extends ConsumerWidget {
  const KonfigurasiUmumDesktopScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permitted =
        allowsOfficeConfiguration(ref.watch(authControllerProvider).session) &&
        context.dependOnInheritedWidgetOfExactType<PromotionalPreview>() ==
            null;
    final data = permitted ? ref.watch(officeConfigurationProvider) : null;
    return MasterDataViewport(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Konfigurasi Umum',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'System > Konfigurasi Umum · Baca Saja',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
              OutlinedButton.icon(
                key: const Key('office-refresh'),
                onPressed: !permitted || data?.isLoading == true
                    ? null
                    : () => ref.invalidate(officeConfigurationProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: !permitted
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Konfigurasi Umum memerlukan sesi online yang valid dan izin baca konfigurasi. Data offline tidak tersedia.',
                        ),
                      ),
                    )
                  : data!.when(
                      skipLoadingOnRefresh: false,
                      data: (v) => _OfficeValues(v),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(officeConfigurationError(e)),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

const _sections = <String, Map<String, String>>{
  'Identitas dan Kontak Kantor': {
    'alamat': 'Alamat',
    'telp_rumah': 'Telepon Rumah',
    'telp_pertama': 'Telepon Pertama',
    'telp_kedua': 'Telepon Kedua',
    'email': 'Email',
  },
  'Identitas Pengirim': {
    'notaris_bersangkutan': 'Dari Notaris Bersangkutan',
    'ppat_bersangkutan': 'Dari PPAT Bersangkutan',
  },
  'Referensi Pajak dan Biaya': {
    'besaran_nilai_tidak_kena_pajak': 'Nilai Besaran Tidak Kena Pajak',
    'pengecekan': 'Nilai Pajak Pengecekan',
    'surat_kuasa_membebankan_hak_tanggungan': 'Nilai Pajak SKMHT',
    'ploting_validasi': 'Ploting Validasi',
  },
  'Harga Materai': {
    'harga_beli_materai': 'Harga Beli Materai',
    'harga_jual_materai': 'Harga Jual Materai',
  },
};

class _OfficeValues extends StatelessWidget {
  const _OfficeValues(this.value);
  final OfficeConfiguration value;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: const Key('office-values'),
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          value.developmentData
              ? 'Lingkungan pengembangan · identitas contoh bukan identitas pejabat resmi.'
              : 'Sumber: konfigurasi kantor pada server · Baca Saja',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        for (final section in _sections.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 22, bottom: 8),
            child: Text(
              section.key,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (final field in section.value.entries)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: LayoutBuilder(
                builder: (context, c) {
                  final label = Text(
                    field.value,
                    style: const TextStyle(color: AppColors.textSecondary),
                  );
                  final text = SelectableText(
                    value.display(field.key),
                    key: Key('office-${field.key}'),
                  );
                  return c.maxWidth < 600
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [label, const SizedBox(height: 5), text],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 300, child: label),
                            const SizedBox(width: 20),
                            Expanded(child: text),
                          ],
                        );
                },
              ),
            ),
        ],
      ],
    ),
  );
}
