import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/auth_session.dart';
import '../models/verified_demo_session.dart';
import '../services/auth_service.dart';
import 'pengeluaran_repository.dart';
import 'penghasilan_repository.dart';

const pendapatanPermission = 'laporan_pendapatan';
const pendapatanDenied =
    'Izin baca Pendapatan, Penghasilan, dan Pengeluaran diperlukan.';

// The existing authentication boundary establishes the session and grants.
// Here we use its JWT expiry to time out reads without another server call.
DateTime? pendapatanSessionExpiry(AuthSession session) {
  if (session is ExpiringPaymentDemoSession) return session.expiresAt;
  try {
    final parts = session.token.split('.');
    if (parts.length != 3 || parts.any((part) => part.isEmpty)) return null;
    final claims = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (claims is! Map ||
        claims['iss'] != 'backend-notaris-go' ||
        claims['uid'] != session.userId ||
        claims['gid'] != session.groupId) {
      return null;
    }
    final seconds = claims['exp'];
    if (seconds is! int || seconds <= 0 || seconds > 253402300799) return null;
    final jwtExpiry = DateTime.fromMillisecondsSinceEpoch(
      seconds * 1000,
      isUtc: true,
    );
    final offlineExpiry = session.verifiedAt.add(
      AuthService.offlineGracePeriod,
    );
    return session.isOffline && offlineExpiry.isBefore(jwtExpiry)
        ? offlineExpiry
        : jwtExpiry;
  } on FormatException {
    return null;
  }
}

bool canReadPendapatan(AuthSession? session) {
  if (session == null ||
      session.userId <= 0 ||
      session.groupId <= 0 ||
      session.token.trim().isEmpty) {
    return false;
  }
  final now = DateTime.now();
  final expiry = pendapatanSessionExpiry(session);
  if (session.verifiedAt.isAfter(now) ||
      expiry == null ||
      !now.isBefore(expiry)) {
    return false;
  }
  bool enabled(Object? value) => value == 1 || value == '1' || value == true;
  return canReadPenghasilan(session) &&
      allowsPengeluaran(session, PengeluaranAction.read) &&
      session.sidebars.any((access) {
        final sidebar = access['sidebar'];
        return sidebar is Map &&
            sidebar['sidebar_kode'] == pendapatanPermission &&
            enabled(sidebar['status']) &&
            enabled(access['read']);
      });
}

// UTC date markers carry calendar components. WIB applies to instants only.
DateTime pendapatanWibDay(DateTime instant) {
  final wib = instant.toUtc().add(const Duration(hours: 7));
  return DateTime.utc(wib.year, wib.month, wib.day);
}

typedef PendapatanPeriod = ({DateTime from, DateTime through});

PendapatanPeriod pendapatanMonth(DateTime instant) {
  final day = pendapatanWibDay(instant);
  return (
    from: DateTime.utc(day.year, day.month),
    through: DateTime.utc(day.year, day.month + 1, 0),
  );
}

String formatPendapatanRupiah(BigInt amount) {
  final digits = amount.abs().toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return '${amount.isNegative ? '-' : ''}Rp $digits';
}

class PendapatanAmounts {
  const PendapatanAmounts(this.receipts, this.expenses);
  final BigInt receipts;
  final BigInt expenses;
  BigInt get difference => receipts - expenses;
}

typedef PendapatanDay = ({DateTime date, PendapatanAmounts amount});
typedef PendapatanReview = ({
  bool payment,
  int? id,
  DateTime? date,
  String reason,
});

class PendapatanReport {
  PendapatanReport(
    Iterable<PendapatanDay> days,
    Iterable<PendapatanReview> reviews,
  ) : days = List.unmodifiable(days),
      reviews = List.unmodifiable(reviews),
      total = PendapatanAmounts(
        days.fold(BigInt.zero, (sum, row) => sum + row.amount.receipts),
        days.fold(BigInt.zero, (sum, row) => sum + row.amount.expenses),
      );

