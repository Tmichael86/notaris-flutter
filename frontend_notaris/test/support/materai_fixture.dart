import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:frontend_notaris/database/app_database.dart';
import 'package:frontend_notaris/models/auth_session.dart';
import 'package:frontend_notaris/repositories/materai_repository.dart';

import 'transaction_ui_test_support.dart' show uiSession;

AuthSession materaiReader({
  String code = materaiPermissionCode,
  int active = 1,
  int read = 1,
}) => uiSession(groupType: 'superadmin', permission: false)
  ..sidebars.add({
    'sidebar': {
      'sidebar_kode': code,
      'sidebar_nama': 'Materai',
      'status': active,
    },
    'read': read,
  });

typedef FixtureMovement = ({
  int? id,
  String? date,
  String? createdAt,
  Object? stockIn,
  Object? stockOut,
  Object? stock,
  int? officer,
  int? status,
  int? previousId,
  String description,
  List<int> transactions,
});

FixtureMovement movement(
  int? id, {
  String? date = '2026-11-08',
  String? createdAt = '2026-11-17T08:00:00Z',
  Object? stockIn = 0,
  Object? stockOut = 0,
  Object? stock = 20,
  int? officer = 1,
  int? status = 1,
  int? previousId,
  String description = 'Mutasi uji',
  List<int> transactions = const [],
}) => (
  id: id,
  date: date,
  createdAt: createdAt,
  stockIn: stockIn,
  stockOut: stockOut,
  stock: stock,
  officer: officer,
  status: status,
  previousId: previousId,
  description: description,
  transactions: transactions,
);

const demoOfficers = {1: 'Dimas Prasetyo', 2: 'Nadia Pertiwi'};

Future<void> seedMaterai(AppDatabase db) async {
  final rows = [
    movement(1, stockIn: 20, description: 'Penerimaan lembar'),
    movement(
      2,
      previousId: 1,
      date: '2026-11-09',
      stockOut: 2,
      stock: 18,
      officer: 2,
      description: 'Pemakaian PPAT',
      transactions: [51, 52],
    ),
    for (var id = 3; id <= 12; id++)
      movement(
        id,
        previousId: id - 1,
        date: '2026-11-10',
        stockOut: 1,
        stock: 20 - id,
        officer: id.isEven ? 2 : 1,
        description: 'Pemakaian berkas $id',
      ),
    movement(13, previousId: 12, date: '2026-11-10', stock: 99, stockIn: 1),
    movement(14, previousId: 13, date: '2026-11-10', stock: 99, status: 0),
  ];
  await loadSyntheticMaterai(db, 'acceptance', rows, opening: 0);
  await loadSyntheticMaterai(db, 'acceptance', rows, opening: 0);
}

