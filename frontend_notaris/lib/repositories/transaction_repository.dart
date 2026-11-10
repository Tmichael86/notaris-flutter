import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../models/dashboard_transactions.dart';
import '../models/transaction_monitoring.dart';

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
    this.prosesSnapshot,
    this.hargaUuid,
    this.kategoriUuid,
    required this.detailUuid,
  });

  /// Must be either 'notaris' or 'ppat'.
  final String jenisPekerjaan;
  final String namaPekerjaan;
  final int? pekerjaanNotarisId;
  final int? pekerjaanPpatId;
  final String? kategoriSnapshot;
  final String? estimasiWaktuSnapshot;

  /// JSON snapshot of the selected process checklist for this transaction job.
  final String? prosesSnapshot;
  final String? hargaUuid;
  final String? kategoriUuid;

  /// Stable detail UUID generated when the job is selected, and preserved
  /// across subsequent edits of the same transaction.
  final String detailUuid;
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

  static const _monitoringContacts = '''
    LEFT JOIN pemohons a ON a.id=t.pemohon_id AND a.deleted_at IS NULL AND a.status=1
      AND (t.pemohon_uuid IS NULL OR a.uuid=t.pemohon_uuid)
    LEFT JOIN petugas o ON o.id=t.petugas_id AND o.deleted_at IS NULL AND o.status=1
      AND (t.petugas_uuid IS NULL OR o.uuid=t.petugas_uuid)''';
  static const _monitoringActive =
      "t.deleted_at IS NULL AND lower(trim(t.status_transaksi)) != 'dihapus'";
  static const _monitoringDetail =
      'd.transaksi_id=t.id AND d.status=1 AND d.deleted_at IS NULL';
  static const _monitoringColumns =
      '''t.*, a.nik AS applicant_nik,
    a.nama AS applicant_name, o.nama AS officer_name,
    (SELECT group_concat(DISTINCT nullif(trim(d.nama_pekerjaan_snapshot), ''))
      FROM transaksi_details d WHERE $_monitoringDetail) AS job_names,
    (SELECT group_concat(DISTINCT nullif(trim(d.kategori_snapshot), ''))
      FROM transaksi_details d WHERE $_monitoringDetail) AS category_names''';

  MonitoringRow _monitoringRow(QueryRow row) => (
    transaction: db.transaksis.map(row.data),
    nik: row.readNullable<String>('applicant_nik'),
    applicant: row.readNullable<String>('applicant_name'),
    officer: row.readNullable<String>('officer_name'),
    jobs: row.readNullable<String>('job_names'),
    categories: row.readNullable<String>('category_names'),
  );

  Stream<MonitoringPage> watchMonitoringPage(MonitoringFilter filter) {
    final variables = <Variable>[];
    String bind<T extends Object>(T value) {
      variables.add(Variable<T>(value));
      return '?';
    }

    final conditions = [
      _monitoringActive,
      if (filter.domain.isNotEmpty) 't.jenis_transaksi=${bind(filter.domain)}',
      if (filter.status.isNotEmpty)
        'lower(trim(t.status_transaksi))=${bind(filter.status.toLowerCase())}',
      if (filter.officerId != 0) 'o.id=${bind(filter.officerId)}',
      if (filter.from case final date?) 't.tanggal_transaksi>=${bind(date)}',
      if (filter.until case final date?)
        't.tanggal_transaksi<${bind(DateTime(date.year, date.month, date.day + 1))}',
      if (filter.job.isNotEmpty || filter.category.isNotEmpty)
        '''EXISTS (SELECT 1 FROM transaksi_details d WHERE $_monitoringDetail
          ${filter.job.isEmpty ? '' : 'AND trim(d.nama_pekerjaan_snapshot)=${bind(filter.job)}'}
          ${filter.category.isEmpty ? '' : 'AND trim(d.kategori_snapshot)=${bind(filter.category)}'})''',
    ];
    final search = filter.search.trim().toLowerCase();
    if (search.isNotEmpty) {
      conditions.add(
        '''(instr(lower(t.no_akta), ${bind(search)}) > 0
        OR instr(lower(a.nik), ${bind(search)}) > 0 OR instr(lower(a.nama), ${bind(search)}) > 0
        OR EXISTS (SELECT 1 FROM transaksi_details d WHERE $_monitoringDetail
          AND instr(lower(d.nama_pekerjaan_snapshot), ${bind(search)}) > 0))''',
      );
    }
    final index = bind(filter.index);
    return db
        .customSelect(
          '''
      WITH matching AS NOT MATERIALIZED (
        SELECT t.id, t.tanggal_transaksi FROM transaksis t $_monitoringContacts
        WHERE ${conditions.join(' AND ')}
      ), bounds AS (
        SELECT count(*) AS monitoring_total,
          min($index, max(0, (count(*) - 1) / $monitoringPageSize)) AS monitoring_index FROM matching
      ), page AS (
        SELECT id FROM matching ORDER BY tanggal_transaksi DESC, id DESC LIMIT $monitoringPageSize
          OFFSET (SELECT monitoring_index * $monitoringPageSize FROM bounds)
      )
      SELECT $_monitoringColumns, bounds.* FROM bounds LEFT JOIN page ON TRUE
      LEFT JOIN transaksis t ON t.id=page.id $_monitoringContacts
      ORDER BY t.tanggal_transaksi DESC, t.id DESC
      ''',
          variables: variables,
          readsFrom: _monitoringTables,
        )
        .watch()
        .map(
          (rows) => (
            total: rows.first.read<int>('monitoring_total'),
            index: rows.first.read<int>('monitoring_index'),
            rows: [
              for (final row in rows)
                if (row.data['id'] != null) _monitoringRow(row),
            ],
          ),
        );
  }

  Set<ResultSetImplementation> get _monitoringTables => {
    db.transaksis,
    db.transaksiDetails,
    db.pemohons,
    db.petugasLocals,
  };

  Stream<MonitoringOptions> watchMonitoringOptions(String domain) {
    return db
        .customSelect(
          '''
      WITH active AS (SELECT t.* FROM transaksis t WHERE $_monitoringActive AND (? = '' OR t.jenis_transaksi = ?)),
      details AS (SELECT d.* FROM active t JOIN transaksi_details d ON $_monitoringDetail)
      SELECT DISTINCT 'job' AS kind, 0 AS id, trim(nama_pekerjaan_snapshot) AS label FROM details
      UNION ALL SELECT DISTINCT 'category', 0, trim(kategori_snapshot) FROM details
      UNION ALL SELECT DISTINCT 'officer', o.id, o.nama FROM active t $_monitoringContacts WHERE o.id IS NOT NULL
      ORDER BY label COLLATE NOCASE, id
      ''',
          variables: [Variable(domain), Variable(domain)],
          readsFrom: _monitoringTables,
        )
        .watch()
        .map((rows) {
          final jobs = <String>[], categories = <String>[];
          final officers = <int, String>{};
          for (final row in rows) {
            final label = row.readNullable<String>('label');
            if (label == null || label.isEmpty) continue;
            switch (row.read<String>('kind')) {
              case 'job':
                jobs.add(label);
              case 'category':
                categories.add(label);
              case 'officer':
                officers[row.read<int>('id')] = label;
            }
          }
          return (jobs: jobs, categories: categories, officers: officers);
        });
  }

  Stream<MonitoringRow?> watchMonitoringTransaction(int id) => db
      .customSelect(
        '''
    SELECT $_monitoringColumns FROM transaksis t $_monitoringContacts
    WHERE $_monitoringActive AND t.id=?
    ''',
        variables: [Variable(id)],
        readsFrom: _monitoringTables,
      )
      .watchSingleOrNull()
      .map((row) => row == null ? null : _monitoringRow(row));

  Stream<List<TransaksiDetail>> watchMonitoringDetails(int id) {
    final d = db.transaksiDetails;
    final t = db.transaksis;
    final query =
        db.select(d).join([
            innerJoin(t, t.id.equalsExp(d.transaksiId), useColumns: false),
          ])
          ..where(
            d.transaksiId.equals(id) &
                d.status.equals(1) &
                d.deletedAt.isNull() &
                t.deletedAt.isNull() &
                t.statusTransaksi.trim().lower().equals('dihapus').not(),
          )
          ..orderBy([OrderingTerm.asc(d.id)]);
    return query.watch().map(
      (rows) => rows.map((row) => row.readTable(d)).toList(),
    );
  }

  Stream<DashboardTransactionPage> watchDashboardPage({
    required DashboardTransactionList list,
    required int year,
    required int pageIndex,
  }) {
    final deadlines = list == DashboardTransactionList.deadlines;
    final order = deadlines
        ? 'tanggal_jatuh_tempo, id'
        : 'tanggal_transaksi DESC, id DESC';
    final deadlineFilter = deadlines
        ? "AND tanggal_jatuh_tempo IS NOT NULL AND lower(trim(status_transaksi)) IN ('baru', 'dalam proses')"
        : '';
    // Keep the count and page in the same snapshot. The left join preserves
    // pagination metadata for an empty result or a page that shrank.
    final query = db.customSelect(
      '''
      WITH matching AS NOT MATERIALIZED (
        SELECT * FROM transaksis
        WHERE deleted_at IS NULL AND lower(trim(status_transaksi)) != 'dihapus'
          AND tanggal_transaksi >= ? AND tanggal_transaksi < ?
          $deadlineFilter
      ), bounds AS (
        SELECT count(*) AS dashboard_total,
          min(?, max(0, (count(*) - 1) / $dashboardTransactionPageSize)) AS dashboard_index
        FROM matching
      )
      SELECT page.*, bounds.* FROM bounds LEFT JOIN (
        SELECT * FROM matching ORDER BY $order LIMIT $dashboardTransactionPageSize
          OFFSET (SELECT dashboard_index * $dashboardTransactionPageSize FROM bounds)
      ) page ON TRUE
      ORDER BY $order
      ''',
      variables: [
        Variable.withDateTime(DateTime(year)),
        Variable.withDateTime(DateTime(year + 1)),
        Variable.withInt(pageIndex),
      ],
      readsFrom: {db.transaksis},
    );
    return query.watch().map(
      (rows) => (
        index: rows.first.read<int>('dashboard_index'),
        total: rows.first.read<int>('dashboard_total'),
        rows: [
          for (final row in rows)
            if (row.data['id'] != null) db.transaksis.map(row.data),
        ],
      ),
    );
  }

  /// Actual receipts by payment date, including installments on earlier sales.
  Stream<double> watchReceivedPayments(int year) {
    final payments = db.transaksiRiwayatPembayarans;
    final transactions = db.transaksis;
    final sum = payments.nominal.sum();
    final query =
        db.selectOnly(payments).join([
            innerJoin(
              transactions,
              transactions.id.equalsExp(payments.transaksiId),
              useColumns: false,
            ),
          ])
          ..addColumns([sum])
          ..where(
            payments.status.equals(1) &
                payments.deletedAt.isNull() &
                transactions.deletedAt.isNull() &
                transactions.statusTransaksi
                    .trim()
                    .lower()
                    .equals('dihapus')
                    .not() &
                payments.tanggalPembayaran.isBiggerOrEqualValue(
                  DateTime(year),
                ) &
                payments.tanggalPembayaran.isSmallerThanValue(
                  DateTime(year + 1),
                ),
          );
    return query.watchSingle().map((row) => row.read(sum) ?? 0);
  }

  Future<Transaksi?> findById(int id) {
    return (db.select(
      db.transaksis,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
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
    final sequencePattern = RegExp(r'^\d{3}\d{6}(\d{4})$');
    var maxSequence = 0;
    for (final row in rows) {
      final match = sequencePattern.firstMatch(row.noAkta);
      if (match == null) continue;
      final sequence = int.tryParse(match.group(1) ?? '') ?? 0;
      if (sequence > maxSequence) maxSequence = sequence;
    }
    if (maxSequence >= 9999) {
      throw StateError(
        'Urutan nomor transaksi telah mencapai batas 9999. '
        'Format nomor transaksi hanya mendukung empat digit urutan.',
      );
    }
    final nextSequence = (maxSequence + 1).toString().padLeft(4, '0');
    return '$typeCode'
        '00$dateCode$nextSequence';
  }

  Future<List<TransaksiDetail>> watchDetailsOnce(int transactionId) {
    return (db.select(db.transaksiDetails)..where(
          (t) =>
              t.transaksiId.equals(transactionId) &
              t.deletedAt.isNull() &
              t.status.equals(1),
        ))
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
      if (job.jenisPekerjaan == 'notaris' && job.pekerjaanNotarisId == null) {
        throw ArgumentError('Referensi pekerjaan Notaris wajib diisi.');
      }
      if (job.jenisPekerjaan == 'ppat' && job.pekerjaanPpatId == null) {
        throw ArgumentError('Referensi pekerjaan PPAT wajib diisi.');
      }
    }

    final normalizedNoAkta = nomorTransaksi.trim();
    if (normalizedNoAkta.isEmpty) {
      throw ArgumentError('Nomor transaksi wajib diisi.');
    }

    for (final job in jobs) {
      if (!job.biayaLayanan.isFinite ||
          !job.biayaLainnya.isFinite ||
          job.biayaLayanan < 0 ||
          job.biayaLainnya < 0) {
        throw ArgumentError(
          'Biaya pekerjaan harus berupa angka valid dan tidak boleh negatif.',
        );
      }
    }

    final totalPekerjaan = jobs.fold<double>(0, (sum, job) => sum + job.total);
    if (!totalPekerjaan.isFinite) {
      throw ArgumentError('Total pekerjaan tidak valid.');
    }

    if (!diskon.isFinite || diskon < 0 || diskon > totalPekerjaan) {
      throw ArgumentError(
        'Diskon harus bernilai antara Rp 0 dan total pekerjaan.',
      );
    }

    final totalBersih = totalPekerjaan - diskon;

    if (!pembayaranSekarang.isFinite ||
        pembayaranSekarang < 0 ||
        pembayaranSekarang > totalBersih) {
      throw ArgumentError(
        'Pembayaran awal harus bernilai antara Rp 0 dan total tagihan.',
      );
    }

    if (jumlahMaterai < 0) {
      throw ArgumentError('Jumlah materai tidak boleh negatif.');
    }

    final now = DateTime.now();

    return db.transaction(() async {
      final pemohon =
          await (db.select(db.pemohons)..where(
                (p) =>
                    p.id.equals(pemohonId) &
                    p.deletedAt.isNull() &
                    p.status.equals(1),
              ))
              .getSingleOrNull();
      final petugas =
          await (db.select(db.petugasLocals)..where(
                (p) =>
                    p.id.equals(petugasId) &
                    p.deletedAt.isNull() &
                    p.status.equals(1),
              ))
              .getSingleOrNull();
      if (pemohon?.uuid != pemohonUuid || petugas?.uuid != petugasUuid) {
        throw ArgumentError('Pemohon atau Petugas lokal tidak valid.');
      }
      for (final job in jobs) {
        if (jenisTransaksi == 'notaris') {
          if (job.pekerjaanPpatId != null ||
              await (db.select(db.pekerjaanNotarisLocals)..where(
                        (p) =>
                            p.id.equals(job.pekerjaanNotarisId!) &
                            p.deletedAt.isNull() &
                            p.status.equals(1),
                      ))
                      .getSingleOrNull() ==
                  null) {
            throw ArgumentError('Pekerjaan Notaris tidak valid.');
          }
        } else if (job.pekerjaanNotarisId != null ||
            await (db.select(db.pekerjaanPpatLocals)..where(
                      (p) =>
                          p.id.equals(job.pekerjaanPpatId!) &
                          p.deletedAt.isNull() &
                          p.status.equals(1),
                    ))
                    .getSingleOrNull() ==
                null) {
          throw ArgumentError('Pekerjaan PPAT tidak valid.');
        }
      }
      // Catch ordinary collisions with a clear error. The unique SQLite index
      // remains the final guard against two concurrent writers racing here.
      final duplicateNumbers = await db
          .customSelect(
            'SELECT id FROM transaksis '
            'WHERE TRIM(no_akta) = ? AND id != ? LIMIT 1',
            variables: [
              Variable.withString(normalizedNoAkta),
              Variable.withInt(id ?? -1),
            ],
          )
          .get();

      if (duplicateNumbers.isNotEmpty) {
        throw StateError(
          'Nomor transaksi "$normalizedNoAkta" sudah digunakan. '
          'Muat ulang nomor transaksi sebelum menyimpan kembali.',
        );
      }

      final transactionId =
          id ??
          await db
              .into(db.transaksis)
              .insert(
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
        await db
            .into(db.transaksiRiwayatPembayarans)
            .insert(
              TransaksiRiwayatPembayaransCompanion.insert(
                uuid: _uuid.v4(),
                transaksiId: transactionId,
                tanggalPembayaran: tanggalTransaksi,
                nominal: pembayaranSekarang,
                metodePembayaran: Value(metodePembayaran),
                keterangan: const Value(
                  'Pembayaran awal saat transaksi dibuat',
                ),
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
        final affected =
            await (db.update(
              db.transaksis,
            )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(
              TransaksisCompanion(
                noAkta: Value(normalizedNoAkta),
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

        // Do not replace every detail row on edit. Stable detail UUIDs are
        // required so process-level validation state can remain attached to
        // the same job across ordinary transaction edits.
      }

      final existingDetails = id == null
          ? <TransaksiDetail>[]
          : await (db.select(db.transaksiDetails)..where(
                  (t) =>
                      t.transaksiId.equals(transactionId) &
                      t.deletedAt.isNull() &
                      t.status.equals(1),
                ))
                .get();
      final existingByUuid = {
        for (final detail in existingDetails) detail.uuid: detail,
      };
      final retainedUuids = jobs.map((job) => job.detailUuid).toSet();

      // Only soft-delete jobs explicitly removed from the edited form.
      final removedUuids = existingByUuid.keys
          .where((uuid) => !retainedUuids.contains(uuid))
          .toList();
      if (removedUuids.isNotEmpty) {
        await (db.update(
          db.transaksiDetails,
        )..where((t) => t.uuid.isIn(removedUuids))).write(
          TransaksiDetailsCompanion(
            status: const Value(0),
            deletedAt: Value(now),
            updatedAt: Value(now),
            isSyncDirty: const Value(true),
          ),
        );
      }

      for (final job in jobs) {
        final existing = existingByUuid[job.detailUuid];
        // Null provenance on an unchanged legacy detail stays unresolved. Never
        // infer a historical price from labels, amounts or integer IDs.
        final priceUuid = job.hargaUuid ?? existing?.hargaUuid;
        final categoryUuid = job.kategoriUuid ?? existing?.kategoriUuid;
        final sameJob =
            existing == null ||
            (existing.pekerjaanNotarisId == job.pekerjaanNotarisId &&
                existing.pekerjaanPpatId == job.pekerjaanPpatId);
        if ((priceUuid == null) != (categoryUuid == null) ||
            (!sameJob && job.hargaUuid == null)) {
          throw StateError(
            'Provenance harga wajib dipilih ulang saat mengganti pekerjaan.',
          );
        }
        if (priceUuid != null &&
            (existing == null ||
                !sameJob ||
                priceUuid != existing.hargaUuid ||
                categoryUuid != existing.kategoriUuid)) {
          final domain = job.jenisPekerjaan;
          final selected = await db
              .customSelect(
                'SELECT h.uuid FROM pekerjaan_${domain}_harga h JOIN pekerjaan_kategori c ON c.id=h.kategori_pekerjaan_id WHERE h.uuid=? AND h.pekerjaan_${domain}_id=? AND c.uuid=? AND h.status=1 AND h.deleted_at IS NULL AND c.status=1 AND c.deleted_at IS NULL',
                variables: [
                  Variable(priceUuid),
                  Variable(job.pekerjaanNotarisId ?? job.pekerjaanPpatId!),
                  Variable(categoryUuid!),
                ],
              )
              .get();
          if (selected.length != 1) {
            throw StateError('Provenance harga/kategori tidak sah.');
          }
        }
        if (existing != null) {
          await (db.update(db.transaksiDetails)..where(
                (t) =>
                    t.uuid.equals(existing.uuid) &
                    t.transaksiId.equals(transactionId) &
                    t.deletedAt.isNull(),
              ))
              .write(
                TransaksiDetailsCompanion(
                  jenisPekerjaan: Value(job.jenisPekerjaan),
                  pekerjaanNotarisId: Value(job.pekerjaanNotarisId),
                  pekerjaanPpatId: Value(job.pekerjaanPpatId),
                  namaPekerjaanSnapshot: Value(job.namaPekerjaan),
                  kategoriSnapshot: Value(job.kategoriSnapshot),
                  hargaUuid: Value(priceUuid),
                  kategoriUuid: Value(categoryUuid),
                  estimasiWaktuSnapshot: Value(job.estimasiWaktuSnapshot),
                  prosesSnapshot: Value(job.prosesSnapshot),
                  biayaLayanan: Value(job.biayaLayanan),
                  biayaLainnya: Value(job.biayaLainnya),
                  totalSnapshot: Value(job.total),
                  updatedAt: Value(now),
                  isSyncDirty: const Value(true),
                ),
              );
        } else {
          await db
              .into(db.transaksiDetails)
              .insert(
                TransaksiDetailsCompanion.insert(
                  uuid: job.detailUuid,
                  transaksiId: transactionId,
                  jenisPekerjaan: job.jenisPekerjaan,
                  pekerjaanNotarisId: Value(job.pekerjaanNotarisId),
                  pekerjaanPpatId: Value(job.pekerjaanPpatId),
                  namaPekerjaanSnapshot: job.namaPekerjaan,
                  kategoriSnapshot: Value(job.kategoriSnapshot),
                  hargaUuid: Value(priceUuid),
                  kategoriUuid: Value(categoryUuid),
                  estimasiWaktuSnapshot: Value(job.estimasiWaktuSnapshot),
                  prosesSnapshot: Value(job.prosesSnapshot),
                  biayaLayanan: Value(job.biayaLayanan),
                  biayaLainnya: Value(job.biayaLainnya),
                  totalSnapshot: Value(job.total),
                  createdAt: Value(now),
                  updatedAt: Value(now),
                  isSyncDirty: const Value(true),
                ),
              );
        }

        await _syncProcessesForJob(
          transactionId: transactionId,
          detailUuid: job.detailUuid,
          snapshot: job.prosesSnapshot,
          now: now,
        );
      }
      return transactionId;
    });
  }

  /// Reconciles the process rows with an explicitly supplied process snapshot.
  ///
  /// A null snapshot means the caller did not provide process data, so existing
  /// workflow state must be left untouched. Matching rows keep their validated
  /// status and audit history; removed rows are soft-deleted, never hard-deleted.
  Future<void> _syncProcessesForJob({
    required int transactionId,
    required String detailUuid,
    required String? snapshot,
    required DateTime now,
  }) async {
    if (snapshot == null) return;

    final Object? decoded;
    try {
      decoded = jsonDecode(snapshot);
    } on FormatException {
      throw ArgumentError('Snapshot proses bukan JSON yang valid.');
    }
    if (decoded is! List) {
      throw ArgumentError('Snapshot proses harus berupa daftar.');
    }

    final incoming = <Map<String, dynamic>>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final name = item['name']?.toString().trim() ?? '';
      if (name.isEmpty) continue;
      incoming.add(Map<String, dynamic>.from(item));
    }

    final existingRows =
        await (db.select(db.transaksiProses)..where(
              (p) =>
                  p.transaksiDetailUuid.equals(detailUuid) &
                  p.transaksiId.equals(transactionId) &
                  p.deletedAt.isNull(),
            ))
            .get();

    final unmatched = [...existingRows];
    for (final item in incoming) {
      final name = item['name']!.toString().trim();
      final rawSourceId = item['id']?.toString().trim();
      final sourceId = rawSourceId == null || rawSourceId.isEmpty
          ? null
          : rawSourceId;

      final matchIndex = unmatched.indexWhere((row) {
        if (sourceId != null && row.sourceProcessId != null) {
          return row.sourceProcessId == sourceId;
        }
        return row.namaProsesSnapshot == name;
      });

      final legacyStatus = item['status']?.toString();
      final legacyData = jsonEncode(item);

      if (matchIndex >= 0) {
        final existing = unmatched.removeAt(matchIndex);
        await (db.update(
          db.transaksiProses,
        )..where((p) => p.id.equals(existing.id))).write(
          TransaksiProsesCompanion(
            namaProsesSnapshot: Value(name),
            sourceProcessId: Value(sourceId ?? existing.sourceProcessId),
            legacyStatus: Value(legacyStatus),
            legacyData: Value(legacyData),
            updatedAt: Value(now),
            isSyncDirty: const Value(true),
          ),
        );
      } else {
        final uuid = _uuid.v4();
        await db
            .into(db.transaksiProses)
            .insert(
              TransaksiProsesCompanion.insert(
                uuid: uuid,
                transaksiId: transactionId,
                transaksiDetailUuid: detailUuid,
                sourceProcessId: Value(sourceId),
                namaProsesSnapshot: name,
                statusProses: const Value(null),
                legacyStatus: Value(legacyStatus),
                legacyData: Value(legacyData),
                createdAt: Value(now),
                updatedAt: Value(now),
                isSyncDirty: const Value(true),
              ),
            );
      }
    }

    if (unmatched.isNotEmpty) {
      final removedIds = unmatched.map((row) => row.id).toList();
      await (db.update(
        db.transaksiProses,
      )..where((p) => p.id.isIn(removedIds))).write(
        TransaksiProsesCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          isSyncDirty: const Value(true),
        ),
      );
    }
  }

  /// Returns active payment history entries ordered by payment date.
  Future<List<TransaksiRiwayatPembayaran>> getPaymentHistory(
    int transactionId,
  ) {
    return (db.select(db.transaksiRiwayatPembayarans)
          ..where(
            (p) =>
                p.transaksiId.equals(transactionId) &
                p.deletedAt.isNull() &
                p.status.equals(1),
          )
          ..orderBy([
            (p) => OrderingTerm.asc(p.tanggalPembayaran),
            (p) => OrderingTerm.asc(p.urutanPembayaran),
          ]))
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
      final paymentId = await db
          .into(db.transaksiRiwayatPembayarans)
          .insert(
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

      await (db.update(
        db.transaksis,
      )..where((t) => t.id.equals(transactionId))).write(
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

  /// Soft-deletes a payment and refreshes the transaction total atomically.
  ///
  /// If updating the transaction header fails, the payment must remain active
  /// so the payment history and cached paid amount cannot diverge.
  Future<bool> deletePayment(int paymentId) {
    return db.transaction(() async {
      final payment =
          await (db.select(db.transaksiRiwayatPembayarans)
                ..where((p) => p.id.equals(paymentId) & p.deletedAt.isNull()))
              .getSingleOrNull();
      if (payment == null) return false;

      final now = DateTime.now();
      await (db.update(
        db.transaksiRiwayatPembayarans,
      )..where((p) => p.id.equals(paymentId) & p.deletedAt.isNull())).write(
        TransaksiRiwayatPembayaransCompanion(
          status: const Value(0),
          deletedAt: Value(now),
          updatedAt: Value(now),
          isSyncDirty: const Value(true),
        ),
      );

      final history = await getPaymentHistory(payment.transaksiId);
      final paid = history.fold<double>(0, (sum, item) => sum + item.nominal);
      final affected =
          await (db.update(db.transaksis)..where(
                (t) => t.id.equals(payment.transaksiId) & t.deletedAt.isNull(),
              ))
              .write(
                TransaksisCompanion(
                  pembayaranSekarang: Value(paid),
                  updatedAt: Value(now),
                  isSyncDirty: const Value(true),
                ),
              );
      if (affected == 0) {
        throw StateError('Transaksi tidak ditemukan atau sudah dihapus.');
      }

      return true;
    });
  }

  Future<bool> delete(int id) async {
    final now = DateTime.now();
    return db.transaction(() async {
      final original = await findById(id);
      if (original == null) return false;
      final details = await (db.select(
        db.transaksiDetails,
      )..where((t) => t.transaksiId.equals(id) & t.deletedAt.isNull())).get();
      // Only facts required to undo this exact local cascade, never payment data.
      await db.customStatement(
        "INSERT INTO recycle_bin_events(attempt_id,module,local_uuid,action,outcome,occurred_at,before_state) VALUES(?,?,?,'delete','success',?,?)",
        [
          _uuid.v4(),
          'transaksi_${original.jenisTransaksi}',
          original.uuid,
          now.toUtc().toIso8601String(),
          jsonEncode({
            'status': original.statusTransaksi,
            'deletedAt': now.millisecondsSinceEpoch ~/ 1000,
            'details': details
                .map((d) => {'uuid': d.uuid, 'status': d.status})
                .toList(),
          }),
        ],
      );
      final affected =
          await (db.update(
            db.transaksis,
          )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(
            TransaksisCompanion(
              statusTransaksi: const Value('Dihapus'),
              deletedAt: Value(now),
              updatedAt: Value(now),
              isSyncDirty: const Value(true),
            ),
          );
      if (affected == 0) return false;
      await (db.update(
        db.transaksiDetails,
      )..where((t) => t.transaksiId.equals(id) & t.deletedAt.isNull())).write(
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
