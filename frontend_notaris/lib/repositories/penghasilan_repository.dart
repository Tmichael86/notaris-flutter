import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/auth_session.dart';
import '../models/transaction_payments.dart';

bool canReadPenghasilan(AuthSession? session) {
  bool enabled(Object? value) => value == 1 || value == '1' || value == true;
  return session != null &&
      session.userId > 0 &&
      session.sidebars.any((access) {
        final sidebar = access['sidebar'];
        return sidebar is Map &&
            sidebar['sidebar_kode'] == 'penghasilan' &&
            enabled(sidebar['status']) &&
            enabled(access['read']);
      });
}

typedef PenghasilanFilter = ({
  DateTime? from,
  DateTime? through,
  String domain,
  String job,
  String category,
  String status,
  int? officer,
  String search,
});

typedef ReceiptJob = ({String name, String category});
typedef ReceiptContext = ({
  int parentId,
  String number,
  String domain,
  String? nik,
  String? applicant,
  int? officerId,
  String? officer,
  String status,
  List<ReceiptJob> jobs,
});
typedef ReceiptRow = ({
  int id,
  String uuid,
  DateTime date,
  int amount,
  ReceiptContext context,
});
typedef ReceiptReview = ({
  int? id,
  DateTime? date,
  String reason,
  ReceiptContext context,
});

class PenghasilanReport {
  PenghasilanReport(Iterable<ReceiptRow> rows, Iterable<ReceiptReview> reviews)
    : rows = List.unmodifiable(rows),
      reviews = List.unmodifiable(reviews),
      total = rows.fold(
        BigInt.zero,
        (sum, row) => sum + BigInt.from(row.amount),
      );

  static const pageSize = 10;
  final List<ReceiptRow> rows;
  final List<ReceiptReview> reviews;
  final BigInt total;

  Iterable<ReceiptContext> get contexts => [
    ...rows.map((row) => row.context),
    ...reviews.map((row) => row.context),
  ];

  PenghasilanReport filtered(PenghasilanFilter filter) {
    final search = filter.search.trim().toLowerCase();
    final start = filter.from == null ? null : _calendar(filter.from!);
    final end = filter.through == null ? null : _calendar(filter.through!);
    bool matches(ReceiptContext context, DateTime? date) {
      if (date != null) {
        final day = _calendar(date);
        if ((start != null && day < start) || (end != null && day > end)) {
          return false;
        }
      }
      if (filter.domain.isNotEmpty && context.domain != filter.domain) {
        return false;
      }
      if (filter.status.isNotEmpty && context.status != filter.status) {
        return false;
      }
      if (filter.officer != null && context.officerId != filter.officer) {
        return false;
      }
      if ((filter.job.isNotEmpty || filter.category.isNotEmpty) &&
          !context.jobs.any(
            (job) =>
                (filter.job.isEmpty || job.name == filter.job) &&
                (filter.category.isEmpty || job.category == filter.category),
          )) {
        return false;
      }
      return search.isEmpty ||
          [
            context.number,
            context.nik,
            context.applicant,
            context.officer,
            ...context.jobs.expand((job) => [job.name, job.category]),
          ].whereType<String>().any(
            (value) => value.toLowerCase().contains(search),
          );
    }

    return PenghasilanReport(
      rows.where((row) => matches(row.context, row.date)),
      reviews.where((row) => matches(row.context, row.date)),
    );
  }

  // Drift decodes the existing payment date in the same local calendar used
  // by the transaction payment editor. Do not convert it to a UTC day.
  static int _calendar(DateTime date) =>
      date.year * 10000 + date.month * 100 + date.day;
}

typedef _Candidate = ({
  int? id,
  String uuid,
  DateTime? date,
  int? amount,
  String? issue,
  ReceiptContext context,
});

class PenghasilanRepository {
  PenghasilanRepository(this._db, this._session);
  final AppDatabase _db;
  final AuthSession? Function() _session;

  void _require() {
    if (!canReadPenghasilan(_session())) {
      throw StateError('Izin baca Penghasilan diperlukan.');
    }
  }

  Stream<PenghasilanReport> watch() {
    _require();
    return _query().watch().map(_project);
  }

  Future<PenghasilanReport> read() async {
    _require();
    return _project(await _query().get());
  }

