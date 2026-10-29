import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';\nimport '../services/pemohon_api_service.dart';

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

  Future<void> syncToCloud(PemohonApiService api) async {
    final pending = await (db.select(db.pemohons)..where((t) => t.isSyncDirty.equals(true))).get();
    for (final snapshot in pending) {
      if (snapshot.uuid.trim().isEmpty) throw StateError('Pemohon lokal ID ${snapshot.id} tidak memiliki UUID.');
      if (snapshot.status != 1 || snapshot.deletedAt != null) {
        // A row created and deleted entirely offline never existed in cloud.
        // Do not send a deactivate request for an unknown UUID.
        if (snapshot.lastSyncedAt == null) {
          await (db.update(db.pemohons)..where((t) => t.id.equals(snapshot.id)))
              .write(PemohonsCompanion(isSyncDirty: const Value(false)));
          continue;
        }
        await api.syncDeactivate(uuid: snapshot.uuid);
        final current = await (db.select(db.pemohons)..where((t) => t.id.equals(snapshot.id))).getSingleOrNull();
        if (current != null && current.isSyncDirty && current.updatedAt == snapshot.updatedAt && current.status == snapshot.status && current.deletedAt == snapshot.deletedAt) {
          await (db.update(db.pemohons)..where((t) => t.id.equals(snapshot.id))).write(PemohonsCompanion(isSyncDirty: const Value(false), lastSyncedAt: Value(DateTime.now())));
        }
        continue;
      }
      String? genderName;
      if (snapshot.jenisKelamin != null) {
        final gender = await (db.select(db.jenisKelamins)..where((t) => t.id.equals(snapshot.jenisKelamin!))).getSingleOrNull();
        if (gender == null) throw StateError('Referensi jenis kelamin Pemohon ID ${snapshot.id} tidak ditemukan.');
        genderName = gender.nama;
      }
      await api.syncUpsert(uuid: snapshot.uuid, nama: snapshot.nama, alamat: snapshot.alamat, jenisKelaminNama: genderName, noTelp: snapshot.noTelp, nik: snapshot.nik);
      final current = await (db.select(db.pemohons)..where((t) => t.id.equals(snapshot.id))).getSingleOrNull();
      if (current != null && current.isSyncDirty && current.updatedAt == snapshot.updatedAt && current.nama == snapshot.nama && current.alamat == snapshot.alamat && current.jenisKelamin == snapshot.jenisKelamin && current.noTelp == snapshot.noTelp && current.nik == snapshot.nik && current.status == snapshot.status) {
        await (db.update(db.pemohons)..where((t) => t.id.equals(snapshot.id))).write(PemohonsCompanion(isSyncDirty: const Value(false), lastSyncedAt: Value(DateTime.now())));
      }
    }
  }

  Future<void> syncFromCloud(List<PemohonApiModel> remoteItems) async {
    await db.transaction(() async {
      final genders = await db.select(db.jenisKelamins).get();
      final localByGenderName = <String, int>{for (final gender in genders) gender.nama.trim().toLowerCase(): gender.id};
      for (final item in remoteItems) {
        final uuid = item.uuid;
        if (uuid == null || uuid.trim().isEmpty) throw const FormatException('Data Pemohon cloud tidak memiliki UUID valid.');
        final existing = await (db.select(db.pemohons)..where((t) => t.uuid.equals(uuid))).getSingleOrNull();
        if (existing?.isSyncDirty == true) continue;
        int? localGenderId;
        final genderName = item.jenisKelaminNama?.trim();
        if (genderName != null && genderName.isNotEmpty) {
          localGenderId = localByGenderName[genderName.toLowerCase()];
          if (localGenderId == null) throw StateError('Jenis kelamin "$genderName" belum tersedia di cache lokal.');
        }
        final values = PemohonsCompanion(
          uuid: Value(uuid), nama: Value(item.nama), alamat: Value(item.alamat), jenisKelamin: Value(localGenderId),
          noTelp: Value(item.noTelp), nik: Value(item.nik), createdBy: Value(item.createdBy), updatedBy: Value(item.updatedBy),
          createdAt: Value(item.createdAt), updatedAt: Value(item.updatedAt), status: Value(item.status),
          isSyncDirty: const Value(false), lastSyncedAt: Value(DateTime.now()), deletedAt: const Value(null),
        );
        if (existing == null) { await db.into(db.pemohons).insert(values); }
        else { await (db.update(db.pemohons)..where((t) => t.id.equals(existing.id))).write(values.copyWith(id: Value(existing.id))); }
      }
    });
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

