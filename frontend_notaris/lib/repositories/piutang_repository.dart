import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/auth_session.dart';
import '../models/transaction_payments.dart';

bool canReadPiutang(AuthSession? session) {
  bool enabled(Object? value) => value == 1 || value == '1' || value == true;
  return session != null &&
      session.userId > 0 &&
      session.sidebars.any((access) {
        final sidebar = access['sidebar'];
        return sidebar is Map &&
            sidebar['sidebar_kode'] == 'piutang' &&
            enabled(sidebar['status']) &&
            enabled(access['read']);
      });
}

typedef PiutangFilter = ({
  String domain,
  DateTime? from,
  DateTime? through,
  String search,
});

typedef PiutangRow = ({
  int id,
  String number,
  String domain,
  String? nik,
  String? applicant,
  String? officer,
  String jobs,
  String categories,
  int billed,
  int paid,
  int remaining,
});

typedef PiutangReview = ({int id, String number, String domain, String reason});

class PiutangReport {
  PiutangReport(List<PiutangRow> rows, List<PiutangReview> reviews)
    : rows = List.unmodifiable(rows),
      reviews = List.unmodifiable(reviews),
      total = rows.fold(
        BigInt.zero,
        (sum, row) => sum + BigInt.from(row.remaining),
      );

  final List<PiutangRow> rows;
  final List<PiutangReview> reviews;
  final BigInt total;
  static const pageSize = 10;
}

class PiutangRepository {
  PiutangRepository(this._db, this._session);

  final AppDatabase _db;
  final AuthSession? Function() _session;

  void _require() {
    if (!canReadPiutang(_session())) {
      throw StateError('Izin baca Piutang diperlukan.');
    }
  }

  Stream<PiutangReport> watch(PiutangFilter filter) {
    _require();
    return _query(filter).watch().map(_report);
  }

  Future<PiutangReport> read(PiutangFilter filter) async {
    _require();
    return _report(await _query(filter).get());
  }

  Selectable<QueryRow> _query(PiutangFilter filter) {
    const active =
        "t.deleted_at IS NULL AND lower(trim(t.status_transaksi)) <> 'dihapus' AND t.jenis_transaksi IN ('notaris','ppat')";
    const detail =
        'd.transaksi_id=t.id AND d.status=1 AND d.deleted_at IS NULL';
    const payment =
        'p.transaksi_id=t.id AND p.status=1 AND p.deleted_at IS NULL';
    final predicates = [active];
    final variables = <Variable>[];
    if (filter.domain.isNotEmpty) {
      predicates.add('t.jenis_transaksi=?');
      variables.add(Variable(filter.domain));
    }
    if (filter.from case final date?) {
      predicates.add('t.tanggal_jatuh_tempo>=?');
      variables.add(Variable(DateTime(date.year, date.month, date.day)));
    }
    if (filter.through case final date?) {
      predicates.add('t.tanggal_jatuh_tempo<?');
      variables.add(Variable(DateTime(date.year, date.month, date.day + 1)));
    }
    final search = filter.search.trim();
    if (search.isNotEmpty) {
      predicates.add('''(
        instr(lower(t.no_akta),lower(?))>0 OR instr(lower(coalesce(a.nik,'')),lower(?))>0
        OR instr(lower(coalesce(a.nama,'')),lower(?))>0 OR instr(lower(coalesce(o.nama,'')),lower(?))>0
        OR EXISTS(SELECT 1 FROM transaksi_details d WHERE $detail AND
          (instr(lower(d.nama_pekerjaan_snapshot),lower(?))>0 OR instr(lower(coalesce(d.kategori_snapshot,'')),lower(?))>0))
      )''');
      variables.addAll(List.generate(6, (_) => Variable(search)));
    }
    final paymentColumns = _db.transaksiRiwayatPembayarans.$columns
        .map((column) => 'p.${column.$name} AS "payment.${column.$name}"')
        .join(', ');
    // Details and payments are disjoint parts, so a job never multiplies a payment.
    return _db.customSelect(
      '''
      WITH selected AS MATERIALIZED (
        SELECT t.id,t.no_akta,t.jenis_transaksi,t.created_at,t.total,t.diskon,t.pembayaran_sekarang,
          a.nik,a.nama AS applicant,o.nama AS officer,
          EXISTS(SELECT 1 FROM transaksis other WHERE other.id<>t.id
            AND trim(other.no_akta)=trim(t.no_akta)) AS duplicate_number
        FROM transaksis t
        LEFT JOIN pemohons a ON (a.id=t.pemohon_id OR (t.pemohon_id IS NULL AND a.uuid=t.pemohon_uuid))
          AND (t.pemohon_uuid IS NULL OR a.uuid=t.pemohon_uuid)
        LEFT JOIN petugas o ON (o.id=t.petugas_id OR (t.petugas_id IS NULL AND o.uuid=t.petugas_uuid))
          AND (t.petugas_uuid IS NULL OR o.uuid=t.petugas_uuid)
        WHERE ${predicates.join(' AND ')}
      ), parts AS (
        SELECT t.id AS parent, d.id, 'job' AS kind FROM selected t JOIN transaksi_details d ON $detail
        UNION ALL
        SELECT t.id AS parent, p.id, 'payment' AS kind FROM selected t JOIN transaksi_riwayat_pembayaran p ON $payment
      )
      SELECT t.*,part.kind,d.jenis_pekerjaan,d.nama_pekerjaan_snapshot,d.kategori_snapshot,
        d.biaya_layanan,d.biaya_lainnya,d.total_snapshot,$paymentColumns
      FROM selected t LEFT JOIN parts part ON part.parent=t.id
      LEFT JOIN transaksi_details d ON part.kind='job' AND d.id=part.id
      LEFT JOIN transaksi_riwayat_pembayaran p ON part.kind='payment' AND p.id=part.id
      ORDER BY t.created_at DESC,t.id DESC,part.kind,part.id
      ''',
      variables: variables,
      readsFrom: {
        _db.transaksis,
        _db.transaksiDetails,
        _db.transaksiRiwayatPembayarans,
        _db.pemohons,
        _db.petugasLocals,
      },
    );
  }