  static const pageSize = 10;
  final List<PendapatanDay> days;
  final List<PendapatanReview> reviews;
  final PendapatanAmounts total;

  int get pageCount => (days.length + pageSize - 1) ~/ pageSize;
  int get unknownDates => reviews.where((row) => row.date == null).length;

  List<PendapatanDay> page(int index) =>
      days.skip(index * pageSize).take(pageSize).toList(growable: false);
}

class PendapatanRepository {
  PendapatanRepository(this._db, this._session);
  final AppDatabase _db;
  final AuthSession? Function() _session;

  AuthSession requireRead({AuthSession? expectedSession}) {
    final current = _session();
    if (!canReadPendapatan(current) ||
        (expectedSession != null && !identical(expectedSession, current))) {
      throw StateError(pendapatanDenied);
    }
    return current!;
  }

  Stream<PendapatanReport> watch(PendapatanPeriod period) {
    final session = requireRead();
    return _snapshot().watch().map((rows) => _report(rows, period, session));
  }

  Future<PendapatanReport> read(PendapatanPeriod period) async {
    final session = requireRead();
    return _report(await _snapshot().get(), period, session);
  }

  // Reconcile payments across their entire parent ledger before date filtering.
  // UNION ALL keeps the expense side independent of both parents and tasks.
  static const _receiptColumns = [
    'parent_id',
    'payment_id',
    'payment_uuid',
    'tanggal_pembayaran',
    'nominal',
    'nominal_rupiah',
    'uuid_count',
    'tx_id',
    'tx_uuid',
    'no_akta',
    'jenis_transaksi',
    'status_transaksi',
    'total',
    'pembayaran_sekarang',
    'jobs',
    'nik',
    'applicant',
    'officer_id',
    'officer',
  ];
  static final _nullReceipt = List.filled(
    _receiptColumns.length,
    'NULL',
  ).join(',');
  static final _snapshotSql =
      '''
    WITH receipts AS (${PenghasilanRepository.receiptSnapshotSql}),
    expenses AS (
      SELECT e.id, e.uuid, e.tanggal, e.nominal,
        COUNT(*) OVER (PARTITION BY lower(trim(e.uuid))) AS uuid_count,
        EXISTS (SELECT 1 FROM pengeluaran_jenis j WHERE j.id=e.jenis_id) AS has_category
      FROM pengeluaran e WHERE e.deleted_at IS NULL
    )
    SELECT 'receipt' AS source,
      ${_receiptColumns.map((c) => c == 'payment_uuid' ? "CASE WHEN typeof(r.payment_uuid)='text' THEN r.payment_uuid END AS payment_uuid" : 'r.$c').join(',')},
      NULL AS source_id, NULL AS source_uuid, NULL AS source_date,
      NULL AS source_amount, NULL AS source_count, NULL AS source_has_category
    FROM receipts r
    UNION ALL
    SELECT 'expense', $_nullReceipt, id,uuid,tanggal,nominal,uuid_count,has_category
    FROM expenses
    UNION ALL
    SELECT 'invalid_payment', $_nullReceipt, p.id,NULL,p.tanggal_pembayaran,NULL,NULL,NULL
    FROM transaksi_riwayat_pembayaran p
    LEFT JOIN transaksis t ON t.id=p.transaksi_id
    WHERE p.deleted_at IS NULL AND (p.status IS NULL OR p.status NOT IN (0,1))
      AND t.deleted_at IS NULL
      AND coalesce(lower(trim(t.status_transaksi)), '') NOT IN
        ('batal','dibatalkan','dihapus','cancelled','canceled')
    ''';

  Selectable<QueryRow> _snapshot() => _db.customSelect(
    _snapshotSql,
    readsFrom: {
      _db.transaksis,
      _db.transaksiRiwayatPembayarans,
      _db.transaksiDetails,
      _db.pemohons,
      _db.petugasLocals,
      _db.pengeluarans,
      _db.pengeluaranJenis,
    },
  );

