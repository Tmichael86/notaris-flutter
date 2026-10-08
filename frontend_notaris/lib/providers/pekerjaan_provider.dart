import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../repositories/pekerjaan_repository.dart';
import '../repositories/pekerjaan_kategori_repository.dart';
import 'database_provider.dart';

final pekerjaanNotarisRepositoryProvider =
    Provider<PekerjaanNotarisRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return PekerjaanNotarisRepository(database.pekerjaanDao);
});

final pekerjaanPpatRepositoryProvider =
    Provider<PekerjaanPpatRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return PekerjaanPpatRepository(database.pekerjaanDao);
});

final pekerjaanNotarisProvider =
    StreamProvider.autoDispose<List<PekerjaanNotarisLocal>>((ref) {
  final repository = ref.watch(pekerjaanNotarisRepositoryProvider);
  return repository.watchAll();
});

final pekerjaanPpatProvider =
    StreamProvider.autoDispose<List<PekerjaanPpatLocal>>((ref) {
  final repository = ref.watch(pekerjaanPpatRepositoryProvider);
  return repository.watchAll();
});

final pekerjaanKategoriRepositoryProvider =
    Provider<PekerjaanKategoriRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return PekerjaanKategoriRepository(database);
});

final pekerjaanKategoriProvider =
    StreamProvider.autoDispose<List<PekerjaanKategori>>((ref) {
  final repository = ref.watch(pekerjaanKategoriRepositoryProvider);
  return repository.watchAll();
});

final pekerjaanKategoriControllerProvider =
    AsyncNotifierProvider<PekerjaanKategoriController, void>(
  PekerjaanKategoriController.new,
);

class PekerjaanKategoriController extends AsyncNotifier<void> {
  PekerjaanKategoriRepository get _repository =>
      ref.read(pekerjaanKategoriRepositoryProvider);

  @override
  Future<void> build() async {}

  Future<int> create({required String nama, int? createdBy}) async {
    state = const AsyncLoading();
    try {
      final id = await _repository.create(nama: nama, createdBy: createdBy);
      state = const AsyncData(null);
      return id;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<bool> update({
    required int id,
    required String nama,
    int? updatedBy,
  }) async {
    state = const AsyncLoading();
    try {
      final updated = await _repository.update(
        id: id,
        nama: nama,
        updatedBy: updatedBy,
      );
      state = const AsyncData(null);
      return updated;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<bool> delete(int id) async {
    state = const AsyncLoading();
    try {
      final deleted = await _repository.delete(id);
      state = const AsyncData(null);
      return deleted;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}


final pekerjaanNotarisAggregateProvider = FutureProvider.autoDispose
    .family<PekerjaanAggregateData?, int>((ref, id) {
  final repository = ref.watch(pekerjaanNotarisRepositoryProvider);
  return repository.getAggregate(id);
});

final pekerjaanPpatAggregateProvider = FutureProvider.autoDispose
    .family<PekerjaanAggregateData?, int>((ref, id) {
  final repository = ref.watch(pekerjaanPpatRepositoryProvider);
  return repository.getAggregate(id);
});

final pekerjaanNotarisControllerProvider =
    AsyncNotifierProvider<PekerjaanNotarisController, void>(
  PekerjaanNotarisController.new,
);

final pekerjaanPpatControllerProvider =
    AsyncNotifierProvider<PekerjaanPpatController, void>(
  PekerjaanPpatController.new,
);

class PekerjaanNotarisController extends AsyncNotifier<void> {
  PekerjaanNotarisRepository get _repository =>
      ref.read(pekerjaanNotarisRepositoryProvider);

  @override
  Future<void> build() async {}

  Future<int> create({
    required PekerjaanAggregateInput input,
    int? createdBy,
  }) async {
    state = const AsyncLoading();

    try {
      final id = await _repository.createAggregate(
        input: input,
        createdBy: createdBy,
      );
      state = const AsyncData(null);
      return id;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<bool> updateAggregate({
    required int id,
    required PekerjaanAggregateInput input,
    int? updatedBy,
  }) async {
    state = const AsyncLoading();

    try {
      final updated = await _repository.updateAggregate(
        id: id,
        input: input,
        updatedBy: updatedBy,
      );

      // The table stream updates the parent row, but the aggregate shown
      // in each table cell is cached by its FutureProvider.family.
      // Invalidate the edited aggregate so its child harga/proses data is
      // read again immediately after the transaction commits.
      if (updated) {
        ref.invalidate(pekerjaanNotarisAggregateProvider(id));
      }

      state = const AsyncData(null);
      return updated;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<bool> delete(int id) async {
    state = const AsyncLoading();

    try {
      final deleted = await _repository.deleteAggregate(id);
      state = const AsyncData(null);
      return deleted;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}

class PekerjaanPpatController extends AsyncNotifier<void> {
  PekerjaanPpatRepository get _repository =>
      ref.read(pekerjaanPpatRepositoryProvider);

  @override
  Future<void> build() async {}

  Future<int> create({
    required PekerjaanAggregateInput input,
    int? createdBy,
  }) async {
    state = const AsyncLoading();

    try {
      final id = await _repository.createAggregate(
        input: input,
        createdBy: createdBy,
      );
      state = const AsyncData(null);
      return id;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<bool> updateAggregate({
    required int id,
    required PekerjaanAggregateInput input,
    int? updatedBy,
  }) async {
    state = const AsyncLoading();

    try {
      final updated = await _repository.updateAggregate(
        id: id,
        input: input,
        updatedBy: updatedBy,
      );

      state = const AsyncData(null);
      return updated;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<bool> delete(int id) async {
    state = const AsyncLoading();

    try {
      final deleted = await _repository.deleteAggregate(id);
      state = const AsyncData(null);
      return deleted;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}
