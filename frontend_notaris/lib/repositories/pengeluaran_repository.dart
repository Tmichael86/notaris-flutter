import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../models/auth_session.dart';

enum PengeluaranAction { read, create, update, delete }

bool allowsPengeluaran(AuthSession? session, PengeluaranAction action) {
  bool enabled(Object? value) => value == 1 || value == '1' || value == true;
  return session?.sidebars.any((access) {
        final sidebar = access['sidebar'];
        return sidebar is Map &&
            sidebar['sidebar_kode'] == 'pengeluaran' &&
            enabled(sidebar['status']) &&
            enabled(access['read']) &&
            enabled(access[action.name]);
      }) ??
      false;
}

class PengeluaranFailure implements Exception {
  const PengeluaranFailure(this.message);
  final String message;
}

typedef PengeluaranFilter = ({
  DateTime? from,
  DateTime? through,
  int? jenisId,
  String search,
  int page,
});

typedef PengeluaranPage = ({
  List<PengeluaranData> rows,
  int count,
  BigInt total,
  int page,
});

typedef PengeluaranInput = ({
  String? noFaktur,
  DateTime? tanggal,
  int nominal,
  int jenisId,
  String keterangan,
});

class PengeluaranRepository {
  PengeluaranRepository(this._db, this._session);

  static const pageSize = 10;
  final AppDatabase _db;
  final AuthSession? Function() _session;

  void _require(PengeluaranAction action) {
    if (!allowsPengeluaran(_session(), action)) {
      throw const PengeluaranFailure('Anda tidak memiliki izin Pengeluaran.');
    }
  }

  // Store calendar dates independently of device timezone. Display via toUtc().
  DateTime _calendar(DateTime date, {int offset = 0}) =>
      DateTime.utc(date.year, date.month, date.day + offset);

  Stream<PengeluaranPage> watchPage(PengeluaranFilter filter) {
    _require(PengeluaranAction.read);
    final predicates = ['deleted_at IS NULL'];
    final variables = <Variable>[];
    if (filter.from case final date?) {
      predicates.add('tanggal >= ?');
      variables.add(Variable(_calendar(date)));
    }
    if (filter.through case final date?) {
      predicates.add('tanggal < ?');
      variables.add(Variable(_calendar(date, offset: 1)));
    }
    if (filter.jenisId case final id?) {
      predicates.add('jenis_id = ?');
      variables.add(Variable(id));
    }
    final search = filter.search.trim();
    if (search.isNotEmpty) {
      predicates.add('''
        (instr(lower(coalesce(no_faktur, '')), lower(?)) > 0
          OR instr(lower(keterangan), lower(?)) > 0)
      ''');
      variables.addAll([Variable(search), Variable(search)]);
    }
    // Split totals to preserve exact Rupiah even above SQLite's signed int64.
    const base = 4294967296;
    return _db
        .customSelect(
          '''
      WITH filtered AS NOT MATERIALIZED (
        SELECT * FROM pengeluaran WHERE ${predicates.join(' AND ')}
      ), summary AS (
        SELECT count(*) AS matched, coalesce(sum(nominal / $base), 0) AS high,
          coalesce(sum(nominal % $base), 0) AS low FROM filtered
      ), position AS (
        SELECT *, min(?, max(matched - 1, 0) / $pageSize) AS page_number FROM summary
      ), page AS (
        SELECT * FROM filtered ORDER BY tanggal DESC, id DESC LIMIT $pageSize
        OFFSET (SELECT page_number * $pageSize FROM position)
      )
      SELECT page.*, matched, high, low, page_number FROM position LEFT JOIN page ON 1
      ORDER BY page.tanggal DESC, page.id DESC
      ''',
          variables: [
            ...variables,
            Variable(filter.page < 0 ? 0 : filter.page),
          ],
          readsFrom: {_db.pengeluarans},
        )
        .watch()
        .map((result) {
          _require(PengeluaranAction.read);
          final summary = result.first;
          return (
            rows: [
              for (final row in result)
                if (row.readNullable<int>('id') != null)
                  _db.pengeluarans.map(row.data),
            ],
            count: summary.read<int>('matched'),
            page: summary.read<int>('page_number'),
            total:
                BigInt.from(summary.read<int>('high')) * BigInt.from(base) +
                BigInt.from(summary.read<int>('low')),
          );
        });
  }