  Selectable<QueryRow> _query() => _db.customSelect(
    '''
    WITH active_payments AS MATERIALIZED (
      SELECT p.*, COUNT(*) OVER (PARTITION BY lower(trim(p.uuid))) AS uuid_count
      FROM transaksi_riwayat_pembayaran p WHERE p.status=1 AND p.deleted_at IS NULL
    ), keys AS (
      SELECT id AS payment_id, transaksi_id AS parent_id FROM active_payments
      UNION ALL
      SELECT NULL,t.id FROM transaksis t WHERE t.deleted_at IS NULL
        AND t.pembayaran_sekarang<>0 AND NOT EXISTS (
          SELECT 1 FROM active_payments p WHERE p.transaksi_id=t.id
        )
    ), parents AS MATERIALIZED (
      SELECT t.id,t.uuid,t.no_akta,t.jenis_transaksi,t.status_transaksi,t.total,
        t.pembayaran_sekarang,t.deleted_at,t.pemohon_id,t.pemohon_uuid,t.petugas_id,t.petugas_uuid,
        (SELECT json_group_array(json_object('name', j.nama_pekerjaan_snapshot, 'category', j.kategori_snapshot))
          FROM (SELECT nama_pekerjaan_snapshot,kategori_snapshot FROM transaksi_details d
                WHERE d.transaksi_id=t.id AND d.status=1 AND d.deleted_at IS NULL
                  AND d.jenis_pekerjaan=t.jenis_transaksi ORDER BY d.id) j) AS jobs
      FROM transaksis t WHERE t.id IN (SELECT parent_id FROM keys)
    )
    SELECT k.parent_id,k.payment_id,p.uuid AS payment_uuid,p.tanggal_pembayaran,p.nominal,p.nominal_rupiah,
      p.uuid_count,t.id AS tx_id,t.uuid AS tx_uuid,t.no_akta,t.jenis_transaksi,t.status_transaksi,
      t.total,t.pembayaran_sekarang,t.jobs,a.nik,a.nama AS applicant,o.id AS officer_id,o.nama AS officer
    FROM keys k LEFT JOIN active_payments p ON p.id=k.payment_id
    LEFT JOIN parents t ON t.id=k.parent_id
    LEFT JOIN pemohons a ON (a.id=t.pemohon_id OR (t.pemohon_id IS NULL AND a.uuid=t.pemohon_uuid))
      AND (t.pemohon_uuid IS NULL OR a.uuid=t.pemohon_uuid)
    LEFT JOIN petugas o ON (o.id=t.petugas_id OR (t.petugas_id IS NULL AND o.uuid=t.petugas_uuid))
      AND (t.petugas_uuid IS NULL OR o.uuid=t.petugas_uuid)
    WHERE t.id IS NULL OR (t.deleted_at IS NULL AND lower(trim(t.status_transaksi))<>'dihapus')
    ORDER BY p.tanggal_pembayaran DESC,p.id DESC,k.parent_id DESC
    ''',
    readsFrom: {
      _db.transaksis,
      _db.transaksiRiwayatPembayarans,
      _db.transaksiDetails,
      _db.pemohons,
      _db.petugasLocals,
    },
  );

  PenghasilanReport _project(List<QueryRow> source) {
    _require();
    final candidates = <_Candidate>[];
    final byParent = <int, List<_Candidate>>{};
    final headers = <int, QueryRow>{};
    for (final raw in source) {
      final parent = raw.read<int>('parent_id');
      final header = headers.putIfAbsent(parent, () => raw);
      final group = byParent.putIfAbsent(parent, () => []);
      final context = group.isEmpty
          ? _context(header, parent)
          : group.first.context;
      final candidate = _candidate(raw, context);
      candidates.add(candidate);
      group.add(candidate);
    }
    final issues = {
      for (final MapEntry(:key, :value) in byParent.entries)
        key: _reconcile(headers[key]!, value),
    };
    final rows = <ReceiptRow>[];
    final reviews = <ReceiptReview>[];
    for (final row in candidates) {
      final issue = row.issue ?? issues[row.context.parentId];
      if (issue != null) {
        reviews.add((
          id: row.id,
          date: row.date,
          reason: issue,
          context: row.context,
        ));
      } else {
        rows.add((
          id: row.id!,
          uuid: row.uuid,
          date: row.date!,
          amount: row.amount!,
          context: row.context,
        ));
      }
    }
    return PenghasilanReport(rows, reviews);
  }

