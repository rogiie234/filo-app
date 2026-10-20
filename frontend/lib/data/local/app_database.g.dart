// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CacheProfilesTable extends CacheProfiles
    with TableInfo<$CacheProfilesTable, CacheProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CacheProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
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
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _schoolMeta = const VerificationMeta('school');
  @override
  late final GeneratedColumn<String> school = GeneratedColumn<String>(
    'school',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _googlePhotoUrlMeta = const VerificationMeta(
    'googlePhotoUrl',
  );
  @override
  late final GeneratedColumn<String> googlePhotoUrl = GeneratedColumn<String>(
    'google_photo_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _avatarPathMeta = const VerificationMeta(
    'avatarPath',
  );
  @override
  late final GeneratedColumn<String> avatarPath = GeneratedColumn<String>(
    'avatar_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _privacyAcceptedAtMeta = const VerificationMeta(
    'privacyAcceptedAt',
  );
  @override
  late final GeneratedColumn<DateTime> privacyAcceptedAt =
      GeneratedColumn<DateTime>(
        'privacy_accepted_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _privacyVersionMeta = const VerificationMeta(
    'privacyVersion',
  );
  @override
  late final GeneratedColumn<String> privacyVersion = GeneratedColumn<String>(
    'privacy_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    role,
    displayName,
    email,
    school,
    googlePhotoUrl,
    avatarPath,
    privacyAcceptedAt,
    privacyVersion,
    deletedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cache_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<CacheProfile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
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
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    }
    if (data.containsKey('school')) {
      context.handle(
        _schoolMeta,
        school.isAcceptableOrUnknown(data['school']!, _schoolMeta),
      );
    }
    if (data.containsKey('google_photo_url')) {
      context.handle(
        _googlePhotoUrlMeta,
        googlePhotoUrl.isAcceptableOrUnknown(
          data['google_photo_url']!,
          _googlePhotoUrlMeta,
        ),
      );
    }
    if (data.containsKey('avatar_path')) {
      context.handle(
        _avatarPathMeta,
        avatarPath.isAcceptableOrUnknown(data['avatar_path']!, _avatarPathMeta),
      );
    }
    if (data.containsKey('privacy_accepted_at')) {
      context.handle(
        _privacyAcceptedAtMeta,
        privacyAcceptedAt.isAcceptableOrUnknown(
          data['privacy_accepted_at']!,
          _privacyAcceptedAtMeta,
        ),
      );
    }
    if (data.containsKey('privacy_version')) {
      context.handle(
        _privacyVersionMeta,
        privacyVersion.isAcceptableOrUnknown(
          data['privacy_version']!,
          _privacyVersionMeta,
        ),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CacheProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CacheProfile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      ),
      school: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}school'],
      ),
      googlePhotoUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}google_photo_url'],
      ),
      avatarPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar_path'],
      ),
      privacyAcceptedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}privacy_accepted_at'],
      ),
      privacyVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}privacy_version'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CacheProfilesTable createAlias(String alias) {
    return $CacheProfilesTable(attachedDatabase, alias);
  }
}

