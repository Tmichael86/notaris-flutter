import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../models/auth_session.dart';
import '../models/dashboard_transactions.dart';
import '../models/transaction_invoice.dart';
import '../models/transaction_monitoring.dart';
import '../models/transaction_payments.dart';

class NotarisDeedInput {
  const NotarisDeedInput(this.title, this.number, this.date);

  final String title;
  final String number;
  final DateTime? date;

  String? get missingField {
    if (title.trim().isEmpty) return 'Judul Akta';
    if (number.trim().isEmpty) return 'Nomor Akta';
    if (date == null) return 'Tanggal Akta';
    return null;
  }
}

enum PpatJobStatus {
  baru('Baru'),
  dalamProses('Dalam Proses'),
  selesai('Selesai');

  const PpatJobStatus(this.label);
  final String label;
}

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
    this.unchangedDetail,
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

  /// The row shown in the form when the user left an existing job untouched.
  final TransaksiDetail? unchangedDetail;

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

  Future<TransactionInvoice> readInvoice({
    required int transactionId,
    required AuthSession? session,
  }) async {
    if (session?.hasTransactionAccess() != true) {
      throw const TransactionInvoiceUnavailable(
        'Izin baca Transaksi diperlukan.',
      );
    }
    // One SELECT keeps the snapshot consistent, works on query-only SQLite,
    // and reads each detail/payment once even when both lists are long.
    final rows = await db
        .customSelect(
          '''
      WITH selected AS (
        SELECT * FROM transaksis WHERE id = ? AND deleted_at IS NULL
          AND lower(trim(status_transaksi)) != 'dihapus'
          AND jenis_transaksi IN ('notaris', 'ppat') AND trim(no_akta) != ''
      ), parts(kind, id) AS (
        SELECT 'applicant', a.id FROM selected t JOIN pemohons a
          ON (t.pemohon_id IS NOT NULL OR t.pemohon_uuid IS NOT NULL)
         AND (t.pemohon_id IS NULL OR a.id = t.pemohon_id)
         AND (t.pemohon_uuid IS NULL OR a.uuid = t.pemohon_uuid)
        UNION ALL
        SELECT 'job', d.id FROM selected t JOIN transaksi_details d
          ON d.transaksi_id = t.id AND d.status = 1 AND d.deleted_at IS NULL
        UNION ALL
        SELECT 'payment', p.id FROM selected t JOIN transaksi_riwayat_pembayaran p
          ON p.transaksi_id = t.id AND p.status = 1 AND p.deleted_at IS NULL
      )
      SELECT t.no_akta AS invoice_number, t.jenis_transaksi AS invoice_domain,
             t.tanggal_transaksi AS invoice_date, t.total AS invoice_billed,
             t.diskon AS invoice_discount, part.kind AS invoice_part,
             a.nama AS invoice_applicant, a.alamat AS invoice_address,
             d.nama_pekerjaan_snapshot AS job_name, d.jenis_pekerjaan AS job_domain,
             d.biaya_layanan AS job_service, d.biaya_lainnya AS job_additional,
             d.total_snapshot AS job_total, p.*
      FROM selected t LEFT JOIN parts part ON 1
      LEFT JOIN pemohons a ON part.kind = 'applicant' AND part.id = a.id
      LEFT JOIN transaksi_details d ON part.kind = 'job' AND part.id = d.id
      LEFT JOIN transaksi_riwayat_pembayaran p ON part.kind = 'payment' AND part.id = p.id
      ORDER BY part.kind, p.tanggal_pembayaran, p.urutan_pembayaran, part.id
      ''',
          variables: [Variable(transactionId)],
        )
        .get();
    if (rows.isEmpty) {
      throw const TransactionInvoiceUnavailable(
        'Transaksi aktif tidak ditemukan.',
      );
    }
    final header = rows.first;
    final domain = header.read<String>('invoice_domain');
    final applicants = rows
        .where((row) => row.data['invoice_part'] == 'applicant')
        .toList();
    if (applicants.length != 1 ||
        applicants.single.read<String>('invoice_applicant').trim().isEmpty) {
      throw const TransactionInvoiceUnavailable(
        'Identitas pemohon perlu diverifikasi.',
      );
    }
    final details = rows.where((row) => row.data['invoice_part'] == 'job');
    final payments = [
      for (final row in rows)
        if (row.data['invoice_part'] == 'payment')
          db.transaksiRiwayatPembayarans.map(row.data),
    ];
    try {
      final jobs = <InvoiceJob>[];
      var subtotal = 0;
      for (final detail in details) {
        final name = detail.read<String>('job_name');
        if (detail.data['job_domain'] != domain || name.trim().isEmpty) {
          throw const TransactionInvoiceUnavailable(
            'Rincian pekerjaan transaksi perlu ditinjau.',
          );
        }
        final service = exactRupiah(
          detail.read<double>('job_service'),
          'Biaya layanan',
        );
        final additional = exactRupiah(
          detail.read<double>('job_additional'),
          'Biaya tambahan',
        );
        final total = exactRupiah(
          detail.read<double>('job_total'),
          'Total pekerjaan',
        );
        if (service + additional != total) {
          throw const TransactionInvoiceUnavailable(
            'Total rincian pekerjaan tidak sesuai snapshot.',
          );
        }
        subtotal = exactRupiah(subtotal + total, 'Subtotal pekerjaan');
        jobs.add(InvoiceJob(name, service, additional, total));
      }
      if (jobs.isEmpty) {
        throw const TransactionInvoiceUnavailable(
          'Rincian pekerjaan transaksi perlu ditinjau.',
        );
      }
      final billed = exactRupiah(
        header.read<double>('invoice_billed'),
        'Total tagihan',
      );
      final discount = exactRupiah(
        header.read<double>('invoice_discount'),
        'Potongan',
      );
      if (subtotal - discount != billed) {
        throw const TransactionInvoiceUnavailable(
          'Rincian dan potongan tidak sesuai total tagihan tersimpan.',
        );
      }
      final paid = totalActiveRupiah(payments);
      if (paid > billed) {
        throw const TransactionInvoiceUnavailable(
          'Pembayaran historis melebihi tagihan.',
        );
      }
      final person = applicants.single;
      return TransactionInvoice(
        number: header.read<String>('invoice_number'),
        domain: domain,
        applicant: person.read<String>('invoice_applicant'),
        address: person.readNullable<String>('invoice_address'),
        transactionDate: header.readNullable<DateTime>('invoice_date'),
        printDate: DateTime.now(),
        subtotal: subtotal,
        discount: discount,
        billed: billed,
        paid: paid,
        jobs: jobs,
        payments: [
          for (final row in payments)
            InvoicePayment(
              row.tanggalPembayaran,
              row.metodePembayaran,
              paymentRupiah(row),
            ),
        ],
      );
    } on ArgumentError {
      throw const TransactionInvoiceUnavailable(
        'Tagihan atau nominal historis bukan rupiah bulat yang valid.',
      );
    } on StateError {
      throw const TransactionInvoiceUnavailable(
        'Nominal pembayaran historis perlu ditinjau.',
      );
    }
  }

  Future<TransaksiDetail> readPpatJob({
    required AuthSession? session,
    required int transactionId,
    required String detailUuid,
  }) async {
    if (session?.hasTransactionAccess() != true) {
      throw StateError('Izin baca Transaksi diperlukan.');
    }
    final detail = db.transaksiDetails;
    final parent = db.transaksis;
    final row =
        await (db.select(detail).join([
              innerJoin(parent, parent.id.equalsExp(detail.transaksiId)),
            ])..where(
              detail.transaksiId.equals(transactionId) &
                  detail.uuid.equals(detailUuid) &
                  detail.jenisPekerjaan.equals('ppat') &
                  detail.status.equals(1) &
                  detail.deletedAt.isNull() &
                  parent.jenisTransaksi.equals('ppat') &
                  parent.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (row == null) throw StateError('Detail pekerjaan PPAT tidak ditemukan.');
    return row.readTable(detail);
  }

  Future<void> savePpatJobStatus({
    required AuthSession? session,
    required TransaksiDetail expected,
    required PpatJobStatus status,
    String? title,
    String? number,
    DateTime? date,
  }) async {
    if (session?.hasTransactionAccess(update: true) != true) {
      throw StateError('Izin ubah Transaksi diperlukan.');
    }
    if (status != PpatJobStatus.selesai &&
        (title != null || number != null || date != null)) {
      throw ArgumentError(
        'Data akta hanya dapat diedit saat pekerjaan Selesai.',
      );
    }
    await db.transaction(() async {
      final detail = await readPpatJob(
        session: session,
        transactionId: expected.transaksiId,
        detailUuid: expected.uuid,
      );
      if (detail != expected) {
        throw StateError('Detail pekerjaan berubah. Buka ulang status PPAT.');
      }
      final complete = status == PpatJobStatus.selesai;
      final nextStatus =
          status == PpatJobStatus.baru && detail.statusPekerjaanPpat == null
          ? null
          : status.name;
      final nextTitle = complete ? _nullableText(title) : detail.judulAktaPpat;
      final nextNumber = complete
          ? _nullableText(number)
          : detail.nomorAktaPpat;
      final nextDate = complete
          ? (date == null
                ? null
                : DateTime.utc(date.year, date.month, date.day))
          : detail.tanggalAktaPpat;
      if (nextStatus == detail.statusPekerjaanPpat &&
          nextTitle == detail.judulAktaPpat &&
          nextNumber == detail.nomorAktaPpat &&
          nextDate?.millisecondsSinceEpoch ==
              detail.tanggalAktaPpat?.millisecondsSinceEpoch) {
        return;
      }
      final pending = await db
          .customSelect(
            "SELECT 1 FROM transaction_cloud_pending m JOIN transaksis t ON t.uuid=m.local_uuid WHERE t.id=? AND m.state='pending'",
            variables: [Variable(detail.transaksiId)],
          )
          .getSingleOrNull();
      if (pending != null) {
        throw StateError('Transaksi memiliki mutasi sinkronisasi tertunda.');
      }
      await (db.update(db.transaksiDetails)..where(
            (d) =>
                d.uuid.equals(detail.uuid) &
                d.transaksiId.equals(detail.transaksiId),
          ))
          .write(
            TransaksiDetailsCompanion(
              statusPekerjaanPpat: Value(nextStatus),
              judulAktaPpat: Value(nextTitle),
              nomorAktaPpat: Value(nextNumber),
              tanggalAktaPpat: Value(nextDate),
              updatedAt: Value(DateTime.now()),
              isSyncDirty: const Value(true),
            ),
          );
    });
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
    NotarisDeedInput? deed,
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
      if (job.unchangedDetail != null) continue;
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

    var totalPekerjaan = 0;
    for (final job in jobs) {
      totalPekerjaan = exactRupiah(
        totalPekerjaan +
            exactRupiah(job.biayaLayanan, 'Biaya layanan') +
            exactRupiah(job.biayaLainnya, 'Biaya tambahan'),
        'Total pekerjaan',
      );
    }
    final diskonRupiah = exactRupiah(diskon, 'Diskon');
    if (diskonRupiah > totalPekerjaan) {
      throw ArgumentError(
        'Diskon harus bernilai antara Rp 0 dan total pekerjaan.',
      );
    }

    final totalBersih = totalPekerjaan - diskonRupiah;
    final pembayaranAwal = exactRupiah(pembayaranSekarang, 'Pembayaran awal');

    if (pembayaranAwal > totalBersih) {
      throw ArgumentError(
        'Pembayaran awal harus bernilai antara Rp 0 dan total tagihan.',
      );
    }

    if (jumlahMaterai < 0) {
      throw ArgumentError('Jumlah materai tidak boleh negatif.');
    }

    final now = DateTime.now();
    final completingNotaris =
        jenisTransaksi == 'notaris' && status.trim().toLowerCase() == 'selesai';
    if (deed != null && !completingNotaris) {
      throw ArgumentError('Data akta hanya dapat diubah saat Notaris Selesai.');
    }
    if (deed?.missingField case final field?) {
      throw ArgumentError('$field wajib diisi.');
    }
    final date = deed?.date;
    final dateOnly = date == null
        ? null
        : DateTime.utc(date.year, date.month, date.day);

    return db.transaction(() async {
      final original = id == null
          ? null
          : await (db.select(db.transaksis)
                  ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
                .getSingleOrNull();
      if (id != null && original?.jenisTransaksi != jenisTransaksi) {
        throw StateError('Transaksi tidak ditemukan atau jenisnya berbeda.');
      }
      final wasComplete =
          original?.statusTransaksi.trim().toLowerCase() == 'selesai';
      if (completingNotaris &&
          !wasComplete &&
          deed == null &&
          (original?.judulAkta?.trim().isNotEmpty != true ||
              original?.nomorAkta?.trim().isNotEmpty != true ||
              original?.tanggalAkta == null)) {
        throw ArgumentError('Judul, Nomor, dan Tanggal Akta wajib diisi.');
      }
      if (original != null &&
          jenisTransaksi == 'notaris' &&
          (deed != null || completingNotaris != wasComplete)) {
        final pending = await db
            .customSelect(
              "SELECT 1 FROM transaction_cloud_pending WHERE local_uuid=? AND state='pending'",
              variables: [Variable(original.uuid)],
            )
            .getSingleOrNull();
        if (pending != null) {
          throw StateError('Transaksi memiliki mutasi sinkronisasi tertunda.');
        }
      }
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
        if (job.unchangedDetail != null) continue;
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
                  judulAkta: Value(deed?.title.trim()),
                  nomorAkta: Value(deed?.number.trim()),
                  tanggalAkta: Value(dateOnly),
                  tanggalTransaksi: Value(tanggalTransaksi),
                  tanggalJatuhTempo: Value(tanggalJatuhTempo),
                  diskon: Value(diskon),
                  pembayaranSekarang: Value(pembayaranAwal.toDouble()),
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
      if (id == null && pembayaranAwal > 0) {
        await db
            .into(db.transaksiRiwayatPembayarans)
            .insert(
              TransaksiRiwayatPembayaransCompanion.insert(
                uuid: _uuid.v4(),
                transaksiId: transactionId,
                tanggalPembayaran: tanggalTransaksi,
                nominal: pembayaranAwal.toDouble(),
                nominalRupiah: Value(pembayaranAwal),
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
        final totalPaid = totalActiveRupiah(existingPayments);
        if (totalPaid > totalBersih) {
          throw ArgumentError(
            'Total tagihan tidak boleh lebih kecil dari pembayaran aktif.',
          );
        }
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
                judulAkta: deed == null
                    ? const Value.absent()
                    : Value(deed.title.trim()),
                nomorAkta: deed == null
                    ? const Value.absent()
                    : Value(deed.number.trim()),
                tanggalAkta: deed == null
                    ? const Value.absent()
                    : Value(dateOnly),
                tanggalTransaksi: Value(tanggalTransaksi),
                tanggalJatuhTempo: Value(tanggalJatuhTempo),
                diskon: Value(diskon),
                pembayaranSekarang: Value(totalPaid.toDouble()),
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
        if (job.unchangedDetail case final unchanged?) {
          if (existing != unchanged ||
              unchanged.jenisPekerjaan != job.jenisPekerjaan ||
              unchanged.biayaLayanan != job.biayaLayanan ||
              unchanged.biayaLainnya != job.biayaLainnya) {
            throw StateError('Detail pekerjaan berubah. Buka ulang transaksi.');
          }
          continue;
        }
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

  Stream<TransactionPaymentStatement> watchPaymentStatement(
    int transactionId,
    AuthSession? session,
  ) async* {
    if (session?.hasTransactionAccess() != true) {
      throw StateError('Izin baca Transaksi diperlukan.');
    }
    final parent = db.transaksis;
    final payment = db.transaksiRiwayatPembayarans;
    final query =
        db.select(parent).join([
            leftOuterJoin(payment, payment.transaksiId.equalsExp(parent.id)),
          ])
          ..where(parent.id.equals(transactionId) & parent.deletedAt.isNull())
          ..orderBy([
            OrderingTerm.asc(payment.urutanPembayaran),
            OrderingTerm.asc(payment.id),
          ]);
    yield* query.watch().map((rows) {
      if (rows.isEmpty) throw StateError('Transaksi tidak ditemukan.');
      return TransactionPaymentStatement(rows.first.readTable(parent), [
        for (final row in rows) ?row.readTableOrNull(payment),
      ]);
    });
  }

  /// The editor creates a UUID once and reuses it for retries of the same add.
  Future<int> addPayment({
    required AuthSession? session,
    required int transactionId,
    required String paymentUuid,
    required DateTime paymentDate,
    required int amount,
    String method = 'Cash',
    String? note,
  }) async {
    final actor = _paymentActor(session);
    _validatePaymentInput(amount, method);
    if (!RegExp(r'^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$')
        .hasMatch(paymentUuid)) {
      throw ArgumentError('UUID pembayaran tidak valid.');
    }

    return db.transaction(() async {
      final transaction = await _paymentTransaction(transactionId);
      final prior = await (db.select(
        db.transaksiRiwayatPembayarans,
      )..where((p) => p.uuid.equals(paymentUuid))).getSingleOrNull();
      if (prior != null) {
        final original = await db
            .customSelect(
              "SELECT after_state FROM transaksi_pembayaran_audit WHERE payment_uuid=? AND action='add'",
              variables: [Variable(paymentUuid)],
            )
            .getSingleOrNull();
        final input = _paymentInput(paymentDate, amount, method, note);
        final accepted = original == null
            ? null
            : jsonDecode(original.read<String>('after_state')) as Map;
        if (prior.transaksiId == transactionId &&
            accepted != null &&
            input.entries.every(
              (entry) => accepted[entry.key] == entry.value,
            )) {
          return prior.id;
        }
        throw StateError('UUID pembayaran sudah digunakan.');
      }

      final paid =
          totalActiveRupiah(await getPaymentHistory(transactionId)) + amount;
      _checkPaymentBalance(transaction, paid);
      final order =
          (await db
                  .customSelect(
                    'SELECT MAX(urutan_pembayaran) AS last_order FROM transaksi_riwayat_pembayaran WHERE transaksi_id=?',
                    variables: [Variable(transactionId)],
                  )
                  .getSingle())
              .readNullable<int>('last_order') ??
          0;
      final now = DateTime.now();
      final payment = await db
          .into(db.transaksiRiwayatPembayarans)
          .insertReturning(
            TransaksiRiwayatPembayaransCompanion.insert(
              uuid: paymentUuid,
              transaksiId: transactionId,
              tanggalPembayaran: paymentDate,
              nominal: amount.toDouble(),
              nominalRupiah: Value(amount),
              metodePembayaran: Value(method.trim()),
              keterangan: Value(_nullableText(note)),
              urutanPembayaran: Value((order < 0 ? 0 : order) + 1),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await _writePaymentAudit('add', actor, now, after: payment);
      await _updatePaid(transactionId, paid, now);
      return payment.id;
    });
  }

  Future<bool> editPayment({
    required AuthSession? session,
    required int transactionId,
    required TransaksiRiwayatPembayaran expected,
    required DateTime paymentDate,
    required int amount,
    required String method,
    String? note,
    required String reason,
  }) {
    _validatePaymentInput(amount, method);
    return _amendPayment(
      session: session,
      transactionId: transactionId,
      expected: expected,
      reason: reason,
      amount: amount,
      paymentDate: paymentDate,
      method: method.trim(),
      note: note,
    );
  }

  Future<bool> cancelPayment({
    required AuthSession? session,
    required int transactionId,
    required TransaksiRiwayatPembayaran expected,
    required String reason,
  }) => _amendPayment(
    session: session,
    transactionId: transactionId,
    expected: expected,
    reason: reason,
  );

  Future<bool> _amendPayment({
    required AuthSession? session,
    required int transactionId,
    required TransaksiRiwayatPembayaran expected,
    required String reason,
    int? amount,
    DateTime? paymentDate,
    String? method,
    String? note,
  }) async {
    final actor = _paymentActor(session, correcting: true);
    final why = _nullableText(reason);
    if (why == null) throw ArgumentError('Alasan wajib diisi.');
    final cancel = amount == null;
    return db.transaction(() async {
      final transaction = await _paymentTransaction(transactionId);
      final query = db.select(db.transaksiRiwayatPembayarans)
        ..where(
          (p) =>
              p.uuid.equals(expected.uuid) &
              p.transaksiId.equals(transactionId),
        );
      final before = await query.getSingleOrNull();
      if (before == null) {
        throw StateError('Pembayaran tidak ditemukan pada transaksi ini.');
      }
      if (cancel && !isActivePayment(before)) return false;
      if (before != expected || !isActivePayment(before)) {
        throw StateError('Pembayaran berubah. Buka kembali riwayat.');
      }
      final beforeState = _paymentState(before);
      if (!cancel &&
          _paymentInput(
            paymentDate!,
            amount,
            method!,
            note,
          ).entries.every((entry) => beforeState[entry.key] == entry.value)) {
        return false;
      }
      final paid =
          totalActiveRupiah(await getPaymentHistory(transactionId)) -
          paymentRupiah(before) +
          (amount ?? 0);
      _checkPaymentBalance(transaction, paid);
      final now = DateTime.now();
      await (db.update(
        db.transaksiRiwayatPembayarans,
      )..where((p) => p.id.equals(before.id))).write(
        TransaksiRiwayatPembayaransCompanion(
          nominal: cancel ? const Value.absent() : Value(amount.toDouble()),
          nominalRupiah: cancel ? const Value.absent() : Value(amount),
          tanggalPembayaran: cancel
              ? const Value.absent()
              : Value(paymentDate!),
          metodePembayaran: cancel ? const Value.absent() : Value(method!),
          keterangan: cancel
              ? const Value.absent()
              : Value(_nullableText(note)),
          status: cancel ? const Value(0) : const Value.absent(),
          deletedAt: cancel ? Value(now) : const Value.absent(),
          updatedAt: Value(now),
          isSyncDirty: const Value(true),
        ),
      );
      await _writePaymentAudit(
        cancel ? 'cancel' : 'edit',
        actor,
        now,
        before: before,
        after: await query.getSingle(),
        reason: why,
      );
      await _updatePaid(transactionId, paid, now);
      return true;
    });
  }

  static int _paymentActor(AuthSession? session, {bool correcting = false}) {
    if (session == null ||
        !session.hasTransactionAccess(update: true) ||
        (correcting && !session.canCorrectTransactionPayment)) {
      throw StateError(
        correcting
            ? 'Koreksi dan pembatalan memerlukan superadmin dengan izin ubah Transaksi.'
            : 'Izin ubah Transaksi diperlukan.',
      );
    }
    return session.userId;
  }

  static void _validatePaymentInput(int amount, String method) {
    if (exactRupiah(amount, 'Nominal pembayaran') == 0) {
      throw ArgumentError('Nominal pembayaran harus lebih dari Rp 0.');
    }
    if (method.trim().isEmpty) {
      throw ArgumentError('Metode pembayaran wajib diisi.');
    }
  }

  Future<Transaksi> _paymentTransaction(int id) async {
    final transaction = await findById(id);
    if (transaction == null ||
        !{'notaris', 'ppat'}.contains(transaction.jenisTransaksi)) {
      throw StateError('Transaksi tidak ditemukan.');
    }
    final pending = await db
        .customSelect(
          "SELECT 1 FROM transaction_cloud_pending WHERE local_uuid=? AND state='pending'",
          variables: [Variable(transaction.uuid)],
        )
        .getSingleOrNull();
    if (pending != null) {
      throw StateError('Transaksi memiliki mutasi sinkronisasi tertunda.');
    }
    return transaction;
  }

  static void _checkPaymentBalance(Transaksi transaction, int paid) {
    if (paid > exactRupiah(transaction.total, 'Total tagihan')) {
      throw ArgumentError('Total pembayaran melebihi total tagihan.');
    }
  }

  static Map<String, Object?> _paymentInput(
    DateTime date,
    int amount,
    String method,
    String? note,
  ) => {
    'date': date.millisecondsSinceEpoch ~/ 1000,
    'amount': amount,
    'method': method.trim(),
    'note': _nullableText(note),
  };

  static Map<String, Object?> _paymentState(
    TransaksiRiwayatPembayaran payment,
  ) => {
    ..._paymentInput(
      payment.tanggalPembayaran,
      paymentRupiah(payment),
      payment.metodePembayaran,
      payment.keterangan,
    ),
    'order': payment.urutanPembayaran,
    'status': payment.status,
    'deleted_at': payment.deletedAt?.millisecondsSinceEpoch,
  };

  Future<void> _writePaymentAudit(
    String action,
    int actor,
    DateTime now, {
    TransaksiRiwayatPembayaran? before,
    required TransaksiRiwayatPembayaran after,
    String? reason,
  }) => db.customStatement(
    'INSERT INTO transaksi_pembayaran_audit(payment_uuid,action,actor_user_id,occurred_at,reason,before_state,after_state) VALUES(?,?,?,?,?,?,?)',
    [
      after.uuid,
      action,
      actor,
      now.millisecondsSinceEpoch,
      reason,
      before == null ? null : jsonEncode(_paymentState(before)),
      jsonEncode(_paymentState(after)),
    ],
  );

  Future<void> _updatePaid(int id, int paid, DateTime now) async {
    final affected =
        await (db.update(
          db.transaksis,
        )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(
          TransaksisCompanion(
            pembayaranSekarang: Value(paid.toDouble()),
            updatedAt: Value(now),
            isSyncDirty: const Value(true),
          ),
        );
    if (affected != 1) {
      throw StateError('Transaksi tidak ditemukan atau sudah dihapus.');
    }
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
