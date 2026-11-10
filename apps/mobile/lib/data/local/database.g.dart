// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $BeneficiariesTable extends Beneficiaries
    with TableInfo<$BeneficiariesTable, BeneficiaryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BeneficiariesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _siteIdMeta = const VerificationMeta('siteId');
  @override
  late final GeneratedColumn<String> siteId = GeneratedColumn<String>(
    'site_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _birthYearMeta = const VerificationMeta(
    'birthYear',
  );
  @override
  late final GeneratedColumn<int> birthYear = GeneratedColumn<int>(
    'birth_year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _preferredChannelMeta = const VerificationMeta(
    'preferredChannel',
  );
  @override
  late final GeneratedColumn<String> preferredChannel = GeneratedColumn<String>(
    'preferred_channel',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('none'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    version,
    createdAt,
    updatedAt,
    deletedAt,
    id,
    code,
    siteId,
    birthYear,
    preferredChannel,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'beneficiaries';
  @override
  VerificationContext validateIntegrity(
    Insertable<BeneficiaryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
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
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    }
    if (data.containsKey('site_id')) {
      context.handle(
        _siteIdMeta,
        siteId.isAcceptableOrUnknown(data['site_id']!, _siteIdMeta),
      );
    }
    if (data.containsKey('birth_year')) {
      context.handle(
        _birthYearMeta,
        birthYear.isAcceptableOrUnknown(data['birth_year']!, _birthYearMeta),
      );
    }
    if (data.containsKey('preferred_channel')) {
      context.handle(
        _preferredChannelMeta,
        preferredChannel.isAcceptableOrUnknown(
          data['preferred_channel']!,
          _preferredChannelMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BeneficiaryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BeneficiaryRow(
      version:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}version'],
          )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      ),
      siteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}site_id'],
      ),
      birthYear: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}birth_year'],
      ),
      preferredChannel:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}preferred_channel'],
          )!,
    );
  }

  @override
  $BeneficiariesTable createAlias(String alias) {
    return $BeneficiariesTable(attachedDatabase, alias);
  }
}

class BeneficiaryRow extends DataClass implements Insertable<BeneficiaryRow> {
  final int version;
  final String? createdAt;
  final String? updatedAt;
  final String? deletedAt;
  final String id;

  /// `FAN-XXXXXX`, attribué par le serveur (null tant que non synchronisé).
  final String? code;
  final String? siteId;
  final int? birthYear;
  final String preferredChannel;
  const BeneficiaryRow({
    required this.version,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    required this.id,
    this.code,
    this.siteId,
    this.birthYear,
    required this.preferredChannel,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['version'] = Variable<int>(version);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || code != null) {
      map['code'] = Variable<String>(code);
    }
    if (!nullToAbsent || siteId != null) {
      map['site_id'] = Variable<String>(siteId);
    }
    if (!nullToAbsent || birthYear != null) {
      map['birth_year'] = Variable<int>(birthYear);
    }
    map['preferred_channel'] = Variable<String>(preferredChannel);
    return map;
  }

  BeneficiariesCompanion toCompanion(bool nullToAbsent) {
    return BeneficiariesCompanion(
      version: Value(version),
      createdAt:
          createdAt == null && nullToAbsent
              ? const Value.absent()
              : Value(createdAt),
      updatedAt:
          updatedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(updatedAt),
      deletedAt:
          deletedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(deletedAt),
      id: Value(id),
      code: code == null && nullToAbsent ? const Value.absent() : Value(code),
      siteId:
          siteId == null && nullToAbsent ? const Value.absent() : Value(siteId),
      birthYear:
          birthYear == null && nullToAbsent
              ? const Value.absent()
              : Value(birthYear),
      preferredChannel: Value(preferredChannel),
    );
  }