  Stream<List<PengeluaranJenisData>> watchFilterJenis() {
    _require(PengeluaranAction.read);
    return _db
        .customSelect(
          '''
      SELECT * FROM pengeluaran_jenis AS jenis
      WHERE (jenis.status = 1 AND jenis.deleted_at IS NULL) OR EXISTS (
        SELECT 1 FROM pengeluaran WHERE jenis_id = jenis.id AND deleted_at IS NULL
      ) ORDER BY nama, id
      ''',
          readsFrom: {_db.pengeluaranJenis, _db.pengeluarans},
        )
        .watch()
        .map((rows) {
          _require(PengeluaranAction.read);
          return [for (final row in rows) _db.pengeluaranJenis.map(row.data)];
        });
  }

  Future<PengeluaranData?> detail(int id) {
    _require(PengeluaranAction.read);
    return (_db.select(_db.pengeluarans)
          ..where((row) => row.id.equals(id) & row.deletedAt.isNull()))
        .getSingleOrNull();
  }

  Future<int> create(PengeluaranInput input) async {
    _require(PengeluaranAction.create);
    _validate(input);
    return _db.transaction(() async {
      final jenisNama = await _activeJenisNama(input.jenisId);
      _require(PengeluaranAction.create);
      final now = DateTime.now();
      return _db
          .into(_db.pengeluarans)
          .insert(
            PengeluaransCompanion.insert(
              uuid: const Uuid().v4(),
              noFaktur: Value(_faktur(input)),
              tanggal: _calendar(input.tanggal!),
              nominal: input.nominal,
              jenisId: input.jenisId,
              jenisNama: jenisNama,
              keterangan: input.keterangan.trim(),
              createdAt: now,
              updatedAt: now,
            ),
          );
    });
  }

  Future<void> update(int id, PengeluaranInput input) async {
    _require(PengeluaranAction.update);
    _validate(input);
    await _db.transaction(() async {
      final existing = await detail(id);
      if (existing == null) {
        throw const PengeluaranFailure('Pengeluaran sudah tidak tersedia.');
      }
      final jenisNama = existing.jenisId == input.jenisId
          ? existing.jenisNama
          : await _activeJenisNama(input.jenisId);
      _require(PengeluaranAction.update);
      await (_db.update(
        _db.pengeluarans,
      )..where((row) => row.id.equals(id))).write(
        PengeluaransCompanion(
          noFaktur: Value(_faktur(input)),
          tanggal: Value(_calendar(input.tanggal!)),
          nominal: Value(input.nominal),
          jenisId: Value(input.jenisId),
          jenisNama: Value(jenisNama),
          keterangan: Value(input.keterangan.trim()),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<void> delete(int id) async {
    _require(PengeluaranAction.delete);
    final now = DateTime.now();
    final changed =
        await (_db.update(
          _db.pengeluarans,
        )..where((row) => row.id.equals(id) & row.deletedAt.isNull())).write(
          PengeluaransCompanion(deletedAt: Value(now), updatedAt: Value(now)),
        );
    if (changed == 0) {
      throw const PengeluaranFailure('Pengeluaran sudah tidak tersedia.');
    }
  }

  Future<String> _activeJenisNama(int id) async {
    final jenis =
        await (_db.select(_db.pengeluaranJenis)..where(
              (row) =>
                  row.id.equals(id) &
                  row.status.equals(1) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (jenis == null) {
      throw const PengeluaranFailure('Pilih Jenis Pengeluaran yang aktif.');
    }
    return jenis.nama;
  }

  String? _faktur(PengeluaranInput input) {
    final value = input.noFaktur?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  void _validate(PengeluaranInput input) {
    if (input.nominal <= 0) {
      throw const PengeluaranFailure(
        'Nominal harus berupa Rupiah bulat positif.',
      );
    }
    if (input.tanggal == null) {
      throw const PengeluaranFailure('Tanggal pengeluaran wajib diisi.');
    }
    if (input.keterangan.trim().isEmpty) {
      throw const PengeluaranFailure('Keterangan wajib diisi.');
    }
  }
}