  PiutangReport _report(List<QueryRow> source) {
    _require();
    final rows = <PiutangRow>[];
    final reviews = <PiutangReview>[];
    for (var start = 0; start < source.length;) {
      final header = source[start];
      final id = header.read<int>('id');
      final number = header.read<String>('no_akta');
      final domain = header.read<String>('jenis_transaksi');
      var end = start + 1;
      while (end < source.length && source[end].read<int>('id') == id) {
        end++;
      }
      final parts = source.getRange(start, end);
      start = end;
      try {
        final row = _reconcile(header, parts, id, number, domain);
        if (row.remaining > 0) rows.add(row);
      } on StateError catch (error) {
        reviews.add((
          id: id,
          number: number,
          domain: domain,
          reason: error.message,
        ));
      } on ArgumentError {
        reviews.add((
          id: id,
          number: number,
          domain: domain,
          reason: 'Nominal historis harus berupa Rupiah bulat yang valid.',
        ));
      }
    }
    return PiutangReport(rows, reviews);
  }

  PiutangRow _reconcile(
    QueryRow header,
    Iterable<QueryRow> parts,
    int id,
    String number,
    String domain,
  ) {
    if (number.trim().isEmpty || header.read<int>('duplicate_number') != 0) {
      throw StateError('Nomor administratif kosong atau ambigu.');
    }
    final applicant = header.readNullable<String>('applicant');
    final officer = header.readNullable<String>('officer');
    if (applicant?.trim().isNotEmpty != true ||
        officer?.trim().isNotEmpty != true) {
      throw StateError(
        'Relasi Pemohon atau Petugas tidak lengkap atau tidak cocok.',
      );
    }
    final jobs = <String>[];
    final categories = <String>[];
    var subtotal = 0;
    final payments = <TransaksiRiwayatPembayaran>[];
    for (final part in parts) {
      switch (part.readNullable<String>('kind')) {
        case 'job':
          final name = part.read<String>('nama_pekerjaan_snapshot');
          if (name.trim().isEmpty ||
              part.read<String>('jenis_pekerjaan') != domain) {
            throw StateError(
              'Snapshot pekerjaan kosong atau tidak sesuai jenis transaksi.',
            );
          }
          final cost = _money(part, 'total_snapshot');
          if (_money(part, 'biaya_layanan') + _money(part, 'biaya_lainnya') !=
              cost) {
            throw StateError('Biaya pekerjaan berbeda dari total snapshot.');
          }
          subtotal = exactRupiah(subtotal + cost, 'Subtotal pekerjaan');
          jobs.add(name);
          final category = part.readNullable<String>('kategori_snapshot');
          categories.add(
            category == null || category.trim().isEmpty ? '—' : category,
          );
        case 'payment':
          _money(part, 'payment.nominal');
          final nominal = part.data['payment.nominal_rupiah'];
          if (nominal != null && nominal is! int) {
            throw StateError('Nominal ledger tidak konsisten.');
          }
          payments.add(
            _db.transaksiRiwayatPembayarans.map(
              part.data,
              tablePrefix: 'payment',
            ),
          );
      }
    }
    final billed = _money(header, 'total');
    if (jobs.isEmpty || subtotal - _money(header, 'diskon') != billed) {
      throw StateError(
        'Snapshot pekerjaan dan diskon tidak cocok dengan tagihan tersimpan.',
      );
    }
    final paid = totalActiveRupiah(payments);
    if (paid > billed) {
      throw StateError('Pembayaran aktif melebihi tagihan layanan.');
    }
    if (paid != _money(header, 'pembayaran_sekarang')) {
      throw StateError('Ringkasan pembayaran tidak cocok dengan ledger aktif.');
    }
    return (
      id: id,
      number: number,
      domain: domain,
      nik: header.readNullable<String>('nik'),
      applicant: applicant,
      officer: officer,
      jobs: jobs.join('\n'),
      categories: categories.join('\n'),
      billed: billed,
      paid: paid,
      remaining: billed - paid,
    );
  }

  int _money(QueryRow row, String column) {
    final value = row.data[column];
    if (value is! num) throw ArgumentError('Nominal bukan angka.');
    return exactRupiah(value, 'Nominal');
  }
}
