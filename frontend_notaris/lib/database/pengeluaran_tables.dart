import 'package:drift/drift.dart';

import 'master_tables.dart';

@DataClassName('PengeluaranData')
@TableIndex(name: 'pengeluaran_by_date', columns: {#tanggal, #id})
@TableIndex(name: 'pengeluaran_by_jenis', columns: {#jenisId})
class Pengeluarans extends Table {
  @override
  String get tableName => 'pengeluaran';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().unique()();
  TextColumn get noFaktur => text().nullable()();
  DateTimeColumn get tanggal => dateTime()();
  IntColumn get nominal => integer().check(
    const CustomExpression<bool>("typeof(nominal) = 'integer' AND nominal > 0"),
  )();
  IntColumn get jenisId => integer().references(PengeluaranJenis, #id)();
  TextColumn get jenisNama => text()();
  TextColumn get keterangan => text().check(
    const CustomExpression<bool>('length(trim(keterangan)) > 0'),
  )();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}
