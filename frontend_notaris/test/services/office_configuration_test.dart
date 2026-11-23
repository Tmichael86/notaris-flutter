import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_notaris/models/auth_session.dart';
import 'package:frontend_notaris/providers/office_configuration_provider.dart';
import 'package:frontend_notaris/services/office_configuration_api_service.dart';

import 'administration_auth_test.dart' show session;
import 'group_sidebar_access_api_service_test.dart'
    show AccessFakeAdapter, accessReply;

Map<String, dynamic> officeData() => {
  'id': 1,
  'development_data': true,
  for (final k in officeTextFields) k: 'Nilai $k',
  for (final k in officeAmountFields) k: '0',
  'notaris_bersangkutan': 'NOTARISDEV SYNTHETIC v1',
  'telp_pertama': null,
  'surat_kuasa_membebankan_hak_tanggungan': null,
  'besaran_nilai_tidak_kena_pajak': '18446744073709551615',
};
AuthSession officeSession({
  bool read = true,
  bool offline = false,
  bool duplicate = false,
  String code = 'konfigurasi',
}) {
  final s = session(role: 'user', offline: offline);
  final grant = {
    'sidebar': {
      'sidebar_kode': code,
      'sidebar_nama': 'Konfigurasi Umum',
      'status': 1,
    },
    'read': read ? 1 : 0,
  };
  return AuthSession(
    token: s.token,
    userId: s.userId,
    groupId: s.groupId,
    userName: s.userName,
    groupName: s.groupName,
    groupType: s.groupType,
    user: s.user,
    isOffline: offline,
    verifiedAt: s.verifiedAt,
    sidebars: [grant, if (duplicate) grant],
  );
}

void main() {
  test(
    'GET only, lossless 13 fields, null is not zero, marker is not signer',
    () async {
      final dio = Dio()
        ..httpClientAdapter = AccessFakeAdapter((r) async {
          expect(r.method, 'GET');
          expect(r.path, '/konfigurasi');
          return accessReply(officeData());
        });
      final v = await OfficeConfigurationApiService(dio).read();
      expect(
        v.amount('besaran_nilai_tidak_kena_pajak'),
        BigInt.parse('18446744073709551615'),
      );
      expect(
        v.display('besaran_nilai_tidak_kena_pajak'),
        'Rp 18.446.744.073.709.551.615',
      );
      expect(v.display('pengecekan'), 'Rp 0');
      expect(v.display('telp_pertama'), 'Belum diisi');
      expect(
        v.display('notaris_bersangkutan'),
        contains('bukan identitas notaris'),
      );
    },
  );
  test(
    'strict malformed fields and range rejected; no numeric floating fallback',
    () {
      for (final bad in [
        -1,
        1.5,
        0,
        '-1',
        '1.5',
        '01',
        '1e3',
        '18446744073709551616',
        true,
      ]) {
        expect(
          () => OfficeConfiguration.fromJson({
            ...officeData(),
            'pengecekan': bad,
          }),
          throwsFormatException,
        );
      }
      for (final k in [...officeTextFields, ...officeAmountFields]) {
        final m = officeData()..remove(k);
        expect(() => OfficeConfiguration.fromJson(m), throwsFormatException);
      }
      expect(
        () => OfficeConfiguration.fromJson({
          ...officeData(),
          'development_data': false,
        }),
        throwsFormatException,
      );
    },
  );
  test('canonical explicit online READ, no alias or role shortcut', () {
    expect(allowsOfficeConfiguration(officeSession()), isTrue);
    for (final s in [
      null,
      officeSession(read: false),
      officeSession(offline: true),
      officeSession(duplicate: true),
      officeSession(code: 'konfigurasi_umum'),
    ]) {
      expect(allowsOfficeConfiguration(s), isFalse);
    }
  });
}