  ReceiptContext _context(QueryRow raw, int parent) {
    final snapshots =
        jsonDecode(raw.readNullable<String>('jobs') ?? '[]') as List;
    return (
      parentId: parent,
      number: raw.readNullable<String>('no_akta') ?? '',
      domain: raw.readNullable<String>('jenis_transaksi') ?? '',
      nik: raw.readNullable<String>('nik'),
      applicant: raw.readNullable<String>('applicant'),
      officerId: raw.readNullable<int>('officer_id'),
      officer: raw.readNullable<String>('officer'),
      status: raw.readNullable<String>('status_transaksi')?.trim() ?? '',
      jobs: List.unmodifiable([
        for (final job in snapshots)
          (
            name: (job['name'] as String? ?? '').trim(),
            category: (job['category'] as String? ?? '').trim(),
          ),
      ]),
    );
  }

  _Candidate _candidate(QueryRow raw, ReceiptContext context) {
    final id = raw.readNullable<int>('payment_id');
    final uuid = raw.readNullable<String>('payment_uuid') ?? '';
    final seconds = raw.data['tanggal_pembayaran'];
    final decoded =
        seconds is int && seconds >= -62135596800 && seconds <= 253402300799
        ? DateTime.fromMillisecondsSinceEpoch(seconds * 1000)
        : null;
    final date = decoded != null && decoded.year >= 1 && decoded.year <= 9999
        ? decoded
        : null;
    final nominal = raw.data['nominal'];
    final integer = raw.data['nominal_rupiah'];
    int? amount;
    String? issue;
    if (id == null) {
      issue = 'Ringkasan pembayaran tersimpan tanpa ledger aktif.';
    } else if (uuid.trim().isEmpty || raw.read<int>('uuid_count') != 1) {
      issue = 'Identitas pembayaran kosong atau ganda.';
    } else {
      try {
        if (nominal is! num || (integer != null && integer is! int)) {
          throw ArgumentError();
        }
        amount = paymentRupiahFromStored(nominal, integer as int?);
      } on ArgumentError {
        issue = 'Nominal pembayaran harus berupa Rupiah bulat positif.';
      } on StateError {
        issue = 'Nominal pembayaran tidak cocok dengan nilai ledger.';
      }
      if (issue == null && date == null) {
        issue = 'Tanggal pembayaran kosong atau tidak valid.';
      }
    }
    return (
      id: id,
      uuid: uuid,
      date: date,
      amount: amount,
      issue: issue,
      context: context,
    );
  }

  String? _reconcile(QueryRow raw, List<_Candidate> candidates) {
    final context = candidates.first.context;
    if (raw.readNullable<int>('tx_id') == null ||
        raw.readNullable<String>('tx_uuid')?.trim().isNotEmpty != true ||
        context.number.trim().isEmpty ||
        !{'notaris', 'ppat'}.contains(context.domain)) {
      return 'Identitas transaksi induk tidak dapat diverifikasi.';
    }
    if (context.applicant?.trim().isNotEmpty != true ||
        context.officer?.trim().isNotEmpty != true) {
      return 'Relasi Pemohon atau Petugas hilang atau tidak cocok.';
    }
    if (candidates.any((row) => row.amount == null)) {
      return 'Ledger aktif transaksi belum dapat direkonsiliasi.';
    }
    final total = candidates.fold(
      BigInt.zero,
      (sum, row) => sum + BigInt.from(row.amount!),
    );
    try {
      final billed = raw.data['total'];
      final header = raw.data['pembayaran_sekarang'];
      if (billed is! num || header is! num) throw ArgumentError();
      if (total > BigInt.from(exactRupiah(billed, 'Tagihan'))) {
        return 'Pembayaran aktif melebihi tagihan tersimpan.';
      }
      if (total != BigInt.from(exactRupiah(header, 'Ringkasan pembayaran'))) {
        return 'Ringkasan pembayaran berbeda dari ledger aktif.';
      }
    } on ArgumentError {
      return 'Tagihan atau ringkasan pembayaran bukan Rupiah bulat yang valid.';
    }
    return null;
  }
}