  factory BeneficiaryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BeneficiaryRow(
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<String?>(json['createdAt']),
      updatedAt: serializer.fromJson<String?>(json['updatedAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
      id: serializer.fromJson<String>(json['id']),
      code: serializer.fromJson<String?>(json['code']),
      siteId: serializer.fromJson<String?>(json['siteId']),
      birthYear: serializer.fromJson<int?>(json['birthYear']),
      preferredChannel: serializer.fromJson<String>(json['preferredChannel']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<String?>(createdAt),
      'updatedAt': serializer.toJson<String?>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
      'id': serializer.toJson<String>(id),
      'code': serializer.toJson<String?>(code),
      'siteId': serializer.toJson<String?>(siteId),
      'birthYear': serializer.toJson<int?>(birthYear),
      'preferredChannel': serializer.toJson<String>(preferredChannel),
    };
  }

  BeneficiaryRow copyWith({
    int? version,
    Value<String?> createdAt = const Value.absent(),
    Value<String?> updatedAt = const Value.absent(),
    Value<String?> deletedAt = const Value.absent(),
    String? id,
    Value<String?> code = const Value.absent(),
    Value<String?> siteId = const Value.absent(),
    Value<int?> birthYear = const Value.absent(),
    String? preferredChannel,
  }) => BeneficiaryRow(
    version: version ?? this.version,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    id: id ?? this.id,
    code: code.present ? code.value : this.code,
    siteId: siteId.present ? siteId.value : this.siteId,
    birthYear: birthYear.present ? birthYear.value : this.birthYear,
    preferredChannel: preferredChannel ?? this.preferredChannel,
  );
  BeneficiaryRow copyWithCompanion(BeneficiariesCompanion data) {
    return BeneficiaryRow(
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      id: data.id.present ? data.id.value : this.id,
      code: data.code.present ? data.code.value : this.code,
      siteId: data.siteId.present ? data.siteId.value : this.siteId,
      birthYear: data.birthYear.present ? data.birthYear.value : this.birthYear,
      preferredChannel:
          data.preferredChannel.present
              ? data.preferredChannel.value
              : this.preferredChannel,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BeneficiaryRow(')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('siteId: $siteId, ')
          ..write('birthYear: $birthYear, ')
          ..write('preferredChannel: $preferredChannel')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    version,
    createdAt,
    updatedAt,
    deletedAt,
    id,
    code,
    siteId,
    birthYear,
    preferredChannel,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BeneficiaryRow &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.id == this.id &&
          other.code == this.code &&
          other.siteId == this.siteId &&
          other.birthYear == this.birthYear &&
          other.preferredChannel == this.preferredChannel);
}

class BeneficiariesCompanion extends UpdateCompanion<BeneficiaryRow> {
  final Value<int> version;
  final Value<String?> createdAt;
  final Value<String?> updatedAt;
  final Value<String?> deletedAt;
  final Value<String> id;
  final Value<String?> code;
  final Value<String?> siteId;
  final Value<int?> birthYear;
  final Value<String> preferredChannel;
  final Value<int> rowid;
  const BeneficiariesCompanion({
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.code = const Value.absent(),
    this.siteId = const Value.absent(),
    this.birthYear = const Value.absent(),
    this.preferredChannel = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BeneficiariesCompanion.insert({
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String id,
    this.code = const Value.absent(),
    this.siteId = const Value.absent(),
    this.birthYear = const Value.absent(),
    this.preferredChannel = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<BeneficiaryRow> custom({
    Expression<int>? version,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<String>? id,
    Expression<String>? code,
    Expression<String>? siteId,
    Expression<int>? birthYear,
    Expression<String>? preferredChannel,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (id != null) 'id': id,
      if (code != null) 'code': code,
      if (siteId != null) 'site_id': siteId,
      if (birthYear != null) 'birth_year': birthYear,
      if (preferredChannel != null) 'preferred_channel': preferredChannel,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BeneficiariesCompanion copyWith({
    Value<int>? version,
    Value<String?>? createdAt,
    Value<String?>? updatedAt,
    Value<String?>? deletedAt,
    Value<String>? id,
    Value<String?>? code,
    Value<String?>? siteId,
    Value<int?>? birthYear,
    Value<String>? preferredChannel,
    Value<int>? rowid,
  }) {
    return BeneficiariesCompanion(
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      id: id ?? this.id,
      code: code ?? this.code,
      siteId: siteId ?? this.siteId,
      birthYear: birthYear ?? this.birthYear,
      preferredChannel: preferredChannel ?? this.preferredChannel,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (siteId.present) {
      map['site_id'] = Variable<String>(siteId.value);
    }
    if (birthYear.present) {
      map['birth_year'] = Variable<int>(birthYear.value);
    }
    if (preferredChannel.present) {
      map['preferred_channel'] = Variable<String>(preferredChannel.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BeneficiariesCompanion(')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('siteId: $siteId, ')
          ..write('birthYear: $birthYear, ')
          ..write('preferredChannel: $preferredChannel, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BeneficiaryIdentitiesTable extends BeneficiaryIdentities
    with TableInfo<$BeneficiaryIdentitiesTable, BeneficiaryIdentityRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BeneficiaryIdentitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _beneficiaryIdMeta = const VerificationMeta(
    'beneficiaryId',
  );
  @override
  late final GeneratedColumn<String> beneficiaryId = GeneratedColumn<String>(
    'beneficiary_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _villageMeta = const VerificationMeta(
    'village',
  );
  @override
  late final GeneratedColumn<String> village = GeneratedColumn<String>(
    'village',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    version,
    createdAt,
    updatedAt,
    deletedAt,
    beneficiaryId,
    displayName,
    phone,
    village,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'beneficiary_identities';
  @override
  VerificationContext validateIntegrity(
    Insertable<BeneficiaryIdentityRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
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
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('beneficiary_id')) {
      context.handle(
        _beneficiaryIdMeta,
        beneficiaryId.isAcceptableOrUnknown(
          data['beneficiary_id']!,
          _beneficiaryIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_beneficiaryIdMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('village')) {
      context.handle(
        _villageMeta,
        village.isAcceptableOrUnknown(data['village']!, _villageMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {beneficiaryId};
  @override
  BeneficiaryIdentityRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BeneficiaryIdentityRow(
      version:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}version'],
          )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
      beneficiaryId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}beneficiary_id'],
          )!,
      displayName:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}display_name'],
          )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      village: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}village'],
      ),
    );
  }

  @override
  $BeneficiaryIdentitiesTable createAlias(String alias) {
    return $BeneficiaryIdentitiesTable(attachedDatabase, alias);
  }
}

class BeneficiaryIdentityRow extends DataClass
    implements Insertable<BeneficiaryIdentityRow> {
  final int version;
  final String? createdAt;
  final String? updatedAt;
  final String? deletedAt;
  final String beneficiaryId;
  final String displayName;
  final String? phone;
  final String? village;
  const BeneficiaryIdentityRow({
    required this.version,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    required this.beneficiaryId,
    required this.displayName,
    this.phone,
    this.village,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['version'] = Variable<int>(version);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    map['beneficiary_id'] = Variable<String>(beneficiaryId);
    map['display_name'] = Variable<String>(displayName);
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || village != null) {
      map['village'] = Variable<String>(village);
    }
    return map;
  }

  BeneficiaryIdentitiesCompanion toCompanion(bool nullToAbsent) {
    return BeneficiaryIdentitiesCompanion(
      version: Value(version),
      createdAt:
          createdAt == null && nullToAbsent
              ? const Value.absent()
              : Value(createdAt),
      updatedAt:
          updatedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(updatedAt),
      deletedAt:
          deletedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(deletedAt),
      beneficiaryId: Value(beneficiaryId),
      displayName: Value(displayName),
      phone:
          phone == null && nullToAbsent ? const Value.absent() : Value(phone),
      village:
          village == null && nullToAbsent
              ? const Value.absent()
              : Value(village),
    );
  }

  factory BeneficiaryIdentityRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BeneficiaryIdentityRow(
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<String?>(json['createdAt']),
      updatedAt: serializer.fromJson<String?>(json['updatedAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
      beneficiaryId: serializer.fromJson<String>(json['beneficiaryId']),
      displayName: serializer.fromJson<String>(json['displayName']),
      phone: serializer.fromJson<String?>(json['phone']),
      village: serializer.fromJson<String?>(json['village']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<String?>(createdAt),
      'updatedAt': serializer.toJson<String?>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
      'beneficiaryId': serializer.toJson<String>(beneficiaryId),
      'displayName': serializer.toJson<String>(displayName),
      'phone': serializer.toJson<String?>(phone),
      'village': serializer.toJson<String?>(village),
    };
  }

  BeneficiaryIdentityRow copyWith({
    int? version,
    Value<String?> createdAt = const Value.absent(),
    Value<String?> updatedAt = const Value.absent(),
    Value<String?> deletedAt = const Value.absent(),
    String? beneficiaryId,
    String? displayName,
    Value<String?> phone = const Value.absent(),
    Value<String?> village = const Value.absent(),
  }) => BeneficiaryIdentityRow(
    version: version ?? this.version,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    beneficiaryId: beneficiaryId ?? this.beneficiaryId,
    displayName: displayName ?? this.displayName,
    phone: phone.present ? phone.value : this.phone,
    village: village.present ? village.value : this.village,
  );
  BeneficiaryIdentityRow copyWithCompanion(
    BeneficiaryIdentitiesCompanion data,
  ) {
    return BeneficiaryIdentityRow(
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      beneficiaryId:
          data.beneficiaryId.present
              ? data.beneficiaryId.value
              : this.beneficiaryId,
      displayName:
          data.displayName.present ? data.displayName.value : this.displayName,
      phone: data.phone.present ? data.phone.value : this.phone,
      village: data.village.present ? data.village.value : this.village,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BeneficiaryIdentityRow(')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('beneficiaryId: $beneficiaryId, ')
          ..write('displayName: $displayName, ')
          ..write('phone: $phone, ')
          ..write('village: $village')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    version,
    createdAt,
    updatedAt,
    deletedAt,
    beneficiaryId,
    displayName,
    phone,
    village,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BeneficiaryIdentityRow &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.beneficiaryId == this.beneficiaryId &&
          other.displayName == this.displayName &&
          other.phone == this.phone &&
          other.village == this.village);
}

class BeneficiaryIdentitiesCompanion
    extends UpdateCompanion<BeneficiaryIdentityRow> {
  final Value<int> version;
  final Value<String?> createdAt;
  final Value<String?> updatedAt;
  final Value<String?> deletedAt;
  final Value<String> beneficiaryId;
  final Value<String> displayName;
  final Value<String?> phone;
  final Value<String?> village;
  final Value<int> rowid;
  const BeneficiaryIdentitiesCompanion({
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.beneficiaryId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.phone = const Value.absent(),
    this.village = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BeneficiaryIdentitiesCompanion.insert({
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String beneficiaryId,
    required String displayName,
    this.phone = const Value.absent(),
    this.village = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : beneficiaryId = Value(beneficiaryId),
       displayName = Value(displayName);
  static Insertable<BeneficiaryIdentityRow> custom({
    Expression<int>? version,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<String>? beneficiaryId,
    Expression<String>? displayName,
    Expression<String>? phone,
    Expression<String>? village,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (beneficiaryId != null) 'beneficiary_id': beneficiaryId,
      if (displayName != null) 'display_name': displayName,
      if (phone != null) 'phone': phone,
      if (village != null) 'village': village,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BeneficiaryIdentitiesCompanion copyWith({
    Value<int>? version,
    Value<String?>? createdAt,
    Value<String?>? updatedAt,
    Value<String?>? deletedAt,
    Value<String>? beneficiaryId,
    Value<String>? displayName,
    Value<String?>? phone,
    Value<String?>? village,
    Value<int>? rowid,
  }) {
    return BeneficiaryIdentitiesCompanion(
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      beneficiaryId: beneficiaryId ?? this.beneficiaryId,
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
      village: village ?? this.village,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (beneficiaryId.present) {
      map['beneficiary_id'] = Variable<String>(beneficiaryId.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (village.present) {
      map['village'] = Variable<String>(village.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BeneficiaryIdentitiesCompanion(')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('beneficiaryId: $beneficiaryId, ')
          ..write('displayName: $displayName, ')
          ..write('phone: $phone, ')
          ..write('village: $village, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConsentsTable extends Consents
    with TableInfo<$ConsentsTable, ConsentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConsentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _beneficiaryIdMeta = const VerificationMeta(
    'beneficiaryId',
  );
  @override
  late final GeneratedColumn<String> beneficiaryId = GeneratedColumn<String>(
    'beneficiary_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _methodMeta = const VerificationMeta('method');
  @override
  late final GeneratedColumn<String> method = GeneratedColumn<String>(
    'method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _informationVersionMeta =
      const VerificationMeta('informationVersion');
  @override
  late final GeneratedColumn<String> informationVersion =
      GeneratedColumn<String>(
        'information_version',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _collectedByUserIdMeta = const VerificationMeta(
    'collectedByUserId',
  );
  @override
  late final GeneratedColumn<String> collectedByUserId =
      GeneratedColumn<String>(
        'collected_by_user_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _collectedAtMeta = const VerificationMeta(
    'collectedAt',
  );
  @override
  late final GeneratedColumn<String> collectedAt = GeneratedColumn<String>(
    'collected_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _withdrawnAtMeta = const VerificationMeta(
    'withdrawnAt',
  );
  @override
  late final GeneratedColumn<String> withdrawnAt = GeneratedColumn<String>(
    'withdrawn_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _withdrawnByUserIdMeta = const VerificationMeta(
    'withdrawnByUserId',
  );
  @override
  late final GeneratedColumn<String> withdrawnByUserId =
      GeneratedColumn<String>(
        'withdrawn_by_user_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    version,
    createdAt,
    updatedAt,
    deletedAt,
    id,
    beneficiaryId,
    scope,
    method,
    informationVersion,
    collectedByUserId,
    collectedAt,
    withdrawnAt,
    withdrawnByUserId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'consents';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConsentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
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
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('beneficiary_id')) {
      context.handle(
        _beneficiaryIdMeta,
        beneficiaryId.isAcceptableOrUnknown(
          data['beneficiary_id']!,
          _beneficiaryIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_beneficiaryIdMeta);
    }
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('method')) {
      context.handle(
        _methodMeta,
        method.isAcceptableOrUnknown(data['method']!, _methodMeta),
      );
    } else if (isInserting) {
      context.missing(_methodMeta);
    }
    if (data.containsKey('information_version')) {
      context.handle(
        _informationVersionMeta,
        informationVersion.isAcceptableOrUnknown(
          data['information_version']!,
          _informationVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_informationVersionMeta);
    }
    if (data.containsKey('collected_by_user_id')) {
      context.handle(
        _collectedByUserIdMeta,
        collectedByUserId.isAcceptableOrUnknown(
          data['collected_by_user_id']!,
          _collectedByUserIdMeta,
        ),
      );
    }
    if (data.containsKey('collected_at')) {
      context.handle(
        _collectedAtMeta,
        collectedAt.isAcceptableOrUnknown(
          data['collected_at']!,
          _collectedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_collectedAtMeta);
    }
    if (data.containsKey('withdrawn_at')) {
      context.handle(
        _withdrawnAtMeta,
        withdrawnAt.isAcceptableOrUnknown(
          data['withdrawn_at']!,
          _withdrawnAtMeta,
        ),
      );
    }
    if (data.containsKey('withdrawn_by_user_id')) {
      context.handle(
        _withdrawnByUserIdMeta,
        withdrawnByUserId.isAcceptableOrUnknown(
          data['withdrawn_by_user_id']!,
          _withdrawnByUserIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConsentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConsentRow(
      version:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}version'],
          )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      beneficiaryId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}beneficiary_id'],
          )!,
      scope:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}scope'],
          )!,
      method:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}method'],
          )!,
      informationVersion:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}information_version'],
          )!,
      collectedByUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collected_by_user_id'],
      ),
      collectedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}collected_at'],
          )!,
      withdrawnAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}withdrawn_at'],
      ),
      withdrawnByUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}withdrawn_by_user_id'],
      ),
    );
  }

  @override
  $ConsentsTable createAlias(String alias) {
    return $ConsentsTable(attachedDatabase, alias);
  }
}

class ConsentRow extends DataClass implements Insertable<ConsentRow> {
  final int version;
  final String? createdAt;
  final String? updatedAt;
  final String? deletedAt;
  final String id;
  final String beneficiaryId;
  final String scope;
  final String method;
  final String informationVersion;
  final String? collectedByUserId;
  final String collectedAt;
  final String? withdrawnAt;
  final String? withdrawnByUserId;
  const ConsentRow({
    required this.version,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    required this.id,
    required this.beneficiaryId,
    required this.scope,
    required this.method,
    required this.informationVersion,
    this.collectedByUserId,
    required this.collectedAt,
    this.withdrawnAt,
    this.withdrawnByUserId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['version'] = Variable<int>(version);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    map['id'] = Variable<String>(id);
    map['beneficiary_id'] = Variable<String>(beneficiaryId);
    map['scope'] = Variable<String>(scope);
    map['method'] = Variable<String>(method);
    map['information_version'] = Variable<String>(informationVersion);
    if (!nullToAbsent || collectedByUserId != null) {
      map['collected_by_user_id'] = Variable<String>(collectedByUserId);
    }
    map['collected_at'] = Variable<String>(collectedAt);
    if (!nullToAbsent || withdrawnAt != null) {
      map['withdrawn_at'] = Variable<String>(withdrawnAt);
    }
    if (!nullToAbsent || withdrawnByUserId != null) {
      map['withdrawn_by_user_id'] = Variable<String>(withdrawnByUserId);
    }
    return map;
  }

  ConsentsCompanion toCompanion(bool nullToAbsent) {
    return ConsentsCompanion(
      version: Value(version),
      createdAt:
          createdAt == null && nullToAbsent
              ? const Value.absent()
              : Value(createdAt),
      updatedAt:
          updatedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(updatedAt),
      deletedAt:
          deletedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(deletedAt),
      id: Value(id),
      beneficiaryId: Value(beneficiaryId),
      scope: Value(scope),
      method: Value(method),
      informationVersion: Value(informationVersion),
      collectedByUserId:
          collectedByUserId == null && nullToAbsent
              ? const Value.absent()
              : Value(collectedByUserId),
      collectedAt: Value(collectedAt),
      withdrawnAt:
          withdrawnAt == null && nullToAbsent
              ? const Value.absent()
              : Value(withdrawnAt),
      withdrawnByUserId:
          withdrawnByUserId == null && nullToAbsent
              ? const Value.absent()
              : Value(withdrawnByUserId),
    );
  }

  factory ConsentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConsentRow(
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<String?>(json['createdAt']),
      updatedAt: serializer.fromJson<String?>(json['updatedAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
      id: serializer.fromJson<String>(json['id']),
      beneficiaryId: serializer.fromJson<String>(json['beneficiaryId']),
      scope: serializer.fromJson<String>(json['scope']),
      method: serializer.fromJson<String>(json['method']),
      informationVersion: serializer.fromJson<String>(
        json['informationVersion'],
      ),
      collectedByUserId: serializer.fromJson<String?>(
        json['collectedByUserId'],
      ),
      collectedAt: serializer.fromJson<String>(json['collectedAt']),
      withdrawnAt: serializer.fromJson<String?>(json['withdrawnAt']),
      withdrawnByUserId: serializer.fromJson<String?>(
        json['withdrawnByUserId'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<String?>(createdAt),
      'updatedAt': serializer.toJson<String?>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
      'id': serializer.toJson<String>(id),
      'beneficiaryId': serializer.toJson<String>(beneficiaryId),
      'scope': serializer.toJson<String>(scope),
      'method': serializer.toJson<String>(method),
      'informationVersion': serializer.toJson<String>(informationVersion),
      'collectedByUserId': serializer.toJson<String?>(collectedByUserId),
      'collectedAt': serializer.toJson<String>(collectedAt),
      'withdrawnAt': serializer.toJson<String?>(withdrawnAt),
      'withdrawnByUserId': serializer.toJson<String?>(withdrawnByUserId),
    };
  }

  ConsentRow copyWith({
    int? version,
    Value<String?> createdAt = const Value.absent(),
    Value<String?> updatedAt = const Value.absent(),
    Value<String?> deletedAt = const Value.absent(),
    String? id,
    String? beneficiaryId,
    String? scope,
    String? method,
    String? informationVersion,
    Value<String?> collectedByUserId = const Value.absent(),
    String? collectedAt,
    Value<String?> withdrawnAt = const Value.absent(),
    Value<String?> withdrawnByUserId = const Value.absent(),
  }) => ConsentRow(
    version: version ?? this.version,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    id: id ?? this.id,
    beneficiaryId: beneficiaryId ?? this.beneficiaryId,
    scope: scope ?? this.scope,
    method: method ?? this.method,
    informationVersion: informationVersion ?? this.informationVersion,
    collectedByUserId:
        collectedByUserId.present
            ? collectedByUserId.value
            : this.collectedByUserId,
    collectedAt: collectedAt ?? this.collectedAt,
    withdrawnAt: withdrawnAt.present ? withdrawnAt.value : this.withdrawnAt,
    withdrawnByUserId:
        withdrawnByUserId.present
            ? withdrawnByUserId.value
            : this.withdrawnByUserId,
  );
  ConsentRow copyWithCompanion(ConsentsCompanion data) {
    return ConsentRow(
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      id: data.id.present ? data.id.value : this.id,
      beneficiaryId:
          data.beneficiaryId.present
              ? data.beneficiaryId.value
              : this.beneficiaryId,
      scope: data.scope.present ? data.scope.value : this.scope,
      method: data.method.present ? data.method.value : this.method,
      informationVersion:
          data.informationVersion.present
              ? data.informationVersion.value
              : this.informationVersion,
      collectedByUserId:
          data.collectedByUserId.present
              ? data.collectedByUserId.value
              : this.collectedByUserId,
      collectedAt:
          data.collectedAt.present ? data.collectedAt.value : this.collectedAt,
      withdrawnAt:
          data.withdrawnAt.present ? data.withdrawnAt.value : this.withdrawnAt,
      withdrawnByUserId:
          data.withdrawnByUserId.present
              ? data.withdrawnByUserId.value
              : this.withdrawnByUserId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConsentRow(')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('beneficiaryId: $beneficiaryId, ')
          ..write('scope: $scope, ')
          ..write('method: $method, ')
          ..write('informationVersion: $informationVersion, ')
          ..write('collectedByUserId: $collectedByUserId, ')
          ..write('collectedAt: $collectedAt, ')
          ..write('withdrawnAt: $withdrawnAt, ')
          ..write('withdrawnByUserId: $withdrawnByUserId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    version,
    createdAt,
    updatedAt,
    deletedAt,
    id,
    beneficiaryId,
    scope,
    method,
    informationVersion,
    collectedByUserId,
    collectedAt,
    withdrawnAt,
    withdrawnByUserId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConsentRow &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.id == this.id &&
          other.beneficiaryId == this.beneficiaryId &&
          other.scope == this.scope &&
          other.method == this.method &&
          other.informationVersion == this.informationVersion &&
          other.collectedByUserId == this.collectedByUserId &&
          other.collectedAt == this.collectedAt &&
          other.withdrawnAt == this.withdrawnAt &&
          other.withdrawnByUserId == this.withdrawnByUserId);
}

class ConsentsCompanion extends UpdateCompanion<ConsentRow> {
  final Value<int> version;
  final Value<String?> createdAt;
  final Value<String?> updatedAt;
  final Value<String?> deletedAt;
  final Value<String> id;
  final Value<String> beneficiaryId;
  final Value<String> scope;
  final Value<String> method;
  final Value<String> informationVersion;
  final Value<String?> collectedByUserId;
  final Value<String> collectedAt;
  final Value<String?> withdrawnAt;
  final Value<String?> withdrawnByUserId;
  final Value<int> rowid;
  const ConsentsCompanion({
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.beneficiaryId = const Value.absent(),
    this.scope = const Value.absent(),
    this.method = const Value.absent(),
    this.informationVersion = const Value.absent(),
    this.collectedByUserId = const Value.absent(),
    this.collectedAt = const Value.absent(),
    this.withdrawnAt = const Value.absent(),
    this.withdrawnByUserId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConsentsCompanion.insert({
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String id,
    required String beneficiaryId,
    required String scope,
    required String method,
    required String informationVersion,
    this.collectedByUserId = const Value.absent(),
    required String collectedAt,
    this.withdrawnAt = const Value.absent(),
    this.withdrawnByUserId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       beneficiaryId = Value(beneficiaryId),
       scope = Value(scope),
       method = Value(method),
       informationVersion = Value(informationVersion),
       collectedAt = Value(collectedAt);
  static Insertable<ConsentRow> custom({
    Expression<int>? version,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<String>? id,
    Expression<String>? beneficiaryId,
    Expression<String>? scope,
    Expression<String>? method,
    Expression<String>? informationVersion,
    Expression<String>? collectedByUserId,
    Expression<String>? collectedAt,
    Expression<String>? withdrawnAt,
    Expression<String>? withdrawnByUserId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (id != null) 'id': id,
      if (beneficiaryId != null) 'beneficiary_id': beneficiaryId,
      if (scope != null) 'scope': scope,
      if (method != null) 'method': method,
      if (informationVersion != null) 'information_version': informationVersion,
      if (collectedByUserId != null) 'collected_by_user_id': collectedByUserId,
      if (collectedAt != null) 'collected_at': collectedAt,
      if (withdrawnAt != null) 'withdrawn_at': withdrawnAt,
      if (withdrawnByUserId != null) 'withdrawn_by_user_id': withdrawnByUserId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConsentsCompanion copyWith({
    Value<int>? version,
    Value<String?>? createdAt,
    Value<String?>? updatedAt,
    Value<String?>? deletedAt,
    Value<String>? id,
    Value<String>? beneficiaryId,
    Value<String>? scope,
    Value<String>? method,
    Value<String>? informationVersion,
    Value<String?>? collectedByUserId,
    Value<String>? collectedAt,
    Value<String?>? withdrawnAt,
    Value<String?>? withdrawnByUserId,
    Value<int>? rowid,
  }) {
    return ConsentsCompanion(
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      id: id ?? this.id,
      beneficiaryId: beneficiaryId ?? this.beneficiaryId,
      scope: scope ?? this.scope,
      method: method ?? this.method,
      informationVersion: informationVersion ?? this.informationVersion,
      collectedByUserId: collectedByUserId ?? this.collectedByUserId,
      collectedAt: collectedAt ?? this.collectedAt,
      withdrawnAt: withdrawnAt ?? this.withdrawnAt,
      withdrawnByUserId: withdrawnByUserId ?? this.withdrawnByUserId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (beneficiaryId.present) {
      map['beneficiary_id'] = Variable<String>(beneficiaryId.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (method.present) {
      map['method'] = Variable<String>(method.value);
    }
    if (informationVersion.present) {
      map['information_version'] = Variable<String>(informationVersion.value);
    }
    if (collectedByUserId.present) {
      map['collected_by_user_id'] = Variable<String>(collectedByUserId.value);
    }
    if (collectedAt.present) {
      map['collected_at'] = Variable<String>(collectedAt.value);
    }
    if (withdrawnAt.present) {
      map['withdrawn_at'] = Variable<String>(withdrawnAt.value);
    }
    if (withdrawnByUserId.present) {
      map['withdrawn_by_user_id'] = Variable<String>(withdrawnByUserId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConsentsCompanion(')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('beneficiaryId: $beneficiaryId, ')
          ..write('scope: $scope, ')
          ..write('method: $method, ')
          ..write('informationVersion: $informationVersion, ')
          ..write('collectedByUserId: $collectedByUserId, ')
          ..write('collectedAt: $collectedAt, ')
          ..write('withdrawnAt: $withdrawnAt, ')
          ..write('withdrawnByUserId: $withdrawnByUserId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PregnanciesTable extends Pregnancies
    with TableInfo<$PregnanciesTable, PregnancyRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PregnanciesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _beneficiaryIdMeta = const VerificationMeta(
    'beneficiaryId',
  );
  @override
  late final GeneratedColumn<String> beneficiaryId = GeneratedColumn<String>(
    'beneficiary_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  static const VerificationMeta _lmpDateMeta = const VerificationMeta(
    'lmpDate',
  );
  @override
  late final GeneratedColumn<String> lmpDate = GeneratedColumn<String>(
    'lmp_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _estimatedDueDateMeta = const VerificationMeta(
    'estimatedDueDate',
  );
  @override
  late final GeneratedColumn<String> estimatedDueDate = GeneratedColumn<String>(
    'estimated_due_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _datesConfirmedByMeta = const VerificationMeta(
    'datesConfirmedBy',
  );
  @override
  late final GeneratedColumn<String> datesConfirmedBy = GeneratedColumn<String>(
    'dates_confirmed_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('ac_declared'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    version,
    createdAt,
    updatedAt,
    deletedAt,
    id,
    beneficiaryId,
    status,
    lmpDate,
    estimatedDueDate,
    datesConfirmedBy,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pregnancies';
  @override
  VerificationContext validateIntegrity(
    Insertable<PregnancyRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
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
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('beneficiary_id')) {
      context.handle(
        _beneficiaryIdMeta,
        beneficiaryId.isAcceptableOrUnknown(
          data['beneficiary_id']!,
          _beneficiaryIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_beneficiaryIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('lmp_date')) {
      context.handle(
        _lmpDateMeta,
        lmpDate.isAcceptableOrUnknown(data['lmp_date']!, _lmpDateMeta),
      );
    }
    if (data.containsKey('estimated_due_date')) {
      context.handle(
        _estimatedDueDateMeta,
        estimatedDueDate.isAcceptableOrUnknown(
          data['estimated_due_date']!,
          _estimatedDueDateMeta,
        ),
      );
    }
    if (data.containsKey('dates_confirmed_by')) {
      context.handle(
        _datesConfirmedByMeta,
        datesConfirmedBy.isAcceptableOrUnknown(
          data['dates_confirmed_by']!,
          _datesConfirmedByMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PregnancyRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PregnancyRow(
      version:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}version'],
          )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      beneficiaryId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}beneficiary_id'],
          )!,
      status:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}status'],
          )!,
      lmpDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lmp_date'],
      ),
      estimatedDueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}estimated_due_date'],
      ),
      datesConfirmedBy:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}dates_confirmed_by'],
          )!,
    );
  }

  @override
  $PregnanciesTable createAlias(String alias) {
    return $PregnanciesTable(attachedDatabase, alias);
  }
}

class PregnancyRow extends DataClass implements Insertable<PregnancyRow> {
  final int version;
  final String? createdAt;
  final String? updatedAt;
  final String? deletedAt;
  final String id;
  final String beneficiaryId;
  final String status;
  final String? lmpDate;
  final String? estimatedDueDate;
  final String datesConfirmedBy;
  const PregnancyRow({
    required this.version,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    required this.id,
    required this.beneficiaryId,
    required this.status,
    this.lmpDate,
    this.estimatedDueDate,
    required this.datesConfirmedBy,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['version'] = Variable<int>(version);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    map['id'] = Variable<String>(id);
    map['beneficiary_id'] = Variable<String>(beneficiaryId);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || lmpDate != null) {
      map['lmp_date'] = Variable<String>(lmpDate);
    }
    if (!nullToAbsent || estimatedDueDate != null) {
      map['estimated_due_date'] = Variable<String>(estimatedDueDate);
    }
    map['dates_confirmed_by'] = Variable<String>(datesConfirmedBy);
    return map;
  }

  PregnanciesCompanion toCompanion(bool nullToAbsent) {
    return PregnanciesCompanion(
      version: Value(version),
      createdAt:
          createdAt == null && nullToAbsent
              ? const Value.absent()
              : Value(createdAt),
      updatedAt:
          updatedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(updatedAt),
      deletedAt:
          deletedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(deletedAt),
      id: Value(id),
      beneficiaryId: Value(beneficiaryId),
      status: Value(status),
      lmpDate:
          lmpDate == null && nullToAbsent
              ? const Value.absent()
              : Value(lmpDate),
      estimatedDueDate:
          estimatedDueDate == null && nullToAbsent
              ? const Value.absent()
              : Value(estimatedDueDate),
      datesConfirmedBy: Value(datesConfirmedBy),
    );
  }

  factory PregnancyRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PregnancyRow(
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<String?>(json['createdAt']),
      updatedAt: serializer.fromJson<String?>(json['updatedAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
      id: serializer.fromJson<String>(json['id']),
      beneficiaryId: serializer.fromJson<String>(json['beneficiaryId']),
      status: serializer.fromJson<String>(json['status']),
      lmpDate: serializer.fromJson<String?>(json['lmpDate']),
      estimatedDueDate: serializer.fromJson<String?>(json['estimatedDueDate']),
      datesConfirmedBy: serializer.fromJson<String>(json['datesConfirmedBy']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<String?>(createdAt),
      'updatedAt': serializer.toJson<String?>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
      'id': serializer.toJson<String>(id),
      'beneficiaryId': serializer.toJson<String>(beneficiaryId),
      'status': serializer.toJson<String>(status),
      'lmpDate': serializer.toJson<String?>(lmpDate),
      'estimatedDueDate': serializer.toJson<String?>(estimatedDueDate),
      'datesConfirmedBy': serializer.toJson<String>(datesConfirmedBy),
    };
  }

  PregnancyRow copyWith({
    int? version,
    Value<String?> createdAt = const Value.absent(),
    Value<String?> updatedAt = const Value.absent(),
    Value<String?> deletedAt = const Value.absent(),
    String? id,
    String? beneficiaryId,
    String? status,
    Value<String?> lmpDate = const Value.absent(),
    Value<String?> estimatedDueDate = const Value.absent(),
    String? datesConfirmedBy,
  }) => PregnancyRow(
    version: version ?? this.version,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    id: id ?? this.id,
    beneficiaryId: beneficiaryId ?? this.beneficiaryId,
    status: status ?? this.status,
    lmpDate: lmpDate.present ? lmpDate.value : this.lmpDate,
    estimatedDueDate:
        estimatedDueDate.present
            ? estimatedDueDate.value
            : this.estimatedDueDate,
    datesConfirmedBy: datesConfirmedBy ?? this.datesConfirmedBy,
  );
  PregnancyRow copyWithCompanion(PregnanciesCompanion data) {
    return PregnancyRow(
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      id: data.id.present ? data.id.value : this.id,
      beneficiaryId:
          data.beneficiaryId.present
              ? data.beneficiaryId.value
              : this.beneficiaryId,
      status: data.status.present ? data.status.value : this.status,
      lmpDate: data.lmpDate.present ? data.lmpDate.value : this.lmpDate,
      estimatedDueDate:
          data.estimatedDueDate.present
              ? data.estimatedDueDate.value
              : this.estimatedDueDate,
      datesConfirmedBy:
          data.datesConfirmedBy.present
              ? data.datesConfirmedBy.value
              : this.datesConfirmedBy,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PregnancyRow(')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('beneficiaryId: $beneficiaryId, ')
          ..write('status: $status, ')
          ..write('lmpDate: $lmpDate, ')
          ..write('estimatedDueDate: $estimatedDueDate, ')
          ..write('datesConfirmedBy: $datesConfirmedBy')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    version,
    createdAt,
    updatedAt,
    deletedAt,
    id,
    beneficiaryId,
    status,
    lmpDate,
    estimatedDueDate,
    datesConfirmedBy,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PregnancyRow &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.id == this.id &&
          other.beneficiaryId == this.beneficiaryId &&
          other.status == this.status &&
          other.lmpDate == this.lmpDate &&
          other.estimatedDueDate == this.estimatedDueDate &&
          other.datesConfirmedBy == this.datesConfirmedBy);
}

class PregnanciesCompanion extends UpdateCompanion<PregnancyRow> {
  final Value<int> version;
  final Value<String?> createdAt;
  final Value<String?> updatedAt;
  final Value<String?> deletedAt;
  final Value<String> id;
  final Value<String> beneficiaryId;
  final Value<String> status;
  final Value<String?> lmpDate;
  final Value<String?> estimatedDueDate;
  final Value<String> datesConfirmedBy;
  final Value<int> rowid;
  const PregnanciesCompanion({
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.beneficiaryId = const Value.absent(),
    this.status = const Value.absent(),
    this.lmpDate = const Value.absent(),
    this.estimatedDueDate = const Value.absent(),
    this.datesConfirmedBy = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PregnanciesCompanion.insert({
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String id,
    required String beneficiaryId,
    this.status = const Value.absent(),
    this.lmpDate = const Value.absent(),
    this.estimatedDueDate = const Value.absent(),
    this.datesConfirmedBy = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       beneficiaryId = Value(beneficiaryId);
  static Insertable<PregnancyRow> custom({
    Expression<int>? version,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<String>? id,
    Expression<String>? beneficiaryId,
    Expression<String>? status,
    Expression<String>? lmpDate,
    Expression<String>? estimatedDueDate,
    Expression<String>? datesConfirmedBy,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (id != null) 'id': id,
      if (beneficiaryId != null) 'beneficiary_id': beneficiaryId,
      if (status != null) 'status': status,
      if (lmpDate != null) 'lmp_date': lmpDate,
      if (estimatedDueDate != null) 'estimated_due_date': estimatedDueDate,
      if (datesConfirmedBy != null) 'dates_confirmed_by': datesConfirmedBy,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PregnanciesCompanion copyWith({
    Value<int>? version,
    Value<String?>? createdAt,
    Value<String?>? updatedAt,
    Value<String?>? deletedAt,
    Value<String>? id,
    Value<String>? beneficiaryId,
    Value<String>? status,
    Value<String?>? lmpDate,
    Value<String?>? estimatedDueDate,
    Value<String>? datesConfirmedBy,
    Value<int>? rowid,
  }) {
    return PregnanciesCompanion(
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      id: id ?? this.id,
      beneficiaryId: beneficiaryId ?? this.beneficiaryId,
      status: status ?? this.status,
      lmpDate: lmpDate ?? this.lmpDate,
      estimatedDueDate: estimatedDueDate ?? this.estimatedDueDate,
      datesConfirmedBy: datesConfirmedBy ?? this.datesConfirmedBy,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (beneficiaryId.present) {
      map['beneficiary_id'] = Variable<String>(beneficiaryId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (lmpDate.present) {
      map['lmp_date'] = Variable<String>(lmpDate.value);
    }
    if (estimatedDueDate.present) {
      map['estimated_due_date'] = Variable<String>(estimatedDueDate.value);
    }
    if (datesConfirmedBy.present) {
      map['dates_confirmed_by'] = Variable<String>(datesConfirmedBy.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PregnanciesCompanion(')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('beneficiaryId: $beneficiaryId, ')
          ..write('status: $status, ')
          ..write('lmpDate: $lmpDate, ')
          ..write('estimatedDueDate: $estimatedDueDate, ')
          ..write('datesConfirmedBy: $datesConfirmedBy, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AncVisitsTable extends AncVisits
    with TableInfo<$AncVisitsTable, AncVisitRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AncVisitsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pregnancyIdMeta = const VerificationMeta(
    'pregnancyId',
  );
  @override
  late final GeneratedColumn<String> pregnancyId = GeneratedColumn<String>(
    'pregnancy_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sequenceMeta = const VerificationMeta(
    'sequence',
  );
  @override
  late final GeneratedColumn<int> sequence = GeneratedColumn<int>(
    'sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scheduledDateMeta = const VerificationMeta(
    'scheduledDate',
  );
  @override
  late final GeneratedColumn<String> scheduledDate = GeneratedColumn<String>(
    'scheduled_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('planned'),
  );
  static const VerificationMeta _doneDateMeta = const VerificationMeta(
    'doneDate',
  );
  @override
  late final GeneratedColumn<String> doneDate = GeneratedColumn<String>(
    'done_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _siteIdMeta = const VerificationMeta('siteId');
  @override
  late final GeneratedColumn<String> siteId = GeneratedColumn<String>(
    'site_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    version,
    createdAt,
    updatedAt,
    deletedAt,
    id,
    pregnancyId,
    sequence,
    scheduledDate,
    status,
    doneDate,
    siteId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'anc_visits';
  @override
  VerificationContext validateIntegrity(
    Insertable<AncVisitRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
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
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('pregnancy_id')) {
      context.handle(
        _pregnancyIdMeta,
        pregnancyId.isAcceptableOrUnknown(
          data['pregnancy_id']!,
          _pregnancyIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_pregnancyIdMeta);
    }
    if (data.containsKey('sequence')) {
      context.handle(
        _sequenceMeta,
        sequence.isAcceptableOrUnknown(data['sequence']!, _sequenceMeta),
      );
    } else if (isInserting) {
      context.missing(_sequenceMeta);
    }
    if (data.containsKey('scheduled_date')) {
      context.handle(
        _scheduledDateMeta,
        scheduledDate.isAcceptableOrUnknown(
          data['scheduled_date']!,
          _scheduledDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduledDateMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('done_date')) {
      context.handle(
        _doneDateMeta,
        doneDate.isAcceptableOrUnknown(data['done_date']!, _doneDateMeta),
      );
    }
    if (data.containsKey('site_id')) {
      context.handle(
        _siteIdMeta,
        siteId.isAcceptableOrUnknown(data['site_id']!, _siteIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AncVisitRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AncVisitRow(
      version:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}version'],
          )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      pregnancyId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}pregnancy_id'],
          )!,
      sequence:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}sequence'],
          )!,
      scheduledDate:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}scheduled_date'],
          )!,
      status:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}status'],
          )!,
      doneDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}done_date'],
      ),
      siteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}site_id'],
      ),
    );
  }

  @override
  $AncVisitsTable createAlias(String alias) {
    return $AncVisitsTable(attachedDatabase, alias);
  }
}

class AncVisitRow extends DataClass implements Insertable<AncVisitRow> {
  final int version;
  final String? createdAt;
  final String? updatedAt;
  final String? deletedAt;
  final String id;
  final String pregnancyId;
  final int sequence;
  final String scheduledDate;
  final String status;
  final String? doneDate;
  final String? siteId;
  const AncVisitRow({
    required this.version,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    required this.id,
    required this.pregnancyId,
    required this.sequence,
    required this.scheduledDate,
    required this.status,
    this.doneDate,
    this.siteId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['version'] = Variable<int>(version);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    map['id'] = Variable<String>(id);
    map['pregnancy_id'] = Variable<String>(pregnancyId);
    map['sequence'] = Variable<int>(sequence);
    map['scheduled_date'] = Variable<String>(scheduledDate);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || doneDate != null) {
      map['done_date'] = Variable<String>(doneDate);
    }
    if (!nullToAbsent || siteId != null) {
      map['site_id'] = Variable<String>(siteId);
    }
    return map;
  }

  AncVisitsCompanion toCompanion(bool nullToAbsent) {
    return AncVisitsCompanion(
      version: Value(version),
      createdAt:
          createdAt == null && nullToAbsent
              ? const Value.absent()
              : Value(createdAt),
      updatedAt:
          updatedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(updatedAt),
      deletedAt:
          deletedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(deletedAt),
      id: Value(id),
      pregnancyId: Value(pregnancyId),
      sequence: Value(sequence),
      scheduledDate: Value(scheduledDate),
      status: Value(status),
      doneDate:
          doneDate == null && nullToAbsent
              ? const Value.absent()
              : Value(doneDate),
      siteId:
          siteId == null && nullToAbsent ? const Value.absent() : Value(siteId),
    );
  }

  factory AncVisitRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AncVisitRow(
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<String?>(json['createdAt']),
      updatedAt: serializer.fromJson<String?>(json['updatedAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
      id: serializer.fromJson<String>(json['id']),
      pregnancyId: serializer.fromJson<String>(json['pregnancyId']),
      sequence: serializer.fromJson<int>(json['sequence']),
      scheduledDate: serializer.fromJson<String>(json['scheduledDate']),
      status: serializer.fromJson<String>(json['status']),
      doneDate: serializer.fromJson<String?>(json['doneDate']),
      siteId: serializer.fromJson<String?>(json['siteId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<String?>(createdAt),
      'updatedAt': serializer.toJson<String?>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
      'id': serializer.toJson<String>(id),
      'pregnancyId': serializer.toJson<String>(pregnancyId),
      'sequence': serializer.toJson<int>(sequence),
      'scheduledDate': serializer.toJson<String>(scheduledDate),
      'status': serializer.toJson<String>(status),
      'doneDate': serializer.toJson<String?>(doneDate),
      'siteId': serializer.toJson<String?>(siteId),
    };
  }

  AncVisitRow copyWith({
    int? version,
    Value<String?> createdAt = const Value.absent(),
    Value<String?> updatedAt = const Value.absent(),
    Value<String?> deletedAt = const Value.absent(),
    String? id,
    String? pregnancyId,
    int? sequence,
    String? scheduledDate,
    String? status,
    Value<String?> doneDate = const Value.absent(),
    Value<String?> siteId = const Value.absent(),
  }) => AncVisitRow(
    version: version ?? this.version,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    id: id ?? this.id,
    pregnancyId: pregnancyId ?? this.pregnancyId,
    sequence: sequence ?? this.sequence,
    scheduledDate: scheduledDate ?? this.scheduledDate,
    status: status ?? this.status,
    doneDate: doneDate.present ? doneDate.value : this.doneDate,
    siteId: siteId.present ? siteId.value : this.siteId,
  );
  AncVisitRow copyWithCompanion(AncVisitsCompanion data) {
    return AncVisitRow(
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      id: data.id.present ? data.id.value : this.id,
      pregnancyId:
          data.pregnancyId.present ? data.pregnancyId.value : this.pregnancyId,
      sequence: data.sequence.present ? data.sequence.value : this.sequence,
      scheduledDate:
          data.scheduledDate.present
              ? data.scheduledDate.value
              : this.scheduledDate,
      status: data.status.present ? data.status.value : this.status,
      doneDate: data.doneDate.present ? data.doneDate.value : this.doneDate,
      siteId: data.siteId.present ? data.siteId.value : this.siteId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AncVisitRow(')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('pregnancyId: $pregnancyId, ')
          ..write('sequence: $sequence, ')
          ..write('scheduledDate: $scheduledDate, ')
          ..write('status: $status, ')
          ..write('doneDate: $doneDate, ')
          ..write('siteId: $siteId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    version,
    createdAt,
    updatedAt,
    deletedAt,
    id,
    pregnancyId,
    sequence,
    scheduledDate,
    status,
    doneDate,
    siteId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AncVisitRow &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.id == this.id &&
          other.pregnancyId == this.pregnancyId &&
          other.sequence == this.sequence &&
          other.scheduledDate == this.scheduledDate &&
          other.status == this.status &&
          other.doneDate == this.doneDate &&
          other.siteId == this.siteId);
}

class AncVisitsCompanion extends UpdateCompanion<AncVisitRow> {
  final Value<int> version;
  final Value<String?> createdAt;
  final Value<String?> updatedAt;
  final Value<String?> deletedAt;
  final Value<String> id;
  final Value<String> pregnancyId;
  final Value<int> sequence;
  final Value<String> scheduledDate;
  final Value<String> status;
  final Value<String?> doneDate;
  final Value<String?> siteId;
  final Value<int> rowid;
  const AncVisitsCompanion({
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.pregnancyId = const Value.absent(),
    this.sequence = const Value.absent(),
    this.scheduledDate = const Value.absent(),
    this.status = const Value.absent(),
    this.doneDate = const Value.absent(),
    this.siteId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AncVisitsCompanion.insert({
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String id,
    required String pregnancyId,
    required int sequence,
    required String scheduledDate,
    this.status = const Value.absent(),
    this.doneDate = const Value.absent(),
    this.siteId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       pregnancyId = Value(pregnancyId),
       sequence = Value(sequence),
       scheduledDate = Value(scheduledDate);
  static Insertable<AncVisitRow> custom({
    Expression<int>? version,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<String>? id,
    Expression<String>? pregnancyId,
    Expression<int>? sequence,
    Expression<String>? scheduledDate,
    Expression<String>? status,
    Expression<String>? doneDate,
    Expression<String>? siteId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (id != null) 'id': id,
      if (pregnancyId != null) 'pregnancy_id': pregnancyId,
      if (sequence != null) 'sequence': sequence,
      if (scheduledDate != null) 'scheduled_date': scheduledDate,
      if (status != null) 'status': status,
      if (doneDate != null) 'done_date': doneDate,
      if (siteId != null) 'site_id': siteId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AncVisitsCompanion copyWith({
    Value<int>? version,
    Value<String?>? createdAt,
    Value<String?>? updatedAt,
    Value<String?>? deletedAt,
    Value<String>? id,
    Value<String>? pregnancyId,
    Value<int>? sequence,
    Value<String>? scheduledDate,
    Value<String>? status,
    Value<String?>? doneDate,
    Value<String?>? siteId,
    Value<int>? rowid,
  }) {
    return AncVisitsCompanion(
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      id: id ?? this.id,
      pregnancyId: pregnancyId ?? this.pregnancyId,
      sequence: sequence ?? this.sequence,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      status: status ?? this.status,
      doneDate: doneDate ?? this.doneDate,
      siteId: siteId ?? this.siteId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (pregnancyId.present) {
      map['pregnancy_id'] = Variable<String>(pregnancyId.value);
    }
    if (sequence.present) {
      map['sequence'] = Variable<int>(sequence.value);
    }
    if (scheduledDate.present) {
      map['scheduled_date'] = Variable<String>(scheduledDate.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (doneDate.present) {
      map['done_date'] = Variable<String>(doneDate.value);
    }
    if (siteId.present) {
      map['site_id'] = Variable<String>(siteId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AncVisitsCompanion(')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('pregnancyId: $pregnancyId, ')
          ..write('sequence: $sequence, ')
          ..write('scheduledDate: $scheduledDate, ')
          ..write('status: $status, ')
          ..write('doneDate: $doneDate, ')
          ..write('siteId: $siteId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReferralsTable extends Referrals
    with TableInfo<$ReferralsTable, ReferralRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReferralsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _beneficiaryIdMeta = const VerificationMeta(
    'beneficiaryId',
  );
  @override
  late final GeneratedColumn<String> beneficiaryId = GeneratedColumn<String>(
    'beneficiary_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _alertIdMeta = const VerificationMeta(
    'alertId',
  );
  @override
  late final GeneratedColumn<String> alertId = GeneratedColumn<String>(
    'alert_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fromSiteIdMeta = const VerificationMeta(
    'fromSiteId',
  );
  @override
  late final GeneratedColumn<String> fromSiteId = GeneratedColumn<String>(
    'from_site_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _toSiteIdMeta = const VerificationMeta(
    'toSiteId',
  );
  @override
  late final GeneratedColumn<String> toSiteId = GeneratedColumn<String>(
    'to_site_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('proposed'),
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _outcomeNoteMeta = const VerificationMeta(
    'outcomeNote',
  );
  @override
  late final GeneratedColumn<String> outcomeNote = GeneratedColumn<String>(
    'outcome_note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    version,
    createdAt,
    updatedAt,
    deletedAt,
    id,
    beneficiaryId,
    alertId,
    fromSiteId,
    toSiteId,
    status,
    reason,
    outcomeNote,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'referrals';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReferralRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
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
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('beneficiary_id')) {
      context.handle(
        _beneficiaryIdMeta,
        beneficiaryId.isAcceptableOrUnknown(
          data['beneficiary_id']!,
          _beneficiaryIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_beneficiaryIdMeta);
    }
    if (data.containsKey('alert_id')) {
      context.handle(
        _alertIdMeta,
        alertId.isAcceptableOrUnknown(data['alert_id']!, _alertIdMeta),
      );
    }
    if (data.containsKey('from_site_id')) {
      context.handle(
        _fromSiteIdMeta,
        fromSiteId.isAcceptableOrUnknown(
          data['from_site_id']!,
          _fromSiteIdMeta,
        ),
      );
    }
    if (data.containsKey('to_site_id')) {
      context.handle(
        _toSiteIdMeta,
        toSiteId.isAcceptableOrUnknown(data['to_site_id']!, _toSiteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_toSiteIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    }
    if (data.containsKey('outcome_note')) {
      context.handle(
        _outcomeNoteMeta,
        outcomeNote.isAcceptableOrUnknown(
          data['outcome_note']!,
          _outcomeNoteMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReferralRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReferralRow(
      version:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}version'],
          )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      beneficiaryId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}beneficiary_id'],
          )!,
      alertId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alert_id'],
      ),
      fromSiteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_site_id'],
      ),
      toSiteId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}to_site_id'],
          )!,
      status:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}status'],
          )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      ),
      outcomeNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}outcome_note'],
      ),
    );
  }

  @override
  $ReferralsTable createAlias(String alias) {
    return $ReferralsTable(attachedDatabase, alias);
  }
}

class ReferralRow extends DataClass implements Insertable<ReferralRow> {
  final int version;
  final String? createdAt;
  final String? updatedAt;
  final String? deletedAt;
  final String id;
  final String beneficiaryId;
  final String? alertId;
  final String? fromSiteId;
  final String toSiteId;
  final String status;
  final String? reason;
  final String? outcomeNote;
  const ReferralRow({
    required this.version,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    required this.id,
    required this.beneficiaryId,
    this.alertId,
    this.fromSiteId,
    required this.toSiteId,
    required this.status,
    this.reason,
    this.outcomeNote,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['version'] = Variable<int>(version);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    map['id'] = Variable<String>(id);
    map['beneficiary_id'] = Variable<String>(beneficiaryId);
    if (!nullToAbsent || alertId != null) {
      map['alert_id'] = Variable<String>(alertId);
    }
    if (!nullToAbsent || fromSiteId != null) {
      map['from_site_id'] = Variable<String>(fromSiteId);
    }
    map['to_site_id'] = Variable<String>(toSiteId);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || reason != null) {
      map['reason'] = Variable<String>(reason);
    }
    if (!nullToAbsent || outcomeNote != null) {
      map['outcome_note'] = Variable<String>(outcomeNote);
    }
    return map;
  }

  ReferralsCompanion toCompanion(bool nullToAbsent) {
    return ReferralsCompanion(
      version: Value(version),
      createdAt:
          createdAt == null && nullToAbsent
              ? const Value.absent()
              : Value(createdAt),
      updatedAt:
          updatedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(updatedAt),
      deletedAt:
          deletedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(deletedAt),
      id: Value(id),
      beneficiaryId: Value(beneficiaryId),
      alertId:
          alertId == null && nullToAbsent
              ? const Value.absent()
              : Value(alertId),
      fromSiteId:
          fromSiteId == null && nullToAbsent
              ? const Value.absent()
              : Value(fromSiteId),
      toSiteId: Value(toSiteId),
      status: Value(status),
      reason:
          reason == null && nullToAbsent ? const Value.absent() : Value(reason),
      outcomeNote:
          outcomeNote == null && nullToAbsent
              ? const Value.absent()
              : Value(outcomeNote),
    );
  }

  factory ReferralRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReferralRow(
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<String?>(json['createdAt']),
      updatedAt: serializer.fromJson<String?>(json['updatedAt']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
      id: serializer.fromJson<String>(json['id']),
      beneficiaryId: serializer.fromJson<String>(json['beneficiaryId']),
      alertId: serializer.fromJson<String?>(json['alertId']),
      fromSiteId: serializer.fromJson<String?>(json['fromSiteId']),
      toSiteId: serializer.fromJson<String>(json['toSiteId']),
      status: serializer.fromJson<String>(json['status']),
      reason: serializer.fromJson<String?>(json['reason']),
      outcomeNote: serializer.fromJson<String?>(json['outcomeNote']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<String?>(createdAt),
      'updatedAt': serializer.toJson<String?>(updatedAt),
      'deletedAt': serializer.toJson<String?>(deletedAt),
      'id': serializer.toJson<String>(id),
      'beneficiaryId': serializer.toJson<String>(beneficiaryId),
      'alertId': serializer.toJson<String?>(alertId),
      'fromSiteId': serializer.toJson<String?>(fromSiteId),
      'toSiteId': serializer.toJson<String>(toSiteId),
      'status': serializer.toJson<String>(status),
      'reason': serializer.toJson<String?>(reason),
      'outcomeNote': serializer.toJson<String?>(outcomeNote),
    };
  }

  ReferralRow copyWith({
    int? version,
    Value<String?> createdAt = const Value.absent(),
    Value<String?> updatedAt = const Value.absent(),
    Value<String?> deletedAt = const Value.absent(),
    String? id,
    String? beneficiaryId,
    Value<String?> alertId = const Value.absent(),
    Value<String?> fromSiteId = const Value.absent(),
    String? toSiteId,
    String? status,
    Value<String?> reason = const Value.absent(),
    Value<String?> outcomeNote = const Value.absent(),
  }) => ReferralRow(
    version: version ?? this.version,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    id: id ?? this.id,
    beneficiaryId: beneficiaryId ?? this.beneficiaryId,
    alertId: alertId.present ? alertId.value : this.alertId,
    fromSiteId: fromSiteId.present ? fromSiteId.value : this.fromSiteId,
    toSiteId: toSiteId ?? this.toSiteId,
    status: status ?? this.status,
    reason: reason.present ? reason.value : this.reason,
    outcomeNote: outcomeNote.present ? outcomeNote.value : this.outcomeNote,
  );
  ReferralRow copyWithCompanion(ReferralsCompanion data) {
    return ReferralRow(
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      id: data.id.present ? data.id.value : this.id,
      beneficiaryId:
          data.beneficiaryId.present
              ? data.beneficiaryId.value
              : this.beneficiaryId,
      alertId: data.alertId.present ? data.alertId.value : this.alertId,
      fromSiteId:
          data.fromSiteId.present ? data.fromSiteId.value : this.fromSiteId,
      toSiteId: data.toSiteId.present ? data.toSiteId.value : this.toSiteId,
      status: data.status.present ? data.status.value : this.status,
      reason: data.reason.present ? data.reason.value : this.reason,
      outcomeNote:
          data.outcomeNote.present ? data.outcomeNote.value : this.outcomeNote,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReferralRow(')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('beneficiaryId: $beneficiaryId, ')
          ..write('alertId: $alertId, ')
          ..write('fromSiteId: $fromSiteId, ')
          ..write('toSiteId: $toSiteId, ')
          ..write('status: $status, ')
          ..write('reason: $reason, ')
          ..write('outcomeNote: $outcomeNote')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    version,
    createdAt,
    updatedAt,
    deletedAt,
    id,
    beneficiaryId,
    alertId,
    fromSiteId,
    toSiteId,
    status,
    reason,
    outcomeNote,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReferralRow &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.id == this.id &&
          other.beneficiaryId == this.beneficiaryId &&
          other.alertId == this.alertId &&
          other.fromSiteId == this.fromSiteId &&
          other.toSiteId == this.toSiteId &&
          other.status == this.status &&
          other.reason == this.reason &&
          other.outcomeNote == this.outcomeNote);
}

class ReferralsCompanion extends UpdateCompanion<ReferralRow> {
  final Value<int> version;
  final Value<String?> createdAt;
  final Value<String?> updatedAt;
  final Value<String?> deletedAt;
  final Value<String> id;
  final Value<String> beneficiaryId;
  final Value<String?> alertId;
  final Value<String?> fromSiteId;
  final Value<String> toSiteId;
  final Value<String> status;
  final Value<String?> reason;
  final Value<String?> outcomeNote;
  final Value<int> rowid;
  const ReferralsCompanion({
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.beneficiaryId = const Value.absent(),
    this.alertId = const Value.absent(),
    this.fromSiteId = const Value.absent(),
    this.toSiteId = const Value.absent(),
    this.status = const Value.absent(),
    this.reason = const Value.absent(),
    this.outcomeNote = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReferralsCompanion.insert({
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String id,
    required String beneficiaryId,
    this.alertId = const Value.absent(),
    this.fromSiteId = const Value.absent(),
    required String toSiteId,
    this.status = const Value.absent(),
    this.reason = const Value.absent(),
    this.outcomeNote = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       beneficiaryId = Value(beneficiaryId),
       toSiteId = Value(toSiteId);
  static Insertable<ReferralRow> custom({
    Expression<int>? version,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<String>? id,
    Expression<String>? beneficiaryId,
    Expression<String>? alertId,
    Expression<String>? fromSiteId,
    Expression<String>? toSiteId,
    Expression<String>? status,
    Expression<String>? reason,
    Expression<String>? outcomeNote,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (id != null) 'id': id,
      if (beneficiaryId != null) 'beneficiary_id': beneficiaryId,
      if (alertId != null) 'alert_id': alertId,
      if (fromSiteId != null) 'from_site_id': fromSiteId,
      if (toSiteId != null) 'to_site_id': toSiteId,
      if (status != null) 'status': status,
      if (reason != null) 'reason': reason,
      if (outcomeNote != null) 'outcome_note': outcomeNote,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReferralsCompanion copyWith({
    Value<int>? version,
    Value<String?>? createdAt,
    Value<String?>? updatedAt,
    Value<String?>? deletedAt,
    Value<String>? id,
    Value<String>? beneficiaryId,
    Value<String?>? alertId,
    Value<String?>? fromSiteId,
    Value<String>? toSiteId,
    Value<String>? status,
    Value<String?>? reason,
    Value<String?>? outcomeNote,
    Value<int>? rowid,
  }) {
    return ReferralsCompanion(
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      id: id ?? this.id,
      beneficiaryId: beneficiaryId ?? this.beneficiaryId,
      alertId: alertId ?? this.alertId,
      fromSiteId: fromSiteId ?? this.fromSiteId,
      toSiteId: toSiteId ?? this.toSiteId,
      status: status ?? this.status,
      reason: reason ?? this.reason,
      outcomeNote: outcomeNote ?? this.outcomeNote,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (beneficiaryId.present) {
      map['beneficiary_id'] = Variable<String>(beneficiaryId.value);
    }
    if (alertId.present) {
      map['alert_id'] = Variable<String>(alertId.value);
    }
    if (fromSiteId.present) {
      map['from_site_id'] = Variable<String>(fromSiteId.value);
    }
    if (toSiteId.present) {
      map['to_site_id'] = Variable<String>(toSiteId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (outcomeNote.present) {
      map['outcome_note'] = Variable<String>(outcomeNote.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReferralsCompanion(')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('beneficiaryId: $beneficiaryId, ')
          ..write('alertId: $alertId, ')
          ..write('fromSiteId: $fromSiteId, ')
          ..write('toSiteId: $toSiteId, ')
          ..write('status: $status, ')
          ..write('reason: $reason, ')
          ..write('outcomeNote: $outcomeNote, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AlertsTable extends Alerts with TableInfo<$AlertsTable, AlertRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AlertsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _beneficiaryIdMeta = const VerificationMeta(
    'beneficiaryId',
  );
  @override
  late final GeneratedColumn<String> beneficiaryId = GeneratedColumn<String>(
    'beneficiary_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _interactionIdMeta = const VerificationMeta(
    'interactionId',
  );
  @override
  late final GeneratedColumn<String> interactionId = GeneratedColumn<String>(
    'interaction_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ruleIdMeta = const VerificationMeta('ruleId');
  @override
  late final GeneratedColumn<String> ruleId = GeneratedColumn<String>(
    'rule_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rulesetVersionMeta = const VerificationMeta(
    'rulesetVersion',
  );
  @override
  late final GeneratedColumn<String> rulesetVersion = GeneratedColumn<String>(
    'ruleset_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _severityMeta = const VerificationMeta(
    'severity',
  );
  @override
  late final GeneratedColumn<String> severity = GeneratedColumn<String>(
    'severity',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('open'),
  );
  static const VerificationMeta _recipientUserIdMeta = const VerificationMeta(
    'recipientUserId',
  );
  @override
  late final GeneratedColumn<String> recipientUserId = GeneratedColumn<String>(
    'recipient_user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _backupUserIdMeta = const VerificationMeta(
    'backupUserId',
  );
  @override
  late final GeneratedColumn<String> backupUserId = GeneratedColumn<String>(
    'backup_user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueAtMeta = const VerificationMeta('dueAt');
  @override
  late final GeneratedColumn<String> dueAt = GeneratedColumn<String>(
    'due_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _acknowledgedAtMeta = const VerificationMeta(
    'acknowledgedAt',
  );
  @override
  late final GeneratedColumn<String> acknowledgedAt = GeneratedColumn<String>(
    'acknowledged_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resolvedAtMeta = const VerificationMeta(
    'resolvedAt',
  );
  @override
  late final GeneratedColumn<String> resolvedAt = GeneratedColumn<String>(
    'resolved_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDemoMeta = const VerificationMeta('isDemo');
  @override
  late final GeneratedColumn<bool> isDemo = GeneratedColumn<bool>(
    'is_demo',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_demo" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    beneficiaryId,
    interactionId,
    ruleId,
    rulesetVersion,
    severity,
    status,
    recipientUserId,
    backupUserId,
    dueAt,
    acknowledgedAt,
    resolvedAt,
    isDemo,
    createdAt,
    version,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'alerts';
  @override
  VerificationContext validateIntegrity(
    Insertable<AlertRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('beneficiary_id')) {
      context.handle(
        _beneficiaryIdMeta,
        beneficiaryId.isAcceptableOrUnknown(
          data['beneficiary_id']!,
          _beneficiaryIdMeta,
        ),
      );
    }
    if (data.containsKey('interaction_id')) {
      context.handle(
        _interactionIdMeta,
        interactionId.isAcceptableOrUnknown(
          data['interaction_id']!,
          _interactionIdMeta,
        ),
      );
    }
    if (data.containsKey('rule_id')) {
      context.handle(
        _ruleIdMeta,
        ruleId.isAcceptableOrUnknown(data['rule_id']!, _ruleIdMeta),
      );
    }
    if (data.containsKey('ruleset_version')) {
      context.handle(
        _rulesetVersionMeta,
        rulesetVersion.isAcceptableOrUnknown(
          data['ruleset_version']!,
          _rulesetVersionMeta,
        ),
      );
    }
    if (data.containsKey('severity')) {
      context.handle(
        _severityMeta,
        severity.isAcceptableOrUnknown(data['severity']!, _severityMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('recipient_user_id')) {
      context.handle(
        _recipientUserIdMeta,
        recipientUserId.isAcceptableOrUnknown(
          data['recipient_user_id']!,
          _recipientUserIdMeta,
        ),
      );
    }
    if (data.containsKey('backup_user_id')) {
      context.handle(
        _backupUserIdMeta,
        backupUserId.isAcceptableOrUnknown(
          data['backup_user_id']!,
          _backupUserIdMeta,
        ),
      );
    }
    if (data.containsKey('due_at')) {
      context.handle(
        _dueAtMeta,
        dueAt.isAcceptableOrUnknown(data['due_at']!, _dueAtMeta),
      );
    }
    if (data.containsKey('acknowledged_at')) {
      context.handle(
        _acknowledgedAtMeta,
        acknowledgedAt.isAcceptableOrUnknown(
          data['acknowledged_at']!,
          _acknowledgedAtMeta,
        ),
      );
    }
    if (data.containsKey('resolved_at')) {
      context.handle(
        _resolvedAtMeta,
        resolvedAt.isAcceptableOrUnknown(data['resolved_at']!, _resolvedAtMeta),
      );
    }
    if (data.containsKey('is_demo')) {
      context.handle(
        _isDemoMeta,
        isDemo.isAcceptableOrUnknown(data['is_demo']!, _isDemoMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
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
  AlertRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AlertRow(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      beneficiaryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}beneficiary_id'],
      ),
      interactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}interaction_id'],
      ),
      ruleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rule_id'],
      ),
      rulesetVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ruleset_version'],
      ),
      severity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}severity'],
      ),
      status:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}status'],
          )!,
      recipientUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipient_user_id'],
      ),
      backupUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}backup_user_id'],
      ),
      dueAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}due_at'],
      ),
      acknowledgedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}acknowledged_at'],
      ),
      resolvedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resolved_at'],
      ),
      isDemo:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_demo'],
          )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      ),
      version:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}version'],
          )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $AlertsTable createAlias(String alias) {
    return $AlertsTable(attachedDatabase, alias);
  }
}

class AlertRow extends DataClass implements Insertable<AlertRow> {
  final String id;
  final String? beneficiaryId;
  final String? interactionId;
  final String? ruleId;
  final String? rulesetVersion;
  final String? severity;
  final String status;
  final String? recipientUserId;
  final String? backupUserId;
  final String? dueAt;
  final String? acknowledgedAt;
  final String? resolvedAt;
  final bool isDemo;
  final String? createdAt;
  final int version;
  final String? deletedAt;
  const AlertRow({
    required this.id,
    this.beneficiaryId,
    this.interactionId,
    this.ruleId,
    this.rulesetVersion,
    this.severity,
    required this.status,
    this.recipientUserId,
    this.backupUserId,
    this.dueAt,
    this.acknowledgedAt,
    this.resolvedAt,
    required this.isDemo,
    this.createdAt,
    required this.version,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || beneficiaryId != null) {
      map['beneficiary_id'] = Variable<String>(beneficiaryId);
    }
    if (!nullToAbsent || interactionId != null) {
      map['interaction_id'] = Variable<String>(interactionId);
    }
    if (!nullToAbsent || ruleId != null) {
      map['rule_id'] = Variable<String>(ruleId);
    }
    if (!nullToAbsent || rulesetVersion != null) {
      map['ruleset_version'] = Variable<String>(rulesetVersion);
    }
    if (!nullToAbsent || severity != null) {
      map['severity'] = Variable<String>(severity);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || recipientUserId != null) {
      map['recipient_user_id'] = Variable<String>(recipientUserId);
    }
    if (!nullToAbsent || backupUserId != null) {
      map['backup_user_id'] = Variable<String>(backupUserId);
    }
    if (!nullToAbsent || dueAt != null) {
      map['due_at'] = Variable<String>(dueAt);
    }
    if (!nullToAbsent || acknowledgedAt != null) {
      map['acknowledged_at'] = Variable<String>(acknowledgedAt);
    }
    if (!nullToAbsent || resolvedAt != null) {
      map['resolved_at'] = Variable<String>(resolvedAt);
    }
    map['is_demo'] = Variable<bool>(isDemo);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    map['version'] = Variable<int>(version);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    return map;
  }

  AlertsCompanion toCompanion(bool nullToAbsent) {
    return AlertsCompanion(
      id: Value(id),
      beneficiaryId:
          beneficiaryId == null && nullToAbsent
              ? const Value.absent()
              : Value(beneficiaryId),
      interactionId:
          interactionId == null && nullToAbsent
              ? const Value.absent()
              : Value(interactionId),
      ruleId:
          ruleId == null && nullToAbsent ? const Value.absent() : Value(ruleId),
      rulesetVersion:
          rulesetVersion == null && nullToAbsent
              ? const Value.absent()
              : Value(rulesetVersion),
      severity:
          severity == null && nullToAbsent
              ? const Value.absent()
              : Value(severity),
      status: Value(status),
      recipientUserId:
          recipientUserId == null && nullToAbsent
              ? const Value.absent()
              : Value(recipientUserId),
      backupUserId:
          backupUserId == null && nullToAbsent
              ? const Value.absent()
              : Value(backupUserId),
      dueAt:
          dueAt == null && nullToAbsent ? const Value.absent() : Value(dueAt),
      acknowledgedAt:
          acknowledgedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(acknowledgedAt),
      resolvedAt:
          resolvedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(resolvedAt),
      isDemo: Value(isDemo),
      createdAt:
          createdAt == null && nullToAbsent
              ? const Value.absent()
              : Value(createdAt),
      version: Value(version),
      deletedAt:
          deletedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(deletedAt),
    );
  }

  factory AlertRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AlertRow(
      id: serializer.fromJson<String>(json['id']),
      beneficiaryId: serializer.fromJson<String?>(json['beneficiaryId']),
      interactionId: serializer.fromJson<String?>(json['interactionId']),
      ruleId: serializer.fromJson<String?>(json['ruleId']),
      rulesetVersion: serializer.fromJson<String?>(json['rulesetVersion']),
      severity: serializer.fromJson<String?>(json['severity']),
      status: serializer.fromJson<String>(json['status']),
      recipientUserId: serializer.fromJson<String?>(json['recipientUserId']),
      backupUserId: serializer.fromJson<String?>(json['backupUserId']),
      dueAt: serializer.fromJson<String?>(json['dueAt']),
      acknowledgedAt: serializer.fromJson<String?>(json['acknowledgedAt']),
      resolvedAt: serializer.fromJson<String?>(json['resolvedAt']),
      isDemo: serializer.fromJson<bool>(json['isDemo']),
      createdAt: serializer.fromJson<String?>(json['createdAt']),
      version: serializer.fromJson<int>(json['version']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'beneficiaryId': serializer.toJson<String?>(beneficiaryId),
      'interactionId': serializer.toJson<String?>(interactionId),
      'ruleId': serializer.toJson<String?>(ruleId),
      'rulesetVersion': serializer.toJson<String?>(rulesetVersion),
      'severity': serializer.toJson<String?>(severity),
      'status': serializer.toJson<String>(status),
      'recipientUserId': serializer.toJson<String?>(recipientUserId),
      'backupUserId': serializer.toJson<String?>(backupUserId),
      'dueAt': serializer.toJson<String?>(dueAt),
      'acknowledgedAt': serializer.toJson<String?>(acknowledgedAt),
      'resolvedAt': serializer.toJson<String?>(resolvedAt),
      'isDemo': serializer.toJson<bool>(isDemo),
      'createdAt': serializer.toJson<String?>(createdAt),
      'version': serializer.toJson<int>(version),
      'deletedAt': serializer.toJson<String?>(deletedAt),
    };
  }

  AlertRow copyWith({
    String? id,
    Value<String?> beneficiaryId = const Value.absent(),
    Value<String?> interactionId = const Value.absent(),
    Value<String?> ruleId = const Value.absent(),
    Value<String?> rulesetVersion = const Value.absent(),
    Value<String?> severity = const Value.absent(),
    String? status,
    Value<String?> recipientUserId = const Value.absent(),
    Value<String?> backupUserId = const Value.absent(),
    Value<String?> dueAt = const Value.absent(),
    Value<String?> acknowledgedAt = const Value.absent(),
    Value<String?> resolvedAt = const Value.absent(),
    bool? isDemo,
    Value<String?> createdAt = const Value.absent(),
    int? version,
    Value<String?> deletedAt = const Value.absent(),
  }) => AlertRow(
    id: id ?? this.id,
    beneficiaryId:
        beneficiaryId.present ? beneficiaryId.value : this.beneficiaryId,
    interactionId:
        interactionId.present ? interactionId.value : this.interactionId,
    ruleId: ruleId.present ? ruleId.value : this.ruleId,
    rulesetVersion:
        rulesetVersion.present ? rulesetVersion.value : this.rulesetVersion,
    severity: severity.present ? severity.value : this.severity,
    status: status ?? this.status,
    recipientUserId:
        recipientUserId.present ? recipientUserId.value : this.recipientUserId,
    backupUserId: backupUserId.present ? backupUserId.value : this.backupUserId,
    dueAt: dueAt.present ? dueAt.value : this.dueAt,
    acknowledgedAt:
        acknowledgedAt.present ? acknowledgedAt.value : this.acknowledgedAt,
    resolvedAt: resolvedAt.present ? resolvedAt.value : this.resolvedAt,
    isDemo: isDemo ?? this.isDemo,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    version: version ?? this.version,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  AlertRow copyWithCompanion(AlertsCompanion data) {
    return AlertRow(
      id: data.id.present ? data.id.value : this.id,
      beneficiaryId:
          data.beneficiaryId.present
              ? data.beneficiaryId.value
              : this.beneficiaryId,
      interactionId:
          data.interactionId.present
              ? data.interactionId.value
              : this.interactionId,
      ruleId: data.ruleId.present ? data.ruleId.value : this.ruleId,
      rulesetVersion:
          data.rulesetVersion.present
              ? data.rulesetVersion.value
              : this.rulesetVersion,
      severity: data.severity.present ? data.severity.value : this.severity,
      status: data.status.present ? data.status.value : this.status,
      recipientUserId:
          data.recipientUserId.present
              ? data.recipientUserId.value
              : this.recipientUserId,
      backupUserId:
          data.backupUserId.present
              ? data.backupUserId.value
              : this.backupUserId,
      dueAt: data.dueAt.present ? data.dueAt.value : this.dueAt,
      acknowledgedAt:
          data.acknowledgedAt.present
              ? data.acknowledgedAt.value
              : this.acknowledgedAt,
      resolvedAt:
          data.resolvedAt.present ? data.resolvedAt.value : this.resolvedAt,
      isDemo: data.isDemo.present ? data.isDemo.value : this.isDemo,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      version: data.version.present ? data.version.value : this.version,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AlertRow(')
          ..write('id: $id, ')
          ..write('beneficiaryId: $beneficiaryId, ')
          ..write('interactionId: $interactionId, ')
          ..write('ruleId: $ruleId, ')
          ..write('rulesetVersion: $rulesetVersion, ')
          ..write('severity: $severity, ')
          ..write('status: $status, ')
          ..write('recipientUserId: $recipientUserId, ')
          ..write('backupUserId: $backupUserId, ')
          ..write('dueAt: $dueAt, ')
          ..write('acknowledgedAt: $acknowledgedAt, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('isDemo: $isDemo, ')
          ..write('createdAt: $createdAt, ')
          ..write('version: $version, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    beneficiaryId,
    interactionId,
    ruleId,
    rulesetVersion,
    severity,
    status,
    recipientUserId,
    backupUserId,
    dueAt,
    acknowledgedAt,
    resolvedAt,
    isDemo,
    createdAt,
    version,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AlertRow &&
          other.id == this.id &&
          other.beneficiaryId == this.beneficiaryId &&
          other.interactionId == this.interactionId &&
          other.ruleId == this.ruleId &&
          other.rulesetVersion == this.rulesetVersion &&
          other.severity == this.severity &&
          other.status == this.status &&
          other.recipientUserId == this.recipientUserId &&
          other.backupUserId == this.backupUserId &&
          other.dueAt == this.dueAt &&
          other.acknowledgedAt == this.acknowledgedAt &&
          other.resolvedAt == this.resolvedAt &&
          other.isDemo == this.isDemo &&
          other.createdAt == this.createdAt &&
          other.version == this.version &&
          other.deletedAt == this.deletedAt);
}

class AlertsCompanion extends UpdateCompanion<AlertRow> {
  final Value<String> id;
  final Value<String?> beneficiaryId;
  final Value<String?> interactionId;
  final Value<String?> ruleId;
  final Value<String?> rulesetVersion;
  final Value<String?> severity;
  final Value<String> status;
  final Value<String?> recipientUserId;
  final Value<String?> backupUserId;
  final Value<String?> dueAt;
  final Value<String?> acknowledgedAt;
  final Value<String?> resolvedAt;
  final Value<bool> isDemo;
  final Value<String?> createdAt;
  final Value<int> version;
  final Value<String?> deletedAt;
  final Value<int> rowid;
  const AlertsCompanion({
    this.id = const Value.absent(),
    this.beneficiaryId = const Value.absent(),
    this.interactionId = const Value.absent(),
    this.ruleId = const Value.absent(),
    this.rulesetVersion = const Value.absent(),
    this.severity = const Value.absent(),
    this.status = const Value.absent(),
    this.recipientUserId = const Value.absent(),
    this.backupUserId = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.acknowledgedAt = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.isDemo = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.version = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AlertsCompanion.insert({
    required String id,
    this.beneficiaryId = const Value.absent(),
    this.interactionId = const Value.absent(),
    this.ruleId = const Value.absent(),
    this.rulesetVersion = const Value.absent(),
    this.severity = const Value.absent(),
    this.status = const Value.absent(),
    this.recipientUserId = const Value.absent(),
    this.backupUserId = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.acknowledgedAt = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.isDemo = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.version = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<AlertRow> custom({
    Expression<String>? id,
    Expression<String>? beneficiaryId,
    Expression<String>? interactionId,
    Expression<String>? ruleId,
    Expression<String>? rulesetVersion,
    Expression<String>? severity,
    Expression<String>? status,
    Expression<String>? recipientUserId,
    Expression<String>? backupUserId,
    Expression<String>? dueAt,
    Expression<String>? acknowledgedAt,
    Expression<String>? resolvedAt,
    Expression<bool>? isDemo,
    Expression<String>? createdAt,
    Expression<int>? version,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (beneficiaryId != null) 'beneficiary_id': beneficiaryId,
      if (interactionId != null) 'interaction_id': interactionId,
      if (ruleId != null) 'rule_id': ruleId,
      if (rulesetVersion != null) 'ruleset_version': rulesetVersion,
      if (severity != null) 'severity': severity,
      if (status != null) 'status': status,
      if (recipientUserId != null) 'recipient_user_id': recipientUserId,
      if (backupUserId != null) 'backup_user_id': backupUserId,
      if (dueAt != null) 'due_at': dueAt,
      if (acknowledgedAt != null) 'acknowledged_at': acknowledgedAt,
      if (resolvedAt != null) 'resolved_at': resolvedAt,
      if (isDemo != null) 'is_demo': isDemo,
      if (createdAt != null) 'created_at': createdAt,
      if (version != null) 'version': version,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AlertsCompanion copyWith({
    Value<String>? id,
    Value<String?>? beneficiaryId,
    Value<String?>? interactionId,
    Value<String?>? ruleId,
    Value<String?>? rulesetVersion,
    Value<String?>? severity,
    Value<String>? status,
    Value<String?>? recipientUserId,
    Value<String?>? backupUserId,
    Value<String?>? dueAt,
    Value<String?>? acknowledgedAt,
    Value<String?>? resolvedAt,
    Value<bool>? isDemo,
    Value<String?>? createdAt,
    Value<int>? version,
    Value<String?>? deletedAt,
    Value<int>? rowid,
  }) {
    return AlertsCompanion(
      id: id ?? this.id,
      beneficiaryId: beneficiaryId ?? this.beneficiaryId,
      interactionId: interactionId ?? this.interactionId,
      ruleId: ruleId ?? this.ruleId,
      rulesetVersion: rulesetVersion ?? this.rulesetVersion,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      recipientUserId: recipientUserId ?? this.recipientUserId,
      backupUserId: backupUserId ?? this.backupUserId,
      dueAt: dueAt ?? this.dueAt,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      isDemo: isDemo ?? this.isDemo,
      createdAt: createdAt ?? this.createdAt,
      version: version ?? this.version,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (beneficiaryId.present) {
      map['beneficiary_id'] = Variable<String>(beneficiaryId.value);
    }
    if (interactionId.present) {
      map['interaction_id'] = Variable<String>(interactionId.value);
    }
    if (ruleId.present) {
      map['rule_id'] = Variable<String>(ruleId.value);
    }
    if (rulesetVersion.present) {
      map['ruleset_version'] = Variable<String>(rulesetVersion.value);
    }
    if (severity.present) {
      map['severity'] = Variable<String>(severity.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (recipientUserId.present) {
      map['recipient_user_id'] = Variable<String>(recipientUserId.value);
    }
    if (backupUserId.present) {
      map['backup_user_id'] = Variable<String>(backupUserId.value);
    }
    if (dueAt.present) {
      map['due_at'] = Variable<String>(dueAt.value);
    }
    if (acknowledgedAt.present) {
      map['acknowledged_at'] = Variable<String>(acknowledgedAt.value);
    }
    if (resolvedAt.present) {
      map['resolved_at'] = Variable<String>(resolvedAt.value);
    }
    if (isDemo.present) {
      map['is_demo'] = Variable<bool>(isDemo.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AlertsCompanion(')
          ..write('id: $id, ')
          ..write('beneficiaryId: $beneficiaryId, ')
          ..write('interactionId: $interactionId, ')
          ..write('ruleId: $ruleId, ')
          ..write('rulesetVersion: $rulesetVersion, ')
          ..write('severity: $severity, ')
          ..write('status: $status, ')
          ..write('recipientUserId: $recipientUserId, ')
          ..write('backupUserId: $backupUserId, ')
          ..write('dueAt: $dueAt, ')
          ..write('acknowledgedAt: $acknowledgedAt, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('isDemo: $isDemo, ')
          ..write('createdAt: $createdAt, ')
          ..write('version: $version, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SitesTable extends Sites with TableInfo<$SitesTable, SiteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SitesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _districtMeta = const VerificationMeta(
    'district',
  );
  @override
  late final GeneratedColumn<String> district = GeneratedColumn<String>(
    'district',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _regionMeta = const VerificationMeta('region');
  @override
  late final GeneratedColumn<String> region = GeneratedColumn<String>(
    'region',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parentSiteIdMeta = const VerificationMeta(
    'parentSiteId',
  );
  @override
  late final GeneratedColumn<String> parentSiteId = GeneratedColumn<String>(
    'parent_site_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    kind,
    code,
    district,
    region,
    parentSiteId,
    isActive,
    version,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sites';
  @override
  VerificationContext validateIntegrity(
    Insertable<SiteRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    }
    if (data.containsKey('district')) {
      context.handle(
        _districtMeta,
        district.isAcceptableOrUnknown(data['district']!, _districtMeta),
      );
    }
    if (data.containsKey('region')) {
      context.handle(
        _regionMeta,
        region.isAcceptableOrUnknown(data['region']!, _regionMeta),
      );
    }
    if (data.containsKey('parent_site_id')) {
      context.handle(
        _parentSiteIdMeta,
        parentSiteId.isAcceptableOrUnknown(
          data['parent_site_id']!,
          _parentSiteIdMeta,
        ),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
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
  SiteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SiteRow(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      name:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}name'],
          )!,
      kind:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}kind'],
          )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      ),
      district: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}district'],
      ),
      region: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}region'],
      ),
      parentSiteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_site_id'],
      ),
      isActive:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_active'],
          )!,
      version:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}version'],
          )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $SitesTable createAlias(String alias) {
    return $SitesTable(attachedDatabase, alias);
  }
}

class SiteRow extends DataClass implements Insertable<SiteRow> {
  final String id;
  final String name;

  /// `csb`, `reference_facility` ou `community_zone`.
  final String kind;
  final String? code;
  final String? district;
  final String? region;
  final String? parentSiteId;
  final bool isActive;
  final int version;
  final String? deletedAt;
  const SiteRow({
    required this.id,
    required this.name,
    required this.kind,
    this.code,
    this.district,
    this.region,
    this.parentSiteId,
    required this.isActive,
    required this.version,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || code != null) {
      map['code'] = Variable<String>(code);
    }
    if (!nullToAbsent || district != null) {
      map['district'] = Variable<String>(district);
    }
    if (!nullToAbsent || region != null) {
      map['region'] = Variable<String>(region);
    }
    if (!nullToAbsent || parentSiteId != null) {
      map['parent_site_id'] = Variable<String>(parentSiteId);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['version'] = Variable<int>(version);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    return map;
  }

  SitesCompanion toCompanion(bool nullToAbsent) {
    return SitesCompanion(
      id: Value(id),
      name: Value(name),
      kind: Value(kind),
      code: code == null && nullToAbsent ? const Value.absent() : Value(code),
      district:
          district == null && nullToAbsent
              ? const Value.absent()
              : Value(district),
      region:
          region == null && nullToAbsent ? const Value.absent() : Value(region),
      parentSiteId:
          parentSiteId == null && nullToAbsent
              ? const Value.absent()
              : Value(parentSiteId),
      isActive: Value(isActive),
      version: Value(version),
      deletedAt:
          deletedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(deletedAt),
    );
  }

  factory SiteRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SiteRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      kind: serializer.fromJson<String>(json['kind']),
      code: serializer.fromJson<String?>(json['code']),
      district: serializer.fromJson<String?>(json['district']),
      region: serializer.fromJson<String?>(json['region']),
      parentSiteId: serializer.fromJson<String?>(json['parentSiteId']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      version: serializer.fromJson<int>(json['version']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'kind': serializer.toJson<String>(kind),
      'code': serializer.toJson<String?>(code),
      'district': serializer.toJson<String?>(district),
      'region': serializer.toJson<String?>(region),
      'parentSiteId': serializer.toJson<String?>(parentSiteId),
      'isActive': serializer.toJson<bool>(isActive),
      'version': serializer.toJson<int>(version),
      'deletedAt': serializer.toJson<String?>(deletedAt),
    };
  }

  SiteRow copyWith({
    String? id,
    String? name,
    String? kind,
    Value<String?> code = const Value.absent(),
    Value<String?> district = const Value.absent(),
    Value<String?> region = const Value.absent(),
    Value<String?> parentSiteId = const Value.absent(),
    bool? isActive,
    int? version,
    Value<String?> deletedAt = const Value.absent(),
  }) => SiteRow(
    id: id ?? this.id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    code: code.present ? code.value : this.code,
    district: district.present ? district.value : this.district,
    region: region.present ? region.value : this.region,
    parentSiteId: parentSiteId.present ? parentSiteId.value : this.parentSiteId,
    isActive: isActive ?? this.isActive,
    version: version ?? this.version,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  SiteRow copyWithCompanion(SitesCompanion data) {
    return SiteRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
      code: data.code.present ? data.code.value : this.code,
      district: data.district.present ? data.district.value : this.district,
      region: data.region.present ? data.region.value : this.region,
      parentSiteId:
          data.parentSiteId.present
              ? data.parentSiteId.value
              : this.parentSiteId,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      version: data.version.present ? data.version.value : this.version,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SiteRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('code: $code, ')
          ..write('district: $district, ')
          ..write('region: $region, ')
          ..write('parentSiteId: $parentSiteId, ')
          ..write('isActive: $isActive, ')
          ..write('version: $version, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    kind,
    code,
    district,
    region,
    parentSiteId,
    isActive,
    version,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SiteRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.kind == this.kind &&
          other.code == this.code &&
          other.district == this.district &&
          other.region == this.region &&
          other.parentSiteId == this.parentSiteId &&
          other.isActive == this.isActive &&
          other.version == this.version &&
          other.deletedAt == this.deletedAt);
}

class SitesCompanion extends UpdateCompanion<SiteRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> kind;
  final Value<String?> code;
  final Value<String?> district;
  final Value<String?> region;
  final Value<String?> parentSiteId;
  final Value<bool> isActive;
  final Value<int> version;
  final Value<String?> deletedAt;
  final Value<int> rowid;
  const SitesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.code = const Value.absent(),
    this.district = const Value.absent(),
    this.region = const Value.absent(),
    this.parentSiteId = const Value.absent(),
    this.isActive = const Value.absent(),
    this.version = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SitesCompanion.insert({
    required String id,
    required String name,
    required String kind,
    this.code = const Value.absent(),
    this.district = const Value.absent(),
    this.region = const Value.absent(),
    this.parentSiteId = const Value.absent(),
    this.isActive = const Value.absent(),
    this.version = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       kind = Value(kind);
  static Insertable<SiteRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? kind,
    Expression<String>? code,
    Expression<String>? district,
    Expression<String>? region,
    Expression<String>? parentSiteId,
    Expression<bool>? isActive,
    Expression<int>? version,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (code != null) 'code': code,
      if (district != null) 'district': district,
      if (region != null) 'region': region,
      if (parentSiteId != null) 'parent_site_id': parentSiteId,
      if (isActive != null) 'is_active': isActive,
      if (version != null) 'version': version,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SitesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? kind,
    Value<String?>? code,
    Value<String?>? district,
    Value<String?>? region,
    Value<String?>? parentSiteId,
    Value<bool>? isActive,
    Value<int>? version,
    Value<String?>? deletedAt,
    Value<int>? rowid,
  }) {
    return SitesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      code: code ?? this.code,
      district: district ?? this.district,
      region: region ?? this.region,
      parentSiteId: parentSiteId ?? this.parentSiteId,
      isActive: isActive ?? this.isActive,
      version: version ?? this.version,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (district.present) {
      map['district'] = Variable<String>(district.value);
    }
    if (region.present) {
      map['region'] = Variable<String>(region.value);
    }
    if (parentSiteId.present) {
      map['parent_site_id'] = Variable<String>(parentSiteId.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SitesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('code: $code, ')
          ..write('district: $district, ')
          ..write('region: $region, ')
          ..write('parentSiteId: $parentSiteId, ')
          ..write('isActive: $isActive, ')
          ..write('version: $version, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReferenceCacheTable extends ReferenceCache
    with TableInfo<$ReferenceCacheTable, ReferenceCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReferenceCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, json, fetchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reference_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReferenceCacheRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  ReferenceCacheRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReferenceCacheRow(
      key:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}key'],
          )!,
      json:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}json'],
          )!,
      fetchedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}fetched_at'],
          )!,
    );
  }

  @override
  $ReferenceCacheTable createAlias(String alias) {
    return $ReferenceCacheTable(attachedDatabase, alias);
  }
}

class ReferenceCacheRow extends DataClass
    implements Insertable<ReferenceCacheRow> {
  /// Ex. `sign-codes:reny`, `consent-information`.
  final String key;
  final String json;
  final DateTime fetchedAt;
  const ReferenceCacheRow({
    required this.key,
    required this.json,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['json'] = Variable<String>(json);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  ReferenceCacheCompanion toCompanion(bool nullToAbsent) {
    return ReferenceCacheCompanion(
      key: Value(key),
      json: Value(json),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory ReferenceCacheRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReferenceCacheRow(
      key: serializer.fromJson<String>(json['key']),
      json: serializer.fromJson<String>(json['json']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'json': serializer.toJson<String>(json),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  ReferenceCacheRow copyWith({
    String? key,
    String? json,
    DateTime? fetchedAt,
  }) => ReferenceCacheRow(
    key: key ?? this.key,
    json: json ?? this.json,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  ReferenceCacheRow copyWithCompanion(ReferenceCacheCompanion data) {
    return ReferenceCacheRow(
      key: data.key.present ? data.key.value : this.key,
      json: data.json.present ? data.json.value : this.json,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReferenceCacheRow(')
          ..write('key: $key, ')
          ..write('json: $json, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, json, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReferenceCacheRow &&
          other.key == this.key &&
          other.json == this.json &&
          other.fetchedAt == this.fetchedAt);
}

class ReferenceCacheCompanion extends UpdateCompanion<ReferenceCacheRow> {
  final Value<String> key;
  final Value<String> json;
  final Value<DateTime> fetchedAt;
  final Value<int> rowid;
  const ReferenceCacheCompanion({
    this.key = const Value.absent(),
    this.json = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReferenceCacheCompanion.insert({
    required String key,
    required String json,
    required DateTime fetchedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       json = Value(json),
       fetchedAt = Value(fetchedAt);
  static Insertable<ReferenceCacheRow> custom({
    Expression<String>? key,
    Expression<String>? json,
    Expression<DateTime>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (json != null) 'json': json,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReferenceCacheCompanion copyWith({
    Value<String>? key,
    Value<String>? json,
    Value<DateTime>? fetchedAt,
    Value<int>? rowid,
  }) {
    return ReferenceCacheCompanion(
      key: key ?? this.key,
      json: json ?? this.json,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReferenceCacheCompanion(')
          ..write('key: $key, ')
          ..write('json: $json, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _changeIdMeta = const VerificationMeta(
    'changeId',
  );
  @override
  late final GeneratedColumn<String> changeId = GeneratedColumn<String>(
    'change_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _opMeta = const VerificationMeta('op');
  @override
  late final GeneratedColumn<String> op = GeneratedColumn<String>(
    'op',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseVersionMeta = const VerificationMeta(
    'baseVersion',
  );
  @override
  late final GeneratedColumn<int> baseVersion = GeneratedColumn<int>(
    'base_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nextAttemptAtMeta = const VerificationMeta(
    'nextAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextAttemptAt =
      GeneratedColumn<DateTime>(
        'next_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    changeId,
    entity,
    op,
    entityId,
    baseVersion,
    data,
    status,
    attempts,
    lastError,
    seq,
    createdAt,
    nextAttemptAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('change_id')) {
      context.handle(
        _changeIdMeta,
        changeId.isAcceptableOrUnknown(data['change_id']!, _changeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_changeIdMeta);
    }
    if (data.containsKey('entity')) {
      context.handle(
        _entityMeta,
        entity.isAcceptableOrUnknown(data['entity']!, _entityMeta),
      );
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('op')) {
      context.handle(_opMeta, op.isAcceptableOrUnknown(data['op']!, _opMeta));
    } else if (isInserting) {
      context.missing(_opMeta);
    }
    if (data.containsKey('id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('base_version')) {
      context.handle(
        _baseVersionMeta,
        baseVersion.isAcceptableOrUnknown(
          data['base_version']!,
          _baseVersionMeta,
        ),
      );
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
        _nextAttemptAtMeta,
        nextAttemptAt.isAcceptableOrUnknown(
          data['next_attempt_at']!,
          _nextAttemptAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {changeId};
  @override
  OutboxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxRow(
      changeId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}change_id'],
          )!,
      entity:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}entity'],
          )!,
      op:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}op'],
          )!,
      entityId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      baseVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}base_version'],
      ),
      data:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}data'],
          )!,
      status:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}status'],
          )!,
      attempts:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}attempts'],
          )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      seq:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}seq'],
          )!,
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
      nextAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_attempt_at'],
      ),
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }
}

class OutboxRow extends DataClass implements Insertable<OutboxRow> {
  /// UUID v4 généré côté client : clé d'idempotence côté serveur.
  final String changeId;
  final String entity;
  final String op;

  /// Identifiant de l'entité (colonne `id` du contrat).
  final String entityId;
  final int? baseVersion;

  /// Charge utile JSON.
  final String data;

  /// `pending` ou `rejected`.
  final String status;
  final int attempts;
  final String? lastError;

  /// Numéro d'ordre monotone (ordre d'envoi = ordre de saisie).
  final int seq;
  final DateTime createdAt;

  /// Prochaine tentative autorisée (backoff), null = immédiatement.
  final DateTime? nextAttemptAt;
  const OutboxRow({
    required this.changeId,
    required this.entity,
    required this.op,
    required this.entityId,
    this.baseVersion,
    required this.data,
    required this.status,
    required this.attempts,
    this.lastError,
    required this.seq,
    required this.createdAt,
    this.nextAttemptAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['change_id'] = Variable<String>(changeId);
    map['entity'] = Variable<String>(entity);
    map['op'] = Variable<String>(op);
    map['id'] = Variable<String>(entityId);
    if (!nullToAbsent || baseVersion != null) {
      map['base_version'] = Variable<int>(baseVersion);
    }
    map['data'] = Variable<String>(data);
    map['status'] = Variable<String>(status);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['seq'] = Variable<int>(seq);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || nextAttemptAt != null) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt);
    }
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      changeId: Value(changeId),
      entity: Value(entity),
      op: Value(op),
      entityId: Value(entityId),
      baseVersion:
          baseVersion == null && nullToAbsent
              ? const Value.absent()
              : Value(baseVersion),
      data: Value(data),
      status: Value(status),
      attempts: Value(attempts),
      lastError:
          lastError == null && nullToAbsent
              ? const Value.absent()
              : Value(lastError),
      seq: Value(seq),
      createdAt: Value(createdAt),
      nextAttemptAt:
          nextAttemptAt == null && nullToAbsent
              ? const Value.absent()
              : Value(nextAttemptAt),
    );
  }

  factory OutboxRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxRow(
      changeId: serializer.fromJson<String>(json['changeId']),
      entity: serializer.fromJson<String>(json['entity']),
      op: serializer.fromJson<String>(json['op']),
      entityId: serializer.fromJson<String>(json['entityId']),
      baseVersion: serializer.fromJson<int?>(json['baseVersion']),
      data: serializer.fromJson<String>(json['data']),
      status: serializer.fromJson<String>(json['status']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      seq: serializer.fromJson<int>(json['seq']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      nextAttemptAt: serializer.fromJson<DateTime?>(json['nextAttemptAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'changeId': serializer.toJson<String>(changeId),
      'entity': serializer.toJson<String>(entity),
      'op': serializer.toJson<String>(op),
      'entityId': serializer.toJson<String>(entityId),
      'baseVersion': serializer.toJson<int?>(baseVersion),
      'data': serializer.toJson<String>(data),
      'status': serializer.toJson<String>(status),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
      'seq': serializer.toJson<int>(seq),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'nextAttemptAt': serializer.toJson<DateTime?>(nextAttemptAt),
    };
  }

  OutboxRow copyWith({
    String? changeId,
    String? entity,
    String? op,
    String? entityId,
    Value<int?> baseVersion = const Value.absent(),
    String? data,
    String? status,
    int? attempts,
    Value<String?> lastError = const Value.absent(),
    int? seq,
    DateTime? createdAt,
    Value<DateTime?> nextAttemptAt = const Value.absent(),
  }) => OutboxRow(
    changeId: changeId ?? this.changeId,
    entity: entity ?? this.entity,
    op: op ?? this.op,
    entityId: entityId ?? this.entityId,
    baseVersion: baseVersion.present ? baseVersion.value : this.baseVersion,
    data: data ?? this.data,
    status: status ?? this.status,
    attempts: attempts ?? this.attempts,
    lastError: lastError.present ? lastError.value : this.lastError,
    seq: seq ?? this.seq,
    createdAt: createdAt ?? this.createdAt,
    nextAttemptAt:
        nextAttemptAt.present ? nextAttemptAt.value : this.nextAttemptAt,
  );
  OutboxRow copyWithCompanion(OutboxCompanion data) {
    return OutboxRow(
      changeId: data.changeId.present ? data.changeId.value : this.changeId,
      entity: data.entity.present ? data.entity.value : this.entity,
      op: data.op.present ? data.op.value : this.op,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      baseVersion:
          data.baseVersion.present ? data.baseVersion.value : this.baseVersion,
      data: data.data.present ? data.data.value : this.data,
      status: data.status.present ? data.status.value : this.status,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      seq: data.seq.present ? data.seq.value : this.seq,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      nextAttemptAt:
          data.nextAttemptAt.present
              ? data.nextAttemptAt.value
              : this.nextAttemptAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxRow(')
          ..write('changeId: $changeId, ')
          ..write('entity: $entity, ')
          ..write('op: $op, ')
          ..write('entityId: $entityId, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('data: $data, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('seq: $seq, ')
          ..write('createdAt: $createdAt, ')
          ..write('nextAttemptAt: $nextAttemptAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    changeId,
    entity,
    op,
    entityId,
    baseVersion,
    data,
    status,
    attempts,
    lastError,
    seq,
    createdAt,
    nextAttemptAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxRow &&
          other.changeId == this.changeId &&
          other.entity == this.entity &&
          other.op == this.op &&
          other.entityId == this.entityId &&
          other.baseVersion == this.baseVersion &&
          other.data == this.data &&
          other.status == this.status &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError &&
          other.seq == this.seq &&
          other.createdAt == this.createdAt &&
          other.nextAttemptAt == this.nextAttemptAt);
}

class OutboxCompanion extends UpdateCompanion<OutboxRow> {
  final Value<String> changeId;
  final Value<String> entity;
  final Value<String> op;
  final Value<String> entityId;
  final Value<int?> baseVersion;
  final Value<String> data;
  final Value<String> status;
  final Value<int> attempts;
  final Value<String?> lastError;
  final Value<int> seq;
  final Value<DateTime> createdAt;
  final Value<DateTime?> nextAttemptAt;
  final Value<int> rowid;
  const OutboxCompanion({
    this.changeId = const Value.absent(),
    this.entity = const Value.absent(),
    this.op = const Value.absent(),
    this.entityId = const Value.absent(),
    this.baseVersion = const Value.absent(),
    this.data = const Value.absent(),
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.seq = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxCompanion.insert({
    required String changeId,
    required String entity,
    required String op,
    required String entityId,
    this.baseVersion = const Value.absent(),
    required String data,
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    required int seq,
    required DateTime createdAt,
    this.nextAttemptAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : changeId = Value(changeId),
       entity = Value(entity),
       op = Value(op),
       entityId = Value(entityId),
       data = Value(data),
       seq = Value(seq),
       createdAt = Value(createdAt);
  static Insertable<OutboxRow> custom({
    Expression<String>? changeId,
    Expression<String>? entity,
    Expression<String>? op,
    Expression<String>? entityId,
    Expression<int>? baseVersion,
    Expression<String>? data,
    Expression<String>? status,
    Expression<int>? attempts,
    Expression<String>? lastError,
    Expression<int>? seq,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? nextAttemptAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (changeId != null) 'change_id': changeId,
      if (entity != null) 'entity': entity,
      if (op != null) 'op': op,
      if (entityId != null) 'id': entityId,
      if (baseVersion != null) 'base_version': baseVersion,
      if (data != null) 'data': data,
      if (status != null) 'status': status,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
      if (seq != null) 'seq': seq,
      if (createdAt != null) 'created_at': createdAt,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxCompanion copyWith({
    Value<String>? changeId,
    Value<String>? entity,
    Value<String>? op,
    Value<String>? entityId,
    Value<int?>? baseVersion,
    Value<String>? data,
    Value<String>? status,
    Value<int>? attempts,
    Value<String?>? lastError,
    Value<int>? seq,
    Value<DateTime>? createdAt,
    Value<DateTime?>? nextAttemptAt,
    Value<int>? rowid,
  }) {
    return OutboxCompanion(
      changeId: changeId ?? this.changeId,
      entity: entity ?? this.entity,
      op: op ?? this.op,
      entityId: entityId ?? this.entityId,
      baseVersion: baseVersion ?? this.baseVersion,
      data: data ?? this.data,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      seq: seq ?? this.seq,
      createdAt: createdAt ?? this.createdAt,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (changeId.present) {
      map['change_id'] = Variable<String>(changeId.value);
    }
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (op.present) {
      map['op'] = Variable<String>(op.value);
    }
    if (entityId.present) {
      map['id'] = Variable<String>(entityId.value);
    }
    if (baseVersion.present) {
      map['base_version'] = Variable<int>(baseVersion.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('changeId: $changeId, ')
          ..write('entity: $entity, ')
          ..write('op: $op, ')
          ..write('entityId: $entityId, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('data: $data, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('seq: $seq, ')
          ..write('createdAt: $createdAt, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncConflictsTable extends SyncConflicts
    with TableInfo<$SyncConflictsTable, SyncConflictRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncConflictsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _changeIdMeta = const VerificationMeta(
    'changeId',
  );
  @override
  late final GeneratedColumn<String> changeId = GeneratedColumn<String>(
    'change_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _opMeta = const VerificationMeta('op');
  @override
  late final GeneratedColumn<String> op = GeneratedColumn<String>(
    'op',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseVersionMeta = const VerificationMeta(
    'baseVersion',
  );
  @override
  late final GeneratedColumn<int> baseVersion = GeneratedColumn<int>(
    'base_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localDataMeta = const VerificationMeta(
    'localData',
  );
  @override
  late final GeneratedColumn<String> localData = GeneratedColumn<String>(
    'local_data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverVersionMeta = const VerificationMeta(
    'serverVersion',
  );
  @override
  late final GeneratedColumn<int> serverVersion = GeneratedColumn<int>(
    'server_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serverDataMeta = const VerificationMeta(
    'serverData',
  );
  @override
  late final GeneratedColumn<String> serverData = GeneratedColumn<String>(
    'server_data',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _detectedAtMeta = const VerificationMeta(
    'detectedAt',
  );
  @override
  late final GeneratedColumn<DateTime> detectedAt = GeneratedColumn<DateTime>(
    'detected_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resolvedAtMeta = const VerificationMeta(
    'resolvedAt',
  );
  @override
  late final GeneratedColumn<DateTime> resolvedAt = GeneratedColumn<DateTime>(
    'resolved_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resolutionMeta = const VerificationMeta(
    'resolution',
  );
  @override
  late final GeneratedColumn<String> resolution = GeneratedColumn<String>(
    'resolution',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    changeId,
    entity,
    entityId,
    op,
    baseVersion,
    localData,
    serverVersion,
    serverData,
    detectedAt,
    resolvedAt,
    resolution,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_conflicts';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncConflictRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('change_id')) {
      context.handle(
        _changeIdMeta,
        changeId.isAcceptableOrUnknown(data['change_id']!, _changeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_changeIdMeta);
    }
    if (data.containsKey('entity')) {
      context.handle(
        _entityMeta,
        entity.isAcceptableOrUnknown(data['entity']!, _entityMeta),
      );
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('op')) {
      context.handle(_opMeta, op.isAcceptableOrUnknown(data['op']!, _opMeta));
    } else if (isInserting) {
      context.missing(_opMeta);
    }
    if (data.containsKey('base_version')) {
      context.handle(
        _baseVersionMeta,
        baseVersion.isAcceptableOrUnknown(
          data['base_version']!,
          _baseVersionMeta,
        ),
      );
    }
    if (data.containsKey('local_data')) {
      context.handle(
        _localDataMeta,
        localData.isAcceptableOrUnknown(data['local_data']!, _localDataMeta),
      );
    } else if (isInserting) {
      context.missing(_localDataMeta);
    }
    if (data.containsKey('server_version')) {
      context.handle(
        _serverVersionMeta,
        serverVersion.isAcceptableOrUnknown(
          data['server_version']!,
          _serverVersionMeta,
        ),
      );
    }
    if (data.containsKey('server_data')) {
      context.handle(
        _serverDataMeta,
        serverData.isAcceptableOrUnknown(data['server_data']!, _serverDataMeta),
      );
    }
    if (data.containsKey('detected_at')) {
      context.handle(
        _detectedAtMeta,
        detectedAt.isAcceptableOrUnknown(data['detected_at']!, _detectedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_detectedAtMeta);
    }
    if (data.containsKey('resolved_at')) {
      context.handle(
        _resolvedAtMeta,
        resolvedAt.isAcceptableOrUnknown(data['resolved_at']!, _resolvedAtMeta),
      );
    }
    if (data.containsKey('resolution')) {
      context.handle(
        _resolutionMeta,
        resolution.isAcceptableOrUnknown(data['resolution']!, _resolutionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncConflictRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncConflictRow(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      changeId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}change_id'],
          )!,
      entity:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}entity'],
          )!,
      entityId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}entity_id'],
          )!,
      op:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}op'],
          )!,
      baseVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}base_version'],
      ),
      localData:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}local_data'],
          )!,
      serverVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_version'],
      ),
      serverData: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_data'],
      ),
      detectedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}detected_at'],
          )!,
      resolvedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}resolved_at'],
      ),
      resolution: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resolution'],
      ),
    );
  }

  @override
  $SyncConflictsTable createAlias(String alias) {
    return $SyncConflictsTable(attachedDatabase, alias);
  }
}

class SyncConflictRow extends DataClass implements Insertable<SyncConflictRow> {
  final int id;
  final String changeId;
  final String entity;
  final String entityId;
  final String op;
  final int? baseVersion;
  final String localData;
  final int? serverVersion;
  final String? serverData;
  final DateTime detectedAt;
  final DateTime? resolvedAt;

  /// `reviewed` (version serveur gardée) ou `reapplied` (version locale renvoyée).
  final String? resolution;
  const SyncConflictRow({
    required this.id,
    required this.changeId,
    required this.entity,
    required this.entityId,
    required this.op,
    this.baseVersion,
    required this.localData,
    this.serverVersion,
    this.serverData,
    required this.detectedAt,
    this.resolvedAt,
    this.resolution,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['change_id'] = Variable<String>(changeId);
    map['entity'] = Variable<String>(entity);
    map['entity_id'] = Variable<String>(entityId);
    map['op'] = Variable<String>(op);
    if (!nullToAbsent || baseVersion != null) {
      map['base_version'] = Variable<int>(baseVersion);
    }
    map['local_data'] = Variable<String>(localData);
    if (!nullToAbsent || serverVersion != null) {
      map['server_version'] = Variable<int>(serverVersion);
    }
    if (!nullToAbsent || serverData != null) {
      map['server_data'] = Variable<String>(serverData);
    }
    map['detected_at'] = Variable<DateTime>(detectedAt);
    if (!nullToAbsent || resolvedAt != null) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt);
    }
    if (!nullToAbsent || resolution != null) {
      map['resolution'] = Variable<String>(resolution);
    }
    return map;
  }

  SyncConflictsCompanion toCompanion(bool nullToAbsent) {
    return SyncConflictsCompanion(
      id: Value(id),
      changeId: Value(changeId),
      entity: Value(entity),
      entityId: Value(entityId),
      op: Value(op),
      baseVersion:
          baseVersion == null && nullToAbsent
              ? const Value.absent()
              : Value(baseVersion),
      localData: Value(localData),
      serverVersion:
          serverVersion == null && nullToAbsent
              ? const Value.absent()
              : Value(serverVersion),
      serverData:
          serverData == null && nullToAbsent
              ? const Value.absent()
              : Value(serverData),
      detectedAt: Value(detectedAt),
      resolvedAt:
          resolvedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(resolvedAt),
      resolution:
          resolution == null && nullToAbsent
              ? const Value.absent()
              : Value(resolution),
    );
  }

  factory SyncConflictRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncConflictRow(
      id: serializer.fromJson<int>(json['id']),
      changeId: serializer.fromJson<String>(json['changeId']),
      entity: serializer.fromJson<String>(json['entity']),
      entityId: serializer.fromJson<String>(json['entityId']),
      op: serializer.fromJson<String>(json['op']),
      baseVersion: serializer.fromJson<int?>(json['baseVersion']),
      localData: serializer.fromJson<String>(json['localData']),
      serverVersion: serializer.fromJson<int?>(json['serverVersion']),
      serverData: serializer.fromJson<String?>(json['serverData']),
      detectedAt: serializer.fromJson<DateTime>(json['detectedAt']),
      resolvedAt: serializer.fromJson<DateTime?>(json['resolvedAt']),
      resolution: serializer.fromJson<String?>(json['resolution']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'changeId': serializer.toJson<String>(changeId),
      'entity': serializer.toJson<String>(entity),
      'entityId': serializer.toJson<String>(entityId),
      'op': serializer.toJson<String>(op),
      'baseVersion': serializer.toJson<int?>(baseVersion),
      'localData': serializer.toJson<String>(localData),
      'serverVersion': serializer.toJson<int?>(serverVersion),
      'serverData': serializer.toJson<String?>(serverData),
      'detectedAt': serializer.toJson<DateTime>(detectedAt),
      'resolvedAt': serializer.toJson<DateTime?>(resolvedAt),
      'resolution': serializer.toJson<String?>(resolution),
    };
  }

  SyncConflictRow copyWith({
    int? id,
    String? changeId,
    String? entity,
    String? entityId,
    String? op,
    Value<int?> baseVersion = const Value.absent(),
    String? localData,
    Value<int?> serverVersion = const Value.absent(),
    Value<String?> serverData = const Value.absent(),
    DateTime? detectedAt,
    Value<DateTime?> resolvedAt = const Value.absent(),
    Value<String?> resolution = const Value.absent(),
  }) => SyncConflictRow(
    id: id ?? this.id,
    changeId: changeId ?? this.changeId,
    entity: entity ?? this.entity,
    entityId: entityId ?? this.entityId,
    op: op ?? this.op,
    baseVersion: baseVersion.present ? baseVersion.value : this.baseVersion,
    localData: localData ?? this.localData,
    serverVersion:
        serverVersion.present ? serverVersion.value : this.serverVersion,
    serverData: serverData.present ? serverData.value : this.serverData,
    detectedAt: detectedAt ?? this.detectedAt,
    resolvedAt: resolvedAt.present ? resolvedAt.value : this.resolvedAt,
    resolution: resolution.present ? resolution.value : this.resolution,
  );
  SyncConflictRow copyWithCompanion(SyncConflictsCompanion data) {
    return SyncConflictRow(
      id: data.id.present ? data.id.value : this.id,
      changeId: data.changeId.present ? data.changeId.value : this.changeId,
      entity: data.entity.present ? data.entity.value : this.entity,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      op: data.op.present ? data.op.value : this.op,
      baseVersion:
          data.baseVersion.present ? data.baseVersion.value : this.baseVersion,
      localData: data.localData.present ? data.localData.value : this.localData,
      serverVersion:
          data.serverVersion.present
              ? data.serverVersion.value
              : this.serverVersion,
      serverData:
          data.serverData.present ? data.serverData.value : this.serverData,
      detectedAt:
          data.detectedAt.present ? data.detectedAt.value : this.detectedAt,
      resolvedAt:
          data.resolvedAt.present ? data.resolvedAt.value : this.resolvedAt,
      resolution:
          data.resolution.present ? data.resolution.value : this.resolution,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncConflictRow(')
          ..write('id: $id, ')
          ..write('changeId: $changeId, ')
          ..write('entity: $entity, ')
          ..write('entityId: $entityId, ')
          ..write('op: $op, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('localData: $localData, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('serverData: $serverData, ')
          ..write('detectedAt: $detectedAt, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('resolution: $resolution')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    changeId,
    entity,
    entityId,
    op,
    baseVersion,
    localData,
    serverVersion,
    serverData,
    detectedAt,
    resolvedAt,
    resolution,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncConflictRow &&
          other.id == this.id &&
          other.changeId == this.changeId &&
          other.entity == this.entity &&
          other.entityId == this.entityId &&
          other.op == this.op &&
          other.baseVersion == this.baseVersion &&
          other.localData == this.localData &&
          other.serverVersion == this.serverVersion &&
          other.serverData == this.serverData &&
          other.detectedAt == this.detectedAt &&
          other.resolvedAt == this.resolvedAt &&
          other.resolution == this.resolution);
}

class SyncConflictsCompanion extends UpdateCompanion<SyncConflictRow> {
  final Value<int> id;
  final Value<String> changeId;
  final Value<String> entity;
  final Value<String> entityId;
  final Value<String> op;
  final Value<int?> baseVersion;
  final Value<String> localData;
  final Value<int?> serverVersion;
  final Value<String?> serverData;
  final Value<DateTime> detectedAt;
  final Value<DateTime?> resolvedAt;
  final Value<String?> resolution;
  const SyncConflictsCompanion({
    this.id = const Value.absent(),
    this.changeId = const Value.absent(),
    this.entity = const Value.absent(),
    this.entityId = const Value.absent(),
    this.op = const Value.absent(),
    this.baseVersion = const Value.absent(),
    this.localData = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.serverData = const Value.absent(),
    this.detectedAt = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.resolution = const Value.absent(),
  });
  SyncConflictsCompanion.insert({
    this.id = const Value.absent(),
    required String changeId,
    required String entity,
    required String entityId,
    required String op,
    this.baseVersion = const Value.absent(),
    required String localData,
    this.serverVersion = const Value.absent(),
    this.serverData = const Value.absent(),
    required DateTime detectedAt,
    this.resolvedAt = const Value.absent(),
    this.resolution = const Value.absent(),
  }) : changeId = Value(changeId),
       entity = Value(entity),
       entityId = Value(entityId),
       op = Value(op),
       localData = Value(localData),
       detectedAt = Value(detectedAt);
  static Insertable<SyncConflictRow> custom({
    Expression<int>? id,
    Expression<String>? changeId,
    Expression<String>? entity,
    Expression<String>? entityId,
    Expression<String>? op,
    Expression<int>? baseVersion,
    Expression<String>? localData,
    Expression<int>? serverVersion,
    Expression<String>? serverData,
    Expression<DateTime>? detectedAt,
    Expression<DateTime>? resolvedAt,
    Expression<String>? resolution,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (changeId != null) 'change_id': changeId,
      if (entity != null) 'entity': entity,
      if (entityId != null) 'entity_id': entityId,
      if (op != null) 'op': op,
      if (baseVersion != null) 'base_version': baseVersion,
      if (localData != null) 'local_data': localData,
      if (serverVersion != null) 'server_version': serverVersion,
      if (serverData != null) 'server_data': serverData,
      if (detectedAt != null) 'detected_at': detectedAt,
      if (resolvedAt != null) 'resolved_at': resolvedAt,
      if (resolution != null) 'resolution': resolution,
    });
  }

  SyncConflictsCompanion copyWith({
    Value<int>? id,
    Value<String>? changeId,
    Value<String>? entity,
    Value<String>? entityId,
    Value<String>? op,
    Value<int?>? baseVersion,
    Value<String>? localData,
    Value<int?>? serverVersion,
    Value<String?>? serverData,
    Value<DateTime>? detectedAt,
    Value<DateTime?>? resolvedAt,
    Value<String?>? resolution,
  }) {
    return SyncConflictsCompanion(
      id: id ?? this.id,
      changeId: changeId ?? this.changeId,
      entity: entity ?? this.entity,
      entityId: entityId ?? this.entityId,
      op: op ?? this.op,
      baseVersion: baseVersion ?? this.baseVersion,
      localData: localData ?? this.localData,
      serverVersion: serverVersion ?? this.serverVersion,
      serverData: serverData ?? this.serverData,
      detectedAt: detectedAt ?? this.detectedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolution: resolution ?? this.resolution,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (changeId.present) {
      map['change_id'] = Variable<String>(changeId.value);
    }
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (op.present) {
      map['op'] = Variable<String>(op.value);
    }
    if (baseVersion.present) {
      map['base_version'] = Variable<int>(baseVersion.value);
    }
    if (localData.present) {
      map['local_data'] = Variable<String>(localData.value);
    }
    if (serverVersion.present) {
      map['server_version'] = Variable<int>(serverVersion.value);
    }
    if (serverData.present) {
      map['server_data'] = Variable<String>(serverData.value);
    }
    if (detectedAt.present) {
      map['detected_at'] = Variable<DateTime>(detectedAt.value);
    }
    if (resolvedAt.present) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt.value);
    }
    if (resolution.present) {
      map['resolution'] = Variable<String>(resolution.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncConflictsCompanion(')
          ..write('id: $id, ')
          ..write('changeId: $changeId, ')
          ..write('entity: $entity, ')
          ..write('entityId: $entityId, ')
          ..write('op: $op, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('localData: $localData, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('serverData: $serverData, ')
          ..write('detectedAt: $detectedAt, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('resolution: $resolution')
          ..write(')'))
        .toString();
  }
}

class $SyncStateTable extends SyncState
    with TableInfo<$SyncStateTable, SyncStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SyncStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateRow(
      key:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}key'],
          )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      ),
    );
  }

  @override
  $SyncStateTable createAlias(String alias) {
    return $SyncStateTable(attachedDatabase, alias);
  }
}

class SyncStateRow extends DataClass implements Insertable<SyncStateRow> {
  final String key;
  final String? value;
  const SyncStateRow({required this.key, this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<String>(value);
    }
    return map;
  }

  SyncStateCompanion toCompanion(bool nullToAbsent) {
    return SyncStateCompanion(
      key: Value(key),
      value:
          value == null && nullToAbsent ? const Value.absent() : Value(value),
    );
  }

  factory SyncStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String?>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String?>(value),
    };
  }

  SyncStateRow copyWith({
    String? key,
    Value<String?> value = const Value.absent(),
  }) => SyncStateRow(
    key: key ?? this.key,
    value: value.present ? value.value : this.value,
  );
  SyncStateRow copyWithCompanion(SyncStateCompanion data) {
    return SyncStateRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateRow &&
          other.key == this.key &&
          other.value == this.value);
}

class SyncStateCompanion extends UpdateCompanion<SyncStateRow> {
  final Value<String> key;
  final Value<String?> value;
  final Value<int> rowid;
  const SyncStateCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStateCompanion.insert({
    required String key,
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key);
  static Insertable<SyncStateRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStateCompanion copyWith({
    Value<String>? key,
    Value<String?>? value,
    Value<int>? rowid,
  }) {
    return SyncStateCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $BeneficiariesTable beneficiaries = $BeneficiariesTable(this);
  late final $BeneficiaryIdentitiesTable beneficiaryIdentities =
      $BeneficiaryIdentitiesTable(this);
  late final $ConsentsTable consents = $ConsentsTable(this);
  late final $PregnanciesTable pregnancies = $PregnanciesTable(this);
  late final $AncVisitsTable ancVisits = $AncVisitsTable(this);
  late final $ReferralsTable referrals = $ReferralsTable(this);
  late final $AlertsTable alerts = $AlertsTable(this);
  late final $SitesTable sites = $SitesTable(this);
  late final $ReferenceCacheTable referenceCache = $ReferenceCacheTable(this);
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $SyncConflictsTable syncConflicts = $SyncConflictsTable(this);
  late final $SyncStateTable syncState = $SyncStateTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    beneficiaries,
    beneficiaryIdentities,
    consents,
    pregnancies,
    ancVisits,
    referrals,
    alerts,
    sites,
    referenceCache,
    outbox,
    syncConflicts,
    syncState,
  ];
}

typedef $$BeneficiariesTableCreateCompanionBuilder =
    BeneficiariesCompanion Function({
      Value<int> version,
      Value<String?> createdAt,
      Value<String?> updatedAt,
      Value<String?> deletedAt,
      required String id,
      Value<String?> code,
      Value<String?> siteId,
      Value<int?> birthYear,
      Value<String> preferredChannel,
      Value<int> rowid,
    });
typedef $$BeneficiariesTableUpdateCompanionBuilder =
    BeneficiariesCompanion Function({
      Value<int> version,
      Value<String?> createdAt,
      Value<String?> updatedAt,
      Value<String?> deletedAt,
      Value<String> id,
      Value<String?> code,
      Value<String?> siteId,
      Value<int?> birthYear,
      Value<String> preferredChannel,
      Value<int> rowid,
    });

class $$BeneficiariesTableFilterComposer
    extends Composer<_$AppDatabase, $BeneficiariesTable> {
  $$BeneficiariesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get siteId => $composableBuilder(
    column: $table.siteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get birthYear => $composableBuilder(
    column: $table.birthYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preferredChannel => $composableBuilder(
    column: $table.preferredChannel,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BeneficiariesTableOrderingComposer
    extends Composer<_$AppDatabase, $BeneficiariesTable> {
  $$BeneficiariesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get siteId => $composableBuilder(
    column: $table.siteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get birthYear => $composableBuilder(
    column: $table.birthYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preferredChannel => $composableBuilder(
    column: $table.preferredChannel,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BeneficiariesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BeneficiariesTable> {
  $$BeneficiariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get siteId =>
      $composableBuilder(column: $table.siteId, builder: (column) => column);

  GeneratedColumn<int> get birthYear =>
      $composableBuilder(column: $table.birthYear, builder: (column) => column);

  GeneratedColumn<String> get preferredChannel => $composableBuilder(
    column: $table.preferredChannel,
    builder: (column) => column,
  );
}

class $$BeneficiariesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BeneficiariesTable,
          BeneficiaryRow,
          $$BeneficiariesTableFilterComposer,
          $$BeneficiariesTableOrderingComposer,
          $$BeneficiariesTableAnnotationComposer,
          $$BeneficiariesTableCreateCompanionBuilder,
          $$BeneficiariesTableUpdateCompanionBuilder,
          (
            BeneficiaryRow,
            BaseReferences<_$AppDatabase, $BeneficiariesTable, BeneficiaryRow>,
          ),
          BeneficiaryRow,
          PrefetchHooks Function()
        > {
  $$BeneficiariesTableTableManager(_$AppDatabase db, $BeneficiariesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$BeneficiariesTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () =>
                  $$BeneficiariesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$BeneficiariesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> version = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String?> code = const Value.absent(),
                Value<String?> siteId = const Value.absent(),
                Value<int?> birthYear = const Value.absent(),
                Value<String> preferredChannel = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BeneficiariesCompanion(
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                code: code,
                siteId: siteId,
                birthYear: birthYear,
                preferredChannel: preferredChannel,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<int> version = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                required String id,
                Value<String?> code = const Value.absent(),
                Value<String?> siteId = const Value.absent(),
                Value<int?> birthYear = const Value.absent(),
                Value<String> preferredChannel = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BeneficiariesCompanion.insert(
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                code: code,
                siteId: siteId,
                birthYear: birthYear,
                preferredChannel: preferredChannel,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BeneficiariesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BeneficiariesTable,
      BeneficiaryRow,
      $$BeneficiariesTableFilterComposer,
      $$BeneficiariesTableOrderingComposer,
      $$BeneficiariesTableAnnotationComposer,
      $$BeneficiariesTableCreateCompanionBuilder,
      $$BeneficiariesTableUpdateCompanionBuilder,
      (
        BeneficiaryRow,
        BaseReferences<_$AppDatabase, $BeneficiariesTable, BeneficiaryRow>,
      ),
      BeneficiaryRow,
      PrefetchHooks Function()
    >;
typedef $$BeneficiaryIdentitiesTableCreateCompanionBuilder =
    BeneficiaryIdentitiesCompanion Function({
      Value<int> version,
      Value<String?> createdAt,
      Value<String?> updatedAt,
      Value<String?> deletedAt,
      required String beneficiaryId,
      required String displayName,
      Value<String?> phone,
      Value<String?> village,
      Value<int> rowid,
    });
typedef $$BeneficiaryIdentitiesTableUpdateCompanionBuilder =
    BeneficiaryIdentitiesCompanion Function({
      Value<int> version,
      Value<String?> createdAt,
      Value<String?> updatedAt,
      Value<String?> deletedAt,
      Value<String> beneficiaryId,
      Value<String> displayName,
      Value<String?> phone,
      Value<String?> village,
      Value<int> rowid,
    });

class $$BeneficiaryIdentitiesTableFilterComposer
    extends Composer<_$AppDatabase, $BeneficiaryIdentitiesTable> {
  $$BeneficiaryIdentitiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get beneficiaryId => $composableBuilder(
    column: $table.beneficiaryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get village => $composableBuilder(
    column: $table.village,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BeneficiaryIdentitiesTableOrderingComposer
    extends Composer<_$AppDatabase, $BeneficiaryIdentitiesTable> {
  $$BeneficiaryIdentitiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get beneficiaryId => $composableBuilder(
    column: $table.beneficiaryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get village => $composableBuilder(
    column: $table.village,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BeneficiaryIdentitiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BeneficiaryIdentitiesTable> {
  $$BeneficiaryIdentitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get beneficiaryId => $composableBuilder(
    column: $table.beneficiaryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get village =>
      $composableBuilder(column: $table.village, builder: (column) => column);
}

class $$BeneficiaryIdentitiesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BeneficiaryIdentitiesTable,
          BeneficiaryIdentityRow,
          $$BeneficiaryIdentitiesTableFilterComposer,
          $$BeneficiaryIdentitiesTableOrderingComposer,
          $$BeneficiaryIdentitiesTableAnnotationComposer,
          $$BeneficiaryIdentitiesTableCreateCompanionBuilder,
          $$BeneficiaryIdentitiesTableUpdateCompanionBuilder,
          (
            BeneficiaryIdentityRow,
            BaseReferences<
              _$AppDatabase,
              $BeneficiaryIdentitiesTable,
              BeneficiaryIdentityRow
            >,
          ),
          BeneficiaryIdentityRow,
          PrefetchHooks Function()
        > {
  $$BeneficiaryIdentitiesTableTableManager(
    _$AppDatabase db,
    $BeneficiaryIdentitiesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$BeneficiaryIdentitiesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$BeneficiaryIdentitiesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$BeneficiaryIdentitiesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> version = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<String> beneficiaryId = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> village = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BeneficiaryIdentitiesCompanion(
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                beneficiaryId: beneficiaryId,
                displayName: displayName,
                phone: phone,
                village: village,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<int> version = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                required String beneficiaryId,
                required String displayName,
                Value<String?> phone = const Value.absent(),
                Value<String?> village = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BeneficiaryIdentitiesCompanion.insert(
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                beneficiaryId: beneficiaryId,
                displayName: displayName,
                phone: phone,
                village: village,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BeneficiaryIdentitiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BeneficiaryIdentitiesTable,
      BeneficiaryIdentityRow,
      $$BeneficiaryIdentitiesTableFilterComposer,
      $$BeneficiaryIdentitiesTableOrderingComposer,
      $$BeneficiaryIdentitiesTableAnnotationComposer,
      $$BeneficiaryIdentitiesTableCreateCompanionBuilder,
      $$BeneficiaryIdentitiesTableUpdateCompanionBuilder,
      (
        BeneficiaryIdentityRow,
        BaseReferences<
          _$AppDatabase,
          $BeneficiaryIdentitiesTable,
          BeneficiaryIdentityRow
        >,
      ),
      BeneficiaryIdentityRow,
      PrefetchHooks Function()
    >;
typedef $$ConsentsTableCreateCompanionBuilder =
    ConsentsCompanion Function({
      Value<int> version,
      Value<String?> createdAt,
      Value<String?> updatedAt,
      Value<String?> deletedAt,
      required String id,
      required String beneficiaryId,
      required String scope,
      required String method,
      required String informationVersion,
      Value<String?> collectedByUserId,
      required String collectedAt,
      Value<String?> withdrawnAt,
      Value<String?> withdrawnByUserId,
      Value<int> rowid,
    });
typedef $$ConsentsTableUpdateCompanionBuilder =
    ConsentsCompanion Function({
      Value<int> version,
      Value<String?> createdAt,
      Value<String?> updatedAt,
      Value<String?> deletedAt,
      Value<String> id,
      Value<String> beneficiaryId,
      Value<String> scope,
      Value<String> method,
      Value<String> informationVersion,
      Value<String?> collectedByUserId,
      Value<String> collectedAt,
      Value<String?> withdrawnAt,
      Value<String?> withdrawnByUserId,
      Value<int> rowid,
    });

class $$ConsentsTableFilterComposer
    extends Composer<_$AppDatabase, $ConsentsTable> {
  $$ConsentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get beneficiaryId => $composableBuilder(
    column: $table.beneficiaryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get informationVersion => $composableBuilder(
    column: $table.informationVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get collectedByUserId => $composableBuilder(
    column: $table.collectedByUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get collectedAt => $composableBuilder(
    column: $table.collectedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get withdrawnAt => $composableBuilder(
    column: $table.withdrawnAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get withdrawnByUserId => $composableBuilder(
    column: $table.withdrawnByUserId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConsentsTableOrderingComposer
    extends Composer<_$AppDatabase, $ConsentsTable> {
  $$ConsentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get beneficiaryId => $composableBuilder(
    column: $table.beneficiaryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get informationVersion => $composableBuilder(
    column: $table.informationVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get collectedByUserId => $composableBuilder(
    column: $table.collectedByUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get collectedAt => $composableBuilder(
    column: $table.collectedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get withdrawnAt => $composableBuilder(
    column: $table.withdrawnAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get withdrawnByUserId => $composableBuilder(
    column: $table.withdrawnByUserId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConsentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConsentsTable> {
  $$ConsentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get beneficiaryId => $composableBuilder(
    column: $table.beneficiaryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => column);

  GeneratedColumn<String> get informationVersion => $composableBuilder(
    column: $table.informationVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get collectedByUserId => $composableBuilder(
    column: $table.collectedByUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get collectedAt => $composableBuilder(
    column: $table.collectedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get withdrawnAt => $composableBuilder(
    column: $table.withdrawnAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get withdrawnByUserId => $composableBuilder(
    column: $table.withdrawnByUserId,
    builder: (column) => column,
  );
}

class $$ConsentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConsentsTable,
          ConsentRow,
          $$ConsentsTableFilterComposer,
          $$ConsentsTableOrderingComposer,
          $$ConsentsTableAnnotationComposer,
          $$ConsentsTableCreateCompanionBuilder,
          $$ConsentsTableUpdateCompanionBuilder,
          (
            ConsentRow,
            BaseReferences<_$AppDatabase, $ConsentsTable, ConsentRow>,
          ),
          ConsentRow,
          PrefetchHooks Function()
        > {
  $$ConsentsTableTableManager(_$AppDatabase db, $ConsentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$ConsentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$ConsentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$ConsentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> version = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> beneficiaryId = const Value.absent(),
                Value<String> scope = const Value.absent(),
                Value<String> method = const Value.absent(),
                Value<String> informationVersion = const Value.absent(),
                Value<String?> collectedByUserId = const Value.absent(),
                Value<String> collectedAt = const Value.absent(),
                Value<String?> withdrawnAt = const Value.absent(),
                Value<String?> withdrawnByUserId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConsentsCompanion(
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                beneficiaryId: beneficiaryId,
                scope: scope,
                method: method,
                informationVersion: informationVersion,
                collectedByUserId: collectedByUserId,
                collectedAt: collectedAt,
                withdrawnAt: withdrawnAt,
                withdrawnByUserId: withdrawnByUserId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<int> version = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                required String id,
                required String beneficiaryId,
                required String scope,
                required String method,
                required String informationVersion,
                Value<String?> collectedByUserId = const Value.absent(),
                required String collectedAt,
                Value<String?> withdrawnAt = const Value.absent(),
                Value<String?> withdrawnByUserId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConsentsCompanion.insert(
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                beneficiaryId: beneficiaryId,
                scope: scope,
                method: method,
                informationVersion: informationVersion,
                collectedByUserId: collectedByUserId,
                collectedAt: collectedAt,
                withdrawnAt: withdrawnAt,
                withdrawnByUserId: withdrawnByUserId,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConsentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConsentsTable,
      ConsentRow,
      $$ConsentsTableFilterComposer,
      $$ConsentsTableOrderingComposer,
      $$ConsentsTableAnnotationComposer,
      $$ConsentsTableCreateCompanionBuilder,
      $$ConsentsTableUpdateCompanionBuilder,
      (ConsentRow, BaseReferences<_$AppDatabase, $ConsentsTable, ConsentRow>),
      ConsentRow,
      PrefetchHooks Function()
    >;
typedef $$PregnanciesTableCreateCompanionBuilder =
    PregnanciesCompanion Function({
      Value<int> version,
      Value<String?> createdAt,
      Value<String?> updatedAt,
      Value<String?> deletedAt,
      required String id,
      required String beneficiaryId,
      Value<String> status,
      Value<String?> lmpDate,
      Value<String?> estimatedDueDate,
      Value<String> datesConfirmedBy,
      Value<int> rowid,
    });
typedef $$PregnanciesTableUpdateCompanionBuilder =
    PregnanciesCompanion Function({
      Value<int> version,
      Value<String?> createdAt,
      Value<String?> updatedAt,
      Value<String?> deletedAt,
      Value<String> id,
      Value<String> beneficiaryId,
      Value<String> status,
      Value<String?> lmpDate,
      Value<String?> estimatedDueDate,
      Value<String> datesConfirmedBy,
      Value<int> rowid,
    });

class $$PregnanciesTableFilterComposer
    extends Composer<_$AppDatabase, $PregnanciesTable> {
  $$PregnanciesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get beneficiaryId => $composableBuilder(
    column: $table.beneficiaryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lmpDate => $composableBuilder(
    column: $table.lmpDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get estimatedDueDate => $composableBuilder(
    column: $table.estimatedDueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get datesConfirmedBy => $composableBuilder(
    column: $table.datesConfirmedBy,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PregnanciesTableOrderingComposer
    extends Composer<_$AppDatabase, $PregnanciesTable> {
  $$PregnanciesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get beneficiaryId => $composableBuilder(
    column: $table.beneficiaryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lmpDate => $composableBuilder(
    column: $table.lmpDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get estimatedDueDate => $composableBuilder(
    column: $table.estimatedDueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get datesConfirmedBy => $composableBuilder(
    column: $table.datesConfirmedBy,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PregnanciesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PregnanciesTable> {
  $$PregnanciesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get beneficiaryId => $composableBuilder(
    column: $table.beneficiaryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get lmpDate =>
      $composableBuilder(column: $table.lmpDate, builder: (column) => column);

  GeneratedColumn<String> get estimatedDueDate => $composableBuilder(
    column: $table.estimatedDueDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get datesConfirmedBy => $composableBuilder(
    column: $table.datesConfirmedBy,
    builder: (column) => column,
  );
}

class $$PregnanciesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PregnanciesTable,
          PregnancyRow,
          $$PregnanciesTableFilterComposer,
          $$PregnanciesTableOrderingComposer,
          $$PregnanciesTableAnnotationComposer,
          $$PregnanciesTableCreateCompanionBuilder,
          $$PregnanciesTableUpdateCompanionBuilder,
          (
            PregnancyRow,
            BaseReferences<_$AppDatabase, $PregnanciesTable, PregnancyRow>,
          ),
          PregnancyRow,
          PrefetchHooks Function()
        > {
  $$PregnanciesTableTableManager(_$AppDatabase db, $PregnanciesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$PregnanciesTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$PregnanciesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () =>
                  $$PregnanciesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> version = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> beneficiaryId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> lmpDate = const Value.absent(),
                Value<String?> estimatedDueDate = const Value.absent(),
                Value<String> datesConfirmedBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PregnanciesCompanion(
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                beneficiaryId: beneficiaryId,
                status: status,
                lmpDate: lmpDate,
                estimatedDueDate: estimatedDueDate,
                datesConfirmedBy: datesConfirmedBy,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<int> version = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                required String id,
                required String beneficiaryId,
                Value<String> status = const Value.absent(),
                Value<String?> lmpDate = const Value.absent(),
                Value<String?> estimatedDueDate = const Value.absent(),
                Value<String> datesConfirmedBy = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PregnanciesCompanion.insert(
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                beneficiaryId: beneficiaryId,
                status: status,
                lmpDate: lmpDate,
                estimatedDueDate: estimatedDueDate,
                datesConfirmedBy: datesConfirmedBy,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PregnanciesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PregnanciesTable,
      PregnancyRow,
      $$PregnanciesTableFilterComposer,
      $$PregnanciesTableOrderingComposer,
      $$PregnanciesTableAnnotationComposer,
      $$PregnanciesTableCreateCompanionBuilder,
      $$PregnanciesTableUpdateCompanionBuilder,
      (
        PregnancyRow,
        BaseReferences<_$AppDatabase, $PregnanciesTable, PregnancyRow>,
      ),
      PregnancyRow,
      PrefetchHooks Function()
    >;
typedef $$AncVisitsTableCreateCompanionBuilder =
    AncVisitsCompanion Function({
      Value<int> version,
      Value<String?> createdAt,
      Value<String?> updatedAt,
      Value<String?> deletedAt,
      required String id,
      required String pregnancyId,
      required int sequence,
      required String scheduledDate,
      Value<String> status,
      Value<String?> doneDate,
      Value<String?> siteId,
      Value<int> rowid,
    });
typedef $$AncVisitsTableUpdateCompanionBuilder =
    AncVisitsCompanion Function({
      Value<int> version,
      Value<String?> createdAt,
      Value<String?> updatedAt,
      Value<String?> deletedAt,
      Value<String> id,
      Value<String> pregnancyId,
      Value<int> sequence,
      Value<String> scheduledDate,
      Value<String> status,
      Value<String?> doneDate,
      Value<String?> siteId,
      Value<int> rowid,
    });

class $$AncVisitsTableFilterComposer
    extends Composer<_$AppDatabase, $AncVisitsTable> {
  $$AncVisitsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pregnancyId => $composableBuilder(
    column: $table.pregnancyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scheduledDate => $composableBuilder(
    column: $table.scheduledDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get doneDate => $composableBuilder(
    column: $table.doneDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get siteId => $composableBuilder(
    column: $table.siteId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AncVisitsTableOrderingComposer
    extends Composer<_$AppDatabase, $AncVisitsTable> {
  $$AncVisitsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pregnancyId => $composableBuilder(
    column: $table.pregnancyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scheduledDate => $composableBuilder(
    column: $table.scheduledDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get doneDate => $composableBuilder(
    column: $table.doneDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get siteId => $composableBuilder(
    column: $table.siteId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AncVisitsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AncVisitsTable> {
  $$AncVisitsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get pregnancyId => $composableBuilder(
    column: $table.pregnancyId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sequence =>
      $composableBuilder(column: $table.sequence, builder: (column) => column);

  GeneratedColumn<String> get scheduledDate => $composableBuilder(
    column: $table.scheduledDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get doneDate =>
      $composableBuilder(column: $table.doneDate, builder: (column) => column);

  GeneratedColumn<String> get siteId =>
      $composableBuilder(column: $table.siteId, builder: (column) => column);
}

class $$AncVisitsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AncVisitsTable,
          AncVisitRow,
          $$AncVisitsTableFilterComposer,
          $$AncVisitsTableOrderingComposer,
          $$AncVisitsTableAnnotationComposer,
          $$AncVisitsTableCreateCompanionBuilder,
          $$AncVisitsTableUpdateCompanionBuilder,
          (
            AncVisitRow,
            BaseReferences<_$AppDatabase, $AncVisitsTable, AncVisitRow>,
          ),
          AncVisitRow,
          PrefetchHooks Function()
        > {
  $$AncVisitsTableTableManager(_$AppDatabase db, $AncVisitsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$AncVisitsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$AncVisitsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$AncVisitsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> version = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> pregnancyId = const Value.absent(),
                Value<int> sequence = const Value.absent(),
                Value<String> scheduledDate = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> doneDate = const Value.absent(),
                Value<String?> siteId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AncVisitsCompanion(
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                pregnancyId: pregnancyId,
                sequence: sequence,
                scheduledDate: scheduledDate,
                status: status,
                doneDate: doneDate,
                siteId: siteId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<int> version = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                required String id,
                required String pregnancyId,
                required int sequence,
                required String scheduledDate,
                Value<String> status = const Value.absent(),
                Value<String?> doneDate = const Value.absent(),
                Value<String?> siteId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AncVisitsCompanion.insert(
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                pregnancyId: pregnancyId,
                sequence: sequence,
                scheduledDate: scheduledDate,
                status: status,
                doneDate: doneDate,
                siteId: siteId,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AncVisitsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AncVisitsTable,
      AncVisitRow,
      $$AncVisitsTableFilterComposer,
      $$AncVisitsTableOrderingComposer,
      $$AncVisitsTableAnnotationComposer,
      $$AncVisitsTableCreateCompanionBuilder,
      $$AncVisitsTableUpdateCompanionBuilder,
      (
        AncVisitRow,
        BaseReferences<_$AppDatabase, $AncVisitsTable, AncVisitRow>,
      ),
      AncVisitRow,
      PrefetchHooks Function()
    >;
typedef $$ReferralsTableCreateCompanionBuilder =
    ReferralsCompanion Function({
      Value<int> version,
      Value<String?> createdAt,
      Value<String?> updatedAt,
      Value<String?> deletedAt,
      required String id,
      required String beneficiaryId,
      Value<String?> alertId,
      Value<String?> fromSiteId,
      required String toSiteId,
      Value<String> status,
      Value<String?> reason,
      Value<String?> outcomeNote,
      Value<int> rowid,
    });
typedef $$ReferralsTableUpdateCompanionBuilder =
    ReferralsCompanion Function({
      Value<int> version,
      Value<String?> createdAt,
      Value<String?> updatedAt,
      Value<String?> deletedAt,
      Value<String> id,
      Value<String> beneficiaryId,
      Value<String?> alertId,
      Value<String?> fromSiteId,
      Value<String> toSiteId,
      Value<String> status,
      Value<String?> reason,
      Value<String?> outcomeNote,
      Value<int> rowid,
    });

class $$ReferralsTableFilterComposer
    extends Composer<_$AppDatabase, $ReferralsTable> {
  $$ReferralsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get beneficiaryId => $composableBuilder(
    column: $table.beneficiaryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alertId => $composableBuilder(
    column: $table.alertId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fromSiteId => $composableBuilder(
    column: $table.fromSiteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toSiteId => $composableBuilder(
    column: $table.toSiteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outcomeNote => $composableBuilder(
    column: $table.outcomeNote,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReferralsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReferralsTable> {
  $$ReferralsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get beneficiaryId => $composableBuilder(
    column: $table.beneficiaryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alertId => $composableBuilder(
    column: $table.alertId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fromSiteId => $composableBuilder(
    column: $table.fromSiteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toSiteId => $composableBuilder(
    column: $table.toSiteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outcomeNote => $composableBuilder(
    column: $table.outcomeNote,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReferralsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReferralsTable> {
  $$ReferralsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get beneficiaryId => $composableBuilder(
    column: $table.beneficiaryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get alertId =>
      $composableBuilder(column: $table.alertId, builder: (column) => column);

  GeneratedColumn<String> get fromSiteId => $composableBuilder(
    column: $table.fromSiteId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get toSiteId =>
      $composableBuilder(column: $table.toSiteId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<String> get outcomeNote => $composableBuilder(
    column: $table.outcomeNote,
    builder: (column) => column,
  );
}

class $$ReferralsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReferralsTable,
          ReferralRow,
          $$ReferralsTableFilterComposer,
          $$ReferralsTableOrderingComposer,
          $$ReferralsTableAnnotationComposer,
          $$ReferralsTableCreateCompanionBuilder,
          $$ReferralsTableUpdateCompanionBuilder,
          (
            ReferralRow,
            BaseReferences<_$AppDatabase, $ReferralsTable, ReferralRow>,
          ),
          ReferralRow,
          PrefetchHooks Function()
        > {
  $$ReferralsTableTableManager(_$AppDatabase db, $ReferralsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$ReferralsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$ReferralsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$ReferralsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> version = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> beneficiaryId = const Value.absent(),
                Value<String?> alertId = const Value.absent(),
                Value<String?> fromSiteId = const Value.absent(),
                Value<String> toSiteId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> reason = const Value.absent(),
                Value<String?> outcomeNote = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReferralsCompanion(
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                beneficiaryId: beneficiaryId,
                alertId: alertId,
                fromSiteId: fromSiteId,
                toSiteId: toSiteId,
                status: status,
                reason: reason,
                outcomeNote: outcomeNote,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<int> version = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                required String id,
                required String beneficiaryId,
                Value<String?> alertId = const Value.absent(),
                Value<String?> fromSiteId = const Value.absent(),
                required String toSiteId,
                Value<String> status = const Value.absent(),
                Value<String?> reason = const Value.absent(),
                Value<String?> outcomeNote = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReferralsCompanion.insert(
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                beneficiaryId: beneficiaryId,
                alertId: alertId,
                fromSiteId: fromSiteId,
                toSiteId: toSiteId,
                status: status,
                reason: reason,
                outcomeNote: outcomeNote,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReferralsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReferralsTable,
      ReferralRow,
      $$ReferralsTableFilterComposer,
      $$ReferralsTableOrderingComposer,
      $$ReferralsTableAnnotationComposer,
      $$ReferralsTableCreateCompanionBuilder,
      $$ReferralsTableUpdateCompanionBuilder,
      (
        ReferralRow,
        BaseReferences<_$AppDatabase, $ReferralsTable, ReferralRow>,
      ),
      ReferralRow,
      PrefetchHooks Function()
    >;
typedef $$AlertsTableCreateCompanionBuilder =
    AlertsCompanion Function({
      required String id,
      Value<String?> beneficiaryId,
      Value<String?> interactionId,
      Value<String?> ruleId,
      Value<String?> rulesetVersion,
      Value<String?> severity,
      Value<String> status,
      Value<String?> recipientUserId,
      Value<String?> backupUserId,
      Value<String?> dueAt,
      Value<String?> acknowledgedAt,
      Value<String?> resolvedAt,
      Value<bool> isDemo,
      Value<String?> createdAt,
      Value<int> version,
      Value<String?> deletedAt,
      Value<int> rowid,
    });
typedef $$AlertsTableUpdateCompanionBuilder =
    AlertsCompanion Function({
      Value<String> id,
      Value<String?> beneficiaryId,
      Value<String?> interactionId,
      Value<String?> ruleId,
      Value<String?> rulesetVersion,
      Value<String?> severity,
      Value<String> status,
      Value<String?> recipientUserId,
      Value<String?> backupUserId,
      Value<String?> dueAt,
      Value<String?> acknowledgedAt,
      Value<String?> resolvedAt,
      Value<bool> isDemo,
      Value<String?> createdAt,
      Value<int> version,
      Value<String?> deletedAt,
      Value<int> rowid,
    });

class $$AlertsTableFilterComposer
    extends Composer<_$AppDatabase, $AlertsTable> {
  $$AlertsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get beneficiaryId => $composableBuilder(
    column: $table.beneficiaryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get interactionId => $composableBuilder(
    column: $table.interactionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ruleId => $composableBuilder(
    column: $table.ruleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rulesetVersion => $composableBuilder(
    column: $table.rulesetVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get severity => $composableBuilder(
    column: $table.severity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recipientUserId => $composableBuilder(
    column: $table.recipientUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backupUserId => $composableBuilder(
    column: $table.backupUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get acknowledgedAt => $composableBuilder(
    column: $table.acknowledgedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDemo => $composableBuilder(
    column: $table.isDemo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AlertsTableOrderingComposer
    extends Composer<_$AppDatabase, $AlertsTable> {
  $$AlertsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get beneficiaryId => $composableBuilder(
    column: $table.beneficiaryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get interactionId => $composableBuilder(
    column: $table.interactionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ruleId => $composableBuilder(
    column: $table.ruleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rulesetVersion => $composableBuilder(
    column: $table.rulesetVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get severity => $composableBuilder(
    column: $table.severity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recipientUserId => $composableBuilder(
    column: $table.recipientUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backupUserId => $composableBuilder(
    column: $table.backupUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get acknowledgedAt => $composableBuilder(
    column: $table.acknowledgedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDemo => $composableBuilder(
    column: $table.isDemo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AlertsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AlertsTable> {
  $$AlertsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get beneficiaryId => $composableBuilder(
    column: $table.beneficiaryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get interactionId => $composableBuilder(
    column: $table.interactionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ruleId =>
      $composableBuilder(column: $table.ruleId, builder: (column) => column);

  GeneratedColumn<String> get rulesetVersion => $composableBuilder(
    column: $table.rulesetVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get severity =>
      $composableBuilder(column: $table.severity, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get recipientUserId => $composableBuilder(
    column: $table.recipientUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get backupUserId => $composableBuilder(
    column: $table.backupUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => column);

  GeneratedColumn<String> get acknowledgedAt => $composableBuilder(
    column: $table.acknowledgedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDemo =>
      $composableBuilder(column: $table.isDemo, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$AlertsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AlertsTable,
          AlertRow,
          $$AlertsTableFilterComposer,
          $$AlertsTableOrderingComposer,
          $$AlertsTableAnnotationComposer,
          $$AlertsTableCreateCompanionBuilder,
          $$AlertsTableUpdateCompanionBuilder,
          (AlertRow, BaseReferences<_$AppDatabase, $AlertsTable, AlertRow>),
          AlertRow,
          PrefetchHooks Function()
        > {
  $$AlertsTableTableManager(_$AppDatabase db, $AlertsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$AlertsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$AlertsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$AlertsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> beneficiaryId = const Value.absent(),
                Value<String?> interactionId = const Value.absent(),
                Value<String?> ruleId = const Value.absent(),
                Value<String?> rulesetVersion = const Value.absent(),
                Value<String?> severity = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> recipientUserId = const Value.absent(),
                Value<String?> backupUserId = const Value.absent(),
                Value<String?> dueAt = const Value.absent(),
                Value<String?> acknowledgedAt = const Value.absent(),
                Value<String?> resolvedAt = const Value.absent(),
                Value<bool> isDemo = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AlertsCompanion(
                id: id,
                beneficiaryId: beneficiaryId,
                interactionId: interactionId,
                ruleId: ruleId,
                rulesetVersion: rulesetVersion,
                severity: severity,
                status: status,
                recipientUserId: recipientUserId,
                backupUserId: backupUserId,
                dueAt: dueAt,
                acknowledgedAt: acknowledgedAt,
                resolvedAt: resolvedAt,
                isDemo: isDemo,
                createdAt: createdAt,
                version: version,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> beneficiaryId = const Value.absent(),
                Value<String?> interactionId = const Value.absent(),
                Value<String?> ruleId = const Value.absent(),
                Value<String?> rulesetVersion = const Value.absent(),
                Value<String?> severity = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> recipientUserId = const Value.absent(),
                Value<String?> backupUserId = const Value.absent(),
                Value<String?> dueAt = const Value.absent(),
                Value<String?> acknowledgedAt = const Value.absent(),
                Value<String?> resolvedAt = const Value.absent(),
                Value<bool> isDemo = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AlertsCompanion.insert(
                id: id,
                beneficiaryId: beneficiaryId,
                interactionId: interactionId,
                ruleId: ruleId,
                rulesetVersion: rulesetVersion,
                severity: severity,
                status: status,
                recipientUserId: recipientUserId,
                backupUserId: backupUserId,
                dueAt: dueAt,
                acknowledgedAt: acknowledgedAt,
                resolvedAt: resolvedAt,
                isDemo: isDemo,
                createdAt: createdAt,
                version: version,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AlertsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AlertsTable,
      AlertRow,
      $$AlertsTableFilterComposer,
      $$AlertsTableOrderingComposer,
      $$AlertsTableAnnotationComposer,
      $$AlertsTableCreateCompanionBuilder,
      $$AlertsTableUpdateCompanionBuilder,
      (AlertRow, BaseReferences<_$AppDatabase, $AlertsTable, AlertRow>),
      AlertRow,
      PrefetchHooks Function()
    >;
typedef $$SitesTableCreateCompanionBuilder =
    SitesCompanion Function({
      required String id,
      required String name,
      required String kind,
      Value<String?> code,
      Value<String?> district,
      Value<String?> region,
      Value<String?> parentSiteId,
      Value<bool> isActive,
      Value<int> version,
      Value<String?> deletedAt,
      Value<int> rowid,
    });
typedef $$SitesTableUpdateCompanionBuilder =
    SitesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> kind,
      Value<String?> code,
      Value<String?> district,
      Value<String?> region,
      Value<String?> parentSiteId,
      Value<bool> isActive,
      Value<int> version,
      Value<String?> deletedAt,
      Value<int> rowid,
    });

class $$SitesTableFilterComposer extends Composer<_$AppDatabase, $SitesTable> {
  $$SitesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get district => $composableBuilder(
    column: $table.district,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get region => $composableBuilder(
    column: $table.region,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentSiteId => $composableBuilder(
    column: $table.parentSiteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SitesTableOrderingComposer
    extends Composer<_$AppDatabase, $SitesTable> {
  $$SitesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get district => $composableBuilder(
    column: $table.district,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get region => $composableBuilder(
    column: $table.region,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentSiteId => $composableBuilder(
    column: $table.parentSiteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SitesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SitesTable> {
  $$SitesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get district =>
      $composableBuilder(column: $table.district, builder: (column) => column);

  GeneratedColumn<String> get region =>
      $composableBuilder(column: $table.region, builder: (column) => column);

  GeneratedColumn<String> get parentSiteId => $composableBuilder(
    column: $table.parentSiteId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$SitesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SitesTable,
          SiteRow,
          $$SitesTableFilterComposer,
          $$SitesTableOrderingComposer,
          $$SitesTableAnnotationComposer,
          $$SitesTableCreateCompanionBuilder,
          $$SitesTableUpdateCompanionBuilder,
          (SiteRow, BaseReferences<_$AppDatabase, $SitesTable, SiteRow>),
          SiteRow,
          PrefetchHooks Function()
        > {
  $$SitesTableTableManager(_$AppDatabase db, $SitesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$SitesTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$SitesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$SitesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> code = const Value.absent(),
                Value<String?> district = const Value.absent(),
                Value<String?> region = const Value.absent(),
                Value<String?> parentSiteId = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SitesCompanion(
                id: id,
                name: name,
                kind: kind,
                code: code,
                district: district,
                region: region,
                parentSiteId: parentSiteId,
                isActive: isActive,
                version: version,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String kind,
                Value<String?> code = const Value.absent(),
                Value<String?> district = const Value.absent(),
                Value<String?> region = const Value.absent(),
                Value<String?> parentSiteId = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SitesCompanion.insert(
                id: id,
                name: name,
                kind: kind,
                code: code,
                district: district,
                region: region,
                parentSiteId: parentSiteId,
                isActive: isActive,
                version: version,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SitesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SitesTable,
      SiteRow,
      $$SitesTableFilterComposer,
      $$SitesTableOrderingComposer,
      $$SitesTableAnnotationComposer,
      $$SitesTableCreateCompanionBuilder,
      $$SitesTableUpdateCompanionBuilder,
      (SiteRow, BaseReferences<_$AppDatabase, $SitesTable, SiteRow>),
      SiteRow,
      PrefetchHooks Function()
    >;
typedef $$ReferenceCacheTableCreateCompanionBuilder =
    ReferenceCacheCompanion Function({
      required String key,
      required String json,
      required DateTime fetchedAt,
      Value<int> rowid,
    });
typedef $$ReferenceCacheTableUpdateCompanionBuilder =
    ReferenceCacheCompanion Function({
      Value<String> key,
      Value<String> json,
      Value<DateTime> fetchedAt,
      Value<int> rowid,
    });

class $$ReferenceCacheTableFilterComposer
    extends Composer<_$AppDatabase, $ReferenceCacheTable> {
  $$ReferenceCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReferenceCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $ReferenceCacheTable> {
  $$ReferenceCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReferenceCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReferenceCacheTable> {
  $$ReferenceCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$ReferenceCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReferenceCacheTable,
          ReferenceCacheRow,
          $$ReferenceCacheTableFilterComposer,
          $$ReferenceCacheTableOrderingComposer,
          $$ReferenceCacheTableAnnotationComposer,
          $$ReferenceCacheTableCreateCompanionBuilder,
          $$ReferenceCacheTableUpdateCompanionBuilder,
          (
            ReferenceCacheRow,
            BaseReferences<
              _$AppDatabase,
              $ReferenceCacheTable,
              ReferenceCacheRow
            >,
          ),
          ReferenceCacheRow,
          PrefetchHooks Function()
        > {
  $$ReferenceCacheTableTableManager(
    _$AppDatabase db,
    $ReferenceCacheTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$ReferenceCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () =>
                  $$ReferenceCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$ReferenceCacheTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReferenceCacheCompanion(
                key: key,
                json: json,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String json,
                required DateTime fetchedAt,
                Value<int> rowid = const Value.absent(),
              }) => ReferenceCacheCompanion.insert(
                key: key,
                json: json,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReferenceCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReferenceCacheTable,
      ReferenceCacheRow,
      $$ReferenceCacheTableFilterComposer,
      $$ReferenceCacheTableOrderingComposer,
      $$ReferenceCacheTableAnnotationComposer,
      $$ReferenceCacheTableCreateCompanionBuilder,
      $$ReferenceCacheTableUpdateCompanionBuilder,
      (
        ReferenceCacheRow,
        BaseReferences<_$AppDatabase, $ReferenceCacheTable, ReferenceCacheRow>,
      ),
      ReferenceCacheRow,
      PrefetchHooks Function()
    >;
typedef $$OutboxTableCreateCompanionBuilder =
    OutboxCompanion Function({
      required String changeId,
      required String entity,
      required String op,
      required String entityId,
      Value<int?> baseVersion,
      required String data,
      Value<String> status,
      Value<int> attempts,
      Value<String?> lastError,
      required int seq,
      required DateTime createdAt,
      Value<DateTime?> nextAttemptAt,
      Value<int> rowid,
    });
typedef $$OutboxTableUpdateCompanionBuilder =
    OutboxCompanion Function({
      Value<String> changeId,
      Value<String> entity,
      Value<String> op,
      Value<String> entityId,
      Value<int?> baseVersion,
      Value<String> data,
      Value<String> status,
      Value<int> attempts,
      Value<String?> lastError,
      Value<int> seq,
      Value<DateTime> createdAt,
      Value<DateTime?> nextAttemptAt,
      Value<int> rowid,
    });

class $$OutboxTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get changeId => $composableBuilder(
    column: $table.changeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get changeId => $composableBuilder(
    column: $table.changeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get changeId =>
      $composableBuilder(column: $table.changeId, builder: (column) => column);

  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<String> get op =>
      $composableBuilder(column: $table.op, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => column,
  );
}

class $$OutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxTable,
          OutboxRow,
          $$OutboxTableFilterComposer,
          $$OutboxTableOrderingComposer,
          $$OutboxTableAnnotationComposer,
          $$OutboxTableCreateCompanionBuilder,
          $$OutboxTableUpdateCompanionBuilder,
          (OutboxRow, BaseReferences<_$AppDatabase, $OutboxTable, OutboxRow>),
          OutboxRow,
          PrefetchHooks Function()
        > {
  $$OutboxTableTableManager(_$AppDatabase db, $OutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> changeId = const Value.absent(),
                Value<String> entity = const Value.absent(),
                Value<String> op = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<int?> baseVersion = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxCompanion(
                changeId: changeId,
                entity: entity,
                op: op,
                entityId: entityId,
                baseVersion: baseVersion,
                data: data,
                status: status,
                attempts: attempts,
                lastError: lastError,
                seq: seq,
                createdAt: createdAt,
                nextAttemptAt: nextAttemptAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String changeId,
                required String entity,
                required String op,
                required String entityId,
                Value<int?> baseVersion = const Value.absent(),
                required String data,
                Value<String> status = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                required int seq,
                required DateTime createdAt,
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxCompanion.insert(
                changeId: changeId,
                entity: entity,
                op: op,
                entityId: entityId,
                baseVersion: baseVersion,
                data: data,
                status: status,
                attempts: attempts,
                lastError: lastError,
                seq: seq,
                createdAt: createdAt,
                nextAttemptAt: nextAttemptAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxTable,
      OutboxRow,
      $$OutboxTableFilterComposer,
      $$OutboxTableOrderingComposer,
      $$OutboxTableAnnotationComposer,
      $$OutboxTableCreateCompanionBuilder,
      $$OutboxTableUpdateCompanionBuilder,
      (OutboxRow, BaseReferences<_$AppDatabase, $OutboxTable, OutboxRow>),
      OutboxRow,
      PrefetchHooks Function()
    >;
typedef $$SyncConflictsTableCreateCompanionBuilder =
    SyncConflictsCompanion Function({
      Value<int> id,
      required String changeId,
      required String entity,
      required String entityId,
      required String op,
      Value<int?> baseVersion,
      required String localData,
      Value<int?> serverVersion,
      Value<String?> serverData,
      required DateTime detectedAt,
      Value<DateTime?> resolvedAt,
      Value<String?> resolution,
    });
typedef $$SyncConflictsTableUpdateCompanionBuilder =
    SyncConflictsCompanion Function({
      Value<int> id,
      Value<String> changeId,
      Value<String> entity,
      Value<String> entityId,
      Value<String> op,
      Value<int?> baseVersion,
      Value<String> localData,
      Value<int?> serverVersion,
      Value<String?> serverData,
      Value<DateTime> detectedAt,
      Value<DateTime?> resolvedAt,
      Value<String?> resolution,
    });

class $$SyncConflictsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncConflictsTable> {
  $$SyncConflictsTableFilterComposer({
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

  ColumnFilters<String> get changeId => $composableBuilder(
    column: $table.changeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localData => $composableBuilder(
    column: $table.localData,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverData => $composableBuilder(
    column: $table.serverData,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get detectedAt => $composableBuilder(
    column: $table.detectedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resolution => $composableBuilder(
    column: $table.resolution,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncConflictsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncConflictsTable> {
  $$SyncConflictsTableOrderingComposer({
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

  ColumnOrderings<String> get changeId => $composableBuilder(
    column: $table.changeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localData => $composableBuilder(
    column: $table.localData,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverData => $composableBuilder(
    column: $table.serverData,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get detectedAt => $composableBuilder(
    column: $table.detectedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resolution => $composableBuilder(
    column: $table.resolution,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncConflictsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncConflictsTable> {
  $$SyncConflictsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get changeId =>
      $composableBuilder(column: $table.changeId, builder: (column) => column);

  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get op =>
      $composableBuilder(column: $table.op, builder: (column) => column);

  GeneratedColumn<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localData =>
      $composableBuilder(column: $table.localData, builder: (column) => column);

  GeneratedColumn<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serverData => $composableBuilder(
    column: $table.serverData,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get detectedAt => $composableBuilder(
    column: $table.detectedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resolution => $composableBuilder(
    column: $table.resolution,
    builder: (column) => column,
  );
}

class $$SyncConflictsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncConflictsTable,
          SyncConflictRow,
          $$SyncConflictsTableFilterComposer,
          $$SyncConflictsTableOrderingComposer,
          $$SyncConflictsTableAnnotationComposer,
          $$SyncConflictsTableCreateCompanionBuilder,
          $$SyncConflictsTableUpdateCompanionBuilder,
          (
            SyncConflictRow,
            BaseReferences<_$AppDatabase, $SyncConflictsTable, SyncConflictRow>,
          ),
          SyncConflictRow,
          PrefetchHooks Function()
        > {
  $$SyncConflictsTableTableManager(_$AppDatabase db, $SyncConflictsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$SyncConflictsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () =>
                  $$SyncConflictsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$SyncConflictsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> changeId = const Value.absent(),
                Value<String> entity = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> op = const Value.absent(),
                Value<int?> baseVersion = const Value.absent(),
                Value<String> localData = const Value.absent(),
                Value<int?> serverVersion = const Value.absent(),
                Value<String?> serverData = const Value.absent(),
                Value<DateTime> detectedAt = const Value.absent(),
                Value<DateTime?> resolvedAt = const Value.absent(),
                Value<String?> resolution = const Value.absent(),
              }) => SyncConflictsCompanion(
                id: id,
                changeId: changeId,
                entity: entity,
                entityId: entityId,
                op: op,
                baseVersion: baseVersion,
                localData: localData,
                serverVersion: serverVersion,
                serverData: serverData,
                detectedAt: detectedAt,
                resolvedAt: resolvedAt,
                resolution: resolution,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String changeId,
                required String entity,
                required String entityId,
                required String op,
                Value<int?> baseVersion = const Value.absent(),
                required String localData,
                Value<int?> serverVersion = const Value.absent(),
                Value<String?> serverData = const Value.absent(),
                required DateTime detectedAt,
                Value<DateTime?> resolvedAt = const Value.absent(),
                Value<String?> resolution = const Value.absent(),
              }) => SyncConflictsCompanion.insert(
                id: id,
                changeId: changeId,
                entity: entity,
                entityId: entityId,
                op: op,
                baseVersion: baseVersion,
                localData: localData,
                serverVersion: serverVersion,
                serverData: serverData,
                detectedAt: detectedAt,
                resolvedAt: resolvedAt,
                resolution: resolution,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncConflictsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncConflictsTable,
      SyncConflictRow,
      $$SyncConflictsTableFilterComposer,
      $$SyncConflictsTableOrderingComposer,
      $$SyncConflictsTableAnnotationComposer,
      $$SyncConflictsTableCreateCompanionBuilder,
      $$SyncConflictsTableUpdateCompanionBuilder,
      (
        SyncConflictRow,
        BaseReferences<_$AppDatabase, $SyncConflictsTable, SyncConflictRow>,
      ),
      SyncConflictRow,
      PrefetchHooks Function()
    >;
typedef $$SyncStateTableCreateCompanionBuilder =
    SyncStateCompanion Function({
      required String key,
      Value<String?> value,
      Value<int> rowid,
    });
typedef $$SyncStateTableUpdateCompanionBuilder =
    SyncStateCompanion Function({
      Value<String> key,
      Value<String?> value,
      Value<int> rowid,
    });

class $$SyncStateTableFilterComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStateTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStateTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SyncStateTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncStateTable,
          SyncStateRow,
          $$SyncStateTableFilterComposer,
          $$SyncStateTableOrderingComposer,
          $$SyncStateTableAnnotationComposer,
          $$SyncStateTableCreateCompanionBuilder,
          $$SyncStateTableUpdateCompanionBuilder,
          (
            SyncStateRow,
            BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateRow>,
          ),
          SyncStateRow,
          PrefetchHooks Function()
        > {
  $$SyncStateTableTableManager(_$AppDatabase db, $SyncStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$SyncStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$SyncStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$SyncStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStateCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                Value<String?> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStateCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStateTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncStateTable,
      SyncStateRow,
      $$SyncStateTableFilterComposer,
      $$SyncStateTableOrderingComposer,
      $$SyncStateTableAnnotationComposer,
      $$SyncStateTableCreateCompanionBuilder,
      $$SyncStateTableUpdateCompanionBuilder,
      (
        SyncStateRow,
        BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateRow>,
      ),
      SyncStateRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$BeneficiariesTableTableManager get beneficiaries =>
      $$BeneficiariesTableTableManager(_db, _db.beneficiaries);
  $$BeneficiaryIdentitiesTableTableManager get beneficiaryIdentities =>
      $$BeneficiaryIdentitiesTableTableManager(_db, _db.beneficiaryIdentities);
  $$ConsentsTableTableManager get consents =>
      $$ConsentsTableTableManager(_db, _db.consents);
  $$PregnanciesTableTableManager get pregnancies =>
      $$PregnanciesTableTableManager(_db, _db.pregnancies);
  $$AncVisitsTableTableManager get ancVisits =>
      $$AncVisitsTableTableManager(_db, _db.ancVisits);
  $$ReferralsTableTableManager get referrals =>
      $$ReferralsTableTableManager(_db, _db.referrals);
  $$AlertsTableTableManager get alerts =>
      $$AlertsTableTableManager(_db, _db.alerts);
  $$SitesTableTableManager get sites =>
      $$SitesTableTableManager(_db, _db.sites);
  $$ReferenceCacheTableTableManager get referenceCache =>
      $$ReferenceCacheTableTableManager(_db, _db.referenceCache);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
  $$SyncConflictsTableTableManager get syncConflicts =>
      $$SyncConflictsTableTableManager(_db, _db.syncConflicts);
  $$SyncStateTableTableManager get syncState =>
      $$SyncStateTableTableManager(_db, _db.syncState);
}
