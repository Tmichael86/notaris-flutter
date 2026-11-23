import 'package:dio/dio.dart';

const officeTextFields = [
  'alamat',
  'telp_rumah',
  'telp_pertama',
  'telp_kedua',
  'email',
  'notaris_bersangkutan',
  'ppat_bersangkutan',
];
const officeAmountFields = [
  'besaran_nilai_tidak_kena_pajak',
  'pengecekan',
  'surat_kuasa_membebankan_hak_tanggungan',
  'ploting_validasi',
  'harga_beli_materai',
  'harga_jual_materai',
];

class OfficeConfiguration {
  OfficeConfiguration.fromJson(Map<String, dynamic> m) {
    if (m['id'] != 1 ||
        m['development_data'] is! bool ||
        m.length != 15 ||
        !m.keys.every(
          (k) => [
            'id',
            'development_data',
            ...officeTextFields,
            ...officeAmountFields,
          ].contains(k),
        )) {
      throw const FormatException('Identitas konfigurasi tidak valid.');
    }
    for (final k in officeTextFields) {
      if (!m.containsKey(k) || (m[k] != null && m[k] is! String)) {
        throw const FormatException('Teks konfigurasi tidak valid.');
      }
      _text[k] = m[k] as String?;
    }
    for (final k in officeAmountFields) {
      final v = m[k];
      if (!m.containsKey(k) ||
          (v != null &&
              (v is! String || !RegExp(r'^(0|[1-9][0-9]*)$').hasMatch(v)))) {
        throw const FormatException('Nominal konfigurasi tidak valid.');
      }
      final n = v == null ? null : BigInt.parse(v as String);
      if (n != null && n > BigInt.parse('18446744073709551615')) {
        throw const FormatException('Nominal di luar batas.');
      }
      _amount[k] = n;
    }
    developmentData = m['development_data'] as bool;
    if (developmentData !=
        (_text['notaris_bersangkutan'] == 'NOTARISDEV SYNTHETIC v1')) {
      throw const FormatException('Konteks konfigurasi tidak valid.');
    }
  }
  final _text = <String, String?>{};
  final _amount = <String, BigInt?>{};
  late final bool developmentData;
  String? text(String key) => _text[key];
  BigInt? amount(String key) => _amount[key];
  String display(String key) {
    if (key == 'notaris_bersangkutan' && developmentData) {
      return 'Data pengembangan · bukan identitas notaris';
    }
    if (officeTextFields.contains(key)) {
      return _text[key] ?? 'Belum diisi';
    }
    final n = _amount[key];
    if (n == null) return 'Belum diisi';
    final digits = n.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return 'Rp $digits';
  }
}

class OfficeConfigurationApiService {
  OfficeConfigurationApiService(this.dio);
  final Dio dio;
  Future<OfficeConfiguration> read() async {
    final raw = (await dio.get<Object?>('/konfigurasi')).data;
    if (raw is! Map || raw['success'] != true || raw['data'] is! Map) {
      throw const FormatException('Response konfigurasi tidak valid.');
    }
    return OfficeConfiguration.fromJson(
      Map<String, dynamic>.from(raw['data'] as Map),
    );
  }
}

String officeConfigurationError(Object e) {
  if (e is DioException) {
    return switch (e.response?.statusCode) {
      401 => 'Sesi berakhir atau dicabut. Silakan login kembali.',
      403 => 'Izin baca Konfigurasi Umum ditolak oleh server.',
      404 =>
        e.response?.data is Map &&
                (e.response!.data as Map)['code'] == 'configuration_missing'
            ? 'Konfigurasi belum tersedia.'
            : 'Endpoint konfigurasi belum tersedia.',
      409 => 'Konfigurasi ambigu. Hubungi administrator.',
      422 => 'Data konfigurasi tidak valid. Hubungi administrator.',
      null =>
        'Backend offline atau tidak dapat dihubungi. Tidak ada data fallback.',
      _ => 'Konfigurasi belum dapat dimuat. Periksa backend lalu Refresh.',
    };
  }
  return 'Response konfigurasi tidak valid. Tidak ada nilai fallback.';
}
