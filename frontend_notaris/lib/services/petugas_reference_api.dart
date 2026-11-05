import 'package:dio/dio.dart';

import 'petugas_sync_api.dart';

class PetugasGenderReference {
  const PetugasGenderReference(this.serverId, this.label);
  final int serverId;
  final String label; // Display only; never used as canonical matching key.
}

class PetugasReferenceApi {
  PetugasReferenceApi(this.dio);
  final Dio dio;
  Future<List<PetugasGenderReference>> genders() async {
    final response = await dio.get<Object?>(
      '/petugas/references/jenis-kelamin',
    );
    final envelope = syncMap(response.data);
    final items = syncMap(envelope['data'])['items'];
    if (envelope['success'] != true || items is! List) {
      throw const FormatException('Invalid gender catalog');
    }
    final seen = <int>{};
    return items.map((value) {
      final row = syncMap(value);
      final id = row['id'];
      if (id is! int ||
          id < 1 ||
          row['nama'] is! String ||
          row['status'] != 1 ||
          !seen.add(id)) {
        throw const FormatException('Invalid or ambiguous gender catalog');
      }
      return PetugasGenderReference(id, row['nama'] as String);
    }).toList();
  }
}
