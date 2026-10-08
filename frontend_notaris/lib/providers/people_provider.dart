
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../repositories/people_repository.dart';
import 'database_provider.dart';

final jenisKelaminRepositoryProvider = Provider<JenisKelaminRepository>((ref) {
  return JenisKelaminRepository(ref.watch(appDatabaseProvider));
});

final jenisKelaminProvider =
    StreamProvider.autoDispose<List<JenisKelamin>>((ref) {
  return ref.watch(jenisKelaminRepositoryProvider).watchAll();
});

final petugasRepositoryProvider = Provider<PetugasRepository>((ref) {
  return PetugasRepository(ref.watch(appDatabaseProvider));
});

final petugasProvider = StreamProvider.autoDispose<List<PetugasLocal>>((ref) {
  return ref.watch(petugasRepositoryProvider).watchAll();
});

final petugasControllerProvider =
    AsyncNotifierProvider<PetugasController, void>(PetugasController.new);

class PetugasController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  PetugasRepository get _repository => ref.read(petugasRepositoryProvider);

  Future<int> create({
    required String nama,
    String? nik,
    String? alamat,
    String? tempatLahir,
    DateTime? tanggalLahir,
    int? jenisKelamin,
    String? noTelp,
    required String email,
    int? userId,
  }) async {
    state = const AsyncLoading();
    try {
      final id = await _repository.create(
        nama: nama, nik: nik, alamat: alamat, tempatLahir: tempatLahir,
        tanggalLahir: tanggalLahir, jenisKelamin: jenisKelamin,
        noTelp: noTelp, email: email, userId: userId,
      );
      state = const AsyncData(null);
      return id;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<bool> updatePetugas({
    required int id,
    required String nama,
    String? nik,
    String? alamat,
    String? tempatLahir,
    DateTime? tanggalLahir,
    int? jenisKelamin,
    String? noTelp,
    required String email,
    int? userId,
  }) async {
    state = const AsyncLoading();
    try {
      final result = await _repository.update(
        id: id, nama: nama, nik: nik, alamat: alamat,
        tempatLahir: tempatLahir, tanggalLahir: tanggalLahir,
        jenisKelamin: jenisKelamin, noTelp: noTelp,
        email: email, userId: userId,
      );
      state = const AsyncData(null);
      return result;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<bool> delete(int id) async {
    state = const AsyncLoading();
    try {
      final result = await _repository.delete(id);
      state = const AsyncData(null);
      return result;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final pemohonRepositoryProvider = Provider<PemohonRepository>((ref) {
  return PemohonRepository(ref.watch(appDatabaseProvider));
});

final pemohonProvider = StreamProvider.autoDispose<List<Pemohon>>((ref) {
  return ref.watch(pemohonRepositoryProvider).watchAll();
});

final pemohonControllerProvider =
    AsyncNotifierProvider<PemohonController, void>(PemohonController.new);

class PemohonController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  PemohonRepository get _repository => ref.read(pemohonRepositoryProvider);

  Future<int> create({
    required String nama,
    String? alamat,
    int? jenisKelamin,
    String? noTelp,
    String? nik,
  }) async {
    state = const AsyncLoading();
    try {
      final id = await _repository.create(
        nama: nama, alamat: alamat, jenisKelamin: jenisKelamin,
        noTelp: noTelp, nik: nik,
      );
      state = const AsyncData(null);
      return id;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<bool> updatePemohon({
    required int id,
    required String nama,
    String? alamat,
    int? jenisKelamin,
    String? noTelp,
    String? nik,
  }) async {
    state = const AsyncLoading();
    try {
      final result = await _repository.update(
        id: id, nama: nama, alamat: alamat,
        jenisKelamin: jenisKelamin, noTelp: noTelp, nik: nik,
      );
      state = const AsyncData(null);
      return result;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<bool> delete(int id) async {
    state = const AsyncLoading();
    try {
      final result = await _repository.delete(id);
      state = const AsyncData(null);
      return result;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
