// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $JenisKelaminsTable extends JenisKelamins
    with TableInfo<$JenisKelaminsTable, JenisKelamin> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JenisKelaminsTable(this.attachedDatabase, [this._alias]);
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
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
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
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<int> createdBy = GeneratedColumn<int>(
    'created_by',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedByMeta = const VerificationMeta(
    'updatedBy',
  );
  @override
  late final GeneratedColumn<int> updatedBy = GeneratedColumn<int>(
    'updated_by',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
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
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
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
    createdBy,
    updatedBy,
    createdAt,
    updatedAt,
    status,
    isSyncDirty,
    lastSyncedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'jenis_kelamin';
  @override
  VerificationContext validateIntegrity(
    Insertable<JenisKelamin> instance, {
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
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    }
    if (data.containsKey('updated_by')) {
      context.handle(
        _updatedByMeta,
        updatedBy.isAcceptableOrUnknown(data['updated_by']!, _updatedByMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
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
  JenisKelamin map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JenisKelamin(
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
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_by'],
      ),
      updatedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_by'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
      isSyncDirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_sync_dirty'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $JenisKelaminsTable createAlias(String alias) {
    return $JenisKelaminsTable(attachedDatabase, alias);
  }
}

class JenisKelamin extends DataClass implements Insertable<JenisKelamin> {
  final int id;
  final String uuid;
  final String nama;
  final int? createdBy;
  final int? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int status;
  final bool isSyncDirty;
  final DateTime? lastSyncedAt;
  final DateTime? deletedAt;
  const JenisKelamin({
    required this.id,
    required this.uuid,
    required this.nama,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
    required this.status,
    required this.isSyncDirty,
    this.lastSyncedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['nama'] = Variable<String>(nama);
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<int>(createdBy);
    }
    if (!nullToAbsent || updatedBy != null) {
      map['updated_by'] = Variable<int>(updatedBy);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    map['status'] = Variable<int>(status);
    map['is_sync_dirty'] = Variable<bool>(isSyncDirty);
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  JenisKelaminsCompanion toCompanion(bool nullToAbsent) {
    return JenisKelaminsCompanion(
      id: Value(id),
      uuid: Value(uuid),
      nama: Value(nama),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      updatedBy: updatedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedBy),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      status: Value(status),
      isSyncDirty: Value(isSyncDirty),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory JenisKelamin.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JenisKelamin(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      nama: serializer.fromJson<String>(json['nama']),
      createdBy: serializer.fromJson<int?>(json['createdBy']),
      updatedBy: serializer.fromJson<int?>(json['updatedBy']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      status: serializer.fromJson<int>(json['status']),
      isSyncDirty: serializer.fromJson<bool>(json['isSyncDirty']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
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
      'createdBy': serializer.toJson<int?>(createdBy),
      'updatedBy': serializer.toJson<int?>(updatedBy),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'status': serializer.toJson<int>(status),
      'isSyncDirty': serializer.toJson<bool>(isSyncDirty),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  JenisKelamin copyWith({
    int? id,
    String? uuid,
    String? nama,
    Value<int?> createdBy = const Value.absent(),
    Value<int?> updatedBy = const Value.absent(),
    Value<DateTime?> createdAt = const Value.absent(),
    Value<DateTime?> updatedAt = const Value.absent(),
    int? status,
    bool? isSyncDirty,
    Value<DateTime?> lastSyncedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => JenisKelamin(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    nama: nama ?? this.nama,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
    updatedBy: updatedBy.present ? updatedBy.value : this.updatedBy,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    status: status ?? this.status,
    isSyncDirty: isSyncDirty ?? this.isSyncDirty,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  JenisKelamin copyWithCompanion(JenisKelaminsCompanion data) {
    return JenisKelamin(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      nama: data.nama.present ? data.nama.value : this.nama,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      updatedBy: data.updatedBy.present ? data.updatedBy.value : this.updatedBy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      status: data.status.present ? data.status.value : this.status,
      isSyncDirty: data.isSyncDirty.present
          ? data.isSyncDirty.value
          : this.isSyncDirty,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JenisKelamin(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('nama: $nama, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('status: $status, ')
          ..write('isSyncDirty: $isSyncDirty, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    nama,
    createdBy,
    updatedBy,
    createdAt,
    updatedAt,
    status,
    isSyncDirty,
    lastSyncedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JenisKelamin &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.nama == this.nama &&
          other.createdBy == this.createdBy &&
          other.updatedBy == this.updatedBy &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.status == this.status &&
          other.isSyncDirty == this.isSyncDirty &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.deletedAt == this.deletedAt);
}

class JenisKelaminsCompanion extends UpdateCompanion<JenisKelamin> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<String> nama;
  final Value<int?> createdBy;
  final Value<int?> updatedBy;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<int> status;
  final Value<bool> isSyncDirty;
  final Value<DateTime?> lastSyncedAt;
  final Value<DateTime?> deletedAt;
  const JenisKelaminsCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.nama = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.isSyncDirty = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  JenisKelaminsCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required String nama,
    this.createdBy = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.isSyncDirty = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  }) : uuid = Value(uuid),
       nama = Value(nama);
  static Insertable<JenisKelamin> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<String>? nama,
    Expression<int>? createdBy,
    Expression<int>? updatedBy,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? status,
    Expression<bool>? isSyncDirty,
    Expression<DateTime>? lastSyncedAt,
    Expression<DateTime>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (nama != null) 'nama': nama,
      if (createdBy != null) 'created_by': createdBy,
      if (updatedBy != null) 'updated_by': updatedBy,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (status != null) 'status': status,
      if (isSyncDirty != null) 'is_sync_dirty': isSyncDirty,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  JenisKelaminsCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<String>? nama,
    Value<int?>? createdBy,
    Value<int?>? updatedBy,
    Value<DateTime?>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<int>? status,
    Value<bool>? isSyncDirty,
    Value<DateTime?>? lastSyncedAt,
    Value<DateTime?>? deletedAt,
  }) {
    return JenisKelaminsCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      nama: nama ?? this.nama,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      isSyncDirty: isSyncDirty ?? this.isSyncDirty,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
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
    if (createdBy.present) {
      map['created_by'] = Variable<int>(createdBy.value);
    }
    if (updatedBy.present) {
      map['updated_by'] = Variable<int>(updatedBy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (isSyncDirty.present) {
      map['is_sync_dirty'] = Variable<bool>(isSyncDirty.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JenisKelaminsCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('nama: $nama, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('status: $status, ')
          ..write('isSyncDirty: $isSyncDirty, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

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
  static const VerificationMeta _jenisKelaminMeta = const VerificationMeta(
    'jenisKelamin',
  );
  @override
  late final GeneratedColumn<int> jenisKelamin = GeneratedColumn<int>(
    'jenis_kelamin',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES jenis_kelamin (id)',
    ),
  );
  static const VerificationMeta _noTelpMeta = const VerificationMeta('noTelp');
  @override
  late final GeneratedColumn<String> noTelp = GeneratedColumn<String>(
    'no_telp',
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
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<int> createdBy = GeneratedColumn<int>(
    'created_by',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedByMeta = const VerificationMeta(
    'updatedBy',
  );
  @override
  late final GeneratedColumn<int> updatedBy = GeneratedColumn<int>(
    'updated_by',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
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
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
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
    jenisKelamin,
    noTelp,
    nik,
    createdBy,
    updatedBy,
    createdAt,
    updatedAt,
    status,
    isSyncDirty,
    lastSyncedAt,
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
    if (data.containsKey('jenis_kelamin')) {
      context.handle(
        _jenisKelaminMeta,
        jenisKelamin.isAcceptableOrUnknown(
          data['jenis_kelamin']!,
          _jenisKelaminMeta,
        ),
      );
    }
    if (data.containsKey('no_telp')) {
      context.handle(
        _noTelpMeta,
        noTelp.isAcceptableOrUnknown(data['no_telp']!, _noTelpMeta),
      );
    }
    if (data.containsKey('nik')) {
      context.handle(
        _nikMeta,
        nik.isAcceptableOrUnknown(data['nik']!, _nikMeta),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    }
    if (data.containsKey('updated_by')) {
      context.handle(
        _updatedByMeta,
        updatedBy.isAcceptableOrUnknown(data['updated_by']!, _updatedByMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
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
      jenisKelamin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}jenis_kelamin'],
      ),
      noTelp: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}no_telp'],
      ),
      nik: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nik'],
      ),
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_by'],
      ),
      updatedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_by'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
      isSyncDirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_sync_dirty'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
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
  final int? jenisKelamin;
  final String? noTelp;
  final String? nik;
  final int? createdBy;
  final int? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int status;
  final bool isSyncDirty;
  final DateTime? lastSyncedAt;
  final DateTime? deletedAt;
  const Pemohon({
    required this.id,
    required this.uuid,
    required this.nama,
    this.alamat,
    this.jenisKelamin,
    this.noTelp,
    this.nik,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
    required this.status,
    required this.isSyncDirty,
    this.lastSyncedAt,
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
    if (!nullToAbsent || jenisKelamin != null) {
      map['jenis_kelamin'] = Variable<int>(jenisKelamin);
    }
    if (!nullToAbsent || noTelp != null) {
      map['no_telp'] = Variable<String>(noTelp);
    }
    if (!nullToAbsent || nik != null) {
      map['nik'] = Variable<String>(nik);
    }
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<int>(createdBy);
    }
    if (!nullToAbsent || updatedBy != null) {
      map['updated_by'] = Variable<int>(updatedBy);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    map['status'] = Variable<int>(status);
    map['is_sync_dirty'] = Variable<bool>(isSyncDirty);
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
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
      jenisKelamin: jenisKelamin == null && nullToAbsent
          ? const Value.absent()
          : Value(jenisKelamin),
      noTelp: noTelp == null && nullToAbsent
          ? const Value.absent()
          : Value(noTelp),
      nik: nik == null && nullToAbsent ? const Value.absent() : Value(nik),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      updatedBy: updatedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedBy),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      status: Value(status),
      isSyncDirty: Value(isSyncDirty),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
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
      jenisKelamin: serializer.fromJson<int?>(json['jenisKelamin']),
      noTelp: serializer.fromJson<String?>(json['noTelp']),
      nik: serializer.fromJson<String?>(json['nik']),
      createdBy: serializer.fromJson<int?>(json['createdBy']),
      updatedBy: serializer.fromJson<int?>(json['updatedBy']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      status: serializer.fromJson<int>(json['status']),
      isSyncDirty: serializer.fromJson<bool>(json['isSyncDirty']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
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
      'jenisKelamin': serializer.toJson<int?>(jenisKelamin),
      'noTelp': serializer.toJson<String?>(noTelp),
      'nik': serializer.toJson<String?>(nik),
      'createdBy': serializer.toJson<int?>(createdBy),
      'updatedBy': serializer.toJson<int?>(updatedBy),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'status': serializer.toJson<int>(status),
      'isSyncDirty': serializer.toJson<bool>(isSyncDirty),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Pemohon copyWith({
    int? id,
    String? uuid,
    String? nama,
    Value<String?> alamat = const Value.absent(),
    Value<int?> jenisKelamin = const Value.absent(),
    Value<String?> noTelp = const Value.absent(),
    Value<String?> nik = const Value.absent(),
    Value<int?> createdBy = const Value.absent(),
    Value<int?> updatedBy = const Value.absent(),
    Value<DateTime?> createdAt = const Value.absent(),
    Value<DateTime?> updatedAt = const Value.absent(),
    int? status,
    bool? isSyncDirty,
    Value<DateTime?> lastSyncedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => Pemohon(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    nama: nama ?? this.nama,
    alamat: alamat.present ? alamat.value : this.alamat,
    jenisKelamin: jenisKelamin.present ? jenisKelamin.value : this.jenisKelamin,
    noTelp: noTelp.present ? noTelp.value : this.noTelp,
    nik: nik.present ? nik.value : this.nik,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
    updatedBy: updatedBy.present ? updatedBy.value : this.updatedBy,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    status: status ?? this.status,
    isSyncDirty: isSyncDirty ?? this.isSyncDirty,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Pemohon copyWithCompanion(PemohonsCompanion data) {
    return Pemohon(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      nama: data.nama.present ? data.nama.value : this.nama,
      alamat: data.alamat.present ? data.alamat.value : this.alamat,
      jenisKelamin: data.jenisKelamin.present
          ? data.jenisKelamin.value
          : this.jenisKelamin,
      noTelp: data.noTelp.present ? data.noTelp.value : this.noTelp,
      nik: data.nik.present ? data.nik.value : this.nik,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      updatedBy: data.updatedBy.present ? data.updatedBy.value : this.updatedBy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      status: data.status.present ? data.status.value : this.status,
      isSyncDirty: data.isSyncDirty.present
          ? data.isSyncDirty.value
          : this.isSyncDirty,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
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
          ..write('jenisKelamin: $jenisKelamin, ')
          ..write('noTelp: $noTelp, ')
          ..write('nik: $nik, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('status: $status, ')
          ..write('isSyncDirty: $isSyncDirty, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
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
    jenisKelamin,
    noTelp,
    nik,
    createdBy,
    updatedBy,
    createdAt,
    updatedAt,
    status,
    isSyncDirty,
    lastSyncedAt,
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
          other.jenisKelamin == this.jenisKelamin &&
          other.noTelp == this.noTelp &&
          other.nik == this.nik &&
          other.createdBy == this.createdBy &&
          other.updatedBy == this.updatedBy &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.status == this.status &&
          other.isSyncDirty == this.isSyncDirty &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.deletedAt == this.deletedAt);
}

class PemohonsCompanion extends UpdateCompanion<Pemohon> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<String> nama;
  final Value<String?> alamat;
  final Value<int?> jenisKelamin;
  final Value<String?> noTelp;
  final Value<String?> nik;
  final Value<int?> createdBy;
  final Value<int?> updatedBy;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<int> status;
  final Value<bool> isSyncDirty;
  final Value<DateTime?> lastSyncedAt;
  final Value<DateTime?> deletedAt;
  const PemohonsCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.nama = const Value.absent(),
    this.alamat = const Value.absent(),
    this.jenisKelamin = const Value.absent(),
    this.noTelp = const Value.absent(),
    this.nik = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.isSyncDirty = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  PemohonsCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required String nama,
    this.alamat = const Value.absent(),
    this.jenisKelamin = const Value.absent(),
    this.noTelp = const Value.absent(),
    this.nik = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.isSyncDirty = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  }) : uuid = Value(uuid),
       nama = Value(nama);
  static Insertable<Pemohon> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<String>? nama,
    Expression<String>? alamat,
    Expression<int>? jenisKelamin,
    Expression<String>? noTelp,
    Expression<String>? nik,
    Expression<int>? createdBy,
    Expression<int>? updatedBy,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? status,
    Expression<bool>? isSyncDirty,
    Expression<DateTime>? lastSyncedAt,
    Expression<DateTime>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (nama != null) 'nama': nama,
      if (alamat != null) 'alamat': alamat,
      if (jenisKelamin != null) 'jenis_kelamin': jenisKelamin,
      if (noTelp != null) 'no_telp': noTelp,
      if (nik != null) 'nik': nik,
      if (createdBy != null) 'created_by': createdBy,
      if (updatedBy != null) 'updated_by': updatedBy,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (status != null) 'status': status,
      if (isSyncDirty != null) 'is_sync_dirty': isSyncDirty,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  PemohonsCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<String>? nama,
    Value<String?>? alamat,
    Value<int?>? jenisKelamin,
    Value<String?>? noTelp,
    Value<String?>? nik,
    Value<int?>? createdBy,
    Value<int?>? updatedBy,
    Value<DateTime?>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<int>? status,
    Value<bool>? isSyncDirty,
    Value<DateTime?>? lastSyncedAt,
    Value<DateTime?>? deletedAt,
  }) {
    return PemohonsCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      nama: nama ?? this.nama,
      alamat: alamat ?? this.alamat,
      jenisKelamin: jenisKelamin ?? this.jenisKelamin,
      noTelp: noTelp ?? this.noTelp,
      nik: nik ?? this.nik,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      isSyncDirty: isSyncDirty ?? this.isSyncDirty,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
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
    if (jenisKelamin.present) {
      map['jenis_kelamin'] = Variable<int>(jenisKelamin.value);
    }
    if (noTelp.present) {
      map['no_telp'] = Variable<String>(noTelp.value);
    }
    if (nik.present) {
      map['nik'] = Variable<String>(nik.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<int>(createdBy.value);
    }
    if (updatedBy.present) {
      map['updated_by'] = Variable<int>(updatedBy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (isSyncDirty.present) {
      map['is_sync_dirty'] = Variable<bool>(isSyncDirty.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
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
          ..write('jenisKelamin: $jenisKelamin, ')
          ..write('noTelp: $noTelp, ')
          ..write('nik: $nik, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('status: $status, ')
          ..write('isSyncDirty: $isSyncDirty, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
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

class $PekerjaanKategorisTable extends PekerjaanKategoris
    with TableInfo<$PekerjaanKategorisTable, PekerjaanKategori> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PekerjaanKategorisTable(this.attachedDatabase, [this._alias]);
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
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
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
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<int> createdBy = GeneratedColumn<int>(
    'created_by',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedByMeta = const VerificationMeta(
    'updatedBy',
  );
  @override
  late final GeneratedColumn<int> updatedBy = GeneratedColumn<int>(
    'updated_by',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
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
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
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
    createdBy,
    updatedBy,
    createdAt,
    updatedAt,
    status,
    isSyncDirty,
    lastSyncedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pekerjaan_kategori';
  @override
  VerificationContext validateIntegrity(
    Insertable<PekerjaanKategori> instance, {
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
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    }
    if (data.containsKey('updated_by')) {
      context.handle(
        _updatedByMeta,
        updatedBy.isAcceptableOrUnknown(data['updated_by']!, _updatedByMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
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
  PekerjaanKategori map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PekerjaanKategori(
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
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_by'],
      ),
      updatedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_by'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
      isSyncDirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_sync_dirty'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $PekerjaanKategorisTable createAlias(String alias) {
    return $PekerjaanKategorisTable(attachedDatabase, alias);
  }
}

class PekerjaanKategori extends DataClass
    implements Insertable<PekerjaanKategori> {
  final int id;
  final String uuid;
  final String nama;
  final int? createdBy;
  final int? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int status;
  final bool isSyncDirty;
  final DateTime? lastSyncedAt;
  final DateTime? deletedAt;
  const PekerjaanKategori({
    required this.id,
    required this.uuid,
    required this.nama,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
    required this.status,
    required this.isSyncDirty,
    this.lastSyncedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['nama'] = Variable<String>(nama);
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<int>(createdBy);
    }
    if (!nullToAbsent || updatedBy != null) {
      map['updated_by'] = Variable<int>(updatedBy);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    map['status'] = Variable<int>(status);
    map['is_sync_dirty'] = Variable<bool>(isSyncDirty);
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  PekerjaanKategorisCompanion toCompanion(bool nullToAbsent) {
    return PekerjaanKategorisCompanion(
      id: Value(id),
      uuid: Value(uuid),
      nama: Value(nama),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      updatedBy: updatedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedBy),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      status: Value(status),
      isSyncDirty: Value(isSyncDirty),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory PekerjaanKategori.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PekerjaanKategori(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      nama: serializer.fromJson<String>(json['nama']),
      createdBy: serializer.fromJson<int?>(json['createdBy']),
      updatedBy: serializer.fromJson<int?>(json['updatedBy']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      status: serializer.fromJson<int>(json['status']),
      isSyncDirty: serializer.fromJson<bool>(json['isSyncDirty']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
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
      'createdBy': serializer.toJson<int?>(createdBy),
      'updatedBy': serializer.toJson<int?>(updatedBy),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'status': serializer.toJson<int>(status),
      'isSyncDirty': serializer.toJson<bool>(isSyncDirty),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  PekerjaanKategori copyWith({
    int? id,
    String? uuid,
    String? nama,
    Value<int?> createdBy = const Value.absent(),
    Value<int?> updatedBy = const Value.absent(),
    Value<DateTime?> createdAt = const Value.absent(),
    Value<DateTime?> updatedAt = const Value.absent(),
    int? status,
    bool? isSyncDirty,
    Value<DateTime?> lastSyncedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => PekerjaanKategori(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    nama: nama ?? this.nama,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
    updatedBy: updatedBy.present ? updatedBy.value : this.updatedBy,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    status: status ?? this.status,
    isSyncDirty: isSyncDirty ?? this.isSyncDirty,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  PekerjaanKategori copyWithCompanion(PekerjaanKategorisCompanion data) {
    return PekerjaanKategori(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      nama: data.nama.present ? data.nama.value : this.nama,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      updatedBy: data.updatedBy.present ? data.updatedBy.value : this.updatedBy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      status: data.status.present ? data.status.value : this.status,
      isSyncDirty: data.isSyncDirty.present
          ? data.isSyncDirty.value
          : this.isSyncDirty,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PekerjaanKategori(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('nama: $nama, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('status: $status, ')
          ..write('isSyncDirty: $isSyncDirty, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    nama,
    createdBy,
    updatedBy,
    createdAt,
    updatedAt,
    status,
    isSyncDirty,
    lastSyncedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PekerjaanKategori &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.nama == this.nama &&
          other.createdBy == this.createdBy &&
          other.updatedBy == this.updatedBy &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.status == this.status &&
          other.isSyncDirty == this.isSyncDirty &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.deletedAt == this.deletedAt);
}

class PekerjaanKategorisCompanion extends UpdateCompanion<PekerjaanKategori> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<String> nama;
  final Value<int?> createdBy;
  final Value<int?> updatedBy;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<int> status;
  final Value<bool> isSyncDirty;
  final Value<DateTime?> lastSyncedAt;
  final Value<DateTime?> deletedAt;
  const PekerjaanKategorisCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.nama = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.isSyncDirty = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  PekerjaanKategorisCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required String nama,
    this.createdBy = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.isSyncDirty = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  }) : uuid = Value(uuid),
       nama = Value(nama);
  static Insertable<PekerjaanKategori> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<String>? nama,
    Expression<int>? createdBy,
    Expression<int>? updatedBy,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? status,
    Expression<bool>? isSyncDirty,
    Expression<DateTime>? lastSyncedAt,
    Expression<DateTime>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (nama != null) 'nama': nama,
      if (createdBy != null) 'created_by': createdBy,
      if (updatedBy != null) 'updated_by': updatedBy,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (status != null) 'status': status,
      if (isSyncDirty != null) 'is_sync_dirty': isSyncDirty,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  PekerjaanKategorisCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<String>? nama,
    Value<int?>? createdBy,
    Value<int?>? updatedBy,
    Value<DateTime?>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<int>? status,
    Value<bool>? isSyncDirty,
    Value<DateTime?>? lastSyncedAt,
    Value<DateTime?>? deletedAt,
  }) {
    return PekerjaanKategorisCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      nama: nama ?? this.nama,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      isSyncDirty: isSyncDirty ?? this.isSyncDirty,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
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
    if (createdBy.present) {
      map['created_by'] = Variable<int>(createdBy.value);
    }
    if (updatedBy.present) {
      map['updated_by'] = Variable<int>(updatedBy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (isSyncDirty.present) {
      map['is_sync_dirty'] = Variable<bool>(isSyncDirty.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PekerjaanKategorisCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('nama: $nama, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('status: $status, ')
          ..write('isSyncDirty: $isSyncDirty, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

class $PengeluaranJenisTable extends PengeluaranJenis
    with TableInfo<$PengeluaranJenisTable, PengeluaranJenisData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PengeluaranJenisTable(this.attachedDatabase, [this._alias]);
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
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
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
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<int> createdBy = GeneratedColumn<int>(
    'created_by',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedByMeta = const VerificationMeta(
    'updatedBy',
  );
  @override
  late final GeneratedColumn<int> updatedBy = GeneratedColumn<int>(
    'updated_by',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
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
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
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
    createdBy,
    updatedBy,
    createdAt,
    updatedAt,
    status,
    isSyncDirty,
    lastSyncedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pengeluaran_jenis';
  @override
  VerificationContext validateIntegrity(
    Insertable<PengeluaranJenisData> instance, {
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
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    }
    if (data.containsKey('updated_by')) {
      context.handle(
        _updatedByMeta,
        updatedBy.isAcceptableOrUnknown(data['updated_by']!, _updatedByMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
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
  PengeluaranJenisData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PengeluaranJenisData(
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
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_by'],
      ),
      updatedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_by'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
      isSyncDirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_sync_dirty'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $PengeluaranJenisTable createAlias(String alias) {
    return $PengeluaranJenisTable(attachedDatabase, alias);
  }
}

class PengeluaranJenisData extends DataClass
    implements Insertable<PengeluaranJenisData> {
  final int id;
  final String uuid;
  final String nama;
  final int? createdBy;
  final int? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int status;
  final bool isSyncDirty;
  final DateTime? lastSyncedAt;
  final DateTime? deletedAt;
  const PengeluaranJenisData({
    required this.id,
    required this.uuid,
    required this.nama,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
    required this.status,
    required this.isSyncDirty,
    this.lastSyncedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['nama'] = Variable<String>(nama);
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<int>(createdBy);
    }
    if (!nullToAbsent || updatedBy != null) {
      map['updated_by'] = Variable<int>(updatedBy);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    map['status'] = Variable<int>(status);
    map['is_sync_dirty'] = Variable<bool>(isSyncDirty);
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  PengeluaranJenisCompanion toCompanion(bool nullToAbsent) {
    return PengeluaranJenisCompanion(
      id: Value(id),
      uuid: Value(uuid),
      nama: Value(nama),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      updatedBy: updatedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedBy),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      status: Value(status),
      isSyncDirty: Value(isSyncDirty),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory PengeluaranJenisData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PengeluaranJenisData(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      nama: serializer.fromJson<String>(json['nama']),
      createdBy: serializer.fromJson<int?>(json['createdBy']),
      updatedBy: serializer.fromJson<int?>(json['updatedBy']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      status: serializer.fromJson<int>(json['status']),
      isSyncDirty: serializer.fromJson<bool>(json['isSyncDirty']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
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
      'createdBy': serializer.toJson<int?>(createdBy),
      'updatedBy': serializer.toJson<int?>(updatedBy),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'status': serializer.toJson<int>(status),
      'isSyncDirty': serializer.toJson<bool>(isSyncDirty),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  PengeluaranJenisData copyWith({
    int? id,
    String? uuid,
    String? nama,
    Value<int?> createdBy = const Value.absent(),
    Value<int?> updatedBy = const Value.absent(),
    Value<DateTime?> createdAt = const Value.absent(),
    Value<DateTime?> updatedAt = const Value.absent(),
    int? status,
    bool? isSyncDirty,
    Value<DateTime?> lastSyncedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => PengeluaranJenisData(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    nama: nama ?? this.nama,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
    updatedBy: updatedBy.present ? updatedBy.value : this.updatedBy,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    status: status ?? this.status,
    isSyncDirty: isSyncDirty ?? this.isSyncDirty,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  PengeluaranJenisData copyWithCompanion(PengeluaranJenisCompanion data) {
    return PengeluaranJenisData(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      nama: data.nama.present ? data.nama.value : this.nama,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      updatedBy: data.updatedBy.present ? data.updatedBy.value : this.updatedBy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      status: data.status.present ? data.status.value : this.status,
      isSyncDirty: data.isSyncDirty.present
          ? data.isSyncDirty.value
          : this.isSyncDirty,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PengeluaranJenisData(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('nama: $nama, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('status: $status, ')
          ..write('isSyncDirty: $isSyncDirty, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    nama,
    createdBy,
    updatedBy,
    createdAt,
    updatedAt,
    status,
    isSyncDirty,
    lastSyncedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PengeluaranJenisData &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.nama == this.nama &&
          other.createdBy == this.createdBy &&
          other.updatedBy == this.updatedBy &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.status == this.status &&
          other.isSyncDirty == this.isSyncDirty &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.deletedAt == this.deletedAt);
}

class PengeluaranJenisCompanion extends UpdateCompanion<PengeluaranJenisData> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<String> nama;
  final Value<int?> createdBy;
  final Value<int?> updatedBy;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<int> status;
  final Value<bool> isSyncDirty;
  final Value<DateTime?> lastSyncedAt;
  final Value<DateTime?> deletedAt;
  const PengeluaranJenisCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.nama = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.isSyncDirty = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  PengeluaranJenisCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required String nama,
    this.createdBy = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.isSyncDirty = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  }) : uuid = Value(uuid),
       nama = Value(nama);
  static Insertable<PengeluaranJenisData> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<String>? nama,
    Expression<int>? createdBy,
    Expression<int>? updatedBy,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? status,
    Expression<bool>? isSyncDirty,
    Expression<DateTime>? lastSyncedAt,
    Expression<DateTime>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (nama != null) 'nama': nama,
      if (createdBy != null) 'created_by': createdBy,
      if (updatedBy != null) 'updated_by': updatedBy,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (status != null) 'status': status,
      if (isSyncDirty != null) 'is_sync_dirty': isSyncDirty,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  PengeluaranJenisCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<String>? nama,
    Value<int?>? createdBy,
    Value<int?>? updatedBy,
    Value<DateTime?>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<int>? status,
    Value<bool>? isSyncDirty,
    Value<DateTime?>? lastSyncedAt,
    Value<DateTime?>? deletedAt,
  }) {
    return PengeluaranJenisCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      nama: nama ?? this.nama,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      isSyncDirty: isSyncDirty ?? this.isSyncDirty,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
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
    if (createdBy.present) {
      map['created_by'] = Variable<int>(createdBy.value);
    }
    if (updatedBy.present) {
      map['updated_by'] = Variable<int>(updatedBy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (isSyncDirty.present) {
      map['is_sync_dirty'] = Variable<bool>(isSyncDirty.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PengeluaranJenisCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('nama: $nama, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('status: $status, ')
          ..write('isSyncDirty: $isSyncDirty, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

class $PetugasLocalsTable extends PetugasLocals
    with TableInfo<$PetugasLocalsTable, PetugasLocal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PetugasLocalsTable(this.attachedDatabase, [this._alias]);
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
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
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
  static const VerificationMeta _tempatLahirMeta = const VerificationMeta(
    'tempatLahir',
  );
  @override
  late final GeneratedColumn<String> tempatLahir = GeneratedColumn<String>(
    'tempat_lahir',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tanggalLahirMeta = const VerificationMeta(
    'tanggalLahir',
  );
  @override
  late final GeneratedColumn<DateTime> tanggalLahir = GeneratedColumn<DateTime>(
    'tanggal_lahir',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _jenisKelaminMeta = const VerificationMeta(
    'jenisKelamin',
  );
  @override
  late final GeneratedColumn<int> jenisKelamin = GeneratedColumn<int>(
    'jenis_kelamin',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES jenis_kelamin (id)',
    ),
  );
  static const VerificationMeta _noTelpMeta = const VerificationMeta('noTelp');
  @override
  late final GeneratedColumn<String> noTelp = GeneratedColumn<String>(
    'no_telp',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<int> userId = GeneratedColumn<int>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<int> createdBy = GeneratedColumn<int>(
    'created_by',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedByMeta = const VerificationMeta(
    'updatedBy',
  );
  @override
  late final GeneratedColumn<int> updatedBy = GeneratedColumn<int>(
    'updated_by',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
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
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
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
    nik,
    nama,
    alamat,
    tempatLahir,
    tanggalLahir,
    jenisKelamin,
    noTelp,
    email,
    userId,
    createdBy,
    updatedBy,
    createdAt,
    updatedAt,
    status,
    isSyncDirty,
    lastSyncedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'petugas';
  @override
  VerificationContext validateIntegrity(
    Insertable<PetugasLocal> instance, {
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
    if (data.containsKey('nik')) {
      context.handle(
        _nikMeta,
        nik.isAcceptableOrUnknown(data['nik']!, _nikMeta),
      );
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
    if (data.containsKey('tempat_lahir')) {
      context.handle(
        _tempatLahirMeta,
        tempatLahir.isAcceptableOrUnknown(
          data['tempat_lahir']!,
          _tempatLahirMeta,
        ),
      );
    }
    if (data.containsKey('tanggal_lahir')) {
      context.handle(
        _tanggalLahirMeta,
        tanggalLahir.isAcceptableOrUnknown(
          data['tanggal_lahir']!,
          _tanggalLahirMeta,
        ),
      );
    }
    if (data.containsKey('jenis_kelamin')) {
      context.handle(
        _jenisKelaminMeta,
        jenisKelamin.isAcceptableOrUnknown(
          data['jenis_kelamin']!,
          _jenisKelaminMeta,
        ),
      );
    }
    if (data.containsKey('no_telp')) {
      context.handle(
        _noTelpMeta,
        noTelp.isAcceptableOrUnknown(data['no_telp']!, _noTelpMeta),
      );
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    } else if (isInserting) {
      context.missing(_emailMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    }
    if (data.containsKey('updated_by')) {
      context.handle(
        _updatedByMeta,
        updatedBy.isAcceptableOrUnknown(data['updated_by']!, _updatedByMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
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
  PetugasLocal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PetugasLocal(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      nik: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nik'],
      ),
      nama: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nama'],
      )!,
      alamat: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alamat'],
      ),
      tempatLahir: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tempat_lahir'],
      ),
      tanggalLahir: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}tanggal_lahir'],
      ),
      jenisKelamin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}jenis_kelamin'],
      ),
      noTelp: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}no_telp'],
      ),
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}user_id'],
      ),
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_by'],
      ),
      updatedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_by'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
      isSyncDirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_sync_dirty'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $PetugasLocalsTable createAlias(String alias) {
    return $PetugasLocalsTable(attachedDatabase, alias);
  }
}

class PetugasLocal extends DataClass implements Insertable<PetugasLocal> {
  final int id;
  final String uuid;
  final String? nik;
  final String nama;
  final String? alamat;
  final String? tempatLahir;
  final DateTime? tanggalLahir;
  final int? jenisKelamin;
  final String? noTelp;
  final String email;
  final int? userId;
  final int? createdBy;
  final int? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int status;
  final bool isSyncDirty;
  final DateTime? lastSyncedAt;
  final DateTime? deletedAt;
  const PetugasLocal({
    required this.id,
    required this.uuid,
    this.nik,
    required this.nama,
    this.alamat,
    this.tempatLahir,
    this.tanggalLahir,
    this.jenisKelamin,
    this.noTelp,
    required this.email,
    this.userId,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
    required this.status,
    required this.isSyncDirty,
    this.lastSyncedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    if (!nullToAbsent || nik != null) {
      map['nik'] = Variable<String>(nik);
    }
    map['nama'] = Variable<String>(nama);
    if (!nullToAbsent || alamat != null) {
      map['alamat'] = Variable<String>(alamat);
    }
    if (!nullToAbsent || tempatLahir != null) {
      map['tempat_lahir'] = Variable<String>(tempatLahir);
    }
    if (!nullToAbsent || tanggalLahir != null) {
      map['tanggal_lahir'] = Variable<DateTime>(tanggalLahir);
    }
    if (!nullToAbsent || jenisKelamin != null) {
      map['jenis_kelamin'] = Variable<int>(jenisKelamin);
    }
    if (!nullToAbsent || noTelp != null) {
      map['no_telp'] = Variable<String>(noTelp);
    }
    map['email'] = Variable<String>(email);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<int>(userId);
    }
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<int>(createdBy);
    }
    if (!nullToAbsent || updatedBy != null) {
      map['updated_by'] = Variable<int>(updatedBy);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    map['status'] = Variable<int>(status);
    map['is_sync_dirty'] = Variable<bool>(isSyncDirty);
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  PetugasLocalsCompanion toCompanion(bool nullToAbsent) {
    return PetugasLocalsCompanion(
      id: Value(id),
      uuid: Value(uuid),
      nik: nik == null && nullToAbsent ? const Value.absent() : Value(nik),
      nama: Value(nama),
      alamat: alamat == null && nullToAbsent
          ? const Value.absent()
          : Value(alamat),
      tempatLahir: tempatLahir == null && nullToAbsent
          ? const Value.absent()
          : Value(tempatLahir),
      tanggalLahir: tanggalLahir == null && nullToAbsent
          ? const Value.absent()
          : Value(tanggalLahir),
      jenisKelamin: jenisKelamin == null && nullToAbsent
          ? const Value.absent()
          : Value(jenisKelamin),
      noTelp: noTelp == null && nullToAbsent
          ? const Value.absent()
          : Value(noTelp),
      email: Value(email),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      updatedBy: updatedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedBy),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      status: Value(status),
      isSyncDirty: Value(isSyncDirty),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory PetugasLocal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PetugasLocal(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      nik: serializer.fromJson<String?>(json['nik']),
      nama: serializer.fromJson<String>(json['nama']),
      alamat: serializer.fromJson<String?>(json['alamat']),
      tempatLahir: serializer.fromJson<String?>(json['tempatLahir']),
      tanggalLahir: serializer.fromJson<DateTime?>(json['tanggalLahir']),
      jenisKelamin: serializer.fromJson<int?>(json['jenisKelamin']),
      noTelp: serializer.fromJson<String?>(json['noTelp']),
      email: serializer.fromJson<String>(json['email']),
      userId: serializer.fromJson<int?>(json['userId']),
      createdBy: serializer.fromJson<int?>(json['createdBy']),
      updatedBy: serializer.fromJson<int?>(json['updatedBy']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      status: serializer.fromJson<int>(json['status']),
      isSyncDirty: serializer.fromJson<bool>(json['isSyncDirty']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'nik': serializer.toJson<String?>(nik),
      'nama': serializer.toJson<String>(nama),
      'alamat': serializer.toJson<String?>(alamat),
      'tempatLahir': serializer.toJson<String?>(tempatLahir),
      'tanggalLahir': serializer.toJson<DateTime?>(tanggalLahir),
      'jenisKelamin': serializer.toJson<int?>(jenisKelamin),
      'noTelp': serializer.toJson<String?>(noTelp),
      'email': serializer.toJson<String>(email),
      'userId': serializer.toJson<int?>(userId),
      'createdBy': serializer.toJson<int?>(createdBy),
      'updatedBy': serializer.toJson<int?>(updatedBy),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'status': serializer.toJson<int>(status),
      'isSyncDirty': serializer.toJson<bool>(isSyncDirty),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  PetugasLocal copyWith({
    int? id,
    String? uuid,
    Value<String?> nik = const Value.absent(),
    String? nama,
    Value<String?> alamat = const Value.absent(),
    Value<String?> tempatLahir = const Value.absent(),
    Value<DateTime?> tanggalLahir = const Value.absent(),
    Value<int?> jenisKelamin = const Value.absent(),
    Value<String?> noTelp = const Value.absent(),
    String? email,
    Value<int?> userId = const Value.absent(),
    Value<int?> createdBy = const Value.absent(),
    Value<int?> updatedBy = const Value.absent(),
    Value<DateTime?> createdAt = const Value.absent(),
    Value<DateTime?> updatedAt = const Value.absent(),
    int? status,
    bool? isSyncDirty,
    Value<DateTime?> lastSyncedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => PetugasLocal(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    nik: nik.present ? nik.value : this.nik,
    nama: nama ?? this.nama,
    alamat: alamat.present ? alamat.value : this.alamat,
    tempatLahir: tempatLahir.present ? tempatLahir.value : this.tempatLahir,
    tanggalLahir: tanggalLahir.present ? tanggalLahir.value : this.tanggalLahir,
    jenisKelamin: jenisKelamin.present ? jenisKelamin.value : this.jenisKelamin,
    noTelp: noTelp.present ? noTelp.value : this.noTelp,
    email: email ?? this.email,
    userId: userId.present ? userId.value : this.userId,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
    updatedBy: updatedBy.present ? updatedBy.value : this.updatedBy,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    status: status ?? this.status,
    isSyncDirty: isSyncDirty ?? this.isSyncDirty,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  PetugasLocal copyWithCompanion(PetugasLocalsCompanion data) {
    return PetugasLocal(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      nik: data.nik.present ? data.nik.value : this.nik,
      nama: data.nama.present ? data.nama.value : this.nama,
      alamat: data.alamat.present ? data.alamat.value : this.alamat,
      tempatLahir: data.tempatLahir.present
          ? data.tempatLahir.value
          : this.tempatLahir,
      tanggalLahir: data.tanggalLahir.present
          ? data.tanggalLahir.value
          : this.tanggalLahir,
      jenisKelamin: data.jenisKelamin.present
          ? data.jenisKelamin.value
          : this.jenisKelamin,
      noTelp: data.noTelp.present ? data.noTelp.value : this.noTelp,
      email: data.email.present ? data.email.value : this.email,
      userId: data.userId.present ? data.userId.value : this.userId,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      updatedBy: data.updatedBy.present ? data.updatedBy.value : this.updatedBy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      status: data.status.present ? data.status.value : this.status,
      isSyncDirty: data.isSyncDirty.present
          ? data.isSyncDirty.value
          : this.isSyncDirty,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PetugasLocal(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('nik: $nik, ')
          ..write('nama: $nama, ')
          ..write('alamat: $alamat, ')
          ..write('tempatLahir: $tempatLahir, ')
          ..write('tanggalLahir: $tanggalLahir, ')
          ..write('jenisKelamin: $jenisKelamin, ')
          ..write('noTelp: $noTelp, ')
          ..write('email: $email, ')
          ..write('userId: $userId, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('status: $status, ')
          ..write('isSyncDirty: $isSyncDirty, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    nik,
    nama,
    alamat,
    tempatLahir,
    tanggalLahir,
    jenisKelamin,
    noTelp,
    email,
    userId,
    createdBy,
    updatedBy,
    createdAt,
    updatedAt,
    status,
    isSyncDirty,
    lastSyncedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PetugasLocal &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.nik == this.nik &&
          other.nama == this.nama &&
          other.alamat == this.alamat &&
          other.tempatLahir == this.tempatLahir &&
          other.tanggalLahir == this.tanggalLahir &&
          other.jenisKelamin == this.jenisKelamin &&
          other.noTelp == this.noTelp &&
          other.email == this.email &&
          other.userId == this.userId &&
          other.createdBy == this.createdBy &&
          other.updatedBy == this.updatedBy &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.status == this.status &&
          other.isSyncDirty == this.isSyncDirty &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.deletedAt == this.deletedAt);
}

class PetugasLocalsCompanion extends UpdateCompanion<PetugasLocal> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<String?> nik;
  final Value<String> nama;
  final Value<String?> alamat;
  final Value<String?> tempatLahir;
  final Value<DateTime?> tanggalLahir;
  final Value<int?> jenisKelamin;
  final Value<String?> noTelp;
  final Value<String> email;
  final Value<int?> userId;
  final Value<int?> createdBy;
  final Value<int?> updatedBy;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<int> status;
  final Value<bool> isSyncDirty;
  final Value<DateTime?> lastSyncedAt;
  final Value<DateTime?> deletedAt;
  const PetugasLocalsCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.nik = const Value.absent(),
    this.nama = const Value.absent(),
    this.alamat = const Value.absent(),
    this.tempatLahir = const Value.absent(),
    this.tanggalLahir = const Value.absent(),
    this.jenisKelamin = const Value.absent(),
    this.noTelp = const Value.absent(),
    this.email = const Value.absent(),
    this.userId = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.isSyncDirty = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  PetugasLocalsCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    this.nik = const Value.absent(),
    required String nama,
    this.alamat = const Value.absent(),
    this.tempatLahir = const Value.absent(),
    this.tanggalLahir = const Value.absent(),
    this.jenisKelamin = const Value.absent(),
    this.noTelp = const Value.absent(),
    required String email,
    this.userId = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.isSyncDirty = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  }) : uuid = Value(uuid),
       nama = Value(nama),
       email = Value(email);
  static Insertable<PetugasLocal> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<String>? nik,
    Expression<String>? nama,
    Expression<String>? alamat,
    Expression<String>? tempatLahir,
    Expression<DateTime>? tanggalLahir,
    Expression<int>? jenisKelamin,
    Expression<String>? noTelp,
    Expression<String>? email,
    Expression<int>? userId,
    Expression<int>? createdBy,
    Expression<int>? updatedBy,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? status,
    Expression<bool>? isSyncDirty,
    Expression<DateTime>? lastSyncedAt,
    Expression<DateTime>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (nik != null) 'nik': nik,
      if (nama != null) 'nama': nama,
      if (alamat != null) 'alamat': alamat,
      if (tempatLahir != null) 'tempat_lahir': tempatLahir,
      if (tanggalLahir != null) 'tanggal_lahir': tanggalLahir,
      if (jenisKelamin != null) 'jenis_kelamin': jenisKelamin,
      if (noTelp != null) 'no_telp': noTelp,
      if (email != null) 'email': email,
      if (userId != null) 'user_id': userId,
      if (createdBy != null) 'created_by': createdBy,
      if (updatedBy != null) 'updated_by': updatedBy,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (status != null) 'status': status,
      if (isSyncDirty != null) 'is_sync_dirty': isSyncDirty,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  PetugasLocalsCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<String?>? nik,
    Value<String>? nama,
    Value<String?>? alamat,
    Value<String?>? tempatLahir,
    Value<DateTime?>? tanggalLahir,
    Value<int?>? jenisKelamin,
    Value<String?>? noTelp,
    Value<String>? email,
    Value<int?>? userId,
    Value<int?>? createdBy,
    Value<int?>? updatedBy,
    Value<DateTime?>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<int>? status,
    Value<bool>? isSyncDirty,
    Value<DateTime?>? lastSyncedAt,
    Value<DateTime?>? deletedAt,
  }) {
    return PetugasLocalsCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      nik: nik ?? this.nik,
      nama: nama ?? this.nama,
      alamat: alamat ?? this.alamat,
      tempatLahir: tempatLahir ?? this.tempatLahir,
      tanggalLahir: tanggalLahir ?? this.tanggalLahir,
      jenisKelamin: jenisKelamin ?? this.jenisKelamin,
      noTelp: noTelp ?? this.noTelp,
      email: email ?? this.email,
      userId: userId ?? this.userId,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      isSyncDirty: isSyncDirty ?? this.isSyncDirty,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
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
    if (nik.present) {
      map['nik'] = Variable<String>(nik.value);
    }
    if (nama.present) {
      map['nama'] = Variable<String>(nama.value);
    }
    if (alamat.present) {
      map['alamat'] = Variable<String>(alamat.value);
    }
    if (tempatLahir.present) {
      map['tempat_lahir'] = Variable<String>(tempatLahir.value);
    }
    if (tanggalLahir.present) {
      map['tanggal_lahir'] = Variable<DateTime>(tanggalLahir.value);
    }
    if (jenisKelamin.present) {
      map['jenis_kelamin'] = Variable<int>(jenisKelamin.value);
    }
    if (noTelp.present) {
      map['no_telp'] = Variable<String>(noTelp.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<int>(userId.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<int>(createdBy.value);
    }
    if (updatedBy.present) {
      map['updated_by'] = Variable<int>(updatedBy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (isSyncDirty.present) {
      map['is_sync_dirty'] = Variable<bool>(isSyncDirty.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PetugasLocalsCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('nik: $nik, ')
          ..write('nama: $nama, ')
          ..write('alamat: $alamat, ')
          ..write('tempatLahir: $tempatLahir, ')
          ..write('tanggalLahir: $tanggalLahir, ')
          ..write('jenisKelamin: $jenisKelamin, ')
          ..write('noTelp: $noTelp, ')
          ..write('email: $email, ')
          ..write('userId: $userId, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('status: $status, ')
          ..write('isSyncDirty: $isSyncDirty, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

class $PekerjaanNotarisLocalsTable extends PekerjaanNotarisLocals
    with TableInfo<$PekerjaanNotarisLocalsTable, PekerjaanNotarisLocal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PekerjaanNotarisLocalsTable(this.attachedDatabase, [this._alias]);
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
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
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
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<int> createdBy = GeneratedColumn<int>(
    'created_by',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedByMeta = const VerificationMeta(
    'updatedBy',
  );
  @override
  late final GeneratedColumn<int> updatedBy = GeneratedColumn<int>(
    'updated_by',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
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
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
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
    createdBy,
    updatedBy,
    createdAt,
    updatedAt,
    status,
    isSyncDirty,
    lastSyncedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pekerjaan_notaris';
  @override
  VerificationContext validateIntegrity(
    Insertable<PekerjaanNotarisLocal> instance, {
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
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    }
    if (data.containsKey('updated_by')) {
      context.handle(
        _updatedByMeta,
        updatedBy.isAcceptableOrUnknown(data['updated_by']!, _updatedByMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
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
  PekerjaanNotarisLocal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PekerjaanNotarisLocal(
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
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_by'],
      ),
      updatedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_by'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
      isSyncDirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_sync_dirty'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $PekerjaanNotarisLocalsTable createAlias(String alias) {
    return $PekerjaanNotarisLocalsTable(attachedDatabase, alias);
  }
}

class PekerjaanNotarisLocal extends DataClass
    implements Insertable<PekerjaanNotarisLocal> {
  final int id;
  final String uuid;
  final String nama;
  final int? createdBy;
  final int? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int status;
  final bool isSyncDirty;
  final DateTime? lastSyncedAt;
  final DateTime? deletedAt;
  const PekerjaanNotarisLocal({
    required this.id,
    required this.uuid,
    required this.nama,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
    required this.status,
    required this.isSyncDirty,
    this.lastSyncedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['nama'] = Variable<String>(nama);
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<int>(createdBy);
    }
    if (!nullToAbsent || updatedBy != null) {
      map['updated_by'] = Variable<int>(updatedBy);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    map['status'] = Variable<int>(status);
    map['is_sync_dirty'] = Variable<bool>(isSyncDirty);
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  PekerjaanNotarisLocalsCompanion toCompanion(bool nullToAbsent) {
    return PekerjaanNotarisLocalsCompanion(
      id: Value(id),
      uuid: Value(uuid),
      nama: Value(nama),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      updatedBy: updatedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedBy),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      status: Value(status),
      isSyncDirty: Value(isSyncDirty),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory PekerjaanNotarisLocal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PekerjaanNotarisLocal(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      nama: serializer.fromJson<String>(json['nama']),
      createdBy: serializer.fromJson<int?>(json['createdBy']),
      updatedBy: serializer.fromJson<int?>(json['updatedBy']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      status: serializer.fromJson<int>(json['status']),
      isSyncDirty: serializer.fromJson<bool>(json['isSyncDirty']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
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
      'createdBy': serializer.toJson<int?>(createdBy),
      'updatedBy': serializer.toJson<int?>(updatedBy),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'status': serializer.toJson<int>(status),
      'isSyncDirty': serializer.toJson<bool>(isSyncDirty),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  PekerjaanNotarisLocal copyWith({
    int? id,
    String? uuid,
    String? nama,
    Value<int?> createdBy = const Value.absent(),
    Value<int?> updatedBy = const Value.absent(),
    Value<DateTime?> createdAt = const Value.absent(),
    Value<DateTime?> updatedAt = const Value.absent(),
    int? status,
    bool? isSyncDirty,
    Value<DateTime?> lastSyncedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => PekerjaanNotarisLocal(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    nama: nama ?? this.nama,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
    updatedBy: updatedBy.present ? updatedBy.value : this.updatedBy,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    status: status ?? this.status,
    isSyncDirty: isSyncDirty ?? this.isSyncDirty,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  PekerjaanNotarisLocal copyWithCompanion(
    PekerjaanNotarisLocalsCompanion data,
  ) {
    return PekerjaanNotarisLocal(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      nama: data.nama.present ? data.nama.value : this.nama,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      updatedBy: data.updatedBy.present ? data.updatedBy.value : this.updatedBy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      status: data.status.present ? data.status.value : this.status,
      isSyncDirty: data.isSyncDirty.present
          ? data.isSyncDirty.value
          : this.isSyncDirty,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PekerjaanNotarisLocal(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('nama: $nama, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('status: $status, ')
          ..write('isSyncDirty: $isSyncDirty, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    nama,
    createdBy,
    updatedBy,
    createdAt,
    updatedAt,
    status,
    isSyncDirty,
    lastSyncedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PekerjaanNotarisLocal &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.nama == this.nama &&
          other.createdBy == this.createdBy &&
          other.updatedBy == this.updatedBy &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.status == this.status &&
          other.isSyncDirty == this.isSyncDirty &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.deletedAt == this.deletedAt);
}

class PekerjaanNotarisLocalsCompanion
    extends UpdateCompanion<PekerjaanNotarisLocal> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<String> nama;
  final Value<int?> createdBy;
  final Value<int?> updatedBy;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<int> status;
  final Value<bool> isSyncDirty;
  final Value<DateTime?> lastSyncedAt;
  final Value<DateTime?> deletedAt;
  const PekerjaanNotarisLocalsCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.nama = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.isSyncDirty = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  PekerjaanNotarisLocalsCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required String nama,
    this.createdBy = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.isSyncDirty = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  }) : uuid = Value(uuid),
       nama = Value(nama);
  static Insertable<PekerjaanNotarisLocal> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<String>? nama,
    Expression<int>? createdBy,
    Expression<int>? updatedBy,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? status,
    Expression<bool>? isSyncDirty,
    Expression<DateTime>? lastSyncedAt,
    Expression<DateTime>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (nama != null) 'nama': nama,
      if (createdBy != null) 'created_by': createdBy,
      if (updatedBy != null) 'updated_by': updatedBy,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (status != null) 'status': status,
      if (isSyncDirty != null) 'is_sync_dirty': isSyncDirty,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  PekerjaanNotarisLocalsCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<String>? nama,
    Value<int?>? createdBy,
    Value<int?>? updatedBy,
    Value<DateTime?>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<int>? status,
    Value<bool>? isSyncDirty,
    Value<DateTime?>? lastSyncedAt,
    Value<DateTime?>? deletedAt,
  }) {
    return PekerjaanNotarisLocalsCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      nama: nama ?? this.nama,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      isSyncDirty: isSyncDirty ?? this.isSyncDirty,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
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
    if (createdBy.present) {
      map['created_by'] = Variable<int>(createdBy.value);
    }
    if (updatedBy.present) {
      map['updated_by'] = Variable<int>(updatedBy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (isSyncDirty.present) {
      map['is_sync_dirty'] = Variable<bool>(isSyncDirty.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PekerjaanNotarisLocalsCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('nama: $nama, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('status: $status, ')
          ..write('isSyncDirty: $isSyncDirty, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

class $PekerjaanNotarisHargaLocalsTable extends PekerjaanNotarisHargaLocals
    with
        TableInfo<
          $PekerjaanNotarisHargaLocalsTable,
          PekerjaanNotarisHargaLocal
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PekerjaanNotarisHargaLocalsTable(this.attachedDatabase, [this._alias]);
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
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _pekerjaanNotarisIdMeta =
      const VerificationMeta('pekerjaanNotarisId');
  @override
  late final GeneratedColumn<int> pekerjaanNotarisId = GeneratedColumn<int>(
    'pekerjaan_notaris_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES pekerjaan_notaris (id)',
    ),
  );
  static const VerificationMeta _hargaMeta = const VerificationMeta('harga');
  @override
  late final GeneratedColumn<String> harga = GeneratedColumn<String>(
    'harga',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kategoriPekerjaanIdMeta =
      const VerificationMeta('kategoriPekerjaanId');
  @override
  late final GeneratedColumn<int> kategoriPekerjaanId = GeneratedColumn<int>(
    'kategori_pekerjaan_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES pekerjaan_kategori (id)',
    ),
  );
  static const VerificationMeta _estimasiWaktuMeta = const VerificationMeta(
    'estimasiWaktu',
  );
  @override
  late final GeneratedColumn<String> estimasiWaktu = GeneratedColumn<String>(
    'estimasi_waktu',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<int> createdBy = GeneratedColumn<int>(
    'created_by',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedByMeta = const VerificationMeta(
    'updatedBy',
  );
  @override
  late final GeneratedColumn<int> updatedBy = GeneratedColumn<int>(
    'updated_by',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
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
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
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
    pekerjaanNotarisId,
    harga,
    kategoriPekerjaanId,
    estimasiWaktu,
    createdBy,
    updatedBy,
    createdAt,
    updatedAt,
    status,
    isSyncDirty,
    lastSyncedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pekerjaan_notaris_harga';
  @override
  VerificationContext validateIntegrity(
    Insertable<PekerjaanNotarisHargaLocal> instance, {
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
    if (data.containsKey('pekerjaan_notaris_id')) {
      context.handle(
        _pekerjaanNotarisIdMeta,
        pekerjaanNotarisId.isAcceptableOrUnknown(
          data['pekerjaan_notaris_id']!,
          _pekerjaanNotarisIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_pekerjaanNotarisIdMeta);
    }
    if (data.containsKey('harga')) {
      context.handle(
        _hargaMeta,
        harga.isAcceptableOrUnknown(data['harga']!, _hargaMeta),
      );
    } else if (isInserting) {
      context.missing(_hargaMeta);
    }
    if (data.containsKey('kategori_pekerjaan_id')) {
      context.handle(
        _kategoriPekerjaanIdMeta,
        kategoriPekerjaanId.isAcceptableOrUnknown(
          data['kategori_pekerjaan_id']!,
          _kategoriPekerjaanIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_kategoriPekerjaanIdMeta);
    }
    if (data.containsKey('estimasi_waktu')) {
      context.handle(
        _estimasiWaktuMeta,
        estimasiWaktu.isAcceptableOrUnknown(
          data['estimasi_waktu']!,
          _estimasiWaktuMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_estimasiWaktuMeta);
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    }
    if (data.containsKey('updated_by')) {
      context.handle(
        _updatedByMeta,
        updatedBy.isAcceptableOrUnknown(data['updated_by']!, _updatedByMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
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
  PekerjaanNotarisHargaLocal map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PekerjaanNotarisHargaLocal(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      pekerjaanNotarisId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pekerjaan_notaris_id'],
      )!,
      harga: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}harga'],
      )!,
      kategoriPekerjaanId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kategori_pekerjaan_id'],
      )!,
      estimasiWaktu: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}estimasi_waktu'],
      )!,
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_by'],
      ),
      updatedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_by'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
      isSyncDirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_sync_dirty'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $PekerjaanNotarisHargaLocalsTable createAlias(String alias) {
    return $PekerjaanNotarisHargaLocalsTable(attachedDatabase, alias);
  }
}

class PekerjaanNotarisHargaLocal extends DataClass
    implements Insertable<PekerjaanNotarisHargaLocal> {
  final int id;
  final String uuid;
  final int pekerjaanNotarisId;
  final String harga;
  final int kategoriPekerjaanId;
  final String estimasiWaktu;
  final int? createdBy;
  final int? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int status;
  final bool isSyncDirty;
  final DateTime? lastSyncedAt;
  final DateTime? deletedAt;
  const PekerjaanNotarisHargaLocal({
    required this.id,
    required this.uuid,
    required this.pekerjaanNotarisId,
    required this.harga,
    required this.kategoriPekerjaanId,
    required this.estimasiWaktu,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
    required this.status,
    required this.isSyncDirty,
    this.lastSyncedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['pekerjaan_notaris_id'] = Variable<int>(pekerjaanNotarisId);
    map['harga'] = Variable<String>(harga);
    map['kategori_pekerjaan_id'] = Variable<int>(kategoriPekerjaanId);
    map['estimasi_waktu'] = Variable<String>(estimasiWaktu);
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<int>(createdBy);
    }
    if (!nullToAbsent || updatedBy != null) {
      map['updated_by'] = Variable<int>(updatedBy);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    map['status'] = Variable<int>(status);
    map['is_sync_dirty'] = Variable<bool>(isSyncDirty);
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  PekerjaanNotarisHargaLocalsCompanion toCompanion(bool nullToAbsent) {
    return PekerjaanNotarisHargaLocalsCompanion(
      id: Value(id),
      uuid: Value(uuid),
      pekerjaanNotarisId: Value(pekerjaanNotarisId),
      harga: Value(harga),
      kategoriPekerjaanId: Value(kategoriPekerjaanId),
      estimasiWaktu: Value(estimasiWaktu),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      updatedBy: updatedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedBy),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      status: Value(status),
      isSyncDirty: Value(isSyncDirty),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory PekerjaanNotarisHargaLocal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PekerjaanNotarisHargaLocal(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      pekerjaanNotarisId: serializer.fromJson<int>(json['pekerjaanNotarisId']),
      harga: serializer.fromJson<String>(json['harga']),
      kategoriPekerjaanId: serializer.fromJson<int>(
        json['kategoriPekerjaanId'],
      ),
      estimasiWaktu: serializer.fromJson<String>(json['estimasiWaktu']),
      createdBy: serializer.fromJson<int?>(json['createdBy']),
      updatedBy: serializer.fromJson<int?>(json['updatedBy']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      status: serializer.fromJson<int>(json['status']),
      isSyncDirty: serializer.fromJson<bool>(json['isSyncDirty']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'pekerjaanNotarisId': serializer.toJson<int>(pekerjaanNotarisId),
      'harga': serializer.toJson<String>(harga),
      'kategoriPekerjaanId': serializer.toJson<int>(kategoriPekerjaanId),
      'estimasiWaktu': serializer.toJson<String>(estimasiWaktu),
      'createdBy': serializer.toJson<int?>(createdBy),
      'updatedBy': serializer.toJson<int?>(updatedBy),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'status': serializer.toJson<int>(status),
      'isSyncDirty': serializer.toJson<bool>(isSyncDirty),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  PekerjaanNotarisHargaLocal copyWith({
    int? id,
    String? uuid,
    int? pekerjaanNotarisId,
    String? harga,
    int? kategoriPekerjaanId,
    String? estimasiWaktu,
    Value<int?> createdBy = const Value.absent(),
    Value<int?> updatedBy = const Value.absent(),
    Value<DateTime?> createdAt = const Value.absent(),
    Value<DateTime?> updatedAt = const Value.absent(),
    int? status,
    bool? isSyncDirty,
    Value<DateTime?> lastSyncedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => PekerjaanNotarisHargaLocal(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    pekerjaanNotarisId: pekerjaanNotarisId ?? this.pekerjaanNotarisId,
    harga: harga ?? this.harga,
    kategoriPekerjaanId: kategoriPekerjaanId ?? this.kategoriPekerjaanId,
    estimasiWaktu: estimasiWaktu ?? this.estimasiWaktu,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
    updatedBy: updatedBy.present ? updatedBy.value : this.updatedBy,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    status: status ?? this.status,
    isSyncDirty: isSyncDirty ?? this.isSyncDirty,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  PekerjaanNotarisHargaLocal copyWithCompanion(
    PekerjaanNotarisHargaLocalsCompanion data,
  ) {
    return PekerjaanNotarisHargaLocal(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      pekerjaanNotarisId: data.pekerjaanNotarisId.present
          ? data.pekerjaanNotarisId.value
          : this.pekerjaanNotarisId,
      harga: data.harga.present ? data.harga.value : this.harga,
      kategoriPekerjaanId: data.kategoriPekerjaanId.present
          ? data.kategoriPekerjaanId.value
          : this.kategoriPekerjaanId,
      estimasiWaktu: data.estimasiWaktu.present
          ? data.estimasiWaktu.value
          : this.estimasiWaktu,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      updatedBy: data.updatedBy.present ? data.updatedBy.value : this.updatedBy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      status: data.status.present ? data.status.value : this.status,
      isSyncDirty: data.isSyncDirty.present
          ? data.isSyncDirty.value
          : this.isSyncDirty,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PekerjaanNotarisHargaLocal(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('pekerjaanNotarisId: $pekerjaanNotarisId, ')
          ..write('harga: $harga, ')
          ..write('kategoriPekerjaanId: $kategoriPekerjaanId, ')
          ..write('estimasiWaktu: $estimasiWaktu, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('status: $status, ')
          ..write('isSyncDirty: $isSyncDirty, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    pekerjaanNotarisId,
    harga,
    kategoriPekerjaanId,
    estimasiWaktu,
    createdBy,
    updatedBy,
    createdAt,
    updatedAt,
    status,
    isSyncDirty,
    lastSyncedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PekerjaanNotarisHargaLocal &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.pekerjaanNotarisId == this.pekerjaanNotarisId &&
          other.harga == this.harga &&
          other.kategoriPekerjaanId == this.kategoriPekerjaanId &&
          other.estimasiWaktu == this.estimasiWaktu &&
          other.createdBy == this.createdBy &&
          other.updatedBy == this.updatedBy &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.status == this.status &&
          other.isSyncDirty == this.isSyncDirty &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.deletedAt == this.deletedAt);
}

class PekerjaanNotarisHargaLocalsCompanion
    extends UpdateCompanion<PekerjaanNotarisHargaLocal> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<int> pekerjaanNotarisId;
  final Value<String> harga;
  final Value<int> kategoriPekerjaanId;
  final Value<String> estimasiWaktu;
  final Value<int?> createdBy;
  final Value<int?> updatedBy;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<int> status;
  final Value<bool> isSyncDirty;
  final Value<DateTime?> lastSyncedAt;
  final Value<DateTime?> deletedAt;
  const PekerjaanNotarisHargaLocalsCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.pekerjaanNotarisId = const Value.absent(),
    this.harga = const Value.absent(),
    this.kategoriPekerjaanId = const Value.absent(),
    this.estimasiWaktu = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.isSyncDirty = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  PekerjaanNotarisHargaLocalsCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required int pekerjaanNotarisId,
    required String harga,
    required int kategoriPekerjaanId,
    required String estimasiWaktu,
    this.createdBy = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.isSyncDirty = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  }) : uuid = Value(uuid),
       pekerjaanNotarisId = Value(pekerjaanNotarisId),
       harga = Value(harga),
       kategoriPekerjaanId = Value(kategoriPekerjaanId),
       estimasiWaktu = Value(estimasiWaktu);
  static Insertable<PekerjaanNotarisHargaLocal> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<int>? pekerjaanNotarisId,
    Expression<String>? harga,
    Expression<int>? kategoriPekerjaanId,
    Expression<String>? estimasiWaktu,
    Expression<int>? createdBy,
    Expression<int>? updatedBy,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? status,
    Expression<bool>? isSyncDirty,
    Expression<DateTime>? lastSyncedAt,
    Expression<DateTime>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (pekerjaanNotarisId != null)
        'pekerjaan_notaris_id': pekerjaanNotarisId,
      if (harga != null) 'harga': harga,
      if (kategoriPekerjaanId != null)
        'kategori_pekerjaan_id': kategoriPekerjaanId,
      if (estimasiWaktu != null) 'estimasi_waktu': estimasiWaktu,
      if (createdBy != null) 'created_by': createdBy,
      if (updatedBy != null) 'updated_by': updatedBy,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (status != null) 'status': status,
      if (isSyncDirty != null) 'is_sync_dirty': isSyncDirty,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  PekerjaanNotarisHargaLocalsCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<int>? pekerjaanNotarisId,
    Value<String>? harga,
    Value<int>? kategoriPekerjaanId,
    Value<String>? estimasiWaktu,
    Value<int?>? createdBy,
    Value<int?>? updatedBy,
    Value<DateTime?>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<int>? status,
    Value<bool>? isSyncDirty,
    Value<DateTime?>? lastSyncedAt,
    Value<DateTime?>? deletedAt,
  }) {
    return PekerjaanNotarisHargaLocalsCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      pekerjaanNotarisId: pekerjaanNotarisId ?? this.pekerjaanNotarisId,
      harga: harga ?? this.harga,
      kategoriPekerjaanId: kategoriPekerjaanId ?? this.kategoriPekerjaanId,
      estimasiWaktu: estimasiWaktu ?? this.estimasiWaktu,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      isSyncDirty: isSyncDirty ?? this.isSyncDirty,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
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
    if (pekerjaanNotarisId.present) {
      map['pekerjaan_notaris_id'] = Variable<int>(pekerjaanNotarisId.value);
    }
    if (harga.present) {
      map['harga'] = Variable<String>(harga.value);
    }
    if (kategoriPekerjaanId.present) {
      map['kategori_pekerjaan_id'] = Variable<int>(kategoriPekerjaanId.value);
    }
    if (estimasiWaktu.present) {
      map['estimasi_waktu'] = Variable<String>(estimasiWaktu.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<int>(createdBy.value);
    }
    if (updatedBy.present) {
      map['updated_by'] = Variable<int>(updatedBy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (isSyncDirty.present) {
      map['is_sync_dirty'] = Variable<bool>(isSyncDirty.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PekerjaanNotarisHargaLocalsCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('pekerjaanNotarisId: $pekerjaanNotarisId, ')
          ..write('harga: $harga, ')
          ..write('kategoriPekerjaanId: $kategoriPekerjaanId, ')
          ..write('estimasiWaktu: $estimasiWaktu, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('status: $status, ')
          ..write('isSyncDirty: $isSyncDirty, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

class $PekerjaanNotarisProsesLocalsTable extends PekerjaanNotarisProsesLocals
    with
        TableInfo<
          $PekerjaanNotarisProsesLocalsTable,
          PekerjaanNotarisProsesLocal
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PekerjaanNotarisProsesLocalsTable(this.attachedDatabase, [this._alias]);
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
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _pekerjaanNotarisIdMeta =
      const VerificationMeta('pekerjaanNotarisId');
  @override
  late final GeneratedColumn<int> pekerjaanNotarisId = GeneratedColumn<int>(
    'pekerjaan_notaris_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES pekerjaan_notaris (id)',
    ),
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
  static const VerificationMeta _detailMeta = const VerificationMeta('detail');
  @override
  late final GeneratedColumn<String> detail = GeneratedColumn<String>(
    'detail',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<int> createdBy = GeneratedColumn<int>(
    'created_by',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedByMeta = const VerificationMeta(
    'updatedBy',
  );
  @override
  late final GeneratedColumn<int> updatedBy = GeneratedColumn<int>(
    'updated_by',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
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
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
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
    pekerjaanNotarisId,
    nama,
    detail,
    createdBy,
    updatedBy,
    createdAt,
    updatedAt,
    status,
    isSyncDirty,
    lastSyncedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pekerjaan_notaris_proses';
  @override
  VerificationContext validateIntegrity(
    Insertable<PekerjaanNotarisProsesLocal> instance, {
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
    if (data.containsKey('pekerjaan_notaris_id')) {
      context.handle(
        _pekerjaanNotarisIdMeta,
        pekerjaanNotarisId.isAcceptableOrUnknown(
          data['pekerjaan_notaris_id']!,
          _pekerjaanNotarisIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_pekerjaanNotarisIdMeta);
    }
    if (data.containsKey('nama')) {
      context.handle(
        _namaMeta,
        nama.isAcceptableOrUnknown(data['nama']!, _namaMeta),
      );
    } else if (isInserting) {
      context.missing(_namaMeta);
    }
    if (data.containsKey('detail')) {
      context.handle(
        _detailMeta,
        detail.isAcceptableOrUnknown(data['detail']!, _detailMeta),
      );
    } else if (isInserting) {
      context.missing(_detailMeta);
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    }
    if (data.containsKey('updated_by')) {
      context.handle(
        _updatedByMeta,
        updatedBy.isAcceptableOrUnknown(data['updated_by']!, _updatedByMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
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
  PekerjaanNotarisProsesLocal map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PekerjaanNotarisProsesLocal(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      pekerjaanNotarisId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pekerjaan_notaris_id'],
      )!,
      nama: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nama'],
      )!,
      detail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detail'],
      )!,
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_by'],
      ),
      updatedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_by'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
      isSyncDirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_sync_dirty'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $PekerjaanNotarisProsesLocalsTable createAlias(String alias) {
    return $PekerjaanNotarisProsesLocalsTable(attachedDatabase, alias);
  }
}

class PekerjaanNotarisProsesLocal extends DataClass
    implements Insertable<PekerjaanNotarisProsesLocal> {
  final int id;
  final String uuid;
  final int pekerjaanNotarisId;
  final String nama;
  final String detail;
  final int? createdBy;
  final int? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int status;
  final bool isSyncDirty;
  final DateTime? lastSyncedAt;
  final DateTime? deletedAt;
  const PekerjaanNotarisProsesLocal({
    required this.id,
    required this.uuid,
    required this.pekerjaanNotarisId,
    required this.nama,
    required this.detail,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
    required this.status,
    required this.isSyncDirty,
    this.lastSyncedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['pekerjaan_notaris_id'] = Variable<int>(pekerjaanNotarisId);
    map['nama'] = Variable<String>(nama);
    map['detail'] = Variable<String>(detail);
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<int>(createdBy);
    }
    if (!nullToAbsent || updatedBy != null) {
      map['updated_by'] = Variable<int>(updatedBy);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    map['status'] = Variable<int>(status);
    map['is_sync_dirty'] = Variable<bool>(isSyncDirty);
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  PekerjaanNotarisProsesLocalsCompanion toCompanion(bool nullToAbsent) {
    return PekerjaanNotarisProsesLocalsCompanion(
      id: Value(id),
      uuid: Value(uuid),
      pekerjaanNotarisId: Value(pekerjaanNotarisId),
      nama: Value(nama),
      detail: Value(detail),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      updatedBy: updatedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedBy),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      status: Value(status),
      isSyncDirty: Value(isSyncDirty),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory PekerjaanNotarisProsesLocal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PekerjaanNotarisProsesLocal(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      pekerjaanNotarisId: serializer.fromJson<int>(json['pekerjaanNotarisId']),
      nama: serializer.fromJson<String>(json['nama']),
      detail: serializer.fromJson<String>(json['detail']),
      createdBy: serializer.fromJson<int?>(json['createdBy']),
      updatedBy: serializer.fromJson<int?>(json['updatedBy']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      status: serializer.fromJson<int>(json['status']),
      isSyncDirty: serializer.fromJson<bool>(json['isSyncDirty']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'pekerjaanNotarisId': serializer.toJson<int>(pekerjaanNotarisId),
      'nama': serializer.toJson<String>(nama),
      'detail': serializer.toJson<String>(detail),
      'createdBy': serializer.toJson<int?>(createdBy),
      'updatedBy': serializer.toJson<int?>(updatedBy),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'status': serializer.toJson<int>(status),
      'isSyncDirty': serializer.toJson<bool>(isSyncDirty),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  PekerjaanNotarisProsesLocal copyWith({
    int? id,
    String? uuid,
    int? pekerjaanNotarisId,
    String? nama,
    String? detail,
    Value<int?> createdBy = const Value.absent(),
    Value<int?> updatedBy = const Value.absent(),
    Value<DateTime?> createdAt = const Value.absent(),
    Value<DateTime?> updatedAt = const Value.absent(),
    int? status,
    bool? isSyncDirty,
    Value<DateTime?> lastSyncedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => PekerjaanNotarisProsesLocal(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    pekerjaanNotarisId: pekerjaanNotarisId ?? this.pekerjaanNotarisId,
    nama: nama ?? this.nama,
    detail: detail ?? this.detail,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
    updatedBy: updatedBy.present ? updatedBy.value : this.updatedBy,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    status: status ?? this.status,
    isSyncDirty: isSyncDirty ?? this.isSyncDirty,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  PekerjaanNotarisProsesLocal copyWithCompanion(
    PekerjaanNotarisProsesLocalsCompanion data,
  ) {
    return PekerjaanNotarisProsesLocal(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      pekerjaanNotarisId: data.pekerjaanNotarisId.present
          ? data.pekerjaanNotarisId.value
          : this.pekerjaanNotarisId,
      nama: data.nama.present ? data.nama.value : this.nama,
      detail: data.detail.present ? data.detail.value : this.detail,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      updatedBy: data.updatedBy.present ? data.updatedBy.value : this.updatedBy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      status: data.status.present ? data.status.value : this.status,
      isSyncDirty: data.isSyncDirty.present
          ? data.isSyncDirty.value
          : this.isSyncDirty,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PekerjaanNotarisProsesLocal(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('pekerjaanNotarisId: $pekerjaanNotarisId, ')
          ..write('nama: $nama, ')
          ..write('detail: $detail, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('status: $status, ')
          ..write('isSyncDirty: $isSyncDirty, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    pekerjaanNotarisId,
    nama,
    detail,
    createdBy,
    updatedBy,
    createdAt,
    updatedAt,
    status,
    isSyncDirty,
    lastSyncedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PekerjaanNotarisProsesLocal &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.pekerjaanNotarisId == this.pekerjaanNotarisId &&
          other.nama == this.nama &&
          other.detail == this.detail &&
          other.createdBy == this.createdBy &&
          other.updatedBy == this.updatedBy &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.status == this.status &&
          other.isSyncDirty == this.isSyncDirty &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.deletedAt == this.deletedAt);
}

class PekerjaanNotarisProsesLocalsCompanion
    extends UpdateCompanion<PekerjaanNotarisProsesLocal> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<int> pekerjaanNotarisId;
  final Value<String> nama;
  final Value<String> detail;
  final Value<int?> createdBy;
  final Value<int?> updatedBy;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<int> status;
  final Value<bool> isSyncDirty;
  final Value<DateTime?> lastSyncedAt;
  final Value<DateTime?> deletedAt;
  const PekerjaanNotarisProsesLocalsCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.pekerjaanNotarisId = const Value.absent(),
    this.nama = const Value.absent(),
    this.detail = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.isSyncDirty = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  PekerjaanNotarisProsesLocalsCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required int pekerjaanNotarisId,
    required String nama,
    required String detail,
    this.createdBy = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.isSyncDirty = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  }) : uuid = Value(uuid),
       pekerjaanNotarisId = Value(pekerjaanNotarisId),
       nama = Value(nama),
       detail = Value(detail);
  static Insertable<PekerjaanNotarisProsesLocal> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<int>? pekerjaanNotarisId,
    Expression<String>? nama,
    Expression<String>? detail,
    Expression<int>? createdBy,
    Expression<int>? updatedBy,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? status,
    Expression<bool>? isSyncDirty,
    Expression<DateTime>? lastSyncedAt,
    Expression<DateTime>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (pekerjaanNotarisId != null)
        'pekerjaan_notaris_id': pekerjaanNotarisId,
      if (nama != null) 'nama': nama,
      if (detail != null) 'detail': detail,
      if (createdBy != null) 'created_by': createdBy,
      if (updatedBy != null) 'updated_by': updatedBy,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (status != null) 'status': status,
      if (isSyncDirty != null) 'is_sync_dirty': isSyncDirty,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  PekerjaanNotarisProsesLocalsCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<int>? pekerjaanNotarisId,
    Value<String>? nama,
    Value<String>? detail,
    Value<int?>? createdBy,
    Value<int?>? updatedBy,
    Value<DateTime?>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<int>? status,
    Value<bool>? isSyncDirty,
    Value<DateTime?>? lastSyncedAt,
    Value<DateTime?>? deletedAt,
  }) {
    return PekerjaanNotarisProsesLocalsCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      pekerjaanNotarisId: pekerjaanNotarisId ?? this.pekerjaanNotarisId,
      nama: nama ?? this.nama,
      detail: detail ?? this.detail,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      isSyncDirty: isSyncDirty ?? this.isSyncDirty,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
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
    if (pekerjaanNotarisId.present) {
      map['pekerjaan_notaris_id'] = Variable<int>(pekerjaanNotarisId.value);
    }
    if (nama.present) {
      map['nama'] = Variable<String>(nama.value);
    }
    if (detail.present) {
      map['detail'] = Variable<String>(detail.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<int>(createdBy.value);
    }
    if (updatedBy.present) {
      map['updated_by'] = Variable<int>(updatedBy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (isSyncDirty.present) {
      map['is_sync_dirty'] = Variable<bool>(isSyncDirty.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PekerjaanNotarisProsesLocalsCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('pekerjaanNotarisId: $pekerjaanNotarisId, ')
          ..write('nama: $nama, ')
          ..write('detail: $detail, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('status: $status, ')
          ..write('isSyncDirty: $isSyncDirty, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

class $PekerjaanNotarisAtributLocalsTable extends PekerjaanNotarisAtributLocals
    with
        TableInfo<
          $PekerjaanNotarisAtributLocalsTable,
          PekerjaanNotarisAtributLocal
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PekerjaanNotarisAtributLocalsTable(this.attachedDatabase, [this._alias]);
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
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _pekerjaanNotarisIdMeta =
      const VerificationMeta('pekerjaanNotarisId');
  @override
  late final GeneratedColumn<int> pekerjaanNotarisId = GeneratedColumn<int>(
    'pekerjaan_notaris_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES pekerjaan_notaris (id)',
    ),
  );
  static const VerificationMeta _prosesPekerjaanNotarisIdMeta =
      const VerificationMeta('prosesPekerjaanNotarisId');
  @override
  late final GeneratedColumn<int> prosesPekerjaanNotarisId =
      GeneratedColumn<int>(
        'proses_pekerjaan_notaris_id',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES pekerjaan_notaris_proses (id)',
        ),
      );
  static const VerificationMeta _atributMeta = const VerificationMeta(
    'atribut',
  );
  @override
  late final GeneratedColumn<String> atribut = GeneratedColumn<String>(
    'atribut',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<int> createdBy = GeneratedColumn<int>(
    'created_by',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedByMeta = const VerificationMeta(
    'updatedBy',
  );
  @override
  late final GeneratedColumn<int> updatedBy = GeneratedColumn<int>(
    'updated_by',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
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
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
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
    pekerjaanNotarisId,
    prosesPekerjaanNotarisId,
    atribut,
    createdBy,
    updatedBy,
    createdAt,
    updatedAt,
    status,
    isSyncDirty,
    lastSyncedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pekerjaan_notaris_atributs';
  @override
  VerificationContext validateIntegrity(
    Insertable<PekerjaanNotarisAtributLocal> instance, {
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
    if (data.containsKey('pekerjaan_notaris_id')) {
      context.handle(
        _pekerjaanNotarisIdMeta,
        pekerjaanNotarisId.isAcceptableOrUnknown(
          data['pekerjaan_notaris_id']!,
          _pekerjaanNotarisIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_pekerjaanNotarisIdMeta);
    }
    if (data.containsKey('proses_pekerjaan_notaris_id')) {
      context.handle(
        _prosesPekerjaanNotarisIdMeta,
        prosesPekerjaanNotarisId.isAcceptableOrUnknown(
          data['proses_pekerjaan_notaris_id']!,
          _prosesPekerjaanNotarisIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_prosesPekerjaanNotarisIdMeta);
    }
    if (data.containsKey('atribut')) {
      context.handle(
        _atributMeta,
        atribut.isAcceptableOrUnknown(data['atribut']!, _atributMeta),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    }
    if (data.containsKey('updated_by')) {
      context.handle(
        _updatedByMeta,
        updatedBy.isAcceptableOrUnknown(data['updated_by']!, _updatedByMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
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
  PekerjaanNotarisAtributLocal map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PekerjaanNotarisAtributLocal(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      pekerjaanNotarisId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pekerjaan_notaris_id'],
      )!,
      prosesPekerjaanNotarisId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}proses_pekerjaan_notaris_id'],
      )!,
      atribut: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}atribut'],
      ),
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_by'],
      ),
      updatedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_by'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
      isSyncDirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_sync_dirty'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $PekerjaanNotarisAtributLocalsTable createAlias(String alias) {
    return $PekerjaanNotarisAtributLocalsTable(attachedDatabase, alias);
  }
}

class PekerjaanNotarisAtributLocal extends DataClass
    implements Insertable<PekerjaanNotarisAtributLocal> {
  final int id;
  final String uuid;
  final int pekerjaanNotarisId;
  final int prosesPekerjaanNotarisId;
  final String? atribut;
  final int? createdBy;
  final int? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int status;
  final bool isSyncDirty;
  final DateTime? lastSyncedAt;
  final DateTime? deletedAt;
  const PekerjaanNotarisAtributLocal({
    required this.id,
    required this.uuid,
    required this.pekerjaanNotarisId,
    required this.prosesPekerjaanNotarisId,
    this.atribut,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
    required this.status,
    required this.isSyncDirty,
    this.lastSyncedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['pekerjaan_notaris_id'] = Variable<int>(pekerjaanNotarisId);
    map['proses_pekerjaan_notaris_id'] = Variable<int>(
      prosesPekerjaanNotarisId,
    );
    if (!nullToAbsent || atribut != null) {
      map['atribut'] = Variable<String>(atribut);
    }
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<int>(createdBy);
    }
    if (!nullToAbsent || updatedBy != null) {
      map['updated_by'] = Variable<int>(updatedBy);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    map['status'] = Variable<int>(status);
    map['is_sync_dirty'] = Variable<bool>(isSyncDirty);
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  PekerjaanNotarisAtributLocalsCompanion toCompanion(bool nullToAbsent) {
    return PekerjaanNotarisAtributLocalsCompanion(
      id: Value(id),
      uuid: Value(uuid),
      pekerjaanNotarisId: Value(pekerjaanNotarisId),
      prosesPekerjaanNotarisId: Value(prosesPekerjaanNotarisId),
      atribut: atribut == null && nullToAbsent
          ? const Value.absent()
          : Value(atribut),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      updatedBy: updatedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedBy),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      status: Value(status),
      isSyncDirty: Value(isSyncDirty),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory PekerjaanNotarisAtributLocal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PekerjaanNotarisAtributLocal(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      pekerjaanNotarisId: serializer.fromJson<int>(json['pekerjaanNotarisId']),
      prosesPekerjaanNotarisId: serializer.fromJson<int>(
        json['prosesPekerjaanNotarisId'],
      ),
      atribut: serializer.fromJson<String?>(json['atribut']),
      createdBy: serializer.fromJson<int?>(json['createdBy']),
      updatedBy: serializer.fromJson<int?>(json['updatedBy']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      status: serializer.fromJson<int>(json['status']),
      isSyncDirty: serializer.fromJson<bool>(json['isSyncDirty']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'pekerjaanNotarisId': serializer.toJson<int>(pekerjaanNotarisId),
      'prosesPekerjaanNotarisId': serializer.toJson<int>(
        prosesPekerjaanNotarisId,
      ),
      'atribut': serializer.toJson<String?>(atribut),
      'createdBy': serializer.toJson<int?>(createdBy),
      'updatedBy': serializer.toJson<int?>(updatedBy),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'status': serializer.toJson<int>(status),
      'isSyncDirty': serializer.toJson<bool>(isSyncDirty),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  PekerjaanNotarisAtributLocal copyWith({
    int? id,
    String? uuid,
    int? pekerjaanNotarisId,
    int? prosesPekerjaanNotarisId,
    Value<String?> atribut = const Value.absent(),
    Value<int?> createdBy = const Value.absent(),
    Value<int?> updatedBy = const Value.absent(),
    Value<DateTime?> createdAt = const Value.absent(),
    Value<DateTime?> updatedAt = const Value.absent(),
    int? status,
    bool? isSyncDirty,
    Value<DateTime?> lastSyncedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => PekerjaanNotarisAtributLocal(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    pekerjaanNotarisId: pekerjaanNotarisId ?? this.pekerjaanNotarisId,
    prosesPekerjaanNotarisId:
        prosesPekerjaanNotarisId ?? this.prosesPekerjaanNotarisId,
    atribut: atribut.present ? atribut.value : this.atribut,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
    updatedBy: updatedBy.present ? updatedBy.value : this.updatedBy,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    status: status ?? this.status,
    isSyncDirty: isSyncDirty ?? this.isSyncDirty,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  PekerjaanNotarisAtributLocal copyWithCompanion(
    PekerjaanNotarisAtributLocalsCompanion data,
  ) {
    return PekerjaanNotarisAtributLocal(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      pekerjaanNotarisId: data.pekerjaanNotarisId.present
          ? data.pekerjaanNotarisId.value
          : this.pekerjaanNotarisId,
      prosesPekerjaanNotarisId: data.prosesPekerjaanNotarisId.present
          ? data.prosesPekerjaanNotarisId.value
          : this.prosesPekerjaanNotarisId,
      atribut: data.atribut.present ? data.atribut.value : this.atribut,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      updatedBy: data.updatedBy.present ? data.updatedBy.value : this.updatedBy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      status: data.status.present ? data.status.value : this.status,
      isSyncDirty: data.isSyncDirty.present
          ? data.isSyncDirty.value
          : this.isSyncDirty,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PekerjaanNotarisAtributLocal(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('pekerjaanNotarisId: $pekerjaanNotarisId, ')
          ..write('prosesPekerjaanNotarisId: $prosesPekerjaanNotarisId, ')
          ..write('atribut: $atribut, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('status: $status, ')
          ..write('isSyncDirty: $isSyncDirty, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    pekerjaanNotarisId,
    prosesPekerjaanNotarisId,
    atribut,
    createdBy,
    updatedBy,
    createdAt,
    updatedAt,
    status,
    isSyncDirty,
    lastSyncedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PekerjaanNotarisAtributLocal &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.pekerjaanNotarisId == this.pekerjaanNotarisId &&
          other.prosesPekerjaanNotarisId == this.prosesPekerjaanNotarisId &&
          other.atribut == this.atribut &&
          other.createdBy == this.createdBy &&
          other.updatedBy == this.updatedBy &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.status == this.status &&
          other.isSyncDirty == this.isSyncDirty &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.deletedAt == this.deletedAt);
}

class PekerjaanNotarisAtributLocalsCompanion
    extends UpdateCompanion<PekerjaanNotarisAtributLocal> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<int> pekerjaanNotarisId;
  final Value<int> prosesPekerjaanNotarisId;
  final Value<String?> atribut;
  final Value<int?> createdBy;
  final Value<int?> updatedBy;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<int> status;
  final Value<bool> isSyncDirty;
  final Value<DateTime?> lastSyncedAt;
  final Value<DateTime?> deletedAt;
  const PekerjaanNotarisAtributLocalsCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.pekerjaanNotarisId = const Value.absent(),
    this.prosesPekerjaanNotarisId = const Value.absent(),
    this.atribut = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.isSyncDirty = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  PekerjaanNotarisAtributLocalsCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required int pekerjaanNotarisId,
    required int prosesPekerjaanNotarisId,
    this.atribut = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.isSyncDirty = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  }) : uuid = Value(uuid),
       pekerjaanNotarisId = Value(pekerjaanNotarisId),
       prosesPekerjaanNotarisId = Value(prosesPekerjaanNotarisId);
  static Insertable<PekerjaanNotarisAtributLocal> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<int>? pekerjaanNotarisId,
    Expression<int>? prosesPekerjaanNotarisId,
    Expression<String>? atribut,
    Expression<int>? createdBy,
    Expression<int>? updatedBy,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? status,
    Expression<bool>? isSyncDirty,
    Expression<DateTime>? lastSyncedAt,
    Expression<DateTime>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (pekerjaanNotarisId != null)
        'pekerjaan_notaris_id': pekerjaanNotarisId,
      if (prosesPekerjaanNotarisId != null)
        'proses_pekerjaan_notaris_id': prosesPekerjaanNotarisId,
      if (atribut != null) 'atribut': atribut,
      if (createdBy != null) 'created_by': createdBy,
      if (updatedBy != null) 'updated_by': updatedBy,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (status != null) 'status': status,
      if (isSyncDirty != null) 'is_sync_dirty': isSyncDirty,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  PekerjaanNotarisAtributLocalsCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<int>? pekerjaanNotarisId,
    Value<int>? prosesPekerjaanNotarisId,
    Value<String?>? atribut,
    Value<int?>? createdBy,
    Value<int?>? updatedBy,
    Value<DateTime?>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<int>? status,
    Value<bool>? isSyncDirty,
    Value<DateTime?>? lastSyncedAt,
    Value<DateTime?>? deletedAt,
  }) {
    return PekerjaanNotarisAtributLocalsCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      pekerjaanNotarisId: pekerjaanNotarisId ?? this.pekerjaanNotarisId,
      prosesPekerjaanNotarisId:
          prosesPekerjaanNotarisId ?? this.prosesPekerjaanNotarisId,
      atribut: atribut ?? this.atribut,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      isSyncDirty: isSyncDirty ?? this.isSyncDirty,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
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
    if (pekerjaanNotarisId.present) {
      map['pekerjaan_notaris_id'] = Variable<int>(pekerjaanNotarisId.value);
    }
    if (prosesPekerjaanNotarisId.present) {
      map['proses_pekerjaan_notaris_id'] = Variable<int>(
        prosesPekerjaanNotarisId.value,
      );
    }
    if (atribut.present) {
      map['atribut'] = Variable<String>(atribut.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<int>(createdBy.value);
    }
    if (updatedBy.present) {
      map['updated_by'] = Variable<int>(updatedBy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (isSyncDirty.present) {
      map['is_sync_dirty'] = Variable<bool>(isSyncDirty.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PekerjaanNotarisAtributLocalsCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('pekerjaanNotarisId: $pekerjaanNotarisId, ')
          ..write('prosesPekerjaanNotarisId: $prosesPekerjaanNotarisId, ')
          ..write('atribut: $atribut, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('status: $status, ')
          ..write('isSyncDirty: $isSyncDirty, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

class $PekerjaanPpatLocalsTable extends PekerjaanPpatLocals
    with TableInfo<$PekerjaanPpatLocalsTable, PekerjaanPpatLocal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PekerjaanPpatLocalsTable(this.attachedDatabase, [this._alias]);
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
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
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
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<int> createdBy = GeneratedColumn<int>(
    'created_by',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedByMeta = const VerificationMeta(
    'updatedBy',
  );
  @override
  late final GeneratedColumn<int> updatedBy = GeneratedColumn<int>(
    'updated_by',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
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
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
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
    createdBy,
    updatedBy,
    createdAt,
    updatedAt,
    status,
    isSyncDirty,
    lastSyncedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pekerjaan_ppat';
  @override
  VerificationContext validateIntegrity(
    Insertable<PekerjaanPpatLocal> instance, {
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
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    }
    if (data.containsKey('updated_by')) {
      context.handle(
        _updatedByMeta,
        updatedBy.isAcceptableOrUnknown(data['updated_by']!, _updatedByMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
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
  PekerjaanPpatLocal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PekerjaanPpatLocal(
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
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_by'],
      ),
      updatedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_by'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
      isSyncDirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_sync_dirty'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $PekerjaanPpatLocalsTable createAlias(String alias) {
    return $PekerjaanPpatLocalsTable(attachedDatabase, alias);
  }
}

class PekerjaanPpatLocal extends DataClass
    implements Insertable<PekerjaanPpatLocal> {
  final int id;
  final String uuid;
  final String nama;
  final int? createdBy;
  final int? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int status;
  final bool isSyncDirty;
  final DateTime? lastSyncedAt;
  final DateTime? deletedAt;
  const PekerjaanPpatLocal({
    required this.id,
    required this.uuid,
    required this.nama,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
    required this.status,
    required this.isSyncDirty,
    this.lastSyncedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['nama'] = Variable<String>(nama);
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<int>(createdBy);
    }
    if (!nullToAbsent || updatedBy != null) {
      map['updated_by'] = Variable<int>(updatedBy);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    map['status'] = Variable<int>(status);
    map['is_sync_dirty'] = Variable<bool>(isSyncDirty);
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  PekerjaanPpatLocalsCompanion toCompanion(bool nullToAbsent) {
    return PekerjaanPpatLocalsCompanion(
      id: Value(id),
      uuid: Value(uuid),
      nama: Value(nama),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      updatedBy: updatedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedBy),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      status: Value(status),
      isSyncDirty: Value(isSyncDirty),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory PekerjaanPpatLocal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PekerjaanPpatLocal(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      nama: serializer.fromJson<String>(json['nama']),
      createdBy: serializer.fromJson<int?>(json['createdBy']),
      updatedBy: serializer.fromJson<int?>(json['updatedBy']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      status: serializer.fromJson<int>(json['status']),
      isSyncDirty: serializer.fromJson<bool>(json['isSyncDirty']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
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
      'createdBy': serializer.toJson<int?>(createdBy),
      'updatedBy': serializer.toJson<int?>(updatedBy),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'status': serializer.toJson<int>(status),
      'isSyncDirty': serializer.toJson<bool>(isSyncDirty),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  PekerjaanPpatLocal copyWith({
    int? id,
    String? uuid,
    String? nama,
    Value<int?> createdBy = const Value.absent(),
    Value<int?> updatedBy = const Value.absent(),
    Value<DateTime?> createdAt = const Value.absent(),
    Value<DateTime?> updatedAt = const Value.absent(),
    int? status,
    bool? isSyncDirty,
    Value<DateTime?> lastSyncedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => PekerjaanPpatLocal(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    nama: nama ?? this.nama,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
    updatedBy: updatedBy.present ? updatedBy.value : this.updatedBy,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    status: status ?? this.status,
    isSyncDirty: isSyncDirty ?? this.isSyncDirty,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  PekerjaanPpatLocal copyWithCompanion(PekerjaanPpatLocalsCompanion data) {
    return PekerjaanPpatLocal(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      nama: data.nama.present ? data.nama.value : this.nama,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      updatedBy: data.updatedBy.present ? data.updatedBy.value : this.updatedBy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      status: data.status.present ? data.status.value : this.status,
      isSyncDirty: data.isSyncDirty.present
          ? data.isSyncDirty.value
          : this.isSyncDirty,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PekerjaanPpatLocal(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('nama: $nama, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('status: $status, ')
          ..write('isSyncDirty: $isSyncDirty, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    nama,
    createdBy,
    updatedBy,
    createdAt,
    updatedAt,
    status,
    isSyncDirty,
    lastSyncedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PekerjaanPpatLocal &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.nama == this.nama &&
          other.createdBy == this.createdBy &&
          other.updatedBy == this.updatedBy &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.status == this.status &&
          other.isSyncDirty == this.isSyncDirty &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.deletedAt == this.deletedAt);
}

class PekerjaanPpatLocalsCompanion extends UpdateCompanion<PekerjaanPpatLocal> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<String> nama;
  final Value<int?> createdBy;
  final Value<int?> updatedBy;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<int> status;
  final Value<bool> isSyncDirty;
  final Value<DateTime?> lastSyncedAt;
  final Value<DateTime?> deletedAt;
  const PekerjaanPpatLocalsCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.nama = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.isSyncDirty = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  PekerjaanPpatLocalsCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required String nama,
    this.createdBy = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.isSyncDirty = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  }) : uuid = Value(uuid),
       nama = Value(nama);
  static Insertable<PekerjaanPpatLocal> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<String>? nama,
    Expression<int>? createdBy,
    Expression<int>? updatedBy,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? status,
    Expression<bool>? isSyncDirty,
    Expression<DateTime>? lastSyncedAt,
    Expression<DateTime>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (nama != null) 'nama': nama,
      if (createdBy != null) 'created_by': createdBy,
      if (updatedBy != null) 'updated_by': updatedBy,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (status != null) 'status': status,
      if (isSyncDirty != null) 'is_sync_dirty': isSyncDirty,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  PekerjaanPpatLocalsCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<String>? nama,
    Value<int?>? createdBy,
    Value<int?>? updatedBy,
    Value<DateTime?>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<int>? status,
    Value<bool>? isSyncDirty,
    Value<DateTime?>? lastSyncedAt,
    Value<DateTime?>? deletedAt,
  }) {
    return PekerjaanPpatLocalsCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      nama: nama ?? this.nama,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      isSyncDirty: isSyncDirty ?? this.isSyncDirty,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
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
    if (createdBy.present) {
      map['created_by'] = Variable<int>(createdBy.value);
    }
    if (updatedBy.present) {
      map['updated_by'] = Variable<int>(updatedBy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (isSyncDirty.present) {
      map['is_sync_dirty'] = Variable<bool>(isSyncDirty.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PekerjaanPpatLocalsCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('nama: $nama, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('status: $status, ')
          ..write('isSyncDirty: $isSyncDirty, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

class $PekerjaanPpatHargaLocalsTable extends PekerjaanPpatHargaLocals
    with TableInfo<$PekerjaanPpatHargaLocalsTable, PekerjaanPpatHargaLocal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PekerjaanPpatHargaLocalsTable(this.attachedDatabase, [this._alias]);
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
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _pekerjaanPpatIdMeta = const VerificationMeta(
    'pekerjaanPpatId',
  );
  @override
  late final GeneratedColumn<int> pekerjaanPpatId = GeneratedColumn<int>(
    'pekerjaan_ppat_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES pekerjaan_ppat (id)',
    ),
  );
  static const VerificationMeta _hargaMeta = const VerificationMeta('harga');
  @override
  late final GeneratedColumn<String> harga = GeneratedColumn<String>(
    'harga',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kategoriPekerjaanIdMeta =
      const VerificationMeta('kategoriPekerjaanId');
  @override
  late final GeneratedColumn<int> kategoriPekerjaanId = GeneratedColumn<int>(
    'kategori_pekerjaan_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES pekerjaan_kategori (id)',
    ),
  );
  static const VerificationMeta _estimasiWaktuMeta = const VerificationMeta(
    'estimasiWaktu',
  );
  @override
  late final GeneratedColumn<String> estimasiWaktu = GeneratedColumn<String>(
    'estimasi_waktu',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<int> createdBy = GeneratedColumn<int>(
    'created_by',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedByMeta = const VerificationMeta(
    'updatedBy',
  );
  @override
  late final GeneratedColumn<int> updatedBy = GeneratedColumn<int>(
    'updated_by',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
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
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
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
    pekerjaanPpatId,
    harga,
    kategoriPekerjaanId,
    estimasiWaktu,
    createdBy,
    updatedBy,
    createdAt,
    updatedAt,
    status,
    isSyncDirty,
    lastSyncedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pekerjaan_ppat_harga';
  @override
  VerificationContext validateIntegrity(
    Insertable<PekerjaanPpatHargaLocal> instance, {
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
    if (data.containsKey('pekerjaan_ppat_id')) {
      context.handle(
        _pekerjaanPpatIdMeta,
        pekerjaanPpatId.isAcceptableOrUnknown(
          data['pekerjaan_ppat_id']!,
          _pekerjaanPpatIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_pekerjaanPpatIdMeta);
    }
    if (data.containsKey('harga')) {
      context.handle(
        _hargaMeta,
        harga.isAcceptableOrUnknown(data['harga']!, _hargaMeta),
      );
    } else if (isInserting) {
      context.missing(_hargaMeta);
    }
    if (data.containsKey('kategori_pekerjaan_id')) {
      context.handle(
        _kategoriPekerjaanIdMeta,
        kategoriPekerjaanId.isAcceptableOrUnknown(
          data['kategori_pekerjaan_id']!,
          _kategoriPekerjaanIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_kategoriPekerjaanIdMeta);
    }
    if (data.containsKey('estimasi_waktu')) {
      context.handle(
        _estimasiWaktuMeta,
        estimasiWaktu.isAcceptableOrUnknown(
          data['estimasi_waktu']!,
          _estimasiWaktuMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_estimasiWaktuMeta);
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    }
    if (data.containsKey('updated_by')) {
      context.handle(
        _updatedByMeta,
        updatedBy.isAcceptableOrUnknown(data['updated_by']!, _updatedByMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
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
  PekerjaanPpatHargaLocal map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PekerjaanPpatHargaLocal(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      pekerjaanPpatId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pekerjaan_ppat_id'],
      )!,
      harga: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}harga'],
      )!,
      kategoriPekerjaanId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kategori_pekerjaan_id'],
      )!,
      estimasiWaktu: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}estimasi_waktu'],
      )!,
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_by'],
      ),
      updatedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_by'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
      isSyncDirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_sync_dirty'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $PekerjaanPpatHargaLocalsTable createAlias(String alias) {
    return $PekerjaanPpatHargaLocalsTable(attachedDatabase, alias);
  }
}

class PekerjaanPpatHargaLocal extends DataClass
    implements Insertable<PekerjaanPpatHargaLocal> {
  final int id;
  final String uuid;
  final int pekerjaanPpatId;
  final String harga;
  final int kategoriPekerjaanId;
  final String estimasiWaktu;
  final int? createdBy;
  final int? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int status;
  final bool isSyncDirty;
  final DateTime? lastSyncedAt;
  final DateTime? deletedAt;
  const PekerjaanPpatHargaLocal({
    required this.id,
    required this.uuid,
    required this.pekerjaanPpatId,
    required this.harga,
    required this.kategoriPekerjaanId,
    required this.estimasiWaktu,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
    required this.status,
    required this.isSyncDirty,
    this.lastSyncedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['pekerjaan_ppat_id'] = Variable<int>(pekerjaanPpatId);
    map['harga'] = Variable<String>(harga);
    map['kategori_pekerjaan_id'] = Variable<int>(kategoriPekerjaanId);
    map['estimasi_waktu'] = Variable<String>(estimasiWaktu);
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<int>(createdBy);
    }
    if (!nullToAbsent || updatedBy != null) {
      map['updated_by'] = Variable<int>(updatedBy);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    map['status'] = Variable<int>(status);
    map['is_sync_dirty'] = Variable<bool>(isSyncDirty);
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  PekerjaanPpatHargaLocalsCompanion toCompanion(bool nullToAbsent) {
    return PekerjaanPpatHargaLocalsCompanion(
      id: Value(id),
      uuid: Value(uuid),
      pekerjaanPpatId: Value(pekerjaanPpatId),
      harga: Value(harga),
      kategoriPekerjaanId: Value(kategoriPekerjaanId),
      estimasiWaktu: Value(estimasiWaktu),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      updatedBy: updatedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedBy),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      status: Value(status),
      isSyncDirty: Value(isSyncDirty),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory PekerjaanPpatHargaLocal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PekerjaanPpatHargaLocal(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      pekerjaanPpatId: serializer.fromJson<int>(json['pekerjaanPpatId']),
      harga: serializer.fromJson<String>(json['harga']),
      kategoriPekerjaanId: serializer.fromJson<int>(
        json['kategoriPekerjaanId'],
      ),
      estimasiWaktu: serializer.fromJson<String>(json['estimasiWaktu']),
      createdBy: serializer.fromJson<int?>(json['createdBy']),
      updatedBy: serializer.fromJson<int?>(json['updatedBy']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      status: serializer.fromJson<int>(json['status']),
      isSyncDirty: serializer.fromJson<bool>(json['isSyncDirty']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'pekerjaanPpatId': serializer.toJson<int>(pekerjaanPpatId),
      'harga': serializer.toJson<String>(harga),
      'kategoriPekerjaanId': serializer.toJson<int>(kategoriPekerjaanId),
      'estimasiWaktu': serializer.toJson<String>(estimasiWaktu),
      'createdBy': serializer.toJson<int?>(createdBy),
      'updatedBy': serializer.toJson<int?>(updatedBy),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'status': serializer.toJson<int>(status),
      'isSyncDirty': serializer.toJson<bool>(isSyncDirty),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  PekerjaanPpatHargaLocal copyWith({
    int? id,
    String? uuid,
    int? pekerjaanPpatId,
    String? harga,
    int? kategoriPekerjaanId,
    String? estimasiWaktu,
    Value<int?> createdBy = const Value.absent(),
    Value<int?> updatedBy = const Value.absent(),
    Value<DateTime?> createdAt = const Value.absent(),
    Value<DateTime?> updatedAt = const Value.absent(),
    int? status,
    bool? isSyncDirty,
    Value<DateTime?> lastSyncedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => PekerjaanPpatHargaLocal(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    pekerjaanPpatId: pekerjaanPpatId ?? this.pekerjaanPpatId,
    harga: harga ?? this.harga,
    kategoriPekerjaanId: kategoriPekerjaanId ?? this.kategoriPekerjaanId,
    estimasiWaktu: estimasiWaktu ?? this.estimasiWaktu,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
    updatedBy: updatedBy.present ? updatedBy.value : this.updatedBy,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    status: status ?? this.status,
    isSyncDirty: isSyncDirty ?? this.isSyncDirty,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  PekerjaanPpatHargaLocal copyWithCompanion(
    PekerjaanPpatHargaLocalsCompanion data,
  ) {
    return PekerjaanPpatHargaLocal(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      pekerjaanPpatId: data.pekerjaanPpatId.present
          ? data.pekerjaanPpatId.value
          : this.pekerjaanPpatId,
      harga: data.harga.present ? data.harga.value : this.harga,
      kategoriPekerjaanId: data.kategoriPekerjaanId.present
          ? data.kategoriPekerjaanId.value
          : this.kategoriPekerjaanId,
      estimasiWaktu: data.estimasiWaktu.present
          ? data.estimasiWaktu.value
          : this.estimasiWaktu,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      updatedBy: data.updatedBy.present ? data.updatedBy.value : this.updatedBy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      status: data.status.present ? data.status.value : this.status,
      isSyncDirty: data.isSyncDirty.present
          ? data.isSyncDirty.value
          : this.isSyncDirty,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PekerjaanPpatHargaLocal(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('pekerjaanPpatId: $pekerjaanPpatId, ')
          ..write('harga: $harga, ')
          ..write('kategoriPekerjaanId: $kategoriPekerjaanId, ')
          ..write('estimasiWaktu: $estimasiWaktu, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('status: $status, ')
          ..write('isSyncDirty: $isSyncDirty, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    pekerjaanPpatId,
    harga,
    kategoriPekerjaanId,
    estimasiWaktu,
    createdBy,
    updatedBy,
    createdAt,
    updatedAt,
    status,
    isSyncDirty,
    lastSyncedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PekerjaanPpatHargaLocal &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.pekerjaanPpatId == this.pekerjaanPpatId &&
          other.harga == this.harga &&
          other.kategoriPekerjaanId == this.kategoriPekerjaanId &&
          other.estimasiWaktu == this.estimasiWaktu &&
          other.createdBy == this.createdBy &&
          other.updatedBy == this.updatedBy &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.status == this.status &&
          other.isSyncDirty == this.isSyncDirty &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.deletedAt == this.deletedAt);
}

class PekerjaanPpatHargaLocalsCompanion
    extends UpdateCompanion<PekerjaanPpatHargaLocal> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<int> pekerjaanPpatId;
  final Value<String> harga;
  final Value<int> kategoriPekerjaanId;
  final Value<String> estimasiWaktu;
  final Value<int?> createdBy;
  final Value<int?> updatedBy;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<int> status;
  final Value<bool> isSyncDirty;
  final Value<DateTime?> lastSyncedAt;
  final Value<DateTime?> deletedAt;
  const PekerjaanPpatHargaLocalsCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.pekerjaanPpatId = const Value.absent(),
    this.harga = const Value.absent(),
    this.kategoriPekerjaanId = const Value.absent(),
    this.estimasiWaktu = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.isSyncDirty = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  PekerjaanPpatHargaLocalsCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required int pekerjaanPpatId,
    required String harga,
    required int kategoriPekerjaanId,
    required String estimasiWaktu,
    this.createdBy = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.isSyncDirty = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  }) : uuid = Value(uuid),
       pekerjaanPpatId = Value(pekerjaanPpatId),
       harga = Value(harga),
       kategoriPekerjaanId = Value(kategoriPekerjaanId),
       estimasiWaktu = Value(estimasiWaktu);
  static Insertable<PekerjaanPpatHargaLocal> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<int>? pekerjaanPpatId,
    Expression<String>? harga,
    Expression<int>? kategoriPekerjaanId,
    Expression<String>? estimasiWaktu,
    Expression<int>? createdBy,
    Expression<int>? updatedBy,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? status,
    Expression<bool>? isSyncDirty,
    Expression<DateTime>? lastSyncedAt,
    Expression<DateTime>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (pekerjaanPpatId != null) 'pekerjaan_ppat_id': pekerjaanPpatId,
      if (harga != null) 'harga': harga,
      if (kategoriPekerjaanId != null)
        'kategori_pekerjaan_id': kategoriPekerjaanId,
      if (estimasiWaktu != null) 'estimasi_waktu': estimasiWaktu,
      if (createdBy != null) 'created_by': createdBy,
      if (updatedBy != null) 'updated_by': updatedBy,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (status != null) 'status': status,
      if (isSyncDirty != null) 'is_sync_dirty': isSyncDirty,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  PekerjaanPpatHargaLocalsCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<int>? pekerjaanPpatId,
    Value<String>? harga,
    Value<int>? kategoriPekerjaanId,
    Value<String>? estimasiWaktu,
    Value<int?>? createdBy,
    Value<int?>? updatedBy,
    Value<DateTime?>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<int>? status,
    Value<bool>? isSyncDirty,
    Value<DateTime?>? lastSyncedAt,
    Value<DateTime?>? deletedAt,
  }) {
    return PekerjaanPpatHargaLocalsCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      pekerjaanPpatId: pekerjaanPpatId ?? this.pekerjaanPpatId,
      harga: harga ?? this.harga,
      kategoriPekerjaanId: kategoriPekerjaanId ?? this.kategoriPekerjaanId,
      estimasiWaktu: estimasiWaktu ?? this.estimasiWaktu,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      isSyncDirty: isSyncDirty ?? this.isSyncDirty,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
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
    if (pekerjaanPpatId.present) {
      map['pekerjaan_ppat_id'] = Variable<int>(pekerjaanPpatId.value);
    }
    if (harga.present) {
      map['harga'] = Variable<String>(harga.value);
    }
    if (kategoriPekerjaanId.present) {
      map['kategori_pekerjaan_id'] = Variable<int>(kategoriPekerjaanId.value);
    }
    if (estimasiWaktu.present) {
      map['estimasi_waktu'] = Variable<String>(estimasiWaktu.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<int>(createdBy.value);
    }
    if (updatedBy.present) {
      map['updated_by'] = Variable<int>(updatedBy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (isSyncDirty.present) {
      map['is_sync_dirty'] = Variable<bool>(isSyncDirty.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PekerjaanPpatHargaLocalsCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('pekerjaanPpatId: $pekerjaanPpatId, ')
          ..write('harga: $harga, ')
          ..write('kategoriPekerjaanId: $kategoriPekerjaanId, ')
          ..write('estimasiWaktu: $estimasiWaktu, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('status: $status, ')
          ..write('isSyncDirty: $isSyncDirty, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

class $PekerjaanPpatProsesLocalsTable extends PekerjaanPpatProsesLocals
    with TableInfo<$PekerjaanPpatProsesLocalsTable, PekerjaanPpatProsesLocal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PekerjaanPpatProsesLocalsTable(this.attachedDatabase, [this._alias]);
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
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _pekerjaanPpatIdMeta = const VerificationMeta(
    'pekerjaanPpatId',
  );
  @override
  late final GeneratedColumn<int> pekerjaanPpatId = GeneratedColumn<int>(
    'pekerjaan_ppat_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES pekerjaan_ppat (id)',
    ),
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
  static const VerificationMeta _detailMeta = const VerificationMeta('detail');
  @override
  late final GeneratedColumn<String> detail = GeneratedColumn<String>(
    'detail',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<int> createdBy = GeneratedColumn<int>(
    'created_by',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedByMeta = const VerificationMeta(
    'updatedBy',
  );
  @override
  late final GeneratedColumn<int> updatedBy = GeneratedColumn<int>(
    'updated_by',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
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
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
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
    pekerjaanPpatId,
    nama,
    detail,
    createdBy,
    updatedBy,
    createdAt,
    updatedAt,
    status,
    isSyncDirty,
    lastSyncedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pekerjaan_ppat_proses';
  @override
  VerificationContext validateIntegrity(
    Insertable<PekerjaanPpatProsesLocal> instance, {
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
    if (data.containsKey('pekerjaan_ppat_id')) {
      context.handle(
        _pekerjaanPpatIdMeta,
        pekerjaanPpatId.isAcceptableOrUnknown(
          data['pekerjaan_ppat_id']!,
          _pekerjaanPpatIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_pekerjaanPpatIdMeta);
    }
    if (data.containsKey('nama')) {
      context.handle(
        _namaMeta,
        nama.isAcceptableOrUnknown(data['nama']!, _namaMeta),
      );
    } else if (isInserting) {
      context.missing(_namaMeta);
    }
    if (data.containsKey('detail')) {
      context.handle(
        _detailMeta,
        detail.isAcceptableOrUnknown(data['detail']!, _detailMeta),
      );
    } else if (isInserting) {
      context.missing(_detailMeta);
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    }
    if (data.containsKey('updated_by')) {
      context.handle(
        _updatedByMeta,
        updatedBy.isAcceptableOrUnknown(data['updated_by']!, _updatedByMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
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
  PekerjaanPpatProsesLocal map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PekerjaanPpatProsesLocal(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      pekerjaanPpatId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pekerjaan_ppat_id'],
      )!,
      nama: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nama'],
      )!,
      detail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detail'],
      )!,
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_by'],
      ),
      updatedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_by'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
      isSyncDirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_sync_dirty'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $PekerjaanPpatProsesLocalsTable createAlias(String alias) {
    return $PekerjaanPpatProsesLocalsTable(attachedDatabase, alias);
  }
}

class PekerjaanPpatProsesLocal extends DataClass
    implements Insertable<PekerjaanPpatProsesLocal> {
  final int id;
  final String uuid;
  final int pekerjaanPpatId;
  final String nama;
  final String detail;
  final int? createdBy;
  final int? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int status;
  final bool isSyncDirty;
  final DateTime? lastSyncedAt;
  final DateTime? deletedAt;
  const PekerjaanPpatProsesLocal({
    required this.id,
    required this.uuid,
    required this.pekerjaanPpatId,
    required this.nama,
    required this.detail,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
    required this.status,
    required this.isSyncDirty,
    this.lastSyncedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['pekerjaan_ppat_id'] = Variable<int>(pekerjaanPpatId);
    map['nama'] = Variable<String>(nama);
    map['detail'] = Variable<String>(detail);
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<int>(createdBy);
    }
    if (!nullToAbsent || updatedBy != null) {
      map['updated_by'] = Variable<int>(updatedBy);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    map['status'] = Variable<int>(status);
    map['is_sync_dirty'] = Variable<bool>(isSyncDirty);
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  PekerjaanPpatProsesLocalsCompanion toCompanion(bool nullToAbsent) {
    return PekerjaanPpatProsesLocalsCompanion(
      id: Value(id),
      uuid: Value(uuid),
      pekerjaanPpatId: Value(pekerjaanPpatId),
      nama: Value(nama),
      detail: Value(detail),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      updatedBy: updatedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedBy),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      status: Value(status),
      isSyncDirty: Value(isSyncDirty),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory PekerjaanPpatProsesLocal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PekerjaanPpatProsesLocal(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      pekerjaanPpatId: serializer.fromJson<int>(json['pekerjaanPpatId']),
      nama: serializer.fromJson<String>(json['nama']),
      detail: serializer.fromJson<String>(json['detail']),
      createdBy: serializer.fromJson<int?>(json['createdBy']),
      updatedBy: serializer.fromJson<int?>(json['updatedBy']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      status: serializer.fromJson<int>(json['status']),
      isSyncDirty: serializer.fromJson<bool>(json['isSyncDirty']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'pekerjaanPpatId': serializer.toJson<int>(pekerjaanPpatId),
      'nama': serializer.toJson<String>(nama),
      'detail': serializer.toJson<String>(detail),
      'createdBy': serializer.toJson<int?>(createdBy),
      'updatedBy': serializer.toJson<int?>(updatedBy),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'status': serializer.toJson<int>(status),
      'isSyncDirty': serializer.toJson<bool>(isSyncDirty),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  PekerjaanPpatProsesLocal copyWith({
    int? id,
    String? uuid,
    int? pekerjaanPpatId,
    String? nama,
    String? detail,
    Value<int?> createdBy = const Value.absent(),
    Value<int?> updatedBy = const Value.absent(),
    Value<DateTime?> createdAt = const Value.absent(),
    Value<DateTime?> updatedAt = const Value.absent(),
    int? status,
    bool? isSyncDirty,
    Value<DateTime?> lastSyncedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => PekerjaanPpatProsesLocal(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    pekerjaanPpatId: pekerjaanPpatId ?? this.pekerjaanPpatId,
    nama: nama ?? this.nama,
    detail: detail ?? this.detail,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
    updatedBy: updatedBy.present ? updatedBy.value : this.updatedBy,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    status: status ?? this.status,
    isSyncDirty: isSyncDirty ?? this.isSyncDirty,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  PekerjaanPpatProsesLocal copyWithCompanion(
    PekerjaanPpatProsesLocalsCompanion data,
  ) {
    return PekerjaanPpatProsesLocal(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      pekerjaanPpatId: data.pekerjaanPpatId.present
          ? data.pekerjaanPpatId.value
          : this.pekerjaanPpatId,
      nama: data.nama.present ? data.nama.value : this.nama,
      detail: data.detail.present ? data.detail.value : this.detail,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      updatedBy: data.updatedBy.present ? data.updatedBy.value : this.updatedBy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      status: data.status.present ? data.status.value : this.status,
      isSyncDirty: data.isSyncDirty.present
          ? data.isSyncDirty.value
          : this.isSyncDirty,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PekerjaanPpatProsesLocal(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('pekerjaanPpatId: $pekerjaanPpatId, ')
          ..write('nama: $nama, ')
          ..write('detail: $detail, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('status: $status, ')
          ..write('isSyncDirty: $isSyncDirty, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    pekerjaanPpatId,
    nama,
    detail,
    createdBy,
    updatedBy,
    createdAt,
    updatedAt,
    status,
    isSyncDirty,
    lastSyncedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PekerjaanPpatProsesLocal &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.pekerjaanPpatId == this.pekerjaanPpatId &&
          other.nama == this.nama &&
          other.detail == this.detail &&
          other.createdBy == this.createdBy &&
          other.updatedBy == this.updatedBy &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.status == this.status &&
          other.isSyncDirty == this.isSyncDirty &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.deletedAt == this.deletedAt);
}

class PekerjaanPpatProsesLocalsCompanion
    extends UpdateCompanion<PekerjaanPpatProsesLocal> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<int> pekerjaanPpatId;
  final Value<String> nama;
  final Value<String> detail;
  final Value<int?> createdBy;
  final Value<int?> updatedBy;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<int> status;
  final Value<bool> isSyncDirty;
  final Value<DateTime?> lastSyncedAt;
  final Value<DateTime?> deletedAt;
  const PekerjaanPpatProsesLocalsCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.pekerjaanPpatId = const Value.absent(),
    this.nama = const Value.absent(),
    this.detail = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.isSyncDirty = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  PekerjaanPpatProsesLocalsCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required int pekerjaanPpatId,
    required String nama,
    required String detail,
    this.createdBy = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.isSyncDirty = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  }) : uuid = Value(uuid),
       pekerjaanPpatId = Value(pekerjaanPpatId),
       nama = Value(nama),
       detail = Value(detail);
  static Insertable<PekerjaanPpatProsesLocal> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<int>? pekerjaanPpatId,
    Expression<String>? nama,
    Expression<String>? detail,
    Expression<int>? createdBy,
    Expression<int>? updatedBy,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? status,
    Expression<bool>? isSyncDirty,
    Expression<DateTime>? lastSyncedAt,
    Expression<DateTime>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (pekerjaanPpatId != null) 'pekerjaan_ppat_id': pekerjaanPpatId,
      if (nama != null) 'nama': nama,
      if (detail != null) 'detail': detail,
      if (createdBy != null) 'created_by': createdBy,
      if (updatedBy != null) 'updated_by': updatedBy,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (status != null) 'status': status,
      if (isSyncDirty != null) 'is_sync_dirty': isSyncDirty,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  PekerjaanPpatProsesLocalsCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<int>? pekerjaanPpatId,
    Value<String>? nama,
    Value<String>? detail,
    Value<int?>? createdBy,
    Value<int?>? updatedBy,
    Value<DateTime?>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<int>? status,
    Value<bool>? isSyncDirty,
    Value<DateTime?>? lastSyncedAt,
    Value<DateTime?>? deletedAt,
  }) {
    return PekerjaanPpatProsesLocalsCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      pekerjaanPpatId: pekerjaanPpatId ?? this.pekerjaanPpatId,
      nama: nama ?? this.nama,
      detail: detail ?? this.detail,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      isSyncDirty: isSyncDirty ?? this.isSyncDirty,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
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
    if (pekerjaanPpatId.present) {
      map['pekerjaan_ppat_id'] = Variable<int>(pekerjaanPpatId.value);
    }
    if (nama.present) {
      map['nama'] = Variable<String>(nama.value);
    }
    if (detail.present) {
      map['detail'] = Variable<String>(detail.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<int>(createdBy.value);
    }
    if (updatedBy.present) {
      map['updated_by'] = Variable<int>(updatedBy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (isSyncDirty.present) {
      map['is_sync_dirty'] = Variable<bool>(isSyncDirty.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PekerjaanPpatProsesLocalsCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('pekerjaanPpatId: $pekerjaanPpatId, ')
          ..write('nama: $nama, ')
          ..write('detail: $detail, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('status: $status, ')
          ..write('isSyncDirty: $isSyncDirty, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

class $PekerjaanPpatAtributLocalsTable extends PekerjaanPpatAtributLocals
    with
        TableInfo<$PekerjaanPpatAtributLocalsTable, PekerjaanPpatAtributLocal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PekerjaanPpatAtributLocalsTable(this.attachedDatabase, [this._alias]);
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
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _pekerjaanPpatIdMeta = const VerificationMeta(
    'pekerjaanPpatId',
  );
  @override
  late final GeneratedColumn<int> pekerjaanPpatId = GeneratedColumn<int>(
    'pekerjaan_ppat_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES pekerjaan_ppat (id)',
    ),
  );
  static const VerificationMeta _prosesPekerjaanPpatIdMeta =
      const VerificationMeta('prosesPekerjaanPpatId');
  @override
  late final GeneratedColumn<int> prosesPekerjaanPpatId = GeneratedColumn<int>(
    'proses_pekerjaan_ppat_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES pekerjaan_ppat_proses (id)',
    ),
  );
  static const VerificationMeta _atributMeta = const VerificationMeta(
    'atribut',
  );
  @override
  late final GeneratedColumn<String> atribut = GeneratedColumn<String>(
    'atribut',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<int> createdBy = GeneratedColumn<int>(
    'created_by',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedByMeta = const VerificationMeta(
    'updatedBy',
  );
  @override
  late final GeneratedColumn<int> updatedBy = GeneratedColumn<int>(
    'updated_by',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
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
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
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
    pekerjaanPpatId,
    prosesPekerjaanPpatId,
    atribut,
    createdBy,
    updatedBy,
    createdAt,
    updatedAt,
    status,
    isSyncDirty,
    lastSyncedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pekerjaan_ppat_atributs';
  @override
  VerificationContext validateIntegrity(
    Insertable<PekerjaanPpatAtributLocal> instance, {
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
    if (data.containsKey('pekerjaan_ppat_id')) {
      context.handle(
        _pekerjaanPpatIdMeta,
        pekerjaanPpatId.isAcceptableOrUnknown(
          data['pekerjaan_ppat_id']!,
          _pekerjaanPpatIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_pekerjaanPpatIdMeta);
    }
    if (data.containsKey('proses_pekerjaan_ppat_id')) {
      context.handle(
        _prosesPekerjaanPpatIdMeta,
        prosesPekerjaanPpatId.isAcceptableOrUnknown(
          data['proses_pekerjaan_ppat_id']!,
          _prosesPekerjaanPpatIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_prosesPekerjaanPpatIdMeta);
    }
    if (data.containsKey('atribut')) {
      context.handle(
        _atributMeta,
        atribut.isAcceptableOrUnknown(data['atribut']!, _atributMeta),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    }
    if (data.containsKey('updated_by')) {
      context.handle(
        _updatedByMeta,
        updatedBy.isAcceptableOrUnknown(data['updated_by']!, _updatedByMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
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
  PekerjaanPpatAtributLocal map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PekerjaanPpatAtributLocal(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      pekerjaanPpatId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pekerjaan_ppat_id'],
      )!,
      prosesPekerjaanPpatId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}proses_pekerjaan_ppat_id'],
      )!,
      atribut: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}atribut'],
      ),
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_by'],
      ),
      updatedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_by'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
      isSyncDirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_sync_dirty'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $PekerjaanPpatAtributLocalsTable createAlias(String alias) {
    return $PekerjaanPpatAtributLocalsTable(attachedDatabase, alias);
  }
}

class PekerjaanPpatAtributLocal extends DataClass
    implements Insertable<PekerjaanPpatAtributLocal> {
  final int id;
  final String uuid;
  final int pekerjaanPpatId;
  final int prosesPekerjaanPpatId;
  final String? atribut;
  final int? createdBy;
  final int? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int status;
  final bool isSyncDirty;
  final DateTime? lastSyncedAt;
  final DateTime? deletedAt;
  const PekerjaanPpatAtributLocal({
    required this.id,
    required this.uuid,
    required this.pekerjaanPpatId,
    required this.prosesPekerjaanPpatId,
    this.atribut,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
    required this.status,
    required this.isSyncDirty,
    this.lastSyncedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['pekerjaan_ppat_id'] = Variable<int>(pekerjaanPpatId);
    map['proses_pekerjaan_ppat_id'] = Variable<int>(prosesPekerjaanPpatId);
    if (!nullToAbsent || atribut != null) {
      map['atribut'] = Variable<String>(atribut);
    }
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<int>(createdBy);
    }
    if (!nullToAbsent || updatedBy != null) {
      map['updated_by'] = Variable<int>(updatedBy);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    map['status'] = Variable<int>(status);
    map['is_sync_dirty'] = Variable<bool>(isSyncDirty);
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  PekerjaanPpatAtributLocalsCompanion toCompanion(bool nullToAbsent) {
    return PekerjaanPpatAtributLocalsCompanion(
      id: Value(id),
      uuid: Value(uuid),
      pekerjaanPpatId: Value(pekerjaanPpatId),
      prosesPekerjaanPpatId: Value(prosesPekerjaanPpatId),
      atribut: atribut == null && nullToAbsent
          ? const Value.absent()
          : Value(atribut),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      updatedBy: updatedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedBy),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      status: Value(status),
      isSyncDirty: Value(isSyncDirty),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory PekerjaanPpatAtributLocal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PekerjaanPpatAtributLocal(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      pekerjaanPpatId: serializer.fromJson<int>(json['pekerjaanPpatId']),
      prosesPekerjaanPpatId: serializer.fromJson<int>(
        json['prosesPekerjaanPpatId'],
      ),
      atribut: serializer.fromJson<String?>(json['atribut']),
      createdBy: serializer.fromJson<int?>(json['createdBy']),
      updatedBy: serializer.fromJson<int?>(json['updatedBy']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      status: serializer.fromJson<int>(json['status']),
      isSyncDirty: serializer.fromJson<bool>(json['isSyncDirty']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'pekerjaanPpatId': serializer.toJson<int>(pekerjaanPpatId),
      'prosesPekerjaanPpatId': serializer.toJson<int>(prosesPekerjaanPpatId),
      'atribut': serializer.toJson<String?>(atribut),
      'createdBy': serializer.toJson<int?>(createdBy),
      'updatedBy': serializer.toJson<int?>(updatedBy),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'status': serializer.toJson<int>(status),
      'isSyncDirty': serializer.toJson<bool>(isSyncDirty),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  PekerjaanPpatAtributLocal copyWith({
    int? id,
    String? uuid,
    int? pekerjaanPpatId,
    int? prosesPekerjaanPpatId,
    Value<String?> atribut = const Value.absent(),
    Value<int?> createdBy = const Value.absent(),
    Value<int?> updatedBy = const Value.absent(),
    Value<DateTime?> createdAt = const Value.absent(),
    Value<DateTime?> updatedAt = const Value.absent(),
    int? status,
    bool? isSyncDirty,
    Value<DateTime?> lastSyncedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => PekerjaanPpatAtributLocal(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    pekerjaanPpatId: pekerjaanPpatId ?? this.pekerjaanPpatId,
    prosesPekerjaanPpatId: prosesPekerjaanPpatId ?? this.prosesPekerjaanPpatId,
    atribut: atribut.present ? atribut.value : this.atribut,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
    updatedBy: updatedBy.present ? updatedBy.value : this.updatedBy,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    status: status ?? this.status,
    isSyncDirty: isSyncDirty ?? this.isSyncDirty,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  PekerjaanPpatAtributLocal copyWithCompanion(
    PekerjaanPpatAtributLocalsCompanion data,
  ) {
    return PekerjaanPpatAtributLocal(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      pekerjaanPpatId: data.pekerjaanPpatId.present
          ? data.pekerjaanPpatId.value
          : this.pekerjaanPpatId,
      prosesPekerjaanPpatId: data.prosesPekerjaanPpatId.present
          ? data.prosesPekerjaanPpatId.value
          : this.prosesPekerjaanPpatId,
      atribut: data.atribut.present ? data.atribut.value : this.atribut,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      updatedBy: data.updatedBy.present ? data.updatedBy.value : this.updatedBy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      status: data.status.present ? data.status.value : this.status,
      isSyncDirty: data.isSyncDirty.present
          ? data.isSyncDirty.value
          : this.isSyncDirty,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PekerjaanPpatAtributLocal(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('pekerjaanPpatId: $pekerjaanPpatId, ')
          ..write('prosesPekerjaanPpatId: $prosesPekerjaanPpatId, ')
          ..write('atribut: $atribut, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('status: $status, ')
          ..write('isSyncDirty: $isSyncDirty, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    pekerjaanPpatId,
    prosesPekerjaanPpatId,
    atribut,
    createdBy,
    updatedBy,
    createdAt,
    updatedAt,
    status,
    isSyncDirty,
    lastSyncedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PekerjaanPpatAtributLocal &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.pekerjaanPpatId == this.pekerjaanPpatId &&
          other.prosesPekerjaanPpatId == this.prosesPekerjaanPpatId &&
          other.atribut == this.atribut &&
          other.createdBy == this.createdBy &&
          other.updatedBy == this.updatedBy &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.status == this.status &&
          other.isSyncDirty == this.isSyncDirty &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.deletedAt == this.deletedAt);
}

class PekerjaanPpatAtributLocalsCompanion
    extends UpdateCompanion<PekerjaanPpatAtributLocal> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<int> pekerjaanPpatId;
  final Value<int> prosesPekerjaanPpatId;
  final Value<String?> atribut;
  final Value<int?> createdBy;
  final Value<int?> updatedBy;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<int> status;
  final Value<bool> isSyncDirty;
  final Value<DateTime?> lastSyncedAt;
  final Value<DateTime?> deletedAt;
  const PekerjaanPpatAtributLocalsCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.pekerjaanPpatId = const Value.absent(),
    this.prosesPekerjaanPpatId = const Value.absent(),
    this.atribut = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.isSyncDirty = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  PekerjaanPpatAtributLocalsCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required int pekerjaanPpatId,
    required int prosesPekerjaanPpatId,
    this.atribut = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.isSyncDirty = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  }) : uuid = Value(uuid),
       pekerjaanPpatId = Value(pekerjaanPpatId),
       prosesPekerjaanPpatId = Value(prosesPekerjaanPpatId);
  static Insertable<PekerjaanPpatAtributLocal> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<int>? pekerjaanPpatId,
    Expression<int>? prosesPekerjaanPpatId,
    Expression<String>? atribut,
    Expression<int>? createdBy,
    Expression<int>? updatedBy,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? status,
    Expression<bool>? isSyncDirty,
    Expression<DateTime>? lastSyncedAt,
    Expression<DateTime>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (pekerjaanPpatId != null) 'pekerjaan_ppat_id': pekerjaanPpatId,
      if (prosesPekerjaanPpatId != null)
        'proses_pekerjaan_ppat_id': prosesPekerjaanPpatId,
      if (atribut != null) 'atribut': atribut,
      if (createdBy != null) 'created_by': createdBy,
      if (updatedBy != null) 'updated_by': updatedBy,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (status != null) 'status': status,
      if (isSyncDirty != null) 'is_sync_dirty': isSyncDirty,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  PekerjaanPpatAtributLocalsCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<int>? pekerjaanPpatId,
    Value<int>? prosesPekerjaanPpatId,
    Value<String?>? atribut,
    Value<int?>? createdBy,
    Value<int?>? updatedBy,
    Value<DateTime?>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<int>? status,
    Value<bool>? isSyncDirty,
    Value<DateTime?>? lastSyncedAt,
    Value<DateTime?>? deletedAt,
  }) {
    return PekerjaanPpatAtributLocalsCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      pekerjaanPpatId: pekerjaanPpatId ?? this.pekerjaanPpatId,
      prosesPekerjaanPpatId:
          prosesPekerjaanPpatId ?? this.prosesPekerjaanPpatId,
      atribut: atribut ?? this.atribut,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      isSyncDirty: isSyncDirty ?? this.isSyncDirty,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
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
    if (pekerjaanPpatId.present) {
      map['pekerjaan_ppat_id'] = Variable<int>(pekerjaanPpatId.value);
    }
    if (prosesPekerjaanPpatId.present) {
      map['proses_pekerjaan_ppat_id'] = Variable<int>(
        prosesPekerjaanPpatId.value,
      );
    }
    if (atribut.present) {
      map['atribut'] = Variable<String>(atribut.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<int>(createdBy.value);
    }
    if (updatedBy.present) {
      map['updated_by'] = Variable<int>(updatedBy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (isSyncDirty.present) {
      map['is_sync_dirty'] = Variable<bool>(isSyncDirty.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PekerjaanPpatAtributLocalsCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('pekerjaanPpatId: $pekerjaanPpatId, ')
          ..write('prosesPekerjaanPpatId: $prosesPekerjaanPpatId, ')
          ..write('atribut: $atribut, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('status: $status, ')
          ..write('isSyncDirty: $isSyncDirty, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $JenisKelaminsTable jenisKelamins = $JenisKelaminsTable(this);
  late final $PemohonsTable pemohons = $PemohonsTable(this);
  late final $TransaksisTable transaksis = $TransaksisTable(this);
  late final $PekerjaanKategorisTable pekerjaanKategoris =
      $PekerjaanKategorisTable(this);
  late final $PengeluaranJenisTable pengeluaranJenis = $PengeluaranJenisTable(
    this,
  );
  late final $PetugasLocalsTable petugasLocals = $PetugasLocalsTable(this);
  late final $PekerjaanNotarisLocalsTable pekerjaanNotarisLocals =
      $PekerjaanNotarisLocalsTable(this);
  late final $PekerjaanNotarisHargaLocalsTable pekerjaanNotarisHargaLocals =
      $PekerjaanNotarisHargaLocalsTable(this);
  late final $PekerjaanNotarisProsesLocalsTable pekerjaanNotarisProsesLocals =
      $PekerjaanNotarisProsesLocalsTable(this);
  late final $PekerjaanNotarisAtributLocalsTable pekerjaanNotarisAtributLocals =
      $PekerjaanNotarisAtributLocalsTable(this);
  late final $PekerjaanPpatLocalsTable pekerjaanPpatLocals =
      $PekerjaanPpatLocalsTable(this);
  late final $PekerjaanPpatHargaLocalsTable pekerjaanPpatHargaLocals =
      $PekerjaanPpatHargaLocalsTable(this);
  late final $PekerjaanPpatProsesLocalsTable pekerjaanPpatProsesLocals =
      $PekerjaanPpatProsesLocalsTable(this);
  late final $PekerjaanPpatAtributLocalsTable pekerjaanPpatAtributLocals =
      $PekerjaanPpatAtributLocalsTable(this);
  late final PekerjaanDao pekerjaanDao = PekerjaanDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    jenisKelamins,
    pemohons,
    transaksis,
    pekerjaanKategoris,
    pengeluaranJenis,
    petugasLocals,
    pekerjaanNotarisLocals,
    pekerjaanNotarisHargaLocals,
    pekerjaanNotarisProsesLocals,
    pekerjaanNotarisAtributLocals,
    pekerjaanPpatLocals,
    pekerjaanPpatHargaLocals,
    pekerjaanPpatProsesLocals,
    pekerjaanPpatAtributLocals,
  ];
}

typedef $$JenisKelaminsTableCreateCompanionBuilder =
    JenisKelaminsCompanion Function({
      Value<int> id,
      required String uuid,
      required String nama,
      Value<int?> createdBy,
      Value<int?> updatedBy,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> status,
      Value<bool> isSyncDirty,
      Value<DateTime?> lastSyncedAt,
      Value<DateTime?> deletedAt,
    });
typedef $$JenisKelaminsTableUpdateCompanionBuilder =
    JenisKelaminsCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<String> nama,
      Value<int?> createdBy,
      Value<int?> updatedBy,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> status,
      Value<bool> isSyncDirty,
      Value<DateTime?> lastSyncedAt,
      Value<DateTime?> deletedAt,
    });

final class $$JenisKelaminsTableReferences
    extends BaseReferences<_$AppDatabase, $JenisKelaminsTable, JenisKelamin> {
  $$JenisKelaminsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$PemohonsTable, List<Pemohon>> _pemohonsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.pemohons,
    aliasName: 'jenis_kelamin__id__pemohons__jenis_kelamin',
  );

  $$PemohonsTableProcessedTableManager get pemohonsRefs {
    final manager = $$PemohonsTableTableManager(
      $_db,
      $_db.pemohons,
    ).filter((f) => f.jenisKelamin.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_pemohonsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PetugasLocalsTable, List<PetugasLocal>>
  _petugasLocalsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.petugasLocals,
    aliasName: 'jenis_kelamin__id__petugas__jenis_kelamin',
  );

  $$PetugasLocalsTableProcessedTableManager get petugasLocalsRefs {
    final manager = $$PetugasLocalsTableTableManager(
      $_db,
      $_db.petugasLocals,
    ).filter((f) => f.jenisKelamin.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_petugasLocalsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$JenisKelaminsTableFilterComposer
    extends Composer<_$AppDatabase, $JenisKelaminsTable> {
  $$JenisKelaminsTableFilterComposer({
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

  ColumnFilters<int> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
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

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> pemohonsRefs(
    Expression<bool> Function($$PemohonsTableFilterComposer f) f,
  ) {
    final $$PemohonsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pemohons,
      getReferencedColumn: (t) => t.jenisKelamin,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PemohonsTableFilterComposer(
            $db: $db,
            $table: $db.pemohons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> petugasLocalsRefs(
    Expression<bool> Function($$PetugasLocalsTableFilterComposer f) f,
  ) {
    final $$PetugasLocalsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.petugasLocals,
      getReferencedColumn: (t) => t.jenisKelamin,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PetugasLocalsTableFilterComposer(
            $db: $db,
            $table: $db.petugasLocals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$JenisKelaminsTableOrderingComposer
    extends Composer<_$AppDatabase, $JenisKelaminsTable> {
  $$JenisKelaminsTableOrderingComposer({
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

  ColumnOrderings<int> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
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

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$JenisKelaminsTableAnnotationComposer
    extends Composer<_$AppDatabase, $JenisKelaminsTable> {
  $$JenisKelaminsTableAnnotationComposer({
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

  GeneratedColumn<int> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<int> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get isSyncDirty => $composableBuilder(
    column: $table.isSyncDirty,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  Expression<T> pemohonsRefs<T extends Object>(
    Expression<T> Function($$PemohonsTableAnnotationComposer a) f,
  ) {
    final $$PemohonsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pemohons,
      getReferencedColumn: (t) => t.jenisKelamin,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PemohonsTableAnnotationComposer(
            $db: $db,
            $table: $db.pemohons,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> petugasLocalsRefs<T extends Object>(
    Expression<T> Function($$PetugasLocalsTableAnnotationComposer a) f,
  ) {
    final $$PetugasLocalsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.petugasLocals,
      getReferencedColumn: (t) => t.jenisKelamin,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PetugasLocalsTableAnnotationComposer(
            $db: $db,
            $table: $db.petugasLocals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$JenisKelaminsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $JenisKelaminsTable,
          JenisKelamin,
          $$JenisKelaminsTableFilterComposer,
          $$JenisKelaminsTableOrderingComposer,
          $$JenisKelaminsTableAnnotationComposer,
          $$JenisKelaminsTableCreateCompanionBuilder,
          $$JenisKelaminsTableUpdateCompanionBuilder,
          (JenisKelamin, $$JenisKelaminsTableReferences),
          JenisKelamin,
          PrefetchHooks Function({bool pemohonsRefs, bool petugasLocalsRefs})
        > {
  $$JenisKelaminsTableTableManager(_$AppDatabase db, $JenisKelaminsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JenisKelaminsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JenisKelaminsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JenisKelaminsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<String> nama = const Value.absent(),
                Value<int?> createdBy = const Value.absent(),
                Value<int?> updatedBy = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<bool> isSyncDirty = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => JenisKelaminsCompanion(
                id: id,
                uuid: uuid,
                nama: nama,
                createdBy: createdBy,
                updatedBy: updatedBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                status: status,
                isSyncDirty: isSyncDirty,
                lastSyncedAt: lastSyncedAt,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uuid,
                required String nama,
                Value<int?> createdBy = const Value.absent(),
                Value<int?> updatedBy = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<bool> isSyncDirty = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => JenisKelaminsCompanion.insert(
                id: id,
                uuid: uuid,
                nama: nama,
                createdBy: createdBy,
                updatedBy: updatedBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                status: status,
                isSyncDirty: isSyncDirty,
                lastSyncedAt: lastSyncedAt,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$JenisKelaminsTable, JenisKelamin>(table),
                  $$JenisKelaminsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({pemohonsRefs = false, petugasLocalsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (pemohonsRefs) db.pemohons,
                    if (petugasLocalsRefs) db.petugasLocals,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (pemohonsRefs)
                        await $_getPrefetchedData<
                          JenisKelamin,
                          $JenisKelaminsTable,
                          Pemohon
                        >(
                          currentTable: table,
                          referencedTable: $$JenisKelaminsTableReferences
                              ._pemohonsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$JenisKelaminsTableReferences(
                                db,
                                table,
                                p0,
                              ).pemohonsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.jenisKelamin == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (petugasLocalsRefs)
                        await $_getPrefetchedData<
                          JenisKelamin,
                          $JenisKelaminsTable,
                          PetugasLocal
                        >(
                          currentTable: table,
                          referencedTable: $$JenisKelaminsTableReferences
                              ._petugasLocalsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$JenisKelaminsTableReferences(
                                db,
                                table,
                                p0,
                              ).petugasLocalsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.jenisKelamin == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$JenisKelaminsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $JenisKelaminsTable,
      JenisKelamin,
      $$JenisKelaminsTableFilterComposer,
      $$JenisKelaminsTableOrderingComposer,
      $$JenisKelaminsTableAnnotationComposer,
      $$JenisKelaminsTableCreateCompanionBuilder,
      $$JenisKelaminsTableUpdateCompanionBuilder,
      (JenisKelamin, $$JenisKelaminsTableReferences),
      JenisKelamin,
      PrefetchHooks Function({bool pemohonsRefs, bool petugasLocalsRefs})
    >;
typedef $$PemohonsTableCreateCompanionBuilder = PemohonsCompanion Function({
  Value<int> id,
  required String uuid,
  required String nama,
  Value<String?> alamat,
  Value<int?> jenisKelamin,
  Value<String?> noTelp,
  Value<String?> nik,
  Value<int?> createdBy,
  Value<int?> updatedBy,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
  Value<int> status,
  Value<bool> isSyncDirty,
  Value<DateTime?> lastSyncedAt,
  Value<DateTime?> deletedAt,
});
typedef $$PemohonsTableUpdateCompanionBuilder = PemohonsCompanion Function({
  Value<int> id,
  Value<String> uuid,
  Value<String> nama,
  Value<String?> alamat,
  Value<int?> jenisKelamin,
  Value<String?> noTelp,
  Value<String?> nik,
  Value<int?> createdBy,
  Value<int?> updatedBy,
  Value<DateTime?> createdAt,
  Value<DateTime?> updatedAt,
  Value<int> status,
  Value<bool> isSyncDirty,
  Value<DateTime?> lastSyncedAt,
  Value<DateTime?> deletedAt,
});

final class $$PemohonsTableReferences
    extends BaseReferences<_$AppDatabase, $PemohonsTable, Pemohon> {
  $$PemohonsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $JenisKelaminsTable _jenisKelaminTable(_$AppDatabase db) => db
      .jenisKelamins
      .createAlias('pemohons__jenis_kelamin__jenis_kelamin__id');

  $$JenisKelaminsTableProcessedTableManager? get jenisKelamin {
    final $_column = $_itemColumn<int>('jenis_kelamin');
    if ($_column == null) return null;
    final manager = $$JenisKelaminsTableTableManager(
      $_db,
      $_db.jenisKelamins,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_jenisKelaminTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

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

  ColumnFilters<String> get noTelp => $composableBuilder(
    column: $table.noTelp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nik => $composableBuilder(
    column: $table.nik,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
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

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$JenisKelaminsTableFilterComposer get jenisKelamin {
    final $$JenisKelaminsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.jenisKelamin,
      referencedTable: $db.jenisKelamins,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$JenisKelaminsTableFilterComposer(
            $db: $db,
            $table: $db.jenisKelamins,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
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

  ColumnOrderings<String> get noTelp => $composableBuilder(
    column: $table.noTelp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nik => $composableBuilder(
    column: $table.nik,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
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

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$JenisKelaminsTableOrderingComposer get jenisKelamin {
    final $$JenisKelaminsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.jenisKelamin,
      referencedTable: $db.jenisKelamins,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$JenisKelaminsTableOrderingComposer(
            $db: $db,
            $table: $db.jenisKelamins,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
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

  GeneratedColumn<String> get noTelp =>
      $composableBuilder(column: $table.noTelp, builder: (column) => column);

  GeneratedColumn<String> get nik =>
      $composableBuilder(column: $table.nik, builder: (column) => column);

  GeneratedColumn<int> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<int> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get isSyncDirty => $composableBuilder(
    column: $table.isSyncDirty,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$JenisKelaminsTableAnnotationComposer get jenisKelamin {
    final $$JenisKelaminsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.jenisKelamin,
      referencedTable: $db.jenisKelamins,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$JenisKelaminsTableAnnotationComposer(
            $db: $db,
            $table: $db.jenisKelamins,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
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
          (Pemohon, $$PemohonsTableReferences),
          Pemohon,
          PrefetchHooks Function({bool jenisKelamin})
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
                Value<int?> jenisKelamin = const Value.absent(),
                Value<String?> noTelp = const Value.absent(),
                Value<String?> nik = const Value.absent(),
                Value<int?> createdBy = const Value.absent(),
                Value<int?> updatedBy = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<bool> isSyncDirty = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => PemohonsCompanion(
                id: id,
                uuid: uuid,
                nama: nama,
                alamat: alamat,
                jenisKelamin: jenisKelamin,
                noTelp: noTelp,
                nik: nik,
                createdBy: createdBy,
                updatedBy: updatedBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                status: status,
                isSyncDirty: isSyncDirty,
                lastSyncedAt: lastSyncedAt,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uuid,
                required String nama,
                Value<String?> alamat = const Value.absent(),
                Value<int?> jenisKelamin = const Value.absent(),
                Value<String?> noTelp = const Value.absent(),
                Value<String?> nik = const Value.absent(),
                Value<int?> createdBy = const Value.absent(),
                Value<int?> updatedBy = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<bool> isSyncDirty = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => PemohonsCompanion.insert(
                id: id,
                uuid: uuid,
                nama: nama,
                alamat: alamat,
                jenisKelamin: jenisKelamin,
                noTelp: noTelp,
                nik: nik,
                createdBy: createdBy,
                updatedBy: updatedBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                status: status,
                isSyncDirty: isSyncDirty,
                lastSyncedAt: lastSyncedAt,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PemohonsTable, Pemohon>(table),
                  $$PemohonsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({jenisKelamin = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (jenisKelamin) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.jenisKelamin,
                        referencedTable: $$PemohonsTableReferences
                            ._jenisKelaminTable(db),
                        referencedColumn: $$PemohonsTableReferences
                            ._jenisKelaminTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
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
      (Pemohon, $$PemohonsTableReferences),
      Pemohon,
      PrefetchHooks Function({bool jenisKelamin})
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
typedef $$PekerjaanKategorisTableCreateCompanionBuilder =
    PekerjaanKategorisCompanion Function({
      Value<int> id,
      required String uuid,
      required String nama,
      Value<int?> createdBy,
      Value<int?> updatedBy,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> status,
      Value<bool> isSyncDirty,
      Value<DateTime?> lastSyncedAt,
      Value<DateTime?> deletedAt,
    });
typedef $$PekerjaanKategorisTableUpdateCompanionBuilder =
    PekerjaanKategorisCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<String> nama,
      Value<int?> createdBy,
      Value<int?> updatedBy,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> status,
      Value<bool> isSyncDirty,
      Value<DateTime?> lastSyncedAt,
      Value<DateTime?> deletedAt,
    });

final class $$PekerjaanKategorisTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $PekerjaanKategorisTable,
          PekerjaanKategori
        > {
  $$PekerjaanKategorisTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $PekerjaanNotarisHargaLocalsTable,
    List<PekerjaanNotarisHargaLocal>
  >
  _pekerjaanNotarisHargaLocalsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.pekerjaanNotarisHargaLocals,
        aliasName: 'pekerjaan_kategori__id__pekerjaan_notaris_harga__kategori_pekerjaan_id',
      );

  $$PekerjaanNotarisHargaLocalsTableProcessedTableManager
  get pekerjaanNotarisHargaLocalsRefs {
    final manager =
        $$PekerjaanNotarisHargaLocalsTableTableManager(
          $_db,
          $_db.pekerjaanNotarisHargaLocals,
        ).filter(
          (f) => f.kategoriPekerjaanId.id.sqlEquals($_itemColumn<int>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _pekerjaanNotarisHargaLocalsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $PekerjaanPpatHargaLocalsTable,
    List<PekerjaanPpatHargaLocal>
  >
  _pekerjaanPpatHargaLocalsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.pekerjaanPpatHargaLocals,
    aliasName:
        'pekerjaan_kategori__id__pekerjaan_ppat_harga__kategori_pekerjaan_id',
  );

  $$PekerjaanPpatHargaLocalsTableProcessedTableManager
  get pekerjaanPpatHargaLocalsRefs {
    final manager =
        $$PekerjaanPpatHargaLocalsTableTableManager(
          $_db,
          $_db.pekerjaanPpatHargaLocals,
        ).filter(
          (f) => f.kategoriPekerjaanId.id.sqlEquals($_itemColumn<int>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _pekerjaanPpatHargaLocalsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PekerjaanKategorisTableFilterComposer
    extends Composer<_$AppDatabase, $PekerjaanKategorisTable> {
  $$PekerjaanKategorisTableFilterComposer({
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

  ColumnFilters<int> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
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

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> pekerjaanNotarisHargaLocalsRefs(
    Expression<bool> Function(
      $$PekerjaanNotarisHargaLocalsTableFilterComposer f,
    )
    f,
  ) {
    final $$PekerjaanNotarisHargaLocalsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.pekerjaanNotarisHargaLocals,
          getReferencedColumn: (t) => t.kategoriPekerjaanId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PekerjaanNotarisHargaLocalsTableFilterComposer(
                $db: $db,
                $table: $db.pekerjaanNotarisHargaLocals,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> pekerjaanPpatHargaLocalsRefs(
    Expression<bool> Function($$PekerjaanPpatHargaLocalsTableFilterComposer f)
    f,
  ) {
    final $$PekerjaanPpatHargaLocalsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.pekerjaanPpatHargaLocals,
          getReferencedColumn: (t) => t.kategoriPekerjaanId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PekerjaanPpatHargaLocalsTableFilterComposer(
                $db: $db,
                $table: $db.pekerjaanPpatHargaLocals,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$PekerjaanKategorisTableOrderingComposer
    extends Composer<_$AppDatabase, $PekerjaanKategorisTable> {
  $$PekerjaanKategorisTableOrderingComposer({
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

  ColumnOrderings<int> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
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

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PekerjaanKategorisTableAnnotationComposer
    extends Composer<_$AppDatabase, $PekerjaanKategorisTable> {
  $$PekerjaanKategorisTableAnnotationComposer({
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

  GeneratedColumn<int> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<int> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get isSyncDirty => $composableBuilder(
    column: $table.isSyncDirty,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  Expression<T> pekerjaanNotarisHargaLocalsRefs<T extends Object>(
    Expression<T> Function(
      $$PekerjaanNotarisHargaLocalsTableAnnotationComposer a,
    )
    f,
  ) {
    final $$PekerjaanNotarisHargaLocalsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.pekerjaanNotarisHargaLocals,
          getReferencedColumn: (t) => t.kategoriPekerjaanId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PekerjaanNotarisHargaLocalsTableAnnotationComposer(
                $db: $db,
                $table: $db.pekerjaanNotarisHargaLocals,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> pekerjaanPpatHargaLocalsRefs<T extends Object>(
    Expression<T> Function($$PekerjaanPpatHargaLocalsTableAnnotationComposer a)
    f,
  ) {
    final $$PekerjaanPpatHargaLocalsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.pekerjaanPpatHargaLocals,
          getReferencedColumn: (t) => t.kategoriPekerjaanId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PekerjaanPpatHargaLocalsTableAnnotationComposer(
                $db: $db,
                $table: $db.pekerjaanPpatHargaLocals,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$PekerjaanKategorisTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PekerjaanKategorisTable,
          PekerjaanKategori,
          $$PekerjaanKategorisTableFilterComposer,
          $$PekerjaanKategorisTableOrderingComposer,
          $$PekerjaanKategorisTableAnnotationComposer,
          $$PekerjaanKategorisTableCreateCompanionBuilder,
          $$PekerjaanKategorisTableUpdateCompanionBuilder,
          (PekerjaanKategori, $$PekerjaanKategorisTableReferences),
          PekerjaanKategori,
          PrefetchHooks Function({
            bool pekerjaanNotarisHargaLocalsRefs,
            bool pekerjaanPpatHargaLocalsRefs,
          })
        > {
  $$PekerjaanKategorisTableTableManager(
    _$AppDatabase db,
    $PekerjaanKategorisTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PekerjaanKategorisTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PekerjaanKategorisTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PekerjaanKategorisTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<String> nama = const Value.absent(),
                Value<int?> createdBy = const Value.absent(),
                Value<int?> updatedBy = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<bool> isSyncDirty = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => PekerjaanKategorisCompanion(
                id: id,
                uuid: uuid,
                nama: nama,
                createdBy: createdBy,
                updatedBy: updatedBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                status: status,
                isSyncDirty: isSyncDirty,
                lastSyncedAt: lastSyncedAt,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uuid,
                required String nama,
                Value<int?> createdBy = const Value.absent(),
                Value<int?> updatedBy = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<bool> isSyncDirty = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => PekerjaanKategorisCompanion.insert(
                id: id,
                uuid: uuid,
                nama: nama,
                createdBy: createdBy,
                updatedBy: updatedBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                status: status,
                isSyncDirty: isSyncDirty,
                lastSyncedAt: lastSyncedAt,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PekerjaanKategorisTable, PekerjaanKategori>(
                    table,
                  ),
                  $$PekerjaanKategorisTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                pekerjaanNotarisHargaLocalsRefs = false,
                pekerjaanPpatHargaLocalsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (pekerjaanNotarisHargaLocalsRefs)
                      db.pekerjaanNotarisHargaLocals,
                    if (pekerjaanPpatHargaLocalsRefs)
                      db.pekerjaanPpatHargaLocals,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (pekerjaanNotarisHargaLocalsRefs)
                        await $_getPrefetchedData<
                          PekerjaanKategori,
                          $PekerjaanKategorisTable,
                          PekerjaanNotarisHargaLocal
                        >(
                          currentTable: table,
                          referencedTable: $$PekerjaanKategorisTableReferences
                              ._pekerjaanNotarisHargaLocalsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PekerjaanKategorisTableReferences(
                                db,
                                table,
                                p0,
                              ).pekerjaanNotarisHargaLocalsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.kategoriPekerjaanId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (pekerjaanPpatHargaLocalsRefs)
                        await $_getPrefetchedData<
                          PekerjaanKategori,
                          $PekerjaanKategorisTable,
                          PekerjaanPpatHargaLocal
                        >(
                          currentTable: table,
                          referencedTable: $$PekerjaanKategorisTableReferences
                              ._pekerjaanPpatHargaLocalsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PekerjaanKategorisTableReferences(
                                db,
                                table,
                                p0,
                              ).pekerjaanPpatHargaLocalsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.kategoriPekerjaanId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PekerjaanKategorisTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PekerjaanKategorisTable,
      PekerjaanKategori,
      $$PekerjaanKategorisTableFilterComposer,
      $$PekerjaanKategorisTableOrderingComposer,
      $$PekerjaanKategorisTableAnnotationComposer,
      $$PekerjaanKategorisTableCreateCompanionBuilder,
      $$PekerjaanKategorisTableUpdateCompanionBuilder,
      (PekerjaanKategori, $$PekerjaanKategorisTableReferences),
      PekerjaanKategori,
      PrefetchHooks Function({
        bool pekerjaanNotarisHargaLocalsRefs,
        bool pekerjaanPpatHargaLocalsRefs,
      })
    >;
typedef $$PengeluaranJenisTableCreateCompanionBuilder =
    PengeluaranJenisCompanion Function({
      Value<int> id,
      required String uuid,
      required String nama,
      Value<int?> createdBy,
      Value<int?> updatedBy,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> status,
      Value<bool> isSyncDirty,
      Value<DateTime?> lastSyncedAt,
      Value<DateTime?> deletedAt,
    });
typedef $$PengeluaranJenisTableUpdateCompanionBuilder =
    PengeluaranJenisCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<String> nama,
      Value<int?> createdBy,
      Value<int?> updatedBy,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> status,
      Value<bool> isSyncDirty,
      Value<DateTime?> lastSyncedAt,
      Value<DateTime?> deletedAt,
    });

class $$PengeluaranJenisTableFilterComposer
    extends Composer<_$AppDatabase, $PengeluaranJenisTable> {
  $$PengeluaranJenisTableFilterComposer({
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

  ColumnFilters<int> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
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

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PengeluaranJenisTableOrderingComposer
    extends Composer<_$AppDatabase, $PengeluaranJenisTable> {
  $$PengeluaranJenisTableOrderingComposer({
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

  ColumnOrderings<int> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
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

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PengeluaranJenisTableAnnotationComposer
    extends Composer<_$AppDatabase, $PengeluaranJenisTable> {
  $$PengeluaranJenisTableAnnotationComposer({
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

  GeneratedColumn<int> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<int> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get isSyncDirty => $composableBuilder(
    column: $table.isSyncDirty,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$PengeluaranJenisTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PengeluaranJenisTable,
          PengeluaranJenisData,
          $$PengeluaranJenisTableFilterComposer,
          $$PengeluaranJenisTableOrderingComposer,
          $$PengeluaranJenisTableAnnotationComposer,
          $$PengeluaranJenisTableCreateCompanionBuilder,
          $$PengeluaranJenisTableUpdateCompanionBuilder,
          (
            PengeluaranJenisData,
            BaseReferences<
              _$AppDatabase,
              $PengeluaranJenisTable,
              PengeluaranJenisData
            >,
          ),
          PengeluaranJenisData,
          PrefetchHooks Function()
        > {
  $$PengeluaranJenisTableTableManager(
    _$AppDatabase db,
    $PengeluaranJenisTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PengeluaranJenisTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PengeluaranJenisTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PengeluaranJenisTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<String> nama = const Value.absent(),
                Value<int?> createdBy = const Value.absent(),
                Value<int?> updatedBy = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<bool> isSyncDirty = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => PengeluaranJenisCompanion(
                id: id,
                uuid: uuid,
                nama: nama,
                createdBy: createdBy,
                updatedBy: updatedBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                status: status,
                isSyncDirty: isSyncDirty,
                lastSyncedAt: lastSyncedAt,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uuid,
                required String nama,
                Value<int?> createdBy = const Value.absent(),
                Value<int?> updatedBy = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<bool> isSyncDirty = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => PengeluaranJenisCompanion.insert(
                id: id,
                uuid: uuid,
                nama: nama,
                createdBy: createdBy,
                updatedBy: updatedBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                status: status,
                isSyncDirty: isSyncDirty,
                lastSyncedAt: lastSyncedAt,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PengeluaranJenisTable, PengeluaranJenisData>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $PengeluaranJenisTable,
                    PengeluaranJenisData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PengeluaranJenisTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PengeluaranJenisTable,
      PengeluaranJenisData,
      $$PengeluaranJenisTableFilterComposer,
      $$PengeluaranJenisTableOrderingComposer,
      $$PengeluaranJenisTableAnnotationComposer,
      $$PengeluaranJenisTableCreateCompanionBuilder,
      $$PengeluaranJenisTableUpdateCompanionBuilder,
      (
        PengeluaranJenisData,
        BaseReferences<
          _$AppDatabase,
          $PengeluaranJenisTable,
          PengeluaranJenisData
        >,
      ),
      PengeluaranJenisData,
      PrefetchHooks Function()
    >;
typedef $$PetugasLocalsTableCreateCompanionBuilder =
    PetugasLocalsCompanion Function({
      Value<int> id,
      required String uuid,
      Value<String?> nik,
      required String nama,
      Value<String?> alamat,
      Value<String?> tempatLahir,
      Value<DateTime?> tanggalLahir,
      Value<int?> jenisKelamin,
      Value<String?> noTelp,
      required String email,
      Value<int?> userId,
      Value<int?> createdBy,
      Value<int?> updatedBy,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> status,
      Value<bool> isSyncDirty,
      Value<DateTime?> lastSyncedAt,
      Value<DateTime?> deletedAt,
    });
typedef $$PetugasLocalsTableUpdateCompanionBuilder =
    PetugasLocalsCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<String?> nik,
      Value<String> nama,
      Value<String?> alamat,
      Value<String?> tempatLahir,
      Value<DateTime?> tanggalLahir,
      Value<int?> jenisKelamin,
      Value<String?> noTelp,
      Value<String> email,
      Value<int?> userId,
      Value<int?> createdBy,
      Value<int?> updatedBy,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> status,
      Value<bool> isSyncDirty,
      Value<DateTime?> lastSyncedAt,
      Value<DateTime?> deletedAt,
    });

final class $$PetugasLocalsTableReferences
    extends BaseReferences<_$AppDatabase, $PetugasLocalsTable, PetugasLocal> {
  $$PetugasLocalsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $JenisKelaminsTable _jenisKelaminTable(_$AppDatabase db) =>
      db.jenisKelamins.createAlias('petugas__jenis_kelamin__jenis_kelamin__id');

  $$JenisKelaminsTableProcessedTableManager? get jenisKelamin {
    final $_column = $_itemColumn<int>('jenis_kelamin');
    if ($_column == null) return null;
    final manager = $$JenisKelaminsTableTableManager(
      $_db,
      $_db.jenisKelamins,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_jenisKelaminTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PetugasLocalsTableFilterComposer
    extends Composer<_$AppDatabase, $PetugasLocalsTable> {
  $$PetugasLocalsTableFilterComposer({
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

  ColumnFilters<String> get nik => $composableBuilder(
    column: $table.nik,
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

  ColumnFilters<String> get tempatLahir => $composableBuilder(
    column: $table.tempatLahir,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get tanggalLahir => $composableBuilder(
    column: $table.tanggalLahir,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get noTelp => $composableBuilder(
    column: $table.noTelp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
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

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$JenisKelaminsTableFilterComposer get jenisKelamin {
    final $$JenisKelaminsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.jenisKelamin,
      referencedTable: $db.jenisKelamins,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$JenisKelaminsTableFilterComposer(
            $db: $db,
            $table: $db.jenisKelamins,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PetugasLocalsTableOrderingComposer
    extends Composer<_$AppDatabase, $PetugasLocalsTable> {
  $$PetugasLocalsTableOrderingComposer({
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

  ColumnOrderings<String> get nik => $composableBuilder(
    column: $table.nik,
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

  ColumnOrderings<String> get tempatLahir => $composableBuilder(
    column: $table.tempatLahir,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get tanggalLahir => $composableBuilder(
    column: $table.tanggalLahir,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get noTelp => $composableBuilder(
    column: $table.noTelp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
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

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$JenisKelaminsTableOrderingComposer get jenisKelamin {
    final $$JenisKelaminsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.jenisKelamin,
      referencedTable: $db.jenisKelamins,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$JenisKelaminsTableOrderingComposer(
            $db: $db,
            $table: $db.jenisKelamins,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PetugasLocalsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PetugasLocalsTable> {
  $$PetugasLocalsTableAnnotationComposer({
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

  GeneratedColumn<String> get nik =>
      $composableBuilder(column: $table.nik, builder: (column) => column);

  GeneratedColumn<String> get nama =>
      $composableBuilder(column: $table.nama, builder: (column) => column);

  GeneratedColumn<String> get alamat =>
      $composableBuilder(column: $table.alamat, builder: (column) => column);

  GeneratedColumn<String> get tempatLahir => $composableBuilder(
    column: $table.tempatLahir,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get tanggalLahir => $composableBuilder(
    column: $table.tanggalLahir,
    builder: (column) => column,
  );

  GeneratedColumn<String> get noTelp =>
      $composableBuilder(column: $table.noTelp, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<int> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<int> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<int> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get isSyncDirty => $composableBuilder(
    column: $table.isSyncDirty,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$JenisKelaminsTableAnnotationComposer get jenisKelamin {
    final $$JenisKelaminsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.jenisKelamin,
      referencedTable: $db.jenisKelamins,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$JenisKelaminsTableAnnotationComposer(
            $db: $db,
            $table: $db.jenisKelamins,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PetugasLocalsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PetugasLocalsTable,
          PetugasLocal,
          $$PetugasLocalsTableFilterComposer,
          $$PetugasLocalsTableOrderingComposer,
          $$PetugasLocalsTableAnnotationComposer,
          $$PetugasLocalsTableCreateCompanionBuilder,
          $$PetugasLocalsTableUpdateCompanionBuilder,
          (PetugasLocal, $$PetugasLocalsTableReferences),
          PetugasLocal,
          PrefetchHooks Function({bool jenisKelamin})
        > {
  $$PetugasLocalsTableTableManager(_$AppDatabase db, $PetugasLocalsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PetugasLocalsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PetugasLocalsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PetugasLocalsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<String?> nik = const Value.absent(),
                Value<String> nama = const Value.absent(),
                Value<String?> alamat = const Value.absent(),
                Value<String?> tempatLahir = const Value.absent(),
                Value<DateTime?> tanggalLahir = const Value.absent(),
                Value<int?> jenisKelamin = const Value.absent(),
                Value<String?> noTelp = const Value.absent(),
                Value<String> email = const Value.absent(),
                Value<int?> userId = const Value.absent(),
                Value<int?> createdBy = const Value.absent(),
                Value<int?> updatedBy = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<bool> isSyncDirty = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => PetugasLocalsCompanion(
                id: id,
                uuid: uuid,
                nik: nik,
                nama: nama,
                alamat: alamat,
                tempatLahir: tempatLahir,
                tanggalLahir: tanggalLahir,
                jenisKelamin: jenisKelamin,
                noTelp: noTelp,
                email: email,
                userId: userId,
                createdBy: createdBy,
                updatedBy: updatedBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                status: status,
                isSyncDirty: isSyncDirty,
                lastSyncedAt: lastSyncedAt,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uuid,
                Value<String?> nik = const Value.absent(),
                required String nama,
                Value<String?> alamat = const Value.absent(),
                Value<String?> tempatLahir = const Value.absent(),
                Value<DateTime?> tanggalLahir = const Value.absent(),
                Value<int?> jenisKelamin = const Value.absent(),
                Value<String?> noTelp = const Value.absent(),
                required String email,
                Value<int?> userId = const Value.absent(),
                Value<int?> createdBy = const Value.absent(),
                Value<int?> updatedBy = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<bool> isSyncDirty = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => PetugasLocalsCompanion.insert(
                id: id,
                uuid: uuid,
                nik: nik,
                nama: nama,
                alamat: alamat,
                tempatLahir: tempatLahir,
                tanggalLahir: tanggalLahir,
                jenisKelamin: jenisKelamin,
                noTelp: noTelp,
                email: email,
                userId: userId,
                createdBy: createdBy,
                updatedBy: updatedBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                status: status,
                isSyncDirty: isSyncDirty,
                lastSyncedAt: lastSyncedAt,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PetugasLocalsTable, PetugasLocal>(table),
                  $$PetugasLocalsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({jenisKelamin = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (jenisKelamin) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.jenisKelamin,
                        referencedTable: $$PetugasLocalsTableReferences
                            ._jenisKelaminTable(db),
                        referencedColumn: $$PetugasLocalsTableReferences
                            ._jenisKelaminTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PetugasLocalsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PetugasLocalsTable,
      PetugasLocal,
      $$PetugasLocalsTableFilterComposer,
      $$PetugasLocalsTableOrderingComposer,
      $$PetugasLocalsTableAnnotationComposer,
      $$PetugasLocalsTableCreateCompanionBuilder,
      $$PetugasLocalsTableUpdateCompanionBuilder,
      (PetugasLocal, $$PetugasLocalsTableReferences),
      PetugasLocal,
      PrefetchHooks Function({bool jenisKelamin})
    >;
typedef $$PekerjaanNotarisLocalsTableCreateCompanionBuilder =
    PekerjaanNotarisLocalsCompanion Function({
      Value<int> id,
      required String uuid,
      required String nama,
      Value<int?> createdBy,
      Value<int?> updatedBy,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> status,
      Value<bool> isSyncDirty,
      Value<DateTime?> lastSyncedAt,
      Value<DateTime?> deletedAt,
    });
typedef $$PekerjaanNotarisLocalsTableUpdateCompanionBuilder =
    PekerjaanNotarisLocalsCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<String> nama,
      Value<int?> createdBy,
      Value<int?> updatedBy,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> status,
      Value<bool> isSyncDirty,
      Value<DateTime?> lastSyncedAt,
      Value<DateTime?> deletedAt,
    });

final class $$PekerjaanNotarisLocalsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $PekerjaanNotarisLocalsTable,
          PekerjaanNotarisLocal
        > {
  $$PekerjaanNotarisLocalsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $PekerjaanNotarisHargaLocalsTable,
    List<PekerjaanNotarisHargaLocal>
  >
  _pekerjaanNotarisHargaLocalsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.pekerjaanNotarisHargaLocals,
    aliasName:
        'pekerjaan_notaris__id__pekerjaan_notaris_harga__pekerjaan_notaris_id',
  );

  $$PekerjaanNotarisHargaLocalsTableProcessedTableManager
  get pekerjaanNotarisHargaLocalsRefs {
    final manager =
        $$PekerjaanNotarisHargaLocalsTableTableManager(
          $_db,
          $_db.pekerjaanNotarisHargaLocals,
        ).filter(
          (f) => f.pekerjaanNotarisId.id.sqlEquals($_itemColumn<int>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _pekerjaanNotarisHargaLocalsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $PekerjaanNotarisProsesLocalsTable,
    List<PekerjaanNotarisProsesLocal>
  >
  _pekerjaanNotarisProsesLocalsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.pekerjaanNotarisProsesLocals,
    aliasName:
        'pekerjaan_notaris__id__pekerjaan_notaris_proses__pekerjaan_notaris_id',
  );

  $$PekerjaanNotarisProsesLocalsTableProcessedTableManager
  get pekerjaanNotarisProsesLocalsRefs {
    final manager =
        $$PekerjaanNotarisProsesLocalsTableTableManager(
          $_db,
          $_db.pekerjaanNotarisProsesLocals,
        ).filter(
          (f) => f.pekerjaanNotarisId.id.sqlEquals($_itemColumn<int>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _pekerjaanNotarisProsesLocalsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $PekerjaanNotarisAtributLocalsTable,
    List<PekerjaanNotarisAtributLocal>
  >
  _pekerjaanNotarisAtributLocalsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.pekerjaanNotarisAtributLocals,
        aliasName: 'pekerjaan_notaris__id__pekerjaan_notaris_atributs__pekerjaan_notaris_id',
      );

  $$PekerjaanNotarisAtributLocalsTableProcessedTableManager
  get pekerjaanNotarisAtributLocalsRefs {
    final manager =
        $$PekerjaanNotarisAtributLocalsTableTableManager(
          $_db,
          $_db.pekerjaanNotarisAtributLocals,
        ).filter(
          (f) => f.pekerjaanNotarisId.id.sqlEquals($_itemColumn<int>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _pekerjaanNotarisAtributLocalsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PekerjaanNotarisLocalsTableFilterComposer
    extends Composer<_$AppDatabase, $PekerjaanNotarisLocalsTable> {
  $$PekerjaanNotarisLocalsTableFilterComposer({
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

  ColumnFilters<int> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
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

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> pekerjaanNotarisHargaLocalsRefs(
    Expression<bool> Function(
      $$PekerjaanNotarisHargaLocalsTableFilterComposer f,
    )
    f,
  ) {
    final $$PekerjaanNotarisHargaLocalsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.pekerjaanNotarisHargaLocals,
          getReferencedColumn: (t) => t.pekerjaanNotarisId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PekerjaanNotarisHargaLocalsTableFilterComposer(
                $db: $db,
                $table: $db.pekerjaanNotarisHargaLocals,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> pekerjaanNotarisProsesLocalsRefs(
    Expression<bool> Function(
      $$PekerjaanNotarisProsesLocalsTableFilterComposer f,
    )
    f,
  ) {
    final $$PekerjaanNotarisProsesLocalsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.pekerjaanNotarisProsesLocals,
          getReferencedColumn: (t) => t.pekerjaanNotarisId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PekerjaanNotarisProsesLocalsTableFilterComposer(
                $db: $db,
                $table: $db.pekerjaanNotarisProsesLocals,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> pekerjaanNotarisAtributLocalsRefs(
    Expression<bool> Function(
      $$PekerjaanNotarisAtributLocalsTableFilterComposer f,
    )
    f,
  ) {
    final $$PekerjaanNotarisAtributLocalsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.pekerjaanNotarisAtributLocals,
          getReferencedColumn: (t) => t.pekerjaanNotarisId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PekerjaanNotarisAtributLocalsTableFilterComposer(
                $db: $db,
                $table: $db.pekerjaanNotarisAtributLocals,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$PekerjaanNotarisLocalsTableOrderingComposer
    extends Composer<_$AppDatabase, $PekerjaanNotarisLocalsTable> {
  $$PekerjaanNotarisLocalsTableOrderingComposer({
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

  ColumnOrderings<int> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
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

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PekerjaanNotarisLocalsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PekerjaanNotarisLocalsTable> {
  $$PekerjaanNotarisLocalsTableAnnotationComposer({
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

  GeneratedColumn<int> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<int> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get isSyncDirty => $composableBuilder(
    column: $table.isSyncDirty,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  Expression<T> pekerjaanNotarisHargaLocalsRefs<T extends Object>(
    Expression<T> Function(
      $$PekerjaanNotarisHargaLocalsTableAnnotationComposer a,
    )
    f,
  ) {
    final $$PekerjaanNotarisHargaLocalsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.pekerjaanNotarisHargaLocals,
          getReferencedColumn: (t) => t.pekerjaanNotarisId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PekerjaanNotarisHargaLocalsTableAnnotationComposer(
                $db: $db,
                $table: $db.pekerjaanNotarisHargaLocals,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> pekerjaanNotarisProsesLocalsRefs<T extends Object>(
    Expression<T> Function(
      $$PekerjaanNotarisProsesLocalsTableAnnotationComposer a,
    )
    f,
  ) {
    final $$PekerjaanNotarisProsesLocalsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.pekerjaanNotarisProsesLocals,
          getReferencedColumn: (t) => t.pekerjaanNotarisId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PekerjaanNotarisProsesLocalsTableAnnotationComposer(
                $db: $db,
                $table: $db.pekerjaanNotarisProsesLocals,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> pekerjaanNotarisAtributLocalsRefs<T extends Object>(
    Expression<T> Function(
      $$PekerjaanNotarisAtributLocalsTableAnnotationComposer a,
    )
    f,
  ) {
    final $$PekerjaanNotarisAtributLocalsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.pekerjaanNotarisAtributLocals,
          getReferencedColumn: (t) => t.pekerjaanNotarisId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PekerjaanNotarisAtributLocalsTableAnnotationComposer(
                $db: $db,
                $table: $db.pekerjaanNotarisAtributLocals,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$PekerjaanNotarisLocalsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PekerjaanNotarisLocalsTable,
          PekerjaanNotarisLocal,
          $$PekerjaanNotarisLocalsTableFilterComposer,
          $$PekerjaanNotarisLocalsTableOrderingComposer,
          $$PekerjaanNotarisLocalsTableAnnotationComposer,
          $$PekerjaanNotarisLocalsTableCreateCompanionBuilder,
          $$PekerjaanNotarisLocalsTableUpdateCompanionBuilder,
          (PekerjaanNotarisLocal, $$PekerjaanNotarisLocalsTableReferences),
          PekerjaanNotarisLocal,
          PrefetchHooks Function({
            bool pekerjaanNotarisHargaLocalsRefs,
            bool pekerjaanNotarisProsesLocalsRefs,
            bool pekerjaanNotarisAtributLocalsRefs,
          })
        > {
  $$PekerjaanNotarisLocalsTableTableManager(
    _$AppDatabase db,
    $PekerjaanNotarisLocalsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PekerjaanNotarisLocalsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$PekerjaanNotarisLocalsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PekerjaanNotarisLocalsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<String> nama = const Value.absent(),
                Value<int?> createdBy = const Value.absent(),
                Value<int?> updatedBy = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<bool> isSyncDirty = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => PekerjaanNotarisLocalsCompanion(
                id: id,
                uuid: uuid,
                nama: nama,
                createdBy: createdBy,
                updatedBy: updatedBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                status: status,
                isSyncDirty: isSyncDirty,
                lastSyncedAt: lastSyncedAt,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uuid,
                required String nama,
                Value<int?> createdBy = const Value.absent(),
                Value<int?> updatedBy = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<bool> isSyncDirty = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => PekerjaanNotarisLocalsCompanion.insert(
                id: id,
                uuid: uuid,
                nama: nama,
                createdBy: createdBy,
                updatedBy: updatedBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                status: status,
                isSyncDirty: isSyncDirty,
                lastSyncedAt: lastSyncedAt,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $PekerjaanNotarisLocalsTable,
                    PekerjaanNotarisLocal
                  >(table),
                  $$PekerjaanNotarisLocalsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                pekerjaanNotarisHargaLocalsRefs = false,
                pekerjaanNotarisProsesLocalsRefs = false,
                pekerjaanNotarisAtributLocalsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (pekerjaanNotarisHargaLocalsRefs)
                      db.pekerjaanNotarisHargaLocals,
                    if (pekerjaanNotarisProsesLocalsRefs)
                      db.pekerjaanNotarisProsesLocals,
                    if (pekerjaanNotarisAtributLocalsRefs)
                      db.pekerjaanNotarisAtributLocals,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (pekerjaanNotarisHargaLocalsRefs)
                        await $_getPrefetchedData<
                          PekerjaanNotarisLocal,
                          $PekerjaanNotarisLocalsTable,
                          PekerjaanNotarisHargaLocal
                        >(
                          currentTable: table,
                          referencedTable:
                              $$PekerjaanNotarisLocalsTableReferences
                                  ._pekerjaanNotarisHargaLocalsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PekerjaanNotarisLocalsTableReferences(
                                db,
                                table,
                                p0,
                              ).pekerjaanNotarisHargaLocalsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.pekerjaanNotarisId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (pekerjaanNotarisProsesLocalsRefs)
                        await $_getPrefetchedData<
                          PekerjaanNotarisLocal,
                          $PekerjaanNotarisLocalsTable,
                          PekerjaanNotarisProsesLocal
                        >(
                          currentTable: table,
                          referencedTable:
                              $$PekerjaanNotarisLocalsTableReferences
                                  ._pekerjaanNotarisProsesLocalsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PekerjaanNotarisLocalsTableReferences(
                                db,
                                table,
                                p0,
                              ).pekerjaanNotarisProsesLocalsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.pekerjaanNotarisId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (pekerjaanNotarisAtributLocalsRefs)
                        await $_getPrefetchedData<
                          PekerjaanNotarisLocal,
                          $PekerjaanNotarisLocalsTable,
                          PekerjaanNotarisAtributLocal
                        >(
                          currentTable: table,
                          referencedTable:
                              $$PekerjaanNotarisLocalsTableReferences
                                  ._pekerjaanNotarisAtributLocalsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PekerjaanNotarisLocalsTableReferences(
                                db,
                                table,
                                p0,
                              ).pekerjaanNotarisAtributLocalsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.pekerjaanNotarisId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PekerjaanNotarisLocalsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PekerjaanNotarisLocalsTable,
      PekerjaanNotarisLocal,
      $$PekerjaanNotarisLocalsTableFilterComposer,
      $$PekerjaanNotarisLocalsTableOrderingComposer,
      $$PekerjaanNotarisLocalsTableAnnotationComposer,
      $$PekerjaanNotarisLocalsTableCreateCompanionBuilder,
      $$PekerjaanNotarisLocalsTableUpdateCompanionBuilder,
      (PekerjaanNotarisLocal, $$PekerjaanNotarisLocalsTableReferences),
      PekerjaanNotarisLocal,
      PrefetchHooks Function({
        bool pekerjaanNotarisHargaLocalsRefs,
        bool pekerjaanNotarisProsesLocalsRefs,
        bool pekerjaanNotarisAtributLocalsRefs,
      })
    >;
typedef $$PekerjaanNotarisHargaLocalsTableCreateCompanionBuilder =
    PekerjaanNotarisHargaLocalsCompanion Function({
      Value<int> id,
      required String uuid,
      required int pekerjaanNotarisId,
      required String harga,
      required int kategoriPekerjaanId,
      required String estimasiWaktu,
      Value<int?> createdBy,
      Value<int?> updatedBy,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> status,
      Value<bool> isSyncDirty,
      Value<DateTime?> lastSyncedAt,
      Value<DateTime?> deletedAt,
    });
typedef $$PekerjaanNotarisHargaLocalsTableUpdateCompanionBuilder =
    PekerjaanNotarisHargaLocalsCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<int> pekerjaanNotarisId,
      Value<String> harga,
      Value<int> kategoriPekerjaanId,
      Value<String> estimasiWaktu,
      Value<int?> createdBy,
      Value<int?> updatedBy,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> status,
      Value<bool> isSyncDirty,
      Value<DateTime?> lastSyncedAt,
      Value<DateTime?> deletedAt,
    });

final class $$PekerjaanNotarisHargaLocalsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $PekerjaanNotarisHargaLocalsTable,
          PekerjaanNotarisHargaLocal
        > {
  $$PekerjaanNotarisHargaLocalsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PekerjaanNotarisLocalsTable _pekerjaanNotarisIdTable(
    _$AppDatabase db,
  ) => db.pekerjaanNotarisLocals.createAlias(
    'pekerjaan_notaris_harga__pekerjaan_notaris_id__pekerjaan_notaris__id',
  );

  $$PekerjaanNotarisLocalsTableProcessedTableManager get pekerjaanNotarisId {
    final $_column = $_itemColumn<int>('pekerjaan_notaris_id')!;

    final manager = $$PekerjaanNotarisLocalsTableTableManager(
      $_db,
      $_db.pekerjaanNotarisLocals,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_pekerjaanNotarisIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PekerjaanKategorisTable _kategoriPekerjaanIdTable(
    _$AppDatabase db,
  ) => db.pekerjaanKategoris.createAlias(
    'pekerjaan_notaris_harga__kategori_pekerjaan_id__pekerjaan_kategori__id',
  );

  $$PekerjaanKategorisTableProcessedTableManager get kategoriPekerjaanId {
    final $_column = $_itemColumn<int>('kategori_pekerjaan_id')!;

    final manager = $$PekerjaanKategorisTableTableManager(
      $_db,
      $_db.pekerjaanKategoris,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_kategoriPekerjaanIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PekerjaanNotarisHargaLocalsTableFilterComposer
    extends Composer<_$AppDatabase, $PekerjaanNotarisHargaLocalsTable> {
  $$PekerjaanNotarisHargaLocalsTableFilterComposer({
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

  ColumnFilters<String> get harga => $composableBuilder(
    column: $table.harga,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get estimasiWaktu => $composableBuilder(
    column: $table.estimasiWaktu,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
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

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PekerjaanNotarisLocalsTableFilterComposer get pekerjaanNotarisId {
    final $$PekerjaanNotarisLocalsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.pekerjaanNotarisId,
          referencedTable: $db.pekerjaanNotarisLocals,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PekerjaanNotarisLocalsTableFilterComposer(
                $db: $db,
                $table: $db.pekerjaanNotarisLocals,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$PekerjaanKategorisTableFilterComposer get kategoriPekerjaanId {
    final $$PekerjaanKategorisTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.kategoriPekerjaanId,
      referencedTable: $db.pekerjaanKategoris,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PekerjaanKategorisTableFilterComposer(
            $db: $db,
            $table: $db.pekerjaanKategoris,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PekerjaanNotarisHargaLocalsTableOrderingComposer
    extends Composer<_$AppDatabase, $PekerjaanNotarisHargaLocalsTable> {
  $$PekerjaanNotarisHargaLocalsTableOrderingComposer({
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

  ColumnOrderings<String> get harga => $composableBuilder(
    column: $table.harga,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get estimasiWaktu => $composableBuilder(
    column: $table.estimasiWaktu,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
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

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PekerjaanNotarisLocalsTableOrderingComposer get pekerjaanNotarisId {
    final $$PekerjaanNotarisLocalsTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.pekerjaanNotarisId,
          referencedTable: $db.pekerjaanNotarisLocals,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PekerjaanNotarisLocalsTableOrderingComposer(
                $db: $db,
                $table: $db.pekerjaanNotarisLocals,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$PekerjaanKategorisTableOrderingComposer get kategoriPekerjaanId {
    final $$PekerjaanKategorisTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.kategoriPekerjaanId,
      referencedTable: $db.pekerjaanKategoris,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PekerjaanKategorisTableOrderingComposer(
            $db: $db,
            $table: $db.pekerjaanKategoris,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PekerjaanNotarisHargaLocalsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PekerjaanNotarisHargaLocalsTable> {
  $$PekerjaanNotarisHargaLocalsTableAnnotationComposer({
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

  GeneratedColumn<String> get harga =>
      $composableBuilder(column: $table.harga, builder: (column) => column);

  GeneratedColumn<String> get estimasiWaktu => $composableBuilder(
    column: $table.estimasiWaktu,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<int> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get isSyncDirty => $composableBuilder(
    column: $table.isSyncDirty,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$PekerjaanNotarisLocalsTableAnnotationComposer get pekerjaanNotarisId {
    final $$PekerjaanNotarisLocalsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.pekerjaanNotarisId,
          referencedTable: $db.pekerjaanNotarisLocals,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PekerjaanNotarisLocalsTableAnnotationComposer(
                $db: $db,
                $table: $db.pekerjaanNotarisLocals,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$PekerjaanKategorisTableAnnotationComposer get kategoriPekerjaanId {
    final $$PekerjaanKategorisTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.kategoriPekerjaanId,
          referencedTable: $db.pekerjaanKategoris,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PekerjaanKategorisTableAnnotationComposer(
                $db: $db,
                $table: $db.pekerjaanKategoris,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$PekerjaanNotarisHargaLocalsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PekerjaanNotarisHargaLocalsTable,
          PekerjaanNotarisHargaLocal,
          $$PekerjaanNotarisHargaLocalsTableFilterComposer,
          $$PekerjaanNotarisHargaLocalsTableOrderingComposer,
          $$PekerjaanNotarisHargaLocalsTableAnnotationComposer,
          $$PekerjaanNotarisHargaLocalsTableCreateCompanionBuilder,
          $$PekerjaanNotarisHargaLocalsTableUpdateCompanionBuilder,
          (
            PekerjaanNotarisHargaLocal,
            $$PekerjaanNotarisHargaLocalsTableReferences,
          ),
          PekerjaanNotarisHargaLocal,
          PrefetchHooks Function({
            bool pekerjaanNotarisId,
            bool kategoriPekerjaanId,
          })
        > {
  $$PekerjaanNotarisHargaLocalsTableTableManager(
    _$AppDatabase db,
    $PekerjaanNotarisHargaLocalsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PekerjaanNotarisHargaLocalsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$PekerjaanNotarisHargaLocalsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PekerjaanNotarisHargaLocalsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<int> pekerjaanNotarisId = const Value.absent(),
                Value<String> harga = const Value.absent(),
                Value<int> kategoriPekerjaanId = const Value.absent(),
                Value<String> estimasiWaktu = const Value.absent(),
                Value<int?> createdBy = const Value.absent(),
                Value<int?> updatedBy = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<bool> isSyncDirty = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => PekerjaanNotarisHargaLocalsCompanion(
                id: id,
                uuid: uuid,
                pekerjaanNotarisId: pekerjaanNotarisId,
                harga: harga,
                kategoriPekerjaanId: kategoriPekerjaanId,
                estimasiWaktu: estimasiWaktu,
                createdBy: createdBy,
                updatedBy: updatedBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                status: status,
                isSyncDirty: isSyncDirty,
                lastSyncedAt: lastSyncedAt,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uuid,
                required int pekerjaanNotarisId,
                required String harga,
                required int kategoriPekerjaanId,
                required String estimasiWaktu,
                Value<int?> createdBy = const Value.absent(),
                Value<int?> updatedBy = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<bool> isSyncDirty = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => PekerjaanNotarisHargaLocalsCompanion.insert(
                id: id,
                uuid: uuid,
                pekerjaanNotarisId: pekerjaanNotarisId,
                harga: harga,
                kategoriPekerjaanId: kategoriPekerjaanId,
                estimasiWaktu: estimasiWaktu,
                createdBy: createdBy,
                updatedBy: updatedBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                status: status,
                isSyncDirty: isSyncDirty,
                lastSyncedAt: lastSyncedAt,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $PekerjaanNotarisHargaLocalsTable,
                    PekerjaanNotarisHargaLocal
                  >(table),
                  $$PekerjaanNotarisHargaLocalsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({pekerjaanNotarisId = false, kategoriPekerjaanId = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (pekerjaanNotarisId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.pekerjaanNotarisId,
                            referencedTable:
                                $$PekerjaanNotarisHargaLocalsTableReferences
                                    ._pekerjaanNotarisIdTable(db),
                            referencedColumn:
                                $$PekerjaanNotarisHargaLocalsTableReferences
                                    ._pekerjaanNotarisIdTable(db)
                                    .id,
                          ) as T;
                        }
                        if (kategoriPekerjaanId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.kategoriPekerjaanId,
                            referencedTable:
                                $$PekerjaanNotarisHargaLocalsTableReferences
                                    ._kategoriPekerjaanIdTable(db),
                            referencedColumn:
                                $$PekerjaanNotarisHargaLocalsTableReferences
                                    ._kategoriPekerjaanIdTable(db)
                                    .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$PekerjaanNotarisHargaLocalsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PekerjaanNotarisHargaLocalsTable,
      PekerjaanNotarisHargaLocal,
      $$PekerjaanNotarisHargaLocalsTableFilterComposer,
      $$PekerjaanNotarisHargaLocalsTableOrderingComposer,
      $$PekerjaanNotarisHargaLocalsTableAnnotationComposer,
      $$PekerjaanNotarisHargaLocalsTableCreateCompanionBuilder,
      $$PekerjaanNotarisHargaLocalsTableUpdateCompanionBuilder,
      (
        PekerjaanNotarisHargaLocal,
        $$PekerjaanNotarisHargaLocalsTableReferences,
      ),
      PekerjaanNotarisHargaLocal,
      PrefetchHooks Function({
        bool pekerjaanNotarisId,
        bool kategoriPekerjaanId,
      })
    >;
typedef $$PekerjaanNotarisProsesLocalsTableCreateCompanionBuilder =
    PekerjaanNotarisProsesLocalsCompanion Function({
      Value<int> id,
      required String uuid,
      required int pekerjaanNotarisId,
      required String nama,
      required String detail,
      Value<int?> createdBy,
      Value<int?> updatedBy,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> status,
      Value<bool> isSyncDirty,
      Value<DateTime?> lastSyncedAt,
      Value<DateTime?> deletedAt,
    });
typedef $$PekerjaanNotarisProsesLocalsTableUpdateCompanionBuilder =
    PekerjaanNotarisProsesLocalsCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<int> pekerjaanNotarisId,
      Value<String> nama,
      Value<String> detail,
      Value<int?> createdBy,
      Value<int?> updatedBy,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> status,
      Value<bool> isSyncDirty,
      Value<DateTime?> lastSyncedAt,
      Value<DateTime?> deletedAt,
    });

final class $$PekerjaanNotarisProsesLocalsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $PekerjaanNotarisProsesLocalsTable,
          PekerjaanNotarisProsesLocal
        > {
  $$PekerjaanNotarisProsesLocalsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PekerjaanNotarisLocalsTable _pekerjaanNotarisIdTable(
    _$AppDatabase db,
  ) => db.pekerjaanNotarisLocals.createAlias(
    'pekerjaan_notaris_proses__pekerjaan_notaris_id__pekerjaan_notaris__id',
  );

  $$PekerjaanNotarisLocalsTableProcessedTableManager get pekerjaanNotarisId {
    final $_column = $_itemColumn<int>('pekerjaan_notaris_id')!;

    final manager = $$PekerjaanNotarisLocalsTableTableManager(
      $_db,
      $_db.pekerjaanNotarisLocals,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_pekerjaanNotarisIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $PekerjaanNotarisAtributLocalsTable,
    List<PekerjaanNotarisAtributLocal>
  >
  _pekerjaanNotarisAtributLocalsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.pekerjaanNotarisAtributLocals,
        aliasName: 'pekerjaan_notaris_proses__id__pekerjaan_notaris_atributs__proses_pekerjaan_notaris_id',
      );

  $$PekerjaanNotarisAtributLocalsTableProcessedTableManager
  get pekerjaanNotarisAtributLocalsRefs {
    final manager =
        $$PekerjaanNotarisAtributLocalsTableTableManager(
          $_db,
          $_db.pekerjaanNotarisAtributLocals,
        ).filter(
          (f) =>
              f.prosesPekerjaanNotarisId.id.sqlEquals($_itemColumn<int>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _pekerjaanNotarisAtributLocalsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PekerjaanNotarisProsesLocalsTableFilterComposer
    extends Composer<_$AppDatabase, $PekerjaanNotarisProsesLocalsTable> {
  $$PekerjaanNotarisProsesLocalsTableFilterComposer({
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

  ColumnFilters<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
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

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PekerjaanNotarisLocalsTableFilterComposer get pekerjaanNotarisId {
    final $$PekerjaanNotarisLocalsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.pekerjaanNotarisId,
          referencedTable: $db.pekerjaanNotarisLocals,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PekerjaanNotarisLocalsTableFilterComposer(
                $db: $db,
                $table: $db.pekerjaanNotarisLocals,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  Expression<bool> pekerjaanNotarisAtributLocalsRefs(
    Expression<bool> Function(
      $$PekerjaanNotarisAtributLocalsTableFilterComposer f,
    )
    f,
  ) {
    final $$PekerjaanNotarisAtributLocalsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.pekerjaanNotarisAtributLocals,
          getReferencedColumn: (t) => t.prosesPekerjaanNotarisId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PekerjaanNotarisAtributLocalsTableFilterComposer(
                $db: $db,
                $table: $db.pekerjaanNotarisAtributLocals,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$PekerjaanNotarisProsesLocalsTableOrderingComposer
    extends Composer<_$AppDatabase, $PekerjaanNotarisProsesLocalsTable> {
  $$PekerjaanNotarisProsesLocalsTableOrderingComposer({
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

  ColumnOrderings<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
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

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PekerjaanNotarisLocalsTableOrderingComposer get pekerjaanNotarisId {
    final $$PekerjaanNotarisLocalsTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.pekerjaanNotarisId,
          referencedTable: $db.pekerjaanNotarisLocals,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PekerjaanNotarisLocalsTableOrderingComposer(
                $db: $db,
                $table: $db.pekerjaanNotarisLocals,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$PekerjaanNotarisProsesLocalsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PekerjaanNotarisProsesLocalsTable> {
  $$PekerjaanNotarisProsesLocalsTableAnnotationComposer({
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

  GeneratedColumn<String> get detail =>
      $composableBuilder(column: $table.detail, builder: (column) => column);

  GeneratedColumn<int> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<int> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get isSyncDirty => $composableBuilder(
    column: $table.isSyncDirty,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$PekerjaanNotarisLocalsTableAnnotationComposer get pekerjaanNotarisId {
    final $$PekerjaanNotarisLocalsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.pekerjaanNotarisId,
          referencedTable: $db.pekerjaanNotarisLocals,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PekerjaanNotarisLocalsTableAnnotationComposer(
                $db: $db,
                $table: $db.pekerjaanNotarisLocals,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  Expression<T> pekerjaanNotarisAtributLocalsRefs<T extends Object>(
    Expression<T> Function(
      $$PekerjaanNotarisAtributLocalsTableAnnotationComposer a,
    )
    f,
  ) {
    final $$PekerjaanNotarisAtributLocalsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.pekerjaanNotarisAtributLocals,
          getReferencedColumn: (t) => t.prosesPekerjaanNotarisId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PekerjaanNotarisAtributLocalsTableAnnotationComposer(
                $db: $db,
                $table: $db.pekerjaanNotarisAtributLocals,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$PekerjaanNotarisProsesLocalsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PekerjaanNotarisProsesLocalsTable,
          PekerjaanNotarisProsesLocal,
          $$PekerjaanNotarisProsesLocalsTableFilterComposer,
          $$PekerjaanNotarisProsesLocalsTableOrderingComposer,
          $$PekerjaanNotarisProsesLocalsTableAnnotationComposer,
          $$PekerjaanNotarisProsesLocalsTableCreateCompanionBuilder,
          $$PekerjaanNotarisProsesLocalsTableUpdateCompanionBuilder,
          (
            PekerjaanNotarisProsesLocal,
            $$PekerjaanNotarisProsesLocalsTableReferences,
          ),
          PekerjaanNotarisProsesLocal,
          PrefetchHooks Function({
            bool pekerjaanNotarisId,
            bool pekerjaanNotarisAtributLocalsRefs,
          })
        > {
  $$PekerjaanNotarisProsesLocalsTableTableManager(
    _$AppDatabase db,
    $PekerjaanNotarisProsesLocalsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PekerjaanNotarisProsesLocalsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$PekerjaanNotarisProsesLocalsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PekerjaanNotarisProsesLocalsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<int> pekerjaanNotarisId = const Value.absent(),
                Value<String> nama = const Value.absent(),
                Value<String> detail = const Value.absent(),
                Value<int?> createdBy = const Value.absent(),
                Value<int?> updatedBy = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<bool> isSyncDirty = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => PekerjaanNotarisProsesLocalsCompanion(
                id: id,
                uuid: uuid,
                pekerjaanNotarisId: pekerjaanNotarisId,
                nama: nama,
                detail: detail,
                createdBy: createdBy,
                updatedBy: updatedBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                status: status,
                isSyncDirty: isSyncDirty,
                lastSyncedAt: lastSyncedAt,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uuid,
                required int pekerjaanNotarisId,
                required String nama,
                required String detail,
                Value<int?> createdBy = const Value.absent(),
                Value<int?> updatedBy = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<bool> isSyncDirty = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => PekerjaanNotarisProsesLocalsCompanion.insert(
                id: id,
                uuid: uuid,
                pekerjaanNotarisId: pekerjaanNotarisId,
                nama: nama,
                detail: detail,
                createdBy: createdBy,
                updatedBy: updatedBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                status: status,
                isSyncDirty: isSyncDirty,
                lastSyncedAt: lastSyncedAt,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $PekerjaanNotarisProsesLocalsTable,
                    PekerjaanNotarisProsesLocal
                  >(table),
                  $$PekerjaanNotarisProsesLocalsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                pekerjaanNotarisId = false,
                pekerjaanNotarisAtributLocalsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (pekerjaanNotarisAtributLocalsRefs)
                      db.pekerjaanNotarisAtributLocals,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (pekerjaanNotarisId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.pekerjaanNotarisId,
                            referencedTable:
                                $$PekerjaanNotarisProsesLocalsTableReferences
                                    ._pekerjaanNotarisIdTable(db),
                            referencedColumn:
                                $$PekerjaanNotarisProsesLocalsTableReferences
                                    ._pekerjaanNotarisIdTable(db)
                                    .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (pekerjaanNotarisAtributLocalsRefs)
                        await $_getPrefetchedData<
                          PekerjaanNotarisProsesLocal,
                          $PekerjaanNotarisProsesLocalsTable,
                          PekerjaanNotarisAtributLocal
                        >(
                          currentTable: table,
                          referencedTable:
                              $$PekerjaanNotarisProsesLocalsTableReferences
                                  ._pekerjaanNotarisAtributLocalsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PekerjaanNotarisProsesLocalsTableReferences(
                                db,
                                table,
                                p0,
                              ).pekerjaanNotarisAtributLocalsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.prosesPekerjaanNotarisId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PekerjaanNotarisProsesLocalsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PekerjaanNotarisProsesLocalsTable,
      PekerjaanNotarisProsesLocal,
      $$PekerjaanNotarisProsesLocalsTableFilterComposer,
      $$PekerjaanNotarisProsesLocalsTableOrderingComposer,
      $$PekerjaanNotarisProsesLocalsTableAnnotationComposer,
      $$PekerjaanNotarisProsesLocalsTableCreateCompanionBuilder,
      $$PekerjaanNotarisProsesLocalsTableUpdateCompanionBuilder,
      (
        PekerjaanNotarisProsesLocal,
        $$PekerjaanNotarisProsesLocalsTableReferences,
      ),
      PekerjaanNotarisProsesLocal,
      PrefetchHooks Function({
        bool pekerjaanNotarisId,
        bool pekerjaanNotarisAtributLocalsRefs,
      })
    >;
typedef $$PekerjaanNotarisAtributLocalsTableCreateCompanionBuilder =
    PekerjaanNotarisAtributLocalsCompanion Function({
      Value<int> id,
      required String uuid,
      required int pekerjaanNotarisId,
      required int prosesPekerjaanNotarisId,
      Value<String?> atribut,
      Value<int?> createdBy,
      Value<int?> updatedBy,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> status,
      Value<bool> isSyncDirty,
      Value<DateTime?> lastSyncedAt,
      Value<DateTime?> deletedAt,
    });
typedef $$PekerjaanNotarisAtributLocalsTableUpdateCompanionBuilder =
    PekerjaanNotarisAtributLocalsCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<int> pekerjaanNotarisId,
      Value<int> prosesPekerjaanNotarisId,
      Value<String?> atribut,
      Value<int?> createdBy,
      Value<int?> updatedBy,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> status,
      Value<bool> isSyncDirty,
      Value<DateTime?> lastSyncedAt,
      Value<DateTime?> deletedAt,
    });

final class $$PekerjaanNotarisAtributLocalsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $PekerjaanNotarisAtributLocalsTable,
          PekerjaanNotarisAtributLocal
        > {
  $$PekerjaanNotarisAtributLocalsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PekerjaanNotarisLocalsTable _pekerjaanNotarisIdTable(
    _$AppDatabase db,
  ) => db.pekerjaanNotarisLocals.createAlias(
    'pekerjaan_notaris_atributs__pekerjaan_notaris_id__pekerjaan_notaris__id',
  );

  $$PekerjaanNotarisLocalsTableProcessedTableManager get pekerjaanNotarisId {
    final $_column = $_itemColumn<int>('pekerjaan_notaris_id')!;

    final manager = $$PekerjaanNotarisLocalsTableTableManager(
      $_db,
      $_db.pekerjaanNotarisLocals,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_pekerjaanNotarisIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PekerjaanNotarisProsesLocalsTable _prosesPekerjaanNotarisIdTable(
    _$AppDatabase db,
  ) => db.pekerjaanNotarisProsesLocals.createAlias(
    'pekerjaan_notaris_atributs__proses_pekerjaan_notaris_id__pekerjaan_notaris_proses__id',
  );

  $$PekerjaanNotarisProsesLocalsTableProcessedTableManager
  get prosesPekerjaanNotarisId {
    final $_column = $_itemColumn<int>('proses_pekerjaan_notaris_id')!;

    final manager = $$PekerjaanNotarisProsesLocalsTableTableManager(
      $_db,
      $_db.pekerjaanNotarisProsesLocals,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(
      _prosesPekerjaanNotarisIdTable($_db),
    );
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PekerjaanNotarisAtributLocalsTableFilterComposer
    extends Composer<_$AppDatabase, $PekerjaanNotarisAtributLocalsTable> {
  $$PekerjaanNotarisAtributLocalsTableFilterComposer({
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

  ColumnFilters<String> get atribut => $composableBuilder(
    column: $table.atribut,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
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

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PekerjaanNotarisLocalsTableFilterComposer get pekerjaanNotarisId {
    final $$PekerjaanNotarisLocalsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.pekerjaanNotarisId,
          referencedTable: $db.pekerjaanNotarisLocals,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PekerjaanNotarisLocalsTableFilterComposer(
                $db: $db,
                $table: $db.pekerjaanNotarisLocals,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$PekerjaanNotarisProsesLocalsTableFilterComposer
  get prosesPekerjaanNotarisId {
    final $$PekerjaanNotarisProsesLocalsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.prosesPekerjaanNotarisId,
          referencedTable: $db.pekerjaanNotarisProsesLocals,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PekerjaanNotarisProsesLocalsTableFilterComposer(
                $db: $db,
                $table: $db.pekerjaanNotarisProsesLocals,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$PekerjaanNotarisAtributLocalsTableOrderingComposer
    extends Composer<_$AppDatabase, $PekerjaanNotarisAtributLocalsTable> {
  $$PekerjaanNotarisAtributLocalsTableOrderingComposer({
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

  ColumnOrderings<String> get atribut => $composableBuilder(
    column: $table.atribut,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
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

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PekerjaanNotarisLocalsTableOrderingComposer get pekerjaanNotarisId {
    final $$PekerjaanNotarisLocalsTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.pekerjaanNotarisId,
          referencedTable: $db.pekerjaanNotarisLocals,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PekerjaanNotarisLocalsTableOrderingComposer(
                $db: $db,
                $table: $db.pekerjaanNotarisLocals,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$PekerjaanNotarisProsesLocalsTableOrderingComposer
  get prosesPekerjaanNotarisId {
    final $$PekerjaanNotarisProsesLocalsTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.prosesPekerjaanNotarisId,
          referencedTable: $db.pekerjaanNotarisProsesLocals,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PekerjaanNotarisProsesLocalsTableOrderingComposer(
                $db: $db,
                $table: $db.pekerjaanNotarisProsesLocals,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$PekerjaanNotarisAtributLocalsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PekerjaanNotarisAtributLocalsTable> {
  $$PekerjaanNotarisAtributLocalsTableAnnotationComposer({
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

  GeneratedColumn<String> get atribut =>
      $composableBuilder(column: $table.atribut, builder: (column) => column);

  GeneratedColumn<int> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<int> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get isSyncDirty => $composableBuilder(
    column: $table.isSyncDirty,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$PekerjaanNotarisLocalsTableAnnotationComposer get pekerjaanNotarisId {
    final $$PekerjaanNotarisLocalsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.pekerjaanNotarisId,
          referencedTable: $db.pekerjaanNotarisLocals,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PekerjaanNotarisLocalsTableAnnotationComposer(
                $db: $db,
                $table: $db.pekerjaanNotarisLocals,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$PekerjaanNotarisProsesLocalsTableAnnotationComposer
  get prosesPekerjaanNotarisId {
    final $$PekerjaanNotarisProsesLocalsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.prosesPekerjaanNotarisId,
          referencedTable: $db.pekerjaanNotarisProsesLocals,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PekerjaanNotarisProsesLocalsTableAnnotationComposer(
                $db: $db,
                $table: $db.pekerjaanNotarisProsesLocals,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$PekerjaanNotarisAtributLocalsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PekerjaanNotarisAtributLocalsTable,
          PekerjaanNotarisAtributLocal,
          $$PekerjaanNotarisAtributLocalsTableFilterComposer,
          $$PekerjaanNotarisAtributLocalsTableOrderingComposer,
          $$PekerjaanNotarisAtributLocalsTableAnnotationComposer,
          $$PekerjaanNotarisAtributLocalsTableCreateCompanionBuilder,
          $$PekerjaanNotarisAtributLocalsTableUpdateCompanionBuilder,
          (
            PekerjaanNotarisAtributLocal,
            $$PekerjaanNotarisAtributLocalsTableReferences,
          ),
          PekerjaanNotarisAtributLocal,
          PrefetchHooks Function({
            bool pekerjaanNotarisId,
            bool prosesPekerjaanNotarisId,
          })
        > {
  $$PekerjaanNotarisAtributLocalsTableTableManager(
    _$AppDatabase db,
    $PekerjaanNotarisAtributLocalsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PekerjaanNotarisAtributLocalsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$PekerjaanNotarisAtributLocalsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PekerjaanNotarisAtributLocalsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<int> pekerjaanNotarisId = const Value.absent(),
                Value<int> prosesPekerjaanNotarisId = const Value.absent(),
                Value<String?> atribut = const Value.absent(),
                Value<int?> createdBy = const Value.absent(),
                Value<int?> updatedBy = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<bool> isSyncDirty = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => PekerjaanNotarisAtributLocalsCompanion(
                id: id,
                uuid: uuid,
                pekerjaanNotarisId: pekerjaanNotarisId,
                prosesPekerjaanNotarisId: prosesPekerjaanNotarisId,
                atribut: atribut,
                createdBy: createdBy,
                updatedBy: updatedBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                status: status,
                isSyncDirty: isSyncDirty,
                lastSyncedAt: lastSyncedAt,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uuid,
                required int pekerjaanNotarisId,
                required int prosesPekerjaanNotarisId,
                Value<String?> atribut = const Value.absent(),
                Value<int?> createdBy = const Value.absent(),
                Value<int?> updatedBy = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<bool> isSyncDirty = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => PekerjaanNotarisAtributLocalsCompanion.insert(
                id: id,
                uuid: uuid,
                pekerjaanNotarisId: pekerjaanNotarisId,
                prosesPekerjaanNotarisId: prosesPekerjaanNotarisId,
                atribut: atribut,
                createdBy: createdBy,
                updatedBy: updatedBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                status: status,
                isSyncDirty: isSyncDirty,
                lastSyncedAt: lastSyncedAt,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $PekerjaanNotarisAtributLocalsTable,
                    PekerjaanNotarisAtributLocal
                  >(table),
                  $$PekerjaanNotarisAtributLocalsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({pekerjaanNotarisId = false, prosesPekerjaanNotarisId = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (pekerjaanNotarisId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.pekerjaanNotarisId,
                            referencedTable:
                                $$PekerjaanNotarisAtributLocalsTableReferences
                                    ._pekerjaanNotarisIdTable(db),
                            referencedColumn:
                                $$PekerjaanNotarisAtributLocalsTableReferences
                                    ._pekerjaanNotarisIdTable(db)
                                    .id,
                          ) as T;
                        }
                        if (prosesPekerjaanNotarisId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.prosesPekerjaanNotarisId,
                            referencedTable:
                                $$PekerjaanNotarisAtributLocalsTableReferences
                                    ._prosesPekerjaanNotarisIdTable(db),
                            referencedColumn:
                                $$PekerjaanNotarisAtributLocalsTableReferences
                                    ._prosesPekerjaanNotarisIdTable(db)
                                    .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$PekerjaanNotarisAtributLocalsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PekerjaanNotarisAtributLocalsTable,
      PekerjaanNotarisAtributLocal,
      $$PekerjaanNotarisAtributLocalsTableFilterComposer,
      $$PekerjaanNotarisAtributLocalsTableOrderingComposer,
      $$PekerjaanNotarisAtributLocalsTableAnnotationComposer,
      $$PekerjaanNotarisAtributLocalsTableCreateCompanionBuilder,
      $$PekerjaanNotarisAtributLocalsTableUpdateCompanionBuilder,
      (
        PekerjaanNotarisAtributLocal,
        $$PekerjaanNotarisAtributLocalsTableReferences,
      ),
      PekerjaanNotarisAtributLocal,
      PrefetchHooks Function({
        bool pekerjaanNotarisId,
        bool prosesPekerjaanNotarisId,
      })
    >;
typedef $$PekerjaanPpatLocalsTableCreateCompanionBuilder =
    PekerjaanPpatLocalsCompanion Function({
      Value<int> id,
      required String uuid,
      required String nama,
      Value<int?> createdBy,
      Value<int?> updatedBy,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> status,
      Value<bool> isSyncDirty,
      Value<DateTime?> lastSyncedAt,
      Value<DateTime?> deletedAt,
    });
typedef $$PekerjaanPpatLocalsTableUpdateCompanionBuilder =
    PekerjaanPpatLocalsCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<String> nama,
      Value<int?> createdBy,
      Value<int?> updatedBy,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> status,
      Value<bool> isSyncDirty,
      Value<DateTime?> lastSyncedAt,
      Value<DateTime?> deletedAt,
    });

final class $$PekerjaanPpatLocalsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $PekerjaanPpatLocalsTable,
          PekerjaanPpatLocal
        > {
  $$PekerjaanPpatLocalsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $PekerjaanPpatHargaLocalsTable,
    List<PekerjaanPpatHargaLocal>
  >
  _pekerjaanPpatHargaLocalsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.pekerjaanPpatHargaLocals,
        aliasName:
            'pekerjaan_ppat__id__pekerjaan_ppat_harga__pekerjaan_ppat_id',
      );

  $$PekerjaanPpatHargaLocalsTableProcessedTableManager
  get pekerjaanPpatHargaLocalsRefs {
    final manager = $$PekerjaanPpatHargaLocalsTableTableManager(
      $_db,
      $_db.pekerjaanPpatHargaLocals,
    ).filter((f) => f.pekerjaanPpatId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _pekerjaanPpatHargaLocalsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $PekerjaanPpatProsesLocalsTable,
    List<PekerjaanPpatProsesLocal>
  >
  _pekerjaanPpatProsesLocalsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.pekerjaanPpatProsesLocals,
        aliasName:
            'pekerjaan_ppat__id__pekerjaan_ppat_proses__pekerjaan_ppat_id',
      );

  $$PekerjaanPpatProsesLocalsTableProcessedTableManager
  get pekerjaanPpatProsesLocalsRefs {
    final manager = $$PekerjaanPpatProsesLocalsTableTableManager(
      $_db,
      $_db.pekerjaanPpatProsesLocals,
    ).filter((f) => f.pekerjaanPpatId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _pekerjaanPpatProsesLocalsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $PekerjaanPpatAtributLocalsTable,
    List<PekerjaanPpatAtributLocal>
  >
  _pekerjaanPpatAtributLocalsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.pekerjaanPpatAtributLocals,
        aliasName:
            'pekerjaan_ppat__id__pekerjaan_ppat_atributs__pekerjaan_ppat_id',
      );

  $$PekerjaanPpatAtributLocalsTableProcessedTableManager
  get pekerjaanPpatAtributLocalsRefs {
    final manager = $$PekerjaanPpatAtributLocalsTableTableManager(
      $_db,
      $_db.pekerjaanPpatAtributLocals,
    ).filter((f) => f.pekerjaanPpatId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _pekerjaanPpatAtributLocalsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PekerjaanPpatLocalsTableFilterComposer
    extends Composer<_$AppDatabase, $PekerjaanPpatLocalsTable> {
  $$PekerjaanPpatLocalsTableFilterComposer({
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

  ColumnFilters<int> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
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

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> pekerjaanPpatHargaLocalsRefs(
    Expression<bool> Function($$PekerjaanPpatHargaLocalsTableFilterComposer f)
    f,
  ) {
    final $$PekerjaanPpatHargaLocalsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.pekerjaanPpatHargaLocals,
          getReferencedColumn: (t) => t.pekerjaanPpatId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PekerjaanPpatHargaLocalsTableFilterComposer(
                $db: $db,
                $table: $db.pekerjaanPpatHargaLocals,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> pekerjaanPpatProsesLocalsRefs(
    Expression<bool> Function($$PekerjaanPpatProsesLocalsTableFilterComposer f)
    f,
  ) {
    final $$PekerjaanPpatProsesLocalsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.pekerjaanPpatProsesLocals,
          getReferencedColumn: (t) => t.pekerjaanPpatId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PekerjaanPpatProsesLocalsTableFilterComposer(
                $db: $db,
                $table: $db.pekerjaanPpatProsesLocals,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> pekerjaanPpatAtributLocalsRefs(
    Expression<bool> Function($$PekerjaanPpatAtributLocalsTableFilterComposer f)
    f,
  ) {
    final $$PekerjaanPpatAtributLocalsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.pekerjaanPpatAtributLocals,
          getReferencedColumn: (t) => t.pekerjaanPpatId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PekerjaanPpatAtributLocalsTableFilterComposer(
                $db: $db,
                $table: $db.pekerjaanPpatAtributLocals,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$PekerjaanPpatLocalsTableOrderingComposer
    extends Composer<_$AppDatabase, $PekerjaanPpatLocalsTable> {
  $$PekerjaanPpatLocalsTableOrderingComposer({
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

  ColumnOrderings<int> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
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

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PekerjaanPpatLocalsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PekerjaanPpatLocalsTable> {
  $$PekerjaanPpatLocalsTableAnnotationComposer({
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

  GeneratedColumn<int> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<int> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get isSyncDirty => $composableBuilder(
    column: $table.isSyncDirty,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  Expression<T> pekerjaanPpatHargaLocalsRefs<T extends Object>(
    Expression<T> Function($$PekerjaanPpatHargaLocalsTableAnnotationComposer a)
    f,
  ) {
    final $$PekerjaanPpatHargaLocalsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.pekerjaanPpatHargaLocals,
          getReferencedColumn: (t) => t.pekerjaanPpatId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PekerjaanPpatHargaLocalsTableAnnotationComposer(
                $db: $db,
                $table: $db.pekerjaanPpatHargaLocals,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> pekerjaanPpatProsesLocalsRefs<T extends Object>(
    Expression<T> Function($$PekerjaanPpatProsesLocalsTableAnnotationComposer a)
    f,
  ) {
    final $$PekerjaanPpatProsesLocalsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.pekerjaanPpatProsesLocals,
          getReferencedColumn: (t) => t.pekerjaanPpatId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PekerjaanPpatProsesLocalsTableAnnotationComposer(
                $db: $db,
                $table: $db.pekerjaanPpatProsesLocals,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> pekerjaanPpatAtributLocalsRefs<T extends Object>(
    Expression<T> Function(
      $$PekerjaanPpatAtributLocalsTableAnnotationComposer a,
    )
    f,
  ) {
    final $$PekerjaanPpatAtributLocalsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.pekerjaanPpatAtributLocals,
          getReferencedColumn: (t) => t.pekerjaanPpatId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PekerjaanPpatAtributLocalsTableAnnotationComposer(
                $db: $db,
                $table: $db.pekerjaanPpatAtributLocals,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$PekerjaanPpatLocalsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PekerjaanPpatLocalsTable,
          PekerjaanPpatLocal,
          $$PekerjaanPpatLocalsTableFilterComposer,
          $$PekerjaanPpatLocalsTableOrderingComposer,
          $$PekerjaanPpatLocalsTableAnnotationComposer,
          $$PekerjaanPpatLocalsTableCreateCompanionBuilder,
          $$PekerjaanPpatLocalsTableUpdateCompanionBuilder,
          (PekerjaanPpatLocal, $$PekerjaanPpatLocalsTableReferences),
          PekerjaanPpatLocal,
          PrefetchHooks Function({
            bool pekerjaanPpatHargaLocalsRefs,
            bool pekerjaanPpatProsesLocalsRefs,
            bool pekerjaanPpatAtributLocalsRefs,
          })
        > {
  $$PekerjaanPpatLocalsTableTableManager(
    _$AppDatabase db,
    $PekerjaanPpatLocalsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PekerjaanPpatLocalsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PekerjaanPpatLocalsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PekerjaanPpatLocalsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<String> nama = const Value.absent(),
                Value<int?> createdBy = const Value.absent(),
                Value<int?> updatedBy = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<bool> isSyncDirty = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => PekerjaanPpatLocalsCompanion(
                id: id,
                uuid: uuid,
                nama: nama,
                createdBy: createdBy,
                updatedBy: updatedBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                status: status,
                isSyncDirty: isSyncDirty,
                lastSyncedAt: lastSyncedAt,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uuid,
                required String nama,
                Value<int?> createdBy = const Value.absent(),
                Value<int?> updatedBy = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<bool> isSyncDirty = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => PekerjaanPpatLocalsCompanion.insert(
                id: id,
                uuid: uuid,
                nama: nama,
                createdBy: createdBy,
                updatedBy: updatedBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                status: status,
                isSyncDirty: isSyncDirty,
                lastSyncedAt: lastSyncedAt,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PekerjaanPpatLocalsTable, PekerjaanPpatLocal>(
                    table,
                  ),
                  $$PekerjaanPpatLocalsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                pekerjaanPpatHargaLocalsRefs = false,
                pekerjaanPpatProsesLocalsRefs = false,
                pekerjaanPpatAtributLocalsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (pekerjaanPpatHargaLocalsRefs)
                      db.pekerjaanPpatHargaLocals,
                    if (pekerjaanPpatProsesLocalsRefs)
                      db.pekerjaanPpatProsesLocals,
                    if (pekerjaanPpatAtributLocalsRefs)
                      db.pekerjaanPpatAtributLocals,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (pekerjaanPpatHargaLocalsRefs)
                        await $_getPrefetchedData<
                          PekerjaanPpatLocal,
                          $PekerjaanPpatLocalsTable,
                          PekerjaanPpatHargaLocal
                        >(
                          currentTable: table,
                          referencedTable: $$PekerjaanPpatLocalsTableReferences
                              ._pekerjaanPpatHargaLocalsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PekerjaanPpatLocalsTableReferences(
                                db,
                                table,
                                p0,
                              ).pekerjaanPpatHargaLocalsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.pekerjaanPpatId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (pekerjaanPpatProsesLocalsRefs)
                        await $_getPrefetchedData<
                          PekerjaanPpatLocal,
                          $PekerjaanPpatLocalsTable,
                          PekerjaanPpatProsesLocal
                        >(
                          currentTable: table,
                          referencedTable: $$PekerjaanPpatLocalsTableReferences
                              ._pekerjaanPpatProsesLocalsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PekerjaanPpatLocalsTableReferences(
                                db,
                                table,
                                p0,
                              ).pekerjaanPpatProsesLocalsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.pekerjaanPpatId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (pekerjaanPpatAtributLocalsRefs)
                        await $_getPrefetchedData<
                          PekerjaanPpatLocal,
                          $PekerjaanPpatLocalsTable,
                          PekerjaanPpatAtributLocal
                        >(
                          currentTable: table,
                          referencedTable: $$PekerjaanPpatLocalsTableReferences
                              ._pekerjaanPpatAtributLocalsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PekerjaanPpatLocalsTableReferences(
                                db,
                                table,
                                p0,
                              ).pekerjaanPpatAtributLocalsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.pekerjaanPpatId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PekerjaanPpatLocalsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PekerjaanPpatLocalsTable,
      PekerjaanPpatLocal,
      $$PekerjaanPpatLocalsTableFilterComposer,
      $$PekerjaanPpatLocalsTableOrderingComposer,
      $$PekerjaanPpatLocalsTableAnnotationComposer,
      $$PekerjaanPpatLocalsTableCreateCompanionBuilder,
      $$PekerjaanPpatLocalsTableUpdateCompanionBuilder,
      (PekerjaanPpatLocal, $$PekerjaanPpatLocalsTableReferences),
      PekerjaanPpatLocal,
      PrefetchHooks Function({
        bool pekerjaanPpatHargaLocalsRefs,
        bool pekerjaanPpatProsesLocalsRefs,
        bool pekerjaanPpatAtributLocalsRefs,
      })
    >;
typedef $$PekerjaanPpatHargaLocalsTableCreateCompanionBuilder =
    PekerjaanPpatHargaLocalsCompanion Function({
      Value<int> id,
      required String uuid,
      required int pekerjaanPpatId,
      required String harga,
      required int kategoriPekerjaanId,
      required String estimasiWaktu,
      Value<int?> createdBy,
      Value<int?> updatedBy,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> status,
      Value<bool> isSyncDirty,
      Value<DateTime?> lastSyncedAt,
      Value<DateTime?> deletedAt,
    });
typedef $$PekerjaanPpatHargaLocalsTableUpdateCompanionBuilder =
    PekerjaanPpatHargaLocalsCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<int> pekerjaanPpatId,
      Value<String> harga,
      Value<int> kategoriPekerjaanId,
      Value<String> estimasiWaktu,
      Value<int?> createdBy,
      Value<int?> updatedBy,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> status,
      Value<bool> isSyncDirty,
      Value<DateTime?> lastSyncedAt,
      Value<DateTime?> deletedAt,
    });

final class $$PekerjaanPpatHargaLocalsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $PekerjaanPpatHargaLocalsTable,
          PekerjaanPpatHargaLocal
        > {
  $$PekerjaanPpatHargaLocalsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PekerjaanPpatLocalsTable _pekerjaanPpatIdTable(_$AppDatabase db) =>
      db.pekerjaanPpatLocals.createAlias(
        'pekerjaan_ppat_harga__pekerjaan_ppat_id__pekerjaan_ppat__id',
      );

  $$PekerjaanPpatLocalsTableProcessedTableManager get pekerjaanPpatId {
    final $_column = $_itemColumn<int>('pekerjaan_ppat_id')!;

    final manager = $$PekerjaanPpatLocalsTableTableManager(
      $_db,
      $_db.pekerjaanPpatLocals,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_pekerjaanPpatIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PekerjaanKategorisTable _kategoriPekerjaanIdTable(_$AppDatabase db) =>
      db.pekerjaanKategoris.createAlias(
        'pekerjaan_ppat_harga__kategori_pekerjaan_id__pekerjaan_kategori__id',
      );

  $$PekerjaanKategorisTableProcessedTableManager get kategoriPekerjaanId {
    final $_column = $_itemColumn<int>('kategori_pekerjaan_id')!;

    final manager = $$PekerjaanKategorisTableTableManager(
      $_db,
      $_db.pekerjaanKategoris,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_kategoriPekerjaanIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PekerjaanPpatHargaLocalsTableFilterComposer
    extends Composer<_$AppDatabase, $PekerjaanPpatHargaLocalsTable> {
  $$PekerjaanPpatHargaLocalsTableFilterComposer({
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

  ColumnFilters<String> get harga => $composableBuilder(
    column: $table.harga,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get estimasiWaktu => $composableBuilder(
    column: $table.estimasiWaktu,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
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

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PekerjaanPpatLocalsTableFilterComposer get pekerjaanPpatId {
    final $$PekerjaanPpatLocalsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pekerjaanPpatId,
      referencedTable: $db.pekerjaanPpatLocals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PekerjaanPpatLocalsTableFilterComposer(
            $db: $db,
            $table: $db.pekerjaanPpatLocals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PekerjaanKategorisTableFilterComposer get kategoriPekerjaanId {
    final $$PekerjaanKategorisTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.kategoriPekerjaanId,
      referencedTable: $db.pekerjaanKategoris,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PekerjaanKategorisTableFilterComposer(
            $db: $db,
            $table: $db.pekerjaanKategoris,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PekerjaanPpatHargaLocalsTableOrderingComposer
    extends Composer<_$AppDatabase, $PekerjaanPpatHargaLocalsTable> {
  $$PekerjaanPpatHargaLocalsTableOrderingComposer({
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

  ColumnOrderings<String> get harga => $composableBuilder(
    column: $table.harga,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get estimasiWaktu => $composableBuilder(
    column: $table.estimasiWaktu,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
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

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PekerjaanPpatLocalsTableOrderingComposer get pekerjaanPpatId {
    final $$PekerjaanPpatLocalsTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.pekerjaanPpatId,
          referencedTable: $db.pekerjaanPpatLocals,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PekerjaanPpatLocalsTableOrderingComposer(
                $db: $db,
                $table: $db.pekerjaanPpatLocals,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$PekerjaanKategorisTableOrderingComposer get kategoriPekerjaanId {
    final $$PekerjaanKategorisTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.kategoriPekerjaanId,
      referencedTable: $db.pekerjaanKategoris,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PekerjaanKategorisTableOrderingComposer(
            $db: $db,
            $table: $db.pekerjaanKategoris,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PekerjaanPpatHargaLocalsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PekerjaanPpatHargaLocalsTable> {
  $$PekerjaanPpatHargaLocalsTableAnnotationComposer({
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

  GeneratedColumn<String> get harga =>
      $composableBuilder(column: $table.harga, builder: (column) => column);

  GeneratedColumn<String> get estimasiWaktu => $composableBuilder(
    column: $table.estimasiWaktu,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<int> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get isSyncDirty => $composableBuilder(
    column: $table.isSyncDirty,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$PekerjaanPpatLocalsTableAnnotationComposer get pekerjaanPpatId {
    final $$PekerjaanPpatLocalsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.pekerjaanPpatId,
          referencedTable: $db.pekerjaanPpatLocals,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PekerjaanPpatLocalsTableAnnotationComposer(
                $db: $db,
                $table: $db.pekerjaanPpatLocals,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$PekerjaanKategorisTableAnnotationComposer get kategoriPekerjaanId {
    final $$PekerjaanKategorisTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.kategoriPekerjaanId,
          referencedTable: $db.pekerjaanKategoris,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PekerjaanKategorisTableAnnotationComposer(
                $db: $db,
                $table: $db.pekerjaanKategoris,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$PekerjaanPpatHargaLocalsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PekerjaanPpatHargaLocalsTable,
          PekerjaanPpatHargaLocal,
          $$PekerjaanPpatHargaLocalsTableFilterComposer,
          $$PekerjaanPpatHargaLocalsTableOrderingComposer,
          $$PekerjaanPpatHargaLocalsTableAnnotationComposer,
          $$PekerjaanPpatHargaLocalsTableCreateCompanionBuilder,
          $$PekerjaanPpatHargaLocalsTableUpdateCompanionBuilder,
          (PekerjaanPpatHargaLocal, $$PekerjaanPpatHargaLocalsTableReferences),
          PekerjaanPpatHargaLocal,
          PrefetchHooks Function({
            bool pekerjaanPpatId,
            bool kategoriPekerjaanId,
          })
        > {
  $$PekerjaanPpatHargaLocalsTableTableManager(
    _$AppDatabase db,
    $PekerjaanPpatHargaLocalsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PekerjaanPpatHargaLocalsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$PekerjaanPpatHargaLocalsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PekerjaanPpatHargaLocalsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<int> pekerjaanPpatId = const Value.absent(),
                Value<String> harga = const Value.absent(),
                Value<int> kategoriPekerjaanId = const Value.absent(),
                Value<String> estimasiWaktu = const Value.absent(),
                Value<int?> createdBy = const Value.absent(),
                Value<int?> updatedBy = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<bool> isSyncDirty = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => PekerjaanPpatHargaLocalsCompanion(
                id: id,
                uuid: uuid,
                pekerjaanPpatId: pekerjaanPpatId,
                harga: harga,
                kategoriPekerjaanId: kategoriPekerjaanId,
                estimasiWaktu: estimasiWaktu,
                createdBy: createdBy,
                updatedBy: updatedBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                status: status,
                isSyncDirty: isSyncDirty,
                lastSyncedAt: lastSyncedAt,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uuid,
                required int pekerjaanPpatId,
                required String harga,
                required int kategoriPekerjaanId,
                required String estimasiWaktu,
                Value<int?> createdBy = const Value.absent(),
                Value<int?> updatedBy = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<bool> isSyncDirty = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => PekerjaanPpatHargaLocalsCompanion.insert(
                id: id,
                uuid: uuid,
                pekerjaanPpatId: pekerjaanPpatId,
                harga: harga,
                kategoriPekerjaanId: kategoriPekerjaanId,
                estimasiWaktu: estimasiWaktu,
                createdBy: createdBy,
                updatedBy: updatedBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                status: status,
                isSyncDirty: isSyncDirty,
                lastSyncedAt: lastSyncedAt,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $PekerjaanPpatHargaLocalsTable,
                    PekerjaanPpatHargaLocal
                  >(table),
                  $$PekerjaanPpatHargaLocalsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({pekerjaanPpatId = false, kategoriPekerjaanId = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (pekerjaanPpatId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.pekerjaanPpatId,
                            referencedTable:
                                $$PekerjaanPpatHargaLocalsTableReferences
                                    ._pekerjaanPpatIdTable(db),
                            referencedColumn:
                                $$PekerjaanPpatHargaLocalsTableReferences
                                    ._pekerjaanPpatIdTable(db)
                                    .id,
                          ) as T;
                        }
                        if (kategoriPekerjaanId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.kategoriPekerjaanId,
                            referencedTable:
                                $$PekerjaanPpatHargaLocalsTableReferences
                                    ._kategoriPekerjaanIdTable(db),
                            referencedColumn:
                                $$PekerjaanPpatHargaLocalsTableReferences
                                    ._kategoriPekerjaanIdTable(db)
                                    .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$PekerjaanPpatHargaLocalsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PekerjaanPpatHargaLocalsTable,
      PekerjaanPpatHargaLocal,
      $$PekerjaanPpatHargaLocalsTableFilterComposer,
      $$PekerjaanPpatHargaLocalsTableOrderingComposer,
      $$PekerjaanPpatHargaLocalsTableAnnotationComposer,
      $$PekerjaanPpatHargaLocalsTableCreateCompanionBuilder,
      $$PekerjaanPpatHargaLocalsTableUpdateCompanionBuilder,
      (PekerjaanPpatHargaLocal, $$PekerjaanPpatHargaLocalsTableReferences),
      PekerjaanPpatHargaLocal,
      PrefetchHooks Function({bool pekerjaanPpatId, bool kategoriPekerjaanId})
    >;
typedef $$PekerjaanPpatProsesLocalsTableCreateCompanionBuilder =
    PekerjaanPpatProsesLocalsCompanion Function({
      Value<int> id,
      required String uuid,
      required int pekerjaanPpatId,
      required String nama,
      required String detail,
      Value<int?> createdBy,
      Value<int?> updatedBy,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> status,
      Value<bool> isSyncDirty,
      Value<DateTime?> lastSyncedAt,
      Value<DateTime?> deletedAt,
    });
typedef $$PekerjaanPpatProsesLocalsTableUpdateCompanionBuilder =
    PekerjaanPpatProsesLocalsCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<int> pekerjaanPpatId,
      Value<String> nama,
      Value<String> detail,
      Value<int?> createdBy,
      Value<int?> updatedBy,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> status,
      Value<bool> isSyncDirty,
      Value<DateTime?> lastSyncedAt,
      Value<DateTime?> deletedAt,
    });

final class $$PekerjaanPpatProsesLocalsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $PekerjaanPpatProsesLocalsTable,
          PekerjaanPpatProsesLocal
        > {
  $$PekerjaanPpatProsesLocalsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PekerjaanPpatLocalsTable _pekerjaanPpatIdTable(_$AppDatabase db) =>
      db.pekerjaanPpatLocals.createAlias(
        'pekerjaan_ppat_proses__pekerjaan_ppat_id__pekerjaan_ppat__id',
      );

  $$PekerjaanPpatLocalsTableProcessedTableManager get pekerjaanPpatId {
    final $_column = $_itemColumn<int>('pekerjaan_ppat_id')!;

    final manager = $$PekerjaanPpatLocalsTableTableManager(
      $_db,
      $_db.pekerjaanPpatLocals,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_pekerjaanPpatIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $PekerjaanPpatAtributLocalsTable,
    List<PekerjaanPpatAtributLocal>
  >
  _pekerjaanPpatAtributLocalsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.pekerjaanPpatAtributLocals,
        aliasName: 'pekerjaan_ppat_proses__id__pekerjaan_ppat_atributs__proses_pekerjaan_ppat_id',
      );

  $$PekerjaanPpatAtributLocalsTableProcessedTableManager
  get pekerjaanPpatAtributLocalsRefs {
    final manager =
        $$PekerjaanPpatAtributLocalsTableTableManager(
          $_db,
          $_db.pekerjaanPpatAtributLocals,
        ).filter(
          (f) => f.prosesPekerjaanPpatId.id.sqlEquals($_itemColumn<int>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _pekerjaanPpatAtributLocalsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PekerjaanPpatProsesLocalsTableFilterComposer
    extends Composer<_$AppDatabase, $PekerjaanPpatProsesLocalsTable> {
  $$PekerjaanPpatProsesLocalsTableFilterComposer({
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

  ColumnFilters<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
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

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PekerjaanPpatLocalsTableFilterComposer get pekerjaanPpatId {
    final $$PekerjaanPpatLocalsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pekerjaanPpatId,
      referencedTable: $db.pekerjaanPpatLocals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PekerjaanPpatLocalsTableFilterComposer(
            $db: $db,
            $table: $db.pekerjaanPpatLocals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> pekerjaanPpatAtributLocalsRefs(
    Expression<bool> Function($$PekerjaanPpatAtributLocalsTableFilterComposer f)
    f,
  ) {
    final $$PekerjaanPpatAtributLocalsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.pekerjaanPpatAtributLocals,
          getReferencedColumn: (t) => t.prosesPekerjaanPpatId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PekerjaanPpatAtributLocalsTableFilterComposer(
                $db: $db,
                $table: $db.pekerjaanPpatAtributLocals,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$PekerjaanPpatProsesLocalsTableOrderingComposer
    extends Composer<_$AppDatabase, $PekerjaanPpatProsesLocalsTable> {
  $$PekerjaanPpatProsesLocalsTableOrderingComposer({
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

  ColumnOrderings<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
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

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PekerjaanPpatLocalsTableOrderingComposer get pekerjaanPpatId {
    final $$PekerjaanPpatLocalsTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.pekerjaanPpatId,
          referencedTable: $db.pekerjaanPpatLocals,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PekerjaanPpatLocalsTableOrderingComposer(
                $db: $db,
                $table: $db.pekerjaanPpatLocals,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$PekerjaanPpatProsesLocalsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PekerjaanPpatProsesLocalsTable> {
  $$PekerjaanPpatProsesLocalsTableAnnotationComposer({
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

  GeneratedColumn<String> get detail =>
      $composableBuilder(column: $table.detail, builder: (column) => column);

  GeneratedColumn<int> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<int> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get isSyncDirty => $composableBuilder(
    column: $table.isSyncDirty,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$PekerjaanPpatLocalsTableAnnotationComposer get pekerjaanPpatId {
    final $$PekerjaanPpatLocalsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.pekerjaanPpatId,
          referencedTable: $db.pekerjaanPpatLocals,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PekerjaanPpatLocalsTableAnnotationComposer(
                $db: $db,
                $table: $db.pekerjaanPpatLocals,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  Expression<T> pekerjaanPpatAtributLocalsRefs<T extends Object>(
    Expression<T> Function(
      $$PekerjaanPpatAtributLocalsTableAnnotationComposer a,
    )
    f,
  ) {
    final $$PekerjaanPpatAtributLocalsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.pekerjaanPpatAtributLocals,
          getReferencedColumn: (t) => t.prosesPekerjaanPpatId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PekerjaanPpatAtributLocalsTableAnnotationComposer(
                $db: $db,
                $table: $db.pekerjaanPpatAtributLocals,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$PekerjaanPpatProsesLocalsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PekerjaanPpatProsesLocalsTable,
          PekerjaanPpatProsesLocal,
          $$PekerjaanPpatProsesLocalsTableFilterComposer,
          $$PekerjaanPpatProsesLocalsTableOrderingComposer,
          $$PekerjaanPpatProsesLocalsTableAnnotationComposer,
          $$PekerjaanPpatProsesLocalsTableCreateCompanionBuilder,
          $$PekerjaanPpatProsesLocalsTableUpdateCompanionBuilder,
          (
            PekerjaanPpatProsesLocal,
            $$PekerjaanPpatProsesLocalsTableReferences,
          ),
          PekerjaanPpatProsesLocal,
          PrefetchHooks Function({
            bool pekerjaanPpatId,
            bool pekerjaanPpatAtributLocalsRefs,
          })
        > {
  $$PekerjaanPpatProsesLocalsTableTableManager(
    _$AppDatabase db,
    $PekerjaanPpatProsesLocalsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PekerjaanPpatProsesLocalsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$PekerjaanPpatProsesLocalsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PekerjaanPpatProsesLocalsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<int> pekerjaanPpatId = const Value.absent(),
                Value<String> nama = const Value.absent(),
                Value<String> detail = const Value.absent(),
                Value<int?> createdBy = const Value.absent(),
                Value<int?> updatedBy = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<bool> isSyncDirty = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => PekerjaanPpatProsesLocalsCompanion(
                id: id,
                uuid: uuid,
                pekerjaanPpatId: pekerjaanPpatId,
                nama: nama,
                detail: detail,
                createdBy: createdBy,
                updatedBy: updatedBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                status: status,
                isSyncDirty: isSyncDirty,
                lastSyncedAt: lastSyncedAt,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uuid,
                required int pekerjaanPpatId,
                required String nama,
                required String detail,
                Value<int?> createdBy = const Value.absent(),
                Value<int?> updatedBy = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<bool> isSyncDirty = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => PekerjaanPpatProsesLocalsCompanion.insert(
                id: id,
                uuid: uuid,
                pekerjaanPpatId: pekerjaanPpatId,
                nama: nama,
                detail: detail,
                createdBy: createdBy,
                updatedBy: updatedBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                status: status,
                isSyncDirty: isSyncDirty,
                lastSyncedAt: lastSyncedAt,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $PekerjaanPpatProsesLocalsTable,
                    PekerjaanPpatProsesLocal
                  >(table),
                  $$PekerjaanPpatProsesLocalsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                pekerjaanPpatId = false,
                pekerjaanPpatAtributLocalsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (pekerjaanPpatAtributLocalsRefs)
                      db.pekerjaanPpatAtributLocals,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (pekerjaanPpatId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.pekerjaanPpatId,
                            referencedTable:
                                $$PekerjaanPpatProsesLocalsTableReferences
                                    ._pekerjaanPpatIdTable(db),
                            referencedColumn:
                                $$PekerjaanPpatProsesLocalsTableReferences
                                    ._pekerjaanPpatIdTable(db)
                                    .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (pekerjaanPpatAtributLocalsRefs)
                        await $_getPrefetchedData<
                          PekerjaanPpatProsesLocal,
                          $PekerjaanPpatProsesLocalsTable,
                          PekerjaanPpatAtributLocal
                        >(
                          currentTable: table,
                          referencedTable:
                              $$PekerjaanPpatProsesLocalsTableReferences
                                  ._pekerjaanPpatAtributLocalsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PekerjaanPpatProsesLocalsTableReferences(
                                db,
                                table,
                                p0,
                              ).pekerjaanPpatAtributLocalsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.prosesPekerjaanPpatId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PekerjaanPpatProsesLocalsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PekerjaanPpatProsesLocalsTable,
      PekerjaanPpatProsesLocal,
      $$PekerjaanPpatProsesLocalsTableFilterComposer,
      $$PekerjaanPpatProsesLocalsTableOrderingComposer,
      $$PekerjaanPpatProsesLocalsTableAnnotationComposer,
      $$PekerjaanPpatProsesLocalsTableCreateCompanionBuilder,
      $$PekerjaanPpatProsesLocalsTableUpdateCompanionBuilder,
      (PekerjaanPpatProsesLocal, $$PekerjaanPpatProsesLocalsTableReferences),
      PekerjaanPpatProsesLocal,
      PrefetchHooks Function({
        bool pekerjaanPpatId,
        bool pekerjaanPpatAtributLocalsRefs,
      })
    >;
typedef $$PekerjaanPpatAtributLocalsTableCreateCompanionBuilder =
    PekerjaanPpatAtributLocalsCompanion Function({
      Value<int> id,
      required String uuid,
      required int pekerjaanPpatId,
      required int prosesPekerjaanPpatId,
      Value<String?> atribut,
      Value<int?> createdBy,
      Value<int?> updatedBy,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> status,
      Value<bool> isSyncDirty,
      Value<DateTime?> lastSyncedAt,
      Value<DateTime?> deletedAt,
    });
typedef $$PekerjaanPpatAtributLocalsTableUpdateCompanionBuilder =
    PekerjaanPpatAtributLocalsCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<int> pekerjaanPpatId,
      Value<int> prosesPekerjaanPpatId,
      Value<String?> atribut,
      Value<int?> createdBy,
      Value<int?> updatedBy,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<int> status,
      Value<bool> isSyncDirty,
      Value<DateTime?> lastSyncedAt,
      Value<DateTime?> deletedAt,
    });

final class $$PekerjaanPpatAtributLocalsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $PekerjaanPpatAtributLocalsTable,
          PekerjaanPpatAtributLocal
        > {
  $$PekerjaanPpatAtributLocalsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PekerjaanPpatLocalsTable _pekerjaanPpatIdTable(_$AppDatabase db) =>
      db.pekerjaanPpatLocals.createAlias(
        'pekerjaan_ppat_atributs__pekerjaan_ppat_id__pekerjaan_ppat__id',
      );

  $$PekerjaanPpatLocalsTableProcessedTableManager get pekerjaanPpatId {
    final $_column = $_itemColumn<int>('pekerjaan_ppat_id')!;

    final manager = $$PekerjaanPpatLocalsTableTableManager(
      $_db,
      $_db.pekerjaanPpatLocals,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_pekerjaanPpatIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PekerjaanPpatProsesLocalsTable _prosesPekerjaanPpatIdTable(
    _$AppDatabase db,
  ) => db.pekerjaanPpatProsesLocals.createAlias(
    'pekerjaan_ppat_atributs__proses_pekerjaan_ppat_id__pekerjaan_ppat_proses__id',
  );

  $$PekerjaanPpatProsesLocalsTableProcessedTableManager
  get prosesPekerjaanPpatId {
    final $_column = $_itemColumn<int>('proses_pekerjaan_ppat_id')!;

    final manager = $$PekerjaanPpatProsesLocalsTableTableManager(
      $_db,
      $_db.pekerjaanPpatProsesLocals,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(
      _prosesPekerjaanPpatIdTable($_db),
    );
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PekerjaanPpatAtributLocalsTableFilterComposer
    extends Composer<_$AppDatabase, $PekerjaanPpatAtributLocalsTable> {
  $$PekerjaanPpatAtributLocalsTableFilterComposer({
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

  ColumnFilters<String> get atribut => $composableBuilder(
    column: $table.atribut,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
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

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PekerjaanPpatLocalsTableFilterComposer get pekerjaanPpatId {
    final $$PekerjaanPpatLocalsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.pekerjaanPpatId,
      referencedTable: $db.pekerjaanPpatLocals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PekerjaanPpatLocalsTableFilterComposer(
            $db: $db,
            $table: $db.pekerjaanPpatLocals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PekerjaanPpatProsesLocalsTableFilterComposer get prosesPekerjaanPpatId {
    final $$PekerjaanPpatProsesLocalsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.prosesPekerjaanPpatId,
          referencedTable: $db.pekerjaanPpatProsesLocals,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PekerjaanPpatProsesLocalsTableFilterComposer(
                $db: $db,
                $table: $db.pekerjaanPpatProsesLocals,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$PekerjaanPpatAtributLocalsTableOrderingComposer
    extends Composer<_$AppDatabase, $PekerjaanPpatAtributLocalsTable> {
  $$PekerjaanPpatAtributLocalsTableOrderingComposer({
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

  ColumnOrderings<String> get atribut => $composableBuilder(
    column: $table.atribut,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
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

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PekerjaanPpatLocalsTableOrderingComposer get pekerjaanPpatId {
    final $$PekerjaanPpatLocalsTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.pekerjaanPpatId,
          referencedTable: $db.pekerjaanPpatLocals,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PekerjaanPpatLocalsTableOrderingComposer(
                $db: $db,
                $table: $db.pekerjaanPpatLocals,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$PekerjaanPpatProsesLocalsTableOrderingComposer get prosesPekerjaanPpatId {
    final $$PekerjaanPpatProsesLocalsTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.prosesPekerjaanPpatId,
          referencedTable: $db.pekerjaanPpatProsesLocals,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PekerjaanPpatProsesLocalsTableOrderingComposer(
                $db: $db,
                $table: $db.pekerjaanPpatProsesLocals,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$PekerjaanPpatAtributLocalsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PekerjaanPpatAtributLocalsTable> {
  $$PekerjaanPpatAtributLocalsTableAnnotationComposer({
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

  GeneratedColumn<String> get atribut =>
      $composableBuilder(column: $table.atribut, builder: (column) => column);

  GeneratedColumn<int> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<int> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get isSyncDirty => $composableBuilder(
    column: $table.isSyncDirty,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$PekerjaanPpatLocalsTableAnnotationComposer get pekerjaanPpatId {
    final $$PekerjaanPpatLocalsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.pekerjaanPpatId,
          referencedTable: $db.pekerjaanPpatLocals,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PekerjaanPpatLocalsTableAnnotationComposer(
                $db: $db,
                $table: $db.pekerjaanPpatLocals,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$PekerjaanPpatProsesLocalsTableAnnotationComposer get prosesPekerjaanPpatId {
    final $$PekerjaanPpatProsesLocalsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.prosesPekerjaanPpatId,
          referencedTable: $db.pekerjaanPpatProsesLocals,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PekerjaanPpatProsesLocalsTableAnnotationComposer(
                $db: $db,
                $table: $db.pekerjaanPpatProsesLocals,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$PekerjaanPpatAtributLocalsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PekerjaanPpatAtributLocalsTable,
          PekerjaanPpatAtributLocal,
          $$PekerjaanPpatAtributLocalsTableFilterComposer,
          $$PekerjaanPpatAtributLocalsTableOrderingComposer,
          $$PekerjaanPpatAtributLocalsTableAnnotationComposer,
          $$PekerjaanPpatAtributLocalsTableCreateCompanionBuilder,
          $$PekerjaanPpatAtributLocalsTableUpdateCompanionBuilder,
          (
            PekerjaanPpatAtributLocal,
            $$PekerjaanPpatAtributLocalsTableReferences,
          ),
          PekerjaanPpatAtributLocal,
          PrefetchHooks Function({
            bool pekerjaanPpatId,
            bool prosesPekerjaanPpatId,
          })
        > {
  $$PekerjaanPpatAtributLocalsTableTableManager(
    _$AppDatabase db,
    $PekerjaanPpatAtributLocalsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PekerjaanPpatAtributLocalsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$PekerjaanPpatAtributLocalsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PekerjaanPpatAtributLocalsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<int> pekerjaanPpatId = const Value.absent(),
                Value<int> prosesPekerjaanPpatId = const Value.absent(),
                Value<String?> atribut = const Value.absent(),
                Value<int?> createdBy = const Value.absent(),
                Value<int?> updatedBy = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<bool> isSyncDirty = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => PekerjaanPpatAtributLocalsCompanion(
                id: id,
                uuid: uuid,
                pekerjaanPpatId: pekerjaanPpatId,
                prosesPekerjaanPpatId: prosesPekerjaanPpatId,
                atribut: atribut,
                createdBy: createdBy,
                updatedBy: updatedBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                status: status,
                isSyncDirty: isSyncDirty,
                lastSyncedAt: lastSyncedAt,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uuid,
                required int pekerjaanPpatId,
                required int prosesPekerjaanPpatId,
                Value<String?> atribut = const Value.absent(),
                Value<int?> createdBy = const Value.absent(),
                Value<int?> updatedBy = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<bool> isSyncDirty = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => PekerjaanPpatAtributLocalsCompanion.insert(
                id: id,
                uuid: uuid,
                pekerjaanPpatId: pekerjaanPpatId,
                prosesPekerjaanPpatId: prosesPekerjaanPpatId,
                atribut: atribut,
                createdBy: createdBy,
                updatedBy: updatedBy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                status: status,
                isSyncDirty: isSyncDirty,
                lastSyncedAt: lastSyncedAt,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $PekerjaanPpatAtributLocalsTable,
                    PekerjaanPpatAtributLocal
                  >(table),
                  $$PekerjaanPpatAtributLocalsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({pekerjaanPpatId = false, prosesPekerjaanPpatId = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (pekerjaanPpatId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.pekerjaanPpatId,
                            referencedTable:
                                $$PekerjaanPpatAtributLocalsTableReferences
                                    ._pekerjaanPpatIdTable(db),
                            referencedColumn:
                                $$PekerjaanPpatAtributLocalsTableReferences
                                    ._pekerjaanPpatIdTable(db)
                                    .id,
                          ) as T;
                        }
                        if (prosesPekerjaanPpatId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.prosesPekerjaanPpatId,
                            referencedTable:
                                $$PekerjaanPpatAtributLocalsTableReferences
                                    ._prosesPekerjaanPpatIdTable(db),
                            referencedColumn:
                                $$PekerjaanPpatAtributLocalsTableReferences
                                    ._prosesPekerjaanPpatIdTable(db)
                                    .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$PekerjaanPpatAtributLocalsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PekerjaanPpatAtributLocalsTable,
      PekerjaanPpatAtributLocal,
      $$PekerjaanPpatAtributLocalsTableFilterComposer,
      $$PekerjaanPpatAtributLocalsTableOrderingComposer,
      $$PekerjaanPpatAtributLocalsTableAnnotationComposer,
      $$PekerjaanPpatAtributLocalsTableCreateCompanionBuilder,
      $$PekerjaanPpatAtributLocalsTableUpdateCompanionBuilder,
      (PekerjaanPpatAtributLocal, $$PekerjaanPpatAtributLocalsTableReferences),
      PekerjaanPpatAtributLocal,
      PrefetchHooks Function({bool pekerjaanPpatId, bool prosesPekerjaanPpatId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$JenisKelaminsTableTableManager get jenisKelamins =>
      $$JenisKelaminsTableTableManager(_db, _db.jenisKelamins);
  $$PemohonsTableTableManager get pemohons =>
      $$PemohonsTableTableManager(_db, _db.pemohons);
  $$TransaksisTableTableManager get transaksis =>
      $$TransaksisTableTableManager(_db, _db.transaksis);
  $$PekerjaanKategorisTableTableManager get pekerjaanKategoris =>
      $$PekerjaanKategorisTableTableManager(_db, _db.pekerjaanKategoris);
  $$PengeluaranJenisTableTableManager get pengeluaranJenis =>
      $$PengeluaranJenisTableTableManager(_db, _db.pengeluaranJenis);
  $$PetugasLocalsTableTableManager get petugasLocals =>
      $$PetugasLocalsTableTableManager(_db, _db.petugasLocals);
  $$PekerjaanNotarisLocalsTableTableManager get pekerjaanNotarisLocals =>
      $$PekerjaanNotarisLocalsTableTableManager(
        _db,
        _db.pekerjaanNotarisLocals,
      );
  $$PekerjaanNotarisHargaLocalsTableTableManager
  get pekerjaanNotarisHargaLocals =>
      $$PekerjaanNotarisHargaLocalsTableTableManager(
        _db,
        _db.pekerjaanNotarisHargaLocals,
      );
  $$PekerjaanNotarisProsesLocalsTableTableManager
  get pekerjaanNotarisProsesLocals =>
      $$PekerjaanNotarisProsesLocalsTableTableManager(
        _db,
        _db.pekerjaanNotarisProsesLocals,
      );
  $$PekerjaanNotarisAtributLocalsTableTableManager
  get pekerjaanNotarisAtributLocals =>
      $$PekerjaanNotarisAtributLocalsTableTableManager(
        _db,
        _db.pekerjaanNotarisAtributLocals,
      );
  $$PekerjaanPpatLocalsTableTableManager get pekerjaanPpatLocals =>
      $$PekerjaanPpatLocalsTableTableManager(_db, _db.pekerjaanPpatLocals);
  $$PekerjaanPpatHargaLocalsTableTableManager get pekerjaanPpatHargaLocals =>
      $$PekerjaanPpatHargaLocalsTableTableManager(
        _db,
        _db.pekerjaanPpatHargaLocals,
      );
  $$PekerjaanPpatProsesLocalsTableTableManager get pekerjaanPpatProsesLocals =>
      $$PekerjaanPpatProsesLocalsTableTableManager(
        _db,
        _db.pekerjaanPpatProsesLocals,
      );
  $$PekerjaanPpatAtributLocalsTableTableManager
  get pekerjaanPpatAtributLocals =>
      $$PekerjaanPpatAtributLocalsTableTableManager(
        _db,
        _db.pekerjaanPpatAtributLocals,
      );
}
