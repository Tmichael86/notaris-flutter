import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

import '../database/app_database.dart';
import '../models/auth_session.dart';
import '../models/verified_demo_session.dart';
import 'materai_repository.dart';

const materaiReceiptLimit = 10000;
const materaiStockLimit = 9007199254740991;
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
  }) {
    if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(profileId) ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(openingSha256)) {
      throw ArgumentError('Binding profil stok Materai tidak valid.');
    }
  }

  final MateraiProfileDatabase database;
  final String profileId, openingSha256;
  final File? pendingReceipt;
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

  ExpiringPaymentDemoSession _actor() {
    final session = _currentSession();
    final now = _now();
    if (session is! ExpiringPaymentDemoSession ||
        session.profileId != binding.profileId ||
        !canCreateMaterai(session) ||
        session.groupId <= 0 ||
        session.token.isEmpty ||
        now.isBefore(session.verifiedAt) ||
        !now.isBefore(session.expiresAt)) {
      throw const MateraiStockException(
        'Sesi terverifikasi dengan izin buat Materai diperlukan.',
      );
    }
    return session;
  }

  void _verifySession(ExpiringPaymentDemoSession original) {
    if (!identical(_actor(), original)) {
      throw const MateraiStockException('Sesi berubah. Buka ulang formulir.');
    }
  }

  Future<void> _writable() async {
    final queryOnly = await _db.customSelect('PRAGMA query_only').getSingle();
    final version = await _db.customSelect('PRAGMA user_version').getSingle();
    if (queryOnly.read<int>('query_only') != 0 ||
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

  Future<MateraiStockContext> context() async {
    final actor = _actor();
    await _writable();
    final officer = await _officer(actor.userId);
    final result = await _head(officer);
    _verifySession(actor);
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

  Future<MateraiStockContext> _head(PetugasLocal officer) async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM materai_movements ORDER BY source_created_ms, id',
        )
        .get();
    var stock = 0;
    String? date;
    var predecessor = 0;
    int? recorded;
    const invalid = MateraiStockException(
      'Saldo pembuka atau rantai stok belum terverifikasi. Penerimaan diblokir.',
    );
    if (rows.isEmpty) throw invalid;
    for (final row in rows) {
      final namespace = row.read<String>('source_namespace');
      final hash = row.read<String>('payload_sha256');
      final payload = row.read<String>('provenance_json');
      final provenance = jsonDecode(payload);
      final currentDate = row.readNullable<String>('business_date');
      final timestamp = row.readNullable<int>('source_created_ms');
      final incoming = row.readNullable<int>('stock_in');
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
          currentStock > materaiStockLimit ||
          row.readNullable<int>('stock_out') != 0) {
        throw invalid;
      }
      if (date == null) {
        if (namespace != '${binding.namespace}:opening' ||
            hash != binding.openingSha256 ||
            provenance['kind'] != 'synthetic_verified_opening' ||
            incoming != 0 ||
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
        final operation = provenance['operation'];
        if (operation is! String ||
            !_operationPattern.hasMatch(operation) ||
            namespace != '${binding.namespace}:receipt:$operation' ||
            provenance['kind'] != 'manual_stock_in' ||
            currentDate!.compareTo(date) < 0 ||
            timestamp <= recorded! ||
            provenance['previous'] != predecessor ||
            incoming < 1 ||
            incoming > materaiReceiptLimit ||
            stock > materaiStockLimit - incoming ||
            currentStock != stock + incoming ||
            provenance['stock'] != currentStock ||
            provenance['quantity'] != incoming ||
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
      }
      predecessor = row.read<int>('id');
      stock = currentStock;
      date = currentDate;
      recorded = timestamp;
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