  static DateTime? _paymentDay(Object? seconds) {
    if (seconds is! int || seconds < -62135596800 || seconds > 253402300799) {
      return null;
    }
    final day = pendapatanWibDay(
      DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true),
    );
    return day.year >= 1 && day.year <= 9999 ? day : null;
  }

  static DateTime? _expenseDay(Object? seconds) {
    if (seconds is! int ||
        seconds < -62135596800 ||
        seconds > 253402300799 ||
        seconds % 86400 != 0) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  PendapatanReport _report(
    List<QueryRow> rows,
    PendapatanPeriod period,
    AuthSession session,
  ) {
    requireRead(expectedSession: session);
    final from = DateTime.utc(
      period.from.year,
      period.from.month,
      period.from.day,
    );
    final through = DateTime.utc(
      period.through.year,
      period.through.month,
      period.through.day,
    );
    if (through.isBefore(from)) {
      throw ArgumentError('Periode laporan tidak sah.');
    }
    bool inPeriod(DateTime day) => !day.isBefore(from) && !day.isAfter(through);
    final receipts = <DateTime, BigInt>{};
    final expenses = <DateTime, BigInt>{};
    final reviews = <PendapatanReview>[];
    void review(bool payment, int? id, DateTime? date, String reason) {
      if (date == null || inPeriod(date)) {
        reviews.add((payment: payment, id: id, date: date, reason: reason));
      }
    }

    const inactive = {
      'batal',
      'dibatalkan',
      'dihapus',
      'cancelled',
      'canceled',
    };
    const active = {'baru', 'dalam proses', 'selesai'};
    final payments = PenghasilanRepository.projectReceiptSnapshot(
      rows.where(
        (row) =>
            row.data['source'] == 'receipt' &&
            !inactive.contains(
              row.data['status_transaksi']?.toString().trim().toLowerCase(),
            ),
      ),
      decodeDate: _paymentDay,
    );
    for (final row in payments.rows) {
      if (!active.contains(row.context.status.toLowerCase())) {
        review(
          true,
          row.id,
          row.date,
          'Status transaksi induk tidak terverifikasi.',
        );
      } else if (inPeriod(row.date)) {
        receipts.update(
          row.date,
          (sum) => sum + BigInt.from(row.amount),
          ifAbsent: () => BigInt.from(row.amount),
        );
      }
    }
    for (final row in payments.reviews) {
      review(true, row.id, row.date, row.reason);
    }
    for (final row in rows) {
      if (row.data['source'] == 'receipt') continue;
      final id = row.read<int>('source_id');
      final dateRaw = row.data['source_date'];
      if (row.data['source'] == 'invalid_payment') {
        review(
          true,
          id,
          _paymentDay(dateRaw),
          'Status pembayaran tidak terverifikasi.',
        );
        continue;
      }
      final date = _expenseDay(dateRaw);
      final uuid = row.data['source_uuid'];
      final amount = row.data['source_amount'];
      final String? issue =
          id <= 0 ||
              uuid is! String ||
              uuid.trim().isEmpty ||
              row.read<int>('source_count') != 1
          ? 'Identitas pengeluaran kosong atau ganda.'
          : row.read<int>('source_has_category') != 1
          ? 'Relasi Jenis Pengeluaran tidak terverifikasi.'
          : date == null
          ? 'Tanggal kalender pengeluaran tidak valid.'
          : amount is! int || amount <= 0
          ? 'Nominal pengeluaran harus berupa Rupiah bulat positif.'
          : null;
      if (issue != null) {
        review(false, id, date, issue);
      } else if (inPeriod(date!)) {
        final value = BigInt.from(amount as int);
        expenses.update(date, (sum) => sum + value, ifAbsent: () => value);
      }
    }
    final dates = {...receipts.keys, ...expenses.keys}.toList()
      ..sort((a, b) => b.compareTo(a));
    return PendapatanReport([
      for (final date in dates)
        (
          date: date,
          amount: PendapatanAmounts(
            receipts[date] ?? BigInt.zero,
            expenses[date] ?? BigInt.zero,
          ),
        ),
    ], reviews);
  }
}
