import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

import '../database/app_database.dart';
import '../models/auth_session.dart';
import '../models/verified_demo_session.dart';
import 'materai_repository.dart';

part 'materai_stock_correction.dart';

const materaiReceiptLimit = 10000;
const materaiStockLimit = 9007199254740991;

int? parseMateraiSheets(String input) {
  final value = input.trim();
  return RegExp(r'^[0-9]+$').hasMatch(value) ? int.tryParse(value) : null;
}

final _operationPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

class MateraiStockException implements Exception {
  const MateraiStockException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// An explicit binding supplied only by the verified disposable entrypoint.
class MateraiStockBinding {
  MateraiStockBinding(
    this.database,
    this.profileId,
    this.openingSha256, {
    this.pendingReceipt,
    this.transactionUsageEnabled = false,
    this.transactionCorrectionsEnabled = false,
    this.acceptsWrites = true,
  }) {
    if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(profileId) ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(openingSha256)) {
      throw ArgumentError('Binding profil stok Materai tidak valid.');
    }
  }

  final MateraiProfileDatabase database;
  final String profileId, openingSha256;
  final File? pendingReceipt;
  final bool transactionUsageEnabled;
  final bool transactionCorrectionsEnabled;
  final bool acceptsWrites;
  String get namespace => 'local:materai:$profileId';
}

typedef MateraiStockContext = ({
  int predecessor,
  int stock,
  String date,
  int officerId,
  String officer,
  int actorId,
});
typedef MateraiStockResult = ({int id, int stock, bool replayed});

typedef MateraiTransactionUsage = ({
  String uuid,
  String domain,
  String number,
  String date,
  int sheets,
  String fingerprint,
});

const materaiUsageProtected =
    'Transaksi tertaut ke ledger meterai. Gunakan profil koreksi untuk mengubah jumlah. Pembatalan dan penghapusan masih diblokir.';

Future<bool> hasMateraiUsageProfile(AppDatabase db) async {
  if (db.schemaVersion < 27) return false;
  return await db.customSelect(r'''
    SELECT 1 FROM materai_movements
    WHERE (source_namespace GLOB 'local:materai:*:opening'
           AND json_extract(provenance_json,'$.transaction_usage')=1)
       OR source_namespace GLOB 'local:materai:*:transaction:*'
    LIMIT 1
    ''').getSingleOrNull() !=
      null;
}

Future<bool> hasInitialMateraiUsage(AppDatabase db, String uuid) async {
  if (db.schemaVersion < 27) return false;
  return await db
          .customSelect(
            r'''
    SELECT 1 FROM materai_movements
    WHERE (source_namespace GLOB 'local:materai:*:transaction:*'
           AND substr(source_namespace,-36)=?)
       OR json_extract(provenance_json,'$.transaction_uuid')=?
    LIMIT 1
    ''',
            variables: [Variable(uuid), Variable(uuid)],
          )
          .getSingleOrNull() !=
      null;
}

String materaiProvenanceHash(String json) =>
    sha256.convert(utf8.encode(json)).toString();