/// Test-only mapping of a Laravel-shaped snapshot. Synthetic source evidence
/// is never used to establish operational authority or loaded at startup.
Future<void> loadSyntheticMaterai(
  AppDatabase db,
  String fixture,
  List<FixtureMovement> source, {
  int? opening,
  Map<int, String> officers = demoOfficers,
}) async {
  if (db is! MateraiProfileDatabase ||
      !RegExp(r'^[a-z0-9-]+$').hasMatch(fixture)) {
    throw StateError('Profil fixture Materai diperlukan.');
  }
  final namespace = 'synthetic:$fixture';
  final rows = <({int id, String hash, List<Object?> values})>[];
  final ids = <int>{};
  int? previousId, previousTime;
  String? previousDate;
  var previousStock = opening;
  for (final raw in source) {
    final id = raw.id;
    if (id == null || id <= 0 || !ids.add(id)) {
      throw StateError('Identitas sumber kosong, tidak valid, atau ganda.');
    }
    final date = _date(raw.date);
    final time = _timestamp(raw.createdAt);
    final stockIn = _quantity(raw.stockIn);
    final stockOut = _quantity(raw.stockOut);
    final stock = _quantity(raw.stock);
    final officer = officers[raw.officer]?.trim();
    final hasOfficer =
        raw.officer != null &&
        raw.officer! > 0 &&
        (officer?.isNotEmpty ?? false);
    final status = raw.status == 1 || raw.status == 0 ? raw.status : null;
    final issues = [
      if (date == null) 'Tanggal bisnis belum terverifikasi',
      if (time == null ||
          (previousId != null && previousTime == null) ||
          (previousTime != null &&
              (time < previousTime ||
                  (time == previousTime && id <= previousId!))))
        'Urutan pencatatan belum terverifikasi',
      if (date != null &&
          previousDate != null &&
          date.compareTo(previousDate) < 0)
        'Tanggal mundur',
      if (raw.previousId != previousId) 'Celah urutan sumber',
      if (stockIn == null || stockOut == null || stock == null)
        'Kuantitas atau stok tidak valid',
      if (stockIn != null && stockOut != null && stockIn > 0 && stockOut > 0)
        'Arah mutasi bertentangan',
      if (status != 1)
        status == 0 ? 'Sumber nonaktif' : 'Status sumber tidak valid',
      if (!hasOfficer) 'Referensi Petugas belum terverifikasi',
      if (raw.transactions.any((id) => id <= 0) ||
          raw.transactions.toSet().length != raw.transactions.length)
        'Referensi transaksi sumber tidak valid',
      if (previousStock == null || previousStock < 0)
        'Saldo pembuka atau saldo sebelumnya belum terverifikasi'
      else if (stockIn != null &&
          stockOut != null &&
          stock != null &&
          BigInt.from(previousStock) +
                  BigInt.from(stockIn) -
                  BigInt.from(stockOut) !=
              BigInt.from(stock))
        'Saldo tercatat tidak cocok dengan mutasi',
    ];
    final provenance = jsonEncode({
      'kind': 'synthetic_fixture',
      'materais.id': id,
      'materais.date': raw.date,
      'materais.created_at': raw.createdAt,
      'materais.materai_masuk': raw.stockIn,
      'materais.materai_keluar': raw.stockOut,
      'materais.stok_materai': raw.stock,
      'materais.keterangan': raw.description,
      'materais.status': raw.status,
      'materais.petugas_id': raw.officer,
      'officer_snapshot': officer,
      'source_previous_id': raw.previousId,
      'declared_opening': opening,
      'transaksi_materai.transaksi_id': raw.transactions.toList()..sort(),
    });
    final hash = sha256.convert(utf8.encode(provenance)).toString();
    rows.add((
      id: id,
      hash: hash,
      values: [
        namespace,
        id,
        date,
        time,
        stockIn,
        stockOut,
        stock,
        raw.description,
        hasOfficer ? raw.officer : null,
        hasOfficer ? officer : null,
        status,
        provenance,
        hash,
        issues.isEmpty ? null : issues.join(' · '),
      ],
    ));
    previousId = id;
    previousTime = time;
    previousDate = date;
    previousStock = issues.isEmpty ? stock : null;
  }
  await db.transaction(() async {
    final existing = await db
        .customSelect(
          'SELECT source_id,payload_sha256 FROM materai_movements WHERE source_namespace=?',
          variables: [Variable(namespace)],
        )
        .get();
    if (existing.isNotEmpty) {
      final hashes = {
        for (final row in existing)
          row.read<int>('source_id'): row.read<String>('payload_sha256'),
      };
      if (hashes.length != rows.length ||
          rows.any((row) => hashes[row.id] != row.hash)) {
        throw StateError(
          'Snapshot bertentangan atau cakupan snapshot berubah.',
        );
      }
      return;
    }
    for (final row in rows) {
      await db.customStatement(
        '''INSERT INTO materai_movements
        (source_namespace,source_id,business_date,source_created_ms,stock_in,stock_out,
         recorded_stock,description,source_officer_id,officer_snapshot,source_status,
         provenance_json,payload_sha256,review_reason) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)''',
        row.values,
      );
    }
  });
}

int? _quantity(Object? value) => value is int && value >= 0 ? value : null;

String? _date(String? value) {
  if (value == null ||
      !RegExp(r'^[0-9]{4}-[0-9]{2}-[0-9]{2}$').hasMatch(value)) {
    return null;
  }
  final parsed = DateTime.tryParse(value);
  return parsed != null &&
          parsed.year > 0 &&
          materaiCalendarDate(parsed) == value
      ? value
      : null;
}

int? _timestamp(String? value) {
  if (value == null ||
      !RegExp(
        r'^[0-9]{4}-[0-9]{2}-[0-9]{2}T(?:[01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]Z$',
      ).hasMatch(value) ||
      _date(value.substring(0, 10)) == null) {
    return null;
  }
  return DateTime.tryParse(value)?.millisecondsSinceEpoch;
}
