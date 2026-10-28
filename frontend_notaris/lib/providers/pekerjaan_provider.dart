import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/kategori_pekerjaan_api_service.dart';
import '../services/jenis_pengeluaran_api_service.dart';
import '../services/petugas_api_service.dart';
import '../services/pemohon_api_service.dart';
import '../services/user_api_service.dart';
import '../services/group_api_service.dart';
import '../services/group_sidebar_access_api_service.dart';
import '../services/sidebar_api_service.dart';
import 'authenticated_api_provider.dart';
import '../database/app_database.dart';
import '../repositories/pekerjaan_repository.dart';
import '../repositories/pekerjaan_kategori_repository.dart';
import '../repositories/pengeluaran_jenis_repository.dart';
import 'database_provider.dart';

final pekerjaanNotarisRepositoryProvider = Provider<PekerjaanNotarisRepository>(
  (ref) {
    final database = ref.watch(appDatabaseProvider);
    return PekerjaanNotarisRepository(database.pekerjaanDao);
  },
);

final pekerjaanPpatRepositoryProvider = Provider<PekerjaanPpatRepository>((
  ref,
) {
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

enum SyncStatus { idle, syncing, pending, success, failed }

enum SyncFailureKind {
  offline,
  timeout,
  unauthorized,
  forbidden,
  conflict,
  validation,
  server,
  unknown,
}

class SyncFailure implements Exception {
  const SyncFailure(this.kind, this.userMessage, {this.cause});

  final SyncFailureKind kind;
  final String userMessage;
  final Object? cause;

  @override
  String toString() => userMessage;
}

/// Single-flight coordinator for category push/pull. Future sync triggers should
/// call this provider instead of invoking repository sync methods directly.
class SyncCoordinator {
  SyncCoordinator({
    required this._runSync,
    required this._onStatusChanged,
  });

  final Future<void> Function() _runSync;
  final void Function(SyncStatus) _onStatusChanged;
  Future<void>? _inFlight;

  Future<void> synchronizeNow() {
    final current = _inFlight;
    if (current != null) return current;
    final operation = _run();
    _inFlight = operation;
    return operation;
  }

  Future<void> _run() async {
    try {
      _onStatusChanged(SyncStatus.syncing);
      await _runSync();
      _onStatusChanged(SyncStatus.success);
    } catch (error) {
      final failure = mapSyncFailure(error);
      final canRetry =
          failure.kind == SyncFailureKind.offline ||
          failure.kind == SyncFailureKind.timeout ||
          failure.kind == SyncFailureKind.server;
      _onStatusChanged(canRetry ? SyncStatus.pending : SyncStatus.failed);
      throw failure;
    } finally {
      _inFlight = null;
    }
  }

  static SyncFailure mapSyncFailure(Object error) {
    if (error is SyncFailure) return error;

    if (error is DioException) {
      if (error.type == DioExceptionType.connectionError) {
        return SyncFailure(
          SyncFailureKind.offline,
          'Server tidak dapat dijangkau. Data tetap tersimpan di perangkat.',
          cause: error,
        );
      }

      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return SyncFailure(
          SyncFailureKind.timeout,
          'Koneksi terlalu lama. Perubahan tetap tersimpan dan menunggu sinkronisasi.',
          cause: error,
        );
      }

      final code = error.response?.statusCode;
      if (code == 401) {
        return SyncFailure(
          SyncFailureKind.unauthorized,
          'Sesi login berakhir. Silakan login kembali untuk menyinkronkan data.',
          cause: error,
        );
      }
      if (code == 403) {
        return SyncFailure(
          SyncFailureKind.forbidden,
          'Akun tidak memiliki izin untuk menyinkronkan perubahan ini.',
          cause: error,
        );
      }
      if (code == 409) {
        return SyncFailure(
          SyncFailureKind.conflict,
          'Perubahan bertentangan dengan data di server. Data lokal tetap tersimpan.',
          cause: error,
        );
      }
      if (code == 400 || code == 422) {
        return SyncFailure(
          SyncFailureKind.validation,
          'Data belum dapat disinkronkan. Periksa kembali data yang dimasukkan.',
          cause: error,
        );
      }
      if (code != null && code >= 500) {
        return SyncFailure(
          SyncFailureKind.server,
          'Server sedang bermasalah. Perubahan menunggu untuk disinkronkan.',
          cause: error,
        );
      }
    }

    return SyncFailure(
      SyncFailureKind.unknown,
      'Sinkronisasi belum selesai. Data lokal tetap tersimpan.',
      cause: error,
    );
  }
}

final syncStatusProvider = StateProvider<SyncStatus>((ref) => SyncStatus.idle);

final syncCoordinatorProvider = Provider<SyncCoordinator>((ref) {
  return SyncCoordinator(
    runSync: () async {
      final repository = ref.read(pekerjaanKategoriRepositoryProvider);
      final api = ref.read(kategoriPekerjaanApiServiceProvider);
      await repository.syncToCloud(api);
      final remote = await api.getAllPages();
      await repository.syncFromCloud(remote);
    },
    onStatusChanged: (status) {
      ref.read(syncStatusProvider.notifier).state = status;
    },
  );
});

final pekerjaanKategoriControllerProvider =
    AsyncNotifierProvider<PekerjaanKategoriController, void>(
      PekerjaanKategoriController.new,
    );

final kategoriPekerjaanApiServiceProvider =
    Provider<KategoriPekerjaanApiService>(
      (ref) => KategoriPekerjaanApiService(ref.watch(authenticatedDioProvider)),
    );

final jenisPengeluaranApiServiceProvider = Provider<JenisPengeluaranApiService>(
  (ref) => JenisPengeluaranApiService(ref.watch(authenticatedDioProvider)),
);

final petugasApiServiceProvider = Provider<PetugasApiService>(
  (ref) => PetugasApiService(ref.watch(authenticatedDioProvider)),
);

final pemohonApiServiceProvider = Provider<PemohonApiService>(
  (ref) => PemohonApiService(ref.watch(authenticatedDioProvider)),
);

final userApiServiceProvider = Provider<UserApiService>(
  (ref) => UserApiService(ref.watch(authenticatedDioProvider)),
);

final groupApiServiceProvider = Provider<GroupApiService>(
  (ref) => GroupApiService(ref.watch(authenticatedDioProvider)),
);

final groupSidebarAccessApiServiceProvider =
    Provider<GroupSidebarAccessApiService>(
      (ref) =>
          GroupSidebarAccessApiService(ref.watch(authenticatedDioProvider)),
    );

final sidebarApiServiceProvider = Provider<SidebarApiService>(
  (ref) => SidebarApiService(ref.watch(authenticatedDioProvider)),
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

  Future<bool> updateCategory({
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

  Future<void> synchronize() async {
    state = const AsyncLoading();
    try {
      await ref.read(syncCoordinatorProvider).synchronizeNow();
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> refreshFromCloud() async {
    state = const AsyncLoading();
    try {
      final api = ref.read(kategoriPekerjaanApiServiceProvider);
      final remote = await api.getAllPages();
      await _repository.syncFromCloud(remote);
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}

final pengeluaranJenisRepositoryProvider = Provider<PengeluaranJenisRepository>(
  (ref) {
    final database = ref.watch(appDatabaseProvider);
    return PengeluaranJenisRepository(database);
  },
);

final pengeluaranJenisProvider =
    StreamProvider.autoDispose<List<PengeluaranJenisData>>((ref) {
      final repository = ref.watch(pengeluaranJenisRepositoryProvider);
      return repository.watchAll();
    });

final pengeluaranJenisControllerProvider =
    AsyncNotifierProvider<PengeluaranJenisController, void>(
      PengeluaranJenisController.new,
    );

class PengeluaranJenisController extends AsyncNotifier<void> {
  PengeluaranJenisRepository get _repository =>
      ref.read(pengeluaranJenisRepositoryProvider);

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

  Future<bool> updateJenis({
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

      if (updated) {
        ref.invalidate(pekerjaanPpatAggregateProvider(id));
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