class MateraiStockRepository {
  MateraiStockRepository(
    this.binding,
    this._currentSession, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final MateraiStockBinding binding;
  final AuthSession? Function() _currentSession;
  final DateTime Function() _now;
  MateraiProfileDatabase get _db => binding.database;

  ExpiringPaymentDemoSession _actor({
    bool transactionUsage = false,
    bool correction = false,
  }) {
    final session = _currentSession();
    final now = _now();
    if (session is! ExpiringPaymentDemoSession ||
        session.profileId != binding.profileId ||
        (transactionUsage && !binding.transactionUsageEnabled) ||
        !(correction
            ? binding.transactionCorrectionsEnabled &&
                  binding.transactionUsageEnabled &&
                  session.hasTransactionAccess(update: true)
            : transactionUsage
            ? session.hasTransactionAccess(create: true)
            : canCreateMaterai(session)) ||
        session.groupId <= 0 ||
        session.token.isEmpty ||
        now.isBefore(session.verifiedAt) ||
        !now.isBefore(session.expiresAt)) {
      throw MateraiStockException(
        correction
            ? 'Sesi terverifikasi dengan izin ubah Transaksi diperlukan untuk koreksi meterai.'
            : transactionUsage
            ? 'Sesi terverifikasi dengan izin buat Transaksi diperlukan untuk pemakaian meterai.'
            : 'Sesi terverifikasi dengan izin buat Materai diperlukan.',
      );
    }
    return session;
  }

  void _verifySession(
    ExpiringPaymentDemoSession original, {
    bool transactionUsage = false,
    bool correction = false,
  }) {
    if (!identical(
      _actor(transactionUsage: transactionUsage, correction: correction),
      original,
    )) {
      throw const MateraiStockException('Sesi berubah. Buka ulang formulir.');
    }
  }

  Future<void> _writable() async {
    final queryOnly = await _db.customSelect('PRAGMA query_only').getSingle();
    final version = await _db.customSelect('PRAGMA user_version').getSingle();
    if (!binding.acceptsWrites ||
        queryOnly.read<int>('query_only') != 0 ||
        version.read<int>('user_version') != 27) {
      throw const MateraiStockException(
        'Profil SQLite ini tidak membuka penerimaan stok.',
      );
    }
  }

  Future<PetugasLocal> _officer(int userId) async {
    final matches =
        await (_db.select(_db.petugasLocals)..where(
              (table) =>
                  table.userId.equals(userId) &
                  table.status.equals(1) &
                  table.deletedAt.isNull(),
            ))
            .get();
    if (matches.length != 1 ||
        matches.single.uuid.trim().isEmpty ||
        matches.single.nama.trim().isEmpty) {
      throw const MateraiStockException(
        'Akun belum mempunyai satu pemetaan Petugas aktif yang sah.',
      );
    }
    return matches.single;
  }

  Future<MateraiStockContext> context({bool transactionUsage = false}) async {
    final actor = _actor(transactionUsage: transactionUsage);
    await _writable();
    final officer = await _officer(actor.userId);
    final result = await _head(officer, transactionUsage: transactionUsage);
    _verifySession(actor, transactionUsage: transactionUsage);
    return result;
  }

  Future<bool> receiptExists(String operation) async {
    final actor = _actor();
    if (!_operationPattern.hasMatch(operation)) {
      throw const MateraiStockException('Identitas draf tidak valid.');
    }
    final exists = await _db
        .customSelect(
          'SELECT id FROM materai_movements WHERE source_namespace=? AND source_id=1',
          variables: [Variable('${binding.namespace}:receipt:$operation')],
        )
        .getSingleOrNull();
    _verifySession(actor);
    return exists != null;
  }

  Future<MateraiStockContext> _head(
    PetugasLocal officer, {
    bool transactionUsage = false,
    bool correction = false,
  }) async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM materai_movements ORDER BY source_created_ms, id',
        )
        .get();
    var stock = 0;
    String? date;
    var predecessor = 0;
    int? recorded;
    final usages =
        <String, ({int id, String domain, int sheets, int original})>{};
    final corrections = <String>{};
    const invalid = MateraiStockException(
      'Perlu Ditinjau: saldo pembuka atau rantai stok meterai belum terverifikasi.',
    );
    if (rows.isEmpty) throw invalid;
    for (final row in rows) {
      final namespace = row.read<String>('source_namespace');
      final hash = row.read<String>('payload_sha256');
      final payload = row.read<String>('provenance_json');
      final Object? provenance;
      try {
        provenance = jsonDecode(payload);
      } on FormatException {
        throw invalid;
      }
      final currentDate = row.readNullable<String>('business_date');
      final timestamp = row.readNullable<int>('source_created_ms');
      final incoming = row.readNullable<int>('stock_in');
      final outgoing = row.readNullable<int>('stock_out');
      final currentStock = row.readNullable<int>('recorded_stock');
      if (provenance is! Map ||
          provenance['profile'] != binding.profileId ||
          hash != materaiProvenanceHash(payload) ||
          row.read<int>('source_id') != 1 ||
          row.readNullable<int>('source_status') != 1 ||
          row.readNullable<String>('review_reason') != null ||
          !_validDate(currentDate) ||
          timestamp == null ||
          incoming == null ||
          currentStock == null ||
          currentStock < 0 ||
          currentStock > materaiStockLimit ||
          outgoing == null) {
        throw invalid;
      }
      if (date == null) {
        if (namespace != '${binding.namespace}:opening' ||
            hash != binding.openingSha256 ||
            provenance['kind'] != 'synthetic_verified_opening' ||
            (transactionUsage && provenance['transaction_usage'] != true) ||
            (correction && provenance['transaction_correction'] != true) ||
            incoming != 0 ||
            outgoing != 0 ||
            provenance['opening'] != currentStock ||
            provenance['date'] != currentDate ||
            provenance['recorded_ms'] != timestamp ||
            provenance['officer_id'] !=
                row.readNullable<int>('source_officer_id') ||
            provenance['officer'] !=
                row.readNullable<String>('officer_snapshot') ||
            provenance['description'] != row.read<String>('description')) {
          throw invalid;
        }
      } else {
        if ((incoming == 0) == (outgoing == 0) ||
            row.read<int>('id') <= predecessor ||
            currentDate!.compareTo(date) < 0 ||
            timestamp <= recorded! ||
            provenance['previous'] != predecessor ||
            incoming < 0 ||
            outgoing < 0 ||
            incoming + outgoing > materaiReceiptLimit ||
            stock < outgoing ||
            stock > materaiStockLimit - incoming ||
            currentStock != stock + incoming - outgoing ||
            provenance['stock'] != currentStock ||
            provenance['quantity'] != incoming + outgoing ||
            provenance['date'] != currentDate ||
            provenance['recorded_ms'] != timestamp ||
            provenance['description'] != row.read<String>('description') ||
            provenance['officer_id'] !=
                row.readNullable<int>('source_officer_id') ||
            provenance['officer'] !=
                row.readNullable<String>('officer_snapshot') ||
            provenance['user_id'] is! int ||
            provenance['group_id'] is! int ||
            (provenance['user_id'] as int) <= 0 ||
            (provenance['group_id'] as int) <= 0) {
          throw invalid;
        }
        if (!_adoptMovement(
          row.read<int>('id'),
          namespace,
          provenance,
          incoming,
          outgoing,
          usages,
          corrections,
        )) {
          throw invalid;
        }
      }
      predecessor = row.read<int>('id');
      stock = currentStock;
      date = currentDate;
      recorded = timestamp;
    }
    for (final MapEntry(key: uuid, value: usage) in usages.entries) {
      final parent = await (_db.select(
        _db.transaksis,
      )..where((table) => table.uuid.equals(uuid))).getSingleOrNull();
      if (parent == null ||
          parent.deletedAt != null ||
          isMateraiCancellation(parent.statusTransaksi) ||
          parent.jenisTransaksi != usage.domain ||
          parent.id != usage.id ||
          parent.jumlahMaterai != usage.sheets) {
        throw MateraiStockException(
          'Perlu Ditinjau: pemakaian tercatat berbeda untuk transaksi $uuid.',
        );
      }
    }
    return (
      predecessor: predecessor,
      stock: stock,
      date: date!,
      officerId: officer.id,
      officer: officer.nama,
      actorId: officer.userId!,
    );
  }

  bool _adoptMovement(
    int id,
    String namespace,
    Map proof,
    int incoming,
    int outgoing,
    Map<String, ({int id, String domain, int sheets, int original})> usages,
    Set<String> corrections,
  ) {
    if (proof['kind'] == 'manual_stock_in') {
      final op = proof['operation'];
      return op is String &&
          _operationPattern.hasMatch(op) &&
          outgoing == 0 &&
          namespace == '${binding.namespace}:receipt:$op';
    }
    final uuid = proof['transaction_uuid'];
    final domain = proof['domain'];
    final parent = proof['transaction_id'];
    if (uuid is! String ||
        !_operationPattern.hasMatch(uuid) ||
        domain is! String ||
        !{'notaris', 'ppat'}.contains(domain) ||
        parent is! int ||
        parent <= 0) {
      return false;
    }
    final initial = '${binding.namespace}:transaction:$uuid';
    final previousUsage = usages[uuid];
    if (proof['kind'] == 'transaction_stock_out') {
      if (incoming != 0 || previousUsage != null || namespace != initial) {
        return false;
      }
      usages[uuid] = (
        id: parent,
        domain: domain,
        sheets: outgoing,
        original: id,
      );
      return true;
    }
    final operation = proof['operation'];
    final newSheets = proof['new_quantity'];
    final revision = proof['expected_revision'];
    final requestHash = proof['request_sha256'];
    final digest = RegExp(r'^[0-9a-f]{64}$');
    if (operation is! String ||
        !_operationPattern.hasMatch(operation) ||
        revision is! String ||
        !digest.hasMatch(revision) ||
        requestHash is! String ||
        !digest.hasMatch(requestHash) ||
        namespace != '$initial:adjustment:$operation' ||
        previousUsage == null ||
        previousUsage.id != parent ||
        previousUsage.domain != domain ||
        previousUsage.original != proof['original_movement'] ||
        previousUsage.sheets != proof['old_quantity'] ||
        newSheets is! int ||
        newSheets < 0 ||
        newSheets > materaiReceiptLimit ||
        newSheets - previousUsage.sheets != outgoing - incoming ||
        proof['delta'] != outgoing - incoming ||
        proof['kind'] !=
            (incoming > 0
                ? 'transaction_usage_return'
                : 'transaction_usage_increase')) {
      return false;
    }
    if (!corrections.add(operation)) return false;
    usages[uuid] = (
      id: parent,
      domain: domain,
      sheets: newSheets,
      original: previousUsage.original,
    );
    return true;
  }

  /// Owns the single transaction. The callback must persist the new header and
  /// its dependents through the bound database, in this Drift transaction.
  Future<int> saveTransactionWithUsage(
    AppDatabase db,
    MateraiTransactionUsage usage,
    Future<int> Function() persist,
  ) async {
    if (!identical(db, _db) ||
        !_operationPattern.hasMatch(usage.uuid) ||
        !_validDate(usage.date) ||
        usage.sheets < 1 ||
        usage.sheets > materaiReceiptLimit) {
      throw const MateraiStockException(
        'Identitas atau jumlah pemakaian meterai tidak valid.',
      );
    }
    final actor = _actor(transactionUsage: true);
    await _writable();
    final namespace = '${binding.namespace}:transaction:${usage.uuid}';
    try {
      return await _db.transaction(() async {
        await _writable();
        final officer = await _officer(actor.userId);
        final current = await _head(officer, transactionUsage: true);
        final existing = await _db
            .customSelect(
              '''
          SELECT provenance_json FROM materai_movements
          WHERE source_namespace=? AND source_id=1
          ''',
              variables: [Variable(namespace)],
            )
            .getSingleOrNull();
        _verifySession(actor, transactionUsage: true);
        if (existing != null) {
          final stored =
              jsonDecode(existing.read<String>('provenance_json')) as Map;
          if (stored['request_sha256'] != usage.fingerprint ||
              stored['quantity'] != usage.sheets ||
              stored['user_id'] != actor.userId ||
              stored['group_id'] != actor.groupId) {
            throw const MateraiStockException(
              'Identitas transaksi sudah dipakai dengan isi berbeda.',
            );
          }
          return stored['transaction_id'] as int;
        }
        final prior = await (_db.select(
          _db.transaksis,
        )..where((table) => table.uuid.equals(usage.uuid))).getSingleOrNull();
        if (prior != null) {
          throw const MateraiStockException(
            'Transaksi lama tidak dapat ditambahkan ke ledger otomatis.',
          );
        }
        if (usage.sheets > current.stock) {
          throw MateraiStockException(
            'Stok meterai tidak cukup. Tersedia ${current.stock} lembar.',
          );
        }
        if (usage.date.compareTo(current.date) < 0) {
          throw const MateraiStockException(
            'Tanggal transaksi mendahului mutasi meterai terakhir.',
          );
        }
        final id = await persist();
        final parent = await (_db.select(
          _db.transaksis,
        )..where((table) => table.id.equals(id))).getSingle();
        if (parent.uuid != usage.uuid ||
            parent.jenisTransaksi != usage.domain ||
            parent.noAkta != usage.number ||
            parent.tanggalTransaksi == null ||
            materaiCalendarDate(parent.tanggalTransaksi!) != usage.date ||
            parent.jumlahMaterai != usage.sheets ||
            parent.deletedAt != null ||
            isMateraiCancellation(parent.statusTransaksi)) {
          throw const MateraiStockException(
            'Transaksi sumber pemakaian meterai tidak cocok.',
          );
        }
        final recorded = _now().millisecondsSinceEpoch;
        final head = await _db
            .customSelect(
              'SELECT source_created_ms FROM materai_movements WHERE id=?',
              variables: [Variable(current.predecessor)],
            )
            .getSingle();
        if (recorded <= head.read<int>('source_created_ms')) {
          throw const MateraiStockException(
            'Waktu pencatatan belum melewati mutasi terakhir. Periksa jam perangkat.',
          );
        }
        final stock = current.stock - usage.sheets;
        final notes =
            'Pemakaian ${usage.domain.toUpperCase()} · ${usage.number}';
        final proof = jsonEncode({
          'kind': 'transaction_stock_out',
          'profile': binding.profileId,
          'transaction_uuid': usage.uuid,
          'transaction_id': id,
          'domain': usage.domain,
          'request_sha256': usage.fingerprint,
          'previous': current.predecessor,
          'date': usage.date,
          'recorded_ms': recorded,
          'quantity': usage.sheets,
          'stock': stock,
          'description': notes,
          'user_id': actor.userId,
          'group_id': actor.groupId,
          'actor_verified_at': actor.verifiedAt.toUtc().toIso8601String(),
          'officer_id': officer.id,
          'officer_uuid': officer.uuid,
          'officer': officer.nama,
        });
        _verifySession(actor, transactionUsage: true);
        await _db.customInsert(
          '''
          INSERT INTO materai_movements
          (source_namespace,source_id,business_date,source_created_ms,stock_in,stock_out,
           recorded_stock,description,source_officer_id,officer_snapshot,source_status,
           provenance_json,payload_sha256) VALUES (?,1,?,?,0,?,?,?,?,?,1,?,?)
          ''',
          variables: [
            Variable(namespace),
            Variable(usage.date),
            Variable(recorded),
            Variable(usage.sheets),
            Variable(stock),
            Variable(notes),
            Variable(officer.id),
            Variable(officer.nama),
            Variable(proof),
            Variable(materaiProvenanceHash(proof)),
          ],
        );
        return id;
      });
    } on SqliteException catch (error) {
      if ({5, 6, 8}.contains(error.resultCode)) {
        throw const MateraiStockException(
          'Profil tidak dapat menulis stok saat ini. Periksa hasil dan ulangi transaksi yang sama.',
        );
      }
      rethrow;
    }
  }

  Future<MateraiStockResult> receive({
    required String operation,
    required int expectedPredecessor,
    required String businessDate,
    required Object? sheets,
    String description = '',
  }) async {
    final actor = _actor();
    final notes = description.trim();
    if (!_operationPattern.hasMatch(operation) ||
        !_validDate(businessDate) ||
        sheets is! int ||
        sheets < 1 ||
        sheets > materaiReceiptLimit ||
        notes.length > 250) {
      throw const MateraiStockException(
        'Isi tanggal yang sah, 1–10.000 lembar, dan keterangan sampai 250 karakter.',
      );
    }
    final namespace = '${binding.namespace}:receipt:$operation';
    await _writable();
    try {
      return await _db.transaction(() async {
        await _writable();
        final officer = await _officer(actor.userId);
        final current = await _head(officer);
        final existing = await _db
            .customSelect(
              'SELECT id, recorded_stock, provenance_json FROM materai_movements WHERE source_namespace=? AND source_id=1',
              variables: [Variable(namespace)],
            )
            .getSingleOrNull();
        _verifySession(actor);
        if (existing != null) {
          final previous =
              jsonDecode(existing.read<String>('provenance_json')) as Map;
          if (previous['user_id'] != actor.userId ||
              previous['group_id'] != actor.groupId ||
              previous['previous'] != expectedPredecessor ||
              previous['date'] != businessDate ||
              previous['quantity'] != sheets ||
              previous['description'] != notes) {
            throw const MateraiStockException(
              'ID operasi sudah dipakai dengan isi berbeda.',
            );
          }
          return (
            id: existing.read<int>('id'),
            stock: existing.read<int>('recorded_stock'),
            replayed: true,
          );
        }
        if (current.predecessor != expectedPredecessor) {
          throw const MateraiStockException(
            'Stok berubah. Buka ulang formulir untuk meninjau saldo.',
          );
        }
        if (businessDate.compareTo(current.date) < 0) {
          throw const MateraiStockException(
            'Tanggal penerimaan mendahului mutasi terakhir.',
          );
        }
        if (current.stock > materaiStockLimit - sheets) {
          throw const MateraiStockException(
            'Stok melebihi batas integer yang didukung.',
          );
        }
        final stock = current.stock + sheets;
        final timestamp = _now().millisecondsSinceEpoch;
        final head = await _db
            .customSelect(
              'SELECT source_created_ms FROM materai_movements WHERE id=?',
              variables: [Variable(current.predecessor)],
            )
            .getSingle();
        if (timestamp <= head.read<int>('source_created_ms')) {
          throw const MateraiStockException(
            'Waktu pencatatan belum melewati mutasi terakhir. Periksa jam perangkat.',
          );
        }
        final provenance = jsonEncode({
          'kind': 'manual_stock_in',
          'profile': binding.profileId,
          'operation': operation,
          'previous': current.predecessor,
          'date': businessDate,
          'recorded_ms': timestamp,
          'quantity': sheets,
          'stock': stock,
          'description': notes,
          'user_id': actor.userId,
          'group_id': actor.groupId,
          'actor_verified_at': actor.verifiedAt.toUtc().toIso8601String(),
          'officer_id': officer.id,
          'officer_uuid': officer.uuid,
          'officer': officer.nama,
        });
        _verifySession(actor);
        final id = await _db.customInsert(
          '''
          INSERT INTO materai_movements
          (source_namespace,source_id,business_date,source_created_ms,stock_in,stock_out,
           recorded_stock,description,source_officer_id,officer_snapshot,source_status,provenance_json,payload_sha256)
          VALUES (?,1,?,?,?,0,?,?,?,?,1,?,?)
        ''',
          variables: [
            Variable(namespace),
            Variable(businessDate),
            Variable(timestamp),
            Variable(sheets),
            Variable(stock),
            Variable(notes),
            Variable(officer.id),
            Variable(officer.nama),
            Variable(provenance),
            Variable(materaiProvenanceHash(provenance)),
          ],
        );
        return (id: id, stock: stock, replayed: false);
      });
    } on SqliteException catch (error) {
      if (error.resultCode == 8) {
        throw const MateraiStockException(
          'Profil SQLite ini tidak membuka penerimaan stok.',
        );
      }
      if ({5, 6}.contains(error.resultCode)) {
        throw const MateraiStockException(
          'Mutasi sedang diproses. Periksa hasil atau ulangi operasi yang sama.',
        );
      }
      rethrow;
    }
  }
}

bool isMateraiCancellation(String status) => const {
  'batal',
  'dibatalkan',
  'dihapus',
  'cancelled',
  'canceled',
}.contains(status.trim().toLowerCase());

bool _validDate(String? value) {
  if (value == null ||
      !RegExp(r'^[0-9]{4}-[0-9]{2}-[0-9]{2}$').hasMatch(value)) {
    return false;
  }
  final parsed = DateTime.tryParse(value);
  return parsed != null &&
      parsed.year > 0 &&
      materaiCalendarDate(parsed) == value;
}