class CacheProfile extends DataClass implements Insertable<CacheProfile> {
  final String id;
  final String role;
  final String displayName;
  final String? email;
  final String? school;
  final String? googlePhotoUrl;
  final String? avatarPath;
  final DateTime? privacyAcceptedAt;
  final String? privacyVersion;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const CacheProfile({
    required this.id,
    required this.role,
    required this.displayName,
    this.email,
    this.school,
    this.googlePhotoUrl,
    this.avatarPath,
    this.privacyAcceptedAt,
    this.privacyVersion,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['role'] = Variable<String>(role);
    map['display_name'] = Variable<String>(displayName);
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || school != null) {
      map['school'] = Variable<String>(school);
    }
    if (!nullToAbsent || googlePhotoUrl != null) {
      map['google_photo_url'] = Variable<String>(googlePhotoUrl);
    }
    if (!nullToAbsent || avatarPath != null) {
      map['avatar_path'] = Variable<String>(avatarPath);
    }
    if (!nullToAbsent || privacyAcceptedAt != null) {
      map['privacy_accepted_at'] = Variable<DateTime>(privacyAcceptedAt);
    }
    if (!nullToAbsent || privacyVersion != null) {
      map['privacy_version'] = Variable<String>(privacyVersion);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CacheProfilesCompanion toCompanion(bool nullToAbsent) {
    return CacheProfilesCompanion(
      id: Value(id),
      role: Value(role),
      displayName: Value(displayName),
      email: email == null && nullToAbsent
          ? const Value.absent()
          : Value(email),
      school: school == null && nullToAbsent
          ? const Value.absent()
          : Value(school),
      googlePhotoUrl: googlePhotoUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(googlePhotoUrl),
      avatarPath: avatarPath == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarPath),
      privacyAcceptedAt: privacyAcceptedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(privacyAcceptedAt),
      privacyVersion: privacyVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(privacyVersion),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory CacheProfile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CacheProfile(
      id: serializer.fromJson<String>(json['id']),
      role: serializer.fromJson<String>(json['role']),
      displayName: serializer.fromJson<String>(json['displayName']),
      email: serializer.fromJson<String?>(json['email']),
      school: serializer.fromJson<String?>(json['school']),
      googlePhotoUrl: serializer.fromJson<String?>(json['googlePhotoUrl']),
      avatarPath: serializer.fromJson<String?>(json['avatarPath']),
      privacyAcceptedAt: serializer.fromJson<DateTime?>(
        json['privacyAcceptedAt'],
      ),
      privacyVersion: serializer.fromJson<String?>(json['privacyVersion']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'role': serializer.toJson<String>(role),
      'displayName': serializer.toJson<String>(displayName),
      'email': serializer.toJson<String?>(email),
      'school': serializer.toJson<String?>(school),
      'googlePhotoUrl': serializer.toJson<String?>(googlePhotoUrl),
      'avatarPath': serializer.toJson<String?>(avatarPath),
      'privacyAcceptedAt': serializer.toJson<DateTime?>(privacyAcceptedAt),
      'privacyVersion': serializer.toJson<String?>(privacyVersion),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CacheProfile copyWith({
    String? id,
    String? role,
    String? displayName,
    Value<String?> email = const Value.absent(),
    Value<String?> school = const Value.absent(),
    Value<String?> googlePhotoUrl = const Value.absent(),
    Value<String?> avatarPath = const Value.absent(),
    Value<DateTime?> privacyAcceptedAt = const Value.absent(),
    Value<String?> privacyVersion = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CacheProfile(
    id: id ?? this.id,
    role: role ?? this.role,
    displayName: displayName ?? this.displayName,
    email: email.present ? email.value : this.email,
    school: school.present ? school.value : this.school,
    googlePhotoUrl: googlePhotoUrl.present
        ? googlePhotoUrl.value
        : this.googlePhotoUrl,
    avatarPath: avatarPath.present ? avatarPath.value : this.avatarPath,
    privacyAcceptedAt: privacyAcceptedAt.present
        ? privacyAcceptedAt.value
        : this.privacyAcceptedAt,
    privacyVersion: privacyVersion.present
        ? privacyVersion.value
        : this.privacyVersion,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CacheProfile copyWithCompanion(CacheProfilesCompanion data) {
    return CacheProfile(
      id: data.id.present ? data.id.value : this.id,
      role: data.role.present ? data.role.value : this.role,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      email: data.email.present ? data.email.value : this.email,
      school: data.school.present ? data.school.value : this.school,
      googlePhotoUrl: data.googlePhotoUrl.present
          ? data.googlePhotoUrl.value
          : this.googlePhotoUrl,
      avatarPath: data.avatarPath.present
          ? data.avatarPath.value
          : this.avatarPath,
      privacyAcceptedAt: data.privacyAcceptedAt.present
          ? data.privacyAcceptedAt.value
          : this.privacyAcceptedAt,
      privacyVersion: data.privacyVersion.present
          ? data.privacyVersion.value
          : this.privacyVersion,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CacheProfile(')
          ..write('id: $id, ')
          ..write('role: $role, ')
          ..write('displayName: $displayName, ')
          ..write('email: $email, ')
          ..write('school: $school, ')
          ..write('googlePhotoUrl: $googlePhotoUrl, ')
          ..write('avatarPath: $avatarPath, ')
          ..write('privacyAcceptedAt: $privacyAcceptedAt, ')
          ..write('privacyVersion: $privacyVersion, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    role,
    displayName,
    email,
    school,
    googlePhotoUrl,
    avatarPath,
    privacyAcceptedAt,
    privacyVersion,
    deletedAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CacheProfile &&
          other.id == this.id &&
          other.role == this.role &&
          other.displayName == this.displayName &&
          other.email == this.email &&
          other.school == this.school &&
          other.googlePhotoUrl == this.googlePhotoUrl &&
          other.avatarPath == this.avatarPath &&
          other.privacyAcceptedAt == this.privacyAcceptedAt &&
          other.privacyVersion == this.privacyVersion &&
          other.deletedAt == this.deletedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CacheProfilesCompanion extends UpdateCompanion<CacheProfile> {
  final Value<String> id;
  final Value<String> role;
  final Value<String> displayName;
  final Value<String?> email;
  final Value<String?> school;
  final Value<String?> googlePhotoUrl;
  final Value<String?> avatarPath;
  final Value<DateTime?> privacyAcceptedAt;
  final Value<String?> privacyVersion;
  final Value<DateTime?> deletedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CacheProfilesCompanion({
    this.id = const Value.absent(),
    this.role = const Value.absent(),
    this.displayName = const Value.absent(),
    this.email = const Value.absent(),
    this.school = const Value.absent(),
    this.googlePhotoUrl = const Value.absent(),
    this.avatarPath = const Value.absent(),
    this.privacyAcceptedAt = const Value.absent(),
    this.privacyVersion = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CacheProfilesCompanion.insert({
    required String id,
    required String role,
    required String displayName,
    this.email = const Value.absent(),
    this.school = const Value.absent(),
    this.googlePhotoUrl = const Value.absent(),
    this.avatarPath = const Value.absent(),
    this.privacyAcceptedAt = const Value.absent(),
    this.privacyVersion = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       role = Value(role),
       displayName = Value(displayName);
  static Insertable<CacheProfile> custom({
    Expression<String>? id,
    Expression<String>? role,
    Expression<String>? displayName,
    Expression<String>? email,
    Expression<String>? school,
    Expression<String>? googlePhotoUrl,
    Expression<String>? avatarPath,
    Expression<DateTime>? privacyAcceptedAt,
    Expression<String>? privacyVersion,
    Expression<DateTime>? deletedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (role != null) 'role': role,
      if (displayName != null) 'display_name': displayName,
      if (email != null) 'email': email,
      if (school != null) 'school': school,
      if (googlePhotoUrl != null) 'google_photo_url': googlePhotoUrl,
      if (avatarPath != null) 'avatar_path': avatarPath,
      if (privacyAcceptedAt != null) 'privacy_accepted_at': privacyAcceptedAt,
      if (privacyVersion != null) 'privacy_version': privacyVersion,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CacheProfilesCompanion copyWith({
    Value<String>? id,
    Value<String>? role,
    Value<String>? displayName,
    Value<String?>? email,
    Value<String?>? school,
    Value<String?>? googlePhotoUrl,
    Value<String?>? avatarPath,
    Value<DateTime?>? privacyAcceptedAt,
    Value<String?>? privacyVersion,
    Value<DateTime?>? deletedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CacheProfilesCompanion(
      id: id ?? this.id,
      role: role ?? this.role,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      school: school ?? this.school,
      googlePhotoUrl: googlePhotoUrl ?? this.googlePhotoUrl,
      avatarPath: avatarPath ?? this.avatarPath,
      privacyAcceptedAt: privacyAcceptedAt ?? this.privacyAcceptedAt,
      privacyVersion: privacyVersion ?? this.privacyVersion,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (school.present) {
      map['school'] = Variable<String>(school.value);
    }
    if (googlePhotoUrl.present) {
      map['google_photo_url'] = Variable<String>(googlePhotoUrl.value);
    }
    if (avatarPath.present) {
      map['avatar_path'] = Variable<String>(avatarPath.value);
    }
    if (privacyAcceptedAt.present) {
      map['privacy_accepted_at'] = Variable<DateTime>(privacyAcceptedAt.value);
    }
    if (privacyVersion.present) {
      map['privacy_version'] = Variable<String>(privacyVersion.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CacheProfilesCompanion(')
          ..write('id: $id, ')
          ..write('role: $role, ')
          ..write('displayName: $displayName, ')
          ..write('email: $email, ')
          ..write('school: $school, ')
          ..write('googlePhotoUrl: $googlePhotoUrl, ')
          ..write('avatarPath: $avatarPath, ')
          ..write('privacyAcceptedAt: $privacyAcceptedAt, ')
          ..write('privacyVersion: $privacyVersion, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CacheClassesTable extends CacheClasses
    with TableInfo<$CacheClassesTable, CacheClassesData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CacheClassesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cache_profiles (id)',
    ),
  );
  static const VerificationMeta _courseMeta = const VerificationMeta('course');
  @override
  late final GeneratedColumn<String> course = GeneratedColumn<String>(
    'course',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sectionMeta = const VerificationMeta(
    'section',
  );
  @override
  late final GeneratedColumn<String> section = GeneratedColumn<String>(
    'section',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _schoolYearMeta = const VerificationMeta(
    'schoolYear',
  );
  @override
  late final GeneratedColumn<String> schoolYear = GeneratedColumn<String>(
    'school_year',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _joinCodeMeta = const VerificationMeta(
    'joinCode',
  );
  @override
  late final GeneratedColumn<String> joinCode = GeneratedColumn<String>(
    'join_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _bannerColorMeta = const VerificationMeta(
    'bannerColor',
  );
  @override
  late final GeneratedColumn<String> bannerColor = GeneratedColumn<String>(
    'banner_color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bannerPathMeta = const VerificationMeta(
    'bannerPath',
  );
  @override
  late final GeneratedColumn<String> bannerPath = GeneratedColumn<String>(
    'banner_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
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
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerId,
    course,
    section,
    schoolYear,
    joinCode,
    bannerColor,
    bannerPath,
    archivedAt,
    deletedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cache_classes';
  @override
  VerificationContext validateIntegrity(
    Insertable<CacheClassesData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('course')) {
      context.handle(
        _courseMeta,
        course.isAcceptableOrUnknown(data['course']!, _courseMeta),
      );
    } else if (isInserting) {
      context.missing(_courseMeta);
    }
    if (data.containsKey('section')) {
      context.handle(
        _sectionMeta,
        section.isAcceptableOrUnknown(data['section']!, _sectionMeta),
      );
    } else if (isInserting) {
      context.missing(_sectionMeta);
    }
    if (data.containsKey('school_year')) {
      context.handle(
        _schoolYearMeta,
        schoolYear.isAcceptableOrUnknown(data['school_year']!, _schoolYearMeta),
      );
    } else if (isInserting) {
      context.missing(_schoolYearMeta);
    }
    if (data.containsKey('join_code')) {
      context.handle(
        _joinCodeMeta,
        joinCode.isAcceptableOrUnknown(data['join_code']!, _joinCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_joinCodeMeta);
    }
    if (data.containsKey('banner_color')) {
      context.handle(
        _bannerColorMeta,
        bannerColor.isAcceptableOrUnknown(
          data['banner_color']!,
          _bannerColorMeta,
        ),
      );
    }
    if (data.containsKey('banner_path')) {
      context.handle(
        _bannerPathMeta,
        bannerPath.isAcceptableOrUnknown(data['banner_path']!, _bannerPathMeta),
      );
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CacheClassesData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CacheClassesData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      course: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course'],
      )!,
      section: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}section'],
      )!,
      schoolYear: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}school_year'],
      )!,
      joinCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}join_code'],
      )!,
      bannerColor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}banner_color'],
      ),
      bannerPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}banner_path'],
      ),
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CacheClassesTable createAlias(String alias) {
    return $CacheClassesTable(attachedDatabase, alias);
  }
}

class CacheClassesData extends DataClass
    implements Insertable<CacheClassesData> {
  final String id;
  final String ownerId;
  final String course;
  final String section;
  final String schoolYear;
  final String joinCode;
  final String? bannerColor;
  final String? bannerPath;
  final DateTime? archivedAt;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const CacheClassesData({
    required this.id,
    required this.ownerId,
    required this.course,
    required this.section,
    required this.schoolYear,
    required this.joinCode,
    this.bannerColor,
    this.bannerPath,
    this.archivedAt,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['owner_id'] = Variable<String>(ownerId);
    map['course'] = Variable<String>(course);
    map['section'] = Variable<String>(section);
    map['school_year'] = Variable<String>(schoolYear);
    map['join_code'] = Variable<String>(joinCode);
    if (!nullToAbsent || bannerColor != null) {
      map['banner_color'] = Variable<String>(bannerColor);
    }
    if (!nullToAbsent || bannerPath != null) {
      map['banner_path'] = Variable<String>(bannerPath);
    }
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CacheClassesCompanion toCompanion(bool nullToAbsent) {
    return CacheClassesCompanion(
      id: Value(id),
      ownerId: Value(ownerId),
      course: Value(course),
      section: Value(section),
      schoolYear: Value(schoolYear),
      joinCode: Value(joinCode),
      bannerColor: bannerColor == null && nullToAbsent
          ? const Value.absent()
          : Value(bannerColor),
      bannerPath: bannerPath == null && nullToAbsent
          ? const Value.absent()
          : Value(bannerPath),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory CacheClassesData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CacheClassesData(
      id: serializer.fromJson<String>(json['id']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      course: serializer.fromJson<String>(json['course']),
      section: serializer.fromJson<String>(json['section']),
      schoolYear: serializer.fromJson<String>(json['schoolYear']),
      joinCode: serializer.fromJson<String>(json['joinCode']),
      bannerColor: serializer.fromJson<String?>(json['bannerColor']),
      bannerPath: serializer.fromJson<String?>(json['bannerPath']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerId': serializer.toJson<String>(ownerId),
      'course': serializer.toJson<String>(course),
      'section': serializer.toJson<String>(section),
      'schoolYear': serializer.toJson<String>(schoolYear),
      'joinCode': serializer.toJson<String>(joinCode),
      'bannerColor': serializer.toJson<String?>(bannerColor),
      'bannerPath': serializer.toJson<String?>(bannerPath),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CacheClassesData copyWith({
    String? id,
    String? ownerId,
    String? course,
    String? section,
    String? schoolYear,
    String? joinCode,
    Value<String?> bannerColor = const Value.absent(),
    Value<String?> bannerPath = const Value.absent(),
    Value<DateTime?> archivedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CacheClassesData(
    id: id ?? this.id,
    ownerId: ownerId ?? this.ownerId,
    course: course ?? this.course,
    section: section ?? this.section,
    schoolYear: schoolYear ?? this.schoolYear,
    joinCode: joinCode ?? this.joinCode,
    bannerColor: bannerColor.present ? bannerColor.value : this.bannerColor,
    bannerPath: bannerPath.present ? bannerPath.value : this.bannerPath,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CacheClassesData copyWithCompanion(CacheClassesCompanion data) {
    return CacheClassesData(
      id: data.id.present ? data.id.value : this.id,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      course: data.course.present ? data.course.value : this.course,
      section: data.section.present ? data.section.value : this.section,
      schoolYear: data.schoolYear.present
          ? data.schoolYear.value
          : this.schoolYear,
      joinCode: data.joinCode.present ? data.joinCode.value : this.joinCode,
      bannerColor: data.bannerColor.present
          ? data.bannerColor.value
          : this.bannerColor,
      bannerPath: data.bannerPath.present
          ? data.bannerPath.value
          : this.bannerPath,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CacheClassesData(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('course: $course, ')
          ..write('section: $section, ')
          ..write('schoolYear: $schoolYear, ')
          ..write('joinCode: $joinCode, ')
          ..write('bannerColor: $bannerColor, ')
          ..write('bannerPath: $bannerPath, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerId,
    course,
    section,
    schoolYear,
    joinCode,
    bannerColor,
    bannerPath,
    archivedAt,
    deletedAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CacheClassesData &&
          other.id == this.id &&
          other.ownerId == this.ownerId &&
          other.course == this.course &&
          other.section == this.section &&
          other.schoolYear == this.schoolYear &&
          other.joinCode == this.joinCode &&
          other.bannerColor == this.bannerColor &&
          other.bannerPath == this.bannerPath &&
          other.archivedAt == this.archivedAt &&
          other.deletedAt == this.deletedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CacheClassesCompanion extends UpdateCompanion<CacheClassesData> {
  final Value<String> id;
  final Value<String> ownerId;
  final Value<String> course;
  final Value<String> section;
  final Value<String> schoolYear;
  final Value<String> joinCode;
  final Value<String?> bannerColor;
  final Value<String?> bannerPath;
  final Value<DateTime?> archivedAt;
  final Value<DateTime?> deletedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CacheClassesCompanion({
    this.id = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.course = const Value.absent(),
    this.section = const Value.absent(),
    this.schoolYear = const Value.absent(),
    this.joinCode = const Value.absent(),
    this.bannerColor = const Value.absent(),
    this.bannerPath = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CacheClassesCompanion.insert({
    required String id,
    required String ownerId,
    required String course,
    required String section,
    required String schoolYear,
    required String joinCode,
    this.bannerColor = const Value.absent(),
    this.bannerPath = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       ownerId = Value(ownerId),
       course = Value(course),
       section = Value(section),
       schoolYear = Value(schoolYear),
       joinCode = Value(joinCode);
  static Insertable<CacheClassesData> custom({
    Expression<String>? id,
    Expression<String>? ownerId,
    Expression<String>? course,
    Expression<String>? section,
    Expression<String>? schoolYear,
    Expression<String>? joinCode,
    Expression<String>? bannerColor,
    Expression<String>? bannerPath,
    Expression<DateTime>? archivedAt,
    Expression<DateTime>? deletedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerId != null) 'owner_id': ownerId,
      if (course != null) 'course': course,
      if (section != null) 'section': section,
      if (schoolYear != null) 'school_year': schoolYear,
      if (joinCode != null) 'join_code': joinCode,
      if (bannerColor != null) 'banner_color': bannerColor,
      if (bannerPath != null) 'banner_path': bannerPath,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CacheClassesCompanion copyWith({
    Value<String>? id,
    Value<String>? ownerId,
    Value<String>? course,
    Value<String>? section,
    Value<String>? schoolYear,
    Value<String>? joinCode,
    Value<String?>? bannerColor,
    Value<String?>? bannerPath,
    Value<DateTime?>? archivedAt,
    Value<DateTime?>? deletedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CacheClassesCompanion(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      course: course ?? this.course,
      section: section ?? this.section,
      schoolYear: schoolYear ?? this.schoolYear,
      joinCode: joinCode ?? this.joinCode,
      bannerColor: bannerColor ?? this.bannerColor,
      bannerPath: bannerPath ?? this.bannerPath,
      archivedAt: archivedAt ?? this.archivedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (course.present) {
      map['course'] = Variable<String>(course.value);
    }
    if (section.present) {
      map['section'] = Variable<String>(section.value);
    }
    if (schoolYear.present) {
      map['school_year'] = Variable<String>(schoolYear.value);
    }
    if (joinCode.present) {
      map['join_code'] = Variable<String>(joinCode.value);
    }
    if (bannerColor.present) {
      map['banner_color'] = Variable<String>(bannerColor.value);
    }
    if (bannerPath.present) {
      map['banner_path'] = Variable<String>(bannerPath.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CacheClassesCompanion(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('course: $course, ')
          ..write('section: $section, ')
          ..write('schoolYear: $schoolYear, ')
          ..write('joinCode: $joinCode, ')
          ..write('bannerColor: $bannerColor, ')
          ..write('bannerPath: $bannerPath, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CacheClassMembersTable extends CacheClassMembers
    with TableInfo<$CacheClassMembersTable, CacheClassMember> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CacheClassMembersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _classIdMeta = const VerificationMeta(
    'classId',
  );
  @override
  late final GeneratedColumn<String> classId = GeneratedColumn<String>(
    'class_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cache_classes (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _studentIdMeta = const VerificationMeta(
    'studentId',
  );
  @override
  late final GeneratedColumn<String> studentId = GeneratedColumn<String>(
    'student_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cache_profiles (id)',
    ),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("pending"),
  );
  static const VerificationMeta _requestedAtMeta = const VerificationMeta(
    'requestedAt',
  );
  @override
  late final GeneratedColumn<DateTime> requestedAt = GeneratedColumn<DateTime>(
    'requested_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _decidedAtMeta = const VerificationMeta(
    'decidedAt',
  );
  @override
  late final GeneratedColumn<DateTime> decidedAt = GeneratedColumn<DateTime>(
    'decided_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _decidedByMeta = const VerificationMeta(
    'decidedBy',
  );
  @override
  late final GeneratedColumn<String> decidedBy = GeneratedColumn<String>(
    'decided_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cache_profiles (id)',
    ),
  );
  static const VerificationMeta _leftAtMeta = const VerificationMeta('leftAt');
  @override
  late final GeneratedColumn<DateTime> leftAt = GeneratedColumn<DateTime>(
    'left_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    classId,
    studentId,
    status,
    requestedAt,
    decidedAt,
    decidedBy,
    leftAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cache_class_members';
  @override
  VerificationContext validateIntegrity(
    Insertable<CacheClassMember> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('class_id')) {
      context.handle(
        _classIdMeta,
        classId.isAcceptableOrUnknown(data['class_id']!, _classIdMeta),
      );
    } else if (isInserting) {
      context.missing(_classIdMeta);
    }
    if (data.containsKey('student_id')) {
      context.handle(
        _studentIdMeta,
        studentId.isAcceptableOrUnknown(data['student_id']!, _studentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_studentIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('requested_at')) {
      context.handle(
        _requestedAtMeta,
        requestedAt.isAcceptableOrUnknown(
          data['requested_at']!,
          _requestedAtMeta,
        ),
      );
    }
    if (data.containsKey('decided_at')) {
      context.handle(
        _decidedAtMeta,
        decidedAt.isAcceptableOrUnknown(data['decided_at']!, _decidedAtMeta),
      );
    }
    if (data.containsKey('decided_by')) {
      context.handle(
        _decidedByMeta,
        decidedBy.isAcceptableOrUnknown(data['decided_by']!, _decidedByMeta),
      );
    }
    if (data.containsKey('left_at')) {
      context.handle(
        _leftAtMeta,
        leftAt.isAcceptableOrUnknown(data['left_at']!, _leftAtMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CacheClassMember map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CacheClassMember(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      classId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}class_id'],
      )!,
      studentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}student_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      requestedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}requested_at'],
      )!,
      decidedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}decided_at'],
      ),
      decidedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}decided_by'],
      ),
      leftAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}left_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CacheClassMembersTable createAlias(String alias) {
    return $CacheClassMembersTable(attachedDatabase, alias);
  }
}

class CacheClassMember extends DataClass
    implements Insertable<CacheClassMember> {
  final String id;
  final String classId;
  final String studentId;
  final String status;
  final DateTime requestedAt;
  final DateTime? decidedAt;
  final String? decidedBy;
  final DateTime? leftAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const CacheClassMember({
    required this.id,
    required this.classId,
    required this.studentId,
    required this.status,
    required this.requestedAt,
    this.decidedAt,
    this.decidedBy,
    this.leftAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['class_id'] = Variable<String>(classId);
    map['student_id'] = Variable<String>(studentId);
    map['status'] = Variable<String>(status);
    map['requested_at'] = Variable<DateTime>(requestedAt);
    if (!nullToAbsent || decidedAt != null) {
      map['decided_at'] = Variable<DateTime>(decidedAt);
    }
    if (!nullToAbsent || decidedBy != null) {
      map['decided_by'] = Variable<String>(decidedBy);
    }
    if (!nullToAbsent || leftAt != null) {
      map['left_at'] = Variable<DateTime>(leftAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CacheClassMembersCompanion toCompanion(bool nullToAbsent) {
    return CacheClassMembersCompanion(
      id: Value(id),
      classId: Value(classId),
      studentId: Value(studentId),
      status: Value(status),
      requestedAt: Value(requestedAt),
      decidedAt: decidedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(decidedAt),
      decidedBy: decidedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(decidedBy),
      leftAt: leftAt == null && nullToAbsent
          ? const Value.absent()
          : Value(leftAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory CacheClassMember.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CacheClassMember(
      id: serializer.fromJson<String>(json['id']),
      classId: serializer.fromJson<String>(json['classId']),
      studentId: serializer.fromJson<String>(json['studentId']),
      status: serializer.fromJson<String>(json['status']),
      requestedAt: serializer.fromJson<DateTime>(json['requestedAt']),
      decidedAt: serializer.fromJson<DateTime?>(json['decidedAt']),
      decidedBy: serializer.fromJson<String?>(json['decidedBy']),
      leftAt: serializer.fromJson<DateTime?>(json['leftAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'classId': serializer.toJson<String>(classId),
      'studentId': serializer.toJson<String>(studentId),
      'status': serializer.toJson<String>(status),
      'requestedAt': serializer.toJson<DateTime>(requestedAt),
      'decidedAt': serializer.toJson<DateTime?>(decidedAt),
      'decidedBy': serializer.toJson<String?>(decidedBy),
      'leftAt': serializer.toJson<DateTime?>(leftAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CacheClassMember copyWith({
    String? id,
    String? classId,
    String? studentId,
    String? status,
    DateTime? requestedAt,
    Value<DateTime?> decidedAt = const Value.absent(),
    Value<String?> decidedBy = const Value.absent(),
    Value<DateTime?> leftAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CacheClassMember(
    id: id ?? this.id,
    classId: classId ?? this.classId,
    studentId: studentId ?? this.studentId,
    status: status ?? this.status,
    requestedAt: requestedAt ?? this.requestedAt,
    decidedAt: decidedAt.present ? decidedAt.value : this.decidedAt,
    decidedBy: decidedBy.present ? decidedBy.value : this.decidedBy,
    leftAt: leftAt.present ? leftAt.value : this.leftAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CacheClassMember copyWithCompanion(CacheClassMembersCompanion data) {
    return CacheClassMember(
      id: data.id.present ? data.id.value : this.id,
      classId: data.classId.present ? data.classId.value : this.classId,
      studentId: data.studentId.present ? data.studentId.value : this.studentId,
      status: data.status.present ? data.status.value : this.status,
      requestedAt: data.requestedAt.present
          ? data.requestedAt.value
          : this.requestedAt,
      decidedAt: data.decidedAt.present ? data.decidedAt.value : this.decidedAt,
      decidedBy: data.decidedBy.present ? data.decidedBy.value : this.decidedBy,
      leftAt: data.leftAt.present ? data.leftAt.value : this.leftAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CacheClassMember(')
          ..write('id: $id, ')
          ..write('classId: $classId, ')
          ..write('studentId: $studentId, ')
          ..write('status: $status, ')
          ..write('requestedAt: $requestedAt, ')
          ..write('decidedAt: $decidedAt, ')
          ..write('decidedBy: $decidedBy, ')
          ..write('leftAt: $leftAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    classId,
    studentId,
    status,
    requestedAt,
    decidedAt,
    decidedBy,
    leftAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CacheClassMember &&
          other.id == this.id &&
          other.classId == this.classId &&
          other.studentId == this.studentId &&
          other.status == this.status &&
          other.requestedAt == this.requestedAt &&
          other.decidedAt == this.decidedAt &&
          other.decidedBy == this.decidedBy &&
          other.leftAt == this.leftAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CacheClassMembersCompanion extends UpdateCompanion<CacheClassMember> {
  final Value<String> id;
  final Value<String> classId;
  final Value<String> studentId;
  final Value<String> status;
  final Value<DateTime> requestedAt;
  final Value<DateTime?> decidedAt;
  final Value<String?> decidedBy;
  final Value<DateTime?> leftAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CacheClassMembersCompanion({
    this.id = const Value.absent(),
    this.classId = const Value.absent(),
    this.studentId = const Value.absent(),
    this.status = const Value.absent(),
    this.requestedAt = const Value.absent(),
    this.decidedAt = const Value.absent(),
    this.decidedBy = const Value.absent(),
    this.leftAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CacheClassMembersCompanion.insert({
    required String id,
    required String classId,
    required String studentId,
    this.status = const Value.absent(),
    this.requestedAt = const Value.absent(),
    this.decidedAt = const Value.absent(),
    this.decidedBy = const Value.absent(),
    this.leftAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       classId = Value(classId),
       studentId = Value(studentId);
  static Insertable<CacheClassMember> custom({
    Expression<String>? id,
    Expression<String>? classId,
    Expression<String>? studentId,
    Expression<String>? status,
    Expression<DateTime>? requestedAt,
    Expression<DateTime>? decidedAt,
    Expression<String>? decidedBy,
    Expression<DateTime>? leftAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (classId != null) 'class_id': classId,
      if (studentId != null) 'student_id': studentId,
      if (status != null) 'status': status,
      if (requestedAt != null) 'requested_at': requestedAt,
      if (decidedAt != null) 'decided_at': decidedAt,
      if (decidedBy != null) 'decided_by': decidedBy,
      if (leftAt != null) 'left_at': leftAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CacheClassMembersCompanion copyWith({
    Value<String>? id,
    Value<String>? classId,
    Value<String>? studentId,
    Value<String>? status,
    Value<DateTime>? requestedAt,
    Value<DateTime?>? decidedAt,
    Value<String?>? decidedBy,
    Value<DateTime?>? leftAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CacheClassMembersCompanion(
      id: id ?? this.id,
      classId: classId ?? this.classId,
      studentId: studentId ?? this.studentId,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      decidedAt: decidedAt ?? this.decidedAt,
      decidedBy: decidedBy ?? this.decidedBy,
      leftAt: leftAt ?? this.leftAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (classId.present) {
      map['class_id'] = Variable<String>(classId.value);
    }
    if (studentId.present) {
      map['student_id'] = Variable<String>(studentId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (requestedAt.present) {
      map['requested_at'] = Variable<DateTime>(requestedAt.value);
    }
    if (decidedAt.present) {
      map['decided_at'] = Variable<DateTime>(decidedAt.value);
    }
    if (decidedBy.present) {
      map['decided_by'] = Variable<String>(decidedBy.value);
    }
    if (leftAt.present) {
      map['left_at'] = Variable<DateTime>(leftAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CacheClassMembersCompanion(')
          ..write('id: $id, ')
          ..write('classId: $classId, ')
          ..write('studentId: $studentId, ')
          ..write('status: $status, ')
          ..write('requestedAt: $requestedAt, ')
          ..write('decidedAt: $decidedAt, ')
          ..write('decidedBy: $decidedBy, ')
          ..write('leftAt: $leftAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachePostsTable extends CachePosts
    with TableInfo<$CachePostsTable, CachePost> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachePostsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _classIdMeta = const VerificationMeta(
    'classId',
  );
  @override
  late final GeneratedColumn<String> classId = GeneratedColumn<String>(
    'class_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cache_classes (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _authorIdMeta = const VerificationMeta(
    'authorId',
  );
  @override
  late final GeneratedColumn<String> authorId = GeneratedColumn<String>(
    'author_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cache_profiles (id)',
    ),
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
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pointsMeta = const VerificationMeta('points');
  @override
  late final GeneratedColumn<int> points = GeneratedColumn<int>(
    'points',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueAtMeta = const VerificationMeta('dueAt');
  @override
  late final GeneratedColumn<DateTime> dueAt = GeneratedColumn<DateTime>(
    'due_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _acceptLateMeta = const VerificationMeta(
    'acceptLate',
  );
  @override
  late final GeneratedColumn<bool> acceptLate = GeneratedColumn<bool>(
    'accept_late',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("accept_late" IN (0, 1))',
    ),
    defaultValue: Constant(true),
  );
  static const VerificationMeta _allowFilesMeta = const VerificationMeta(
    'allowFiles',
  );
  @override
  late final GeneratedColumn<bool> allowFiles = GeneratedColumn<bool>(
    'allow_files',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("allow_files" IN (0, 1))',
    ),
    defaultValue: Constant(true),
  );
  static const VerificationMeta _maxFilesMeta = const VerificationMeta(
    'maxFiles',
  );
  @override
  late final GeneratedColumn<int> maxFiles = GeneratedColumn<int>(
    'max_files',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: Constant(5),
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
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
    classId,
    authorId,
    kind,
    title,
    body,
    points,
    dueAt,
    acceptLate,
    allowFiles,
    maxFiles,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cache_posts';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachePost> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('class_id')) {
      context.handle(
        _classIdMeta,
        classId.isAcceptableOrUnknown(data['class_id']!, _classIdMeta),
      );
    } else if (isInserting) {
      context.missing(_classIdMeta);
    }
    if (data.containsKey('author_id')) {
      context.handle(
        _authorIdMeta,
        authorId.isAcceptableOrUnknown(data['author_id']!, _authorIdMeta),
      );
    } else if (isInserting) {
      context.missing(_authorIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    }
    if (data.containsKey('points')) {
      context.handle(
        _pointsMeta,
        points.isAcceptableOrUnknown(data['points']!, _pointsMeta),
      );
    }
    if (data.containsKey('due_at')) {
      context.handle(
        _dueAtMeta,
        dueAt.isAcceptableOrUnknown(data['due_at']!, _dueAtMeta),
      );
    }
    if (data.containsKey('accept_late')) {
      context.handle(
        _acceptLateMeta,
        acceptLate.isAcceptableOrUnknown(data['accept_late']!, _acceptLateMeta),
      );
    }
    if (data.containsKey('allow_files')) {
      context.handle(
        _allowFilesMeta,
        allowFiles.isAcceptableOrUnknown(data['allow_files']!, _allowFilesMeta),
      );
    }
    if (data.containsKey('max_files')) {
      context.handle(
        _maxFilesMeta,
        maxFiles.isAcceptableOrUnknown(data['max_files']!, _maxFilesMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachePost map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachePost(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      classId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}class_id'],
      )!,
      authorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      ),
      points: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}points'],
      ),
      dueAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_at'],
      ),
      acceptLate: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}accept_late'],
      )!,
      allowFiles: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}allow_files'],
      )!,
      maxFiles: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_files'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $CachePostsTable createAlias(String alias) {
    return $CachePostsTable(attachedDatabase, alias);
  }
}

class CachePost extends DataClass implements Insertable<CachePost> {
  final String id;
  final String classId;
  final String authorId;
  final String kind;
  final String title;
  final String? body;
  final int? points;
  final DateTime? dueAt;
  final bool acceptLate;
  final bool allowFiles;
  final int maxFiles;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const CachePost({
    required this.id,
    required this.classId,
    required this.authorId,
    required this.kind,
    required this.title,
    this.body,
    this.points,
    this.dueAt,
    required this.acceptLate,
    required this.allowFiles,
    required this.maxFiles,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['class_id'] = Variable<String>(classId);
    map['author_id'] = Variable<String>(authorId);
    map['kind'] = Variable<String>(kind);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || body != null) {
      map['body'] = Variable<String>(body);
    }
    if (!nullToAbsent || points != null) {
      map['points'] = Variable<int>(points);
    }
    if (!nullToAbsent || dueAt != null) {
      map['due_at'] = Variable<DateTime>(dueAt);
    }
    map['accept_late'] = Variable<bool>(acceptLate);
    map['allow_files'] = Variable<bool>(allowFiles);
    map['max_files'] = Variable<int>(maxFiles);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  CachePostsCompanion toCompanion(bool nullToAbsent) {
    return CachePostsCompanion(
      id: Value(id),
      classId: Value(classId),
      authorId: Value(authorId),
      kind: Value(kind),
      title: Value(title),
      body: body == null && nullToAbsent ? const Value.absent() : Value(body),
      points: points == null && nullToAbsent
          ? const Value.absent()
          : Value(points),
      dueAt: dueAt == null && nullToAbsent
          ? const Value.absent()
          : Value(dueAt),
      acceptLate: Value(acceptLate),
      allowFiles: Value(allowFiles),
      maxFiles: Value(maxFiles),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory CachePost.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachePost(
      id: serializer.fromJson<String>(json['id']),
      classId: serializer.fromJson<String>(json['classId']),
      authorId: serializer.fromJson<String>(json['authorId']),
      kind: serializer.fromJson<String>(json['kind']),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String?>(json['body']),
      points: serializer.fromJson<int?>(json['points']),
      dueAt: serializer.fromJson<DateTime?>(json['dueAt']),
      acceptLate: serializer.fromJson<bool>(json['acceptLate']),
      allowFiles: serializer.fromJson<bool>(json['allowFiles']),
      maxFiles: serializer.fromJson<int>(json['maxFiles']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'classId': serializer.toJson<String>(classId),
      'authorId': serializer.toJson<String>(authorId),
      'kind': serializer.toJson<String>(kind),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String?>(body),
      'points': serializer.toJson<int?>(points),
      'dueAt': serializer.toJson<DateTime?>(dueAt),
      'acceptLate': serializer.toJson<bool>(acceptLate),
      'allowFiles': serializer.toJson<bool>(allowFiles),
      'maxFiles': serializer.toJson<int>(maxFiles),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  CachePost copyWith({
    String? id,
    String? classId,
    String? authorId,
    String? kind,
    String? title,
    Value<String?> body = const Value.absent(),
    Value<int?> points = const Value.absent(),
    Value<DateTime?> dueAt = const Value.absent(),
    bool? acceptLate,
    bool? allowFiles,
    int? maxFiles,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => CachePost(
    id: id ?? this.id,
    classId: classId ?? this.classId,
    authorId: authorId ?? this.authorId,
    kind: kind ?? this.kind,
    title: title ?? this.title,
    body: body.present ? body.value : this.body,
    points: points.present ? points.value : this.points,
    dueAt: dueAt.present ? dueAt.value : this.dueAt,
    acceptLate: acceptLate ?? this.acceptLate,
    allowFiles: allowFiles ?? this.allowFiles,
    maxFiles: maxFiles ?? this.maxFiles,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  CachePost copyWithCompanion(CachePostsCompanion data) {
    return CachePost(
      id: data.id.present ? data.id.value : this.id,
      classId: data.classId.present ? data.classId.value : this.classId,
      authorId: data.authorId.present ? data.authorId.value : this.authorId,
      kind: data.kind.present ? data.kind.value : this.kind,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      points: data.points.present ? data.points.value : this.points,
      dueAt: data.dueAt.present ? data.dueAt.value : this.dueAt,
      acceptLate: data.acceptLate.present
          ? data.acceptLate.value
          : this.acceptLate,
      allowFiles: data.allowFiles.present
          ? data.allowFiles.value
          : this.allowFiles,
      maxFiles: data.maxFiles.present ? data.maxFiles.value : this.maxFiles,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachePost(')
          ..write('id: $id, ')
          ..write('classId: $classId, ')
          ..write('authorId: $authorId, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('points: $points, ')
          ..write('dueAt: $dueAt, ')
          ..write('acceptLate: $acceptLate, ')
          ..write('allowFiles: $allowFiles, ')
          ..write('maxFiles: $maxFiles, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    classId,
    authorId,
    kind,
    title,
    body,
    points,
    dueAt,
    acceptLate,
    allowFiles,
    maxFiles,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachePost &&
          other.id == this.id &&
          other.classId == this.classId &&
          other.authorId == this.authorId &&
          other.kind == this.kind &&
          other.title == this.title &&
          other.body == this.body &&
          other.points == this.points &&
          other.dueAt == this.dueAt &&
          other.acceptLate == this.acceptLate &&
          other.allowFiles == this.allowFiles &&
          other.maxFiles == this.maxFiles &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class CachePostsCompanion extends UpdateCompanion<CachePost> {
  final Value<String> id;
  final Value<String> classId;
  final Value<String> authorId;
  final Value<String> kind;
  final Value<String> title;
  final Value<String?> body;
  final Value<int?> points;
  final Value<DateTime?> dueAt;
  final Value<bool> acceptLate;
  final Value<bool> allowFiles;
  final Value<int> maxFiles;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const CachePostsCompanion({
    this.id = const Value.absent(),
    this.classId = const Value.absent(),
    this.authorId = const Value.absent(),
    this.kind = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.points = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.acceptLate = const Value.absent(),
    this.allowFiles = const Value.absent(),
    this.maxFiles = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachePostsCompanion.insert({
    required String id,
    required String classId,
    required String authorId,
    required String kind,
    required String title,
    this.body = const Value.absent(),
    this.points = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.acceptLate = const Value.absent(),
    this.allowFiles = const Value.absent(),
    this.maxFiles = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       classId = Value(classId),
       authorId = Value(authorId),
       kind = Value(kind),
       title = Value(title);
  static Insertable<CachePost> custom({
    Expression<String>? id,
    Expression<String>? classId,
    Expression<String>? authorId,
    Expression<String>? kind,
    Expression<String>? title,
    Expression<String>? body,
    Expression<int>? points,
    Expression<DateTime>? dueAt,
    Expression<bool>? acceptLate,
    Expression<bool>? allowFiles,
    Expression<int>? maxFiles,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (classId != null) 'class_id': classId,
      if (authorId != null) 'author_id': authorId,
      if (kind != null) 'kind': kind,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (points != null) 'points': points,
      if (dueAt != null) 'due_at': dueAt,
      if (acceptLate != null) 'accept_late': acceptLate,
      if (allowFiles != null) 'allow_files': allowFiles,
      if (maxFiles != null) 'max_files': maxFiles,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachePostsCompanion copyWith({
    Value<String>? id,
    Value<String>? classId,
    Value<String>? authorId,
    Value<String>? kind,
    Value<String>? title,
    Value<String?>? body,
    Value<int?>? points,
    Value<DateTime?>? dueAt,
    Value<bool>? acceptLate,
    Value<bool>? allowFiles,
    Value<int>? maxFiles,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return CachePostsCompanion(
      id: id ?? this.id,
      classId: classId ?? this.classId,
      authorId: authorId ?? this.authorId,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      body: body ?? this.body,
      points: points ?? this.points,
      dueAt: dueAt ?? this.dueAt,
      acceptLate: acceptLate ?? this.acceptLate,
      allowFiles: allowFiles ?? this.allowFiles,
      maxFiles: maxFiles ?? this.maxFiles,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
    if (classId.present) {
      map['class_id'] = Variable<String>(classId.value);
    }
    if (authorId.present) {
      map['author_id'] = Variable<String>(authorId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (points.present) {
      map['points'] = Variable<int>(points.value);
    }
    if (dueAt.present) {
      map['due_at'] = Variable<DateTime>(dueAt.value);
    }
    if (acceptLate.present) {
      map['accept_late'] = Variable<bool>(acceptLate.value);
    }
    if (allowFiles.present) {
      map['allow_files'] = Variable<bool>(allowFiles.value);
    }
    if (maxFiles.present) {
      map['max_files'] = Variable<int>(maxFiles.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachePostsCompanion(')
          ..write('id: $id, ')
          ..write('classId: $classId, ')
          ..write('authorId: $authorId, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('points: $points, ')
          ..write('dueAt: $dueAt, ')
          ..write('acceptLate: $acceptLate, ')
          ..write('allowFiles: $allowFiles, ')
          ..write('maxFiles: $maxFiles, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachePostAttachmentsTable extends CachePostAttachments
    with TableInfo<$CachePostAttachmentsTable, CachePostAttachment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachePostAttachmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _postIdMeta = const VerificationMeta('postId');
  @override
  late final GeneratedColumn<String> postId = GeneratedColumn<String>(
    'post_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cache_posts (id) ON DELETE CASCADE',
    ),
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storagePathMeta = const VerificationMeta(
    'storagePath',
  );
  @override
  late final GeneratedColumn<String> storagePath = GeneratedColumn<String>(
    'storage_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: Constant(0),
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
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
    postId,
    kind,
    name,
    storagePath,
    url,
    mimeType,
    sizeBytes,
    sortOrder,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cache_post_attachments';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachePostAttachment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('post_id')) {
      context.handle(
        _postIdMeta,
        postId.isAcceptableOrUnknown(data['post_id']!, _postIdMeta),
      );
    } else if (isInserting) {
      context.missing(_postIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('storage_path')) {
      context.handle(
        _storagePathMeta,
        storagePath.isAcceptableOrUnknown(
          data['storage_path']!,
          _storagePathMeta,
        ),
      );
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachePostAttachment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachePostAttachment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      postId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}post_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      storagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}storage_path'],
      ),
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      ),
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      ),
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $CachePostAttachmentsTable createAlias(String alias) {
    return $CachePostAttachmentsTable(attachedDatabase, alias);
  }
}

class CachePostAttachment extends DataClass
    implements Insertable<CachePostAttachment> {
  final String id;
  final String postId;
  final String kind;
  final String name;
  final String? storagePath;
  final String? url;
  final String? mimeType;
  final int? sizeBytes;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const CachePostAttachment({
    required this.id,
    required this.postId,
    required this.kind,
    required this.name,
    this.storagePath,
    this.url,
    this.mimeType,
    this.sizeBytes,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['post_id'] = Variable<String>(postId);
    map['kind'] = Variable<String>(kind);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || storagePath != null) {
      map['storage_path'] = Variable<String>(storagePath);
    }
    if (!nullToAbsent || url != null) {
      map['url'] = Variable<String>(url);
    }
    if (!nullToAbsent || mimeType != null) {
      map['mime_type'] = Variable<String>(mimeType);
    }
    if (!nullToAbsent || sizeBytes != null) {
      map['size_bytes'] = Variable<int>(sizeBytes);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  CachePostAttachmentsCompanion toCompanion(bool nullToAbsent) {
    return CachePostAttachmentsCompanion(
      id: Value(id),
      postId: Value(postId),
      kind: Value(kind),
      name: Value(name),
      storagePath: storagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(storagePath),
      url: url == null && nullToAbsent ? const Value.absent() : Value(url),
      mimeType: mimeType == null && nullToAbsent
          ? const Value.absent()
          : Value(mimeType),
      sizeBytes: sizeBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(sizeBytes),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory CachePostAttachment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachePostAttachment(
      id: serializer.fromJson<String>(json['id']),
      postId: serializer.fromJson<String>(json['postId']),
      kind: serializer.fromJson<String>(json['kind']),
      name: serializer.fromJson<String>(json['name']),
      storagePath: serializer.fromJson<String?>(json['storagePath']),
      url: serializer.fromJson<String?>(json['url']),
      mimeType: serializer.fromJson<String?>(json['mimeType']),
      sizeBytes: serializer.fromJson<int?>(json['sizeBytes']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'postId': serializer.toJson<String>(postId),
      'kind': serializer.toJson<String>(kind),
      'name': serializer.toJson<String>(name),
      'storagePath': serializer.toJson<String?>(storagePath),
      'url': serializer.toJson<String?>(url),
      'mimeType': serializer.toJson<String?>(mimeType),
      'sizeBytes': serializer.toJson<int?>(sizeBytes),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  CachePostAttachment copyWith({
    String? id,
    String? postId,
    String? kind,
    String? name,
    Value<String?> storagePath = const Value.absent(),
    Value<String?> url = const Value.absent(),
    Value<String?> mimeType = const Value.absent(),
    Value<int?> sizeBytes = const Value.absent(),
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => CachePostAttachment(
    id: id ?? this.id,
    postId: postId ?? this.postId,
    kind: kind ?? this.kind,
    name: name ?? this.name,
    storagePath: storagePath.present ? storagePath.value : this.storagePath,
    url: url.present ? url.value : this.url,
    mimeType: mimeType.present ? mimeType.value : this.mimeType,
    sizeBytes: sizeBytes.present ? sizeBytes.value : this.sizeBytes,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  CachePostAttachment copyWithCompanion(CachePostAttachmentsCompanion data) {
    return CachePostAttachment(
      id: data.id.present ? data.id.value : this.id,
      postId: data.postId.present ? data.postId.value : this.postId,
      kind: data.kind.present ? data.kind.value : this.kind,
      name: data.name.present ? data.name.value : this.name,
      storagePath: data.storagePath.present
          ? data.storagePath.value
          : this.storagePath,
      url: data.url.present ? data.url.value : this.url,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachePostAttachment(')
          ..write('id: $id, ')
          ..write('postId: $postId, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('storagePath: $storagePath, ')
          ..write('url: $url, ')
          ..write('mimeType: $mimeType, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    postId,
    kind,
    name,
    storagePath,
    url,
    mimeType,
    sizeBytes,
    sortOrder,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachePostAttachment &&
          other.id == this.id &&
          other.postId == this.postId &&
          other.kind == this.kind &&
          other.name == this.name &&
          other.storagePath == this.storagePath &&
          other.url == this.url &&
          other.mimeType == this.mimeType &&
          other.sizeBytes == this.sizeBytes &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class CachePostAttachmentsCompanion
    extends UpdateCompanion<CachePostAttachment> {
  final Value<String> id;
  final Value<String> postId;
  final Value<String> kind;
  final Value<String> name;
  final Value<String?> storagePath;
  final Value<String?> url;
  final Value<String?> mimeType;
  final Value<int?> sizeBytes;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const CachePostAttachmentsCompanion({
    this.id = const Value.absent(),
    this.postId = const Value.absent(),
    this.kind = const Value.absent(),
    this.name = const Value.absent(),
    this.storagePath = const Value.absent(),
    this.url = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachePostAttachmentsCompanion.insert({
    required String id,
    required String postId,
    required String kind,
    required String name,
    this.storagePath = const Value.absent(),
    this.url = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       postId = Value(postId),
       kind = Value(kind),
       name = Value(name);
  static Insertable<CachePostAttachment> custom({
    Expression<String>? id,
    Expression<String>? postId,
    Expression<String>? kind,
    Expression<String>? name,
    Expression<String>? storagePath,
    Expression<String>? url,
    Expression<String>? mimeType,
    Expression<int>? sizeBytes,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (postId != null) 'post_id': postId,
      if (kind != null) 'kind': kind,
      if (name != null) 'name': name,
      if (storagePath != null) 'storage_path': storagePath,
      if (url != null) 'url': url,
      if (mimeType != null) 'mime_type': mimeType,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachePostAttachmentsCompanion copyWith({
    Value<String>? id,
    Value<String>? postId,
    Value<String>? kind,
    Value<String>? name,
    Value<String?>? storagePath,
    Value<String?>? url,
    Value<String?>? mimeType,
    Value<int?>? sizeBytes,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return CachePostAttachmentsCompanion(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      storagePath: storagePath ?? this.storagePath,
      url: url ?? this.url,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
    if (postId.present) {
      map['post_id'] = Variable<String>(postId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (storagePath.present) {
      map['storage_path'] = Variable<String>(storagePath.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachePostAttachmentsCompanion(')
          ..write('id: $id, ')
          ..write('postId: $postId, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('storagePath: $storagePath, ')
          ..write('url: $url, ')
          ..write('mimeType: $mimeType, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CacheSubmissionsTable extends CacheSubmissions
    with TableInfo<$CacheSubmissionsTable, CacheSubmission> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CacheSubmissionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _postIdMeta = const VerificationMeta('postId');
  @override
  late final GeneratedColumn<String> postId = GeneratedColumn<String>(
    'post_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cache_posts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _studentIdMeta = const VerificationMeta(
    'studentId',
  );
  @override
  late final GeneratedColumn<String> studentId = GeneratedColumn<String>(
    'student_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cache_profiles (id)',
    ),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("draft"),
  );
  static const VerificationMeta _privateCommentMeta = const VerificationMeta(
    'privateComment',
  );
  @override
  late final GeneratedColumn<String> privateComment = GeneratedColumn<String>(
    'private_comment',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _submittedAtMeta = const VerificationMeta(
    'submittedAt',
  );
  @override
  late final GeneratedColumn<DateTime> submittedAt = GeneratedColumn<DateTime>(
    'submitted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isLateMeta = const VerificationMeta('isLate');
  @override
  late final GeneratedColumn<bool> isLate = GeneratedColumn<bool>(
    'is_late',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_late" IN (0, 1))',
    ),
    defaultValue: Constant(false),
  );
  static const VerificationMeta _unsubmitUntilMeta = const VerificationMeta(
    'unsubmitUntil',
  );
  @override
  late final GeneratedColumn<DateTime> unsubmitUntil =
      GeneratedColumn<DateTime>(
        'unsubmit_until',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    postId,
    studentId,
    status,
    privateComment,
    submittedAt,
    isLate,
    unsubmitUntil,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cache_submissions';
  @override
  VerificationContext validateIntegrity(
    Insertable<CacheSubmission> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('post_id')) {
      context.handle(
        _postIdMeta,
        postId.isAcceptableOrUnknown(data['post_id']!, _postIdMeta),
      );
    } else if (isInserting) {
      context.missing(_postIdMeta);
    }
    if (data.containsKey('student_id')) {
      context.handle(
        _studentIdMeta,
        studentId.isAcceptableOrUnknown(data['student_id']!, _studentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_studentIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('private_comment')) {
      context.handle(
        _privateCommentMeta,
        privateComment.isAcceptableOrUnknown(
          data['private_comment']!,
          _privateCommentMeta,
        ),
      );
    }
    if (data.containsKey('submitted_at')) {
      context.handle(
        _submittedAtMeta,
        submittedAt.isAcceptableOrUnknown(
          data['submitted_at']!,
          _submittedAtMeta,
        ),
      );
    }
    if (data.containsKey('is_late')) {
      context.handle(
        _isLateMeta,
        isLate.isAcceptableOrUnknown(data['is_late']!, _isLateMeta),
      );
    }
    if (data.containsKey('unsubmit_until')) {
      context.handle(
        _unsubmitUntilMeta,
        unsubmitUntil.isAcceptableOrUnknown(
          data['unsubmit_until']!,
          _unsubmitUntilMeta,
        ),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CacheSubmission map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CacheSubmission(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      postId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}post_id'],
      )!,
      studentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}student_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      privateComment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}private_comment'],
      ),
      submittedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}submitted_at'],
      ),
      isLate: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_late'],
      )!,
      unsubmitUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}unsubmit_until'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CacheSubmissionsTable createAlias(String alias) {
    return $CacheSubmissionsTable(attachedDatabase, alias);
  }
}

class CacheSubmission extends DataClass implements Insertable<CacheSubmission> {
  final String id;
  final String postId;
  final String studentId;
  final String status;
  final String? privateComment;
  final DateTime? submittedAt;
  final bool isLate;
  final DateTime? unsubmitUntil;
  final DateTime createdAt;
  final DateTime updatedAt;
  const CacheSubmission({
    required this.id,
    required this.postId,
    required this.studentId,
    required this.status,
    this.privateComment,
    this.submittedAt,
    required this.isLate,
    this.unsubmitUntil,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['post_id'] = Variable<String>(postId);
    map['student_id'] = Variable<String>(studentId);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || privateComment != null) {
      map['private_comment'] = Variable<String>(privateComment);
    }
    if (!nullToAbsent || submittedAt != null) {
      map['submitted_at'] = Variable<DateTime>(submittedAt);
    }
    map['is_late'] = Variable<bool>(isLate);
    if (!nullToAbsent || unsubmitUntil != null) {
      map['unsubmit_until'] = Variable<DateTime>(unsubmitUntil);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CacheSubmissionsCompanion toCompanion(bool nullToAbsent) {
    return CacheSubmissionsCompanion(
      id: Value(id),
      postId: Value(postId),
      studentId: Value(studentId),
      status: Value(status),
      privateComment: privateComment == null && nullToAbsent
          ? const Value.absent()
          : Value(privateComment),
      submittedAt: submittedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(submittedAt),
      isLate: Value(isLate),
      unsubmitUntil: unsubmitUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(unsubmitUntil),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory CacheSubmission.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CacheSubmission(
      id: serializer.fromJson<String>(json['id']),
      postId: serializer.fromJson<String>(json['postId']),
      studentId: serializer.fromJson<String>(json['studentId']),
      status: serializer.fromJson<String>(json['status']),
      privateComment: serializer.fromJson<String?>(json['privateComment']),
      submittedAt: serializer.fromJson<DateTime?>(json['submittedAt']),
      isLate: serializer.fromJson<bool>(json['isLate']),
      unsubmitUntil: serializer.fromJson<DateTime?>(json['unsubmitUntil']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'postId': serializer.toJson<String>(postId),
      'studentId': serializer.toJson<String>(studentId),
      'status': serializer.toJson<String>(status),
      'privateComment': serializer.toJson<String?>(privateComment),
      'submittedAt': serializer.toJson<DateTime?>(submittedAt),
      'isLate': serializer.toJson<bool>(isLate),
      'unsubmitUntil': serializer.toJson<DateTime?>(unsubmitUntil),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CacheSubmission copyWith({
    String? id,
    String? postId,
    String? studentId,
    String? status,
    Value<String?> privateComment = const Value.absent(),
    Value<DateTime?> submittedAt = const Value.absent(),
    bool? isLate,
    Value<DateTime?> unsubmitUntil = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CacheSubmission(
    id: id ?? this.id,
    postId: postId ?? this.postId,
    studentId: studentId ?? this.studentId,
    status: status ?? this.status,
    privateComment: privateComment.present
        ? privateComment.value
        : this.privateComment,
    submittedAt: submittedAt.present ? submittedAt.value : this.submittedAt,
    isLate: isLate ?? this.isLate,
    unsubmitUntil: unsubmitUntil.present
        ? unsubmitUntil.value
        : this.unsubmitUntil,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CacheSubmission copyWithCompanion(CacheSubmissionsCompanion data) {
    return CacheSubmission(
      id: data.id.present ? data.id.value : this.id,
      postId: data.postId.present ? data.postId.value : this.postId,
      studentId: data.studentId.present ? data.studentId.value : this.studentId,
      status: data.status.present ? data.status.value : this.status,
      privateComment: data.privateComment.present
          ? data.privateComment.value
          : this.privateComment,
      submittedAt: data.submittedAt.present
          ? data.submittedAt.value
          : this.submittedAt,
      isLate: data.isLate.present ? data.isLate.value : this.isLate,
      unsubmitUntil: data.unsubmitUntil.present
          ? data.unsubmitUntil.value
          : this.unsubmitUntil,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CacheSubmission(')
          ..write('id: $id, ')
          ..write('postId: $postId, ')
          ..write('studentId: $studentId, ')
          ..write('status: $status, ')
          ..write('privateComment: $privateComment, ')
          ..write('submittedAt: $submittedAt, ')
          ..write('isLate: $isLate, ')
          ..write('unsubmitUntil: $unsubmitUntil, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    postId,
    studentId,
    status,
    privateComment,
    submittedAt,
    isLate,
    unsubmitUntil,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CacheSubmission &&
          other.id == this.id &&
          other.postId == this.postId &&
          other.studentId == this.studentId &&
          other.status == this.status &&
          other.privateComment == this.privateComment &&
          other.submittedAt == this.submittedAt &&
          other.isLate == this.isLate &&
          other.unsubmitUntil == this.unsubmitUntil &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CacheSubmissionsCompanion extends UpdateCompanion<CacheSubmission> {
  final Value<String> id;
  final Value<String> postId;
  final Value<String> studentId;
  final Value<String> status;
  final Value<String?> privateComment;
  final Value<DateTime?> submittedAt;
  final Value<bool> isLate;
  final Value<DateTime?> unsubmitUntil;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CacheSubmissionsCompanion({
    this.id = const Value.absent(),
    this.postId = const Value.absent(),
    this.studentId = const Value.absent(),
    this.status = const Value.absent(),
    this.privateComment = const Value.absent(),
    this.submittedAt = const Value.absent(),
    this.isLate = const Value.absent(),
    this.unsubmitUntil = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CacheSubmissionsCompanion.insert({
    required String id,
    required String postId,
    required String studentId,
    this.status = const Value.absent(),
    this.privateComment = const Value.absent(),
    this.submittedAt = const Value.absent(),
    this.isLate = const Value.absent(),
    this.unsubmitUntil = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       postId = Value(postId),
       studentId = Value(studentId);
  static Insertable<CacheSubmission> custom({
    Expression<String>? id,
    Expression<String>? postId,
    Expression<String>? studentId,
    Expression<String>? status,
    Expression<String>? privateComment,
    Expression<DateTime>? submittedAt,
    Expression<bool>? isLate,
    Expression<DateTime>? unsubmitUntil,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (postId != null) 'post_id': postId,
      if (studentId != null) 'student_id': studentId,
      if (status != null) 'status': status,
      if (privateComment != null) 'private_comment': privateComment,
      if (submittedAt != null) 'submitted_at': submittedAt,
      if (isLate != null) 'is_late': isLate,
      if (unsubmitUntil != null) 'unsubmit_until': unsubmitUntil,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CacheSubmissionsCompanion copyWith({
    Value<String>? id,
    Value<String>? postId,
    Value<String>? studentId,
    Value<String>? status,
    Value<String?>? privateComment,
    Value<DateTime?>? submittedAt,
    Value<bool>? isLate,
    Value<DateTime?>? unsubmitUntil,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CacheSubmissionsCompanion(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      studentId: studentId ?? this.studentId,
      status: status ?? this.status,
      privateComment: privateComment ?? this.privateComment,
      submittedAt: submittedAt ?? this.submittedAt,
      isLate: isLate ?? this.isLate,
      unsubmitUntil: unsubmitUntil ?? this.unsubmitUntil,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (postId.present) {
      map['post_id'] = Variable<String>(postId.value);
    }
    if (studentId.present) {
      map['student_id'] = Variable<String>(studentId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (privateComment.present) {
      map['private_comment'] = Variable<String>(privateComment.value);
    }
    if (submittedAt.present) {
      map['submitted_at'] = Variable<DateTime>(submittedAt.value);
    }
    if (isLate.present) {
      map['is_late'] = Variable<bool>(isLate.value);
    }
    if (unsubmitUntil.present) {
      map['unsubmit_until'] = Variable<DateTime>(unsubmitUntil.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CacheSubmissionsCompanion(')
          ..write('id: $id, ')
          ..write('postId: $postId, ')
          ..write('studentId: $studentId, ')
          ..write('status: $status, ')
          ..write('privateComment: $privateComment, ')
          ..write('submittedAt: $submittedAt, ')
          ..write('isLate: $isLate, ')
          ..write('unsubmitUntil: $unsubmitUntil, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CacheSubmissionItemsTable extends CacheSubmissionItems
    with TableInfo<$CacheSubmissionItemsTable, CacheSubmissionItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CacheSubmissionItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _submissionIdMeta = const VerificationMeta(
    'submissionId',
  );
  @override
  late final GeneratedColumn<String> submissionId = GeneratedColumn<String>(
    'submission_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cache_submissions (id) ON DELETE CASCADE',
    ),
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _storagePathMeta = const VerificationMeta(
    'storagePath',
  );
  @override
  late final GeneratedColumn<String> storagePath = GeneratedColumn<String>(
    'storage_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _textContentMeta = const VerificationMeta(
    'textContent',
  );
  @override
  late final GeneratedColumn<String> textContent = GeneratedColumn<String>(
    'text_content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: Constant(0),
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
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
    submissionId,
    kind,
    name,
    storagePath,
    url,
    textContent,
    mimeType,
    sizeBytes,
    sortOrder,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cache_submission_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<CacheSubmissionItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('submission_id')) {
      context.handle(
        _submissionIdMeta,
        submissionId.isAcceptableOrUnknown(
          data['submission_id']!,
          _submissionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_submissionIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('storage_path')) {
      context.handle(
        _storagePathMeta,
        storagePath.isAcceptableOrUnknown(
          data['storage_path']!,
          _storagePathMeta,
        ),
      );
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    }
    if (data.containsKey('text_content')) {
      context.handle(
        _textContentMeta,
        textContent.isAcceptableOrUnknown(
          data['text_content']!,
          _textContentMeta,
        ),
      );
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CacheSubmissionItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CacheSubmissionItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      submissionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}submission_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      storagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}storage_path'],
      ),
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      ),
      textContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text_content'],
      ),
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      ),
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $CacheSubmissionItemsTable createAlias(String alias) {
    return $CacheSubmissionItemsTable(attachedDatabase, alias);
  }
}

class CacheSubmissionItem extends DataClass
    implements Insertable<CacheSubmissionItem> {
  final String id;
  final String submissionId;
  final String kind;
  final String? name;
  final String? storagePath;
  final String? url;
  final String? textContent;
  final String? mimeType;
  final int? sizeBytes;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const CacheSubmissionItem({
    required this.id,
    required this.submissionId,
    required this.kind,
    this.name,
    this.storagePath,
    this.url,
    this.textContent,
    this.mimeType,
    this.sizeBytes,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['submission_id'] = Variable<String>(submissionId);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || storagePath != null) {
      map['storage_path'] = Variable<String>(storagePath);
    }
    if (!nullToAbsent || url != null) {
      map['url'] = Variable<String>(url);
    }
    if (!nullToAbsent || textContent != null) {
      map['text_content'] = Variable<String>(textContent);
    }
    if (!nullToAbsent || mimeType != null) {
      map['mime_type'] = Variable<String>(mimeType);
    }
    if (!nullToAbsent || sizeBytes != null) {
      map['size_bytes'] = Variable<int>(sizeBytes);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  CacheSubmissionItemsCompanion toCompanion(bool nullToAbsent) {
    return CacheSubmissionItemsCompanion(
      id: Value(id),
      submissionId: Value(submissionId),
      kind: Value(kind),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      storagePath: storagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(storagePath),
      url: url == null && nullToAbsent ? const Value.absent() : Value(url),
      textContent: textContent == null && nullToAbsent
          ? const Value.absent()
          : Value(textContent),
      mimeType: mimeType == null && nullToAbsent
          ? const Value.absent()
          : Value(mimeType),
      sizeBytes: sizeBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(sizeBytes),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory CacheSubmissionItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CacheSubmissionItem(
      id: serializer.fromJson<String>(json['id']),
      submissionId: serializer.fromJson<String>(json['submissionId']),
      kind: serializer.fromJson<String>(json['kind']),
      name: serializer.fromJson<String?>(json['name']),
      storagePath: serializer.fromJson<String?>(json['storagePath']),
      url: serializer.fromJson<String?>(json['url']),
      textContent: serializer.fromJson<String?>(json['textContent']),
      mimeType: serializer.fromJson<String?>(json['mimeType']),
      sizeBytes: serializer.fromJson<int?>(json['sizeBytes']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'submissionId': serializer.toJson<String>(submissionId),
      'kind': serializer.toJson<String>(kind),
      'name': serializer.toJson<String?>(name),
      'storagePath': serializer.toJson<String?>(storagePath),
      'url': serializer.toJson<String?>(url),
      'textContent': serializer.toJson<String?>(textContent),
      'mimeType': serializer.toJson<String?>(mimeType),
      'sizeBytes': serializer.toJson<int?>(sizeBytes),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  CacheSubmissionItem copyWith({
    String? id,
    String? submissionId,
    String? kind,
    Value<String?> name = const Value.absent(),
    Value<String?> storagePath = const Value.absent(),
    Value<String?> url = const Value.absent(),
    Value<String?> textContent = const Value.absent(),
    Value<String?> mimeType = const Value.absent(),
    Value<int?> sizeBytes = const Value.absent(),
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => CacheSubmissionItem(
    id: id ?? this.id,
    submissionId: submissionId ?? this.submissionId,
    kind: kind ?? this.kind,
    name: name.present ? name.value : this.name,
    storagePath: storagePath.present ? storagePath.value : this.storagePath,
    url: url.present ? url.value : this.url,
    textContent: textContent.present ? textContent.value : this.textContent,
    mimeType: mimeType.present ? mimeType.value : this.mimeType,
    sizeBytes: sizeBytes.present ? sizeBytes.value : this.sizeBytes,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  CacheSubmissionItem copyWithCompanion(CacheSubmissionItemsCompanion data) {
    return CacheSubmissionItem(
      id: data.id.present ? data.id.value : this.id,
      submissionId: data.submissionId.present
          ? data.submissionId.value
          : this.submissionId,
      kind: data.kind.present ? data.kind.value : this.kind,
      name: data.name.present ? data.name.value : this.name,
      storagePath: data.storagePath.present
          ? data.storagePath.value
          : this.storagePath,
      url: data.url.present ? data.url.value : this.url,
      textContent: data.textContent.present
          ? data.textContent.value
          : this.textContent,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CacheSubmissionItem(')
          ..write('id: $id, ')
          ..write('submissionId: $submissionId, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('storagePath: $storagePath, ')
          ..write('url: $url, ')
          ..write('textContent: $textContent, ')
          ..write('mimeType: $mimeType, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    submissionId,
    kind,
    name,
    storagePath,
    url,
    textContent,
    mimeType,
    sizeBytes,
    sortOrder,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CacheSubmissionItem &&
          other.id == this.id &&
          other.submissionId == this.submissionId &&
          other.kind == this.kind &&
          other.name == this.name &&
          other.storagePath == this.storagePath &&
          other.url == this.url &&
          other.textContent == this.textContent &&
          other.mimeType == this.mimeType &&
          other.sizeBytes == this.sizeBytes &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class CacheSubmissionItemsCompanion
    extends UpdateCompanion<CacheSubmissionItem> {
  final Value<String> id;
  final Value<String> submissionId;
  final Value<String> kind;
  final Value<String?> name;
  final Value<String?> storagePath;
  final Value<String?> url;
  final Value<String?> textContent;
  final Value<String?> mimeType;
  final Value<int?> sizeBytes;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const CacheSubmissionItemsCompanion({
    this.id = const Value.absent(),
    this.submissionId = const Value.absent(),
    this.kind = const Value.absent(),
    this.name = const Value.absent(),
    this.storagePath = const Value.absent(),
    this.url = const Value.absent(),
    this.textContent = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CacheSubmissionItemsCompanion.insert({
    required String id,
    required String submissionId,
    required String kind,
    this.name = const Value.absent(),
    this.storagePath = const Value.absent(),
    this.url = const Value.absent(),
    this.textContent = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       submissionId = Value(submissionId),
       kind = Value(kind);
  static Insertable<CacheSubmissionItem> custom({
    Expression<String>? id,
    Expression<String>? submissionId,
    Expression<String>? kind,
    Expression<String>? name,
    Expression<String>? storagePath,
    Expression<String>? url,
    Expression<String>? textContent,
    Expression<String>? mimeType,
    Expression<int>? sizeBytes,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (submissionId != null) 'submission_id': submissionId,
      if (kind != null) 'kind': kind,
      if (name != null) 'name': name,
      if (storagePath != null) 'storage_path': storagePath,
      if (url != null) 'url': url,
      if (textContent != null) 'text_content': textContent,
      if (mimeType != null) 'mime_type': mimeType,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CacheSubmissionItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? submissionId,
    Value<String>? kind,
    Value<String?>? name,
    Value<String?>? storagePath,
    Value<String?>? url,
    Value<String?>? textContent,
    Value<String?>? mimeType,
    Value<int?>? sizeBytes,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return CacheSubmissionItemsCompanion(
      id: id ?? this.id,
      submissionId: submissionId ?? this.submissionId,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      storagePath: storagePath ?? this.storagePath,
      url: url ?? this.url,
      textContent: textContent ?? this.textContent,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
    if (submissionId.present) {
      map['submission_id'] = Variable<String>(submissionId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (storagePath.present) {
      map['storage_path'] = Variable<String>(storagePath.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (textContent.present) {
      map['text_content'] = Variable<String>(textContent.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CacheSubmissionItemsCompanion(')
          ..write('id: $id, ')
          ..write('submissionId: $submissionId, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('storagePath: $storagePath, ')
          ..write('url: $url, ')
          ..write('textContent: $textContent, ')
          ..write('mimeType: $mimeType, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CacheGradesTable extends CacheGrades
    with TableInfo<$CacheGradesTable, CacheGrade> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CacheGradesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _submissionIdMeta = const VerificationMeta(
    'submissionId',
  );
  @override
  late final GeneratedColumn<String> submissionId = GeneratedColumn<String>(
    'submission_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cache_submissions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<int> score = GeneratedColumn<int>(
    'score',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _feedbackMeta = const VerificationMeta(
    'feedback',
  );
  @override
  late final GeneratedColumn<String> feedback = GeneratedColumn<String>(
    'feedback',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _gradedByMeta = const VerificationMeta(
    'gradedBy',
  );
  @override
  late final GeneratedColumn<String> gradedBy = GeneratedColumn<String>(
    'graded_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cache_profiles (id)',
    ),
  );
  static const VerificationMeta _gradedAtMeta = const VerificationMeta(
    'gradedAt',
  );
  @override
  late final GeneratedColumn<DateTime> gradedAt = GeneratedColumn<DateTime>(
    'graded_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _returnedAtMeta = const VerificationMeta(
    'returnedAt',
  );
  @override
  late final GeneratedColumn<DateTime> returnedAt = GeneratedColumn<DateTime>(
    'returned_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    submissionId,
    score,
    feedback,
    gradedBy,
    gradedAt,
    returnedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cache_grades';
  @override
  VerificationContext validateIntegrity(
    Insertable<CacheGrade> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('submission_id')) {
      context.handle(
        _submissionIdMeta,
        submissionId.isAcceptableOrUnknown(
          data['submission_id']!,
          _submissionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_submissionIdMeta);
    }
    if (data.containsKey('score')) {
      context.handle(
        _scoreMeta,
        score.isAcceptableOrUnknown(data['score']!, _scoreMeta),
      );
    }
    if (data.containsKey('feedback')) {
      context.handle(
        _feedbackMeta,
        feedback.isAcceptableOrUnknown(data['feedback']!, _feedbackMeta),
      );
    }
    if (data.containsKey('graded_by')) {
      context.handle(
        _gradedByMeta,
        gradedBy.isAcceptableOrUnknown(data['graded_by']!, _gradedByMeta),
      );
    }
    if (data.containsKey('graded_at')) {
      context.handle(
        _gradedAtMeta,
        gradedAt.isAcceptableOrUnknown(data['graded_at']!, _gradedAtMeta),
      );
    }
    if (data.containsKey('returned_at')) {
      context.handle(
        _returnedAtMeta,
        returnedAt.isAcceptableOrUnknown(data['returned_at']!, _returnedAtMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {submissionId};
  @override
  CacheGrade map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CacheGrade(
      submissionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}submission_id'],
      )!,
      score: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}score'],
      ),
      feedback: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}feedback'],
      ),
      gradedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}graded_by'],
      ),
      gradedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}graded_at'],
      ),
      returnedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}returned_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CacheGradesTable createAlias(String alias) {
    return $CacheGradesTable(attachedDatabase, alias);
  }
}

class CacheGrade extends DataClass implements Insertable<CacheGrade> {
  final String submissionId;
  final int? score;
  final String? feedback;
  final String? gradedBy;
  final DateTime? gradedAt;
  final DateTime? returnedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const CacheGrade({
    required this.submissionId,
    this.score,
    this.feedback,
    this.gradedBy,
    this.gradedAt,
    this.returnedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['submission_id'] = Variable<String>(submissionId);
    if (!nullToAbsent || score != null) {
      map['score'] = Variable<int>(score);
    }
    if (!nullToAbsent || feedback != null) {
      map['feedback'] = Variable<String>(feedback);
    }
    if (!nullToAbsent || gradedBy != null) {
      map['graded_by'] = Variable<String>(gradedBy);
    }
    if (!nullToAbsent || gradedAt != null) {
      map['graded_at'] = Variable<DateTime>(gradedAt);
    }
    if (!nullToAbsent || returnedAt != null) {
      map['returned_at'] = Variable<DateTime>(returnedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CacheGradesCompanion toCompanion(bool nullToAbsent) {
    return CacheGradesCompanion(
      submissionId: Value(submissionId),
      score: score == null && nullToAbsent
          ? const Value.absent()
          : Value(score),
      feedback: feedback == null && nullToAbsent
          ? const Value.absent()
          : Value(feedback),
      gradedBy: gradedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(gradedBy),
      gradedAt: gradedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(gradedAt),
      returnedAt: returnedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(returnedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory CacheGrade.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CacheGrade(
      submissionId: serializer.fromJson<String>(json['submissionId']),
      score: serializer.fromJson<int?>(json['score']),
      feedback: serializer.fromJson<String?>(json['feedback']),
      gradedBy: serializer.fromJson<String?>(json['gradedBy']),
      gradedAt: serializer.fromJson<DateTime?>(json['gradedAt']),
      returnedAt: serializer.fromJson<DateTime?>(json['returnedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'submissionId': serializer.toJson<String>(submissionId),
      'score': serializer.toJson<int?>(score),
      'feedback': serializer.toJson<String?>(feedback),
      'gradedBy': serializer.toJson<String?>(gradedBy),
      'gradedAt': serializer.toJson<DateTime?>(gradedAt),
      'returnedAt': serializer.toJson<DateTime?>(returnedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CacheGrade copyWith({
    String? submissionId,
    Value<int?> score = const Value.absent(),
    Value<String?> feedback = const Value.absent(),
    Value<String?> gradedBy = const Value.absent(),
    Value<DateTime?> gradedAt = const Value.absent(),
    Value<DateTime?> returnedAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CacheGrade(
    submissionId: submissionId ?? this.submissionId,
    score: score.present ? score.value : this.score,
    feedback: feedback.present ? feedback.value : this.feedback,
    gradedBy: gradedBy.present ? gradedBy.value : this.gradedBy,
    gradedAt: gradedAt.present ? gradedAt.value : this.gradedAt,
    returnedAt: returnedAt.present ? returnedAt.value : this.returnedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CacheGrade copyWithCompanion(CacheGradesCompanion data) {
    return CacheGrade(
      submissionId: data.submissionId.present
          ? data.submissionId.value
          : this.submissionId,
      score: data.score.present ? data.score.value : this.score,
      feedback: data.feedback.present ? data.feedback.value : this.feedback,
      gradedBy: data.gradedBy.present ? data.gradedBy.value : this.gradedBy,
      gradedAt: data.gradedAt.present ? data.gradedAt.value : this.gradedAt,
      returnedAt: data.returnedAt.present
          ? data.returnedAt.value
          : this.returnedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CacheGrade(')
          ..write('submissionId: $submissionId, ')
          ..write('score: $score, ')
          ..write('feedback: $feedback, ')
          ..write('gradedBy: $gradedBy, ')
          ..write('gradedAt: $gradedAt, ')
          ..write('returnedAt: $returnedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    submissionId,
    score,
    feedback,
    gradedBy,
    gradedAt,
    returnedAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CacheGrade &&
          other.submissionId == this.submissionId &&
          other.score == this.score &&
          other.feedback == this.feedback &&
          other.gradedBy == this.gradedBy &&
          other.gradedAt == this.gradedAt &&
          other.returnedAt == this.returnedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CacheGradesCompanion extends UpdateCompanion<CacheGrade> {
  final Value<String> submissionId;
  final Value<int?> score;
  final Value<String?> feedback;
  final Value<String?> gradedBy;
  final Value<DateTime?> gradedAt;
  final Value<DateTime?> returnedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CacheGradesCompanion({
    this.submissionId = const Value.absent(),
    this.score = const Value.absent(),
    this.feedback = const Value.absent(),
    this.gradedBy = const Value.absent(),
    this.gradedAt = const Value.absent(),
    this.returnedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CacheGradesCompanion.insert({
    required String submissionId,
    this.score = const Value.absent(),
    this.feedback = const Value.absent(),
    this.gradedBy = const Value.absent(),
    this.gradedAt = const Value.absent(),
    this.returnedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : submissionId = Value(submissionId);
  static Insertable<CacheGrade> custom({
    Expression<String>? submissionId,
    Expression<int>? score,
    Expression<String>? feedback,
    Expression<String>? gradedBy,
    Expression<DateTime>? gradedAt,
    Expression<DateTime>? returnedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (submissionId != null) 'submission_id': submissionId,
      if (score != null) 'score': score,
      if (feedback != null) 'feedback': feedback,
      if (gradedBy != null) 'graded_by': gradedBy,
      if (gradedAt != null) 'graded_at': gradedAt,
      if (returnedAt != null) 'returned_at': returnedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CacheGradesCompanion copyWith({
    Value<String>? submissionId,
    Value<int?>? score,
    Value<String?>? feedback,
    Value<String?>? gradedBy,
    Value<DateTime?>? gradedAt,
    Value<DateTime?>? returnedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CacheGradesCompanion(
      submissionId: submissionId ?? this.submissionId,
      score: score ?? this.score,
      feedback: feedback ?? this.feedback,
      gradedBy: gradedBy ?? this.gradedBy,
      gradedAt: gradedAt ?? this.gradedAt,
      returnedAt: returnedAt ?? this.returnedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (submissionId.present) {
      map['submission_id'] = Variable<String>(submissionId.value);
    }
    if (score.present) {
      map['score'] = Variable<int>(score.value);
    }
    if (feedback.present) {
      map['feedback'] = Variable<String>(feedback.value);
    }
    if (gradedBy.present) {
      map['graded_by'] = Variable<String>(gradedBy.value);
    }
    if (gradedAt.present) {
      map['graded_at'] = Variable<DateTime>(gradedAt.value);
    }
    if (returnedAt.present) {
      map['returned_at'] = Variable<DateTime>(returnedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CacheGradesCompanion(')
          ..write('submissionId: $submissionId, ')
          ..write('score: $score, ')
          ..write('feedback: $feedback, ')
          ..write('gradedBy: $gradedBy, ')
          ..write('gradedAt: $gradedAt, ')
          ..write('returnedAt: $returnedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CacheQuizzesTable extends CacheQuizzes
    with TableInfo<$CacheQuizzesTable, CacheQuizze> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CacheQuizzesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _classIdMeta = const VerificationMeta(
    'classId',
  );
  @override
  late final GeneratedColumn<String> classId = GeneratedColumn<String>(
    'class_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cache_classes (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _authorIdMeta = const VerificationMeta(
    'authorId',
  );
  @override
  late final GeneratedColumn<String> authorId = GeneratedColumn<String>(
    'author_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cache_profiles (id)',
    ),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant("quiz"),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _instructionsMeta = const VerificationMeta(
    'instructions',
  );
  @override
  late final GeneratedColumn<String> instructions = GeneratedColumn<String>(
    'instructions',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timeLimitMinutesMeta = const VerificationMeta(
    'timeLimitMinutes',
  );
  @override
  late final GeneratedColumn<int> timeLimitMinutes = GeneratedColumn<int>(
    'time_limit_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: Constant(30),
  );
  static const VerificationMeta _opensAtMeta = const VerificationMeta(
    'opensAt',
  );
  @override
  late final GeneratedColumn<DateTime> opensAt = GeneratedColumn<DateTime>(
    'opens_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _closesAtMeta = const VerificationMeta(
    'closesAt',
  );
  @override
  late final GeneratedColumn<DateTime> closesAt = GeneratedColumn<DateTime>(
    'closes_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _shuffleQuestionsMeta = const VerificationMeta(
    'shuffleQuestions',
  );
  @override
  late final GeneratedColumn<bool> shuffleQuestions = GeneratedColumn<bool>(
    'shuffle_questions',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("shuffle_questions" IN (0, 1))',
    ),
    defaultValue: Constant(true),
  );
  static const VerificationMeta _shuffleOptionsMeta = const VerificationMeta(
    'shuffleOptions',
  );
  @override
  late final GeneratedColumn<bool> shuffleOptions = GeneratedColumn<bool>(
    'shuffle_options',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("shuffle_options" IN (0, 1))',
    ),
    defaultValue: Constant(true),
  );
  static const VerificationMeta _showCorrectAnswersMeta =
      const VerificationMeta('showCorrectAnswers');
  @override
  late final GeneratedColumn<bool> showCorrectAnswers = GeneratedColumn<bool>(
    'show_correct_answers',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("show_correct_answers" IN (0, 1))',
    ),
    defaultValue: Constant(true),
  );
  static const VerificationMeta _passingPercentMeta = const VerificationMeta(
    'passingPercent',
  );
  @override
  late final GeneratedColumn<int> passingPercent = GeneratedColumn<int>(
    'passing_percent',
    aliasedName,
    true,
    type: DriftSqlType.int,
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
    defaultValue: Constant("draft"),
  );
  static const VerificationMeta _publishedAtMeta = const VerificationMeta(
    'publishedAt',
  );
  @override
  late final GeneratedColumn<DateTime> publishedAt = GeneratedColumn<DateTime>(
    'published_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resultsReleasedAtMeta = const VerificationMeta(
    'resultsReleasedAt',
  );
  @override
  late final GeneratedColumn<DateTime> resultsReleasedAt =
      GeneratedColumn<DateTime>(
        'results_released_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _totalPointsMeta = const VerificationMeta(
    'totalPoints',
  );
  @override
  late final GeneratedColumn<int> totalPoints = GeneratedColumn<int>(
    'total_points',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: Constant(0),
  );
  static const VerificationMeta _hasEssayMeta = const VerificationMeta(
    'hasEssay',
  );
  @override
  late final GeneratedColumn<bool> hasEssay = GeneratedColumn<bool>(
    'has_essay',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_essay" IN (0, 1))',
    ),
    defaultValue: Constant(false),
  );
  static const VerificationMeta _lockedAtMeta = const VerificationMeta(
    'lockedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lockedAt = GeneratedColumn<DateTime>(
    'locked_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
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
    classId,
    authorId,
    type,
    title,
    instructions,
    timeLimitMinutes,
    opensAt,
    closesAt,
    shuffleQuestions,
    shuffleOptions,
    showCorrectAnswers,
    passingPercent,
    status,
    publishedAt,
    resultsReleasedAt,
    totalPoints,
    hasEssay,
    lockedAt,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cache_quizzes';
  @override
  VerificationContext validateIntegrity(
    Insertable<CacheQuizze> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('class_id')) {
      context.handle(
        _classIdMeta,
        classId.isAcceptableOrUnknown(data['class_id']!, _classIdMeta),
      );
    } else if (isInserting) {
      context.missing(_classIdMeta);
    }
    if (data.containsKey('author_id')) {
      context.handle(
        _authorIdMeta,
        authorId.isAcceptableOrUnknown(data['author_id']!, _authorIdMeta),
      );
    } else if (isInserting) {
      context.missing(_authorIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('instructions')) {
      context.handle(
        _instructionsMeta,
        instructions.isAcceptableOrUnknown(
          data['instructions']!,
          _instructionsMeta,
        ),
      );
    }
    if (data.containsKey('time_limit_minutes')) {
      context.handle(
        _timeLimitMinutesMeta,
        timeLimitMinutes.isAcceptableOrUnknown(
          data['time_limit_minutes']!,
          _timeLimitMinutesMeta,
        ),
      );
    }
    if (data.containsKey('opens_at')) {
      context.handle(
        _opensAtMeta,
        opensAt.isAcceptableOrUnknown(data['opens_at']!, _opensAtMeta),
      );
    }
    if (data.containsKey('closes_at')) {
      context.handle(
        _closesAtMeta,
        closesAt.isAcceptableOrUnknown(data['closes_at']!, _closesAtMeta),
      );
    }
    if (data.containsKey('shuffle_questions')) {
      context.handle(
        _shuffleQuestionsMeta,
        shuffleQuestions.isAcceptableOrUnknown(
          data['shuffle_questions']!,
          _shuffleQuestionsMeta,
        ),
      );
    }
    if (data.containsKey('shuffle_options')) {
      context.handle(
        _shuffleOptionsMeta,
        shuffleOptions.isAcceptableOrUnknown(
          data['shuffle_options']!,
          _shuffleOptionsMeta,
        ),
      );
    }
    if (data.containsKey('show_correct_answers')) {
      context.handle(
        _showCorrectAnswersMeta,
        showCorrectAnswers.isAcceptableOrUnknown(
          data['show_correct_answers']!,
          _showCorrectAnswersMeta,
        ),
      );
    }
    if (data.containsKey('passing_percent')) {
      context.handle(
        _passingPercentMeta,
        passingPercent.isAcceptableOrUnknown(
          data['passing_percent']!,
          _passingPercentMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('published_at')) {
      context.handle(
        _publishedAtMeta,
        publishedAt.isAcceptableOrUnknown(
          data['published_at']!,
          _publishedAtMeta,
        ),
      );
    }
    if (data.containsKey('results_released_at')) {
      context.handle(
        _resultsReleasedAtMeta,
        resultsReleasedAt.isAcceptableOrUnknown(
          data['results_released_at']!,
          _resultsReleasedAtMeta,
        ),
      );
    }
    if (data.containsKey('total_points')) {
      context.handle(
        _totalPointsMeta,
        totalPoints.isAcceptableOrUnknown(
          data['total_points']!,
          _totalPointsMeta,
        ),
      );
    }
    if (data.containsKey('has_essay')) {
      context.handle(
        _hasEssayMeta,
        hasEssay.isAcceptableOrUnknown(data['has_essay']!, _hasEssayMeta),
      );
    }
    if (data.containsKey('locked_at')) {
      context.handle(
        _lockedAtMeta,
        lockedAt.isAcceptableOrUnknown(data['locked_at']!, _lockedAtMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CacheQuizze map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CacheQuizze(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      classId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}class_id'],
      )!,
      authorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      instructions: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}instructions'],
      ),
      timeLimitMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}time_limit_minutes'],
      )!,
      opensAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}opens_at'],
      ),
      closesAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}closes_at'],
      ),
      shuffleQuestions: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}shuffle_questions'],
      )!,
      shuffleOptions: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}shuffle_options'],
      )!,
      showCorrectAnswers: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}show_correct_answers'],
      )!,
      passingPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}passing_percent'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      publishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}published_at'],
      ),
      resultsReleasedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}results_released_at'],
      ),
      totalPoints: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_points'],
      )!,
      hasEssay: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_essay'],
      )!,
      lockedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}locked_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $CacheQuizzesTable createAlias(String alias) {
    return $CacheQuizzesTable(attachedDatabase, alias);
  }
}

class CacheQuizze extends DataClass implements Insertable<CacheQuizze> {
  final String id;
  final String classId;
  final String authorId;
  final String type;
  final String title;
  final String? instructions;
  final int timeLimitMinutes;
  final DateTime? opensAt;
  final DateTime? closesAt;
  final bool shuffleQuestions;
  final bool shuffleOptions;
  final bool showCorrectAnswers;
  final int? passingPercent;
  final String status;
  final DateTime? publishedAt;
  final DateTime? resultsReleasedAt;
  final int totalPoints;
  final bool hasEssay;
  final DateTime? lockedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const CacheQuizze({
    required this.id,
    required this.classId,
    required this.authorId,
    required this.type,
    required this.title,
    this.instructions,
    required this.timeLimitMinutes,
    this.opensAt,
    this.closesAt,
    required this.shuffleQuestions,
    required this.shuffleOptions,
    required this.showCorrectAnswers,
    this.passingPercent,
    required this.status,
    this.publishedAt,
    this.resultsReleasedAt,
    required this.totalPoints,
    required this.hasEssay,
    this.lockedAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['class_id'] = Variable<String>(classId);
    map['author_id'] = Variable<String>(authorId);
    map['type'] = Variable<String>(type);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || instructions != null) {
      map['instructions'] = Variable<String>(instructions);
    }
    map['time_limit_minutes'] = Variable<int>(timeLimitMinutes);
    if (!nullToAbsent || opensAt != null) {
      map['opens_at'] = Variable<DateTime>(opensAt);
    }
    if (!nullToAbsent || closesAt != null) {
      map['closes_at'] = Variable<DateTime>(closesAt);
    }
    map['shuffle_questions'] = Variable<bool>(shuffleQuestions);
    map['shuffle_options'] = Variable<bool>(shuffleOptions);
    map['show_correct_answers'] = Variable<bool>(showCorrectAnswers);
    if (!nullToAbsent || passingPercent != null) {
      map['passing_percent'] = Variable<int>(passingPercent);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || publishedAt != null) {
      map['published_at'] = Variable<DateTime>(publishedAt);
    }
    if (!nullToAbsent || resultsReleasedAt != null) {
      map['results_released_at'] = Variable<DateTime>(resultsReleasedAt);
    }
    map['total_points'] = Variable<int>(totalPoints);
    map['has_essay'] = Variable<bool>(hasEssay);
    if (!nullToAbsent || lockedAt != null) {
      map['locked_at'] = Variable<DateTime>(lockedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  CacheQuizzesCompanion toCompanion(bool nullToAbsent) {
    return CacheQuizzesCompanion(
      id: Value(id),
      classId: Value(classId),
      authorId: Value(authorId),
      type: Value(type),
      title: Value(title),
      instructions: instructions == null && nullToAbsent
          ? const Value.absent()
          : Value(instructions),
      timeLimitMinutes: Value(timeLimitMinutes),
      opensAt: opensAt == null && nullToAbsent
          ? const Value.absent()
          : Value(opensAt),
      closesAt: closesAt == null && nullToAbsent
          ? const Value.absent()
          : Value(closesAt),
      shuffleQuestions: Value(shuffleQuestions),
      shuffleOptions: Value(shuffleOptions),
      showCorrectAnswers: Value(showCorrectAnswers),
      passingPercent: passingPercent == null && nullToAbsent
          ? const Value.absent()
          : Value(passingPercent),
      status: Value(status),
      publishedAt: publishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(publishedAt),
      resultsReleasedAt: resultsReleasedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(resultsReleasedAt),
      totalPoints: Value(totalPoints),
      hasEssay: Value(hasEssay),
      lockedAt: lockedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lockedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory CacheQuizze.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CacheQuizze(
      id: serializer.fromJson<String>(json['id']),
      classId: serializer.fromJson<String>(json['classId']),
      authorId: serializer.fromJson<String>(json['authorId']),
      type: serializer.fromJson<String>(json['type']),
      title: serializer.fromJson<String>(json['title']),
      instructions: serializer.fromJson<String?>(json['instructions']),
      timeLimitMinutes: serializer.fromJson<int>(json['timeLimitMinutes']),
      opensAt: serializer.fromJson<DateTime?>(json['opensAt']),
      closesAt: serializer.fromJson<DateTime?>(json['closesAt']),
      shuffleQuestions: serializer.fromJson<bool>(json['shuffleQuestions']),
      shuffleOptions: serializer.fromJson<bool>(json['shuffleOptions']),
      showCorrectAnswers: serializer.fromJson<bool>(json['showCorrectAnswers']),
      passingPercent: serializer.fromJson<int?>(json['passingPercent']),
      status: serializer.fromJson<String>(json['status']),
      publishedAt: serializer.fromJson<DateTime?>(json['publishedAt']),
      resultsReleasedAt: serializer.fromJson<DateTime?>(
        json['resultsReleasedAt'],
      ),
      totalPoints: serializer.fromJson<int>(json['totalPoints']),
      hasEssay: serializer.fromJson<bool>(json['hasEssay']),
      lockedAt: serializer.fromJson<DateTime?>(json['lockedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'classId': serializer.toJson<String>(classId),
      'authorId': serializer.toJson<String>(authorId),
      'type': serializer.toJson<String>(type),
      'title': serializer.toJson<String>(title),
      'instructions': serializer.toJson<String?>(instructions),
      'timeLimitMinutes': serializer.toJson<int>(timeLimitMinutes),
      'opensAt': serializer.toJson<DateTime?>(opensAt),
      'closesAt': serializer.toJson<DateTime?>(closesAt),
      'shuffleQuestions': serializer.toJson<bool>(shuffleQuestions),
      'shuffleOptions': serializer.toJson<bool>(shuffleOptions),
      'showCorrectAnswers': serializer.toJson<bool>(showCorrectAnswers),
      'passingPercent': serializer.toJson<int?>(passingPercent),
      'status': serializer.toJson<String>(status),
      'publishedAt': serializer.toJson<DateTime?>(publishedAt),
      'resultsReleasedAt': serializer.toJson<DateTime?>(resultsReleasedAt),
      'totalPoints': serializer.toJson<int>(totalPoints),
      'hasEssay': serializer.toJson<bool>(hasEssay),
      'lockedAt': serializer.toJson<DateTime?>(lockedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  CacheQuizze copyWith({
    String? id,
    String? classId,
    String? authorId,
    String? type,
    String? title,
    Value<String?> instructions = const Value.absent(),
    int? timeLimitMinutes,
    Value<DateTime?> opensAt = const Value.absent(),
    Value<DateTime?> closesAt = const Value.absent(),
    bool? shuffleQuestions,
    bool? shuffleOptions,
    bool? showCorrectAnswers,
    Value<int?> passingPercent = const Value.absent(),
    String? status,
    Value<DateTime?> publishedAt = const Value.absent(),
    Value<DateTime?> resultsReleasedAt = const Value.absent(),
    int? totalPoints,
    bool? hasEssay,
    Value<DateTime?> lockedAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => CacheQuizze(
    id: id ?? this.id,
    classId: classId ?? this.classId,
    authorId: authorId ?? this.authorId,
    type: type ?? this.type,
    title: title ?? this.title,
    instructions: instructions.present ? instructions.value : this.instructions,
    timeLimitMinutes: timeLimitMinutes ?? this.timeLimitMinutes,
    opensAt: opensAt.present ? opensAt.value : this.opensAt,
    closesAt: closesAt.present ? closesAt.value : this.closesAt,
    shuffleQuestions: shuffleQuestions ?? this.shuffleQuestions,
    shuffleOptions: shuffleOptions ?? this.shuffleOptions,
    showCorrectAnswers: showCorrectAnswers ?? this.showCorrectAnswers,
    passingPercent: passingPercent.present
        ? passingPercent.value
        : this.passingPercent,
    status: status ?? this.status,
    publishedAt: publishedAt.present ? publishedAt.value : this.publishedAt,
    resultsReleasedAt: resultsReleasedAt.present
        ? resultsReleasedAt.value
        : this.resultsReleasedAt,
    totalPoints: totalPoints ?? this.totalPoints,
    hasEssay: hasEssay ?? this.hasEssay,
    lockedAt: lockedAt.present ? lockedAt.value : this.lockedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  CacheQuizze copyWithCompanion(CacheQuizzesCompanion data) {
    return CacheQuizze(
      id: data.id.present ? data.id.value : this.id,
      classId: data.classId.present ? data.classId.value : this.classId,
      authorId: data.authorId.present ? data.authorId.value : this.authorId,
      type: data.type.present ? data.type.value : this.type,
      title: data.title.present ? data.title.value : this.title,
      instructions: data.instructions.present
          ? data.instructions.value
          : this.instructions,
      timeLimitMinutes: data.timeLimitMinutes.present
          ? data.timeLimitMinutes.value
          : this.timeLimitMinutes,
      opensAt: data.opensAt.present ? data.opensAt.value : this.opensAt,
      closesAt: data.closesAt.present ? data.closesAt.value : this.closesAt,
      shuffleQuestions: data.shuffleQuestions.present
          ? data.shuffleQuestions.value
          : this.shuffleQuestions,
      shuffleOptions: data.shuffleOptions.present
          ? data.shuffleOptions.value
          : this.shuffleOptions,
      showCorrectAnswers: data.showCorrectAnswers.present
          ? data.showCorrectAnswers.value
          : this.showCorrectAnswers,
      passingPercent: data.passingPercent.present
          ? data.passingPercent.value
          : this.passingPercent,
      status: data.status.present ? data.status.value : this.status,
      publishedAt: data.publishedAt.present
          ? data.publishedAt.value
          : this.publishedAt,
      resultsReleasedAt: data.resultsReleasedAt.present
          ? data.resultsReleasedAt.value
          : this.resultsReleasedAt,
      totalPoints: data.totalPoints.present
          ? data.totalPoints.value
          : this.totalPoints,
      hasEssay: data.hasEssay.present ? data.hasEssay.value : this.hasEssay,
      lockedAt: data.lockedAt.present ? data.lockedAt.value : this.lockedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CacheQuizze(')
          ..write('id: $id, ')
          ..write('classId: $classId, ')
          ..write('authorId: $authorId, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('instructions: $instructions, ')
          ..write('timeLimitMinutes: $timeLimitMinutes, ')
          ..write('opensAt: $opensAt, ')
          ..write('closesAt: $closesAt, ')
          ..write('shuffleQuestions: $shuffleQuestions, ')
          ..write('shuffleOptions: $shuffleOptions, ')
          ..write('showCorrectAnswers: $showCorrectAnswers, ')
          ..write('passingPercent: $passingPercent, ')
          ..write('status: $status, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('resultsReleasedAt: $resultsReleasedAt, ')
          ..write('totalPoints: $totalPoints, ')
          ..write('hasEssay: $hasEssay, ')
          ..write('lockedAt: $lockedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    classId,
    authorId,
    type,
    title,
    instructions,
    timeLimitMinutes,
    opensAt,
    closesAt,
    shuffleQuestions,
    shuffleOptions,
    showCorrectAnswers,
    passingPercent,
    status,
    publishedAt,
    resultsReleasedAt,
    totalPoints,
    hasEssay,
    lockedAt,
    createdAt,
    updatedAt,
    deletedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CacheQuizze &&
          other.id == this.id &&
          other.classId == this.classId &&
          other.authorId == this.authorId &&
          other.type == this.type &&
          other.title == this.title &&
          other.instructions == this.instructions &&
          other.timeLimitMinutes == this.timeLimitMinutes &&
          other.opensAt == this.opensAt &&
          other.closesAt == this.closesAt &&
          other.shuffleQuestions == this.shuffleQuestions &&
          other.shuffleOptions == this.shuffleOptions &&
          other.showCorrectAnswers == this.showCorrectAnswers &&
          other.passingPercent == this.passingPercent &&
          other.status == this.status &&
          other.publishedAt == this.publishedAt &&
          other.resultsReleasedAt == this.resultsReleasedAt &&
          other.totalPoints == this.totalPoints &&
          other.hasEssay == this.hasEssay &&
          other.lockedAt == this.lockedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class CacheQuizzesCompanion extends UpdateCompanion<CacheQuizze> {
  final Value<String> id;
  final Value<String> classId;
  final Value<String> authorId;
  final Value<String> type;
  final Value<String> title;
  final Value<String?> instructions;
  final Value<int> timeLimitMinutes;
  final Value<DateTime?> opensAt;
  final Value<DateTime?> closesAt;
  final Value<bool> shuffleQuestions;
  final Value<bool> shuffleOptions;
  final Value<bool> showCorrectAnswers;
  final Value<int?> passingPercent;
  final Value<String> status;
  final Value<DateTime?> publishedAt;
  final Value<DateTime?> resultsReleasedAt;
  final Value<int> totalPoints;
  final Value<bool> hasEssay;
  final Value<DateTime?> lockedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const CacheQuizzesCompanion({
    this.id = const Value.absent(),
    this.classId = const Value.absent(),
    this.authorId = const Value.absent(),
    this.type = const Value.absent(),
    this.title = const Value.absent(),
    this.instructions = const Value.absent(),
    this.timeLimitMinutes = const Value.absent(),
    this.opensAt = const Value.absent(),
    this.closesAt = const Value.absent(),
    this.shuffleQuestions = const Value.absent(),
    this.shuffleOptions = const Value.absent(),
    this.showCorrectAnswers = const Value.absent(),
    this.passingPercent = const Value.absent(),
    this.status = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.resultsReleasedAt = const Value.absent(),
    this.totalPoints = const Value.absent(),
    this.hasEssay = const Value.absent(),
    this.lockedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CacheQuizzesCompanion.insert({
    required String id,
    required String classId,
    required String authorId,
    this.type = const Value.absent(),
    required String title,
    this.instructions = const Value.absent(),
    this.timeLimitMinutes = const Value.absent(),
    this.opensAt = const Value.absent(),
    this.closesAt = const Value.absent(),
    this.shuffleQuestions = const Value.absent(),
    this.shuffleOptions = const Value.absent(),
    this.showCorrectAnswers = const Value.absent(),
    this.passingPercent = const Value.absent(),
    this.status = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.resultsReleasedAt = const Value.absent(),
    this.totalPoints = const Value.absent(),
    this.hasEssay = const Value.absent(),
    this.lockedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       classId = Value(classId),
       authorId = Value(authorId),
       title = Value(title);
  static Insertable<CacheQuizze> custom({
    Expression<String>? id,
    Expression<String>? classId,
    Expression<String>? authorId,
    Expression<String>? type,
    Expression<String>? title,
    Expression<String>? instructions,
    Expression<int>? timeLimitMinutes,
    Expression<DateTime>? opensAt,
    Expression<DateTime>? closesAt,
    Expression<bool>? shuffleQuestions,
    Expression<bool>? shuffleOptions,
    Expression<bool>? showCorrectAnswers,
    Expression<int>? passingPercent,
    Expression<String>? status,
    Expression<DateTime>? publishedAt,
    Expression<DateTime>? resultsReleasedAt,
    Expression<int>? totalPoints,
    Expression<bool>? hasEssay,
    Expression<DateTime>? lockedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (classId != null) 'class_id': classId,
      if (authorId != null) 'author_id': authorId,
      if (type != null) 'type': type,
      if (title != null) 'title': title,
      if (instructions != null) 'instructions': instructions,
      if (timeLimitMinutes != null) 'time_limit_minutes': timeLimitMinutes,
      if (opensAt != null) 'opens_at': opensAt,
      if (closesAt != null) 'closes_at': closesAt,
      if (shuffleQuestions != null) 'shuffle_questions': shuffleQuestions,
      if (shuffleOptions != null) 'shuffle_options': shuffleOptions,
      if (showCorrectAnswers != null)
        'show_correct_answers': showCorrectAnswers,
      if (passingPercent != null) 'passing_percent': passingPercent,
      if (status != null) 'status': status,
      if (publishedAt != null) 'published_at': publishedAt,
      if (resultsReleasedAt != null) 'results_released_at': resultsReleasedAt,
      if (totalPoints != null) 'total_points': totalPoints,
      if (hasEssay != null) 'has_essay': hasEssay,
      if (lockedAt != null) 'locked_at': lockedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CacheQuizzesCompanion copyWith({
    Value<String>? id,
    Value<String>? classId,
    Value<String>? authorId,
    Value<String>? type,
    Value<String>? title,
    Value<String?>? instructions,
    Value<int>? timeLimitMinutes,
    Value<DateTime?>? opensAt,
    Value<DateTime?>? closesAt,
    Value<bool>? shuffleQuestions,
    Value<bool>? shuffleOptions,
    Value<bool>? showCorrectAnswers,
    Value<int?>? passingPercent,
    Value<String>? status,
    Value<DateTime?>? publishedAt,
    Value<DateTime?>? resultsReleasedAt,
    Value<int>? totalPoints,
    Value<bool>? hasEssay,
    Value<DateTime?>? lockedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return CacheQuizzesCompanion(
      id: id ?? this.id,
      classId: classId ?? this.classId,
      authorId: authorId ?? this.authorId,
      type: type ?? this.type,
      title: title ?? this.title,
      instructions: instructions ?? this.instructions,
      timeLimitMinutes: timeLimitMinutes ?? this.timeLimitMinutes,
      opensAt: opensAt ?? this.opensAt,
      closesAt: closesAt ?? this.closesAt,
      shuffleQuestions: shuffleQuestions ?? this.shuffleQuestions,
      shuffleOptions: shuffleOptions ?? this.shuffleOptions,
      showCorrectAnswers: showCorrectAnswers ?? this.showCorrectAnswers,
      passingPercent: passingPercent ?? this.passingPercent,
      status: status ?? this.status,
      publishedAt: publishedAt ?? this.publishedAt,
      resultsReleasedAt: resultsReleasedAt ?? this.resultsReleasedAt,
      totalPoints: totalPoints ?? this.totalPoints,
      hasEssay: hasEssay ?? this.hasEssay,
      lockedAt: lockedAt ?? this.lockedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
    if (classId.present) {
      map['class_id'] = Variable<String>(classId.value);
    }
    if (authorId.present) {
      map['author_id'] = Variable<String>(authorId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (instructions.present) {
      map['instructions'] = Variable<String>(instructions.value);
    }
    if (timeLimitMinutes.present) {
      map['time_limit_minutes'] = Variable<int>(timeLimitMinutes.value);
    }
    if (opensAt.present) {
      map['opens_at'] = Variable<DateTime>(opensAt.value);
    }
    if (closesAt.present) {
      map['closes_at'] = Variable<DateTime>(closesAt.value);
    }
    if (shuffleQuestions.present) {
      map['shuffle_questions'] = Variable<bool>(shuffleQuestions.value);
    }
    if (shuffleOptions.present) {
      map['shuffle_options'] = Variable<bool>(shuffleOptions.value);
    }
    if (showCorrectAnswers.present) {
      map['show_correct_answers'] = Variable<bool>(showCorrectAnswers.value);
    }
    if (passingPercent.present) {
      map['passing_percent'] = Variable<int>(passingPercent.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (publishedAt.present) {
      map['published_at'] = Variable<DateTime>(publishedAt.value);
    }
    if (resultsReleasedAt.present) {
      map['results_released_at'] = Variable<DateTime>(resultsReleasedAt.value);
    }
    if (totalPoints.present) {
      map['total_points'] = Variable<int>(totalPoints.value);
    }
    if (hasEssay.present) {
      map['has_essay'] = Variable<bool>(hasEssay.value);
    }
    if (lockedAt.present) {
      map['locked_at'] = Variable<DateTime>(lockedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CacheQuizzesCompanion(')
          ..write('id: $id, ')
          ..write('classId: $classId, ')
          ..write('authorId: $authorId, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('instructions: $instructions, ')
          ..write('timeLimitMinutes: $timeLimitMinutes, ')
          ..write('opensAt: $opensAt, ')
          ..write('closesAt: $closesAt, ')
          ..write('shuffleQuestions: $shuffleQuestions, ')
          ..write('shuffleOptions: $shuffleOptions, ')
          ..write('showCorrectAnswers: $showCorrectAnswers, ')
          ..write('passingPercent: $passingPercent, ')
          ..write('status: $status, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('resultsReleasedAt: $resultsReleasedAt, ')
          ..write('totalPoints: $totalPoints, ')
          ..write('hasEssay: $hasEssay, ')
          ..write('lockedAt: $lockedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CacheResultsTable extends CacheResults
    with TableInfo<$CacheResultsTable, CacheResult> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CacheResultsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<int> score = GeneratedColumn<int>(
    'score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalPointsMeta = const VerificationMeta(
    'totalPoints',
  );
  @override
  late final GeneratedColumn<int> totalPoints = GeneratedColumn<int>(
    'total_points',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _percentMeta = const VerificationMeta(
    'percent',
  );
  @override
  late final GeneratedColumn<int> percent = GeneratedColumn<int>(
    'percent',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _passedMeta = const VerificationMeta('passed');
  @override
  late final GeneratedColumn<bool> passed = GeneratedColumn<bool>(
    'passed',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("passed" IN (0, 1))',
    ),
  );
  static const VerificationMeta _reviewMeta = const VerificationMeta('review');
  @override
  late final GeneratedColumn<String> review = GeneratedColumn<String>(
    'review',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sessionId,
    score,
    totalPoints,
    percent,
    passed,
    review,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cache_results';
  @override
  VerificationContext validateIntegrity(
    Insertable<CacheResult> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('score')) {
      context.handle(
        _scoreMeta,
        score.isAcceptableOrUnknown(data['score']!, _scoreMeta),
      );
    } else if (isInserting) {
      context.missing(_scoreMeta);
    }
    if (data.containsKey('total_points')) {
      context.handle(
        _totalPointsMeta,
        totalPoints.isAcceptableOrUnknown(
          data['total_points']!,
          _totalPointsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalPointsMeta);
    }
    if (data.containsKey('percent')) {
      context.handle(
        _percentMeta,
        percent.isAcceptableOrUnknown(data['percent']!, _percentMeta),
      );
    } else if (isInserting) {
      context.missing(_percentMeta);
    }
    if (data.containsKey('passed')) {
      context.handle(
        _passedMeta,
        passed.isAcceptableOrUnknown(data['passed']!, _passedMeta),
      );
    }
    if (data.containsKey('review')) {
      context.handle(
        _reviewMeta,
        review.isAcceptableOrUnknown(data['review']!, _reviewMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId};
  @override
  CacheResult map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CacheResult(
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      score: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}score'],
      )!,
      totalPoints: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_points'],
      )!,
      percent: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}percent'],
      )!,
      passed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}passed'],
      ),
      review: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}review'],
      ),
    );
  }

  @override
  $CacheResultsTable createAlias(String alias) {
    return $CacheResultsTable(attachedDatabase, alias);
  }
}

class CacheResult extends DataClass implements Insertable<CacheResult> {
  final String sessionId;
  final int score;
  final int totalPoints;
  final int percent;
  final bool? passed;
  final String? review;
  const CacheResult({
    required this.sessionId,
    required this.score,
    required this.totalPoints,
    required this.percent,
    this.passed,
    this.review,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<String>(sessionId);
    map['score'] = Variable<int>(score);
    map['total_points'] = Variable<int>(totalPoints);
    map['percent'] = Variable<int>(percent);
    if (!nullToAbsent || passed != null) {
      map['passed'] = Variable<bool>(passed);
    }
    if (!nullToAbsent || review != null) {
      map['review'] = Variable<String>(review);
    }
    return map;
  }

  CacheResultsCompanion toCompanion(bool nullToAbsent) {
    return CacheResultsCompanion(
      sessionId: Value(sessionId),
      score: Value(score),
      totalPoints: Value(totalPoints),
      percent: Value(percent),
      passed: passed == null && nullToAbsent
          ? const Value.absent()
          : Value(passed),
      review: review == null && nullToAbsent
          ? const Value.absent()
          : Value(review),
    );
  }

  factory CacheResult.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CacheResult(
      sessionId: serializer.fromJson<String>(json['sessionId']),
      score: serializer.fromJson<int>(json['score']),
      totalPoints: serializer.fromJson<int>(json['totalPoints']),
      percent: serializer.fromJson<int>(json['percent']),
      passed: serializer.fromJson<bool?>(json['passed']),
      review: serializer.fromJson<String?>(json['review']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sessionId': serializer.toJson<String>(sessionId),
      'score': serializer.toJson<int>(score),
      'totalPoints': serializer.toJson<int>(totalPoints),
      'percent': serializer.toJson<int>(percent),
      'passed': serializer.toJson<bool?>(passed),
      'review': serializer.toJson<String?>(review),
    };
  }

  CacheResult copyWith({
    String? sessionId,
    int? score,
    int? totalPoints,
    int? percent,
    Value<bool?> passed = const Value.absent(),
    Value<String?> review = const Value.absent(),
  }) => CacheResult(
    sessionId: sessionId ?? this.sessionId,
    score: score ?? this.score,
    totalPoints: totalPoints ?? this.totalPoints,
    percent: percent ?? this.percent,
    passed: passed.present ? passed.value : this.passed,
    review: review.present ? review.value : this.review,
  );
  CacheResult copyWithCompanion(CacheResultsCompanion data) {
    return CacheResult(
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      score: data.score.present ? data.score.value : this.score,
      totalPoints: data.totalPoints.present
          ? data.totalPoints.value
          : this.totalPoints,
      percent: data.percent.present ? data.percent.value : this.percent,
      passed: data.passed.present ? data.passed.value : this.passed,
      review: data.review.present ? data.review.value : this.review,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CacheResult(')
          ..write('sessionId: $sessionId, ')
          ..write('score: $score, ')
          ..write('totalPoints: $totalPoints, ')
          ..write('percent: $percent, ')
          ..write('passed: $passed, ')
          ..write('review: $review')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(sessionId, score, totalPoints, percent, passed, review);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CacheResult &&
          other.sessionId == this.sessionId &&
          other.score == this.score &&
          other.totalPoints == this.totalPoints &&
          other.percent == this.percent &&
          other.passed == this.passed &&
          other.review == this.review);
}

class CacheResultsCompanion extends UpdateCompanion<CacheResult> {
  final Value<String> sessionId;
  final Value<int> score;
  final Value<int> totalPoints;
  final Value<int> percent;
  final Value<bool?> passed;
  final Value<String?> review;
  final Value<int> rowid;
  const CacheResultsCompanion({
    this.sessionId = const Value.absent(),
    this.score = const Value.absent(),
    this.totalPoints = const Value.absent(),
    this.percent = const Value.absent(),
    this.passed = const Value.absent(),
    this.review = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CacheResultsCompanion.insert({
    required String sessionId,
    required int score,
    required int totalPoints,
    required int percent,
    this.passed = const Value.absent(),
    this.review = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : sessionId = Value(sessionId),
       score = Value(score),
       totalPoints = Value(totalPoints),
       percent = Value(percent);
  static Insertable<CacheResult> custom({
    Expression<String>? sessionId,
    Expression<int>? score,
    Expression<int>? totalPoints,
    Expression<int>? percent,
    Expression<bool>? passed,
    Expression<String>? review,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (score != null) 'score': score,
      if (totalPoints != null) 'total_points': totalPoints,
      if (percent != null) 'percent': percent,
      if (passed != null) 'passed': passed,
      if (review != null) 'review': review,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CacheResultsCompanion copyWith({
    Value<String>? sessionId,
    Value<int>? score,
    Value<int>? totalPoints,
    Value<int>? percent,
    Value<bool?>? passed,
    Value<String?>? review,
    Value<int>? rowid,
  }) {
    return CacheResultsCompanion(
      sessionId: sessionId ?? this.sessionId,
      score: score ?? this.score,
      totalPoints: totalPoints ?? this.totalPoints,
      percent: percent ?? this.percent,
      passed: passed ?? this.passed,
      review: review ?? this.review,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (score.present) {
      map['score'] = Variable<int>(score.value);
    }
    if (totalPoints.present) {
      map['total_points'] = Variable<int>(totalPoints.value);
    }
    if (percent.present) {
      map['percent'] = Variable<int>(percent.value);
    }
    if (passed.present) {
      map['passed'] = Variable<bool>(passed.value);
    }
    if (review.present) {
      map['review'] = Variable<String>(review.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CacheResultsCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('score: $score, ')
          ..write('totalPoints: $totalPoints, ')
          ..write('percent: $percent, ')
          ..write('passed: $passed, ')
          ..write('review: $review, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CacheNotificationsTable extends CacheNotifications
    with TableInfo<$CacheNotificationsTable, CacheNotification> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CacheNotificationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recipientIdMeta = const VerificationMeta(
    'recipientId',
  );
  @override
  late final GeneratedColumn<String> recipientId = GeneratedColumn<String>(
    'recipient_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cache_profiles (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _classIdMeta = const VerificationMeta(
    'classId',
  );
  @override
  late final GeneratedColumn<String> classId = GeneratedColumn<String>(
    'class_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cache_classes (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetTypeMeta = const VerificationMeta(
    'targetType',
  );
  @override
  late final GeneratedColumn<String> targetType = GeneratedColumn<String>(
    'target_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetIdMeta = const VerificationMeta(
    'targetId',
  );
  @override
  late final GeneratedColumn<String> targetId = GeneratedColumn<String>(
    'target_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _readAtMeta = const VerificationMeta('readAt');
  @override
  late final GeneratedColumn<DateTime> readAt = GeneratedColumn<DateTime>(
    'read_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    recipientId,
    classId,
    type,
    title,
    body,
    targetType,
    targetId,
    readAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cache_notifications';
  @override
  VerificationContext validateIntegrity(
    Insertable<CacheNotification> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('recipient_id')) {
      context.handle(
        _recipientIdMeta,
        recipientId.isAcceptableOrUnknown(
          data['recipient_id']!,
          _recipientIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recipientIdMeta);
    }
    if (data.containsKey('class_id')) {
      context.handle(
        _classIdMeta,
        classId.isAcceptableOrUnknown(data['class_id']!, _classIdMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    }
    if (data.containsKey('target_type')) {
      context.handle(
        _targetTypeMeta,
        targetType.isAcceptableOrUnknown(data['target_type']!, _targetTypeMeta),
      );
    }
    if (data.containsKey('target_id')) {
      context.handle(
        _targetIdMeta,
        targetId.isAcceptableOrUnknown(data['target_id']!, _targetIdMeta),
      );
    }
    if (data.containsKey('read_at')) {
      context.handle(
        _readAtMeta,
        readAt.isAcceptableOrUnknown(data['read_at']!, _readAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CacheNotification map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CacheNotification(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      recipientId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipient_id'],
      )!,
      classId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}class_id'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      ),
      targetType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_type'],
      ),
      targetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_id'],
      ),
      readAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}read_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CacheNotificationsTable createAlias(String alias) {
    return $CacheNotificationsTable(attachedDatabase, alias);
  }
}

class CacheNotification extends DataClass
    implements Insertable<CacheNotification> {
  final String id;
  final String recipientId;
  final String? classId;
  final String type;
  final String title;
  final String? body;
  final String? targetType;
  final String? targetId;
  final DateTime? readAt;
  final DateTime createdAt;
  const CacheNotification({
    required this.id,
    required this.recipientId,
    this.classId,
    required this.type,
    required this.title,
    this.body,
    this.targetType,
    this.targetId,
    this.readAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['recipient_id'] = Variable<String>(recipientId);
    if (!nullToAbsent || classId != null) {
      map['class_id'] = Variable<String>(classId);
    }
    map['type'] = Variable<String>(type);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || body != null) {
      map['body'] = Variable<String>(body);
    }
    if (!nullToAbsent || targetType != null) {
      map['target_type'] = Variable<String>(targetType);
    }
    if (!nullToAbsent || targetId != null) {
      map['target_id'] = Variable<String>(targetId);
    }
    if (!nullToAbsent || readAt != null) {
      map['read_at'] = Variable<DateTime>(readAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CacheNotificationsCompanion toCompanion(bool nullToAbsent) {
    return CacheNotificationsCompanion(
      id: Value(id),
      recipientId: Value(recipientId),
      classId: classId == null && nullToAbsent
          ? const Value.absent()
          : Value(classId),
      type: Value(type),
      title: Value(title),
      body: body == null && nullToAbsent ? const Value.absent() : Value(body),
      targetType: targetType == null && nullToAbsent
          ? const Value.absent()
          : Value(targetType),
      targetId: targetId == null && nullToAbsent
          ? const Value.absent()
          : Value(targetId),
      readAt: readAt == null && nullToAbsent
          ? const Value.absent()
          : Value(readAt),
      createdAt: Value(createdAt),
    );
  }

  factory CacheNotification.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CacheNotification(
      id: serializer.fromJson<String>(json['id']),
      recipientId: serializer.fromJson<String>(json['recipientId']),
      classId: serializer.fromJson<String?>(json['classId']),
      type: serializer.fromJson<String>(json['type']),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String?>(json['body']),
      targetType: serializer.fromJson<String?>(json['targetType']),
      targetId: serializer.fromJson<String?>(json['targetId']),
      readAt: serializer.fromJson<DateTime?>(json['readAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'recipientId': serializer.toJson<String>(recipientId),
      'classId': serializer.toJson<String?>(classId),
      'type': serializer.toJson<String>(type),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String?>(body),
      'targetType': serializer.toJson<String?>(targetType),
      'targetId': serializer.toJson<String?>(targetId),
      'readAt': serializer.toJson<DateTime?>(readAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  CacheNotification copyWith({
    String? id,
    String? recipientId,
    Value<String?> classId = const Value.absent(),
    String? type,
    String? title,
    Value<String?> body = const Value.absent(),
    Value<String?> targetType = const Value.absent(),
    Value<String?> targetId = const Value.absent(),
    Value<DateTime?> readAt = const Value.absent(),
    DateTime? createdAt,
  }) => CacheNotification(
    id: id ?? this.id,
    recipientId: recipientId ?? this.recipientId,
    classId: classId.present ? classId.value : this.classId,
    type: type ?? this.type,
    title: title ?? this.title,
    body: body.present ? body.value : this.body,
    targetType: targetType.present ? targetType.value : this.targetType,
    targetId: targetId.present ? targetId.value : this.targetId,
    readAt: readAt.present ? readAt.value : this.readAt,
    createdAt: createdAt ?? this.createdAt,
  );
  CacheNotification copyWithCompanion(CacheNotificationsCompanion data) {
    return CacheNotification(
      id: data.id.present ? data.id.value : this.id,
      recipientId: data.recipientId.present
          ? data.recipientId.value
          : this.recipientId,
      classId: data.classId.present ? data.classId.value : this.classId,
      type: data.type.present ? data.type.value : this.type,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      targetType: data.targetType.present
          ? data.targetType.value
          : this.targetType,
      targetId: data.targetId.present ? data.targetId.value : this.targetId,
      readAt: data.readAt.present ? data.readAt.value : this.readAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CacheNotification(')
          ..write('id: $id, ')
          ..write('recipientId: $recipientId, ')
          ..write('classId: $classId, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('targetType: $targetType, ')
          ..write('targetId: $targetId, ')
          ..write('readAt: $readAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    recipientId,
    classId,
    type,
    title,
    body,
    targetType,
    targetId,
    readAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CacheNotification &&
          other.id == this.id &&
          other.recipientId == this.recipientId &&
          other.classId == this.classId &&
          other.type == this.type &&
          other.title == this.title &&
          other.body == this.body &&
          other.targetType == this.targetType &&
          other.targetId == this.targetId &&
          other.readAt == this.readAt &&
          other.createdAt == this.createdAt);
}

class CacheNotificationsCompanion extends UpdateCompanion<CacheNotification> {
  final Value<String> id;
  final Value<String> recipientId;
  final Value<String?> classId;
  final Value<String> type;
  final Value<String> title;
  final Value<String?> body;
  final Value<String?> targetType;
  final Value<String?> targetId;
  final Value<DateTime?> readAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const CacheNotificationsCompanion({
    this.id = const Value.absent(),
    this.recipientId = const Value.absent(),
    this.classId = const Value.absent(),
    this.type = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.targetType = const Value.absent(),
    this.targetId = const Value.absent(),
    this.readAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CacheNotificationsCompanion.insert({
    required String id,
    required String recipientId,
    this.classId = const Value.absent(),
    required String type,
    required String title,
    this.body = const Value.absent(),
    this.targetType = const Value.absent(),
    this.targetId = const Value.absent(),
    this.readAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       recipientId = Value(recipientId),
       type = Value(type),
       title = Value(title);
  static Insertable<CacheNotification> custom({
    Expression<String>? id,
    Expression<String>? recipientId,
    Expression<String>? classId,
    Expression<String>? type,
    Expression<String>? title,
    Expression<String>? body,
    Expression<String>? targetType,
    Expression<String>? targetId,
    Expression<DateTime>? readAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (recipientId != null) 'recipient_id': recipientId,
      if (classId != null) 'class_id': classId,
      if (type != null) 'type': type,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (targetType != null) 'target_type': targetType,
      if (targetId != null) 'target_id': targetId,
      if (readAt != null) 'read_at': readAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CacheNotificationsCompanion copyWith({
    Value<String>? id,
    Value<String>? recipientId,
    Value<String?>? classId,
    Value<String>? type,
    Value<String>? title,
    Value<String?>? body,
    Value<String?>? targetType,
    Value<String?>? targetId,
    Value<DateTime?>? readAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return CacheNotificationsCompanion(
      id: id ?? this.id,
      recipientId: recipientId ?? this.recipientId,
      classId: classId ?? this.classId,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (recipientId.present) {
      map['recipient_id'] = Variable<String>(recipientId.value);
    }
    if (classId.present) {
      map['class_id'] = Variable<String>(classId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (targetType.present) {
      map['target_type'] = Variable<String>(targetType.value);
    }
    if (targetId.present) {
      map['target_id'] = Variable<String>(targetId.value);
    }
    if (readAt.present) {
      map['read_at'] = Variable<DateTime>(readAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CacheNotificationsCompanion(')
          ..write('id: $id, ')
          ..write('recipientId: $recipientId, ')
          ..write('classId: $classId, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('targetType: $targetType, ')
          ..write('targetId: $targetId, ')
          ..write('readAt: $readAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncStateTable extends SyncState
    with TableInfo<$SyncStateTable, SyncStateData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _syncedTableNameMeta = const VerificationMeta(
    'syncedTableName',
  );
  @override
  late final GeneratedColumn<String> syncedTableName = GeneratedColumn<String>(
    'table_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  @override
  List<GeneratedColumn> get $columns => [syncedTableName, lastSyncedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncStateData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('table_name')) {
      context.handle(
        _syncedTableNameMeta,
        syncedTableName.isAcceptableOrUnknown(
          data['table_name']!,
          _syncedTableNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_syncedTableNameMeta);
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {syncedTableName};
  @override
  SyncStateData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateData(
      syncedTableName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}table_name'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      ),
    );
  }

  @override
  $SyncStateTable createAlias(String alias) {
    return $SyncStateTable(attachedDatabase, alias);
  }
}

class SyncStateData extends DataClass implements Insertable<SyncStateData> {
  final String syncedTableName;
  final DateTime? lastSyncedAt;
  const SyncStateData({required this.syncedTableName, this.lastSyncedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['table_name'] = Variable<String>(syncedTableName);
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    return map;
  }

  SyncStateCompanion toCompanion(bool nullToAbsent) {
    return SyncStateCompanion(
      syncedTableName: Value(syncedTableName),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
    );
  }

  factory SyncStateData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateData(
      syncedTableName: serializer.fromJson<String>(json['syncedTableName']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'syncedTableName': serializer.toJson<String>(syncedTableName),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
    };
  }

  SyncStateData copyWith({
    String? syncedTableName,
    Value<DateTime?> lastSyncedAt = const Value.absent(),
  }) => SyncStateData(
    syncedTableName: syncedTableName ?? this.syncedTableName,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
  );
  SyncStateData copyWithCompanion(SyncStateCompanion data) {
    return SyncStateData(
      syncedTableName: data.syncedTableName.present
          ? data.syncedTableName.value
          : this.syncedTableName,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateData(')
          ..write('syncedTableName: $syncedTableName, ')
          ..write('lastSyncedAt: $lastSyncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(syncedTableName, lastSyncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateData &&
          other.syncedTableName == this.syncedTableName &&
          other.lastSyncedAt == this.lastSyncedAt);
}

class SyncStateCompanion extends UpdateCompanion<SyncStateData> {
  final Value<String> syncedTableName;
  final Value<DateTime?> lastSyncedAt;
  final Value<int> rowid;
  const SyncStateCompanion({
    this.syncedTableName = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStateCompanion.insert({
    required String syncedTableName,
    this.lastSyncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : syncedTableName = Value(syncedTableName);
  static Insertable<SyncStateData> custom({
    Expression<String>? syncedTableName,
    Expression<DateTime>? lastSyncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (syncedTableName != null) 'table_name': syncedTableName,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStateCompanion copyWith({
    Value<String>? syncedTableName,
    Value<DateTime?>? lastSyncedAt,
    Value<int>? rowid,
  }) {
    return SyncStateCompanion(
      syncedTableName: syncedTableName ?? this.syncedTableName,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (syncedTableName.present) {
      map['table_name'] = Variable<String>(syncedTableName.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateCompanion(')
          ..write('syncedTableName: $syncedTableName, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionTypeMeta = const VerificationMeta(
    'actionType',
  );
  @override
  late final GeneratedColumn<String> actionType = GeneratedColumn<String>(
    'action_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
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
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    actionType,
    payload,
    createdAt,
    attempts,
    lastError,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('action_type')) {
      context.handle(
        _actionTypeMeta,
        actionType.isAcceptableOrUnknown(data['action_type']!, _actionTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_actionTypeMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
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
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      actionType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action_type'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }
}

class OutboxData extends DataClass implements Insertable<OutboxData> {
  final String id;
  final String actionType;
  final String payload;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;
  final String status;
  const OutboxData({
    required this.id,
    required this.actionType,
    required this.payload,
    required this.createdAt,
    required this.attempts,
    this.lastError,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['action_type'] = Variable<String>(actionType);
    map['payload'] = Variable<String>(payload);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['status'] = Variable<String>(status);
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      id: Value(id),
      actionType: Value(actionType),
      payload: Value(payload),
      createdAt: Value(createdAt),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      status: Value(status),
    );
  }

  factory OutboxData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxData(
      id: serializer.fromJson<String>(json['id']),
      actionType: serializer.fromJson<String>(json['actionType']),
      payload: serializer.fromJson<String>(json['payload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'actionType': serializer.toJson<String>(actionType),
      'payload': serializer.toJson<String>(payload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
      'status': serializer.toJson<String>(status),
    };
  }

  OutboxData copyWith({
    String? id,
    String? actionType,
    String? payload,
    DateTime? createdAt,
    int? attempts,
    Value<String?> lastError = const Value.absent(),
    String? status,
  }) => OutboxData(
    id: id ?? this.id,
    actionType: actionType ?? this.actionType,
    payload: payload ?? this.payload,
    createdAt: createdAt ?? this.createdAt,
    attempts: attempts ?? this.attempts,
    lastError: lastError.present ? lastError.value : this.lastError,
    status: status ?? this.status,
  );
  OutboxData copyWithCompanion(OutboxCompanion data) {
    return OutboxData(
      id: data.id.present ? data.id.value : this.id,
      actionType: data.actionType.present
          ? data.actionType.value
          : this.actionType,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxData(')
          ..write('id: $id, ')
          ..write('actionType: $actionType, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    actionType,
    payload,
    createdAt,
    attempts,
    lastError,
    status,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxData &&
          other.id == this.id &&
          other.actionType == this.actionType &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError &&
          other.status == this.status);
}

class OutboxCompanion extends UpdateCompanion<OutboxData> {
  final Value<String> id;
  final Value<String> actionType;
  final Value<String> payload;
  final Value<DateTime> createdAt;
  final Value<int> attempts;
  final Value<String?> lastError;
  final Value<String> status;
  final Value<int> rowid;
  const OutboxCompanion({
    this.id = const Value.absent(),
    this.actionType = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxCompanion.insert({
    required String id,
    required String actionType,
    required String payload,
    this.createdAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    required String status,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       actionType = Value(actionType),
       payload = Value(payload),
       status = Value(status);
  static Insertable<OutboxData> custom({
    Expression<String>? id,
    Expression<String>? actionType,
    Expression<String>? payload,
    Expression<DateTime>? createdAt,
    Expression<int>? attempts,
    Expression<String>? lastError,
    Expression<String>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (actionType != null) 'action_type': actionType,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxCompanion copyWith({
    Value<String>? id,
    Value<String>? actionType,
    Value<String>? payload,
    Value<DateTime>? createdAt,
    Value<int>? attempts,
    Value<String?>? lastError,
    Value<String>? status,
    Value<int>? rowid,
  }) {
    return OutboxCompanion(
      id: id ?? this.id,
      actionType: actionType ?? this.actionType,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (actionType.present) {
      map['action_type'] = Variable<String>(actionType.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('id: $id, ')
          ..write('actionType: $actionType, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalFoldersTable extends LocalFolders
    with TableInfo<$LocalFoldersTable, LocalFolderRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalFoldersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES local_folders (id)',
    ),
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
  static const VerificationMeta _classIdMeta = const VerificationMeta(
    'classId',
  );
  @override
  late final GeneratedColumn<String> classId = GeneratedColumn<String>(
    'class_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    parentId,
    name,
    classId,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalFolderRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('class_id')) {
      context.handle(
        _classIdMeta,
        classId.isAcceptableOrUnknown(data['class_id']!, _classIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalFolderRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalFolderRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      classId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}class_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LocalFoldersTable createAlias(String alias) {
    return $LocalFoldersTable(attachedDatabase, alias);
  }
}

class LocalFolderRecord extends DataClass
    implements Insertable<LocalFolderRecord> {
  final String id;
  final String? parentId;
  final String name;
  final String? classId;
  final DateTime createdAt;
  final DateTime updatedAt;
  const LocalFolderRecord({
    required this.id,
    this.parentId,
    required this.name,
    this.classId,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || classId != null) {
      map['class_id'] = Variable<String>(classId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalFoldersCompanion toCompanion(bool nullToAbsent) {
    return LocalFoldersCompanion(
      id: Value(id),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      name: Value(name),
      classId: classId == null && nullToAbsent
          ? const Value.absent()
          : Value(classId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalFolderRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalFolderRecord(
      id: serializer.fromJson<String>(json['id']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      name: serializer.fromJson<String>(json['name']),
      classId: serializer.fromJson<String?>(json['classId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'parentId': serializer.toJson<String?>(parentId),
      'name': serializer.toJson<String>(name),
      'classId': serializer.toJson<String?>(classId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalFolderRecord copyWith({
    String? id,
    Value<String?> parentId = const Value.absent(),
    String? name,
    Value<String?> classId = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => LocalFolderRecord(
    id: id ?? this.id,
    parentId: parentId.present ? parentId.value : this.parentId,
    name: name ?? this.name,
    classId: classId.present ? classId.value : this.classId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LocalFolderRecord copyWithCompanion(LocalFoldersCompanion data) {
    return LocalFolderRecord(
      id: data.id.present ? data.id.value : this.id,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      name: data.name.present ? data.name.value : this.name,
      classId: data.classId.present ? data.classId.value : this.classId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalFolderRecord(')
          ..write('id: $id, ')
          ..write('parentId: $parentId, ')
          ..write('name: $name, ')
          ..write('classId: $classId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, parentId, name, classId, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalFolderRecord &&
          other.id == this.id &&
          other.parentId == this.parentId &&
          other.name == this.name &&
          other.classId == this.classId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class LocalFoldersCompanion extends UpdateCompanion<LocalFolderRecord> {
  final Value<String> id;
  final Value<String?> parentId;
  final Value<String> name;
  final Value<String?> classId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalFoldersCompanion({
    this.id = const Value.absent(),
    this.parentId = const Value.absent(),
    this.name = const Value.absent(),
    this.classId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalFoldersCompanion.insert({
    required String id,
    this.parentId = const Value.absent(),
    required String name,
    this.classId = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<LocalFolderRecord> custom({
    Expression<String>? id,
    Expression<String>? parentId,
    Expression<String>? name,
    Expression<String>? classId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (parentId != null) 'parent_id': parentId,
      if (name != null) 'name': name,
      if (classId != null) 'class_id': classId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalFoldersCompanion copyWith({
    Value<String>? id,
    Value<String?>? parentId,
    Value<String>? name,
    Value<String?>? classId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalFoldersCompanion(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      name: name ?? this.name,
      classId: classId ?? this.classId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (classId.present) {
      map['class_id'] = Variable<String>(classId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalFoldersCompanion(')
          ..write('id: $id, ')
          ..write('parentId: $parentId, ')
          ..write('name: $name, ')
          ..write('classId: $classId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalFilesTable extends LocalFiles
    with TableInfo<$LocalFilesTable, LocalFileRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalFilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<String> folderId = GeneratedColumn<String>(
    'folder_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES local_folders (id)',
    ),
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
  static const VerificationMeta _relativePathMeta = const VerificationMeta(
    'relativePath',
  );
  @override
  late final GeneratedColumn<String> relativePath = GeneratedColumn<String>(
    'relative_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceAttachmentIdMeta =
      const VerificationMeta('sourceAttachmentId');
  @override
  late final GeneratedColumn<String> sourceAttachmentId =
      GeneratedColumn<String>(
        'source_attachment_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _classIdMeta = const VerificationMeta(
    'classId',
  );
  @override
  late final GeneratedColumn<String> classId = GeneratedColumn<String>(
    'class_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourcePostIdMeta = const VerificationMeta(
    'sourcePostId',
  );
  @override
  late final GeneratedColumn<String> sourcePostId = GeneratedColumn<String>(
    'source_post_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _backedUpAtMeta = const VerificationMeta(
    'backedUpAt',
  );
  @override
  late final GeneratedColumn<DateTime> backedUpAt = GeneratedColumn<DateTime>(
    'backed_up_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    folderId,
    name,
    relativePath,
    mimeType,
    size,
    source,
    sourceAttachmentId,
    classId,
    sourcePostId,
    backedUpAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_files';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalFileRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('relative_path')) {
      context.handle(
        _relativePathMeta,
        relativePath.isAcceptableOrUnknown(
          data['relative_path']!,
          _relativePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_relativePathMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('source_attachment_id')) {
      context.handle(
        _sourceAttachmentIdMeta,
        sourceAttachmentId.isAcceptableOrUnknown(
          data['source_attachment_id']!,
          _sourceAttachmentIdMeta,
        ),
      );
    }
    if (data.containsKey('class_id')) {
      context.handle(
        _classIdMeta,
        classId.isAcceptableOrUnknown(data['class_id']!, _classIdMeta),
      );
    }
    if (data.containsKey('source_post_id')) {
      context.handle(
        _sourcePostIdMeta,
        sourcePostId.isAcceptableOrUnknown(
          data['source_post_id']!,
          _sourcePostIdMeta,
        ),
      );
    }
    if (data.containsKey('backed_up_at')) {
      context.handle(
        _backedUpAtMeta,
        backedUpAt.isAcceptableOrUnknown(
          data['backed_up_at']!,
          _backedUpAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalFileRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalFileRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      relativePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relative_path'],
      )!,
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      ),
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      sourceAttachmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_attachment_id'],
      ),
      classId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}class_id'],
      ),
      sourcePostId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_post_id'],
      ),
      backedUpAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}backed_up_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LocalFilesTable createAlias(String alias) {
    return $LocalFilesTable(attachedDatabase, alias);
  }
}

class LocalFileRecord extends DataClass implements Insertable<LocalFileRecord> {
  final String id;
  final String? folderId;
  final String name;
  final String relativePath;
  final String? mimeType;
  final int size;
  final String source;
  final String? sourceAttachmentId;
  final String? classId;
  final String? sourcePostId;
  final DateTime? backedUpAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const LocalFileRecord({
    required this.id,
    this.folderId,
    required this.name,
    required this.relativePath,
    this.mimeType,
    required this.size,
    required this.source,
    this.sourceAttachmentId,
    this.classId,
    this.sourcePostId,
    this.backedUpAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || folderId != null) {
      map['folder_id'] = Variable<String>(folderId);
    }
    map['name'] = Variable<String>(name);
    map['relative_path'] = Variable<String>(relativePath);
    if (!nullToAbsent || mimeType != null) {
      map['mime_type'] = Variable<String>(mimeType);
    }
    map['size'] = Variable<int>(size);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || sourceAttachmentId != null) {
      map['source_attachment_id'] = Variable<String>(sourceAttachmentId);
    }
    if (!nullToAbsent || classId != null) {
      map['class_id'] = Variable<String>(classId);
    }
    if (!nullToAbsent || sourcePostId != null) {
      map['source_post_id'] = Variable<String>(sourcePostId);
    }
    if (!nullToAbsent || backedUpAt != null) {
      map['backed_up_at'] = Variable<DateTime>(backedUpAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalFilesCompanion toCompanion(bool nullToAbsent) {
    return LocalFilesCompanion(
      id: Value(id),
      folderId: folderId == null && nullToAbsent
          ? const Value.absent()
          : Value(folderId),
      name: Value(name),
      relativePath: Value(relativePath),
      mimeType: mimeType == null && nullToAbsent
          ? const Value.absent()
          : Value(mimeType),
      size: Value(size),
      source: Value(source),
      sourceAttachmentId: sourceAttachmentId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceAttachmentId),
      classId: classId == null && nullToAbsent
          ? const Value.absent()
          : Value(classId),
      sourcePostId: sourcePostId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourcePostId),
      backedUpAt: backedUpAt == null && nullToAbsent
          ? const Value.absent()
          : Value(backedUpAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalFileRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalFileRecord(
      id: serializer.fromJson<String>(json['id']),
      folderId: serializer.fromJson<String?>(json['folderId']),
      name: serializer.fromJson<String>(json['name']),
      relativePath: serializer.fromJson<String>(json['relativePath']),
      mimeType: serializer.fromJson<String?>(json['mimeType']),
      size: serializer.fromJson<int>(json['size']),
      source: serializer.fromJson<String>(json['source']),
      sourceAttachmentId: serializer.fromJson<String?>(
        json['sourceAttachmentId'],
      ),
      classId: serializer.fromJson<String?>(json['classId']),
      sourcePostId: serializer.fromJson<String?>(json['sourcePostId']),
      backedUpAt: serializer.fromJson<DateTime?>(json['backedUpAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'folderId': serializer.toJson<String?>(folderId),
      'name': serializer.toJson<String>(name),
      'relativePath': serializer.toJson<String>(relativePath),
      'mimeType': serializer.toJson<String?>(mimeType),
      'size': serializer.toJson<int>(size),
      'source': serializer.toJson<String>(source),
      'sourceAttachmentId': serializer.toJson<String?>(sourceAttachmentId),
      'classId': serializer.toJson<String?>(classId),
      'sourcePostId': serializer.toJson<String?>(sourcePostId),
      'backedUpAt': serializer.toJson<DateTime?>(backedUpAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalFileRecord copyWith({
    String? id,
    Value<String?> folderId = const Value.absent(),
    String? name,
    String? relativePath,
    Value<String?> mimeType = const Value.absent(),
    int? size,
    String? source,
    Value<String?> sourceAttachmentId = const Value.absent(),
    Value<String?> classId = const Value.absent(),
    Value<String?> sourcePostId = const Value.absent(),
    Value<DateTime?> backedUpAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => LocalFileRecord(
    id: id ?? this.id,
    folderId: folderId.present ? folderId.value : this.folderId,
    name: name ?? this.name,
    relativePath: relativePath ?? this.relativePath,
    mimeType: mimeType.present ? mimeType.value : this.mimeType,
    size: size ?? this.size,
    source: source ?? this.source,
    sourceAttachmentId: sourceAttachmentId.present
        ? sourceAttachmentId.value
        : this.sourceAttachmentId,
    classId: classId.present ? classId.value : this.classId,
    sourcePostId: sourcePostId.present ? sourcePostId.value : this.sourcePostId,
    backedUpAt: backedUpAt.present ? backedUpAt.value : this.backedUpAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LocalFileRecord copyWithCompanion(LocalFilesCompanion data) {
    return LocalFileRecord(
      id: data.id.present ? data.id.value : this.id,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      name: data.name.present ? data.name.value : this.name,
      relativePath: data.relativePath.present
          ? data.relativePath.value
          : this.relativePath,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      size: data.size.present ? data.size.value : this.size,
      source: data.source.present ? data.source.value : this.source,
      sourceAttachmentId: data.sourceAttachmentId.present
          ? data.sourceAttachmentId.value
          : this.sourceAttachmentId,
      classId: data.classId.present ? data.classId.value : this.classId,
      sourcePostId: data.sourcePostId.present
          ? data.sourcePostId.value
          : this.sourcePostId,
      backedUpAt: data.backedUpAt.present
          ? data.backedUpAt.value
          : this.backedUpAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalFileRecord(')
          ..write('id: $id, ')
          ..write('folderId: $folderId, ')
          ..write('name: $name, ')
          ..write('relativePath: $relativePath, ')
          ..write('mimeType: $mimeType, ')
          ..write('size: $size, ')
          ..write('source: $source, ')
          ..write('sourceAttachmentId: $sourceAttachmentId, ')
          ..write('classId: $classId, ')
          ..write('sourcePostId: $sourcePostId, ')
          ..write('backedUpAt: $backedUpAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    folderId,
    name,
    relativePath,
    mimeType,
    size,
    source,
    sourceAttachmentId,
    classId,
    sourcePostId,
    backedUpAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalFileRecord &&
          other.id == this.id &&
          other.folderId == this.folderId &&
          other.name == this.name &&
          other.relativePath == this.relativePath &&
          other.mimeType == this.mimeType &&
          other.size == this.size &&
          other.source == this.source &&
          other.sourceAttachmentId == this.sourceAttachmentId &&
          other.classId == this.classId &&
          other.sourcePostId == this.sourcePostId &&
          other.backedUpAt == this.backedUpAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class LocalFilesCompanion extends UpdateCompanion<LocalFileRecord> {
  final Value<String> id;
  final Value<String?> folderId;
  final Value<String> name;
  final Value<String> relativePath;
  final Value<String?> mimeType;
  final Value<int> size;
  final Value<String> source;
  final Value<String?> sourceAttachmentId;
  final Value<String?> classId;
  final Value<String?> sourcePostId;
  final Value<DateTime?> backedUpAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalFilesCompanion({
    this.id = const Value.absent(),
    this.folderId = const Value.absent(),
    this.name = const Value.absent(),
    this.relativePath = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.size = const Value.absent(),
    this.source = const Value.absent(),
    this.sourceAttachmentId = const Value.absent(),
    this.classId = const Value.absent(),
    this.sourcePostId = const Value.absent(),
    this.backedUpAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalFilesCompanion.insert({
    required String id,
    this.folderId = const Value.absent(),
    required String name,
    required String relativePath,
    this.mimeType = const Value.absent(),
    required int size,
    required String source,
    this.sourceAttachmentId = const Value.absent(),
    this.classId = const Value.absent(),
    this.sourcePostId = const Value.absent(),
    this.backedUpAt = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       relativePath = Value(relativePath),
       size = Value(size),
       source = Value(source),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<LocalFileRecord> custom({
    Expression<String>? id,
    Expression<String>? folderId,
    Expression<String>? name,
    Expression<String>? relativePath,
    Expression<String>? mimeType,
    Expression<int>? size,
    Expression<String>? source,
    Expression<String>? sourceAttachmentId,
    Expression<String>? classId,
    Expression<String>? sourcePostId,
    Expression<DateTime>? backedUpAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (folderId != null) 'folder_id': folderId,
      if (name != null) 'name': name,
      if (relativePath != null) 'relative_path': relativePath,
      if (mimeType != null) 'mime_type': mimeType,
      if (size != null) 'size': size,
      if (source != null) 'source': source,
      if (sourceAttachmentId != null)
        'source_attachment_id': sourceAttachmentId,
      if (classId != null) 'class_id': classId,
      if (sourcePostId != null) 'source_post_id': sourcePostId,
      if (backedUpAt != null) 'backed_up_at': backedUpAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalFilesCompanion copyWith({
    Value<String>? id,
    Value<String?>? folderId,
    Value<String>? name,
    Value<String>? relativePath,
    Value<String?>? mimeType,
    Value<int>? size,
    Value<String>? source,
    Value<String?>? sourceAttachmentId,
    Value<String?>? classId,
    Value<String?>? sourcePostId,
    Value<DateTime?>? backedUpAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalFilesCompanion(
      id: id ?? this.id,
      folderId: folderId ?? this.folderId,
      name: name ?? this.name,
      relativePath: relativePath ?? this.relativePath,
      mimeType: mimeType ?? this.mimeType,
      size: size ?? this.size,
      source: source ?? this.source,
      sourceAttachmentId: sourceAttachmentId ?? this.sourceAttachmentId,
      classId: classId ?? this.classId,
      sourcePostId: sourcePostId ?? this.sourcePostId,
      backedUpAt: backedUpAt ?? this.backedUpAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<String>(folderId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (relativePath.present) {
      map['relative_path'] = Variable<String>(relativePath.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (sourceAttachmentId.present) {
      map['source_attachment_id'] = Variable<String>(sourceAttachmentId.value);
    }
    if (classId.present) {
      map['class_id'] = Variable<String>(classId.value);
    }
    if (sourcePostId.present) {
      map['source_post_id'] = Variable<String>(sourcePostId.value);
    }
    if (backedUpAt.present) {
      map['backed_up_at'] = Variable<DateTime>(backedUpAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalFilesCompanion(')
          ..write('id: $id, ')
          ..write('folderId: $folderId, ')
          ..write('name: $name, ')
          ..write('relativePath: $relativePath, ')
          ..write('mimeType: $mimeType, ')
          ..write('size: $size, ')
          ..write('source: $source, ')
          ..write('sourceAttachmentId: $sourceAttachmentId, ')
          ..write('classId: $classId, ')
          ..write('sourcePostId: $sourcePostId, ')
          ..write('backedUpAt: $backedUpAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CacheProfilesTable cacheProfiles = $CacheProfilesTable(this);
  late final $CacheClassesTable cacheClasses = $CacheClassesTable(this);
  late final $CacheClassMembersTable cacheClassMembers =
      $CacheClassMembersTable(this);
  late final $CachePostsTable cachePosts = $CachePostsTable(this);
  late final $CachePostAttachmentsTable cachePostAttachments =
      $CachePostAttachmentsTable(this);
  late final $CacheSubmissionsTable cacheSubmissions = $CacheSubmissionsTable(
    this,
  );
  late final $CacheSubmissionItemsTable cacheSubmissionItems =
      $CacheSubmissionItemsTable(this);
  late final $CacheGradesTable cacheGrades = $CacheGradesTable(this);
  late final $CacheQuizzesTable cacheQuizzes = $CacheQuizzesTable(this);
  late final $CacheResultsTable cacheResults = $CacheResultsTable(this);
  late final $CacheNotificationsTable cacheNotifications =
      $CacheNotificationsTable(this);
  late final $SyncStateTable syncState = $SyncStateTable(this);
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $LocalFoldersTable localFolders = $LocalFoldersTable(this);
  late final $LocalFilesTable localFiles = $LocalFilesTable(this);
  late final Index cacheIdxClassesOwner = Index(
    'cache_idx_classes_owner',
    'CREATE INDEX cache_idx_classes_owner ON cache_classes (owner_id) WHERE deleted_at IS NULL',
  );
  late final Index cacheIdxMembersStudent = Index(
    'cache_idx_members_student',
    'CREATE INDEX cache_idx_members_student ON cache_class_members (student_id, status)',
  );
  late final Index cacheIdxMembersClass = Index(
    'cache_idx_members_class',
    'CREATE INDEX cache_idx_members_class ON cache_class_members (class_id, status)',
  );
  late final Index cacheIdxPostsClass = Index(
    'cache_idx_posts_class',
    'CREATE INDEX cache_idx_posts_class ON cache_posts (class_id, created_at DESC)',
  );
  late final Index cacheIdxPostsDue = Index(
    'cache_idx_posts_due',
    'CREATE INDEX cache_idx_posts_due ON cache_posts (class_id, due_at) WHERE kind = \'assignment\'',
  );
  late final Index cacheIdxAttachmentsPost = Index(
    'cache_idx_attachments_post',
    'CREATE INDEX cache_idx_attachments_post ON cache_post_attachments (post_id)',
  );
  late final Index cacheIdxSubmissionsPost = Index(
    'cache_idx_submissions_post',
    'CREATE INDEX cache_idx_submissions_post ON cache_submissions (post_id, status)',
  );
  late final Index cacheIdxSubmissionsStudent = Index(
    'cache_idx_submissions_student',
    'CREATE INDEX cache_idx_submissions_student ON cache_submissions (student_id)',
  );
  late final Index cacheIdxItemsSubmission = Index(
    'cache_idx_items_submission',
    'CREATE INDEX cache_idx_items_submission ON cache_submission_items (submission_id)',
  );
  late final Index cacheIdxQuizzesClass = Index(
    'cache_idx_quizzes_class',
    'CREATE INDEX cache_idx_quizzes_class ON cache_quizzes (class_id, status)',
  );
  late final Index cacheIdxNotificationsInbox = Index(
    'cache_idx_notifications_inbox',
    'CREATE INDEX cache_idx_notifications_inbox ON cache_notifications (recipient_id, created_at DESC)',
  );
  late final Index cacheIdxNotificationsUnread = Index(
    'cache_idx_notifications_unread',
    'CREATE INDEX cache_idx_notifications_unread ON cache_notifications (recipient_id) WHERE read_at IS NULL',
  );
  late final Index localFoldersParentName = Index(
    'local_folders_parent_name',
    'CREATE INDEX local_folders_parent_name ON local_folders (parent_id, name COLLATE NOCASE)',
  );
  late final Index localFoldersName = Index(
    'local_folders_name',
    'CREATE INDEX local_folders_name ON local_folders (name COLLATE NOCASE)',
  );
  late final Index localFoldersClass = Index(
    'local_folders_class',
    'CREATE UNIQUE INDEX local_folders_class ON local_folders (class_id) WHERE class_id IS NOT NULL',
  );
  late final Index localFilesFolderName = Index(
    'local_files_folder_name',
    'CREATE INDEX local_files_folder_name ON local_files (folder_id, name COLLATE NOCASE)',
  );
  late final Index localFilesName = Index(
    'local_files_name',
    'CREATE INDEX local_files_name ON local_files (name COLLATE NOCASE)',
  );
  late final Index localFilesAttachment = Index(
    'local_files_attachment',
    'CREATE UNIQUE INDEX local_files_attachment ON local_files (source_attachment_id) WHERE source_attachment_id IS NOT NULL',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cacheProfiles,
    cacheClasses,
    cacheClassMembers,
    cachePosts,
    cachePostAttachments,
    cacheSubmissions,
    cacheSubmissionItems,
    cacheGrades,
    cacheQuizzes,
    cacheResults,
    cacheNotifications,
    syncState,
    outbox,
    localFolders,
    localFiles,
    cacheIdxClassesOwner,
    cacheIdxMembersStudent,
    cacheIdxMembersClass,
    cacheIdxPostsClass,
    cacheIdxPostsDue,
    cacheIdxAttachmentsPost,
    cacheIdxSubmissionsPost,
    cacheIdxSubmissionsStudent,
    cacheIdxItemsSubmission,
    cacheIdxQuizzesClass,
    cacheIdxNotificationsInbox,
    cacheIdxNotificationsUnread,
    localFoldersParentName,
    localFoldersName,
    localFoldersClass,
    localFilesFolderName,
    localFilesName,
    localFilesAttachment,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'cache_classes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('cache_class_members', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'cache_classes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('cache_posts', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'cache_posts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('cache_post_attachments', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'cache_posts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('cache_submissions', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'cache_submissions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('cache_submission_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'cache_submissions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('cache_grades', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'cache_classes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('cache_quizzes', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'cache_profiles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('cache_notifications', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'cache_classes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('cache_notifications', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$CacheProfilesTableCreateCompanionBuilder =
    CacheProfilesCompanion Function({
      required String id,
      required String role,
      required String displayName,
      Value<String?> email,
      Value<String?> school,
      Value<String?> googlePhotoUrl,
      Value<String?> avatarPath,
      Value<DateTime?> privacyAcceptedAt,
      Value<String?> privacyVersion,
      Value<DateTime?> deletedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$CacheProfilesTableUpdateCompanionBuilder =
    CacheProfilesCompanion Function({
      Value<String> id,
      Value<String> role,
      Value<String> displayName,
      Value<String?> email,
      Value<String?> school,
      Value<String?> googlePhotoUrl,
      Value<String?> avatarPath,
      Value<DateTime?> privacyAcceptedAt,
      Value<String?> privacyVersion,
      Value<DateTime?> deletedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$CacheProfilesTableReferences
    extends BaseReferences<_$AppDatabase, $CacheProfilesTable, CacheProfile> {
  $$CacheProfilesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$CacheClassesTable, List<CacheClassesData>>
  _cacheClassesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.cacheClasses,
    aliasName: 'cache_profiles__id__cache_classes__owner_id',
  );

  $$CacheClassesTableProcessedTableManager get cacheClassesRefs {
    final manager = $$CacheClassesTableTableManager(
      $_db,
      $_db.cacheClasses,
    ).filter((f) => f.ownerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_cacheClassesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CacheClassMembersTable, List<CacheClassMember>>
  _studentMembershipsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.cacheClassMembers,
    aliasName: 'cache_profiles__id__cache_class_members__student_id',
  );

  $$CacheClassMembersTableProcessedTableManager get studentMemberships {
    final manager = $$CacheClassMembersTableTableManager(
      $_db,
      $_db.cacheClassMembers,
    ).filter((f) => f.studentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_studentMembershipsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CacheClassMembersTable, List<CacheClassMember>>
  _decidedMembershipsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.cacheClassMembers,
    aliasName: 'cache_profiles__id__cache_class_members__decided_by',
  );

  $$CacheClassMembersTableProcessedTableManager get decidedMemberships {
    final manager = $$CacheClassMembersTableTableManager(
      $_db,
      $_db.cacheClassMembers,
    ).filter((f) => f.decidedBy.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_decidedMembershipsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CachePostsTable, List<CachePost>>
  _cachePostsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.cachePosts,
    aliasName: 'cache_profiles__id__cache_posts__author_id',
  );

  $$CachePostsTableProcessedTableManager get cachePostsRefs {
    final manager = $$CachePostsTableTableManager(
      $_db,
      $_db.cachePosts,
    ).filter((f) => f.authorId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_cachePostsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CacheSubmissionsTable, List<CacheSubmission>>
  _cacheSubmissionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.cacheSubmissions,
    aliasName: 'cache_profiles__id__cache_submissions__student_id',
  );

  $$CacheSubmissionsTableProcessedTableManager get cacheSubmissionsRefs {
    final manager = $$CacheSubmissionsTableTableManager(
      $_db,
      $_db.cacheSubmissions,
    ).filter((f) => f.studentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _cacheSubmissionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CacheGradesTable, List<CacheGrade>>
  _cacheGradesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.cacheGrades,
    aliasName: 'cache_profiles__id__cache_grades__graded_by',
  );

  $$CacheGradesTableProcessedTableManager get cacheGradesRefs {
    final manager = $$CacheGradesTableTableManager(
      $_db,
      $_db.cacheGrades,
    ).filter((f) => f.gradedBy.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_cacheGradesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CacheQuizzesTable, List<CacheQuizze>>
  _cacheQuizzesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.cacheQuizzes,
    aliasName: 'cache_profiles__id__cache_quizzes__author_id',
  );

  $$CacheQuizzesTableProcessedTableManager get cacheQuizzesRefs {
    final manager = $$CacheQuizzesTableTableManager(
      $_db,
      $_db.cacheQuizzes,
    ).filter((f) => f.authorId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_cacheQuizzesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CacheNotificationsTable, List<CacheNotification>>
  _cacheNotificationsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.cacheNotifications,
        aliasName: 'cache_profiles__id__cache_notifications__recipient_id',
      );

  $$CacheNotificationsTableProcessedTableManager get cacheNotificationsRefs {
    final manager = $$CacheNotificationsTableTableManager(
      $_db,
      $_db.cacheNotifications,
    ).filter((f) => f.recipientId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _cacheNotificationsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CacheProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $CacheProfilesTable> {
  $$CacheProfilesTableFilterComposer({
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

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get school => $composableBuilder(
    column: $table.school,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get googlePhotoUrl => $composableBuilder(
    column: $table.googlePhotoUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avatarPath => $composableBuilder(
    column: $table.avatarPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get privacyAcceptedAt => $composableBuilder(
    column: $table.privacyAcceptedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get privacyVersion => $composableBuilder(
    column: $table.privacyVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
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

  Expression<bool> cacheClassesRefs(
    Expression<bool> Function($$CacheClassesTableFilterComposer f) f,
  ) {
    final $$CacheClassesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cacheClasses,
      getReferencedColumn: (t) => t.ownerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheClassesTableFilterComposer(
            $db: $db,
            $table: $db.cacheClasses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> studentMemberships(
    Expression<bool> Function($$CacheClassMembersTableFilterComposer f) f,
  ) {
    final $$CacheClassMembersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cacheClassMembers,
      getReferencedColumn: (t) => t.studentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheClassMembersTableFilterComposer(
            $db: $db,
            $table: $db.cacheClassMembers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> decidedMemberships(
    Expression<bool> Function($$CacheClassMembersTableFilterComposer f) f,
  ) {
    final $$CacheClassMembersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cacheClassMembers,
      getReferencedColumn: (t) => t.decidedBy,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheClassMembersTableFilterComposer(
            $db: $db,
            $table: $db.cacheClassMembers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> cachePostsRefs(
    Expression<bool> Function($$CachePostsTableFilterComposer f) f,
  ) {
    final $$CachePostsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cachePosts,
      getReferencedColumn: (t) => t.authorId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CachePostsTableFilterComposer(
            $db: $db,
            $table: $db.cachePosts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> cacheSubmissionsRefs(
    Expression<bool> Function($$CacheSubmissionsTableFilterComposer f) f,
  ) {
    final $$CacheSubmissionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cacheSubmissions,
      getReferencedColumn: (t) => t.studentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheSubmissionsTableFilterComposer(
            $db: $db,
            $table: $db.cacheSubmissions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> cacheGradesRefs(
    Expression<bool> Function($$CacheGradesTableFilterComposer f) f,
  ) {
    final $$CacheGradesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cacheGrades,
      getReferencedColumn: (t) => t.gradedBy,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheGradesTableFilterComposer(
            $db: $db,
            $table: $db.cacheGrades,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> cacheQuizzesRefs(
    Expression<bool> Function($$CacheQuizzesTableFilterComposer f) f,
  ) {
    final $$CacheQuizzesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cacheQuizzes,
      getReferencedColumn: (t) => t.authorId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheQuizzesTableFilterComposer(
            $db: $db,
            $table: $db.cacheQuizzes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> cacheNotificationsRefs(
    Expression<bool> Function($$CacheNotificationsTableFilterComposer f) f,
  ) {
    final $$CacheNotificationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cacheNotifications,
      getReferencedColumn: (t) => t.recipientId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheNotificationsTableFilterComposer(
            $db: $db,
            $table: $db.cacheNotifications,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CacheProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $CacheProfilesTable> {
  $$CacheProfilesTableOrderingComposer({
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

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get school => $composableBuilder(
    column: $table.school,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get googlePhotoUrl => $composableBuilder(
    column: $table.googlePhotoUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avatarPath => $composableBuilder(
    column: $table.avatarPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get privacyAcceptedAt => $composableBuilder(
    column: $table.privacyAcceptedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get privacyVersion => $composableBuilder(
    column: $table.privacyVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
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
}

class $$CacheProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CacheProfilesTable> {
  $$CacheProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get school =>
      $composableBuilder(column: $table.school, builder: (column) => column);

  GeneratedColumn<String> get googlePhotoUrl => $composableBuilder(
    column: $table.googlePhotoUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get avatarPath => $composableBuilder(
    column: $table.avatarPath,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get privacyAcceptedAt => $composableBuilder(
    column: $table.privacyAcceptedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get privacyVersion => $composableBuilder(
    column: $table.privacyVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> cacheClassesRefs<T extends Object>(
    Expression<T> Function($$CacheClassesTableAnnotationComposer a) f,
  ) {
    final $$CacheClassesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cacheClasses,
      getReferencedColumn: (t) => t.ownerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheClassesTableAnnotationComposer(
            $db: $db,
            $table: $db.cacheClasses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> studentMemberships<T extends Object>(
    Expression<T> Function($$CacheClassMembersTableAnnotationComposer a) f,
  ) {
    final $$CacheClassMembersTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.cacheClassMembers,
          getReferencedColumn: (t) => t.studentId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CacheClassMembersTableAnnotationComposer(
                $db: $db,
                $table: $db.cacheClassMembers,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> decidedMemberships<T extends Object>(
    Expression<T> Function($$CacheClassMembersTableAnnotationComposer a) f,
  ) {
    final $$CacheClassMembersTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.cacheClassMembers,
          getReferencedColumn: (t) => t.decidedBy,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CacheClassMembersTableAnnotationComposer(
                $db: $db,
                $table: $db.cacheClassMembers,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> cachePostsRefs<T extends Object>(
    Expression<T> Function($$CachePostsTableAnnotationComposer a) f,
  ) {
    final $$CachePostsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cachePosts,
      getReferencedColumn: (t) => t.authorId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CachePostsTableAnnotationComposer(
            $db: $db,
            $table: $db.cachePosts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> cacheSubmissionsRefs<T extends Object>(
    Expression<T> Function($$CacheSubmissionsTableAnnotationComposer a) f,
  ) {
    final $$CacheSubmissionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cacheSubmissions,
      getReferencedColumn: (t) => t.studentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheSubmissionsTableAnnotationComposer(
            $db: $db,
            $table: $db.cacheSubmissions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> cacheGradesRefs<T extends Object>(
    Expression<T> Function($$CacheGradesTableAnnotationComposer a) f,
  ) {
    final $$CacheGradesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cacheGrades,
      getReferencedColumn: (t) => t.gradedBy,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheGradesTableAnnotationComposer(
            $db: $db,
            $table: $db.cacheGrades,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> cacheQuizzesRefs<T extends Object>(
    Expression<T> Function($$CacheQuizzesTableAnnotationComposer a) f,
  ) {
    final $$CacheQuizzesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cacheQuizzes,
      getReferencedColumn: (t) => t.authorId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheQuizzesTableAnnotationComposer(
            $db: $db,
            $table: $db.cacheQuizzes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> cacheNotificationsRefs<T extends Object>(
    Expression<T> Function($$CacheNotificationsTableAnnotationComposer a) f,
  ) {
    final $$CacheNotificationsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.cacheNotifications,
          getReferencedColumn: (t) => t.recipientId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CacheNotificationsTableAnnotationComposer(
                $db: $db,
                $table: $db.cacheNotifications,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$CacheProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CacheProfilesTable,
          CacheProfile,
          $$CacheProfilesTableFilterComposer,
          $$CacheProfilesTableOrderingComposer,
          $$CacheProfilesTableAnnotationComposer,
          $$CacheProfilesTableCreateCompanionBuilder,
          $$CacheProfilesTableUpdateCompanionBuilder,
          (CacheProfile, $$CacheProfilesTableReferences),
          CacheProfile,
          PrefetchHooks Function({
            bool cacheClassesRefs,
            bool studentMemberships,
            bool decidedMemberships,
            bool cachePostsRefs,
            bool cacheSubmissionsRefs,
            bool cacheGradesRefs,
            bool cacheQuizzesRefs,
            bool cacheNotificationsRefs,
          })
        > {
  $$CacheProfilesTableTableManager(_$AppDatabase db, $CacheProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CacheProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CacheProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CacheProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> school = const Value.absent(),
                Value<String?> googlePhotoUrl = const Value.absent(),
                Value<String?> avatarPath = const Value.absent(),
                Value<DateTime?> privacyAcceptedAt = const Value.absent(),
                Value<String?> privacyVersion = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CacheProfilesCompanion(
                id: id,
                role: role,
                displayName: displayName,
                email: email,
                school: school,
                googlePhotoUrl: googlePhotoUrl,
                avatarPath: avatarPath,
                privacyAcceptedAt: privacyAcceptedAt,
                privacyVersion: privacyVersion,
                deletedAt: deletedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String role,
                required String displayName,
                Value<String?> email = const Value.absent(),
                Value<String?> school = const Value.absent(),
                Value<String?> googlePhotoUrl = const Value.absent(),
                Value<String?> avatarPath = const Value.absent(),
                Value<DateTime?> privacyAcceptedAt = const Value.absent(),
                Value<String?> privacyVersion = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CacheProfilesCompanion.insert(
                id: id,
                role: role,
                displayName: displayName,
                email: email,
                school: school,
                googlePhotoUrl: googlePhotoUrl,
                avatarPath: avatarPath,
                privacyAcceptedAt: privacyAcceptedAt,
                privacyVersion: privacyVersion,
                deletedAt: deletedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CacheProfilesTable, CacheProfile>(table),
                  $$CacheProfilesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                cacheClassesRefs = false,
                studentMemberships = false,
                decidedMemberships = false,
                cachePostsRefs = false,
                cacheSubmissionsRefs = false,
                cacheGradesRefs = false,
                cacheQuizzesRefs = false,
                cacheNotificationsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (cacheClassesRefs) db.cacheClasses,
                    if (studentMemberships) db.cacheClassMembers,
                    if (decidedMemberships) db.cacheClassMembers,
                    if (cachePostsRefs) db.cachePosts,
                    if (cacheSubmissionsRefs) db.cacheSubmissions,
                    if (cacheGradesRefs) db.cacheGrades,
                    if (cacheQuizzesRefs) db.cacheQuizzes,
                    if (cacheNotificationsRefs) db.cacheNotifications,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (cacheClassesRefs)
                        await $_getPrefetchedData<
                          CacheProfile,
                          $CacheProfilesTable,
                          CacheClassesData
                        >(
                          currentTable: table,
                          referencedTable: $$CacheProfilesTableReferences
                              ._cacheClassesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CacheProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).cacheClassesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.ownerId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (studentMemberships)
                        await $_getPrefetchedData<
                          CacheProfile,
                          $CacheProfilesTable,
                          CacheClassMember
                        >(
                          currentTable: table,
                          referencedTable: $$CacheProfilesTableReferences
                              ._studentMembershipsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CacheProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).studentMemberships,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.studentId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (decidedMemberships)
                        await $_getPrefetchedData<
                          CacheProfile,
                          $CacheProfilesTable,
                          CacheClassMember
                        >(
                          currentTable: table,
                          referencedTable: $$CacheProfilesTableReferences
                              ._decidedMembershipsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CacheProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).decidedMemberships,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.decidedBy == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (cachePostsRefs)
                        await $_getPrefetchedData<
                          CacheProfile,
                          $CacheProfilesTable,
                          CachePost
                        >(
                          currentTable: table,
                          referencedTable: $$CacheProfilesTableReferences
                              ._cachePostsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CacheProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).cachePostsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.authorId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (cacheSubmissionsRefs)
                        await $_getPrefetchedData<
                          CacheProfile,
                          $CacheProfilesTable,
                          CacheSubmission
                        >(
                          currentTable: table,
                          referencedTable: $$CacheProfilesTableReferences
                              ._cacheSubmissionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CacheProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).cacheSubmissionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.studentId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (cacheGradesRefs)
                        await $_getPrefetchedData<
                          CacheProfile,
                          $CacheProfilesTable,
                          CacheGrade
                        >(
                          currentTable: table,
                          referencedTable: $$CacheProfilesTableReferences
                              ._cacheGradesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CacheProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).cacheGradesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.gradedBy == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (cacheQuizzesRefs)
                        await $_getPrefetchedData<
                          CacheProfile,
                          $CacheProfilesTable,
                          CacheQuizze
                        >(
                          currentTable: table,
                          referencedTable: $$CacheProfilesTableReferences
                              ._cacheQuizzesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CacheProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).cacheQuizzesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.authorId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (cacheNotificationsRefs)
                        await $_getPrefetchedData<
                          CacheProfile,
                          $CacheProfilesTable,
                          CacheNotification
                        >(
                          currentTable: table,
                          referencedTable: $$CacheProfilesTableReferences
                              ._cacheNotificationsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CacheProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).cacheNotificationsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.recipientId == item.id,
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

typedef $$CacheProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CacheProfilesTable,
      CacheProfile,
      $$CacheProfilesTableFilterComposer,
      $$CacheProfilesTableOrderingComposer,
      $$CacheProfilesTableAnnotationComposer,
      $$CacheProfilesTableCreateCompanionBuilder,
      $$CacheProfilesTableUpdateCompanionBuilder,
      (CacheProfile, $$CacheProfilesTableReferences),
      CacheProfile,
      PrefetchHooks Function({
        bool cacheClassesRefs,
        bool studentMemberships,
        bool decidedMemberships,
        bool cachePostsRefs,
        bool cacheSubmissionsRefs,
        bool cacheGradesRefs,
        bool cacheQuizzesRefs,
        bool cacheNotificationsRefs,
      })
    >;
typedef $$CacheClassesTableCreateCompanionBuilder =
    CacheClassesCompanion Function({
      required String id,
      required String ownerId,
      required String course,
      required String section,
      required String schoolYear,
      required String joinCode,
      Value<String?> bannerColor,
      Value<String?> bannerPath,
      Value<DateTime?> archivedAt,
      Value<DateTime?> deletedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$CacheClassesTableUpdateCompanionBuilder =
    CacheClassesCompanion Function({
      Value<String> id,
      Value<String> ownerId,
      Value<String> course,
      Value<String> section,
      Value<String> schoolYear,
      Value<String> joinCode,
      Value<String?> bannerColor,
      Value<String?> bannerPath,
      Value<DateTime?> archivedAt,
      Value<DateTime?> deletedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$CacheClassesTableReferences
    extends
        BaseReferences<_$AppDatabase, $CacheClassesTable, CacheClassesData> {
  $$CacheClassesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CacheProfilesTable _ownerIdTable(_$AppDatabase db) => db.cacheProfiles
      .createAlias('cache_classes__owner_id__cache_profiles__id');

  $$CacheProfilesTableProcessedTableManager get ownerId {
    final $_column = $_itemColumn<String>('owner_id')!;

    final manager = $$CacheProfilesTableTableManager(
      $_db,
      $_db.cacheProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_ownerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$CacheClassMembersTable, List<CacheClassMember>>
  _cacheClassMembersRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.cacheClassMembers,
        aliasName: 'cache_classes__id__cache_class_members__class_id',
      );

  $$CacheClassMembersTableProcessedTableManager get cacheClassMembersRefs {
    final manager = $$CacheClassMembersTableTableManager(
      $_db,
      $_db.cacheClassMembers,
    ).filter((f) => f.classId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _cacheClassMembersRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CachePostsTable, List<CachePost>>
  _cachePostsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.cachePosts,
    aliasName: 'cache_classes__id__cache_posts__class_id',
  );

  $$CachePostsTableProcessedTableManager get cachePostsRefs {
    final manager = $$CachePostsTableTableManager(
      $_db,
      $_db.cachePosts,
    ).filter((f) => f.classId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_cachePostsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CacheQuizzesTable, List<CacheQuizze>>
  _cacheQuizzesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.cacheQuizzes,
    aliasName: 'cache_classes__id__cache_quizzes__class_id',
  );

  $$CacheQuizzesTableProcessedTableManager get cacheQuizzesRefs {
    final manager = $$CacheQuizzesTableTableManager(
      $_db,
      $_db.cacheQuizzes,
    ).filter((f) => f.classId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_cacheQuizzesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CacheNotificationsTable, List<CacheNotification>>
  _cacheNotificationsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.cacheNotifications,
        aliasName: 'cache_classes__id__cache_notifications__class_id',
      );

  $$CacheNotificationsTableProcessedTableManager get cacheNotificationsRefs {
    final manager = $$CacheNotificationsTableTableManager(
      $_db,
      $_db.cacheNotifications,
    ).filter((f) => f.classId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _cacheNotificationsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CacheClassesTableFilterComposer
    extends Composer<_$AppDatabase, $CacheClassesTable> {
  $$CacheClassesTableFilterComposer({
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

  ColumnFilters<String> get course => $composableBuilder(
    column: $table.course,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get section => $composableBuilder(
    column: $table.section,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get schoolYear => $composableBuilder(
    column: $table.schoolYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get joinCode => $composableBuilder(
    column: $table.joinCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bannerColor => $composableBuilder(
    column: $table.bannerColor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bannerPath => $composableBuilder(
    column: $table.bannerPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
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

  $$CacheProfilesTableFilterComposer get ownerId {
    final $$CacheProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ownerId,
      referencedTable: $db.cacheProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheProfilesTableFilterComposer(
            $db: $db,
            $table: $db.cacheProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> cacheClassMembersRefs(
    Expression<bool> Function($$CacheClassMembersTableFilterComposer f) f,
  ) {
    final $$CacheClassMembersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cacheClassMembers,
      getReferencedColumn: (t) => t.classId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheClassMembersTableFilterComposer(
            $db: $db,
            $table: $db.cacheClassMembers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> cachePostsRefs(
    Expression<bool> Function($$CachePostsTableFilterComposer f) f,
  ) {
    final $$CachePostsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cachePosts,
      getReferencedColumn: (t) => t.classId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CachePostsTableFilterComposer(
            $db: $db,
            $table: $db.cachePosts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> cacheQuizzesRefs(
    Expression<bool> Function($$CacheQuizzesTableFilterComposer f) f,
  ) {
    final $$CacheQuizzesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cacheQuizzes,
      getReferencedColumn: (t) => t.classId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheQuizzesTableFilterComposer(
            $db: $db,
            $table: $db.cacheQuizzes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> cacheNotificationsRefs(
    Expression<bool> Function($$CacheNotificationsTableFilterComposer f) f,
  ) {
    final $$CacheNotificationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cacheNotifications,
      getReferencedColumn: (t) => t.classId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheNotificationsTableFilterComposer(
            $db: $db,
            $table: $db.cacheNotifications,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CacheClassesTableOrderingComposer
    extends Composer<_$AppDatabase, $CacheClassesTable> {
  $$CacheClassesTableOrderingComposer({
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

  ColumnOrderings<String> get course => $composableBuilder(
    column: $table.course,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get section => $composableBuilder(
    column: $table.section,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get schoolYear => $composableBuilder(
    column: $table.schoolYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get joinCode => $composableBuilder(
    column: $table.joinCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bannerColor => $composableBuilder(
    column: $table.bannerColor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bannerPath => $composableBuilder(
    column: $table.bannerPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
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

  $$CacheProfilesTableOrderingComposer get ownerId {
    final $$CacheProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ownerId,
      referencedTable: $db.cacheProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.cacheProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CacheClassesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CacheClassesTable> {
  $$CacheClassesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get course =>
      $composableBuilder(column: $table.course, builder: (column) => column);

  GeneratedColumn<String> get section =>
      $composableBuilder(column: $table.section, builder: (column) => column);

  GeneratedColumn<String> get schoolYear => $composableBuilder(
    column: $table.schoolYear,
    builder: (column) => column,
  );

  GeneratedColumn<String> get joinCode =>
      $composableBuilder(column: $table.joinCode, builder: (column) => column);

  GeneratedColumn<String> get bannerColor => $composableBuilder(
    column: $table.bannerColor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bannerPath => $composableBuilder(
    column: $table.bannerPath,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$CacheProfilesTableAnnotationComposer get ownerId {
    final $$CacheProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ownerId,
      referencedTable: $db.cacheProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.cacheProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> cacheClassMembersRefs<T extends Object>(
    Expression<T> Function($$CacheClassMembersTableAnnotationComposer a) f,
  ) {
    final $$CacheClassMembersTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.cacheClassMembers,
          getReferencedColumn: (t) => t.classId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CacheClassMembersTableAnnotationComposer(
                $db: $db,
                $table: $db.cacheClassMembers,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> cachePostsRefs<T extends Object>(
    Expression<T> Function($$CachePostsTableAnnotationComposer a) f,
  ) {
    final $$CachePostsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cachePosts,
      getReferencedColumn: (t) => t.classId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CachePostsTableAnnotationComposer(
            $db: $db,
            $table: $db.cachePosts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> cacheQuizzesRefs<T extends Object>(
    Expression<T> Function($$CacheQuizzesTableAnnotationComposer a) f,
  ) {
    final $$CacheQuizzesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cacheQuizzes,
      getReferencedColumn: (t) => t.classId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheQuizzesTableAnnotationComposer(
            $db: $db,
            $table: $db.cacheQuizzes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> cacheNotificationsRefs<T extends Object>(
    Expression<T> Function($$CacheNotificationsTableAnnotationComposer a) f,
  ) {
    final $$CacheNotificationsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.cacheNotifications,
          getReferencedColumn: (t) => t.classId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CacheNotificationsTableAnnotationComposer(
                $db: $db,
                $table: $db.cacheNotifications,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$CacheClassesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CacheClassesTable,
          CacheClassesData,
          $$CacheClassesTableFilterComposer,
          $$CacheClassesTableOrderingComposer,
          $$CacheClassesTableAnnotationComposer,
          $$CacheClassesTableCreateCompanionBuilder,
          $$CacheClassesTableUpdateCompanionBuilder,
          (CacheClassesData, $$CacheClassesTableReferences),
          CacheClassesData,
          PrefetchHooks Function({
            bool ownerId,
            bool cacheClassMembersRefs,
            bool cachePostsRefs,
            bool cacheQuizzesRefs,
            bool cacheNotificationsRefs,
          })
        > {
  $$CacheClassesTableTableManager(_$AppDatabase db, $CacheClassesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CacheClassesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CacheClassesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CacheClassesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<String> course = const Value.absent(),
                Value<String> section = const Value.absent(),
                Value<String> schoolYear = const Value.absent(),
                Value<String> joinCode = const Value.absent(),
                Value<String?> bannerColor = const Value.absent(),
                Value<String?> bannerPath = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CacheClassesCompanion(
                id: id,
                ownerId: ownerId,
                course: course,
                section: section,
                schoolYear: schoolYear,
                joinCode: joinCode,
                bannerColor: bannerColor,
                bannerPath: bannerPath,
                archivedAt: archivedAt,
                deletedAt: deletedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String ownerId,
                required String course,
                required String section,
                required String schoolYear,
                required String joinCode,
                Value<String?> bannerColor = const Value.absent(),
                Value<String?> bannerPath = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CacheClassesCompanion.insert(
                id: id,
                ownerId: ownerId,
                course: course,
                section: section,
                schoolYear: schoolYear,
                joinCode: joinCode,
                bannerColor: bannerColor,
                bannerPath: bannerPath,
                archivedAt: archivedAt,
                deletedAt: deletedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CacheClassesTable, CacheClassesData>(table),
                  $$CacheClassesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                ownerId = false,
                cacheClassMembersRefs = false,
                cachePostsRefs = false,
                cacheQuizzesRefs = false,
                cacheNotificationsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (cacheClassMembersRefs) db.cacheClassMembers,
                    if (cachePostsRefs) db.cachePosts,
                    if (cacheQuizzesRefs) db.cacheQuizzes,
                    if (cacheNotificationsRefs) db.cacheNotifications,
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
                        if (ownerId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.ownerId,
                            referencedTable: $$CacheClassesTableReferences
                                ._ownerIdTable(db),
                            referencedColumn: $$CacheClassesTableReferences
                                ._ownerIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (cacheClassMembersRefs)
                        await $_getPrefetchedData<
                          CacheClassesData,
                          $CacheClassesTable,
                          CacheClassMember
                        >(
                          currentTable: table,
                          referencedTable: $$CacheClassesTableReferences
                              ._cacheClassMembersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CacheClassesTableReferences(
                                db,
                                table,
                                p0,
                              ).cacheClassMembersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.classId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (cachePostsRefs)
                        await $_getPrefetchedData<
                          CacheClassesData,
                          $CacheClassesTable,
                          CachePost
                        >(
                          currentTable: table,
                          referencedTable: $$CacheClassesTableReferences
                              ._cachePostsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CacheClassesTableReferences(
                                db,
                                table,
                                p0,
                              ).cachePostsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.classId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (cacheQuizzesRefs)
                        await $_getPrefetchedData<
                          CacheClassesData,
                          $CacheClassesTable,
                          CacheQuizze
                        >(
                          currentTable: table,
                          referencedTable: $$CacheClassesTableReferences
                              ._cacheQuizzesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CacheClassesTableReferences(
                                db,
                                table,
                                p0,
                              ).cacheQuizzesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.classId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (cacheNotificationsRefs)
                        await $_getPrefetchedData<
                          CacheClassesData,
                          $CacheClassesTable,
                          CacheNotification
                        >(
                          currentTable: table,
                          referencedTable: $$CacheClassesTableReferences
                              ._cacheNotificationsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CacheClassesTableReferences(
                                db,
                                table,
                                p0,
                              ).cacheNotificationsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.classId == item.id,
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

typedef $$CacheClassesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CacheClassesTable,
      CacheClassesData,
      $$CacheClassesTableFilterComposer,
      $$CacheClassesTableOrderingComposer,
      $$CacheClassesTableAnnotationComposer,
      $$CacheClassesTableCreateCompanionBuilder,
      $$CacheClassesTableUpdateCompanionBuilder,
      (CacheClassesData, $$CacheClassesTableReferences),
      CacheClassesData,
      PrefetchHooks Function({
        bool ownerId,
        bool cacheClassMembersRefs,
        bool cachePostsRefs,
        bool cacheQuizzesRefs,
        bool cacheNotificationsRefs,
      })
    >;
typedef $$CacheClassMembersTableCreateCompanionBuilder =
    CacheClassMembersCompanion Function({
      required String id,
      required String classId,
      required String studentId,
      Value<String> status,
      Value<DateTime> requestedAt,
      Value<DateTime?> decidedAt,
      Value<String?> decidedBy,
      Value<DateTime?> leftAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$CacheClassMembersTableUpdateCompanionBuilder =
    CacheClassMembersCompanion Function({
      Value<String> id,
      Value<String> classId,
      Value<String> studentId,
      Value<String> status,
      Value<DateTime> requestedAt,
      Value<DateTime?> decidedAt,
      Value<String?> decidedBy,
      Value<DateTime?> leftAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$CacheClassMembersTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $CacheClassMembersTable,
          CacheClassMember
        > {
  $$CacheClassMembersTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CacheClassesTable _classIdTable(_$AppDatabase db) => db.cacheClasses
      .createAlias('cache_class_members__class_id__cache_classes__id');

  $$CacheClassesTableProcessedTableManager get classId {
    final $_column = $_itemColumn<String>('class_id')!;

    final manager = $$CacheClassesTableTableManager(
      $_db,
      $_db.cacheClasses,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_classIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CacheProfilesTable _studentIdTable(_$AppDatabase db) => db
      .cacheProfiles
      .createAlias('cache_class_members__student_id__cache_profiles__id');

  $$CacheProfilesTableProcessedTableManager get studentId {
    final $_column = $_itemColumn<String>('student_id')!;

    final manager = $$CacheProfilesTableTableManager(
      $_db,
      $_db.cacheProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_studentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CacheProfilesTable _decidedByTable(_$AppDatabase db) => db
      .cacheProfiles
      .createAlias('cache_class_members__decided_by__cache_profiles__id');

  $$CacheProfilesTableProcessedTableManager? get decidedBy {
    final $_column = $_itemColumn<String>('decided_by');
    if ($_column == null) return null;
    final manager = $$CacheProfilesTableTableManager(
      $_db,
      $_db.cacheProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_decidedByTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CacheClassMembersTableFilterComposer
    extends Composer<_$AppDatabase, $CacheClassMembersTable> {
  $$CacheClassMembersTableFilterComposer({
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

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get requestedAt => $composableBuilder(
    column: $table.requestedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get decidedAt => $composableBuilder(
    column: $table.decidedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get leftAt => $composableBuilder(
    column: $table.leftAt,
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

  $$CacheClassesTableFilterComposer get classId {
    final $$CacheClassesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.classId,
      referencedTable: $db.cacheClasses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheClassesTableFilterComposer(
            $db: $db,
            $table: $db.cacheClasses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CacheProfilesTableFilterComposer get studentId {
    final $$CacheProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studentId,
      referencedTable: $db.cacheProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheProfilesTableFilterComposer(
            $db: $db,
            $table: $db.cacheProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CacheProfilesTableFilterComposer get decidedBy {
    final $$CacheProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.decidedBy,
      referencedTable: $db.cacheProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheProfilesTableFilterComposer(
            $db: $db,
            $table: $db.cacheProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CacheClassMembersTableOrderingComposer
    extends Composer<_$AppDatabase, $CacheClassMembersTable> {
  $$CacheClassMembersTableOrderingComposer({
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

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get requestedAt => $composableBuilder(
    column: $table.requestedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get decidedAt => $composableBuilder(
    column: $table.decidedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get leftAt => $composableBuilder(
    column: $table.leftAt,
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

  $$CacheClassesTableOrderingComposer get classId {
    final $$CacheClassesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.classId,
      referencedTable: $db.cacheClasses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheClassesTableOrderingComposer(
            $db: $db,
            $table: $db.cacheClasses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CacheProfilesTableOrderingComposer get studentId {
    final $$CacheProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studentId,
      referencedTable: $db.cacheProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.cacheProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CacheProfilesTableOrderingComposer get decidedBy {
    final $$CacheProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.decidedBy,
      referencedTable: $db.cacheProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.cacheProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CacheClassMembersTableAnnotationComposer
    extends Composer<_$AppDatabase, $CacheClassMembersTable> {
  $$CacheClassMembersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get requestedAt => $composableBuilder(
    column: $table.requestedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get decidedAt =>
      $composableBuilder(column: $table.decidedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get leftAt =>
      $composableBuilder(column: $table.leftAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$CacheClassesTableAnnotationComposer get classId {
    final $$CacheClassesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.classId,
      referencedTable: $db.cacheClasses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheClassesTableAnnotationComposer(
            $db: $db,
            $table: $db.cacheClasses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CacheProfilesTableAnnotationComposer get studentId {
    final $$CacheProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studentId,
      referencedTable: $db.cacheProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.cacheProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CacheProfilesTableAnnotationComposer get decidedBy {
    final $$CacheProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.decidedBy,
      referencedTable: $db.cacheProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.cacheProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CacheClassMembersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CacheClassMembersTable,
          CacheClassMember,
          $$CacheClassMembersTableFilterComposer,
          $$CacheClassMembersTableOrderingComposer,
          $$CacheClassMembersTableAnnotationComposer,
          $$CacheClassMembersTableCreateCompanionBuilder,
          $$CacheClassMembersTableUpdateCompanionBuilder,
          (CacheClassMember, $$CacheClassMembersTableReferences),
          CacheClassMember,
          PrefetchHooks Function({bool classId, bool studentId, bool decidedBy})
        > {
  $$CacheClassMembersTableTableManager(
    _$AppDatabase db,
    $CacheClassMembersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CacheClassMembersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CacheClassMembersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CacheClassMembersTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> classId = const Value.absent(),
                Value<String> studentId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> requestedAt = const Value.absent(),
                Value<DateTime?> decidedAt = const Value.absent(),
                Value<String?> decidedBy = const Value.absent(),
                Value<DateTime?> leftAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CacheClassMembersCompanion(
                id: id,
                classId: classId,
                studentId: studentId,
                status: status,
                requestedAt: requestedAt,
                decidedAt: decidedAt,
                decidedBy: decidedBy,
                leftAt: leftAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String classId,
                required String studentId,
                Value<String> status = const Value.absent(),
                Value<DateTime> requestedAt = const Value.absent(),
                Value<DateTime?> decidedAt = const Value.absent(),
                Value<String?> decidedBy = const Value.absent(),
                Value<DateTime?> leftAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CacheClassMembersCompanion.insert(
                id: id,
                classId: classId,
                studentId: studentId,
                status: status,
                requestedAt: requestedAt,
                decidedAt: decidedAt,
                decidedBy: decidedBy,
                leftAt: leftAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CacheClassMembersTable, CacheClassMember>(table),
                  $$CacheClassMembersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({classId = false, studentId = false, decidedBy = false}) {
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
                        if (classId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.classId,
                            referencedTable: $$CacheClassMembersTableReferences
                                ._classIdTable(db),
                            referencedColumn: $$CacheClassMembersTableReferences
                                ._classIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (studentId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.studentId,
                            referencedTable: $$CacheClassMembersTableReferences
                                ._studentIdTable(db),
                            referencedColumn: $$CacheClassMembersTableReferences
                                ._studentIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (decidedBy) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.decidedBy,
                            referencedTable: $$CacheClassMembersTableReferences
                                ._decidedByTable(db),
                            referencedColumn: $$CacheClassMembersTableReferences
                                ._decidedByTable(db)
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

typedef $$CacheClassMembersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CacheClassMembersTable,
      CacheClassMember,
      $$CacheClassMembersTableFilterComposer,
      $$CacheClassMembersTableOrderingComposer,
      $$CacheClassMembersTableAnnotationComposer,
      $$CacheClassMembersTableCreateCompanionBuilder,
      $$CacheClassMembersTableUpdateCompanionBuilder,
      (CacheClassMember, $$CacheClassMembersTableReferences),
      CacheClassMember,
      PrefetchHooks Function({bool classId, bool studentId, bool decidedBy})
    >;
typedef $$CachePostsTableCreateCompanionBuilder = CachePostsCompanion Function({
  required String id,
  required String classId,
  required String authorId,
  required String kind,
  required String title,
  Value<String?> body,
  Value<int?> points,
  Value<DateTime?> dueAt,
  Value<bool> acceptLate,
  Value<bool> allowFiles,
  Value<int> maxFiles,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$CachePostsTableUpdateCompanionBuilder = CachePostsCompanion Function({
  Value<String> id,
  Value<String> classId,
  Value<String> authorId,
  Value<String> kind,
  Value<String> title,
  Value<String?> body,
  Value<int?> points,
  Value<DateTime?> dueAt,
  Value<bool> acceptLate,
  Value<bool> allowFiles,
  Value<int> maxFiles,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

final class $$CachePostsTableReferences
    extends BaseReferences<_$AppDatabase, $CachePostsTable, CachePost> {
  $$CachePostsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CacheClassesTable _classIdTable(_$AppDatabase db) =>
      db.cacheClasses.createAlias('cache_posts__class_id__cache_classes__id');

  $$CacheClassesTableProcessedTableManager get classId {
    final $_column = $_itemColumn<String>('class_id')!;

    final manager = $$CacheClassesTableTableManager(
      $_db,
      $_db.cacheClasses,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_classIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CacheProfilesTable _authorIdTable(_$AppDatabase db) => db
      .cacheProfiles
      .createAlias('cache_posts__author_id__cache_profiles__id');

  $$CacheProfilesTableProcessedTableManager get authorId {
    final $_column = $_itemColumn<String>('author_id')!;

    final manager = $$CacheProfilesTableTableManager(
      $_db,
      $_db.cacheProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_authorIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $CachePostAttachmentsTable,
    List<CachePostAttachment>
  >
  _cachePostAttachmentsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.cachePostAttachments,
        aliasName: 'cache_posts__id__cache_post_attachments__post_id',
      );

  $$CachePostAttachmentsTableProcessedTableManager
  get cachePostAttachmentsRefs {
    final manager = $$CachePostAttachmentsTableTableManager(
      $_db,
      $_db.cachePostAttachments,
    ).filter((f) => f.postId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _cachePostAttachmentsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CacheSubmissionsTable, List<CacheSubmission>>
  _cacheSubmissionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.cacheSubmissions,
    aliasName: 'cache_posts__id__cache_submissions__post_id',
  );

  $$CacheSubmissionsTableProcessedTableManager get cacheSubmissionsRefs {
    final manager = $$CacheSubmissionsTableTableManager(
      $_db,
      $_db.cacheSubmissions,
    ).filter((f) => f.postId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _cacheSubmissionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CachePostsTableFilterComposer
    extends Composer<_$AppDatabase, $CachePostsTable> {
  $$CachePostsTableFilterComposer({
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

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get points => $composableBuilder(
    column: $table.points,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get acceptLate => $composableBuilder(
    column: $table.acceptLate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get allowFiles => $composableBuilder(
    column: $table.allowFiles,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxFiles => $composableBuilder(
    column: $table.maxFiles,
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

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CacheClassesTableFilterComposer get classId {
    final $$CacheClassesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.classId,
      referencedTable: $db.cacheClasses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheClassesTableFilterComposer(
            $db: $db,
            $table: $db.cacheClasses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CacheProfilesTableFilterComposer get authorId {
    final $$CacheProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.authorId,
      referencedTable: $db.cacheProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheProfilesTableFilterComposer(
            $db: $db,
            $table: $db.cacheProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> cachePostAttachmentsRefs(
    Expression<bool> Function($$CachePostAttachmentsTableFilterComposer f) f,
  ) {
    final $$CachePostAttachmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cachePostAttachments,
      getReferencedColumn: (t) => t.postId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CachePostAttachmentsTableFilterComposer(
            $db: $db,
            $table: $db.cachePostAttachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> cacheSubmissionsRefs(
    Expression<bool> Function($$CacheSubmissionsTableFilterComposer f) f,
  ) {
    final $$CacheSubmissionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cacheSubmissions,
      getReferencedColumn: (t) => t.postId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheSubmissionsTableFilterComposer(
            $db: $db,
            $table: $db.cacheSubmissions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CachePostsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachePostsTable> {
  $$CachePostsTableOrderingComposer({
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

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get points => $composableBuilder(
    column: $table.points,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get acceptLate => $composableBuilder(
    column: $table.acceptLate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get allowFiles => $composableBuilder(
    column: $table.allowFiles,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxFiles => $composableBuilder(
    column: $table.maxFiles,
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

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CacheClassesTableOrderingComposer get classId {
    final $$CacheClassesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.classId,
      referencedTable: $db.cacheClasses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheClassesTableOrderingComposer(
            $db: $db,
            $table: $db.cacheClasses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CacheProfilesTableOrderingComposer get authorId {
    final $$CacheProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.authorId,
      referencedTable: $db.cacheProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.cacheProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CachePostsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachePostsTable> {
  $$CachePostsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<int> get points =>
      $composableBuilder(column: $table.points, builder: (column) => column);

  GeneratedColumn<DateTime> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => column);

  GeneratedColumn<bool> get acceptLate => $composableBuilder(
    column: $table.acceptLate,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get allowFiles => $composableBuilder(
    column: $table.allowFiles,
    builder: (column) => column,
  );

  GeneratedColumn<int> get maxFiles =>
      $composableBuilder(column: $table.maxFiles, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$CacheClassesTableAnnotationComposer get classId {
    final $$CacheClassesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.classId,
      referencedTable: $db.cacheClasses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheClassesTableAnnotationComposer(
            $db: $db,
            $table: $db.cacheClasses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CacheProfilesTableAnnotationComposer get authorId {
    final $$CacheProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.authorId,
      referencedTable: $db.cacheProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.cacheProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> cachePostAttachmentsRefs<T extends Object>(
    Expression<T> Function($$CachePostAttachmentsTableAnnotationComposer a) f,
  ) {
    final $$CachePostAttachmentsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.cachePostAttachments,
          getReferencedColumn: (t) => t.postId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CachePostAttachmentsTableAnnotationComposer(
                $db: $db,
                $table: $db.cachePostAttachments,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> cacheSubmissionsRefs<T extends Object>(
    Expression<T> Function($$CacheSubmissionsTableAnnotationComposer a) f,
  ) {
    final $$CacheSubmissionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cacheSubmissions,
      getReferencedColumn: (t) => t.postId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheSubmissionsTableAnnotationComposer(
            $db: $db,
            $table: $db.cacheSubmissions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CachePostsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachePostsTable,
          CachePost,
          $$CachePostsTableFilterComposer,
          $$CachePostsTableOrderingComposer,
          $$CachePostsTableAnnotationComposer,
          $$CachePostsTableCreateCompanionBuilder,
          $$CachePostsTableUpdateCompanionBuilder,
          (CachePost, $$CachePostsTableReferences),
          CachePost,
          PrefetchHooks Function({
            bool classId,
            bool authorId,
            bool cachePostAttachmentsRefs,
            bool cacheSubmissionsRefs,
          })
        > {
  $$CachePostsTableTableManager(_$AppDatabase db, $CachePostsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachePostsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachePostsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachePostsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> classId = const Value.absent(),
                Value<String> authorId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> body = const Value.absent(),
                Value<int?> points = const Value.absent(),
                Value<DateTime?> dueAt = const Value.absent(),
                Value<bool> acceptLate = const Value.absent(),
                Value<bool> allowFiles = const Value.absent(),
                Value<int> maxFiles = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachePostsCompanion(
                id: id,
                classId: classId,
                authorId: authorId,
                kind: kind,
                title: title,
                body: body,
                points: points,
                dueAt: dueAt,
                acceptLate: acceptLate,
                allowFiles: allowFiles,
                maxFiles: maxFiles,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String classId,
                required String authorId,
                required String kind,
                required String title,
                Value<String?> body = const Value.absent(),
                Value<int?> points = const Value.absent(),
                Value<DateTime?> dueAt = const Value.absent(),
                Value<bool> acceptLate = const Value.absent(),
                Value<bool> allowFiles = const Value.absent(),
                Value<int> maxFiles = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachePostsCompanion.insert(
                id: id,
                classId: classId,
                authorId: authorId,
                kind: kind,
                title: title,
                body: body,
                points: points,
                dueAt: dueAt,
                acceptLate: acceptLate,
                allowFiles: allowFiles,
                maxFiles: maxFiles,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CachePostsTable, CachePost>(table),
                  $$CachePostsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                classId = false,
                authorId = false,
                cachePostAttachmentsRefs = false,
                cacheSubmissionsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (cachePostAttachmentsRefs) db.cachePostAttachments,
                    if (cacheSubmissionsRefs) db.cacheSubmissions,
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
                        if (classId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.classId,
                            referencedTable: $$CachePostsTableReferences
                                ._classIdTable(db),
                            referencedColumn: $$CachePostsTableReferences
                                ._classIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (authorId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.authorId,
                            referencedTable: $$CachePostsTableReferences
                                ._authorIdTable(db),
                            referencedColumn: $$CachePostsTableReferences
                                ._authorIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (cachePostAttachmentsRefs)
                        await $_getPrefetchedData<
                          CachePost,
                          $CachePostsTable,
                          CachePostAttachment
                        >(
                          currentTable: table,
                          referencedTable: $$CachePostsTableReferences
                              ._cachePostAttachmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CachePostsTableReferences(
                                db,
                                table,
                                p0,
                              ).cachePostAttachmentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.postId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (cacheSubmissionsRefs)
                        await $_getPrefetchedData<
                          CachePost,
                          $CachePostsTable,
                          CacheSubmission
                        >(
                          currentTable: table,
                          referencedTable: $$CachePostsTableReferences
                              ._cacheSubmissionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CachePostsTableReferences(
                                db,
                                table,
                                p0,
                              ).cacheSubmissionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.postId == item.id,
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

typedef $$CachePostsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachePostsTable,
      CachePost,
      $$CachePostsTableFilterComposer,
      $$CachePostsTableOrderingComposer,
      $$CachePostsTableAnnotationComposer,
      $$CachePostsTableCreateCompanionBuilder,
      $$CachePostsTableUpdateCompanionBuilder,
      (CachePost, $$CachePostsTableReferences),
      CachePost,
      PrefetchHooks Function({
        bool classId,
        bool authorId,
        bool cachePostAttachmentsRefs,
        bool cacheSubmissionsRefs,
      })
    >;
typedef $$CachePostAttachmentsTableCreateCompanionBuilder =
    CachePostAttachmentsCompanion Function({
      required String id,
      required String postId,
      required String kind,
      required String name,
      Value<String?> storagePath,
      Value<String?> url,
      Value<String?> mimeType,
      Value<int?> sizeBytes,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$CachePostAttachmentsTableUpdateCompanionBuilder =
    CachePostAttachmentsCompanion Function({
      Value<String> id,
      Value<String> postId,
      Value<String> kind,
      Value<String> name,
      Value<String?> storagePath,
      Value<String?> url,
      Value<String?> mimeType,
      Value<int?> sizeBytes,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

final class $$CachePostAttachmentsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $CachePostAttachmentsTable,
          CachePostAttachment
        > {
  $$CachePostAttachmentsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CachePostsTable _postIdTable(_$AppDatabase db) => db.cachePosts
      .createAlias('cache_post_attachments__post_id__cache_posts__id');

  $$CachePostsTableProcessedTableManager get postId {
    final $_column = $_itemColumn<String>('post_id')!;

    final manager = $$CachePostsTableTableManager(
      $_db,
      $_db.cachePosts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_postIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CachePostAttachmentsTableFilterComposer
    extends Composer<_$AppDatabase, $CachePostAttachmentsTable> {
  $$CachePostAttachmentsTableFilterComposer({
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

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get storagePath => $composableBuilder(
    column: $table.storagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
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

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CachePostsTableFilterComposer get postId {
    final $$CachePostsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.postId,
      referencedTable: $db.cachePosts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CachePostsTableFilterComposer(
            $db: $db,
            $table: $db.cachePosts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CachePostAttachmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachePostAttachmentsTable> {
  $$CachePostAttachmentsTableOrderingComposer({
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

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get storagePath => $composableBuilder(
    column: $table.storagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
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

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CachePostsTableOrderingComposer get postId {
    final $$CachePostsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.postId,
      referencedTable: $db.cachePosts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CachePostsTableOrderingComposer(
            $db: $db,
            $table: $db.cachePosts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CachePostAttachmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachePostAttachmentsTable> {
  $$CachePostAttachmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get storagePath => $composableBuilder(
    column: $table.storagePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$CachePostsTableAnnotationComposer get postId {
    final $$CachePostsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.postId,
      referencedTable: $db.cachePosts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CachePostsTableAnnotationComposer(
            $db: $db,
            $table: $db.cachePosts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CachePostAttachmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachePostAttachmentsTable,
          CachePostAttachment,
          $$CachePostAttachmentsTableFilterComposer,
          $$CachePostAttachmentsTableOrderingComposer,
          $$CachePostAttachmentsTableAnnotationComposer,
          $$CachePostAttachmentsTableCreateCompanionBuilder,
          $$CachePostAttachmentsTableUpdateCompanionBuilder,
          (CachePostAttachment, $$CachePostAttachmentsTableReferences),
          CachePostAttachment,
          PrefetchHooks Function({bool postId})
        > {
  $$CachePostAttachmentsTableTableManager(
    _$AppDatabase db,
    $CachePostAttachmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachePostAttachmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachePostAttachmentsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CachePostAttachmentsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> postId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> storagePath = const Value.absent(),
                Value<String?> url = const Value.absent(),
                Value<String?> mimeType = const Value.absent(),
                Value<int?> sizeBytes = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachePostAttachmentsCompanion(
                id: id,
                postId: postId,
                kind: kind,
                name: name,
                storagePath: storagePath,
                url: url,
                mimeType: mimeType,
                sizeBytes: sizeBytes,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String postId,
                required String kind,
                required String name,
                Value<String?> storagePath = const Value.absent(),
                Value<String?> url = const Value.absent(),
                Value<String?> mimeType = const Value.absent(),
                Value<int?> sizeBytes = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachePostAttachmentsCompanion.insert(
                id: id,
                postId: postId,
                kind: kind,
                name: name,
                storagePath: storagePath,
                url: url,
                mimeType: mimeType,
                sizeBytes: sizeBytes,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CachePostAttachmentsTable, CachePostAttachment>(
                    table,
                  ),
                  $$CachePostAttachmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({postId = false}) {
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
                    if (postId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.postId,
                        referencedTable: $$CachePostAttachmentsTableReferences
                            ._postIdTable(db),
                        referencedColumn: $$CachePostAttachmentsTableReferences
                            ._postIdTable(db)
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

typedef $$CachePostAttachmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachePostAttachmentsTable,
      CachePostAttachment,
      $$CachePostAttachmentsTableFilterComposer,
      $$CachePostAttachmentsTableOrderingComposer,
      $$CachePostAttachmentsTableAnnotationComposer,
      $$CachePostAttachmentsTableCreateCompanionBuilder,
      $$CachePostAttachmentsTableUpdateCompanionBuilder,
      (CachePostAttachment, $$CachePostAttachmentsTableReferences),
      CachePostAttachment,
      PrefetchHooks Function({bool postId})
    >;
typedef $$CacheSubmissionsTableCreateCompanionBuilder =
    CacheSubmissionsCompanion Function({
      required String id,
      required String postId,
      required String studentId,
      Value<String> status,
      Value<String?> privateComment,
      Value<DateTime?> submittedAt,
      Value<bool> isLate,
      Value<DateTime?> unsubmitUntil,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$CacheSubmissionsTableUpdateCompanionBuilder =
    CacheSubmissionsCompanion Function({
      Value<String> id,
      Value<String> postId,
      Value<String> studentId,
      Value<String> status,
      Value<String?> privateComment,
      Value<DateTime?> submittedAt,
      Value<bool> isLate,
      Value<DateTime?> unsubmitUntil,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$CacheSubmissionsTableReferences
    extends
        BaseReferences<_$AppDatabase, $CacheSubmissionsTable, CacheSubmission> {
  $$CacheSubmissionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CachePostsTable _postIdTable(_$AppDatabase db) =>
      db.cachePosts.createAlias('cache_submissions__post_id__cache_posts__id');

  $$CachePostsTableProcessedTableManager get postId {
    final $_column = $_itemColumn<String>('post_id')!;

    final manager = $$CachePostsTableTableManager(
      $_db,
      $_db.cachePosts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_postIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CacheProfilesTable _studentIdTable(_$AppDatabase db) => db
      .cacheProfiles
      .createAlias('cache_submissions__student_id__cache_profiles__id');

  $$CacheProfilesTableProcessedTableManager get studentId {
    final $_column = $_itemColumn<String>('student_id')!;

    final manager = $$CacheProfilesTableTableManager(
      $_db,
      $_db.cacheProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_studentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $CacheSubmissionItemsTable,
    List<CacheSubmissionItem>
  >
  _cacheSubmissionItemsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.cacheSubmissionItems,
        aliasName:
            'cache_submissions__id__cache_submission_items__submission_id',
      );

  $$CacheSubmissionItemsTableProcessedTableManager
  get cacheSubmissionItemsRefs {
    final manager = $$CacheSubmissionItemsTableTableManager(
      $_db,
      $_db.cacheSubmissionItems,
    ).filter((f) => f.submissionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _cacheSubmissionItemsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CacheGradesTable, List<CacheGrade>>
  _cacheGradesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.cacheGrades,
    aliasName: 'cache_submissions__id__cache_grades__submission_id',
  );

  $$CacheGradesTableProcessedTableManager get cacheGradesRefs {
    final manager = $$CacheGradesTableTableManager(
      $_db,
      $_db.cacheGrades,
    ).filter((f) => f.submissionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_cacheGradesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CacheSubmissionsTableFilterComposer
    extends Composer<_$AppDatabase, $CacheSubmissionsTable> {
  $$CacheSubmissionsTableFilterComposer({
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

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get privateComment => $composableBuilder(
    column: $table.privateComment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get submittedAt => $composableBuilder(
    column: $table.submittedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isLate => $composableBuilder(
    column: $table.isLate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get unsubmitUntil => $composableBuilder(
    column: $table.unsubmitUntil,
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

  $$CachePostsTableFilterComposer get postId {
    final $$CachePostsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.postId,
      referencedTable: $db.cachePosts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CachePostsTableFilterComposer(
            $db: $db,
            $table: $db.cachePosts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CacheProfilesTableFilterComposer get studentId {
    final $$CacheProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studentId,
      referencedTable: $db.cacheProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheProfilesTableFilterComposer(
            $db: $db,
            $table: $db.cacheProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> cacheSubmissionItemsRefs(
    Expression<bool> Function($$CacheSubmissionItemsTableFilterComposer f) f,
  ) {
    final $$CacheSubmissionItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cacheSubmissionItems,
      getReferencedColumn: (t) => t.submissionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheSubmissionItemsTableFilterComposer(
            $db: $db,
            $table: $db.cacheSubmissionItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> cacheGradesRefs(
    Expression<bool> Function($$CacheGradesTableFilterComposer f) f,
  ) {
    final $$CacheGradesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cacheGrades,
      getReferencedColumn: (t) => t.submissionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheGradesTableFilterComposer(
            $db: $db,
            $table: $db.cacheGrades,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CacheSubmissionsTableOrderingComposer
    extends Composer<_$AppDatabase, $CacheSubmissionsTable> {
  $$CacheSubmissionsTableOrderingComposer({
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

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get privateComment => $composableBuilder(
    column: $table.privateComment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get submittedAt => $composableBuilder(
    column: $table.submittedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isLate => $composableBuilder(
    column: $table.isLate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get unsubmitUntil => $composableBuilder(
    column: $table.unsubmitUntil,
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

  $$CachePostsTableOrderingComposer get postId {
    final $$CachePostsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.postId,
      referencedTable: $db.cachePosts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CachePostsTableOrderingComposer(
            $db: $db,
            $table: $db.cachePosts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CacheProfilesTableOrderingComposer get studentId {
    final $$CacheProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studentId,
      referencedTable: $db.cacheProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.cacheProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CacheSubmissionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CacheSubmissionsTable> {
  $$CacheSubmissionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get privateComment => $composableBuilder(
    column: $table.privateComment,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get submittedAt => $composableBuilder(
    column: $table.submittedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isLate =>
      $composableBuilder(column: $table.isLate, builder: (column) => column);

  GeneratedColumn<DateTime> get unsubmitUntil => $composableBuilder(
    column: $table.unsubmitUntil,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$CachePostsTableAnnotationComposer get postId {
    final $$CachePostsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.postId,
      referencedTable: $db.cachePosts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CachePostsTableAnnotationComposer(
            $db: $db,
            $table: $db.cachePosts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CacheProfilesTableAnnotationComposer get studentId {
    final $$CacheProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studentId,
      referencedTable: $db.cacheProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.cacheProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> cacheSubmissionItemsRefs<T extends Object>(
    Expression<T> Function($$CacheSubmissionItemsTableAnnotationComposer a) f,
  ) {
    final $$CacheSubmissionItemsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.cacheSubmissionItems,
          getReferencedColumn: (t) => t.submissionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CacheSubmissionItemsTableAnnotationComposer(
                $db: $db,
                $table: $db.cacheSubmissionItems,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> cacheGradesRefs<T extends Object>(
    Expression<T> Function($$CacheGradesTableAnnotationComposer a) f,
  ) {
    final $$CacheGradesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cacheGrades,
      getReferencedColumn: (t) => t.submissionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheGradesTableAnnotationComposer(
            $db: $db,
            $table: $db.cacheGrades,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CacheSubmissionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CacheSubmissionsTable,
          CacheSubmission,
          $$CacheSubmissionsTableFilterComposer,
          $$CacheSubmissionsTableOrderingComposer,
          $$CacheSubmissionsTableAnnotationComposer,
          $$CacheSubmissionsTableCreateCompanionBuilder,
          $$CacheSubmissionsTableUpdateCompanionBuilder,
          (CacheSubmission, $$CacheSubmissionsTableReferences),
          CacheSubmission,
          PrefetchHooks Function({
            bool postId,
            bool studentId,
            bool cacheSubmissionItemsRefs,
            bool cacheGradesRefs,
          })
        > {
  $$CacheSubmissionsTableTableManager(
    _$AppDatabase db,
    $CacheSubmissionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CacheSubmissionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CacheSubmissionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CacheSubmissionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> postId = const Value.absent(),
                Value<String> studentId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> privateComment = const Value.absent(),
                Value<DateTime?> submittedAt = const Value.absent(),
                Value<bool> isLate = const Value.absent(),
                Value<DateTime?> unsubmitUntil = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CacheSubmissionsCompanion(
                id: id,
                postId: postId,
                studentId: studentId,
                status: status,
                privateComment: privateComment,
                submittedAt: submittedAt,
                isLate: isLate,
                unsubmitUntil: unsubmitUntil,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String postId,
                required String studentId,
                Value<String> status = const Value.absent(),
                Value<String?> privateComment = const Value.absent(),
                Value<DateTime?> submittedAt = const Value.absent(),
                Value<bool> isLate = const Value.absent(),
                Value<DateTime?> unsubmitUntil = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CacheSubmissionsCompanion.insert(
                id: id,
                postId: postId,
                studentId: studentId,
                status: status,
                privateComment: privateComment,
                submittedAt: submittedAt,
                isLate: isLate,
                unsubmitUntil: unsubmitUntil,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CacheSubmissionsTable, CacheSubmission>(table),
                  $$CacheSubmissionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                postId = false,
                studentId = false,
                cacheSubmissionItemsRefs = false,
                cacheGradesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (cacheSubmissionItemsRefs) db.cacheSubmissionItems,
                    if (cacheGradesRefs) db.cacheGrades,
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
                        if (postId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.postId,
                            referencedTable: $$CacheSubmissionsTableReferences
                                ._postIdTable(db),
                            referencedColumn: $$CacheSubmissionsTableReferences
                                ._postIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (studentId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.studentId,
                            referencedTable: $$CacheSubmissionsTableReferences
                                ._studentIdTable(db),
                            referencedColumn: $$CacheSubmissionsTableReferences
                                ._studentIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (cacheSubmissionItemsRefs)
                        await $_getPrefetchedData<
                          CacheSubmission,
                          $CacheSubmissionsTable,
                          CacheSubmissionItem
                        >(
                          currentTable: table,
                          referencedTable: $$CacheSubmissionsTableReferences
                              ._cacheSubmissionItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CacheSubmissionsTableReferences(
                                db,
                                table,
                                p0,
                              ).cacheSubmissionItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.submissionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (cacheGradesRefs)
                        await $_getPrefetchedData<
                          CacheSubmission,
                          $CacheSubmissionsTable,
                          CacheGrade
                        >(
                          currentTable: table,
                          referencedTable: $$CacheSubmissionsTableReferences
                              ._cacheGradesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CacheSubmissionsTableReferences(
                                db,
                                table,
                                p0,
                              ).cacheGradesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.submissionId == item.id,
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

typedef $$CacheSubmissionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CacheSubmissionsTable,
      CacheSubmission,
      $$CacheSubmissionsTableFilterComposer,
      $$CacheSubmissionsTableOrderingComposer,
      $$CacheSubmissionsTableAnnotationComposer,
      $$CacheSubmissionsTableCreateCompanionBuilder,
      $$CacheSubmissionsTableUpdateCompanionBuilder,
      (CacheSubmission, $$CacheSubmissionsTableReferences),
      CacheSubmission,
      PrefetchHooks Function({
        bool postId,
        bool studentId,
        bool cacheSubmissionItemsRefs,
        bool cacheGradesRefs,
      })
    >;
typedef $$CacheSubmissionItemsTableCreateCompanionBuilder =
    CacheSubmissionItemsCompanion Function({
      required String id,
      required String submissionId,
      required String kind,
      Value<String?> name,
      Value<String?> storagePath,
      Value<String?> url,
      Value<String?> textContent,
      Value<String?> mimeType,
      Value<int?> sizeBytes,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$CacheSubmissionItemsTableUpdateCompanionBuilder =
    CacheSubmissionItemsCompanion Function({
      Value<String> id,
      Value<String> submissionId,
      Value<String> kind,
      Value<String?> name,
      Value<String?> storagePath,
      Value<String?> url,
      Value<String?> textContent,
      Value<String?> mimeType,
      Value<int?> sizeBytes,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

final class $$CacheSubmissionItemsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $CacheSubmissionItemsTable,
          CacheSubmissionItem
        > {
  $$CacheSubmissionItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CacheSubmissionsTable _submissionIdTable(_$AppDatabase db) =>
      db.cacheSubmissions.createAlias(
        'cache_submission_items__submission_id__cache_submissions__id',
      );

  $$CacheSubmissionsTableProcessedTableManager get submissionId {
    final $_column = $_itemColumn<String>('submission_id')!;

    final manager = $$CacheSubmissionsTableTableManager(
      $_db,
      $_db.cacheSubmissions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_submissionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CacheSubmissionItemsTableFilterComposer
    extends Composer<_$AppDatabase, $CacheSubmissionItemsTable> {
  $$CacheSubmissionItemsTableFilterComposer({
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

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get storagePath => $composableBuilder(
    column: $table.storagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get textContent => $composableBuilder(
    column: $table.textContent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
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

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CacheSubmissionsTableFilterComposer get submissionId {
    final $$CacheSubmissionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.submissionId,
      referencedTable: $db.cacheSubmissions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheSubmissionsTableFilterComposer(
            $db: $db,
            $table: $db.cacheSubmissions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CacheSubmissionItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $CacheSubmissionItemsTable> {
  $$CacheSubmissionItemsTableOrderingComposer({
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

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get storagePath => $composableBuilder(
    column: $table.storagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get textContent => $composableBuilder(
    column: $table.textContent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
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

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CacheSubmissionsTableOrderingComposer get submissionId {
    final $$CacheSubmissionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.submissionId,
      referencedTable: $db.cacheSubmissions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheSubmissionsTableOrderingComposer(
            $db: $db,
            $table: $db.cacheSubmissions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CacheSubmissionItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CacheSubmissionItemsTable> {
  $$CacheSubmissionItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get storagePath => $composableBuilder(
    column: $table.storagePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get textContent => $composableBuilder(
    column: $table.textContent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$CacheSubmissionsTableAnnotationComposer get submissionId {
    final $$CacheSubmissionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.submissionId,
      referencedTable: $db.cacheSubmissions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheSubmissionsTableAnnotationComposer(
            $db: $db,
            $table: $db.cacheSubmissions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CacheSubmissionItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CacheSubmissionItemsTable,
          CacheSubmissionItem,
          $$CacheSubmissionItemsTableFilterComposer,
          $$CacheSubmissionItemsTableOrderingComposer,
          $$CacheSubmissionItemsTableAnnotationComposer,
          $$CacheSubmissionItemsTableCreateCompanionBuilder,
          $$CacheSubmissionItemsTableUpdateCompanionBuilder,
          (CacheSubmissionItem, $$CacheSubmissionItemsTableReferences),
          CacheSubmissionItem,
          PrefetchHooks Function({bool submissionId})
        > {
  $$CacheSubmissionItemsTableTableManager(
    _$AppDatabase db,
    $CacheSubmissionItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CacheSubmissionItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CacheSubmissionItemsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CacheSubmissionItemsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> submissionId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> storagePath = const Value.absent(),
                Value<String?> url = const Value.absent(),
                Value<String?> textContent = const Value.absent(),
                Value<String?> mimeType = const Value.absent(),
                Value<int?> sizeBytes = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CacheSubmissionItemsCompanion(
                id: id,
                submissionId: submissionId,
                kind: kind,
                name: name,
                storagePath: storagePath,
                url: url,
                textContent: textContent,
                mimeType: mimeType,
                sizeBytes: sizeBytes,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String submissionId,
                required String kind,
                Value<String?> name = const Value.absent(),
                Value<String?> storagePath = const Value.absent(),
                Value<String?> url = const Value.absent(),
                Value<String?> textContent = const Value.absent(),
                Value<String?> mimeType = const Value.absent(),
                Value<int?> sizeBytes = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CacheSubmissionItemsCompanion.insert(
                id: id,
                submissionId: submissionId,
                kind: kind,
                name: name,
                storagePath: storagePath,
                url: url,
                textContent: textContent,
                mimeType: mimeType,
                sizeBytes: sizeBytes,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CacheSubmissionItemsTable, CacheSubmissionItem>(
                    table,
                  ),
                  $$CacheSubmissionItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({submissionId = false}) {
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
                    if (submissionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.submissionId,
                        referencedTable: $$CacheSubmissionItemsTableReferences
                            ._submissionIdTable(db),
                        referencedColumn: $$CacheSubmissionItemsTableReferences
                            ._submissionIdTable(db)
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

typedef $$CacheSubmissionItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CacheSubmissionItemsTable,
      CacheSubmissionItem,
      $$CacheSubmissionItemsTableFilterComposer,
      $$CacheSubmissionItemsTableOrderingComposer,
      $$CacheSubmissionItemsTableAnnotationComposer,
      $$CacheSubmissionItemsTableCreateCompanionBuilder,
      $$CacheSubmissionItemsTableUpdateCompanionBuilder,
      (CacheSubmissionItem, $$CacheSubmissionItemsTableReferences),
      CacheSubmissionItem,
      PrefetchHooks Function({bool submissionId})
    >;
typedef $$CacheGradesTableCreateCompanionBuilder =
    CacheGradesCompanion Function({
      required String submissionId,
      Value<int?> score,
      Value<String?> feedback,
      Value<String?> gradedBy,
      Value<DateTime?> gradedAt,
      Value<DateTime?> returnedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$CacheGradesTableUpdateCompanionBuilder =
    CacheGradesCompanion Function({
      Value<String> submissionId,
      Value<int?> score,
      Value<String?> feedback,
      Value<String?> gradedBy,
      Value<DateTime?> gradedAt,
      Value<DateTime?> returnedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$CacheGradesTableReferences
    extends BaseReferences<_$AppDatabase, $CacheGradesTable, CacheGrade> {
  $$CacheGradesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CacheSubmissionsTable _submissionIdTable(_$AppDatabase db) => db
      .cacheSubmissions
      .createAlias('cache_grades__submission_id__cache_submissions__id');

  $$CacheSubmissionsTableProcessedTableManager get submissionId {
    final $_column = $_itemColumn<String>('submission_id')!;

    final manager = $$CacheSubmissionsTableTableManager(
      $_db,
      $_db.cacheSubmissions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_submissionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CacheProfilesTable _gradedByTable(_$AppDatabase db) => db
      .cacheProfiles
      .createAlias('cache_grades__graded_by__cache_profiles__id');

  $$CacheProfilesTableProcessedTableManager? get gradedBy {
    final $_column = $_itemColumn<String>('graded_by');
    if ($_column == null) return null;
    final manager = $$CacheProfilesTableTableManager(
      $_db,
      $_db.cacheProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_gradedByTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CacheGradesTableFilterComposer
    extends Composer<_$AppDatabase, $CacheGradesTable> {
  $$CacheGradesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get feedback => $composableBuilder(
    column: $table.feedback,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get gradedAt => $composableBuilder(
    column: $table.gradedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get returnedAt => $composableBuilder(
    column: $table.returnedAt,
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

  $$CacheSubmissionsTableFilterComposer get submissionId {
    final $$CacheSubmissionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.submissionId,
      referencedTable: $db.cacheSubmissions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheSubmissionsTableFilterComposer(
            $db: $db,
            $table: $db.cacheSubmissions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CacheProfilesTableFilterComposer get gradedBy {
    final $$CacheProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.gradedBy,
      referencedTable: $db.cacheProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheProfilesTableFilterComposer(
            $db: $db,
            $table: $db.cacheProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CacheGradesTableOrderingComposer
    extends Composer<_$AppDatabase, $CacheGradesTable> {
  $$CacheGradesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get feedback => $composableBuilder(
    column: $table.feedback,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get gradedAt => $composableBuilder(
    column: $table.gradedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get returnedAt => $composableBuilder(
    column: $table.returnedAt,
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

  $$CacheSubmissionsTableOrderingComposer get submissionId {
    final $$CacheSubmissionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.submissionId,
      referencedTable: $db.cacheSubmissions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheSubmissionsTableOrderingComposer(
            $db: $db,
            $table: $db.cacheSubmissions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CacheProfilesTableOrderingComposer get gradedBy {
    final $$CacheProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.gradedBy,
      referencedTable: $db.cacheProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.cacheProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CacheGradesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CacheGradesTable> {
  $$CacheGradesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<String> get feedback =>
      $composableBuilder(column: $table.feedback, builder: (column) => column);

  GeneratedColumn<DateTime> get gradedAt =>
      $composableBuilder(column: $table.gradedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get returnedAt => $composableBuilder(
    column: $table.returnedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$CacheSubmissionsTableAnnotationComposer get submissionId {
    final $$CacheSubmissionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.submissionId,
      referencedTable: $db.cacheSubmissions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheSubmissionsTableAnnotationComposer(
            $db: $db,
            $table: $db.cacheSubmissions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CacheProfilesTableAnnotationComposer get gradedBy {
    final $$CacheProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.gradedBy,
      referencedTable: $db.cacheProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.cacheProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CacheGradesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CacheGradesTable,
          CacheGrade,
          $$CacheGradesTableFilterComposer,
          $$CacheGradesTableOrderingComposer,
          $$CacheGradesTableAnnotationComposer,
          $$CacheGradesTableCreateCompanionBuilder,
          $$CacheGradesTableUpdateCompanionBuilder,
          (CacheGrade, $$CacheGradesTableReferences),
          CacheGrade,
          PrefetchHooks Function({bool submissionId, bool gradedBy})
        > {
  $$CacheGradesTableTableManager(_$AppDatabase db, $CacheGradesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CacheGradesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CacheGradesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CacheGradesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> submissionId = const Value.absent(),
                Value<int?> score = const Value.absent(),
                Value<String?> feedback = const Value.absent(),
                Value<String?> gradedBy = const Value.absent(),
                Value<DateTime?> gradedAt = const Value.absent(),
                Value<DateTime?> returnedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CacheGradesCompanion(
                submissionId: submissionId,
                score: score,
                feedback: feedback,
                gradedBy: gradedBy,
                gradedAt: gradedAt,
                returnedAt: returnedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String submissionId,
                Value<int?> score = const Value.absent(),
                Value<String?> feedback = const Value.absent(),
                Value<String?> gradedBy = const Value.absent(),
                Value<DateTime?> gradedAt = const Value.absent(),
                Value<DateTime?> returnedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CacheGradesCompanion.insert(
                submissionId: submissionId,
                score: score,
                feedback: feedback,
                gradedBy: gradedBy,
                gradedAt: gradedAt,
                returnedAt: returnedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CacheGradesTable, CacheGrade>(table),
                  $$CacheGradesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({submissionId = false, gradedBy = false}) {
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
                    if (submissionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.submissionId,
                        referencedTable: $$CacheGradesTableReferences
                            ._submissionIdTable(db),
                        referencedColumn: $$CacheGradesTableReferences
                            ._submissionIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (gradedBy) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.gradedBy,
                        referencedTable: $$CacheGradesTableReferences
                            ._gradedByTable(db),
                        referencedColumn: $$CacheGradesTableReferences
                            ._gradedByTable(db)
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

typedef $$CacheGradesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CacheGradesTable,
      CacheGrade,
      $$CacheGradesTableFilterComposer,
      $$CacheGradesTableOrderingComposer,
      $$CacheGradesTableAnnotationComposer,
      $$CacheGradesTableCreateCompanionBuilder,
      $$CacheGradesTableUpdateCompanionBuilder,
      (CacheGrade, $$CacheGradesTableReferences),
      CacheGrade,
      PrefetchHooks Function({bool submissionId, bool gradedBy})
    >;
typedef $$CacheQuizzesTableCreateCompanionBuilder =
    CacheQuizzesCompanion Function({
      required String id,
      required String classId,
      required String authorId,
      Value<String> type,
      required String title,
      Value<String?> instructions,
      Value<int> timeLimitMinutes,
      Value<DateTime?> opensAt,
      Value<DateTime?> closesAt,
      Value<bool> shuffleQuestions,
      Value<bool> shuffleOptions,
      Value<bool> showCorrectAnswers,
      Value<int?> passingPercent,
      Value<String> status,
      Value<DateTime?> publishedAt,
      Value<DateTime?> resultsReleasedAt,
      Value<int> totalPoints,
      Value<bool> hasEssay,
      Value<DateTime?> lockedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$CacheQuizzesTableUpdateCompanionBuilder =
    CacheQuizzesCompanion Function({
      Value<String> id,
      Value<String> classId,
      Value<String> authorId,
      Value<String> type,
      Value<String> title,
      Value<String?> instructions,
      Value<int> timeLimitMinutes,
      Value<DateTime?> opensAt,
      Value<DateTime?> closesAt,
      Value<bool> shuffleQuestions,
      Value<bool> shuffleOptions,
      Value<bool> showCorrectAnswers,
      Value<int?> passingPercent,
      Value<String> status,
      Value<DateTime?> publishedAt,
      Value<DateTime?> resultsReleasedAt,
      Value<int> totalPoints,
      Value<bool> hasEssay,
      Value<DateTime?> lockedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

final class $$CacheQuizzesTableReferences
    extends BaseReferences<_$AppDatabase, $CacheQuizzesTable, CacheQuizze> {
  $$CacheQuizzesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CacheClassesTable _classIdTable(_$AppDatabase db) =>
      db.cacheClasses.createAlias('cache_quizzes__class_id__cache_classes__id');

  $$CacheClassesTableProcessedTableManager get classId {
    final $_column = $_itemColumn<String>('class_id')!;

    final manager = $$CacheClassesTableTableManager(
      $_db,
      $_db.cacheClasses,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_classIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CacheProfilesTable _authorIdTable(_$AppDatabase db) => db
      .cacheProfiles
      .createAlias('cache_quizzes__author_id__cache_profiles__id');

  $$CacheProfilesTableProcessedTableManager get authorId {
    final $_column = $_itemColumn<String>('author_id')!;

    final manager = $$CacheProfilesTableTableManager(
      $_db,
      $_db.cacheProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_authorIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CacheQuizzesTableFilterComposer
    extends Composer<_$AppDatabase, $CacheQuizzesTable> {
  $$CacheQuizzesTableFilterComposer({
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

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get instructions => $composableBuilder(
    column: $table.instructions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timeLimitMinutes => $composableBuilder(
    column: $table.timeLimitMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get opensAt => $composableBuilder(
    column: $table.opensAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get closesAt => $composableBuilder(
    column: $table.closesAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get shuffleQuestions => $composableBuilder(
    column: $table.shuffleQuestions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get shuffleOptions => $composableBuilder(
    column: $table.shuffleOptions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get showCorrectAnswers => $composableBuilder(
    column: $table.showCorrectAnswers,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get passingPercent => $composableBuilder(
    column: $table.passingPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get resultsReleasedAt => $composableBuilder(
    column: $table.resultsReleasedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalPoints => $composableBuilder(
    column: $table.totalPoints,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasEssay => $composableBuilder(
    column: $table.hasEssay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lockedAt => $composableBuilder(
    column: $table.lockedAt,
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

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CacheClassesTableFilterComposer get classId {
    final $$CacheClassesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.classId,
      referencedTable: $db.cacheClasses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheClassesTableFilterComposer(
            $db: $db,
            $table: $db.cacheClasses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CacheProfilesTableFilterComposer get authorId {
    final $$CacheProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.authorId,
      referencedTable: $db.cacheProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheProfilesTableFilterComposer(
            $db: $db,
            $table: $db.cacheProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CacheQuizzesTableOrderingComposer
    extends Composer<_$AppDatabase, $CacheQuizzesTable> {
  $$CacheQuizzesTableOrderingComposer({
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

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get instructions => $composableBuilder(
    column: $table.instructions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timeLimitMinutes => $composableBuilder(
    column: $table.timeLimitMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get opensAt => $composableBuilder(
    column: $table.opensAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get closesAt => $composableBuilder(
    column: $table.closesAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get shuffleQuestions => $composableBuilder(
    column: $table.shuffleQuestions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get shuffleOptions => $composableBuilder(
    column: $table.shuffleOptions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get showCorrectAnswers => $composableBuilder(
    column: $table.showCorrectAnswers,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get passingPercent => $composableBuilder(
    column: $table.passingPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get resultsReleasedAt => $composableBuilder(
    column: $table.resultsReleasedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalPoints => $composableBuilder(
    column: $table.totalPoints,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasEssay => $composableBuilder(
    column: $table.hasEssay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lockedAt => $composableBuilder(
    column: $table.lockedAt,
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

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CacheClassesTableOrderingComposer get classId {
    final $$CacheClassesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.classId,
      referencedTable: $db.cacheClasses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheClassesTableOrderingComposer(
            $db: $db,
            $table: $db.cacheClasses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CacheProfilesTableOrderingComposer get authorId {
    final $$CacheProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.authorId,
      referencedTable: $db.cacheProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.cacheProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CacheQuizzesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CacheQuizzesTable> {
  $$CacheQuizzesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get instructions => $composableBuilder(
    column: $table.instructions,
    builder: (column) => column,
  );

  GeneratedColumn<int> get timeLimitMinutes => $composableBuilder(
    column: $table.timeLimitMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get opensAt =>
      $composableBuilder(column: $table.opensAt, builder: (column) => column);

  GeneratedColumn<DateTime> get closesAt =>
      $composableBuilder(column: $table.closesAt, builder: (column) => column);

  GeneratedColumn<bool> get shuffleQuestions => $composableBuilder(
    column: $table.shuffleQuestions,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get shuffleOptions => $composableBuilder(
    column: $table.shuffleOptions,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get showCorrectAnswers => $composableBuilder(
    column: $table.showCorrectAnswers,
    builder: (column) => column,
  );

  GeneratedColumn<int> get passingPercent => $composableBuilder(
    column: $table.passingPercent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get resultsReleasedAt => $composableBuilder(
    column: $table.resultsReleasedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalPoints => $composableBuilder(
    column: $table.totalPoints,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hasEssay =>
      $composableBuilder(column: $table.hasEssay, builder: (column) => column);

  GeneratedColumn<DateTime> get lockedAt =>
      $composableBuilder(column: $table.lockedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$CacheClassesTableAnnotationComposer get classId {
    final $$CacheClassesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.classId,
      referencedTable: $db.cacheClasses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheClassesTableAnnotationComposer(
            $db: $db,
            $table: $db.cacheClasses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CacheProfilesTableAnnotationComposer get authorId {
    final $$CacheProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.authorId,
      referencedTable: $db.cacheProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.cacheProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CacheQuizzesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CacheQuizzesTable,
          CacheQuizze,
          $$CacheQuizzesTableFilterComposer,
          $$CacheQuizzesTableOrderingComposer,
          $$CacheQuizzesTableAnnotationComposer,
          $$CacheQuizzesTableCreateCompanionBuilder,
          $$CacheQuizzesTableUpdateCompanionBuilder,
          (CacheQuizze, $$CacheQuizzesTableReferences),
          CacheQuizze,
          PrefetchHooks Function({bool classId, bool authorId})
        > {
  $$CacheQuizzesTableTableManager(_$AppDatabase db, $CacheQuizzesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CacheQuizzesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CacheQuizzesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CacheQuizzesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> classId = const Value.absent(),
                Value<String> authorId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> instructions = const Value.absent(),
                Value<int> timeLimitMinutes = const Value.absent(),
                Value<DateTime?> opensAt = const Value.absent(),
                Value<DateTime?> closesAt = const Value.absent(),
                Value<bool> shuffleQuestions = const Value.absent(),
                Value<bool> shuffleOptions = const Value.absent(),
                Value<bool> showCorrectAnswers = const Value.absent(),
                Value<int?> passingPercent = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime?> publishedAt = const Value.absent(),
                Value<DateTime?> resultsReleasedAt = const Value.absent(),
                Value<int> totalPoints = const Value.absent(),
                Value<bool> hasEssay = const Value.absent(),
                Value<DateTime?> lockedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CacheQuizzesCompanion(
                id: id,
                classId: classId,
                authorId: authorId,
                type: type,
                title: title,
                instructions: instructions,
                timeLimitMinutes: timeLimitMinutes,
                opensAt: opensAt,
                closesAt: closesAt,
                shuffleQuestions: shuffleQuestions,
                shuffleOptions: shuffleOptions,
                showCorrectAnswers: showCorrectAnswers,
                passingPercent: passingPercent,
                status: status,
                publishedAt: publishedAt,
                resultsReleasedAt: resultsReleasedAt,
                totalPoints: totalPoints,
                hasEssay: hasEssay,
                lockedAt: lockedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String classId,
                required String authorId,
                Value<String> type = const Value.absent(),
                required String title,
                Value<String?> instructions = const Value.absent(),
                Value<int> timeLimitMinutes = const Value.absent(),
                Value<DateTime?> opensAt = const Value.absent(),
                Value<DateTime?> closesAt = const Value.absent(),
                Value<bool> shuffleQuestions = const Value.absent(),
                Value<bool> shuffleOptions = const Value.absent(),
                Value<bool> showCorrectAnswers = const Value.absent(),
                Value<int?> passingPercent = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime?> publishedAt = const Value.absent(),
                Value<DateTime?> resultsReleasedAt = const Value.absent(),
                Value<int> totalPoints = const Value.absent(),
                Value<bool> hasEssay = const Value.absent(),
                Value<DateTime?> lockedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CacheQuizzesCompanion.insert(
                id: id,
                classId: classId,
                authorId: authorId,
                type: type,
                title: title,
                instructions: instructions,
                timeLimitMinutes: timeLimitMinutes,
                opensAt: opensAt,
                closesAt: closesAt,
                shuffleQuestions: shuffleQuestions,
                shuffleOptions: shuffleOptions,
                showCorrectAnswers: showCorrectAnswers,
                passingPercent: passingPercent,
                status: status,
                publishedAt: publishedAt,
                resultsReleasedAt: resultsReleasedAt,
                totalPoints: totalPoints,
                hasEssay: hasEssay,
                lockedAt: lockedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CacheQuizzesTable, CacheQuizze>(table),
                  $$CacheQuizzesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({classId = false, authorId = false}) {
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
                    if (classId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.classId,
                        referencedTable: $$CacheQuizzesTableReferences
                            ._classIdTable(db),
                        referencedColumn: $$CacheQuizzesTableReferences
                            ._classIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (authorId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.authorId,
                        referencedTable: $$CacheQuizzesTableReferences
                            ._authorIdTable(db),
                        referencedColumn: $$CacheQuizzesTableReferences
                            ._authorIdTable(db)
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

typedef $$CacheQuizzesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CacheQuizzesTable,
      CacheQuizze,
      $$CacheQuizzesTableFilterComposer,
      $$CacheQuizzesTableOrderingComposer,
      $$CacheQuizzesTableAnnotationComposer,
      $$CacheQuizzesTableCreateCompanionBuilder,
      $$CacheQuizzesTableUpdateCompanionBuilder,
      (CacheQuizze, $$CacheQuizzesTableReferences),
      CacheQuizze,
      PrefetchHooks Function({bool classId, bool authorId})
    >;
typedef $$CacheResultsTableCreateCompanionBuilder =
    CacheResultsCompanion Function({
      required String sessionId,
      required int score,
      required int totalPoints,
      required int percent,
      Value<bool?> passed,
      Value<String?> review,
      Value<int> rowid,
    });
typedef $$CacheResultsTableUpdateCompanionBuilder =
    CacheResultsCompanion Function({
      Value<String> sessionId,
      Value<int> score,
      Value<int> totalPoints,
      Value<int> percent,
      Value<bool?> passed,
      Value<String?> review,
      Value<int> rowid,
    });

class $$CacheResultsTableFilterComposer
    extends Composer<_$AppDatabase, $CacheResultsTable> {
  $$CacheResultsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalPoints => $composableBuilder(
    column: $table.totalPoints,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get percent => $composableBuilder(
    column: $table.percent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get passed => $composableBuilder(
    column: $table.passed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get review => $composableBuilder(
    column: $table.review,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CacheResultsTableOrderingComposer
    extends Composer<_$AppDatabase, $CacheResultsTable> {
  $$CacheResultsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalPoints => $composableBuilder(
    column: $table.totalPoints,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get percent => $composableBuilder(
    column: $table.percent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get passed => $composableBuilder(
    column: $table.passed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get review => $composableBuilder(
    column: $table.review,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CacheResultsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CacheResultsTable> {
  $$CacheResultsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<int> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<int> get totalPoints => $composableBuilder(
    column: $table.totalPoints,
    builder: (column) => column,
  );

  GeneratedColumn<int> get percent =>
      $composableBuilder(column: $table.percent, builder: (column) => column);

  GeneratedColumn<bool> get passed =>
      $composableBuilder(column: $table.passed, builder: (column) => column);

  GeneratedColumn<String> get review =>
      $composableBuilder(column: $table.review, builder: (column) => column);
}

class $$CacheResultsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CacheResultsTable,
          CacheResult,
          $$CacheResultsTableFilterComposer,
          $$CacheResultsTableOrderingComposer,
          $$CacheResultsTableAnnotationComposer,
          $$CacheResultsTableCreateCompanionBuilder,
          $$CacheResultsTableUpdateCompanionBuilder,
          (
            CacheResult,
            BaseReferences<_$AppDatabase, $CacheResultsTable, CacheResult>,
          ),
          CacheResult,
          PrefetchHooks Function()
        > {
  $$CacheResultsTableTableManager(_$AppDatabase db, $CacheResultsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CacheResultsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CacheResultsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CacheResultsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sessionId = const Value.absent(),
                Value<int> score = const Value.absent(),
                Value<int> totalPoints = const Value.absent(),
                Value<int> percent = const Value.absent(),
                Value<bool?> passed = const Value.absent(),
                Value<String?> review = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CacheResultsCompanion(
                sessionId: sessionId,
                score: score,
                totalPoints: totalPoints,
                percent: percent,
                passed: passed,
                review: review,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sessionId,
                required int score,
                required int totalPoints,
                required int percent,
                Value<bool?> passed = const Value.absent(),
                Value<String?> review = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CacheResultsCompanion.insert(
                sessionId: sessionId,
                score: score,
                totalPoints: totalPoints,
                percent: percent,
                passed: passed,
                review: review,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CacheResultsTable, CacheResult>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CacheResultsTable,
                    CacheResult
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CacheResultsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CacheResultsTable,
      CacheResult,
      $$CacheResultsTableFilterComposer,
      $$CacheResultsTableOrderingComposer,
      $$CacheResultsTableAnnotationComposer,
      $$CacheResultsTableCreateCompanionBuilder,
      $$CacheResultsTableUpdateCompanionBuilder,
      (
        CacheResult,
        BaseReferences<_$AppDatabase, $CacheResultsTable, CacheResult>,
      ),
      CacheResult,
      PrefetchHooks Function()
    >;
typedef $$CacheNotificationsTableCreateCompanionBuilder =
    CacheNotificationsCompanion Function({
      required String id,
      required String recipientId,
      Value<String?> classId,
      required String type,
      required String title,
      Value<String?> body,
      Value<String?> targetType,
      Value<String?> targetId,
      Value<DateTime?> readAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$CacheNotificationsTableUpdateCompanionBuilder =
    CacheNotificationsCompanion Function({
      Value<String> id,
      Value<String> recipientId,
      Value<String?> classId,
      Value<String> type,
      Value<String> title,
      Value<String?> body,
      Value<String?> targetType,
      Value<String?> targetId,
      Value<DateTime?> readAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$CacheNotificationsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $CacheNotificationsTable,
          CacheNotification
        > {
  $$CacheNotificationsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CacheProfilesTable _recipientIdTable(_$AppDatabase db) => db
      .cacheProfiles
      .createAlias('cache_notifications__recipient_id__cache_profiles__id');

  $$CacheProfilesTableProcessedTableManager get recipientId {
    final $_column = $_itemColumn<String>('recipient_id')!;

    final manager = $$CacheProfilesTableTableManager(
      $_db,
      $_db.cacheProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_recipientIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CacheClassesTable _classIdTable(_$AppDatabase db) => db.cacheClasses
      .createAlias('cache_notifications__class_id__cache_classes__id');

  $$CacheClassesTableProcessedTableManager? get classId {
    final $_column = $_itemColumn<String>('class_id');
    if ($_column == null) return null;
    final manager = $$CacheClassesTableTableManager(
      $_db,
      $_db.cacheClasses,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_classIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CacheNotificationsTableFilterComposer
    extends Composer<_$AppDatabase, $CacheNotificationsTable> {
  $$CacheNotificationsTableFilterComposer({
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

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetType => $composableBuilder(
    column: $table.targetType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get readAt => $composableBuilder(
    column: $table.readAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CacheProfilesTableFilterComposer get recipientId {
    final $$CacheProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipientId,
      referencedTable: $db.cacheProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheProfilesTableFilterComposer(
            $db: $db,
            $table: $db.cacheProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CacheClassesTableFilterComposer get classId {
    final $$CacheClassesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.classId,
      referencedTable: $db.cacheClasses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheClassesTableFilterComposer(
            $db: $db,
            $table: $db.cacheClasses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CacheNotificationsTableOrderingComposer
    extends Composer<_$AppDatabase, $CacheNotificationsTable> {
  $$CacheNotificationsTableOrderingComposer({
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

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetType => $composableBuilder(
    column: $table.targetType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get readAt => $composableBuilder(
    column: $table.readAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CacheProfilesTableOrderingComposer get recipientId {
    final $$CacheProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipientId,
      referencedTable: $db.cacheProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.cacheProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CacheClassesTableOrderingComposer get classId {
    final $$CacheClassesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.classId,
      referencedTable: $db.cacheClasses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheClassesTableOrderingComposer(
            $db: $db,
            $table: $db.cacheClasses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CacheNotificationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CacheNotificationsTable> {
  $$CacheNotificationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get targetType => $composableBuilder(
    column: $table.targetType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get targetId =>
      $composableBuilder(column: $table.targetId, builder: (column) => column);

  GeneratedColumn<DateTime> get readAt =>
      $composableBuilder(column: $table.readAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$CacheProfilesTableAnnotationComposer get recipientId {
    final $$CacheProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipientId,
      referencedTable: $db.cacheProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.cacheProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CacheClassesTableAnnotationComposer get classId {
    final $$CacheClassesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.classId,
      referencedTable: $db.cacheClasses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CacheClassesTableAnnotationComposer(
            $db: $db,
            $table: $db.cacheClasses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CacheNotificationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CacheNotificationsTable,
          CacheNotification,
          $$CacheNotificationsTableFilterComposer,
          $$CacheNotificationsTableOrderingComposer,
          $$CacheNotificationsTableAnnotationComposer,
          $$CacheNotificationsTableCreateCompanionBuilder,
          $$CacheNotificationsTableUpdateCompanionBuilder,
          (CacheNotification, $$CacheNotificationsTableReferences),
          CacheNotification,
          PrefetchHooks Function({bool recipientId, bool classId})
        > {
  $$CacheNotificationsTableTableManager(
    _$AppDatabase db,
    $CacheNotificationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CacheNotificationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CacheNotificationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CacheNotificationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> recipientId = const Value.absent(),
                Value<String?> classId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> body = const Value.absent(),
                Value<String?> targetType = const Value.absent(),
                Value<String?> targetId = const Value.absent(),
                Value<DateTime?> readAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CacheNotificationsCompanion(
                id: id,
                recipientId: recipientId,
                classId: classId,
                type: type,
                title: title,
                body: body,
                targetType: targetType,
                targetId: targetId,
                readAt: readAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String recipientId,
                Value<String?> classId = const Value.absent(),
                required String type,
                required String title,
                Value<String?> body = const Value.absent(),
                Value<String?> targetType = const Value.absent(),
                Value<String?> targetId = const Value.absent(),
                Value<DateTime?> readAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CacheNotificationsCompanion.insert(
                id: id,
                recipientId: recipientId,
                classId: classId,
                type: type,
                title: title,
                body: body,
                targetType: targetType,
                targetId: targetId,
                readAt: readAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CacheNotificationsTable, CacheNotification>(
                    table,
                  ),
                  $$CacheNotificationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({recipientId = false, classId = false}) {
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
                    if (recipientId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.recipientId,
                        referencedTable: $$CacheNotificationsTableReferences
                            ._recipientIdTable(db),
                        referencedColumn: $$CacheNotificationsTableReferences
                            ._recipientIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (classId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.classId,
                        referencedTable: $$CacheNotificationsTableReferences
                            ._classIdTable(db),
                        referencedColumn: $$CacheNotificationsTableReferences
                            ._classIdTable(db)
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

typedef $$CacheNotificationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CacheNotificationsTable,
      CacheNotification,
      $$CacheNotificationsTableFilterComposer,
      $$CacheNotificationsTableOrderingComposer,
      $$CacheNotificationsTableAnnotationComposer,
      $$CacheNotificationsTableCreateCompanionBuilder,
      $$CacheNotificationsTableUpdateCompanionBuilder,
      (CacheNotification, $$CacheNotificationsTableReferences),
      CacheNotification,
      PrefetchHooks Function({bool recipientId, bool classId})
    >;
typedef $$SyncStateTableCreateCompanionBuilder = SyncStateCompanion Function({
  required String syncedTableName,
  Value<DateTime?> lastSyncedAt,
  Value<int> rowid,
});
typedef $$SyncStateTableUpdateCompanionBuilder = SyncStateCompanion Function({
  Value<String> syncedTableName,
  Value<DateTime?> lastSyncedAt,
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
  ColumnFilters<String> get syncedTableName => $composableBuilder(
    column: $table.syncedTableName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
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
  ColumnOrderings<String> get syncedTableName => $composableBuilder(
    column: $table.syncedTableName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
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
  GeneratedColumn<String> get syncedTableName => $composableBuilder(
    column: $table.syncedTableName,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );
}

class $$SyncStateTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncStateTable,
          SyncStateData,
          $$SyncStateTableFilterComposer,
          $$SyncStateTableOrderingComposer,
          $$SyncStateTableAnnotationComposer,
          $$SyncStateTableCreateCompanionBuilder,
          $$SyncStateTableUpdateCompanionBuilder,
          (
            SyncStateData,
            BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateData>,
          ),
          SyncStateData,
          PrefetchHooks Function()
        > {
  $$SyncStateTableTableManager(_$AppDatabase db, $SyncStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> syncedTableName = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStateCompanion(
                syncedTableName: syncedTableName,
                lastSyncedAt: lastSyncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String syncedTableName,
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStateCompanion.insert(
                syncedTableName: syncedTableName,
                lastSyncedAt: lastSyncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncStateTable, SyncStateData>(table),
                  BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateData>(
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

typedef $$SyncStateTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncStateTable,
      SyncStateData,
      $$SyncStateTableFilterComposer,
      $$SyncStateTableOrderingComposer,
      $$SyncStateTableAnnotationComposer,
      $$SyncStateTableCreateCompanionBuilder,
      $$SyncStateTableUpdateCompanionBuilder,
      (
        SyncStateData,
        BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateData>,
      ),
      SyncStateData,
      PrefetchHooks Function()
    >;
typedef $$OutboxTableCreateCompanionBuilder = OutboxCompanion Function({
  required String id,
  required String actionType,
  required String payload,
  Value<DateTime> createdAt,
  Value<int> attempts,
  Value<String?> lastError,
  required String status,
  Value<int> rowid,
});
typedef $$OutboxTableUpdateCompanionBuilder = OutboxCompanion Function({
  Value<String> id,
  Value<String> actionType,
  Value<String> payload,
  Value<DateTime> createdAt,
  Value<int> attempts,
  Value<String?> lastError,
  Value<String> status,
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
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actionType => $composableBuilder(
    column: $table.actionType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
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

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
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
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actionType => $composableBuilder(
    column: $table.actionType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
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

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
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
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get actionType => $composableBuilder(
    column: $table.actionType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$OutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxTable,
          OutboxData,
          $$OutboxTableFilterComposer,
          $$OutboxTableOrderingComposer,
          $$OutboxTableAnnotationComposer,
          $$OutboxTableCreateCompanionBuilder,
          $$OutboxTableUpdateCompanionBuilder,
          (OutboxData, BaseReferences<_$AppDatabase, $OutboxTable, OutboxData>),
          OutboxData,
          PrefetchHooks Function()
        > {
  $$OutboxTableTableManager(_$AppDatabase db, $OutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> actionType = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxCompanion(
                id: id,
                actionType: actionType,
                payload: payload,
                createdAt: createdAt,
                attempts: attempts,
                lastError: lastError,
                status: status,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String actionType,
                required String payload,
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                required String status,
                Value<int> rowid = const Value.absent(),
              }) => OutboxCompanion.insert(
                id: id,
                actionType: actionType,
                payload: payload,
                createdAt: createdAt,
                attempts: attempts,
                lastError: lastError,
                status: status,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OutboxTable, OutboxData>(table),
                  BaseReferences<_$AppDatabase, $OutboxTable, OutboxData>(
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

typedef $$OutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxTable,
      OutboxData,
      $$OutboxTableFilterComposer,
      $$OutboxTableOrderingComposer,
      $$OutboxTableAnnotationComposer,
      $$OutboxTableCreateCompanionBuilder,
      $$OutboxTableUpdateCompanionBuilder,
      (OutboxData, BaseReferences<_$AppDatabase, $OutboxTable, OutboxData>),
      OutboxData,
      PrefetchHooks Function()
    >;
typedef $$LocalFoldersTableCreateCompanionBuilder =
    LocalFoldersCompanion Function({
      required String id,
      Value<String?> parentId,
      required String name,
      Value<String?> classId,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$LocalFoldersTableUpdateCompanionBuilder =
    LocalFoldersCompanion Function({
      Value<String> id,
      Value<String?> parentId,
      Value<String> name,
      Value<String?> classId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$LocalFoldersTableReferences
    extends
        BaseReferences<_$AppDatabase, $LocalFoldersTable, LocalFolderRecord> {
  $$LocalFoldersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LocalFoldersTable _parentIdTable(_$AppDatabase db) => db.localFolders
      .createAlias('local_folders__parent_id__local_folders__id');

  $$LocalFoldersTableProcessedTableManager? get parentId {
    final $_column = $_itemColumn<String>('parent_id');
    if ($_column == null) return null;
    final manager = $$LocalFoldersTableTableManager(
      $_db,
      $_db.localFolders,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$LocalFilesTable, List<LocalFileRecord>>
  _localFilesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.localFiles,
    aliasName: 'local_folders__id__local_files__folder_id',
  );

  $$LocalFilesTableProcessedTableManager get localFilesRefs {
    final manager = $$LocalFilesTableTableManager(
      $_db,
      $_db.localFiles,
    ).filter((f) => f.folderId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_localFilesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LocalFoldersTableFilterComposer
    extends Composer<_$AppDatabase, $LocalFoldersTable> {
  $$LocalFoldersTableFilterComposer({
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

  ColumnFilters<String> get classId => $composableBuilder(
    column: $table.classId,
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

  $$LocalFoldersTableFilterComposer get parentId {
    final $$LocalFoldersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentId,
      referencedTable: $db.localFolders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalFoldersTableFilterComposer(
            $db: $db,
            $table: $db.localFolders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> localFilesRefs(
    Expression<bool> Function($$LocalFilesTableFilterComposer f) f,
  ) {
    final $$LocalFilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localFiles,
      getReferencedColumn: (t) => t.folderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalFilesTableFilterComposer(
            $db: $db,
            $table: $db.localFiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LocalFoldersTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalFoldersTable> {
  $$LocalFoldersTableOrderingComposer({
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

  ColumnOrderings<String> get classId => $composableBuilder(
    column: $table.classId,
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

  $$LocalFoldersTableOrderingComposer get parentId {
    final $$LocalFoldersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentId,
      referencedTable: $db.localFolders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalFoldersTableOrderingComposer(
            $db: $db,
            $table: $db.localFolders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalFoldersTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalFoldersTable> {
  $$LocalFoldersTableAnnotationComposer({
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

  GeneratedColumn<String> get classId =>
      $composableBuilder(column: $table.classId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$LocalFoldersTableAnnotationComposer get parentId {
    final $$LocalFoldersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentId,
      referencedTable: $db.localFolders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalFoldersTableAnnotationComposer(
            $db: $db,
            $table: $db.localFolders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> localFilesRefs<T extends Object>(
    Expression<T> Function($$LocalFilesTableAnnotationComposer a) f,
  ) {
    final $$LocalFilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localFiles,
      getReferencedColumn: (t) => t.folderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalFilesTableAnnotationComposer(
            $db: $db,
            $table: $db.localFiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LocalFoldersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalFoldersTable,
          LocalFolderRecord,
          $$LocalFoldersTableFilterComposer,
          $$LocalFoldersTableOrderingComposer,
          $$LocalFoldersTableAnnotationComposer,
          $$LocalFoldersTableCreateCompanionBuilder,
          $$LocalFoldersTableUpdateCompanionBuilder,
          (LocalFolderRecord, $$LocalFoldersTableReferences),
          LocalFolderRecord,
          PrefetchHooks Function({bool parentId, bool localFilesRefs})
        > {
  $$LocalFoldersTableTableManager(_$AppDatabase db, $LocalFoldersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalFoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalFoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalFoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> classId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalFoldersCompanion(
                id: id,
                parentId: parentId,
                name: name,
                classId: classId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> parentId = const Value.absent(),
                required String name,
                Value<String?> classId = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalFoldersCompanion.insert(
                id: id,
                parentId: parentId,
                name: name,
                classId: classId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalFoldersTable, LocalFolderRecord>(table),
                  $$LocalFoldersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({parentId = false, localFilesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (localFilesRefs) db.localFiles],
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
                    if (parentId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.parentId,
                        referencedTable: $$LocalFoldersTableReferences
                            ._parentIdTable(db),
                        referencedColumn: $$LocalFoldersTableReferences
                            ._parentIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (localFilesRefs)
                    await $_getPrefetchedData<
                      LocalFolderRecord,
                      $LocalFoldersTable,
                      LocalFileRecord
                    >(
                      currentTable: table,
                      referencedTable: $$LocalFoldersTableReferences
                          ._localFilesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$LocalFoldersTableReferences(
                            db,
                            table,
                            p0,
                          ).localFilesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.folderId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$LocalFoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalFoldersTable,
      LocalFolderRecord,
      $$LocalFoldersTableFilterComposer,
      $$LocalFoldersTableOrderingComposer,
      $$LocalFoldersTableAnnotationComposer,
      $$LocalFoldersTableCreateCompanionBuilder,
      $$LocalFoldersTableUpdateCompanionBuilder,
      (LocalFolderRecord, $$LocalFoldersTableReferences),
      LocalFolderRecord,
      PrefetchHooks Function({bool parentId, bool localFilesRefs})
    >;
typedef $$LocalFilesTableCreateCompanionBuilder = LocalFilesCompanion Function({
  required String id,
  Value<String?> folderId,
  required String name,
  required String relativePath,
  Value<String?> mimeType,
  required int size,
  required String source,
  Value<String?> sourceAttachmentId,
  Value<String?> classId,
  Value<String?> sourcePostId,
  Value<DateTime?> backedUpAt,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$LocalFilesTableUpdateCompanionBuilder = LocalFilesCompanion Function({
  Value<String> id,
  Value<String?> folderId,
  Value<String> name,
  Value<String> relativePath,
  Value<String?> mimeType,
  Value<int> size,
  Value<String> source,
  Value<String?> sourceAttachmentId,
  Value<String?> classId,
  Value<String?> sourcePostId,
  Value<DateTime?> backedUpAt,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$LocalFilesTableReferences
    extends BaseReferences<_$AppDatabase, $LocalFilesTable, LocalFileRecord> {
  $$LocalFilesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LocalFoldersTable _folderIdTable(_$AppDatabase db) =>
      db.localFolders.createAlias('local_files__folder_id__local_folders__id');

  $$LocalFoldersTableProcessedTableManager? get folderId {
    final $_column = $_itemColumn<String>('folder_id');
    if ($_column == null) return null;
    final manager = $$LocalFoldersTableTableManager(
      $_db,
      $_db.localFolders,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_folderIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LocalFilesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalFilesTable> {
  $$LocalFilesTableFilterComposer({
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

  ColumnFilters<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceAttachmentId => $composableBuilder(
    column: $table.sourceAttachmentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get classId => $composableBuilder(
    column: $table.classId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourcePostId => $composableBuilder(
    column: $table.sourcePostId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get backedUpAt => $composableBuilder(
    column: $table.backedUpAt,
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

  $$LocalFoldersTableFilterComposer get folderId {
    final $$LocalFoldersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.localFolders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalFoldersTableFilterComposer(
            $db: $db,
            $table: $db.localFolders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalFilesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalFilesTable> {
  $$LocalFilesTableOrderingComposer({
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

  ColumnOrderings<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceAttachmentId => $composableBuilder(
    column: $table.sourceAttachmentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get classId => $composableBuilder(
    column: $table.classId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourcePostId => $composableBuilder(
    column: $table.sourcePostId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get backedUpAt => $composableBuilder(
    column: $table.backedUpAt,
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

  $$LocalFoldersTableOrderingComposer get folderId {
    final $$LocalFoldersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.localFolders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalFoldersTableOrderingComposer(
            $db: $db,
            $table: $db.localFolders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalFilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalFilesTable> {
  $$LocalFilesTableAnnotationComposer({
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

  GeneratedColumn<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get sourceAttachmentId => $composableBuilder(
    column: $table.sourceAttachmentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get classId =>
      $composableBuilder(column: $table.classId, builder: (column) => column);

  GeneratedColumn<String> get sourcePostId => $composableBuilder(
    column: $table.sourcePostId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get backedUpAt => $composableBuilder(
    column: $table.backedUpAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$LocalFoldersTableAnnotationComposer get folderId {
    final $$LocalFoldersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.localFolders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalFoldersTableAnnotationComposer(
            $db: $db,
            $table: $db.localFolders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalFilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalFilesTable,
          LocalFileRecord,
          $$LocalFilesTableFilterComposer,
          $$LocalFilesTableOrderingComposer,
          $$LocalFilesTableAnnotationComposer,
          $$LocalFilesTableCreateCompanionBuilder,
          $$LocalFilesTableUpdateCompanionBuilder,
          (LocalFileRecord, $$LocalFilesTableReferences),
          LocalFileRecord,
          PrefetchHooks Function({bool folderId})
        > {
  $$LocalFilesTableTableManager(_$AppDatabase db, $LocalFilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalFilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalFilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalFilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> folderId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> relativePath = const Value.absent(),
                Value<String?> mimeType = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> sourceAttachmentId = const Value.absent(),
                Value<String?> classId = const Value.absent(),
                Value<String?> sourcePostId = const Value.absent(),
                Value<DateTime?> backedUpAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalFilesCompanion(
                id: id,
                folderId: folderId,
                name: name,
                relativePath: relativePath,
                mimeType: mimeType,
                size: size,
                source: source,
                sourceAttachmentId: sourceAttachmentId,
                classId: classId,
                sourcePostId: sourcePostId,
                backedUpAt: backedUpAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> folderId = const Value.absent(),
                required String name,
                required String relativePath,
                Value<String?> mimeType = const Value.absent(),
                required int size,
                required String source,
                Value<String?> sourceAttachmentId = const Value.absent(),
                Value<String?> classId = const Value.absent(),
                Value<String?> sourcePostId = const Value.absent(),
                Value<DateTime?> backedUpAt = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalFilesCompanion.insert(
                id: id,
                folderId: folderId,
                name: name,
                relativePath: relativePath,
                mimeType: mimeType,
                size: size,
                source: source,
                sourceAttachmentId: sourceAttachmentId,
                classId: classId,
                sourcePostId: sourcePostId,
                backedUpAt: backedUpAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalFilesTable, LocalFileRecord>(table),
                  $$LocalFilesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({folderId = false}) {
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
                    if (folderId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.folderId,
                        referencedTable: $$LocalFilesTableReferences
                            ._folderIdTable(db),
                        referencedColumn: $$LocalFilesTableReferences
                            ._folderIdTable(db)
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

typedef $$LocalFilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalFilesTable,
      LocalFileRecord,
      $$LocalFilesTableFilterComposer,
      $$LocalFilesTableOrderingComposer,
      $$LocalFilesTableAnnotationComposer,
      $$LocalFilesTableCreateCompanionBuilder,
      $$LocalFilesTableUpdateCompanionBuilder,
      (LocalFileRecord, $$LocalFilesTableReferences),
      LocalFileRecord,
      PrefetchHooks Function({bool folderId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CacheProfilesTableTableManager get cacheProfiles =>
      $$CacheProfilesTableTableManager(_db, _db.cacheProfiles);
  $$CacheClassesTableTableManager get cacheClasses =>
      $$CacheClassesTableTableManager(_db, _db.cacheClasses);
  $$CacheClassMembersTableTableManager get cacheClassMembers =>
      $$CacheClassMembersTableTableManager(_db, _db.cacheClassMembers);
  $$CachePostsTableTableManager get cachePosts =>
      $$CachePostsTableTableManager(_db, _db.cachePosts);
  $$CachePostAttachmentsTableTableManager get cachePostAttachments =>
      $$CachePostAttachmentsTableTableManager(_db, _db.cachePostAttachments);
  $$CacheSubmissionsTableTableManager get cacheSubmissions =>
      $$CacheSubmissionsTableTableManager(_db, _db.cacheSubmissions);
  $$CacheSubmissionItemsTableTableManager get cacheSubmissionItems =>
      $$CacheSubmissionItemsTableTableManager(_db, _db.cacheSubmissionItems);
  $$CacheGradesTableTableManager get cacheGrades =>
      $$CacheGradesTableTableManager(_db, _db.cacheGrades);
  $$CacheQuizzesTableTableManager get cacheQuizzes =>
      $$CacheQuizzesTableTableManager(_db, _db.cacheQuizzes);
  $$CacheResultsTableTableManager get cacheResults =>
      $$CacheResultsTableTableManager(_db, _db.cacheResults);
  $$CacheNotificationsTableTableManager get cacheNotifications =>
      $$CacheNotificationsTableTableManager(_db, _db.cacheNotifications);
  $$SyncStateTableTableManager get syncState =>
      $$SyncStateTableTableManager(_db, _db.syncState);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
  $$LocalFoldersTableTableManager get localFolders =>
      $$LocalFoldersTableTableManager(_db, _db.localFolders);
  $$LocalFilesTableTableManager get localFiles =>
      $$LocalFilesTableTableManager(_db, _db.localFiles);
}
