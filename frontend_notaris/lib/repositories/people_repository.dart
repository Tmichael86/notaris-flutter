
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';

class JenisKelaminRepository {
  JenisKelaminRepository(this.db);
  final AppDatabase db;

  Stream<List<JenisKelamin>> watchAll() {
    return (db.select(db.jenisKelamins)
          ..where((t) => t.status.equals(1) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.nama)]))
        .watch();
  }
}

class PetugasRepository {
  PetugasRepository(this.db);
  final AppDatabase db;
  static const _uuid = Uuid();

  Stream<List<PetugasLocal>> watchAll() {
    return (db.select(db.petugasLocals)
          ..where((t) => t.status.equals(1) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.nama)]))
        .watch();
  }

  Future<int> create({
    required String nama,
    String? nik,
    String? alamat,
    String? tempatLahir,
    DateTime? tanggalLahir,
    int? jenisKelamin,
    String? noTelp,
    required String email,
    int? userId,
  }) {
    final now = DateTime.now();
    return db.into(db.petugasLocals).insert(
      PetugasLocalsCompanion.insert(
        uuid: _uuid.v4(),
        nama: nama,
        nik: Value(_text(nik)),
        alamat: Value(_text(alamat)),
        tempatLahir: Value(_text(tempatLahir)),
        tanggalLahir: Value(tanggalLahir),
        jenisKelamin: Value(jenisKelamin),
        noTelp: Value(_text(noTelp)),
        email: email,
        userId: Value(userId),
        createdAt: Value(now),
        updatedAt: Value(now),
        isSyncDirty: const Value(true),
      ),
    );
  }

  Future<bool> update({
    required int id,
    required String nama,
    String? nik,
    String? alamat,
    String? tempatLahir,
    DateTime? tanggalLahir,
    int? jenisKelamin,
    String? noTelp,
    required String email,
    int? userId,
  }) async {
    final affected = await (db.update(db.petugasLocals)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .write(
      PetugasLocalsCompanion(
        nama: Value(nama),
        nik: Value(_text(nik)),
        alamat: Value(_text(alamat)),
        tempatLahir: Value(_text(tempatLahir)),
        tanggalLahir: Value(tanggalLahir),
        jenisKelamin: Value(jenisKelamin),
        noTelp: Value(_text(noTelp)),
        email: Value(email),
        userId: Value(userId),
        updatedAt: Value(DateTime.now()),
        isSyncDirty: const Value(true),
      ),
    );
    return affected > 0;
  }

  Future<bool> delete(int id) async {
    final affected = await (db.update(db.petugasLocals)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .write(
      PetugasLocalsCompanion(
        status: const Value(0),
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        isSyncDirty: const Value(true),
      ),
    );
    return affected > 0;
  }

  static String? _text(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

class PemohonRepository {
  PemohonRepository(this.db);
  final AppDatabase db;
  static const _uuid = Uuid();

  Stream<List<Pemohon>> watchAll() {
    return (db.select(db.pemohons)
          ..where((t) => t.status.equals(1) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.nama)]))
        .watch();
  }

  Future<int> create({
    required String nama,
    String? alamat,
    int? jenisKelamin,
    String? noTelp,
    String? nik,
  }) {
    final now = DateTime.now();
    return db.into(db.pemohons).insert(
      PemohonsCompanion.insert(
        uuid: _uuid.v4(),
        nama: nama,
        alamat: Value(_text(alamat)),
        jenisKelamin: Value(jenisKelamin),
        noTelp: Value(_text(noTelp)),
        nik: Value(_text(nik)),
        createdAt: Value(now),
        updatedAt: Value(now),
        isSyncDirty: const Value(true),
      ),
    );
  }

  Future<bool> update({
    required int id,
    required String nama,
    String? alamat,
    int? jenisKelamin,
    String? noTelp,
    String? nik,
  }) async {
    final affected = await (db.update(db.pemohons)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .write(
      PemohonsCompanion(
        nama: Value(nama),
        alamat: Value(_text(alamat)),
        jenisKelamin: Value(jenisKelamin),
        noTelp: Value(_text(noTelp)),
        nik: Value(_text(nik)),
        updatedAt: Value(DateTime.now()),
        isSyncDirty: const Value(true),
      ),
    );
    return affected > 0;
  }

  Future<bool> delete(int id) async {
    final affected = await (db.update(db.pemohons)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .write(
      PemohonsCompanion(
        status: const Value(0),
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        isSyncDirty: const Value(true),
      ),
    );
    return affected > 0;
  }

  static String? _text(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
