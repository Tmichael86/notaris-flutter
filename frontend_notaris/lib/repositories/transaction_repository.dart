import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';

/// Input for one selected Notaris/PPAT job in a transaction.
class TransactionJobInput {
  const TransactionJobInput({
    required this.jenisPekerjaan,
    required this.namaPekerjaan,
    required this.biayaLayanan,
    this.biayaLainnya = 0,
    this.pekerjaanNotarisId,
    this.pekerjaanPpatId,
    this.kategoriSnapshot,
    this.estimasiWaktuSnapshot,
  });

  /// Must be either 'notaris' or 'ppat'.
  final String jenisPekerjaan;
  final String namaPekerjaan;
  final int? pekerjaanNotarisId;
  final int? pekerjaanPpatId;
  final String? kategoriSnapshot;
  final String? estimasiWaktuSnapshot;
  final double biayaLayanan;
  final double biayaLainnya;

  double get total => biayaLayanan + biayaLainnya;
}

/// Local-first persistence for transaction headers and their job details.
class TransactionRepository {
  TransactionRepository(this.db);

  final AppDatabase db;
  static const _uuid = Uuid();

  Stream<List<Transaksi>> watchAll() {
    return (db.select(db.transaksis)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<Transaksi?> findById(int id) {
    return (db.select(db.transaksis)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .getSingleOrNull();
  }

  Future<List<TransaksiDetail>> watchDetailsOnce(int transactionId) {
    return (db.select(db.transaksiDetails)
          ..where((t) =>
              t.transaksiId.equals(transactionId) &
              t.deletedAt.isNull() &
              t.status.equals(1)))
        .get();
  }

  /// Saves the header and all selected jobs atomically.
  /// Job prices and labels are persisted as snapshots to protect history from
  /// later edits to Master pricing.
  Future<int> save({
    int? id,
    required String nomorTransaksi,
    required String jenisTransaksi,
    required int pemohonId,
    required String pemohonUuid,
    required int petugasId,
    required String petugasUuid,
    required String status,
    required DateTime tanggalTransaksi,
    DateTime? tanggalJatuhTempo,
    required List<TransactionJobInput> jobs,
    double diskon = 0,
    double pembayaranSekarang = 0,
    String metodePembayaran = 'Cash',
    int jumlahMaterai = 0,
    String? catatan,
  }) async {
    if (jobs.isEmpty) {
      throw ArgumentError('Transaksi harus memiliki minimal satu pekerjaan.');
    }
    if (jenisTransaksi != 'notaris' && jenisTransaksi != 'ppat') {
      throw ArgumentError('Jenis transaksi harus notaris atau ppat.');
    }
    for (final job in jobs) {
      if (job.jenisPekerjaan != jenisTransaksi) {
        throw ArgumentError(
          'Semua pekerjaan dalam satu transaksi harus bertipe '
          '${jenisTransaksi.toUpperCase()}.',
        );
      }
      if (job.jenisPekerjaan == 'notaris' &&
          job.pekerjaanNotarisId == null) {
        throw ArgumentError('Referensi pekerjaan Notaris wajib diisi.');
      }
      if (job.jenisPekerjaan == 'ppat' && job.pekerjaanPpatId == null) {
        throw ArgumentError('Referensi pekerjaan PPAT wajib diisi.');
      }
    }

    final now = DateTime.now();
    final totalPekerjaan = jobs.fold<double>(0, (sum, job) => sum + job.total);
    final totalBersih = (totalPekerjaan - diskon).clamp(0, double.infinity);

return db.transaction(() async {
      final transactionId = id ??
          await db.into(db.transaksis).insert(
                TransaksisCompanion.insert(
                  uuid: _uuid.v4(),
                  noAkta: nomorTransaksi.trim(),
                  total: totalBersih.toDouble(),
                  pemohonId: Value(pemohonId),
                  pemohonUuid: Value(pemohonUuid),
                  petugasId: Value(petugasId),
                  petugasUuid: Value(petugasUuid),
                  jenisTransaksi: Value(jenisTransaksi),
                  statusTransaksi: Value(status),
                  tanggalTransaksi: Value(tanggalTransaksi),
                  tanggalJatuhTempo: Value(tanggalJatuhTempo),
                  diskon: Value(diskon),
                  pembayaranSekarang: Value(pembayaranSekarang),
                  metodePembayaran: Value(metodePembayaran),
                  jumlahMaterai: Value(jumlahMaterai),
                  catatan: Value(_nullableText(catatan)),
                  createdAt: Value(now),
                  updatedAt: Value(now),
                  isSyncDirty: const Value(true),
                ),
              );

      if (id != null) {
        final affected = await (db.update(db.transaksis)
              ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
            .write(
          TransaksisCompanion(
            noAkta: Value(nomorTransaksi.trim()),
            total: Value(totalBersih.toDouble()),
            pemohonId: Value(pemohonId),
            pemohonUuid: Value(pemohonUuid),
            petugasId: Value(petugasId),
            petugasUuid: Value(petugasUuid),
            jenisTransaksi: Value(jenisTransaksi),
            statusTransaksi: Value(status),
            tanggalTransaksi: Value(tanggalTransaksi),
            tanggalJatuhTempo: Value(tanggalJatuhTempo),
            diskon: Value(diskon),
            pembayaranSekarang: Value(pembayaranSekarang),
            metodePembayaran: Value(metodePembayaran),
            jumlahMaterai: Value(jumlahMaterai),
            catatan: Value(_nullableText(catatan)),
            updatedAt: Value(now),
            isSyncDirty: const Value(true),
          ),
        );
        if (affected == 0) {
          throw StateError('Transaksi tidak ditemukan atau sudah dihapus.');
        }

        await (db.update(db.transaksiDetails)
              ..where((t) =>
                  t.transaksiId.equals(id) & t.deletedAt.isNull()))
            .write(
          TransaksiDetailsCompanion(
            status: const Value(0),
            deletedAt: Value(now),
            updatedAt: Value(now),
            isSyncDirty: const Value(true),
          ),
        );
      }

      for (final job in jobs) {
        await db.into(db.transaksiDetails).insert(
              TransaksiDetailsCompanion.insert(
                uuid: _uuid.v4(),
                transaksiId: transactionId,
                jenisPekerjaan: job.jenisPekerjaan,
                pekerjaanNotarisId: Value(job.pekerjaanNotarisId),
                pekerjaanPpatId: Value(job.pekerjaanPpatId),
                namaPekerjaanSnapshot: job.namaPekerjaan,
                kategoriSnapshot: Value(job.kategoriSnapshot),
                estimasiWaktuSnapshot: Value(job.estimasiWaktuSnapshot),
                biayaLayanan: Value(job.biayaLayanan),
                biayaLainnya: Value(job.biayaLainnya),
                totalSnapshot: Value(job.total),
                createdAt: Value(now),
                updatedAt: Value(now),
                isSyncDirty: const Value(true),
              ),
            );
      }
      return transactionId;
    });
  }

  Future<bool> delete(int id) async {
    final now = DateTime.now();
    return db.transaction(() async {
      final affected = await (db.update(db.transaksis)
            ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
          .write(
        TransaksisCompanion(
          statusTransaksi: const Value('Dihapus'),
          deletedAt: Value(now),
          updatedAt: Value(now),
          isSyncDirty: const Value(true),
        ),
      );
      if (affected == 0) return false;
      await (db.update(db.transaksiDetails)
            ..where((t) =>
                t.transaksiId.equals(id) & t.deletedAt.isNull()))
          .write(
        TransaksiDetailsCompanion(
          status: const Value(0),
          deletedAt: Value(now),
          updatedAt: Value(now),
          isSyncDirty: const Value(true),
        ),
      );
      return true;
    });
  }

  static String? _nullableText(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
