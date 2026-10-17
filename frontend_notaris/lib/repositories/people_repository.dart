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
  }) async {
    final normalizedNama = _requiredText(nama, 'Nama petugas');
    final normalizedEmail = _requiredText(email, 'Email');

    final now = DateTime.now();

    return db
        .into(db.petugasLocals)
        .insert(
          PetugasLocalsCompanion.insert(
            uuid: _uuid.v4(),
            nama: normalizedNama,
            nik: Value(_text(nik)),
            alamat: Value(_text(alamat)),
            tempatLahir: Value(_text(tempatLahir)),
            tanggalLahir: Value(tanggalLahir),
            jenisKelamin: Value(jenisKelamin),
            noTelp: Value(_text(noTelp)),
            email: normalizedEmail,
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
    final normalizedNama = _requiredText(nama, 'Nama petugas');
    final normalizedEmail = _requiredText(email, 'Email');
    final now = DateTime.now();

    final affected =
        await (db.update(db.petugasLocals)..where(
              (t) =>
                  t.id.equals(id) & t.status.equals(1) & t.deletedAt.isNull(),
            ))
            .write(
              PetugasLocalsCompanion(
                nama: Value(normalizedNama),
                nik: Value(_text(nik)),
                alamat: Value(_text(alamat)),
                tempatLahir: Value(_text(tempatLahir)),
                tanggalLahir: Value(tanggalLahir),
                jenisKelamin: Value(jenisKelamin),
                noTelp: Value(_text(noTelp)),
                email: Value(normalizedEmail),
                userId: Value(userId),
                updatedAt: Value(now),
                isSyncDirty: const Value(true),
              ),
            );

    return affected > 0;
  }

  Future<bool> delete(int id) async {
    final now = DateTime.now();

    final affected =
        await (db.update(db.petugasLocals)..where(
              (t) =>
                  t.id.equals(id) & t.status.equals(1) & t.deletedAt.isNull(),
            ))
            .write(
              PetugasLocalsCompanion(
                status: const Value(0),
                deletedAt: Value(now),
                updatedAt: Value(now),
                isSyncDirty: const Value(true),
              ),
            );

    return affected > 0;
  }

  static String _requiredText(String value, String label) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      throw ArgumentError('$label wajib diisi.');
    }

    return normalized;
  }

  static String? _text(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
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
    final normalizedNama = _requiredText(nama);
    final now = DateTime.now();

    return db.into(db.pemohons).insert(
          PemohonsCompanion.insert(
            uuid: _uuid.v4(),
            nama: normalizedNama,
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
    final normalizedNama = _requiredText(nama);
    final now = DateTime.now();

    final affected = await (db.update(db.pemohons)
          ..where(
            (t) =>
                t.id.equals(id) &
                t.status.equals(1) &
                t.deletedAt.isNull(),
          ))
        .write(
      PemohonsCompanion(
        nama: Value(normalizedNama),
        alamat: Value(_text(alamat)),
        jenisKelamin: Value(jenisKelamin),
        noTelp: Value(_text(noTelp)),
        nik: Value(_text(nik)),
        updatedAt: Value(now),
        isSyncDirty: const Value(true),
      ),
    );

    return affected > 0;
  }

  Future<bool> delete(int id) async {
    final now = DateTime.now();

    final affected = await (db.update(db.pemohons)
          ..where(
            (t) =>
                t.id.equals(id) &
                t.status.equals(1) &
                t.deletedAt.isNull(),
          ))
        .write(
      PemohonsCompanion(
        status: const Value(0),
        deletedAt: Value(now),
        updatedAt: Value(now),
        isSyncDirty: const Value(true),
      ),
    );

    return affected > 0;
  }

  static String _requiredText(String value) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      throw ArgumentError('Nama pemohon wajib diisi.');
    }

    return normalized;
  }

  static String? _text(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}

