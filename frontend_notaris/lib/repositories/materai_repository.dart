import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/auth_session.dart';

const materaiPermissionCode = 'laporan_materai';

bool canReadMaterai(AuthSession? session) => _hasAccess(session, create: false);
bool canCreateMaterai(AuthSession? session) =>
    _hasAccess(session, create: true);

bool _hasAccess(AuthSession? session, {required bool create}) {
  bool enabled(Object? value) => value == 1 || value == '1' || value == true;
  return session != null &&
      session.userId > 0 &&
      session.sidebars.any((access) {
        final sidebar = access['sidebar'];
        return sidebar is Map &&
            sidebar['sidebar_kode'] == materaiPermissionCode &&
            enabled(sidebar['status']) &&
            enabled(access['read']) &&
            (!create || enabled(access['create']));
      });
}

String materaiCalendarDate(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

typedef MateraiFilter = ({
  String? from,
  String? through,
  String? officer,
  String search,
});

class MateraiMovement {
  MateraiMovement(QueryRow row)
    : id = row.read<int>('id'),
      namespace = row.read<String>('source_namespace'),
      sourceId = row.read<int>('source_id'),
      businessDate = row.readNullable<String>('business_date'),
      stockIn = row.readNullable<int>('stock_in'),
      stockOut = row.readNullable<int>('stock_out'),
      recordedStock = row.readNullable<int>('recorded_stock'),
      description = row.read<String>('description'),
      officerId = row.readNullable<int>('source_officer_id'),
      officer = row.readNullable<String>('officer_snapshot'),
      review = row.readNullable<String>('review_reason');

  final int id, sourceId;
  final String namespace, description;
  final String? businessDate, officer, review;
  final int? stockIn, stockOut, recordedStock, officerId;
  String? get officerKey {
    if (officerId == null || officer == null) return null;
    final scope = namespace.startsWith('local:materai:')
        ? namespace.split(':').take(3).join(':')
        : namespace;
    return '$scope:$officerId';
  }
}

class MateraiReport {
  MateraiReport(Iterable<MateraiMovement> rows, {required this.imported})
    : movements = List.unmodifiable(rows);

  static const pageSize = 10;
  final bool imported;
  final List<MateraiMovement> movements;
  Iterable<MateraiMovement> get verified =>
      movements.where((row) => row.review == null);
  Iterable<MateraiMovement> get review =>
      movements.where((row) => row.review != null);

  Map<String, String> get officers => {
    for (final row in movements.reversed) ?row.officerKey: row.officer!,
  };

  MateraiReport filtered(MateraiFilter filter) {
    final query = filter.search.trim().toLowerCase();
    return MateraiReport(
      movements.where((row) {
        // Undated anomalies remain visible and cannot contribute verified stock.
        final date = row.businessDate;
        return (date == null ||
                ((filter.from == null || date.compareTo(filter.from!) >= 0) &&
                    (filter.through == null ||
                        date.compareTo(filter.through!) <= 0))) &&
            (filter.officer == null || row.officerKey == filter.officer) &&
            row.description.toLowerCase().contains(query);
      }),
      imported: imported,
    );
  }
}

class MateraiRepository {
  MateraiRepository(this._db, this._session);

  final AppDatabase _db;
  final AuthSession? Function() _session;

  void _requireRead() {
    if (!canReadMaterai(_session())) {
      throw StateError('Izin baca Laporan Materai diperlukan.');
    }
  }

  Future<MateraiReport> read() async {
    _requireRead();
    if (_db.schemaVersion < 27) return MateraiReport([], imported: false);
    final rows = await _db.customSelect('''
      SELECT id, source_namespace, source_id, business_date, stock_in, stock_out,
        recorded_stock, description, source_officer_id, officer_snapshot,
        source_status, review_reason
      FROM materai_movements
      ORDER BY source_created_ms DESC, source_id DESC, source_namespace DESC
    ''').get();
    _requireRead();
    return MateraiReport([
      for (final row in rows)
        if (row.readNullable<int>('source_status') != 0) MateraiMovement(row),
    ], imported: rows.isNotEmpty);
  }
}
