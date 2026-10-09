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

  /// Generates the legacy Laravel number format locally.
  /// Laravel uses: type code + 2-digit user id + ddmmyy + 4-digit sequence.
  /// Until local authentication exists, "00" is reserved as the offline user
  /// segment. Scan all records, including soft-deleted rows, so a number is
  /// never reused after a transaction is deleted.
  Future<String> generateNextTransactionNumber({
    required String jenisTransaksi,
    required DateTime date,
  }) async {
    if (jenisTransaksi != 'notaris' && jenisTransaksi != 'ppat') {
      throw ArgumentError('Jenis transaksi harus notaris atau ppat.');
    }
    final typeCode = jenisTransaksi == 'notaris' ? '1' : '2';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = (date.year % 100).toString().padLeft(2, '0');
    final dateCode = '$day$month$year';
    final rows = await db.select(db.transaksis).get();
    final sequencePattern = RegExp(r'^\\d{3}\\d{6}(\\d{4})$');
    var maxSequence = 0;
    for (final row in rows) {
      final match = sequencePattern.firstMatch(row.noAkta);
      if (match == null) continue;
      final sequence = int.tryParse(match.group(1) ?? '') ?? 0;
      if (sequence > maxSequence) maxSequence = sequence;
    }
    final nextSequence = (maxSequence + 1).toString().padLeft(4, '0');
    return '$typeCode' '00$dateCode$nextSequence';
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

      // A payment entered during transaction creation must also become
      // an auditable history row. Editing an existing transaction must not
      // duplicate the same payment on every save.
      if (id == null && pembayaranSekarang > 0) {
        await db.into(db.transaksiRiwayatPembayarans).insert(
          TransaksiRiwayatPembayaransCompanion.insert(
            uuid: _uuid.v4(),
            transaksiId: transactionId,
            tanggalPembayaran: tanggalTransaksi,
            nominal: pembayaranSekarang,
            metodePembayaran: Value(metodePembayaran),
            keterangan: const Value('Pembayaran awal saat transaksi dibuat'),
            urutanPembayaran: const Value(1),
            createdAt: Value(now),
            updatedAt: Value(now),
            isSyncDirty: const Value(true),
          ),
        );
      }

      if (id != null) {
        final existingPayments = await getPaymentHistory(id);
        final totalPaid = existingPayments.fold<double>(
          0,
          (sum, payment) => sum + payment.nominal,
        );
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
            pembayaranSekarang: Value(totalPaid),
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

  /// Returns active payment history entries ordered by payment date.
  Future<List<TransaksiRiwayatPembayaran>> getPaymentHistory(int transactionId) {
    return (db.select(db.transaksiRiwayatPembayarans)
          ..where((p) => p.transaksiId.equals(transactionId) & p.deletedAt.isNull() & p.status.equals(1))
          ..orderBy([(p) => OrderingTerm.asc(p.tanggalPembayaran), (p) => OrderingTerm.asc(p.urutanPembayaran)]))
        .get();
  }

  /// Adds an installment as its own auditable record.
  Future<int> addPayment({
    required int transactionId,
    required DateTime paymentDate,
    required double amount,
    String method = 'Cash',
    String? note,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Nominal pembayaran harus lebih dari Rp 0.');
    }

    return db.transaction(() async {
      final transaction = await findById(transactionId);
      if (transaction == null) {
        throw StateError('Transaksi tidak ditemukan.');
      }

      final history = await getPaymentHistory(transactionId);
      final paid = history.fold<double>(0, (sum, item) => sum + item.nominal);
      if (paid + amount > transaction.total) {
        throw ArgumentError(
          'Nominal pembayaran melebihi sisa tagihan '
          'Rp ${(transaction.total - paid).clamp(0, double.infinity).toStringAsFixed(0)}.',
        );
      }

      final now = DateTime.now();
      final paymentId = await db.into(db.transaksiRiwayatPembayarans).insert(
        TransaksiRiwayatPembayaransCompanion.insert(
          uuid: _uuid.v4(),
          transaksiId: transactionId,
          tanggalPembayaran: paymentDate,
          nominal: amount,
          metodePembayaran: Value(method),
          keterangan: Value(_nullableText(note)),
          urutanPembayaran: Value(history.length + 1),
          createdAt: Value(now),
          updatedAt: Value(now),
          isSyncDirty: const Value(true),
        ),
      );

      await (db.update(db.transaksis)
            ..where((t) => t.id.equals(transactionId)))
          .write(
        TransaksisCompanion(
          pembayaranSekarang: Value(paid + amount),
          metodePembayaran: Value(method),
          updatedAt: Value(now),
          isSyncDirty: const Value(true),
        ),
      );

      return paymentId;
    });
  }

  Future<bool> deletePayment(int paymentId) async {
    final payment = await (db.select(db.transaksiRiwayatPembayarans)
          ..where((p) => p.id.equals(paymentId) & p.deletedAt.isNull()))
        .getSingleOrNull();
    if (payment == null) return false;
    final now = DateTime.now();
    await (db.update(db.transaksiRiwayatPembayarans)..where((p) => p.id.equals(paymentId))).write(
      TransaksiRiwayatPembayaransCompanion(
        status: const Value(0),
        deletedAt: Value(now),
        updatedAt: Value(now),
        isSyncDirty: const Value(true),
      ),
    );
    final history = await getPaymentHistory(payment.transaksiId);
    final paid = history.fold<double>(0, (sum, item) => sum + item.nominal);
    await (db.update(db.transaksis)..where((t) => t.id.equals(payment.transaksiId))).write(
      TransaksisCompanion(
        pembayaranSekarang: Value(paid),
        updatedAt: Value(now),
        isSyncDirty: const Value(true),
      ),
    );
    return true;
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
);
    var maxSequence = 0;
    for (final row in rows) {
      final match = sequencePattern.firstMatch(row.noAkta);
      if (match == null) continue;
      final sequence = int.tryParse(match.group(1) ?? '') ?? 0;
      if (sequence > maxSequence) maxSequence = sequence;
    }
    final nextSequence = (maxSequence + 1).toString().padLeft(4, '0');
    return '$typeCode' '00$dateCode$nextSequence';
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

      // A payment entered during transaction creation must also become
      // an auditable history row. Editing an existing transaction must not
      // duplicate the same payment on every save.
      if (id == null && pembayaranSekarang > 0) {
        await db.into(db.transaksiRiwayatPembayarans).insert(
          TransaksiRiwayatPembayaransCompanion.insert(
            uuid: _uuid.v4(),
            transaksiId: transactionId,
            tanggalPembayaran: tanggalTransaksi,
            nominal: pembayaranSekarang,
            metodePembayaran: Value(metodePembayaran),
            keterangan: const Value('Pembayaran awal saat transaksi dibuat'),
            urutanPembayaran: const Value(1),
            createdAt: Value(now),
            updatedAt: Value(now),
            isSyncDirty: const Value(true),
          ),
        );
      }

      if (id != null) {
        final existingPayments = await getPaymentHistory(id);
        final totalPaid = existingPayments.fold<double>(
          0,
          (sum, payment) => sum + payment.nominal,
        );
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
            pembayaranSekarang: Value(totalPaid),
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

  /// Returns active payment history entries ordered by payment date.
  Future<List<TransaksiRiwayatPembayaran>> getPaymentHistory(int transactionId) {
    return (db.select(db.transaksiRiwayatPembayarans)
          ..where((p) => p.transaksiId.equals(transactionId) & p.deletedAt.isNull() & p.status.equals(1))
          ..orderBy([(p) => OrderingTerm.asc(p.tanggalPembayaran), (p) => OrderingTerm.asc(p.urutanPembayaran)]))
        .get();
  }

  /// Adds an installment as its own auditable record.
  Future<int> addPayment({
    required int transactionId,
    required DateTime paymentDate,
    required double amount,
    String method = 'Cash',
    String? note,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Nominal pembayaran harus lebih dari Rp 0.');
    }

    return db.transaction(() async {
      final transaction = await findById(transactionId);
      if (transaction == null) {
        throw StateError('Transaksi tidak ditemukan.');
      }

      final history = await getPaymentHistory(transactionId);
      final paid = history.fold<double>(0, (sum, item) => sum + item.nominal);
      if (paid + amount > transaction.total) {
        throw ArgumentError(
          'Nominal pembayaran melebihi sisa tagihan '
          'Rp ${(transaction.total - paid).clamp(0, double.infinity).toStringAsFixed(0)}.',
        );
      }

      final now = DateTime.now();
      final paymentId = await db.into(db.transaksiRiwayatPembayarans).insert(
        TransaksiRiwayatPembayaransCompanion.insert(
          uuid: _uuid.v4(),
          transaksiId: transactionId,
          tanggalPembayaran: paymentDate,
          nominal: amount,
          metodePembayaran: Value(method),
          keterangan: Value(_nullableText(note)),
          urutanPembayaran: Value(history.length + 1),
          createdAt: Value(now),
          updatedAt: Value(now),
          isSyncDirty: const Value(true),
        ),
      );

      await (db.update(db.transaksis)
            ..where((t) => t.id.equals(transactionId)))
          .write(
        TransaksisCompanion(
          pembayaranSekarang: Value(paid + amount),
          metodePembayaran: Value(method),
          updatedAt: Value(now),
          isSyncDirty: const Value(true),
        ),
      );

      return paymentId;
    });
  }

  Future<bool> deletePayment(int paymentId) async {
    final payment = await (db.select(db.transaksiRiwayatPembayarans)
          ..where((p) => p.id.equals(paymentId) & p.deletedAt.isNull()))
        .getSingleOrNull();
    if (payment == null) return false;
    final now = DateTime.now();
    await (db.update(db.transaksiRiwayatPembayarans)..where((p) => p.id.equals(paymentId))).write(
      TransaksiRiwayatPembayaransCompanion(
        status: const Value(0),
        deletedAt: Value(now),
        updatedAt: Value(now),
        isSyncDirty: const Value(true),
      ),
    );
    final history = await getPaymentHistory(payment.transaksiId);
    final paid = history.fold<double>(0, (sum, item) => sum + item.nominal);
    await (db.update(db.transaksis)..where((t) => t.id.equals(payment.transaksiId))).write(
      TransaksisCompanion(
        pembayaranSekarang: Value(paid),
        updatedAt: Value(now),
        isSyncDirty: const Value(true),
      ),
    );
    return true;
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
