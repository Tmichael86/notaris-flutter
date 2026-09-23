// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $PemohonsTable extends Pemohons with TableInfo<$PemohonsTable, Pemohon> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PemohonsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _namaMeta = const VerificationMeta('nama');
  @override
  late final GeneratedColumn<String> nama = GeneratedColumn<String>(
    'nama',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _alamatMeta = const VerificationMeta('alamat');
  @override
  late final GeneratedColumn<String> alamat = GeneratedColumn<String>(
    'alamat',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nikMeta = const VerificationMeta('nik');
  @override
  late final GeneratedColumn<String> nik = GeneratedColumn<String>(
    'nik',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isSyncDirtyMeta = const VerificationMeta(
    'isSyncDirty',
  );
  @override
  late final GeneratedColumn<bool> isSyncDirty = GeneratedColumn<bool>(
    'is_sync_dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_sync_dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uuid,
    nama,
    alamat,
    nik,
    isSyncDirty,
    lastSyncedAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pemohons';
  @override
  VerificationContext validateIntegrity(
    Insertable<Pemohon> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('nama')) {
      context.handle(
        _namaMeta,
        nama.isAcceptableOrUnknown(data['nama']!, _namaMeta),
      );
    } else if (isInserting) {
      context.missing(_namaMeta);
    }
    if (data.containsKey('alamat')) {
      context.handle(
        _alamatMeta,
        alamat.isAcceptableOrUnknown(data['alamat']!, _alamatMeta),
      );
    }
    if (data.containsKey('nik')) {
      context.handle(
        _nikMeta,
        nik.isAcceptableOrUnknown(data['nik']!, _nikMeta),
      );
    }
    if (data.containsKey('is_sync_dirty')) {
      context.handle(
        _isSyncDirtyMeta,
        isSyncDirty.isAcceptableOrUnknown(
          data['is_sync_dirty']!,
          _isSyncDirtyMeta,
        ),
      );
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Pemohon map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Pemohon(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      nama: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nama'],
      )!,
      alamat: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alamat'],
      ),
      nik: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nik'],
      ),
      isSyncDirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_sync_dirty'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $PemohonsTable createAlias(String alias) {
    return $PemohonsTable(attachedDatabase, alias);
  }
}

class Pemohon extends DataClass implements Insertable<Pemohon> {
  final int id;
  final String uuid;
  final String nama;
  final String? alamat;
  final String? nik;
  final bool isSyncDirty;
  final DateTime? lastSyncedAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  const Pemohon({
    required this.id,
    required this.uuid,
    required this.nama,
    this.alamat,
    this.nik,
    required this.isSyncDirty,
    this.lastSyncedAt,
    this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['nama'] = Variable<String>(nama);
    if (!nullToAbsent || alamat != null) {
      map['alamat'] = Variable<String>(alamat);
    }
    if (!nullToAbsent || nik != null) {
      map['nik'] = Variable<String>(nik);
    }
    map['is_sync_dirty'] = Variable<bool>(isSyncDirty);
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  PemohonsCompanion toCompanion(bool nullToAbsent) {
    return PemohonsCompanion(
      id: Value(id),
      uuid: Value(uuid),
      nama: Value(nama),
      alamat: alamat == null && nullToAbsent
          ? const Value.absent()
          : Value(alamat),
      nik: nik == null && nullToAbsent ? const Value.absent() : Value(nik),
      isSyncDirty: Value(isSyncDirty),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Pemohon.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Pemohon(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      nama: serializer.fromJson<String>(json['nama']),
      alamat: serializer.fromJson<String?>(json['alamat']),
      nik: serializer.fromJson<String?>(json['nik']),
      isSyncDirty: serializer.fromJson<bool>(json['isSyncDirty']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'nama': serializer.toJson<String>(nama),
      'alamat': serializer.toJson<String?>(alamat),
      'nik': serializer.toJson<String?>(nik),
      'isSyncDirty': serializer.toJson<bool>(isSyncDirty),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Pemohon copyWith({
    int? id,
    String? uuid,
    String? nama,
    Value<String?> alamat = const Value.absent(),
    Value<String?> nik = const Value.absent(),
    bool? isSyncDirty,
    Value<DateTime?> lastSyncedAt = const Value.absent(),
    Value<DateTime?> updatedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => Pemohon(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    nama: nama ?? this.nama,
    alamat: alamat.present ? alamat.value : this.alamat,
    nik: nik.present ? nik.value : this.nik,
    isSyncDirty: isSyncDirty ?? this.isSyncDirty,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Pemohon copyWithCompanion(PemohonsCompanion data) {
    return Pemohon(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      nama: data.nama.present ? data.nama.value : this.nama,
      alamat: data.alamat.present ? data.alamat.value : this.alamat,
      nik: data.nik.present ? data.nik.value : this.nik,
      isSyncDirty: data.isSyncDirty.present
          ? data.isSyncDirty.value
          : this.isSyncDirty,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Pemohon(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('nama: $nama, ')
          ..write('alamat: $alamat, ')
          ..write('nik: $nik, ')
          ..write('isSyncDirty: $isSyncDirty, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    nama,
    alamat,
    nik,
    isSyncDirty,
    lastSyncedAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Pemohon &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.nama == this.nama &&
          other.alamat == this.alamat &&
          other.nik == this.nik &&
          other.isSyncDirty == this.isSyncDirty &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class PemohonsCompanion extends UpdateCompanion<Pemohon> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<String> nama;
  final Value<String?> alamat;
  final Value<String?> nik;
  final Value<bool> isSyncDirty;
  final Value<DateTime?> lastSyncedAt;
  final Value<DateTime?> updatedAt;
  final Value<DateTime?> deletedAt;
  const PemohonsCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.nama = const Value.absent(),
    this.alamat = const Value.absent(),
    this.nik = const Value.absent(),
    this.isSyncDirty = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  PemohonsCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required String nama,
    this.alamat = const Value.absent(),
    this.nik = const Value.absent(),
    this.isSyncDirty = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  }) : uuid = Value(uuid),
       nama = Value(nama);
  static Insertable<Pemohon> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<String>? nama,
    Expression<String>? alamat,
    Expression<String>? nik,
    Expression<bool>? isSyncDirty,
    Expression<DateTime>? lastSyncedAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (nama != null) 'nama': nama,
      if (alamat != null) 'alamat': alamat,
      if (nik != null) 'nik': nik,
      if (isSyncDirty != null) 'is_sync_dirty': isSyncDirty,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  PemohonsCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<String>? nama,
    Value<String?>? alamat,
    Value<String?>? nik,
    Value<bool>? isSyncDirty,
    Value<DateTime?>? lastSyncedAt,
    Value<DateTime?>? updatedAt,
    Value<DateTime?>? deletedAt,
  }) {
    return PemohonsCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      nama: nama ?? this.nama,
      alamat: alamat ?? this.alamat,
      nik: nik ?? this.nik,
      isSyncDirty: isSyncDirty ?? this.isSyncDirty,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (nama.present) {
      map['nama'] = Variable<String>(nama.value);
    }
    if (alamat.present) {
      map['alamat'] = Variable<String>(alamat.value);
    }
    if (nik.present) {
      map['nik'] = Variable<String>(nik.value);
    }
    if (isSyncDirty.present) {
      map['is_sync_dirty'] = Variable<bool>(isSyncDirty.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PemohonsCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('nama: $nama, ')
          ..write('alamat: $alamat, ')
          ..write('nik: $nik, ')
          ..write('isSyncDirty: $isSyncDirty, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

class $TransaksisTable extends Transaksis
    with TableInfo<$TransaksisTable, Transaksi> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransaksisTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noAktaMeta = const VerificationMeta('noAkta');
  @override
  late final GeneratedColumn<String> noAkta = GeneratedColumn<String>(
    'no_akta',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<double> total = GeneratedColumn<double>(
    'total',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pemohonIdMeta = const VerificationMeta(
    'pemohonId',
  );
  @override
  late final GeneratedColumn<int> pemohonId = GeneratedColumn<int>(
    'pemohon_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pemohonUuidMeta = const VerificationMeta(
    'pemohonUuid',
  );
  @override
  late final GeneratedColumn<String> pemohonUuid = GeneratedColumn<String>(
    'pemohon_uuid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isSyncDirtyMeta = const VerificationMeta(
    'isSyncDirty',
  );
  @override
  late final GeneratedColumn<bool> isSyncDirty = GeneratedColumn<bool>(
    'is_sync_dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_sync_dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uuid,
    noAkta,
    total,
    pemohonId,
    pemohonUuid,
    isSyncDirty,
    lastSyncedAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transaksis';
  @override
  VerificationContext validateIntegrity(
    Insertable<Transaksi> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('no_akta')) {
      context.handle(
        _noAktaMeta,
        noAkta.isAcceptableOrUnknown(data['no_akta']!, _noAktaMeta),
      );
    } else if (isInserting) {
      context.missing(_noAktaMeta);
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    } else if (isInserting) {
      context.missing(_totalMeta);
    }
    if (data.containsKey('pemohon_id')) {
      context.handle(
        _pemohonIdMeta,
        pemohonId.isAcceptableOrUnknown(data['pemohon_id']!, _pemohonIdMeta),
      );
    }
    if (data.containsKey('pemohon_uuid')) {
      context.handle(
        _pemohonUuidMeta,
        pemohonUuid.isAcceptableOrUnknown(
          data['pemohon_uuid']!,
          _pemohonUuidMeta,
        ),
      );
    }
    if (data.containsKey('is_sync_dirty')) {
      context.handle(
        _isSyncDirtyMeta,
        isSyncDirty.isAcceptableOrUnknown(
          data['is_sync_dirty']!,
          _isSyncDirtyMeta,
        ),
      );
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Transaksi map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Transaksi(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      noAkta: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}no_akta'],
      )!,
      total: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total'],
      )!,
      pemohonId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pemohon_id'],
      ),
      pemohonUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pemohon_uuid'],
      ),
      isSyncDirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_sync_dirty'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $TransaksisTable createAlias(String alias) {
    return $TransaksisTable(attachedDatabase, alias);
  }
}

class Transaksi extends DataClass implements Insertable<Transaksi> {
  final int id;
  final String uuid;
  final String noAkta;
  final double total;
  final int? pemohonId;
  final String? pemohonUuid;
  final bool isSyncDirty;
  final DateTime? lastSyncedAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  const Transaksi({
    required this.id,
    required this.uuid,
    required this.noAkta,
    required this.total,
    this.pemohonId,
    this.pemohonUuid,
    required this.isSyncDirty,
    this.lastSyncedAt,
    this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['no_akta'] = Variable<String>(noAkta);
    map['total'] = Variable<double>(total);
    if (!nullToAbsent || pemohonId != null) {
      map['pemohon_id'] = Variable<int>(pemohonId);
    }
    if (!nullToAbsent || pemohonUuid != null) {
      map['pemohon_uuid'] = Variable<String>(pemohonUuid);
    }
    map['is_sync_dirty'] = Variable<bool>(isSyncDirty);
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  TransaksisCompanion toCompanion(bool nullToAbsent) {
    return TransaksisCompanion(
      id: Value(id),
      uuid: Value(uuid),
      noAkta: Value(noAkta),
      total: Value(total),
      pemohonId: pemohonId == null && nullToAbsent
          ? const Value.absent()
          : Value(pemohonId),
      pemohonUuid: pemohonUuid == null && nullToAbsent
          ? const Value.absent()
          : Value(pemohonUuid),
      isSyncDirty: Value(isSyncDirty),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Transaksi.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Transaksi(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      noAkta: serializer.fromJson<String>(json['noAkta']),
      total: serializer.fromJson<double>(json['total']),
      pemohonId: serializer.fromJson<int?>(json['pemohonId']),
      pemohonUuid: serializer.fromJson<String?>(json['pemohonUuid']),
      isSyncDirty: serializer.fromJson<bool>(json['isSyncDirty']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'noAkta': serializer.toJson<String>(noAkta),
      'total': serializer.toJson<double>(total),
      'pemohonId': serializer.toJson<int?>(pemohonId),
      'pemohonUuid': serializer.toJson<String?>(pemohonUuid),
      'isSyncDirty': serializer.toJson<bool>(isSyncDirty),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Transaksi copyWith({
    int? id,
    String? uuid,
    String? noAkta,
    double? total,
    Value<int?> pemohonId = const Value.absent(),
    Value<String?> pemohonUuid = const Value.absent(),
    bool? isSyncDirty,
    Value<DateTime?> lastSyncedAt = const Value.absent(),
    Value<DateTime?> updatedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => Transaksi(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    noAkta: noAkta ?? this.noAkta,
    total: total ?? this.total,
    pemohonId: pemohonId.present ? pemohonId.value : this.pemohonId,
    pemohonUuid: pemohonUuid.present ? pemohonUuid.value : this.pemohonUuid,
    isSyncDirty: isSyncDirty ?? this.isSyncDirty,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Transaksi copyWithCompanion(TransaksisCompanion data) {
    return Transaksi(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      noAkta: data.noAkta.present ? data.noAkta.value : this.noAkta,
      total: data.total.present ? data.total.value : this.total,
      pemohonId: data.pemohonId.present ? data.pemohonId.value : this.pemohonId,
      pemohonUuid: data.pemohonUuid.present
          ? data.pemohonUuid.value
          : this.pemohonUuid,
      isSyncDirty: data.isSyncDirty.present
          ? data.isSyncDirty.value
          : this.isSyncDirty,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Transaksi(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('noAkta: $noAkta, ')
          ..write('total: $total, ')
          ..write('pemohonId: $pemohonId, ')
          ..write('pemohonUuid: $pemohonUuid, ')
          ..write('isSyncDirty: $isSyncDirty, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    noAkta,
    total,
    pemohonId,
    pemohonUuid,
    isSyncDirty,
    lastSyncedAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Transaksi &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.noAkta == this.noAkta &&
          other.total == this.total &&
          other.pemohonId == this.pemohonId &&
          other.pemohonUuid == this.pemohonUuid &&
          other.isSyncDirty == this.isSyncDirty &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class TransaksisCompanion extends UpdateCompanion<Transaksi> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<String> noAkta;
  final Value<double> total;
  final Value<int?> pemohonId;
  final Value<String?> pemohonUuid;
  final Value<bool> isSyncDirty;
  final Value<DateTime?> lastSyncedAt;
  final Value<DateTime?> updatedAt;
  final Value<DateTime?> deletedAt;
  const TransaksisCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.noAkta = const Value.absent(),
    this.total = const Value.absent(),
    this.pemohonId = const Value.absent(),
    this.pemohonUuid = const Value.absent(),
    this.isSyncDirty = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  TransaksisCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required String noAkta,
    required double total,
    this.pemohonId = const Value.absent(),
    this.pemohonUuid = const Value.absent(),
    this.isSyncDirty = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  }) : uuid = Value(uuid),
       noAkta = Value(noAkta),
       total = Value(total);
  static Insertable<Transaksi> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<String>? noAkta,
    Expression<double>? total,
    Expression<int>? pemohonId,
    Expression<String>? pemohonUuid,
    Expression<bool>? isSyncDirty,
    Expression<DateTime>? lastSyncedAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (noAkta != null) 'no_akta': noAkta,
      if (total != null) 'total': total,
      if (pemohonId != null) 'pemohon_id': pemohonId,
      if (pemohonUuid != null) 'pemohon_uuid': pemohonUuid,
      if (isSyncDirty != null) 'is_sync_dirty': isSyncDirty,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  TransaksisCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<String>? noAkta,
    Value<double>? total,
    Value<int?>? pemohonId,
    Value<String?>? pemohonUuid,
    Value<bool>? isSyncDirty,
    Value<DateTime?>? lastSyncedAt,
    Value<DateTime?>? updatedAt,
    Value<DateTime?>? deletedAt,
  }) {
    return TransaksisCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      noAkta: noAkta ?? this.noAkta,
      total: total ?? this.total,
      pemohonId: pemohonId ?? this.pemohonId,
      pemohonUuid: pemohonUuid ?? this.pemohonUuid,
      isSyncDirty: isSyncDirty ?? this.isSyncDirty,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (noAkta.present) {
      map['no_akta'] = Variable<String>(noAkta.value);
    }
    if (total.present) {
      map['total'] = Variable<double>(total.value);
    }
    if (pemohonId.present) {
      map['pemohon_id'] = Variable<int>(pemohonId.value);
    }
    if (pemohonUuid.present) {
      map['pemohon_uuid'] = Variable<String>(pemohonUuid.value);
    }
    if (isSyncDirty.present) {
      map['is_sync_dirty'] = Variable<bool>(isSyncDirty.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransaksisCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('noAkta: $noAkta, ')
          ..write('total: $total, ')
          ..write('pemohonId: $pemohonId, ')
          ..write('pemohonUuid: $pemohonUuid, ')
          ..write('isSyncDirty: $isSyncDirty, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PemohonsTable pemohons = $PemohonsTable(this);
  late final $TransaksisTable transaksis = $TransaksisTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [pemohons, transaksis];
}

typedef $$PemohonsTableCreateCompanionBuilder = PemohonsCompanion Function({
  Value<int> id,
  required String uuid,
  required String nama,
  Value<String?> alamat,
  Value<String?> nik,
  Value<bool> isSyncDirty,
  Value<DateTime?> lastSyncedAt,
  Value<DateTime?> updatedAt,
  Value<DateTime?> deletedAt,
});
typedef $$PemohonsTableUpdateCompanionBuilder = PemohonsCompanion Function({
  Value<int> id,
  Value<String> uuid,
  Value<String> nama,
  Value<String?> alamat,
  Value<String?> nik,
  Value<bool> isSyncDirty,
  Value<DateTime?> lastSyncedAt,
  Value<DateTime?> updatedAt,
  Value<DateTime?> deletedAt,
});

class $$PemohonsTableFilterComposer
    extends Composer<_$AppDatabase, $PemohonsTable> {
  $$PemohonsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nama => $composableBuilder(
    column: $table.nama,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alamat => $composableBuilder(
    column: $table.alamat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nik => $composableBuilder(
    column: $table.nik,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSyncDirty => $composableBuilder(
    column: $table.isSyncDirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PemohonsTableOrderingComposer
    extends Composer<_$AppDatabase, $PemohonsTable> {
  $$PemohonsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nama => $composableBuilder(
    column: $table.nama,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alamat => $composableBuilder(
    column: $table.alamat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nik => $composableBuilder(
    column: $table.nik,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSyncDirty => $composableBuilder(
    column: $table.isSyncDirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PemohonsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PemohonsTable> {
  $$PemohonsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get nama =>
      $composableBuilder(column: $table.nama, builder: (column) => column);

  GeneratedColumn<String> get alamat =>
      $composableBuilder(column: $table.alamat, builder: (column) => column);

  GeneratedColumn<String> get nik =>
      $composableBuilder(column: $table.nik, builder: (column) => column);

  GeneratedColumn<bool> get isSyncDirty => $composableBuilder(
    column: $table.isSyncDirty,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$PemohonsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PemohonsTable,
          Pemohon,
          $$PemohonsTableFilterComposer,
          $$PemohonsTableOrderingComposer,
          $$PemohonsTableAnnotationComposer,
          $$PemohonsTableCreateCompanionBuilder,
          $$PemohonsTableUpdateCompanionBuilder,
          (Pemohon, BaseReferences<_$AppDatabase, $PemohonsTable, Pemohon>),
          Pemohon,
          PrefetchHooks Function()
        > {
  $$PemohonsTableTableManager(_$AppDatabase db, $PemohonsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PemohonsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PemohonsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PemohonsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<String> nama = const Value.absent(),
                Value<String?> alamat = const Value.absent(),
                Value<String?> nik = const Value.absent(),
                Value<bool> isSyncDirty = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => PemohonsCompanion(
                id: id,
                uuid: uuid,
                nama: nama,
                alamat: alamat,
                nik: nik,
                isSyncDirty: isSyncDirty,
                lastSyncedAt: lastSyncedAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uuid,
                required String nama,
                Value<String?> alamat = const Value.absent(),
                Value<String?> nik = const Value.absent(),
                Value<bool> isSyncDirty = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => PemohonsCompanion.insert(
                id: id,
                uuid: uuid,
                nama: nama,
                alamat: alamat,
                nik: nik,
                isSyncDirty: isSyncDirty,
                lastSyncedAt: lastSyncedAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PemohonsTable, Pemohon>(table),
                  BaseReferences<_$AppDatabase, $PemohonsTable, Pemohon>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PemohonsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PemohonsTable,
      Pemohon,
      $$PemohonsTableFilterComposer,
      $$PemohonsTableOrderingComposer,
      $$PemohonsTableAnnotationComposer,
      $$PemohonsTableCreateCompanionBuilder,
      $$PemohonsTableUpdateCompanionBuilder,
      (Pemohon, BaseReferences<_$AppDatabase, $PemohonsTable, Pemohon>),
      Pemohon,
      PrefetchHooks Function()
    >;
typedef $$TransaksisTableCreateCompanionBuilder = TransaksisCompanion Function({
  Value<int> id,
  required String uuid,
  required String noAkta,
  required double total,
  Value<int?> pemohonId,
  Value<String?> pemohonUuid,
  Value<bool> isSyncDirty,
  Value<DateTime?> lastSyncedAt,
  Value<DateTime?> updatedAt,
  Value<DateTime?> deletedAt,
});
typedef $$TransaksisTableUpdateCompanionBuilder = TransaksisCompanion Function({
  Value<int> id,
  Value<String> uuid,
  Value<String> noAkta,
  Value<double> total,
  Value<int?> pemohonId,
  Value<String?> pemohonUuid,
  Value<bool> isSyncDirty,
  Value<DateTime?> lastSyncedAt,
  Value<DateTime?> updatedAt,
  Value<DateTime?> deletedAt,
});

class $$TransaksisTableFilterComposer
    extends Composer<_$AppDatabase, $TransaksisTable> {
  $$TransaksisTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get noAkta => $composableBuilder(
    column: $table.noAkta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pemohonId => $composableBuilder(
    column: $table.pemohonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pemohonUuid => $composableBuilder(
    column: $table.pemohonUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSyncDirty => $composableBuilder(
    column: $table.isSyncDirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TransaksisTableOrderingComposer
    extends Composer<_$AppDatabase, $TransaksisTable> {
  $$TransaksisTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get noAkta => $composableBuilder(
    column: $table.noAkta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pemohonId => $composableBuilder(
    column: $table.pemohonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pemohonUuid => $composableBuilder(
    column: $table.pemohonUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSyncDirty => $composableBuilder(
    column: $table.isSyncDirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TransaksisTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransaksisTable> {
  $$TransaksisTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get noAkta =>
      $composableBuilder(column: $table.noAkta, builder: (column) => column);

  GeneratedColumn<double> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);

  GeneratedColumn<int> get pemohonId =>
      $composableBuilder(column: $table.pemohonId, builder: (column) => column);

  GeneratedColumn<String> get pemohonUuid => $composableBuilder(
    column: $table.pemohonUuid,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isSyncDirty => $composableBuilder(
    column: $table.isSyncDirty,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$TransaksisTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransaksisTable,
          Transaksi,
          $$TransaksisTableFilterComposer,
          $$TransaksisTableOrderingComposer,
          $$TransaksisTableAnnotationComposer,
          $$TransaksisTableCreateCompanionBuilder,
          $$TransaksisTableUpdateCompanionBuilder,
          (
            Transaksi,
            BaseReferences<_$AppDatabase, $TransaksisTable, Transaksi>,
          ),
          Transaksi,
          PrefetchHooks Function()
        > {
  $$TransaksisTableTableManager(_$AppDatabase db, $TransaksisTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransaksisTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransaksisTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransaksisTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<String> noAkta = const Value.absent(),
                Value<double> total = const Value.absent(),
                Value<int?> pemohonId = const Value.absent(),
                Value<String?> pemohonUuid = const Value.absent(),
                Value<bool> isSyncDirty = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => TransaksisCompanion(
                id: id,
                uuid: uuid,
                noAkta: noAkta,
                total: total,
                pemohonId: pemohonId,
                pemohonUuid: pemohonUuid,
                isSyncDirty: isSyncDirty,
                lastSyncedAt: lastSyncedAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uuid,
                required String noAkta,
                required double total,
                Value<int?> pemohonId = const Value.absent(),
                Value<String?> pemohonUuid = const Value.absent(),
                Value<bool> isSyncDirty = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => TransaksisCompanion.insert(
                id: id,
                uuid: uuid,
                noAkta: noAkta,
                total: total,
                pemohonId: pemohonId,
                pemohonUuid: pemohonUuid,
                isSyncDirty: isSyncDirty,
                lastSyncedAt: lastSyncedAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TransaksisTable, Transaksi>(table),
                  BaseReferences<_$AppDatabase, $TransaksisTable, Transaksi>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TransaksisTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransaksisTable,
      Transaksi,
      $$TransaksisTableFilterComposer,
      $$TransaksisTableOrderingComposer,
      $$TransaksisTableAnnotationComposer,
      $$TransaksisTableCreateCompanionBuilder,
      $$TransaksisTableUpdateCompanionBuilder,
      (Transaksi, BaseReferences<_$AppDatabase, $TransaksisTable, Transaksi>),
      Transaksi,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PemohonsTableTableManager get pemohons =>
      $$PemohonsTableTableManager(_db, _db.pemohons);
  $$TransaksisTableTableManager get transaksis =>
      $$TransaksisTableTableManager(_db, _db.transaksis);
}
